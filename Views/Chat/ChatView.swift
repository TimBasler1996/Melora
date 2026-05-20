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
    @Environment(\.dismiss) private var dismiss

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
                                if vm.needsAcceptance || vm.waitingForAcceptance {
                                    requestBanner
                                }

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

                    footer
                }
            }
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.start(conversationId: conversationId) }
        .onDisappear {
            Task { await vm.markAsRead(conversationId: conversationId) }
            vm.stop()
        }
    }

    @ViewBuilder
    private var footer: some View {
        if vm.needsAcceptance {
            acceptDeclineFooter
        } else if vm.waitingForAcceptance {
            waitingFooter
        } else {
            composer
        }
    }

    private var requestBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 12, weight: .bold))
            Text(vm.needsAcceptance
                 ? "Message request — accept to start chatting"
                 : "Waiting for the other user to accept your request")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.white.opacity(0.12))
        )
        .padding(.bottom, 4)
    }

    private var acceptDeclineFooter: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await vm.declineRequest()
                    dismiss()
                }
            } label: {
                Text("Decline")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .disabled(vm.isResponding)

            Button {
                Task { await vm.acceptRequest() }
            } label: {
                HStack(spacing: 6) {
                    if vm.isResponding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text("Accept")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.primary)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isResponding)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 12)
    }

    private var waitingFooter: some View {
        Text("You can send more messages once your request is accepted.")
            .font(AppFonts.footnote())
            .foregroundColor(.white.opacity(0.6))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.vertical, 14)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $vm.draft)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.16))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await vm.send(conversationId: conversationId) }
            } label: {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.18))
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

    /// Extract a Spotify track ID from the message text, if present.
    private var spotifyTrackId: String? {
        let text = message.text
        // Match "https://open.spotify.com/track/{id}" or "spotify:track:{id}"
        if let range = text.range(of: #"open\.spotify\.com/track/([A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(text[range])
            return match.components(separatedBy: "/").last
        }
        if let range = text.range(of: #"spotify:track:([A-Za-z0-9]+)"#, options: .regularExpression) {
            let match = String(text[range])
            return match.components(separatedBy: ":").last
        }
        return nil
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                // Show a Spotify link card if the message contains a track URL
                if let trackId = spotifyTrackId {
                    SpotifyLinkCard(
                        trackId: trackId,
                        title: "Spotify Track",
                        artist: "Tap to open",
                        album: String?.none,
                        artworkURL: URL?.none
                    )
                    .padding(.top, 4)
                }

                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            .padding(12)
            .background(Color.white.opacity(isMine ? 0.24 : 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !isMine { Spacer(minLength: 40) }
        }
    }
}
