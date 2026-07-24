import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Persists car photos to the app's Documents directory and vends thumbnails.
///
/// Frozen contract. SwiftData stores only the returned relative filenames, never image blobs
/// (spec §3). Full images live at `Documents/photos/<uuid>.heic`; thumbnails at
/// `Documents/photos/thumbs/<uuid>.jpg`, 400px longest edge (spec §9).
protocol PhotoStore: Sendable {
    /// Saves a full-resolution HEIC plus a 400px thumbnail. Returns the relative filename
    /// (e.g. `"<uuid>.heic"`) to store in ``Car/photoFilenames``.
    func save(_ image: UIImage) throws -> String

    /// Loads the full-resolution image for a relative filename, or `nil` if missing.
    func fullImage(for filename: String) -> UIImage?

    /// Loads the thumbnail for a relative filename, or `nil` if missing.
    func thumbnail(for filename: String) -> UIImage?

    /// Deletes the full image and its thumbnail. No-op if already gone.
    func delete(_ filename: String) throws

    /// Total bytes used by stored photos and thumbnails (for the Settings readout).
    func totalBytes() -> Int64
}

/// Default `PhotoStore` backed by the Documents directory.
///
/// Phase-A scaffold: directory layout and paths are final; the AddCar agent fills in HEIC encoding
/// and thumbnail generation. Kept deliberately small so it can be understood at a glance.
struct DocumentsPhotoStore: PhotoStore {
    static let shared = DocumentsPhotoStore()

    /// `Documents/photos/`
    var photosDirectory: URL {
        Self.documents.appendingPathComponent("photos", isDirectory: true)
    }

    /// `Documents/photos/thumbs/`
    var thumbsDirectory: URL {
        photosDirectory.appendingPathComponent("thumbs", isDirectory: true)
    }

    private static var documents: URL {
        // Documents always exists for an app sandbox; fall back to a temp dir only in the
        // impossible case, so we never force-unwrap (spec §9).
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    func save(_ image: UIImage) throws -> String {
        let filename = "\(UUID().uuidString).heic"
        // Creating the thumbs directory also creates its `photos` parent.
        try FileManager.default.createDirectory(at: thumbsDirectory, withIntermediateDirectories: true)

        // Bake in the capture orientation so the on-disk pixels stand upright.
        let upright = Self.normalizedUp(image)

        guard let cgImage = upright.cgImage, let heic = Self.heicData(from: cgImage) else {
            throw PhotoStoreError.encodingFailed
        }
        try heic.write(to: photosDirectory.appendingPathComponent(filename), options: .atomic)

        let thumb = Self.thumbnail(from: upright, maxEdge: 400)
        guard let jpeg = thumb.jpegData(compressionQuality: 0.8) else {
            throw PhotoStoreError.encodingFailed
        }
        try jpeg.write(to: thumbURL(for: filename), options: .atomic)

        return filename
    }

    func fullImage(for filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func thumbnail(for filename: String) -> UIImage? {
        let url = thumbURL(for: filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func delete(_ filename: String) throws {
        let fileManager = FileManager.default
        let full = photosDirectory.appendingPathComponent(filename)
        if fileManager.fileExists(atPath: full.path) { try fileManager.removeItem(at: full) }
        let thumb = thumbURL(for: filename)
        if fileManager.fileExists(atPath: thumb.path) { try fileManager.removeItem(at: thumb) }
    }

    func totalBytes() -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: photosDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            if values?.isRegularFile == true, let size = values?.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    /// `Documents/photos/thumbs/<uuid>.jpg` for a given full-image filename.
    private func thumbURL(for filename: String) -> URL {
        let base = (filename as NSString).deletingPathExtension
        return thumbsDirectory.appendingPathComponent("\(base).jpg")
    }

    /// Redraws the image so its pixels are upright (`.up`). Camera captures otherwise carry an
    /// orientation flag that `cgImage` and raw HEIC encoding ignore.
    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }

    /// Scales `image` so its longest edge is at most `maxEdge` points (400px thumbnails, spec §9).
    private static func thumbnail(from image: UIImage, maxEdge: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge, longest > 0 else { return image }
        let scale = maxEdge / longest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    /// Encodes a `CGImage` as lossy HEIC data, or `nil` if the codec is unavailable.
    private static func heicData(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.heic.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination, cgImage,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

enum PhotoStoreError: Error {
    case notImplemented
    case encodingFailed
}
