import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

struct ProfileView: View {

    enum Mode {
        case preview
        case edit
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

    @EnvironmentObject private var currentUserStore: CurrentUserStore

    @State private var showSettings = false
    @State private var photoPickerItems: [PhotosPickerItem?] = Array(repeating: nil, count: 6)
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var followerCount: Int?
    @State private var likesReceivedCount: Int?

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

                    ScrollView(.vertical) {
                        VStack(spacing: 16) {
                            if viewModel.isLoading {
                                loadingState
                            } else if let error = viewModel.errorMessage {
                                errorState(error)
                            } else {
                                profileContent
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
                viewModel.beginEditing()
                await loadProfileStats()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            if mode == .edit {
                Button {
                    if viewModel.hasDraftChanges {
                        showDiscardAlert = true
                    } else {
                        viewModel.discardDraft()
                        mode = .preview
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(mode == .preview ? "Your Profile" : "Edit Profile")
                    .font(AppFonts.title())
                    .foregroundColor(AppColors.primaryText)

                Text("Edit your profile details")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }

            Spacer()

            if mode == .preview {
                HStack(spacing: 12) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        mode = .edit
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(AppColors.tintedBackground.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit Profile")

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
            }
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 12)
    }

    // MARK: - Profile Content (stats + edit)

    @ViewBuilder
    private var profileContent: some View {
        statsSection

        if let draft = viewModel.draft {
            VStack(spacing: 18) {
                editHeader(draft: draft)
                basicsSection(draft: draft)
                photoEditorSection(draft: draft)

                // Save button
                Button {
                    Task {
                        await viewModel.saveDraftChanges()
                    }
                } label: {
                    HStack(spacing: 10) {
                        if viewModel.isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        }
                        Text(viewModel.isSaving ? "Saving..." : "Save Changes")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                            .fill(viewModel.hasDraftChanges && !viewModel.isSaving ? AppColors.primary : AppColors.primary.opacity(0.5))
                    )
                    .foregroundColor(.white)
                    .shadow(color: viewModel.hasDraftChanges ? AppColors.primary.opacity(0.3) : .clear, radius: 12, x: 0, y: 6)
                }
                .disabled(viewModel.isSaving || !viewModel.hasDraftChanges)

                if viewModel.saveSucceeded {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Changes saved successfully")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.green)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.15))
                    )
                }
            }
        } else {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(AppColors.primary)
                Text("Preparing editor…")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 0) {
            NavigationLink {
                FollowersListView()
            } label: {
                statItem(
                    value: followerCount.map(String.init) ?? "0",
                    label: "Followers",
                    tappable: true
                )
            }
            .buttonStyle(.plain)

            Spacer()
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 32)
            Spacer()

            statItem(
                value: formatBroadcastTime(currentUserStore.user?.broadcastMinutesTotal),
                label: "Broadcast"
            )

            Spacer()
            Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 32)
            Spacer()

            statItem(
                value: likesReceivedCount.map(String.init) ?? "0",
                label: "Likes"
            )
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private func statItem(value: String, label: String, tappable: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.mutedText)
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.mutedText)
                }
            }
        }
        .frame(minWidth: 60)
    }

    private func formatBroadcastTime(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "0min" }
        if minutes < 60 { return "\(minutes)min" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 { return "\(hours)h" }
        return "\(hours)h \(remaining)m"
    }

    // MARK: - Edit Header (hero photo)

    private func editHeader(draft: ProfileViewModel.ProfileDraft) -> some View {
        let avatarURL = draft.photoURLs.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackAvatarURL = viewModel.profile?.spotifyAvatarURL
        let displayURL = (avatarURL?.isEmpty == false) ? avatarURL : fallbackAvatarURL
        let localImage = draft.selectedImages.first ?? nil

        return VStack(alignment: .leading, spacing: 12) {
            Text("Profile Photo")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            PhotosPicker(selection: $avatarPickerItem, matching: .images, photoLibrary: .shared()) {
                ZStack(alignment: .bottomTrailing) {
                    // Large hero image preview
                    Group {
                        if let localImage {
                            Image(uiImage: localImage)
                                .resizable()
                                .scaledToFill()
                        } else if let displayURL, let url = URL(string: displayURL), !displayURL.isEmpty {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    heroEditPlaceholder
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .transaction { t in t.animation = nil }
                                case .failure:
                                    heroEditPlaceholder
                                @unknown default:
                                    heroEditPlaceholder
                                }
                            }
                        } else {
                            heroEditPlaceholder
                        }
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    // Edit button overlay
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Tap to change")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.6))
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                    .padding(16)
                }
            }
            .buttonStyle(.plain)
            .onChange(of: avatarPickerItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    let image = data.flatMap { UIImage(data: $0) }

                    await MainActor.run {
                        viewModel.setDraftSelectedImage(image, index: 0)
                        avatarPickerItem = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private var heroEditPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.3), AppColors.primary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText.opacity(0.6))
                Text("Add your main photo")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }

    // MARK: Photos editor

    private func photoEditorSection(draft: ProfileViewModel.ProfileDraft) -> some View {
        // 2x3 grid as per UX guidelines (Hinge-like)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(AppFonts.sectionTitle())
                    .foregroundColor(AppColors.primaryText)

                Spacer()

                Text("Tap to add or replace")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.mutedText)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1..<6, id: \.self) { index in
                    photoEditorTile(index: index, draft: draft)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private func photoEditorTile(index: Int, draft: ProfileViewModel.ProfileDraft) -> some View {
        let localImage = draft.selectedImages.indices.contains(index) ? draft.selectedImages[index] : nil
        let remoteURL = draft.photoURLs.indices.contains(index) ? draft.photoURLs[index] : nil

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
            .aspectRatio(3/4, contentMode: .fit)
            .background(AppColors.tintedBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .stroke(hasAnyPhoto ? Color.clear : Color.white.opacity(0.12), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(hasAnyPhoto ? 0.1 : 0.05), radius: 8, x: 0, y: 4)
        }

        return picker
            .overlay(alignment: .topTrailing) {
                if hasAnyPhoto {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.removeDraftPhoto(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 26, height: 26)
                            )
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove photo \(index + 1)")
                }
            }
            .accessibilityLabel(Text("Photo \(index + 1)"))
            .onChange(of: binding.wrappedValue) { _, newItem in
                guard let newItem else {
                    viewModel.setDraftSelectedImage(nil, index: index)
                    return
                }

                Task {
                    let data = try? await newItem.loadTransferable(type: Data.self)
                    let image = data.flatMap { UIImage(data: $0) }

                    await MainActor.run {
                        viewModel.setDraftSelectedImage(image, index: index)
                        if image != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    }
                }
            }
    }

    private func editPhotoPlaceholder(index: Int) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(AppColors.primary.opacity(0.7))

            Text("Add Photo")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [AppColors.tintedBackground.opacity(0.5), AppColors.tintedBackground.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func photoBadge(_ badge: String) -> some View {
        Text(badge)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
            )
            .padding(10)
    }

    // MARK: Basics section

    private func basicsSection(draft: ProfileViewModel.ProfileDraft) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basics")
                .font(AppFonts.sectionTitle())
                .foregroundColor(AppColors.primaryText)

            VStack(spacing: 14) {
                labeledField(title: "First name", isProminent: true) {
                    TextField("First name", text: draftBinding(\.firstName))
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                labeledField(title: "Last name") {
                    TextField("Last name", text: draftBinding(\.lastName))
                        .textInputAutocapitalization(.words)
                        .keyboardType(.namePhonePad)
                }

                birthdayPicker

                labeledField(title: "City") {
                    CitySearchFieldEdit(city: draftBinding(\.city))
                }

                genderSelector(currentGender: draft.gender)

                lookingForSelector(currentValue: draft.lookingFor)
            }
        }
        .padding(AppLayout.cardPadding)
        .background(cardBackground)
    }

    private let lookingForOptions = ["New Music", "Friends", "Open for all"]

    private func lookingForSelector(currentValue: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Looking for")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(lookingForOptions, id: \.self) { option in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                viewModel.updateDraft { $0.lookingFor = option }
                            } label: {
                                Text(option)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(currentValue == option ? .white : AppColors.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(currentValue == option ? AppColors.primary : AppColors.tintedBackground.opacity(0.8))
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

    private var birthdayPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Birthday")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.mutedText)

            fieldContainer {
                HStack(spacing: 12) {
                    DatePicker(
                        "",
                        selection: draftDateBinding(\.birthday),
                        in: minimumDate...Date(),
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Spacer(minLength: 0)

                    if let age = viewModel.draft?.birthday.age() {
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

    private func genderSelector(currentGender: String) -> some View {
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
                                viewModel.updateDraft { $0.gender = option }
                            } label: {
                                Text(option)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(currentGender == option ? .white : AppColors.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule().fill(currentGender == option ? AppColors.primary : AppColors.tintedBackground.opacity(0.8))
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

    private func draftBinding(_ keyPath: WritableKeyPath<ProfileViewModel.ProfileDraft, String>) -> Binding<String> {
        Binding(
            get: { viewModel.draft?[keyPath: keyPath] ?? "" },
            set: { newValue in
                viewModel.updateDraft { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func draftDateBinding(_ keyPath: WritableKeyPath<ProfileViewModel.ProfileDraft, Date>) -> Binding<Date> {
        Binding(
            get: { viewModel.draft?[keyPath: keyPath] ?? Date() },
            set: { newValue in
                viewModel.updateDraft { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private var minimumDate: Date {
        Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? .distantPast
    }

    // MARK: - Stats Loading

    private func loadProfileStats() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Fetch follower count
        if let followers = try? await FollowApiService.shared.fetchFollowerIds(of: uid) {
            followerCount = followers.count
        }

        // Fetch likes received count
        if let likes = try? await LikeApiService.shared.fetchLikesReceived(for: uid) {
            likesReceivedCount = likes.count
        }
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
            SettingsContentView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showSettings = false }
                    }
                }
        }
    }

    // MARK: - Mode handling

    private func handleModeChange(oldValue: Mode, newValue: Mode) {
        if newValue == .edit {
            viewModel.beginEditing()
        }
    }
}

struct ProfileAvatarView: View {
    let image: UIImage?
    let urlString: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transaction { t in t.animation = nil }
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground.opacity(0.6))
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.35, weight: .semibold))
                .foregroundColor(AppColors.secondaryText)
        }
    }
}
