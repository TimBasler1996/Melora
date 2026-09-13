import SwiftUI

/// The mark: a point and the waves it sends out. Static version for icons,
/// tabs and the wordmark; `LiveRipple` animates it while someone is on air.
struct RippleMark: View {
    var size: CGFloat = 24
    var color: Color = AppColors.primary
    /// 0 rings = just the dot (tiny sizes), 2 = the full mark.
    var rings: Int = 2

    var body: some View {
        ZStack {
            if rings >= 2 {
                Circle()
                    .stroke(color.opacity(0.22), lineWidth: max(1.5, size * 0.045))
                    .frame(width: size, height: size)
            }
            if rings >= 1 {
                Circle()
                    .stroke(color.opacity(0.55), lineWidth: max(1.5, size * 0.045))
                    .frame(width: size * 0.64, height: size * 0.64)
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
    }
}

/// The mark, breathing: rings expand from the dot while live.
struct LiveRipple: View {
    var size: CGFloat = 44
    var color: Color = AppColors.primary

    @State private var animate = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if reduceMotion {
                // Still "on air", just not moving: two fixed rings.
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(color.opacity(index == 0 ? 0.45 : 0.18), lineWidth: 2)
                        .frame(width: size * 0.5, height: size * 0.5)
                        .scaleEffect(index == 0 ? 1.2 : 1.8)
                }
            } else {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: size * 0.5, height: size * 0.5)
                        .scaleEffect(animate ? 2.2 : 0.6)
                        .opacity(animate ? 0 : 0.9)
                        // One ring every 1.3 s: calm, not a siren.
                        .animation(
                            .easeOut(duration: 3.9)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 1.3),
                            value: animate
                        )
                }
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.36, height: size * 0.36)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            // Restart cleanly even when the view is re-inserted with its
            // state preserved (a same-value set would not animate).
            animate = false
            DispatchQueue.main.async { animate = true }
        }
        .onDisappear { animate = false }
    }
}

/// "melora" with the mark as its o.
struct MeloraWordmark: View {
    var size: CGFloat = 28
    var color: Color = AppColors.primaryText

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("mel")
                .font(.system(size: size, weight: .heavy))
                .kerning(-size * 0.05)
                .foregroundColor(color)
            RippleMark(size: size * 0.82)
                .padding(.horizontal, size * 0.04)
                .offset(y: size * 0.06)
            Text("ra")
                .font(.system(size: size, weight: .heavy))
                .kerning(-size * 0.05)
                .foregroundColor(color)
        }
        .accessibilityLabel("Melora")
    }
}

#Preview {
    VStack(spacing: 24) {
        MeloraWordmark(size: 40)
        HStack(spacing: 20) {
            RippleMark(size: 64)
            RippleMark(size: 24)
            RippleMark(size: 12, rings: 0)
            LiveRipple(size: 44)
        }
    }
    .padding(40)
    .melScreenBackground()
}
