//
//  LikeMessageSheet.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//


import SwiftUI

struct LikeMessageSheet: View {

    let targetUser: AppUser?
    let track: Track?

    @Binding var message: String
    let isSending: Bool

    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Send a like")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    if let u = targetUser {
                        Text("to \(u.displayName)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    if let t = track {
                        Text("🎵 \(t.title) · \(t.artist)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Optional message")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)

                    TextField("Say something nice…", text: $message, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(12)
                        .background(Color.secondary.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("\(message.count)/160")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onSend()
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView().tint(.white)
                        } else {
                            Text("Send Like")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isSending)

            }
            .padding(16)
            .navigationTitle("Like")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
            .onChange(of: message) { newValue in
                if newValue.count > 160 {
                    message = String(newValue.prefix(160))
                }
            }
        }
    }
}
