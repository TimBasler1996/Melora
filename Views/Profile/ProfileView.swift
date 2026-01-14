import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {

    enum Mode: String, CaseIterable, Identifiable {
        case preview = "Preview"
        case edit = "Edit"
        var id: String { rawValue }
    }

    // ✅ Inject for previews/testing
    @StateObject private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // ✅ Convenience init for app usage (MainActor safe)
    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: ProfileViewModel())
    }

    @State private var mode: Mode = .preview
    @State private var showSettings = false
    @State private var photoPickerItems: [PhotosPickerItem?] = Array(repeating: nil, count: 6)

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]

    private var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - (AppLayout.screenPadding * 2)

            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 14) {
                    header

                    Picker("Profile mode", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, AppLayout.screenPadding)

                    ScrollView(.vertical) {
                        VStack(spacing: 16) {
                            if viewModel.isLoading {
                                loadingState
                            } else if let error = viewModel.errorMessage {
                                errorState(error)
                            } else {
                                if mode == .preview {
                                    previewContent
                                } else {
                                    editContent(contentWidth: contentWidth)
                                }
                            }
                        }
                        .frame(width: contentWidth, alignment: .center)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .task {
            if !isXcodePreview {
                await viewModel.loadProfile()
            }
        }
        .animation(.easeInOut(duration: 0.18), value: mode)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Profile")
                    .font(AppFonts.title())
                    .foregroundColor(AppColors.primaryText)

                Text(mode == .preview ? "This is how others see you" : "Edit your profile details")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }

            Spacer()

            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppColors.tintedBackground.opacity(0.35)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 12)
    }

    // MARK: - Preview Content (uses shared ProfilePreviewView)

    private var previewContent: some View {
        ProfilePreviewView(
            model: .fromUserProfile(viewModel.profile),
            density: .regular
        )
    }

    // MARK: - Edit Content

    private func editContent(contentWidth: CGFloat) -> some View {
        VStack(spacing: 18) {
            photoEditorSection
            basicsSection

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.discardChanges()
                } label: {
                    Text("Discard")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                                .fill(AppColors.tintedBackground)
                        )
                        .foregroundColor(AppColors.primaryText)
                }
                .disabled(viewModel.isSaving || !viewModel.hasChanges)

                Button {
                    Task { await viewModel.saveChanges() }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isSaving { ProgressView().tint(.white) }
                        Text(viewModel.isSaving ? "Saving…" : "Save")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                            .fill(viewModel.hasChanges ? AppColors.primary : AppColors.primary.opacity(0.4))
                    )
                    .foregroundColor(.white)
                }
                .disabled(viewModel.isSaving || !viewModel.hasChanges)
            }

            if viewModel.saveSucceeded {
                Text("Changes saved ✅")
                    .font(AppFonts.footnote())
                    .foregroundColor(.green)
            }
        }
    }

    // MARK: Photos editor

    private var photoEditorSection: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    photoEditorTile(index: index)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private func photoEditorTile(index: Int) -> some View {
        let localImage = viewModel.selectedImages.indices.contains(index) ? viewModel.selectedImages[index] : nil
        let remoteURL = viewModel.photoURLs.indices.contains(index) ? viewModel.photoURLs[index] : nil

        let hasRemote = !(remoteURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasLocal = localImage != nil
        let hasAnyPhoto = hasLocal || hasRemote

        let binding = Binding<PhotosPickerItem?>(
            get: { photoPickerItems.indices.contains(index) ? photoPickerItems[index] : nil },
            set: { newValue in
                if photoPickerItems.indices.contains(index) { photoPickerItems[index] = newValue }
            }
        )

        let picker = PhotosPicker(selection: binding, matching: .images, photoLibrary: .shared()) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let localImage {
                        Image(uiImage: localImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else if let remoteURL, let url = URL(string: remoteURL), !remoteURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                editPhotoPlaceholder(index: index)
                            case .success(let image):
                                image.resizable().scaledToFill().clipped()
                                    .transaction { t in t.animation = nil }
                            case .failure:
                                editPhotoPlaceholder(index: index)
                            @unknown default:
                                editPhotoPlaceholder(index: index)
                            }
                        }
                    } else {
                        editPhotoPlaceholder(index: index)
                    }
                }

                photoBadge("\(index + 1)")
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(3 / 4, contentMode: .fit)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(index == 0 ? 0.22 : 0.14), lineWidth: 1)
            )
        }

        return picker
            .overlay(alignment: .topTrailing) {
                if hasAnyPhoto {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.removePhoto(at: index)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo \(index + 1)")
                }
            }
            .accessibilityLabel(Text("Photo \(index + 1)"))
            .onChange(of: binding.wrappedValue) { newItem in
                guard let newItem else {
                    viewModel.setSelectedImage(nil, index: index)
                    return
                }

                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    let image = data.flatMap { UIImage(data: $0) }

                    await MainActor.run {
                        viewModel.setSelectedImage(image, index: index)
                        if image != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    }
                }
            }
    }

    private func editPhotoPlaceholder(index: Int) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)

            Text(index == 0 ? "Profile" : "Add")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func photoBadge(_ badge: String) -> some View {
        Text(badge)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.4)))
            .padding(10)
    }

    // MARK: Basics section

    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basics")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            VStack(spacing: 14) {
                labeledField(title: "First name", isProminent: true) {
                    TextField("First name", text: $viewModel.firstName)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                labeledField(title: "Last name") {
                    TextField("Last name", text: $viewModel.lastName)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                birthdayPicker

                labeledField(title: "City") {
                    TextField("City", text: $viewModel.city)
                        .textInputAutocapitalization(.words)
                        .keyboardType(.default)
                }

                genderSelector
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private var birthdayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthday")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                HStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: $viewModel.birthday,
                        in: minimumDate...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Spacer(minLength: 0)

                    if let age = viewModel.birthday.age() {
                        Text("\(age)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AppColors.tintedBackground.opacity(0.6)))
                    }
                }
            }
        }
    }

    private var genderSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gender")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(genderOptions, id: \.self) { option in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.gender = option
                            } label: {
                                Text(option)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(viewModel.gender == option ? .white : AppColors.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(viewModel.gender == option ? AppColors.primary : AppColors.tintedBackground.opacity(0.8))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func labeledField<Content: View>(
        title: String,
        isProminent: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFonts.footnote())
                .foregroundColor(isProminent ? AppColors.primaryText : AppColors.mutedText)

            fieldContainer(content: content)
        }
    }

    private func fieldContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .fill(AppColors.tintedBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var minimumDate: Date {
        Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
            .fill(AppColors.cardBackground)
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }

    // MARK: Loading / error

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(AppColors.primary)
            Text("Loading profile…")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private func errorState(_ message: String) -> some View {
        Text(message)
            .font(AppFonts.body())
            .foregroundColor(AppColors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    // MARK: Settings sheet

    private var settingsSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(AppColors.primary)

                Text("Settings")
                    .font(AppFonts.sectionTitle())

                Text("Settings options will appear here soon.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ProfileView(viewModel: ProfileViewModel(preview: true))
}
#endif
