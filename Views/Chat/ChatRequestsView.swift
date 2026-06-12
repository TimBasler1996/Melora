import SwiftUI

/// Lists pending message requests for the current user. Tapping a row opens
/// the chat in pending mode, where the recipient can Accept or Decline.
struct ChatRequestsView: View {

    let rows: [ChatInboxRow]

    var body: some View {
        ZStack {
            AppGradients.darkBackground
            .ignoresSafeArea()

            if rows.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.3))
                    Text("No requests")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Text("Accept a request to start chatting. Ignored requests are not delivered.")
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        ForEach(rows) { row in
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
        .navigationTitle("Message Requests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
