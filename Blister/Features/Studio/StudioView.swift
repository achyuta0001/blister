import RealityKit
import SwiftUI

/// Full-screen 3D "studio" viewer for a car photo (**frozen contract** — the detail hero presents
/// this). Renders the photo as a lit, glossy card on a turntable inside a RealityKit studio scene:
/// reflective floor, contact shadow, and a key/fill/rim light rig.
///
/// Interaction: the card slowly auto-rotates (disabled under Reduce Motion); a drag orbits it
/// (horizontal = spin, vertical = camera pitch) and overrides the auto-rotation; a pinch dollies the
/// camera. If the photo can't be turned into a texture, a plain SwiftUI stage with a simple reflection
/// is shown instead so the screen never goes black. Keep the `init(image:)` signature.
struct StudioView: View {
    let image: UIImage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: StudioScene?
    @State private var didFail = false

    init(image: UIImage) {
        self.image = image
    }

    var body: some View {
        ZStack {
            studioBackdrop

            if let scene {
                stage(scene)
            } else if didFail {
                StudioFallbackStage(image: image)
            } else {
                ProgressView()
                    .tint(DesignTokens.accent)
            }
        }
        .overlay(alignment: .topTrailing) { doneButton }
        .task {
            guard scene == nil, !didFail else { return }
            if let built = await StudioScene.make(image: image, reduceMotion: reduceMotion) {
                scene = built
            } else {
                didFail = true
            }
        }
    }

    // MARK: - RealityKit stage

    private func stage(_ scene: StudioScene) -> some View {
        RealityView { content in
            content.add(scene.root)
            // Drive the turntable off RealityKit's own frame clock so the SwiftUI view need not
            // re-render each frame (keeps drag/pinch gestures stable). Runs on the main actor.
            scene.updateSubscription = content.subscribe(to: SceneEvents.Update.self) { event in
                MainActor.assumeIsolated {
                    scene.tick(deltaTime: event.deltaTime)
                }
            }
        }
        .gesture(orbitGesture(scene))
        .simultaneousGesture(zoomGesture(scene))
        .ignoresSafeArea()
    }

    private func orbitGesture(_ scene: StudioScene) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if value.translation == .zero { scene.beginDrag() }
                scene.updateDrag(translation: value.translation)
            }
            .onEnded { _ in scene.endDrag() }
    }

    private func zoomGesture(_ scene: StudioScene) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if value.magnification == 1 { scene.beginZoom() }
                scene.updateZoom(scale: value.magnification)
            }
            .onEnded { _ in scene.endZoom() }
    }

    // MARK: - Chrome

    private var studioBackdrop: some View {
        RadialGradient(colors: [Color(white: 0.16), DesignTokens.background],
                       center: .center, startRadius: 0, endRadius: 520)
            .ignoresSafeArea()
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text(String(localized: "Done"))
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.accent)
                .frame(minWidth: DesignTokens.minTapTarget, minHeight: DesignTokens.minTapTarget)
                .padding(.horizontal, DesignTokens.spacingS)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(DesignTokens.spacingM)
    }
}

/// SwiftUI fallback when the RealityKit scene can't be built: the photo on the studio backdrop with a
/// simple mirrored, faded reflection. Never crashes, never shows black.
private struct StudioFallbackStage: View {
    let image: UIImage

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(x: 1, y: -1)
                .opacity(0.28)
                .mask(
                    LinearGradient(colors: [.black, .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
                .frame(maxHeight: 120)
                .clipped()
        }
        .padding(DesignTokens.spacingL)
    }
}
