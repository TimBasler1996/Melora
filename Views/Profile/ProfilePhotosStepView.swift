import SwiftUI
import PhotosUI

struct ProfilePhotosStepView: View {

    @ObservedObject var vm: ProfileSetupWizardViewModel

    @State private var pickerSlot: Int = 1
    @State private var selectedItem: PhotosPickerItem? = nil

    var body: some View {
        VStack(spacing: 14) {

            Text("Set up your profile")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Step 2/3 — Photos")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            card

            if let err = vm.errorMessage {
                Text(err)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await vm.saveStep2UploadPhotos() }
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    }
                    Text("Continue")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(vm.canContinuePhotos ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
                )
                .foregroundColor(.white)
            }
            .disabled(!vm.canContinuePhotos)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .photosPicker(
            isPresented: Binding(
                get: { false },
                set: { _ in }
            ),
            selection: $selectedItem
        )
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    vm.pickPhoto(uiImage, slot: pickerSlot)
                } else {
                    vm.errorMessage = "Could not load the selected image."
                }
                selectedItem = nil
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Add at least 2 photos")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.black)

            Text("This is what others will see when you broadcast nearby.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                photoSlot(slot: 1, image: vm.photo1)
                photoSlot(slot: 2, image: vm.photo2)
                photoSlot(slot: 3, image: vm.photo3)
            }
            .padding(.top, 6)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
    }

    private func photoSlot(slot: Int, image: UIImage?) -> some View {
        Button {
            if image != nil {
                vm.removePhoto(slot: slot)
            } else {
                pickerSlot = slot
                // We trigger the PhotosPicker by binding it to selection via a simple trick:
                // set selectedItem to nil and present picker using PhotosPicker in a sheet-like way.
                // In iOS 16+ easiest is to use PhotosPicker as the label itself:
                // We'll do that inline below with a PhotosPicker.
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.25))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
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
                        Text("Photo \(slot)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: 98, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            // ✅ Real PhotosPicker overlay (tap when empty)
            Group {
                if image == nil {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Color.clear
                    }
                    .onTapGesture {
                        pickerSlot = slot
                    }
                }
            }
        )
        .buttonStyle(.plain)
    }
}

