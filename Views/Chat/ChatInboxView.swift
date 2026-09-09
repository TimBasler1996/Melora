//
//  ChatInboxView.swift
//  SocialSound
//
//  Created by Tim Basler on 07.01.2026.
//

import SwiftUI

struct ChatInboxView: View {

    @StateObject private var vm = ChatInboxViewModel()
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @State private var chatToDelete: ChatInboxRow?
    /// Conversation pushed from a notification tap or a Discover "Open chat".
    @State private var routedConversationId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                content
            }
            .melScreenBackground()
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $routedConversationId) { conversationId in
                ChatView(conversationId: conversationId)
            }
            .onAppear {
                vm.startListening()
                consumeRoutedConversation()
            }
            .onChange(of: router.pendingConversationId) { _, _ in
                consumeRoutedConversation()
            }
            .onDisappear { vm.stopListening() }
            .refreshable { vm.reloadOnce() }
            .overlay(alignment: .bottom) {
                if let toast = vm.actionError {
                    errorToast(toast)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if vm.actionError == toast { vm.actionError = nil }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: vm.actionError)
        }
    }

    private func errorToast(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(AppColors.primary)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.surfaceElevated)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        )
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 12)
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
                    .font(AppFonts.headline())
                    .foregroundColor(.white)

                Text(err)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { vm.startListening() }
                    .font(AppFonts.subheadline())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.surfaceElevated)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if vm.acceptedRows.isEmpty && vm.pendingRequestRows.isEmpty && vm.sentRequestRows.isEmpty {
            VStack(spacing: 12) {
                if let me = currentUserStore.user {
                    NavigationLink {
                        LikesInboxView(user: me, showsCloseButton: false)
                    } label: {
                        likesBanner
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 12)
                }
                Spacer()
                Text("No chats yet")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Like a track in Discover or accept a like you received, and the chat shows up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    if !vm.pendingRequestRows.isEmpty {
                        NavigationLink {
                            ChatRequestsView(rows: vm.pendingRequestRows)
                        } label: {
                            requestsBanner(count: vm.pendingRequestRows.count)
                        }
                        .buttonStyle(.plain)
                    }

                    if let me = currentUserStore.user {
                        NavigationLink {
                            LikesInboxView(user: me, showsCloseButton: false)
                        } label: {
                            likesBanner
                        }
                        .buttonStyle(.plain)
                    }

                    if !vm.sentRequestRows.isEmpty {
                        chatSectionHeader("Waiting for response")
                        ForEach(vm.sentRequestRows) { row in
                            NavigationLink {
                                ChatView(conversationId: row.conversationId)
                            } label: {
                                ChatInboxRowView(row: row)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !vm.todayRows.isEmpty {
                        chatSectionHeader("Today")
                        ForEach(vm.todayRows) { row in
                            chatRow(row)
                        }
                    }
                    if !vm.earlierRows.isEmpty {
                        chatSectionHeader("Earlier")
                        ForEach(vm.earlierRows) { row in
                            chatRow(row)
                        }
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .confirmationDialog(
                "Delete this chat?",
                isPresented: Binding(
                    get: { chatToDelete != nil },
                    set: { if !$0 { chatToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let row = chatToDelete {
                    Button("Delete Chat", role: .destructive) {
                        vm.deleteChat(row)
                        chatToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { chatToDelete = nil }
            } message: {
                Text("The conversation is removed for both of you.")
            }
        }
    }

    private func consumeRoutedConversation() {
        guard let id = router.pendingConversationId else { return }
        router.pendingConversationId = nil
        routedConversationId = id
    }

    /// A chat row with a long-press menu. (Swipe actions only work inside
    /// `List`, and this screen is a custom `ScrollView`.)
    private func chatRow(_ row: ChatInboxRow) -> some View {
        NavigationLink {
            ChatView(conversationId: row.conversationId)
        } label: {
            ChatInboxRowView(row: row)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                chatToDelete = row
            } label: {
                Label("Delete Chat", systemImage: "trash")
            }
        }
    }

    private var likesBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.live.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Likes and followers")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("See who liked your tracks")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .melCard(cornerRadius: 14)
    }

    private func requestsBanner(count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.primary.opacity(0.25))
                    .frame(width: 44, height: 44)
                Image(systemName: "tray.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Message Requests")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("\(count) new \(count == 1 ? "request" : "requests")")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .melCard(cornerRadius: 14)
    }

    private func chatSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(.top, title == "Earlier" ? 8 : 0)
    }
}

