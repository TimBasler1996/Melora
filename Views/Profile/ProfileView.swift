import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {

    enum Mode: String, CaseIterable, Identifiable {
        case preview = "Preview"
        case edit = "Edit"
        var id: String { rawValue }
    }

    // ✅ inject for previews / testing
    @StateObject private var viewModel: ProfileViewModel

        init(viewModel: ProfileViewModel) {
            _viewModel = StateObject(wrappedValue: viewModel)
        }
    
    // Convenience init für die App (MainActor-safe)
       @MainActor
       init() {
           _viewModel = StateObject(wrappedValue: ProfileViewModel())
       }

    @State private var mode: Mode = .preview
    @State private var showSettings = false
    @State private var photoPickerItems: [PhotosPickerItem?] = [nil, nil, nil]

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]

    private var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - (AppLayout.screenPadding * 2)

            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 16) {
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
                        .padding(.bottom, 24)
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

    // MARK: Header

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
                    .background(
                        Circle().fill(AppColors.tintedBackground.opacity(0.35))
                    )
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 12)
    }

    // MARK: Preview Content

    private var previewContent: some View {
        VStack(spacing: 12) {
            heroCard

            topInfoRow

            // ✅ Only show photo2 + photo3 under hero
            photoCard(urlString: viewModel.profile?.photoURL(at: 1))
            photoCard(urlString: viewModel.profile?.photoURL(at: 2))
        }
    }

    // ✅ Not round. Smaller. No left/right cropping.
    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            heroImageNonCropping

            LinearGradient(
                colors: [Color.black.opacity(0.00), Color.black.opacity(0.60)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 6) {
                Text(heroTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(heroSubtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3 / 4, contentMode: .fit)
        .frame(maxHeight: 520) // ✅ smaller than before
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 10)
    }

    private var heroImageNonCropping: some View {
        Group {
            if let urlString = viewModel.profile?.heroPhotoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        ZStack {
                            // Background blur so we NEVER get ugly bars.
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 18)
                                .opacity(0.35)
                                .clipped()
                                .allowsHitTesting(false)

                            // Foreground fits fully -> no side cropping
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                                .clipped()
                                .transaction { t in t.animation = nil }
                        }
                    case .failure:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var heroPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.6), AppColors.secondary.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "person.crop.square.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var heroTitle: String {
        let name = viewModel.profile?.displayFirstName ?? "Your Name"
        if let age = viewModel.profile?.age {
            return "\(name), \(age)"
        }
        return name
    }

    private var heroSubtitle: String {
        let city = viewModel.profile?.city.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return city.isEmpty ? "Add your city" : city
    }

    // ✅ Male + CH first, then Age + City somewhere, and spotify link
    private var topInfoRow: some View {
        HStack(spacing: 10) {
            if let gender = trimmedValue(viewModel.profile?.gender) {
                ProfileChip(text: gender, icon: "person.fill")
            }

            if let country = trimmedValue(viewModel.profile?.spotifyCountry ?? viewModel.profile?.countryCode) {
                ProfileChip(text: country.uppercased(), icon: "globe")
            }

            if let age = viewModel.profile?.age {
                let city = trimmedValue(viewModel.profile?.city) ?? ""
                let text = city.isEmpty ? "\(age)" : "\(age) · \(city)"
                ProfileChip(text: text, icon: "location.fill")
            } else if let city = trimmedValue(viewModel.profile?.city) {
                ProfileChip(text: city, icon: "location.fill")
            }

            Spacer(minLength: 0)

            if let spotifyURL = spotifyProfileURL {
                Link(destination: spotifyURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Spotify")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.tintedBackground.opacity(0.55)))
                    .foregroundColor(AppColors.primaryText)
                }
                .accessibilityLabel("Open Spotify profile")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spotifyProfileURL: URL? {
        let raw = (viewModel.profile?.spotifyId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        return URL(string: "https://open.spotify.com/user/\(raw)")
    }

    private func photoCard(urlString: String?) -> some View {
        ZStack {
            Group {
                if let urlString, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            photoPlaceholder
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipped()
                                .transaction { t in t.animation = nil }
                        case .failure:
                            photoPlaceholder
                        @unknown default:
                            photoPlaceholder
                        }
                    }
                } else {
                    photoPlaceholder
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 10)
    }

    private var photoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.tintedBackground.opacity(0.35))
            Image(systemName: "photo.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
        }
    }

    private func trimmedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: Edit Content (kept as-is, only layout safe)

    private func editContent(contentWidth: CGFloat) -> some View {
        VStack(spacing: 18) {
            photoEditorSection(contentWidth: contentWidth)
            basicsSection

            Button {
                Task { await viewModel.saveChanges() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving {
                        ProgressView().tint(.white)
                    }
                    Text(viewModel.isSaving ? "Saving…" : "Save changes")
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

            if viewModel.saveSucceeded {
                Text("Changes saved ✅")
                    .font(AppFonts.footnote())
                    .foregroundColor(.green)
            }
        }
    }

    private func photoEditorSection(contentWidth: CGFloat) -> some View {
        let spacing: CGFloat = 12
        let innerWidth = contentWidth - (AppLayout.cardPadding * 2)
        let halfWidth = (innerWidth - spacing) / 2

        return VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            VStack(spacing: 12) {
                photoEditorTile(index: 0, title: "Profile photo", badge: "1", isPrimary: true, fixedWidth: nil)
                HStack(spacing: spacing) {
                    photoEditorTile(index: 1, title: "Photo 2", badge: "2", isPrimary: false, fixedWidth: halfWidth)
                    photoEditorTile(index: 2, title: "Photo 3", badge: "3", isPrimary: false, fixedWidth: halfWidth)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private func photoEditorTile(
        index: Int,
        title: String,
        badge: String,
        isPrimary: Bool,
        fixedWidth: CGFloat?
    ) -> some View {
        let localImage = viewModel.selectedImages.indices.contains(index) ? viewModel.selectedImages[index] : nil
        let remoteURL = viewModel.profile?.photoURL(at: index)

        let binding = Binding<PhotosPickerItem?>(
            get: { photoPickerItems.indices.contains(index) ? photoPickerItems[index] : nil },
            set: { newValue in
                if photoPickerItems.indices.contains(index) {
                    photoPickerItems[index] = newValue
                }
            }
        )

        return PhotosPicker(selection: binding, matching: .images, photoLibrary: .shared()) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let localImage {
                        Image(uiImage: localImage)
                            .resizable()
                            .scaledToFill()
                            .clipped()
                    } else if let remoteURL, let url = URL(string: remoteURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                editPhotoPlaceholder(isPrimary: isPrimary)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                                    .transaction { t in t.animation = nil }
                            case .failure:
                                editPhotoPlaceholder(isPrimary: isPrimary)
                            @unknown default:
                                editPhotoPlaceholder(isPrimary: isPrimary)
                            }
                        }
                    } else {
                        editPhotoPlaceholder(isPrimary: isPrimary)
                    }
                }

                photoBadge(badge)
            }
            .frame(width: fixedWidth)
            .frame(maxWidth: fixedWidth == nil ? .infinity : fixedWidth)
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipped()
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(Color.white.opacity(isPrimary ? 0.25 : 0.16), lineWidth: 1)
            )
        }
        .accessibilityLabel(Text(title))
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
                    if image != nil {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
    }

    private func editPhotoPlaceholder(isPrimary: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)

            Text(isPrimary ? "Profile photo" : "Add photo")
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

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(genderOptions, id: \.self) { option in
                    Button {
                        viewModel.gender = option
                    } label: {
                        Text(option)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(viewModel.gender == option ? .white : AppColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(viewModel.gender == option ? AppColors.primary : AppColors.tintedBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        viewModel.gender == option ? AppColors.primary.opacity(0.8) : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    }
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
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                content()
                    .font(isProminent ? .system(size: 18, weight: .semibold, design: .rounded) : AppFonts.body())
                    .foregroundColor(AppColors.primaryText)
                    .disableAutocorrection(true)
            }
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

private struct ProfileChip: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppColors.tintedBackground.opacity(0.5)))
        .foregroundColor(AppColors.primaryText)
    }
}

#if DEBUG

#Preview {
    ProfileView(viewModel: ProfileViewModel(preview: true))
}

#endif
