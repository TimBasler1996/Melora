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
                    imageData: viewModel.profilePhotoData,
                    item: $profilePickerItem,
                    height: 200
                ) { data in
                    viewModel.profilePhotoData = data
                }

                HStack(spacing: 12) {
                    photoSlot(
                        title: "Photo 2",
                        imageData: viewModel.photo2Data,
                        item: $photo2PickerItem,
                        height: 140
                    ) { data in
                        viewModel.photo2Data = data
                    }

                    photoSlot(
                        title: "Photo 3",
                        imageData: viewModel.photo3Data,
                        item: $photo3PickerItem,
                        height: 140
                    ) { data in
                        viewModel.photo3Data = data
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func photoSlot(
        title: String,
        imageData: Data?,
        item: Binding<PhotosPickerItem?>,
        height: CGFloat,
        onDataLoaded: @escaping (Data?) -> Void
    ) -> some View {
        PhotosPicker(selection: item, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let imageData, let image = UIImage(data: imageData) {
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
                onDataLoaded(nil)
                return
            }

            Task {
                let data = try? await newItem.loadTransferable(type: Data.self)
                await MainActor.run {
                    onDataLoaded(data)
                    if data != nil {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
                }
            }
        }
    }
}

#Preview {
    OnboardingStepPhotosView(viewModel: OnboardingViewModel())
        .padding()
}
