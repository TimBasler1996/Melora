import SwiftUI
import PhotosUI
import UIKit

struct PhotoCard: View {
    let title: String
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            VStack(spacing: 12) {
                ZStack {
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
                }
                .aspectRatio(3 / 4, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(AppColors.tintedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )

                Text(image == nil ? "Add photo" : "Change photo")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
        }
        .accessibilityLabel(Text(title))
    }
}

#Preview {
    PhotoCard(
        title: "Photo 2",
        image: nil,
        pickerItem: .constant(nil)
    )
    .padding()
    .background(AppColors.cardBackground)
}
