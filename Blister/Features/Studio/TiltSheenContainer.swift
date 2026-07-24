import CoreMotion
import SwiftUI
import os

/// A reusable "tilt + sheen" interaction wrapper for the car-detail hero.
///
/// Wraps arbitrary `content` in a tactile card that:
/// - tilts in 3D (`rotation3DEffect` about X and Y) following a `DragGesture`, using ``TiltMath``,
///   springing back to flat on release;
/// - carries a diagonal translucent sheen that slides across as it tilts ("metal catching light");
/// - drifts with a subtle ambient tilt from device motion when idle (when available);
/// - calls `onActivate` on a tap (distinct from the drag).
///
/// Honours `accessibilityReduceMotion`: ambient motion is disabled and the spring is softened.
struct TiltSheenContainer<Content: View>: View {
    private let onActivate: () -> Void
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var motion = MotionCoordinator()
    @GestureState private var dragTranslation: CGSize = .zero
    @State private var isDragging = false

    private let maxDegrees: Double = 12
    private let sheenTravel: CGFloat = 60

    init(onActivate: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onActivate = onActivate
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let angles = currentAngles(in: proxy.size)
            let sheen = TiltMath.sheenOffset(for: angles, maxDegrees: maxDegrees, travel: sheenTravel)

            content
                .overlay { sheenOverlay(offset: sheen) }
                .rotation3DEffect(
                    .degrees(angles.x),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .center,
                    anchorZ: 0,
                    perspective: 0.6
                )
                .rotation3DEffect(
                    .degrees(angles.y),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .center,
                    anchorZ: 0,
                    perspective: 0.6
                )
                .animation(springBack, value: dragTranslation)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .contentShape(Rectangle())
                .gesture(dragGesture)
                .onTapGesture { onActivate() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(localized: "View in studio"))
                .accessibilityHint(String(localized: "Opens a 3D studio view of this photo"))
        }
        .onAppear { startAmbientIfPossible() }
        .onDisappear { motion.stop() }
        .onChange(of: reduceMotion) { _, _ in startAmbientIfPossible() }
    }

    // MARK: Angles

    /// Angles from the active drag, or the ambient device tilt when idle. Zero if reduce-motion is on
    /// and there is no drag.
    private func currentAngles(in size: CGSize) -> (x: Double, y: Double) {
        if isDragging || dragTranslation != .zero {
            return TiltMath.tiltAngles(for: dragTranslation, in: size, maxDegrees: maxDegrees)
        }
        guard !reduceMotion else { return (x: 0, y: 0) }
        return motion.ambientAngles(maxDegrees: maxDegrees * 0.4)
    }

    private var springBack: Animation? {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: Gestures

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                if !isDragging { isDragging = true }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    // MARK: Sheen

    @ViewBuilder
    private func sheenOverlay(offset: CGSize) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.35), location: 0.5),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .scaleEffect(1.8)
        .offset(offset)
        .blendMode(.plusLighter)
        .mask { content }
        .allowsHitTesting(false)
    }

    // MARK: Ambient motion

    private func startAmbientIfPossible() {
        if reduceMotion {
            motion.stop()
        } else {
            motion.start()
        }
    }
}

/// Confines the non-`Sendable` `CMMotionManager` to the main actor and publishes a smoothed ambient
/// tilt. Device-motion callbacks hop threads, so values are marshalled back to the main actor.
@MainActor
@Observable
final class MotionCoordinator {
    /// Device roll in radians (rotation about the front-to-back axis).
    private(set) var roll: Double = 0
    /// Device pitch in radians (rotation about the left-to-right axis).
    private(set) var pitch: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let logger = Logger(subsystem: "app.blister", category: "TiltMotion")

    /// Maps the current device attitude to small tilt angles, clamped to `±maxDegrees`.
    func ambientAngles(maxDegrees: Double) -> (x: Double, y: Double) {
        // Scale radians so a modest wrist tilt reaches the ambient bound.
        let scale = maxDegrees / (Double.pi / 6)
        let x = clamp(pitch * scale, to: maxDegrees)
        let y = clamp(roll * scale, to: maxDegrees)
        return (x: x, y: y)
    }

    /// Begins device-motion updates if the hardware supports it. No-op (and no crash) otherwise —
    /// e.g. on the Simulator.
    func start() {
        guard manager.isDeviceMotionAvailable else {
            logger.debug("Device motion unavailable; skipping ambient tilt.")
            return
        }
        guard !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            // Delivered on the main queue, so we are already on the main actor.
            MainActor.assumeIsolated {
                self?.roll = roll
                self?.pitch = pitch
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        roll = 0
        pitch = 0
    }

    private func clamp(_ value: Double, to bound: Double) -> Double {
        min(max(value, -bound), bound)
    }
}
