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
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data),
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
