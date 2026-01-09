import SwiftUI

struct ChatInboxView: View {

    @StateObject private var vm = ChatInboxViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { vm.startListening() }
            .onDisappear { vm.stopListening() }
            .refreshable { vm.reloadOnce() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.rows.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading chats…").tint(.white)
                Spacer()
            }
        } else if let err = vm.errorMessage {
            VStack(spacing: 10) {
                Text("Couldn’t load chats")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(err)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { vm.startListening() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if vm.rows.isEmpty {
            VStack(spacing: 10) {
                Spacer()
                Text("No chats yet")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("When you accept a like and start chatting, it shows up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.rows) { row in
                        NavigationLink {
                            ChatView(conversationId: row.conversationId)
                        } label: {
                            ChatInboxRowView(row: row)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}
