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

        // Post to backend callback endpoint — the backend already handles state verification
        let provider = url.pathComponents.dropFirst().first ?? ""
        Task {
            try? await APIClient.shared.requestVoid(
                "/integrations/\(provider)/callback?code=\(code)&state=\(state)",
                method: "GET"
            )
        }
    }
}
