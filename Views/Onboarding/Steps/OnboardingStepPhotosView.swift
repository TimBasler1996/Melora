import SwiftUI
import PhotosUI
import UIKit

struct OnboardingStepPhotosView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var photo2PickerItem: PhotosPickerItem?
    @State private var photo3PickerItem: PhotosPickerItem?
    @State private var pendingAvatar: PendingAvatar?
    @State private var originalHeroImage: UIImage? // Store uncropped version

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
            .overlay(alignment: .leading) {
                PhotosPicker(selection: $profilePickerItem, matching: .images, photoLibrary: .shared()) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 64, height: 64)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 14)
                .accessibilityLabel(Text("Add profile photo"))
            }

            VStack(spacing: 16) {
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
        .sheet(item: $pendingAvatar) { pending in
            AvatarCropperView(
                image: pending.image,
                onCancel: {
                    pendingAvatar = nil
                },
                onUse: { cropped in
                    Task { @MainActor in
                        // Store both versions: cropped for avatars, original for hero
                        setImage(cropped, at: 0)
                        originalHeroImage = pending.image // Keep original
                        pendingAvatar = nil
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: profilePickerItem) { newItem in
            guard let newItem else { return }
            loadImage(from: newItem) { image in
                guard let image else { return }
                pendingAvatar = PendingAvatar(image: image)
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
        .onDisappear {
            // Store the original hero image in the ViewModel when leaving this screen
            if let originalHeroImage {
                viewModel.originalHeroImage = originalHeroImage
            }
        }
    }

    private func setImage(_ image: UIImage?, at index: Int) {
        guard viewModel.selectedImages.indices.contains(index) else { return }
        viewModel.selectedImages[index] = image
    }

    private func loadImage(from item: PhotosPickerItem, completion: @escaping (UIImage?) -> Void) {
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let image = data.flatMap { UIImage(data: $0) }
            await MainActor.run {
                completion(image)
                if image != nil {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }

}

private struct PendingAvatar: Identifiable {
    let id = UUID()
    let image: UIImage
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
