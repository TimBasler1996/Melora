import SwiftUI
import UIKit

struct AvatarCropperView: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUse: (UIImage) -> Void

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var previewCropSize: CGSize = .zero

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("Crop Avatar")
                    .font(AppFonts.sectionTitle())
                    .foregroundColor(AppColors.primaryText)

                Text("Move and scale")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding(.top, 4)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height)
                let cropSize = CGSize(width: size, height: size)

                ZStack {
                    Color.black.opacity(0.12)

                    avatarImageView(in: cropSize)
                        .frame(width: cropSize.width, height: cropSize.height)
                        .clipped()

                    cropOverlay()
                        .frame(width: cropSize.width, height: cropSize.height)
                        .allowsHitTesting(false)

                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .frame(width: cropSize.width, height: cropSize.height)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .gesture(dragGesture(in: cropSize))
                .gesture(magnificationGesture(in: cropSize))
                .onAppear {
                    previewCropSize = cropSize
                }
                .onChange(of: geo.size) { _, _ in
                    previewCropSize = cropSize
                }
            }
            .frame(height: 300)
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                                .fill(AppColors.tintedBackground)
                        )
                }

                Button {
                    let cropped = cropImage(cropSize: previewCropSize)
                    onUse(cropped)
                } label: {
                    Text("Use Photo")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 20)
    }

    private func cropOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.55)
            Circle()
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func avatarImageView(in cropSize: CGSize) -> some View {
        let baseScale = max(cropSize.width / image.size.width, cropSize.height / image.size.height)
        let effectiveScale = baseScale * scale
        let scaledSize = CGSize(width: image.size.width * effectiveScale, height: image.size.height * effectiveScale)
        let clampedOffset = clampOffset(offset, for: scaledSize, in: cropSize)

        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: scaledSize.width, height: scaledSize.height)
            .offset(clampedOffset)
    }

    private func dragGesture(in cropSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                offset = clampOffset(offset, for: scaledSize(in: cropSize), in: cropSize)
                lastOffset = offset
            }
    }

    private func magnificationGesture(in cropSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(1, lastScale * value)
            }
            .onEnded { _ in
                scale = max(1, scale)
                lastScale = scale
                offset = clampOffset(offset, for: scaledSize(in: cropSize), in: cropSize)
                lastOffset = offset
            }
    }

    private func scaledSize(in cropSize: CGSize) -> CGSize {
        let baseScale = max(cropSize.width / image.size.width, cropSize.height / image.size.height)
        let effectiveScale = baseScale * scale
        return CGSize(width: image.size.width * effectiveScale, height: image.size.height * effectiveScale)
    }

    private func clampOffset(_ offset: CGSize, for imageSize: CGSize, in cropSize: CGSize) -> CGSize {
        let maxX = max((imageSize.width - cropSize.width) / 2, 0)
        let maxY = max((imageSize.height - cropSize.height) / 2, 0)

        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    private func cropImage(cropSize: CGSize) -> UIImage {
        let cropSize = cropSize == .zero ? CGSize(width: 280, height: 280) : cropSize
        let baseScale = max(cropSize.width / image.size.width, cropSize.height / image.size.height)
        let effectiveScale = baseScale * scale
        let scaledSize = CGSize(width: image.size.width * effectiveScale, height: image.size.height * effectiveScale)
        let clampedOffset = clampOffset(offset, for: scaledSize, in: cropSize)
        let center = CGPoint(x: cropSize.width / 2 + clampedOffset.width, y: cropSize.height / 2 + clampedOffset.height)
        let drawOrigin = CGPoint(x: center.x - scaledSize.width / 2, y: center.y - scaledSize.height / 2)
        let drawRect = CGRect(origin: drawOrigin, size: scaledSize)

        let renderer = UIGraphicsImageRenderer(size: cropSize)
        return renderer.image { context in
            let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: cropSize))
            circlePath.addClip()
            image.draw(in: drawRect)
        }
    }
}

#Preview {
    AvatarCropperView(
        image: UIImage(systemName: "person.circle.fill") ?? UIImage(),
        onCancel: {},
        onUse: { _ in }
    )
    .padding()
    .background(AppColors.cardBackground)
}
