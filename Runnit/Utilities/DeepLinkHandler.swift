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
        // e.g. runnit://oauth/strava?code=abc&state=xyz
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let code  = components?.queryItems?.first(where: { $0.name == "code" })?.value
        let state = components?.queryItems?.first(where: { $0.name == "state" })?.value

        guard let code, let state else { return }

        // POST to mobile-callback endpoint with code + state in body (not URL params)
        let provider = url.pathComponents.dropFirst().first ?? ""
        struct OAuthBody: Encodable { let code: String; let state: String }
        Task {
            do {
                try await APIClient.shared.requestVoid(
                    "/integrations/\(provider)/mobile-callback",
                    method: "POST",
                    body: OAuthBody(code: code, state: state)
                )
            } catch {
                print("[DeepLink] OAuth callback failed for \(provider): \(error.localizedDescription)")
            }
        }
    }
}
