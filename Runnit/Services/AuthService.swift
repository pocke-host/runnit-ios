import Foundation
import Combine

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: User?
    @Published var isLoggedIn = false
    @Published var isLoading = true

    private let api = APIClient.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Listen for 401s from any request
        NotificationCenter.default.publisher(for: .apiUnauthorized)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.logout() }
            .store(in: &cancellables)

        Task { await restoreSession() }
    }

    // MARK: - Session restore

    func restoreSession() async {
        guard KeychainHelper.token != nil else {
            isLoading = false
            return
        }
        do {
            let user: User = try await api.request("/auth/me", authenticated: true)
            currentUser = user
            isLoggedIn = true
        } catch {
            KeychainHelper.token = nil
        }
        isLoading = false
    }

    // MARK: - Login

    func login(email: String, password: String) async throws {
        struct LoginBody: Encodable { let email: String; let password: String }
        struct LoginResponse: Decodable { let token: String; let user: User }

        let resp: LoginResponse = try await api.request(
            "/auth/login",
            method: "POST",
            body: LoginBody(email: email, password: password),
            authenticated: false
        )
        KeychainHelper.token = resp.token
        currentUser = resp.user
        isLoggedIn = true
    }

    // MARK: - Register

    func register(email: String, password: String, displayName: String, username: String) async throws {
        struct RegisterBody: Encodable {
            let email, password, displayName, user: String
        }
        struct RegisterResponse: Decodable { let token: String; let user: User }

        let resp: RegisterResponse = try await api.request(
            "/auth/register",
            method: "POST",
            body: RegisterBody(email: email, password: password, displayName: displayName, user: username),
            authenticated: false
        )
        KeychainHelper.token = resp.token
        currentUser = resp.user
        isLoggedIn = true
    }

    // MARK: - Logout

    func logout() {
        KeychainHelper.token = nil
        currentUser = nil
        isLoggedIn = false
    }

    // MARK: - Update profile

    func updateProfile(displayName: String?, bio: String?, location: String?, sport: String?) async throws {
        struct UpdateBody: Encodable {
            let displayName: String?
            let bio: String?
            let location: String?
            let sport: String?
        }
        let updated: User = try await api.request(
            "/users/me",
            method: "PATCH",
            body: UpdateBody(displayName: displayName, bio: bio, location: location, sport: sport)
        )
        currentUser = updated
    }
}
