import SwiftUI
import UIKit

/// Album covers tint the room: one average color per artwork URL, computed
/// once and kept for the session so a Discover list doesn't re-download.
actor ArtworkColorCache {

    static let shared = ArtworkColorCache()

    private var colors: [URL: Color] = [:]
    private var inFlight: [URL: Task<Color?, Never>] = [:]

    func color(for url: URL) async -> Color? {
        if let cached = colors[url] { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task<Color?, Never> {
            // A 128 px decode is plenty for an average color and shares the
            // download with the card's artwork.
            guard let image = await RemoteImageLoader.load(url, pixelSize: 128),
                  let uiColor = await image.dominantColor() else { return nil }
            return Color(uiColor)
        }
        inFlight[url] = task
        let result = await task.value
        inFlight[url] = nil
        if let result { colors[url] = result }
        return result
    }
}
