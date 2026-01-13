import SwiftUI
import PhotosUI
import UIKit

struct PhotoCard: View {
    let title: String
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack(alignment: .bottomLeading) {
                GeometryReader { geo in
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.black.opacity(0.35), .clear],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(AppColors.secondaryText)

                            Text("Add photo")
                                .font(AppFonts.footnote())
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }

                if image != nil {
                    Text("Change photo")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
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
