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
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.secondary)

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
            .background(Color(.systemGray6))
            .overlay(Rectangle().stroke(Color(.systemGray4), lineWidth: 1))
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .tracking(2)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(configuration.isPressed ? Color(.systemGray) : .black)
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
