import SwiftUI
import PhotosUI
import UIKit

struct ProfilePhotosStepView: View {

    @ObservedObject var vm: ProfileSetupWizardViewModel

    @State private var pickerSlotIndex: Int = 0
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Step 2/3 — Photos")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))

            card {
                VStack(alignment: .leading, spacing: 10) {

                    Text("Add at least 2 photos")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)

                    Text("This is what others will see when you broadcast nearby.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.gray)

                    HStack(spacing: 12) {
                        photoSlot(index: 0)
                        photoSlot(index: 1)
                        photoSlot(index: 2)
                    }
                    .padding(.top, 6)

                    Text("Selected: \(vm.selectedImages.compactMap { $0 }.count)/3 (min. 2)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
            }

            if let err = vm.errorMessage, !err.isEmpty {
                Text(err)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
            }

            if !vm.canContinuePhotos {
                Text("Pick at least 2 photos to continue.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }

            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        vm.pickPhoto(at: pickerSlotIndex, image: uiImage)
                        vm.errorMessage = nil
                    } else {
                        vm.errorMessage = "Could not load the selected image."
                    }
                } catch {
                    vm.errorMessage = "Could not load the selected image."
                }

                selectedItem = nil
            }
        }
    }

    // MARK: - UI

    private func photoSlot(index: Int) -> some View {
        let image = vm.selectedImages.indices.contains(index) ? vm.selectedImages[index] : nil
        let slotNumber = index + 1

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.25))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 98, height: 120)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Photo \(slotNumber)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Remove button (only when filled)
            if image != nil {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            vm.removePhoto(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 3)
                        }
                        .padding(6)
                    }
                    Spacer()
                }
            }

            // Picker overlay to add/replace
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Color.clear
            }
            .contentShape(Rectangle())
            .onTapGesture {
                pickerSlotIndex = index
            }
        }
        .frame(width: 98, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .buttonStyle(.plain)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
    }
}

