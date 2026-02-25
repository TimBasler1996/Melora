//
//  ChatView.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//


import SwiftUI
import FirebaseAuth

struct ChatView: View {

    let conversationId: String

    @StateObject private var vm = ChatViewModel()

    var body: some View {
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

            VStack(spacing: 10) {

                if vm.isLoading && vm.messages.isEmpty {
                    Spacer()
                    ProgressView("Loading chat…").tint(.white)
                    Spacer()
                } else if let err = vm.errorMessage {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("Couldn’t load chat")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(err)
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)

                        Button("Retry") { vm.start(conversationId: conversationId) }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.18))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    Spacer()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(vm.messages) { msg in
                                    ChatBubble(message: msg)
                                        .id(msg.id)
                                }
                            }
                            .padding(.horizontal, AppLayout.screenPadding)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: vm.messages.count) { _ in
                            if let last = vm.messages.last {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }

                    composer
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { vm.start(conversationId: conversationId) }
        .onDisappear { vm.stop() }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $vm.draft)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await vm.send(conversationId: conversationId) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(AppColors.primary.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 12)
    }
}

private struct ChatBubble: View {

    let message: ChatMessage

    private var isMine: Bool {
        guard let myId = Auth.auth().currentUser?.uid else { return false }
        return message.senderId == myId
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(12)
            .background(isMine ? AppColors.primary.opacity(0.55) : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isMine { Spacer(minLength: 40) }
        }
    }
}
