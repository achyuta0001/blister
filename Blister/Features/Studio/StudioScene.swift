import Foundation
import os
import RealityKit
import simd
import UIKit

/// Builds and drives the RealityKit "studio" scene for a single car photo.
///
/// The photo becomes a lit, glossy card standing on a reflective studio floor: a rounded slab body
/// (so it keeps visible depth at grazing angles), a front label plane textured with the photo, a
/// gradient-faded mirror reflection below the floor, and a soft contact-shadow blob beneath it. A key
/// + fill + rim light rig gives it a photographed-in-a-studio feel.
///
/// All entity mutation happens on the main actor; `StudioView` owns the SwiftUI/`RealityView` shell
/// and forwards gesture + per-frame ticks here. `make(image:reduceMotion:)` returns `nil` (never
/// crashes, never force-unwraps) when the photo can't be turned into a texture, letting the view fall
/// back to a plain SwiftUI stage.
@MainActor
final class StudioScene {
    /// Root that is added to the `RealityView` content; owns the camera, lights, floor and turntable.
    let root = Entity()

    /// Retains the per-frame update subscription so the turntable keeps spinning.
    var updateSubscription: EventSubscription?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Blister",
                                       category: "StudioScene")

    // Scene graph.
    private let turntable = Entity()          // Yaw pivot for the card + its reflection.
    private let camera = PerspectiveCamera()

    // Card metrics (metres).
    private let cardHeight: Float = 0.62

    // Interaction state.
    //
    // The card is a flat cutout, so *spinning it* would expose its paper-thin edge (the "plaque"
    // look). Instead the card stays put and the **camera orbits around it**, clamped to a shallow
    // arc so the face is always mostly toward the viewer — the reflective floor + shadow sell the
    // sense of a piece sitting in a lit display case rather than a rotating sign.
    private let autoRotate: Bool
    private var isDragging = false
    private var isZooming = false
    private var hasInteracted = false         // once the user drags, the resting sway stops for good
    private var autoPhase: Float = 0          // drives the gentle idle sway

    /// Horizontal camera orbit angle around the card (0 = head-on). Clamped so the face never goes
    /// edge-on and reveals the cutout's flatness.
    private var azimuth: Float = -0.32        // start slightly angled for a 3-D read
    private let azimuthLimit: Float = 0.62    // ~35° each way
    private var elevation: Float = 0.18       // camera pitch above the card centre
    private var distance: Float = 1.55        // camera dolly (set to frame the card in init)
    private var defaultDistance: Float = 1.55 // the framed distance; zoom clamps are relative to it

    private var azimuthAtDragStart: Float = 0
    private var elevationAtDragStart: Float = 0
    private var distanceAtZoomStart: Float = 0

    // MARK: - Construction

    /// Builds the scene asynchronously. Returns `nil` if the image can't be turned into a texture.
    static func make(image: UIImage, reduceMotion: Bool) async -> StudioScene? {
        guard let base = normalizedCGImage(from: image) else {
            logger.error("Studio scene unavailable: image has no drawable representation")
            return nil
        }
        guard let reflectionImage = reflectionCGImage(from: base),
              let shadowImage = contactShadowCGImage() else {
            logger.error("Studio scene unavailable: could not synthesise reflection/shadow textures")
            return nil
        }

        do {
            let colorOptions = TextureResource.CreateOptions(semantic: .color)
            let photoTexture = try await TextureResource(image: base, options: colorOptions)
            let reflectionTexture = try await TextureResource(image: reflectionImage, options: colorOptions)
            let shadowTexture = try await TextureResource(image: shadowImage, options: colorOptions)

            let aspect = Float(base.width) / Float(max(base.height, 1))
            return StudioScene(photoTexture: photoTexture,
                               reflectionTexture: reflectionTexture,
                               shadowTexture: shadowTexture,
                               aspect: aspect,
                               reduceMotion: reduceMotion)
        } catch {
            logger.error("Studio scene unavailable: texture creation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private init(photoTexture: TextureResource,
                 reflectionTexture: TextureResource,
                 shadowTexture: TextureResource,
                 aspect: Float,
                 reduceMotion: Bool) {
        self.autoRotate = !reduceMotion

        let height = cardHeight
        let width = height * max(aspect, 0.2)
        let halfHeight = height / 2

        // Card body: a thin rounded slab so the object keeps depth when rotated edge-on.
        let slabDepth: Float = 0.03
        let slabMesh = MeshResource.generateBox(size: [width + 0.03, height + 0.03, slabDepth],
                                                cornerRadius: 0.02)
        let slab = ModelEntity(mesh: slabMesh,
                               materials: [Self.solidMaterial(tint: UIColor(white: 0.14, alpha: 1),
                                                              roughness: 0.55, metallic: 0.0)])

        // Front label plane textured with the photo (slightly proud of the slab face).
        let faceMesh = MeshResource.generatePlane(width: width, height: height, cornerRadius: 0.015)
        let face = ModelEntity(mesh: faceMesh, materials: [Self.photoMaterial(texture: photoTexture)])
        face.position = [0, 0, slabDepth / 2 + 0.001]

        let card = Entity()
        card.addChild(slab)
        card.addChild(face)

        // Gradient-faded mirror reflection, hanging below the floor line, rotating with the card.
        let reflectionMesh = MeshResource.generatePlane(width: width, height: height, cornerRadius: 0.015)
        let reflection = ModelEntity(mesh: reflectionMesh,
                                     materials: [Self.reflectionMaterial(texture: reflectionTexture)])
        reflection.position = [0, -height, slabDepth / 2 + 0.001]

        turntable.addChild(card)
        turntable.addChild(reflection)

        // Reflective studio floor (dark, low roughness for a crisp sheen) — static beneath everything.
        let floorMesh = MeshResource.generatePlane(width: 3, depth: 3)
        let floor = ModelEntity(mesh: floorMesh,
                                materials: [Self.solidMaterial(tint: UIColor(red: 0x1C / 255,
                                                                             green: 0x1C / 255,
                                                                             blue: 0x1C / 255, alpha: 1),
                                                               roughness: 0.16, metallic: 0.0)])
        floor.position = [0, -halfHeight, 0]

        // Soft contact shadow blob directly under the card.
        let shadowMesh = MeshResource.generatePlane(width: width * 1.35, depth: 0.22)
        let shadow = ModelEntity(mesh: shadowMesh,
                                 materials: [Self.shadowMaterial(texture: shadowTexture)])
        shadow.position = [0, -halfHeight + 0.002, 0]

        // Lighting rig: a brighter key for a punchier read, a soft fill to open the shadows, and a
        // pair of rims from behind either side to catch the glossy card + slab edges.
        let key = Self.directionalLight(intensity: 4400, from: [0.7, 0.9, 1.1])
        let fill = Self.directionalLight(intensity: 1000, from: [-0.9, 0.35, 0.8])
        let rimLeft = Self.directionalLight(intensity: 1300, from: [-0.9, 0.5, -1.1])
        let rimRight = Self.directionalLight(intensity: 1300, from: [0.9, 0.5, -1.1])

        camera.camera.fieldOfViewInDegrees = 38

        // Frame the whole card with margin. The 38° FOV is vertical, so on a tall portrait screen the
        // horizontal view is the tight one — pull back enough for the card's width, and pull back
        // further for wide (landscape) photos so they never crop.
        let fit = max(1, max(aspect, 0.2))
        distance = 3.0 * fit
        defaultDistance = distance

        root.addChild(turntable)
        root.addChild(floor)
        root.addChild(shadow)
        root.addChild(key)
        root.addChild(fill)
        root.addChild(rimLeft)
        root.addChild(rimRight)
        root.addChild(camera)

        applyCamera()
    }

    // MARK: - Per-frame

    /// Gentle idle sway of the camera around the card, until the user takes over. No-op while the
    /// user interacts, after they've interacted once, or when reduce-motion is on.
    func tick(deltaTime: TimeInterval) {
        guard autoRotate, !hasInteracted, !isDragging, !isZooming else { return }
        autoPhase += Float(deltaTime) * 0.5
        azimuth = -0.32 + 0.20 * sin(autoPhase)
        applyCamera()
    }

    // MARK: - Gestures

    func beginDrag() {
        isDragging = true
        hasInteracted = true
        azimuthAtDragStart = azimuth
        elevationAtDragStart = elevation
    }

    func updateDrag(translation: CGSize) {
        azimuth = Self.clamp(azimuthAtDragStart + Float(translation.width) * 0.006,
                             lower: -azimuthLimit, upper: azimuthLimit)
        elevation = Self.clamp(elevationAtDragStart - Float(translation.height) * 0.006,
                               lower: 0.02, upper: 0.75)
        applyCamera()
    }

    func endDrag() {
        isDragging = false
    }

    func beginZoom() {
        isZooming = true
        distanceAtZoomStart = distance
    }

    func updateZoom(scale: CGFloat) {
        let factor = Float(max(scale, 0.05))
        distance = Self.clamp(distanceAtZoomStart / factor,
                              lower: defaultDistance * 0.5, upper: defaultDistance * 1.8)
        applyCamera()
    }

    func endZoom() {
        isZooming = false
    }

    // MARK: - Transforms

    private func applyCamera() {
        // Orbit the camera on a sphere around the card centre; the card itself never rotates.
        let horizontal = distance * cos(elevation)
        let position = SIMD3<Float>(horizontal * sin(azimuth),
                                    distance * sin(elevation),
                                    horizontal * cos(azimuth))
        camera.look(at: [0, 0, 0], from: position, upVector: [0, 1, 0], relativeTo: nil)
    }

    // MARK: - Materials

    private static func photoMaterial(texture: TextureResource) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(texture))
        // A touch of self-illumination guarantees the photo stays readable regardless of the rig.
        material.emissiveColor = .init(color: .white, texture: .init(texture))
        material.emissiveIntensity = 0.14
        material.roughness = 0.42
        material.metallic = 0.0
        return material
    }

    private static func solidMaterial(tint: UIColor, roughness: Float, metallic: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: tint)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: metallic)
        return material
    }

    private static func reflectionMaterial(texture: TextureResource) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(texture))
        material.emissiveColor = .init(color: .white, texture: .init(texture))
        material.emissiveIntensity = 1.0
        material.roughness = 1.0
        material.metallic = 0.0
        // Baked alpha (mirror flip + vertical fade) drives the transparency.
        material.blending = .transparent(opacity: 1.0)
        return material
    }

    private static func shadowMaterial(texture: TextureResource) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .black, texture: .init(texture))
        material.roughness = 1.0
        material.metallic = 0.0
        material.blending = .transparent(opacity: 1.0)
        return material
    }

    private static func directionalLight(intensity: Float, from position: SIMD3<Float>) -> Entity {
        let entity = Entity()
        entity.components.set(DirectionalLightComponent(color: .white, intensity: intensity))
        entity.look(at: [0, 0, 0], from: position, upVector: [0, 1, 0], relativeTo: nil)
        return entity
    }

    // MARK: - Texture synthesis (Core Graphics)

    /// Orientation-normalised, top-left-origin `CGImage` (handles EXIF rotation).
    private static func normalizedCGImage(from image: UIImage) -> CGImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }

    /// Vertically-mirrored copy of the photo with a top-to-bottom alpha fade, for the floor reflection.
    private static func reflectionCGImage(from base: CGImage) -> CGImage? {
        let size = CGSize(width: base.width, height: base.height)
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            let cg = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            // Drawing a CGImage via Core Graphics inside the flipped UIKit context yields the mirror.
            cg.draw(base, in: rect)
            cg.setBlendMode(.destinationIn)
            let colors = [UIColor(white: 1, alpha: 0.5).cgColor,
                          UIColor(white: 1, alpha: 0.0).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient,
                                      start: CGPoint(x: 0, y: 0),
                                      end: CGPoint(x: 0, y: size.height),
                                      options: [])
            }
        }
        return rendered.cgImage
    }

    /// Soft radial blob for the contact shadow.
    private static func contactShadowCGImage() -> CGImage? {
        let side: CGFloat = 256
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { context in
            let cg = context.cgContext
            let colors = [UIColor(white: 0, alpha: 0.55).cgColor,
                          UIColor(white: 0, alpha: 0.0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colors, locations: [0, 1]) else { return }
            let centre = CGPoint(x: side / 2, y: side / 2)
            cg.drawRadialGradient(gradient,
                                  startCenter: centre, startRadius: 0,
                                  endCenter: centre, endRadius: side / 2,
                                  options: [])
        }
        return rendered.cgImage
    }

    // MARK: - Helpers

    private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
