import SwiftUI
import PhotosUI
import UIKit

struct OnboardingStepPhotosView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var photo2PickerItem: PhotosPickerItem?
    @State private var photo3PickerItem: PhotosPickerItem?
    @State private var pendingAvatarImage: UIImage?
    @State private var isCroppingAvatar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add photos")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("Build your profile look.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            ProfilePreviewHeader(
                firstName: viewModel.firstName,
                city: viewModel.city,
                birthday: viewModel.birthday,
                gender: viewModel.gender,
                avatarImage: viewModel.selectedImages[safe: 0] ?? nil
            )

            VStack(spacing: 14) {
                AvatarPhotoCard(
                    image: viewModel.selectedImages[safe: 0] ?? nil,
                    helperText: "This is your avatar everywhere.",
                    pickerItem: $profilePickerItem
                )

                PhotoCard(
                    title: "Photo 2",
                    image: viewModel.selectedImages[safe: 1] ?? nil,
                    pickerItem: $photo2PickerItem
                )

                PhotoCard(
                    title: "Photo 3",
                    image: viewModel.selectedImages[safe: 2] ?? nil,
                    pickerItem: $photo3PickerItem
                )
            }
        }
        .sheet(isPresented: $isCroppingAvatar) {
            if let pendingAvatarImage {
                AvatarCropperView(
                    image: pendingAvatarImage,
                    onCancel: {
                        isCroppingAvatar = false
                        self.pendingAvatarImage = nil
                    },
                    onUse: { cropped in
                        setImage(cropped, at: 0)
                        isCroppingAvatar = false
                        self.pendingAvatarImage = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: profilePickerItem) { newItem in
            guard let newItem else { return }
            loadImage(from: newItem) { image in
                guard let image else { return }
                pendingAvatarImage = image
                isCroppingAvatar = true
            }
        }
        .onChange(of: photo2PickerItem) { newItem in
            guard let newItem else { return }
            loadImage(from: newItem) { image in
                setImage(image, at: 1)
            }
        }
        .onChange(of: photo3PickerItem) { newItem in
            guard let newItem else { return }
            loadImage(from: newItem) { image in
                setImage(image, at: 2)
            }
        }
    }

    private func setImage(_ image: UIImage?, at index: Int) {
        guard viewModel.selectedImages.indices.contains(index) else { return }
        viewModel.selectedImages[index] = image
    }

    private func loadImage(from item: PhotosPickerItem, completion: @escaping (UIImage?) -> Void) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let image = data.flatMap { UIImage(data: $0) }
            await MainActor.run {
                completion(image)
                if image != nil {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
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
