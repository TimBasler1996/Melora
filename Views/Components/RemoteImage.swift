import SwiftUI
import UIKit
import ImageIO

// MARK: - Loader

/// Loads remote images once, decoded small, and keeps them in memory.
///
/// Why not `AsyncImage`: it decodes the full-size photo (a 1600 px profile
/// picture for a 44 pt avatar) on every appearance, never shares a download
/// between two views, and flashes the placeholder each time a row scrolls
/// back in. This loader
/// - downsamples with ImageIO to the pixel size actually displayed,
/// - keeps decoded images in an `NSCache` (a memory hit renders on the
///   first frame, no placeholder),
/// - de-duplicates in-flight requests per URL and size,
/// - reads and writes `URLCache.shared`, so bytes stay on disk between launches.
enum RemoteImageLoader {

    // NSCache is thread-safe; the compiler can't see that.
    nonisolated(unsafe) private static let memory: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache.shared
        config.httpMaximumConnectionsPerHost = 6
        return URLSession(configuration: config)
    }()

    /// One task per (url, size) so a list of identical avatars downloads once.
    private static let inFlight = InFlight()

    private actor InFlight {
        private var tasks: [String: Task<UIImage?, Never>] = [:]

        func run(_ key: String, _ make: @escaping @Sendable () async -> UIImage?) async -> UIImage? {
            if let existing = tasks[key] { return await existing.value }
            let task = Task { await make() }
            tasks[key] = task
            let value = await task.value
            tasks[key] = nil
            return value
        }
    }

    /// Longest edge in pixels the image is decoded to. Sizes are bucketed
    /// so a 50 pt and a 56 pt avatar share one decode.
    @MainActor
    static func pixelSize(forPoints points: CGFloat) -> Int {
        guard points > 0 else { return 0 }
        let scale = UITraitCollection.current.displayScale
        let px = Int((points * scale).rounded(.up))
        return ((px + 127) / 128) * 128
    }

    private static func key(_ url: URL, _ px: Int) -> NSString {
        "\(px)|\(url.absoluteString)" as NSString
    }

    /// Synchronous memory hit, for the first render.
    static func cached(_ url: URL, pixelSize px: Int) -> UIImage? {
        memory.object(forKey: key(url, px))
    }

    static func load(_ url: URL, pixelSize px: Int) async -> UIImage? {
        if let hit = cached(url, pixelSize: px) { return hit }
        return await inFlight.run("\(px)|\(url.absoluteString)") {
            guard let data = await fetch(url) else { return nil }
            guard let image = decode(data, maxPixelSize: px) else { return nil }
            memory.setObject(image, forKey: key(url, px), cost: byteCost(image))
            return image
        }
    }

    private static func fetch(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
        return data
    }

    /// ImageIO thumbnail decode: never inflates the full bitmap, runs on the
    /// calling (background) task.
    private static func decode(_ data: Data, maxPixelSize px: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return UIImage(data: data)
        }
        var options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        if px > 0 { options[kCGImageSourceThumbnailMaxPixelSize] = px }
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cg)
    }

    private static func byteCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}

// MARK: - View

enum RemoteImagePhase {
    case empty
    case success(Image)
    case failure
}

/// Drop-in for `AsyncImage(url:) { phase in }` with a display size, so the
/// image is decoded at that size and stays cached in memory.
struct RemoteImage<Content: View>: View {

    private let url: URL?
    private let pixelSize: Int
    private let content: (RemoteImagePhase) -> Content

    @State private var phase: RemoteImagePhase

    /// - Parameters:
    ///   - url: Remote image; nil renders `.failure`.
    ///   - size: Longest edge on screen, in points. 0 = decode full size.
    init(url: URL?, size: CGFloat, @ViewBuilder content: @escaping (RemoteImagePhase) -> Content) {
        self.url = url
        self.pixelSize = RemoteImageLoader.pixelSize(forPoints: size)
        self.content = content
        if let url, let hit = RemoteImageLoader.cached(url, pixelSize: pixelSize) {
            _phase = State(initialValue: .success(Image(uiImage: hit)))
        } else {
            _phase = State(initialValue: url == nil ? .failure : .empty)
        }
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                guard let url else {
                    phase = .failure
                    return
                }
                if let hit = RemoteImageLoader.cached(url, pixelSize: pixelSize) {
                    phase = .success(Image(uiImage: hit))
                    return
                }
                phase = .empty
                let image = await RemoteImageLoader.load(url, pixelSize: pixelSize)
                guard !Task.isCancelled else { return }
                if let image {
                    phase = .success(Image(uiImage: image))
                } else {
                    phase = .failure
                }
            }
    }
}
