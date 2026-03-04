import SwiftUI
import PhotosUI
import UIKit

struct PhotoGridView: View {
    let profileImage: UIImage?
    let photo2Image: UIImage?
    let photo3Image: UIImage?

    @Binding var profilePickerItem: PhotosPickerItem?
    @Binding var photo2PickerItem: PhotosPickerItem?
    @Binding var photo3PickerItem: PhotosPickerItem?

    let onImageLoaded: (UIImage?, Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            PhotoSlotView(
                title: "Profile photo",
                badgeText: "1",
                image: profileImage,
                pickerItem: $profilePickerItem,
                isPrimary: true
            ) { image in
                onImageLoaded(image, 0)
            }

            HStack(spacing: 12) {
                PhotoSlotView(
                    title: "Photo 2",
                    badgeText: "2",
                    image: photo2Image,
                    pickerItem: $photo2PickerItem,
                    isPrimary: false
                ) { image in
                    onImageLoaded(image, 1)
                }

                PhotoSlotView(
                    title: "Photo 3",
                    badgeText: "3",
                    image: photo3Image,
                    pickerItem: $photo3PickerItem,
                    isPrimary: false
                ) { image in
                    onImageLoaded(image, 2)
                }
            }
        }
    }
}

struct PhotoSlotView: View {
    let title: String
    let badgeText: String
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?
    let isPrimary: Bool
    let onImageLoaded: (UIImage?) -> Void

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(AppColors.secondaryText)

                        Text("Add photo")
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.secondaryText)
                    }
                }

                badgeView
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(isPrimary ? 0.25 : 0.16), lineWidth: 1)
            )
        }
        .accessibilityLabel(Text(title))
        .onChange(of: pickerItem) { newItem in
            guard let newItem else {
                onImageLoaded(nil)
                return
            }

            Task {
                let data = try? await newItem.loadTransferable(type: Data.self)
                let image = data.flatMap { UIImage(data: $0) }

                await MainActor.run {
                    onImageLoaded(image)
                    if image != nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
    }

    private var badgeView: some View {
        Text(badgeText)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.4))
            )
            .padding(10)
    }
}

#Preview {
    PhotoGridView(
        profileImage: nil,
        photo2Image: nil,
        photo3Image: nil,
        profilePickerItem: .constant(nil),
        photo2PickerItem: .constant(nil),
        photo3PickerItem: .constant(nil)
    ) { _, _ in }
    .padding()
    .background(AppColors.cardBackground)
}
