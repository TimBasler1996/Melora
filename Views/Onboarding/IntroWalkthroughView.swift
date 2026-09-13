import SwiftUI

/// Three pages that show, not tell, what Melora is. Shown once, the first
/// time someone lands in the app after onboarding; reachable again from
/// Settings → "How Melora works".
///
/// Each page is one idea, one sentence and a small living illustration built
/// from the app's own pieces (the ripple, a Discover card, the song sheet),
/// so the real screens feel familiar afterwards.
struct IntroWalkthroughView: View {
    let onDone: () -> Void

    @State private var page: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let pageCount = 3

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    goLivePage.tag(0)
                    discoverPage.tag(1)
                    songPage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: page)

                controls
            }

            topBar
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            MeloraWordmark(size: 22)
            Spacer()
            // Sizing lives on the label: SwiftUI hit-tests a button on its
            // label's bounds, so a frame on the Button alone changes nothing.
            Button {
                finish()
            } label: {
                Text("Skip")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip introduction")
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
    }

    private var controls: some View {
        VStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? AppColors.primary : AppColors.surfaceElevated)
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page)
                }
            }

            Button {
                if page < pageCount - 1 {
                    page += 1
                } else {
                    finish()
                }
            } label: {
                Text(page < pageCount - 1 ? "Next" : "Let’s go")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(AppColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 24)
    }

    private func finish() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onDone()
    }

    // MARK: - Page 1: Go live

    private var goLivePage: some View {
        pageLayout(
            title: "You go live",
            text: "Play something on Spotify and tap Go live. People nearby see what you’re playing — for as long as it plays."
        ) {
            VStack(spacing: 26) {
                LiveRipple(size: 120)

                nowPlayingPill(title: "Nights", artist: "Frank Ocean")
            }
        }
    }

    private func nowPlayingPill(title: String, artist: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x4A2C3A), Color(hex: 0x1E1418)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(MIcon("music", size: 16, color: AppColors.primaryText.opacity(0.7)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.song(size: 19))
                    .foregroundColor(AppColors.primaryText)
                Text(artist)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }

            Spacer(minLength: 8)

            Text("Live")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(AppColors.background)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppColors.live))
        }
        .padding(12)
        .frame(width: 280)
        .melCard(cornerRadius: 16)
    }

    // MARK: - Page 2: Discover

    private var discoverPage: some View {
        pageLayout(
            title: "See who’s around",
            text: "Discover shows the people near you and the song they’re playing right now. Slide “Within” to see further.",
            footnote: "Your distance is shown in rough steps — never your exact location."
        ) {
            VStack(spacing: 12) {
                miniCard(name: "Lena", song: "Nights", artist: "Frank Ocean", distance: "under 500 m", tint: Color(hex: 0x4A2C3A))
                miniCard(name: "Samir", song: "Redbone", artist: "Childish Gambino", distance: "about 1 km", tint: Color(hex: 0x3A2E1A))
                    .scaleEffect(0.96)
                    .opacity(0.85)
                miniCard(name: "Ava", song: "Kill Bill", artist: "SZA", distance: "about 2 km", tint: Color(hex: 0x1F2E3A))
                    .scaleEffect(0.92)
                    .opacity(0.65)
            }
        }
    }

    private func miniCard(name: String, song: String, artist: String, distance: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColors.surfaceElevated)
                .frame(width: 40, height: 40)
                .overlay(MIcon("person", size: 16, color: AppColors.mutedText))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(AppColors.primaryText)
                Text(song)
                    .font(AppFonts.song(size: 18))
                    .foregroundColor(AppColors.primaryText)
                HStack(spacing: 5) {
                    RippleMark(size: 10, rings: 1)
                    Text("Live · \(distance)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.secondaryText)
                }
            }

            Spacer(minLength: 8)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(colors: [tint, AppColors.backgroundElevated], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
        }
        .padding(12)
        .frame(width: 300)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppColors.cardBackground)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 220))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.stroke, lineWidth: 1))
    }

    // MARK: - Page 3: The song

    private var songPage: some View {
        pageLayout(
            title: "A song is the door",
            text: "Tap a song to play it on your Spotify, like it, or say something. If they say hi back, you’re chatting."
        ) {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x4A2C3A), Color(hex: 0x1E1418)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .overlay(MIcon("music", size: 36, color: AppColors.primaryText.opacity(0.6)))
                    .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 10)

                VStack(spacing: 2) {
                    Text("Nights")
                        .font(AppFonts.song(size: 24))
                        .foregroundColor(AppColors.primaryText)
                    Text("Frank Ocean")
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                }

                // Mirrors the real sheet: one Ember primary, then the row.
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        MIcon("play", size: 16, color: AppColors.background)
                        Text("Play on Spotify")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(AppColors.background)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(AppColors.primary))

                    HStack(spacing: 0) {
                        miniAction(icon: "heart", label: "Like")
                        miniAction(icon: "send", label: "Message")
                        miniAction(icon: "next", label: "Queue")
                        miniAction(icon: "arrow-up-right", label: "Share")
                    }
                    .padding(.vertical, 2)
                    .melCard(cornerRadius: 16)
                }
                .frame(width: 300)
            }
        }
    }

    private func miniAction(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            MIcon(icon, size: 20, color: AppColors.primaryText)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.primaryText.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    // MARK: - Layout

    private func pageLayout<Illustration: View>(
        title: String,
        text: String,
        footnote: String? = nil,
        @ViewBuilder illustration: () -> Illustration
    ) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)

            illustration()
                .frame(maxWidth: .infinity)
                .frame(height: 300)

            Spacer(minLength: 20)

            VStack(spacing: 12) {
                Text(title)
                    .font(AppFonts.largeTitle())
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)

                Text(text)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let footnote {
                    Text(footnote)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 28)
        }
    }
}

// MARK: - Seen state

/// Whether the intro has been shown. Bump `currentVersion` to show a
/// reworked intro to existing users again.
enum IntroWalkthrough {
    static let currentVersion = 1
    private static let key = "intro.seenVersion"

    static var hasBeenSeen: Bool {
        UserDefaults.standard.integer(forKey: key) >= currentVersion
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}

#Preview {
    IntroWalkthroughView(onDone: {})
}
