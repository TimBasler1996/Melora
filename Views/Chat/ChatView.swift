import SwiftUI
import FirebaseAuth

struct ChatView: View {

    let conversationId: String

    @StateObject private var vm = ChatViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppGradients.darkBackground
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
                    messagesScrollView
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

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if vm.needsAcceptance || vm.waitingForAcceptance {
                        requestBanner
                    }

                    ForEach(Array(vm.messages.enumerated()), id: \.element.id) { index, msg in
                        if shouldShowDateSeparator(at: index) {
                            DateSeparator(date: msg.createdAt)
                                .padding(.vertical, 8)
                        }

                        ChatBubble(
                            message: msg,
                            currentUserId: vm.currentUserId,
                            onDoubleTap: {
                                Task { await vm.toggleReaction("❤️", on: msg, conversationId: conversationId) }
                            },
                            onReply: { vm.startReply(to: msg) },
                            onReact: { emoji in
                                Task { await vm.toggleReaction(emoji, on: msg, conversationId: conversationId) }
                            }
                        )
                        .id(msg.id)

                        if shouldShowSeen(at: index) {
                            SeenIndicator()
                                .padding(.top, 2)
                        }
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
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index < vm.messages.count else { return false }
        let current = vm.messages[index]
        if index == 0 { return true }
        let previous = vm.messages[index - 1]
        return !Calendar.current.isDate(current.createdAt, inSameDayAs: previous.createdAt)
    }

    /// Show the "Seen" indicator under the most recent message I sent, if the
    /// other user has read past it.
    private func shouldShowSeen(at index: Int) -> Bool {
        guard let myId = vm.currentUserId else { return false }
        let msg = vm.messages[index]
        guard msg.senderId == myId else { return false }

        // Only on the very last "mine" message in the timeline.
        let later = vm.messages.dropFirst(index + 1)
        if later.contains(where: { $0.senderId == myId }) { return false }

        guard let otherReadAt = vm.otherUserLastReadAt else { return false }
        return otherReadAt >= msg.createdAt
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if vm.needsAcceptance {
            acceptDeclineFooter
        } else if vm.waitingForAcceptance {
            waitingFooter
        } else {
            VStack(spacing: 6) {
                if let replyTarget = vm.replyingTo {
                    replyPreviewBar(for: replyTarget)
                }
                composer
            }
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

    private func replyPreviewBar(for message: ChatMessage) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.senderId == vm.currentUserId ? "yourself" : "message")")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primary)
                Text(message.text)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                vm.cancelReply()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .padding(.horizontal, AppLayout.screenPadding)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $vm.draft, axis: .vertical)
                .lineLimit(1...5)
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

// MARK: - Date Separator

private struct DateSeparator: View {
    let date: Date

    var label: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "EEEE, MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    var body: some View {
        HStack(spacing: 10) {
            line
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
    }
}

// MARK: - Seen Indicator

private struct SeenIndicator: View {
    var body: some View {
        HStack {
            Spacer()
            Text("Seen")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.trailing, 4)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {

    let message: ChatMessage
    let currentUserId: String?
    let onDoubleTap: () -> Void
    let onReply: () -> Void
    let onReact: (String) -> Void

    private static let availableReactions = ["❤️", "😂", "😮", "😢", "🙏", "🔥"]

    private var isMine: Bool {
        guard let myId = currentUserId else { return false }
        return message.senderId == myId
    }

    private var spotifyTrackId: String? {
        let text = message.text
        if let range = text.range(of: #"open\.spotify\.com/track/([A-Za-z0-9]+)"#, options: .regularExpression) {
            return String(text[range]).components(separatedBy: "/").last
        }
        if let range = text.range(of: #"spotify:track:([A-Za-z0-9]+)"#, options: .regularExpression) {
            return String(text[range]).components(separatedBy: ":").last
        }
        return nil
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .padding(12)
                    .background(Color.white.opacity(isMine ? 0.24 : 0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .onTapGesture(count: 2) { onDoubleTap() }
                    .contextMenu {
                        Section("React") {
                            ForEach(Self.availableReactions, id: \.self) { emoji in
                                Button { onReact(emoji) } label: {
                                    Text(emoji)
                                }
                            }
                        }
                        Button {
                            onReply()
                        } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }
                    }

                if let reactions = message.reactions, !reactions.isEmpty {
                    reactionsRow(reactions)
                }
            }

            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let reply = message.replyTo {
                replyQuote(reply)
            }

            Text(message.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

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
    }

    private func replyQuote(_ reply: ChatMessage.ReplyContext) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppColors.primary)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.senderId == currentUserId ? "You" : "Reply")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primary)
                Text(reply.textPreview)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func reactionsRow(_ reactions: [String: String]) -> some View {
        let counts = Dictionary(grouping: reactions.values, by: { $0 })
            .mapValues { $0.count }
        let sorted = counts.sorted { $0.value > $1.value }

        return HStack(spacing: 4) {
            ForEach(sorted, id: \.key) { emoji, count in
                HStack(spacing: 3) {
                    Text(emoji).font(.system(size: 12))
                    if count > 1 {
                        Text("\(count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.black.opacity(0.4))
                        .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                )
            }
        }
        .padding(.horizontal, 4)
        .offset(y: -4)
    }
}
