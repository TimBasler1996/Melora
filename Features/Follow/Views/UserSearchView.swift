import SwiftUI

struct UserSearchView: View {

    @StateObject private var viewModel = UserSearchViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.2),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    content
                }
            }
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
        .background(Color.white.opacity(0.1))
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
        } else if viewModel.results.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: "person.slash.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white.opacity(0.3))
                Text("No results found")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.results) { user in
                        UserSearchRowView(
                            user: user,
                            isFollowing: viewModel.isFollowing(user.uid),
                            onToggleFollow: {
                                Task { await viewModel.toggleFollow(userId: user.uid) }
                            }
                        )
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
