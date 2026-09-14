import SwiftUI

/// The native companion to the web app's RUNNIT design tokens.
enum RunnitTheme {
    static let canvas = Color(red: 0.984, green: 0.965, blue: 0.925) // #FBF6EC
    static let ink = Color(red: 0.086, green: 0.075, blue: 0.059) // #16130F
    static let signal = Color(red: 0.165, green: 0.333, blue: 0.961) // #2A55F5
    static let signalPressed = Color(red: 0.118, green: 0.259, blue: 0.839)
    static let yellow = Color(red: 1.0, green: 0.831, blue: 0.278) // #FFD447
    static let rule = Color(red: 0.906, green: 0.875, blue: 0.808) // #E7DFCE
    static let muted = Color(red: 0.38, green: 0.35, blue: 0.31)
    static let success = Color(red: 0.10, green: 0.56, blue: 0.30)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 0
    static let controlRadius: CGFloat = 6
}

struct RunnitPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .tracking(1.2)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(configuration.isPressed ? RunnitTheme.signalPressed : RunnitTheme.signal)
            .foregroundStyle(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: RunnitTheme.controlRadius))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct RunnitSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(RunnitTheme.signal)
    }
}

struct RunnitCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(Color.white)
            .overlay(Rectangle().stroke(RunnitTheme.rule, lineWidth: 1))
    }
}
