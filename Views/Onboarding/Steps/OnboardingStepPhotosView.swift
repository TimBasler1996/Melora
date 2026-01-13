import SwiftUI
import PhotosUI
import UIKit

struct OnboardingStepPhotosView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var profilePickerItem: PhotosPickerItem?
    @State private var photo2PickerItem: PhotosPickerItem?
    @State private var photo3PickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add photos")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("Pick 3 photos — your first one is your profile picture")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            VStack(spacing: 12) {
                photoSlot(
                    title: "Profile photo",
                    image: viewModel.selectedImages[safe: 0] ?? nil,
                    item: $profilePickerItem,
                    height: 200
                ) { image in
                    setImage(image, at: 0)
                }

                HStack(spacing: 12) {
                    photoSlot(
                        title: "Photo 2",
                        image: viewModel.selectedImages[safe: 1] ?? nil,
                        item: $photo2PickerItem,
                        height: 140
                    ) { image in
                        setImage(image, at: 1)
                    }

                    photoSlot(
                        title: "Photo 3",
                        image: viewModel.selectedImages[safe: 2] ?? nil,
                        item: $photo3PickerItem,
                        height: 140
                    ) { image in
                        setImage(image, at: 2)
                    }
                }
            }
        }
    }

    private func setImage(_ image: UIImage?, at index: Int) {
        guard viewModel.selectedImages.indices.contains(index) else { return }
        viewModel.selectedImages[index] = image
    }

    @ViewBuilder
    private func photoSlot(
        title: String,
        image: UIImage?,
        item: Binding<PhotosPickerItem?>,
        height: CGFloat,
        onImageLoaded: @escaping (UIImage?) -> Void
    ) -> some View {
        PhotosPicker(selection: item, matching: .images, photoLibrary: .shared()) {
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
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .accessibilityLabel(Text(title))
        .onChange(of: item.wrappedValue) { newItem in
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

