import SwiftUI
import PhotosUI
import UIKit
import FirebaseAuth

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

    @EnvironmentObject private var currentUserStore: CurrentUserStore

    @State private var mode: Mode = .preview
    @State private var showSettings = false
    @State private var showLikesInbox = false
    @State private var photoPickerItems: [PhotosPickerItem?] = Array(repeating: nil, count: ProfileViewModel.photoSlotCount)
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var showDiscardAlert = false
    @State private var followerCount: Int?
    @State private var likesReceivedCount: Int?

    private let genderOptions = ["Female", "Male", "Non-binary", "Other"]
    private let avatarSize: CGFloat = 84

    private var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - (AppLayout.screenPadding * 2)

            ZStack {
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
                                    editContent()
                                }
                            }
                        }
                        .frame(width: contentWidth, alignment: .center)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .melScreenBackground()
        }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .fullScreenCover(isPresented: $showLikesInbox) {
            if let me = currentUserStore.user {
                NavigationStack {
                    LikesInboxView(user: me)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if viewModel.saveSucceeded {
                savedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        viewModel.saveSucceeded = false
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.saveSucceeded)
        .alert("Discard changes?", isPresented: $showDiscardAlert) {
            Button("Discard", role: .destructive) {
                viewModel.discardDraft()
                mode = .preview
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved edits. Discard them and return to Preview?")
        }
        .task {
            if !isXcodePreview {
                await viewModel.loadProfile()
                await loadProfileStats()
            }
        }
        .onChange(of: mode) { oldValue, newValue in
            handleModeChange(oldValue: oldValue, newValue: newValue)
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

    // MARK: - Preview Content

    private var previewContent: some View {
        Group {
            if let profile = viewModel.profile {
                let previewData = ProfilePreviewData(
                    heroPhotoURL: profile.displayHeroPhotoURL,
                    additionalPhotoURLs: Array(profile.photoURLs.dropFirst())
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty },
                    fullName: profile.fullName,
                    age: profile.age,
                    city: profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : profile.city,
                    gender: profile.gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : profile.gender,
                    birthday: profile.birthday,
                    spotifyId: profile.spotifyId,
                    musicTaste: nil,
                    lookingFor: profile.lookingFor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? profile.lookingFor : nil,
                    followerCount: followerCount,
                    broadcastMinutes: currentUserStore.user?.broadcastMinutesTotal,
                    likesReceivedCount: likesReceivedCount,
                    userId: profile.uid
                )
                SharedProfilePreviewView(
                    data: previewData,
                    onLikesTap: currentUserStore.user == nil ? nil : { showLikesInbox = true }
                )
            } else {
                Text("No profile data available")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }


    // MARK: - Edit Content

    @ViewBuilder
    private func editContent() -> some View {
        if let draft = viewModel.draft {
            VStack(spacing: 18) {
                editHeader(draft: draft)

                if let saveError = viewModel.saveError {
                    saveErrorBanner(saveError)
                }

                basicsSection(draft: draft)
                photoEditorSection(draft: draft)

                VStack(spacing: 14) {
                    if viewModel.hasDraftChanges, let hint = viewModel.validationMessage {
                        Text(hint)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Save button
                    Button {
                        Task {
                            let didSave = await viewModel.saveDraftChanges()
                            if didSave { mode = .preview }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                            }
                            Text(viewModel.isSaving ? "Saving..." : "Save Changes")
                                .font(AppFonts.headline())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                                .fill(viewModel.canSave ? AppColors.primary : AppColors.primary.opacity(0.5))
                        )
                        .foregroundColor(.white)
                        .shadow(color: viewModel.canSave ? AppColors.primary.opacity(0.3) : .clear, radius: 12, x: 0, y: 6)
                    }
                    .disabled(!viewModel.canSave)

                    // Discard button — same confirmation as leaving via the picker.
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showDiscardAlert = true
                    } label: {
                        Text("Discard Changes")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                                    .fill(AppColors.tintedBackground.opacity(0.6))
                            )
                            .foregroundColor(AppColors.primaryText.opacity(viewModel.hasDraftChanges ? 1.0 : 0.5))
                    }
                    .disabled(viewModel.isSaving || !viewModel.hasDraftChanges)
                }
                .padding(.top, 6)

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
                            .stroke(AppColors.stroke, lineWidth: 1)
                    )
                    
                    // Edit button overlay
                    HStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Tap to change")
                            .font(AppFonts.subheadline())
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
                    let image = data.flatMap { UIImage(data: $0)?.downscaled() }

                    await MainActor.run {
                        viewModel.setDraftSelectedImage(image, index: 0)
                        avatarPickerItem = nil
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
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
                    .font(AppFonts.body())
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
                
                Text("\(draftPhotoCount(draft)) of \(ProfileViewModel.maxPhotoCount) · tap to add or replace")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.mutedText)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1..<ProfileViewModel.photoSlotCount, id: \.self) { index in
                    photoEditorTile(index: index, draft: draft)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
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
                    .stroke(hasAnyPhoto ? Color.clear : AppColors.stroke, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(hasAnyPhoto ? 0.1 : 0.05), radius: 8, x: 0, y: 4)
        }

        return picker
            .overlay(alignment: .topTrailing) {
                if hasAnyPhoto {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.removeDraftPhoto(at: index)
                        // Forget the picker selection too, so picking the same
                        // photo again counts as a new pick.
                        if photoPickerItems.indices.contains(index) { photoPickerItems[index] = nil }
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
                    let image = data.flatMap { UIImage(data: $0)?.downscaled() }

                    await MainActor.run {
                        viewModel.setDraftSelectedImage(image, index: index)
                        if image != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    }
                }
            }
    }

    /// Photos in the draft: a kept remote URL or a newly picked image per slot.
    private func draftPhotoCount(_ draft: ProfileViewModel.ProfileDraft) -> Int {
        zip(draft.photoURLs, draft.selectedImages).filter { url, image in
            image != nil || !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
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

                labeledField(title: "City") {
                    CitySearchFieldEdit(city: draftBinding(\.city))
                }

                genderSelector(currentGender: draft.gender)

                lookingForSelector(currentValue: draft.lookingFor)
            }
        }
        .padding(AppLayout.cardPadding)
        .melCard(cornerRadius: AppLayout.cornerRadiusLarge)
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
                                    .font(AppFonts.subheadline())
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
                                    .font(AppFonts.subheadline())
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
                    .stroke(AppColors.stroke, lineWidth: 1)
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

    // MARK: - Stats Loading

    private func loadProfileStats() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        async let countFetch = FollowApiService.shared.fetchFollowerCount(of: uid)
        async let likesFetch = LikeApiService.shared.fetchLikesReceivedCount(for: uid)

        followerCount = (try? await countFetch) ?? 0
        likesReceivedCount = (try? await likesFetch) ?? 0
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

    /// Inline save failure: the editor stays, the draft stays, Retry is one tap.
    private func saveErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(AppColors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.validationMessage == nil {
                Button("Retry") {
                    Task {
                        let didSave = await viewModel.saveDraftChanges()
                        if didSave { mode = .preview }
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(AppColors.primary))
                .disabled(viewModel.isSaving)
            }
        }
        .padding(14)
        .melCard(cornerRadius: 14)
    }

    private func errorState(_ message: String) -> some View {
        Text(message)
            .font(AppFonts.body())
            .foregroundColor(AppColors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }

    private var savedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
            Text("Profile saved")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.vertical, 12)
        .padding(.horizontal, 18)
        .background(
            Capsule()
                .fill(AppColors.live)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .padding(.bottom, 16)
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

        if oldValue == .edit && newValue == .preview {
            if viewModel.hasDraftChanges {
                showDiscardAlert = true
                mode = .edit
            } else {
                viewModel.discardDraft()
            }
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
            Circle().stroke(AppColors.stroke, lineWidth: 1)
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
