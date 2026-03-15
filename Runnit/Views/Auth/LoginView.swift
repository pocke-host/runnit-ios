import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero
                VStack(spacing: 8) {
                    Text("RUNNIT")
                        .font(.system(size: 48, weight: .black))
                        .tracking(4)
                    Text("TRAIN SMARTER. RACE FASTER.")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
                .background(.black)
                .foregroundStyle(.white)

                // Form
                VStack(spacing: 16) {
                    VStack(spacing: 12) {
                        RunnitTextField(label: "EMAIL", text: $email, keyboardType: .emailAddress, autocapitalization: .never)
                        RunnitTextField(label: "PASSWORD", text: $password, isSecure: true)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button(action: login) {
                        ZStack {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("LOG IN")
                                    .font(.system(size: 13, weight: .semibold))
                                    .tracking(2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.black)
                        .foregroundStyle(.white)
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)

                    Button("Don't have an account? Join RUNNIT →") {
                        showRegister = true
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.black)
                    .padding(.top, 4)
                }
                .padding(24)

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .navigationDestination(isPresented: $showRegister) {
                RegisterView()
            }
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await auth.login(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
