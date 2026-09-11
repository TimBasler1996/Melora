import SwiftUI

/// Melora's own line icons (Assets.xcassets/Icons, 24-grid, 1.8 pt stroke).
/// One style everywhere instead of mixed SF Symbol weights.
struct MIcon: View {
    let name: String
    var size: CGFloat = 20
    var color: Color = AppColors.primaryText

    init(_ name: String, size: CGFloat = 20, color: Color = AppColors.primaryText) {
        self.name = name
        self.size = size
        self.color = color
    }

    var body: some View {
        Image("icon-\(name)")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

/// Buttons sink slightly under the thumb. Used for every primary action.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// One-shot ripple: three rings leave the point once. Fired on a like, on
/// going live, on anything that "sends a signal".
struct RippleBurst: View {
    var size: CGFloat = 120
    var color: Color = AppColors.primary
    /// Change this value to fire the burst again.
    var trigger: Int

    @State private var fired = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .scaleEffect(fired ? 3.2 : 0.4)
                    .opacity(fired ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 0.9).delay(Double(index) * 0.12),
                        value: fired
                    )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            fired = false
            DispatchQueue.main.async { fired = true }
        }
        .onAppear {
            // Inserted and triggered in the same update: onChange won't
            // fire, so start from appearance too.
            fired = false
            DispatchQueue.main.async { fired = true }
        }
    }
}

/// Two-segment control in the house style: a cream pill on a dark track.
struct MeloraSegmentedControl<T: Hashable>: View {
    let options: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option, label in
                let selected = option == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option }
                } label: {
                    Text(label)
                        .font(.system(size: 14, weight: selected ? .heavy : .bold))
                        .foregroundColor(selected ? AppColors.background : AppColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selected ? AppColors.primaryText : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppColors.surface)
        )
    }
}
