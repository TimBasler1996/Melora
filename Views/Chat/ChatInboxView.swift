//
//  ChatInboxView.swift
//  SocialSound
//
//  Created by Tim Basler on 07.01.2026.
//

import SwiftUI

struct ChatInboxView: View {

    @StateObject private var vm = ChatInboxViewModel()
    @State private var showEarlierChats = false
    @State private var chatToDelete: ChatInboxRow?

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

                content
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                Text("When you accept a like and start chatting, it will show up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Spacer()
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    if vm.todayRows.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No new messages today")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        chatSectionHeader("Today")
                        ForEach(vm.todayRows) { row in
                            chatRow(row)
                        }
                    }
                    if !vm.earlierRows.isEmpty {
                        DisclosureGroup(isExpanded: $showEarlierChats) {
                            ForEach(vm.earlierRows) { row in
                                chatRow(row)
                            }
                        } label: {
                            Text("Earlier")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .tint(.white.opacity(0.5))
                        .padding(.top, 8)
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
                        vm.deleteChat(row: row)
                    }
                }
                Button("Cancel", role: .cancel) {
                    chatToDelete = nil
                }
            }
        }
    }

    private func chatRow(_ row: ChatInboxRow) -> some View {
        NavigationLink {
            ChatView(conversationId: row.conversationId)
        } label: {
            ChatInboxRowView(row: row)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                chatToDelete = row
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func chatSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }
}

