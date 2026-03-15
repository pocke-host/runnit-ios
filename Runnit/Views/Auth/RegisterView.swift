import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Create account")
                        .font(.system(size: 28, weight: .black))
                    Text("Join the community")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(spacing: 12) {
                    RunnitTextField(label: "DISPLAY NAME", text: $displayName)
                    RunnitTextField(label: "USERNAME", text: $username, autocapitalization: .never)
                    RunnitTextField(label: "EMAIL", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                    RunnitTextField(label: "PASSWORD", text: $password, isSecure: true)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: register) {
                    ZStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("JOIN RUNNIT")
                                .font(.system(size: 13, weight: .semibold))
                                .tracking(2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(.black)
                    .foregroundStyle(.white)
                }
                .disabled(isLoading || email.isEmpty || password.isEmpty || displayName.isEmpty || username.isEmpty)
            }
            .padding(24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func register() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await auth.register(email: email, password: password, displayName: displayName, username: username)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
