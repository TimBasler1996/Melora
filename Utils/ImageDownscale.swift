import UIKit

extension UIImage {

    /// Longest edge used for profile photos. Plenty for a 3:4 tile on any
    /// iPhone and roughly 10× smaller than a raw camera-roll photo.
    static let profilePhotoMaxDimension: CGFloat = 1600

    /// Returns a copy scaled so its longest edge is at most `maxDimension`
    /// points, or `self` when it is already small enough. Also normalises
    /// orientation, so the result is safe to upload as-is.
    func downscaled(maxDimension: CGFloat = UIImage.profilePhotoMaxDimension) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return self }

        let ratio = maxDimension / longest
        let target = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
