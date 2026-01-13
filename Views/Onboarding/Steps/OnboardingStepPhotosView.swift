import SwiftUI
import PhotosUI
import UIKit

struct OnboardingStepPhotosView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var photo2PickerItem: PhotosPickerItem?
    @State private var photo3PickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add photos")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("Your photos shape your profile preview.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            ProfilePreviewHeader(
                firstName: viewModel.firstName,
                city: viewModel.city,
                birthday: viewModel.birthday,
                gender: viewModel.gender,
                avatarImage: viewModel.selectedImages[safe: 0] ?? nil
            )

            PhotoGridView(
                profileImage: viewModel.selectedImages[safe: 0] ?? nil,
                photo2Image: viewModel.selectedImages[safe: 1] ?? nil,
                photo3Image: viewModel.selectedImages[safe: 2] ?? nil,
                profilePickerItem: $profilePickerItem,
                photo2PickerItem: $photo2PickerItem,
                photo3PickerItem: $photo3PickerItem,
                onImageLoaded: setImage
            )

            guidanceSection
        }
    }

    private func setImage(_ image: UIImage?, at index: Int) {
        guard viewModel.selectedImages.indices.contains(index) else { return }
        viewModel.selectedImages[index] = image
    }

    private var guidanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Photo 1 should clearly show your face.")
            Text("Avoid group photos as your first picture.")
            Text("Good lighting works best.")
        }
        .font(AppFonts.footnote())
        .foregroundColor(AppColors.secondaryText)
        .padding(.top, 4)
    }
}

// MARK: - Safe index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    OnboardingStepPhotosView(viewModel: OnboardingViewModel())
        .padding()
}
