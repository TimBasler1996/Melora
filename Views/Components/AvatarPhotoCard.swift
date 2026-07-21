import SwiftUI
import PhotosUI
import UIKit

struct AvatarPhotoCard: View {
    let image: UIImage?
    let helperText: String
    @Binding var pickerItem: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            HStack(spacing: 16) {
                avatarView

                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile photo")
                        .font(AppFonts.sectionTitle())
                        .foregroundColor(AppColors.primaryText)

                    Text(helperText)
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)

                    Text(image == nil ? "Choose profile photo" : "Change photo")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primary)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
        }
    }

    private var avatarView: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)

                Image(systemName: "person.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .overlay(
            Circle()
                .stroke(AppColors.stroke, lineWidth: 1)
        )
    }
}

#Preview {
    AvatarPhotoCard(
        image: nil,
        helperText: "This is your avatar everywhere.",
        pickerItem: .constant(nil)
    )
    .padding()
    .background(AppColors.cardBackground)
}
