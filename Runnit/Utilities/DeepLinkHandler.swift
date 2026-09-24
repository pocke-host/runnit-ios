import Foundation

enum DeepLinkHandler {
    /// Handles runnit:// deep links (OAuth callbacks, universal links)
    static func handle(_ url: URL) {
        guard url.scheme == "runnit" else { return }

        switch url.host {
        case "oauth":
            handleOAuth(url)
        default:
            break
        }
    }

    private static func handleOAuth(_ url: URL) {
        // e.g. runnit://oauth/coros?code=abc&state=xyz
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code  = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value
        let provider = url.pathComponents.dropFirst().first ?? ""

        guard let code, let state, !code.isEmpty, !state.isEmpty else {
            NotificationCenter.default.post(name: .oauthCallbackFailed, object: nil, userInfo: ["provider": provider, "reason": "missing_code_or_state"])
            return
        }

        guard let path = callbackPath(for: provider) else {
            NotificationCenter.default.post(name: .oauthCallbackFailed, object: nil, userInfo: ["provider": provider, "reason": "unsupported_provider"])
            return
        }

        // POST to mobile-callback endpoint with code + state in body (not URL params)
        struct OAuthBody: Encodable { let code: String; let state: String }
        Task {
            do {
                try await APIClient.shared.requestVoid(
                    path,
                    method: "POST",
                    body: OAuthBody(code: code, state: state)
                )
                await MainActor.run { NotificationCenter.default.post(name: .oauthCallbackCompleted, object: nil, userInfo: ["provider": provider]) }
            } catch {
                print("[DeepLink] OAuth callback failed for \(provider): \(error.localizedDescription)")
                await MainActor.run { NotificationCenter.default.post(name: .oauthCallbackFailed, object: nil, userInfo: ["provider": provider, "reason": error.localizedDescription]) }
            }
        }
    }

    private static func callbackPath(for provider: String) -> String? {
        switch provider.lowercased() {
        case "spotify": return "/spotify/mobile-callback"
        case "runsignup": return "/integrations/runsignup/oauth/mobile-callback"
        case "google-calendar": return "/integrations/google-calendar/mobile-callback"
        case "whoop", "oura", "fitbit", "strava": return "/integrations/\(provider.lowercased())/mobile-callback"
        default: return nil
        }
    }
}

extension Notification.Name {
    static let oauthCallbackCompleted = Notification.Name("RunnitOAuthCallbackCompleted")
    static let oauthCallbackFailed = Notification.Name("RunnitOAuthCallbackFailed")
}
