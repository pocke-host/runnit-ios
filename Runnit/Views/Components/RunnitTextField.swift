import SwiftUI

struct RunnitTextField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(RunnitTheme.muted)

            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                        .autocorrectionDisabled()
                }
            }
            .font(.system(size: 16))
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(Color.white)
            .overlay(Rectangle().stroke(RunnitTheme.rule, lineWidth: 1))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RunnitPrimaryButtonStyle().makeBody(configuration: configuration)
    }
}
