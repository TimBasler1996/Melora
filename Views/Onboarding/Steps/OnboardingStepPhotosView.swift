import SwiftUI
import PhotosUI
import UIKit

struct OnboardingStepPhotosView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    @State private var pickerItems: [PhotosPickerItem?] = [nil, nil, nil, nil, nil]
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Add photos")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Add 2-5 photos. Your first photo will be your profile picture.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Photo count indicator with proper status message
            HStack(spacing: 8) {
                Image(systemName: photoStatusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(photoStatusColor)
                
                Text("\(viewModel.selectedImagesCount)/5 photos")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                if !photoStatusMessage.isEmpty {
                    Text("• \(photoStatusMessage)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(photoStatusColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        PhotoPickerCard(
                            index: index,
                            image: viewModel.selectedImages[safe: index] ?? nil,
                            pickerItem: Binding(
                                get: { pickerItems[index] },
                                set: { pickerItems[index] = $0 }
                            ),
                            isFirst: index == 0
                        )
                    }
                }
            }
        }
        .onChange(of: pickerItems) { items in
            for (index, item) in items.enumerated() {
                if let item = item {
                    loadImage(from: item, at: index)
                }
            }
        }
    }
    
    // Photo status helpers
    private var photoStatusIcon: String {
        let count = viewModel.selectedImagesCount
        if count >= 5 {
            return "checkmark.circle.fill"
        } else if count >= 2 {
            return "checkmark.circle.fill"
        } else {
            return "photo.circle"
        }
    }
    
    private var photoStatusColor: Color {
        let count = viewModel.selectedImagesCount
        if count >= 5 {
            return .orange
        } else if count >= 2 {
            return .green
        } else {
            return AppColors.secondaryText
        }
    }
    
    private var photoStatusMessage: String {
        let count = viewModel.selectedImagesCount
        if count >= 5 {
            return "Maximum reached"
        } else if count >= 2 {
            return "Minimum reached"
        } else {
            return ""
        }
    }

    private func loadImage(from item: PhotosPickerItem, at index: Int) {
        Task {
            let data = try? await item.loadTransferable(type: Data.self)
            let image = data.flatMap { UIImage(data: $0) }
            await MainActor.run {
                if let image {
                    viewModel.selectedImages[index] = image
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Photo Picker Card

private struct PhotoPickerCard: View {
    let index: Int
    let image: UIImage?
    @Binding var pickerItem: PhotosPickerItem?
    let isFirst: Bool
    
    var body: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            GeometryReader { geometry in
                ZStack {
                    if let image {
                        // Show image with consistent sizing
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [.black.opacity(0.4), .clear],
                                    startPoint: .bottom,
                                    endPoint: .center
                                )
                            )
                        
                        // Profile picture badge (for first photo)
                        if isFirst {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    Text("Profile")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                        .padding(10)
                                }
                                Spacer()
                            }
                        }
                        
                        // Change button
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                                    .padding(10)
                            }
                        }
                        
                    } else {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: isFirst ? "person.crop.circle.badge.plus" : "photo.badge.plus")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            
                            if isFirst {
                                VStack(spacing: 4) {
                                    Text("Profile Photo")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("Required")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                                }
                            } else {
                                Text("Add photo")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isFirst && image == nil
                            ? Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.5)
                            : Color.white.opacity(0.15),
                        lineWidth: isFirst && image == nil ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
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
