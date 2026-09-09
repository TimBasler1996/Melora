import SwiftUI

struct UserSearchView: View {

    @StateObject private var viewModel = UserSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    searchBar
                    content
                }
            }
            .melScreenBackground()
            .navigationTitle("Find People")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .task {
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))
                .font(.system(size: 16, weight: .medium))

            TextField("Search by name…", text: $viewModel.searchText)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { viewModel.search() }
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.search()
                }

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                    viewModel.search()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching {
            Spacer()
            ProgressView()
                .tint(.white)
            Spacer()
        } else if viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.3))
                Text("Search for people to follow")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Text("Type at least 2 characters to search.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.3))
                Text("Couldn’t search")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Retry") { viewModel.search() }
                    .font(AppFonts.subheadline())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.surfaceElevated)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
        } else if viewModel.results.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "person.slash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.3))
                Text("Nobody by that name")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Text("Try a first or last name.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.results) { user in
                        NavigationLink {
                            UserProfilePreviewView(userId: user.uid)
                        } label: {
                            UserSearchRowView(
                                user: user,
                                isFollowing: viewModel.isFollowing(user.uid),
                                onToggleFollow: {
                                    Task { await viewModel.toggleFollow(userId: user.uid) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    UserSearchView()
}
