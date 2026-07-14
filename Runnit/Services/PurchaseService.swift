import Foundation
import RevenueCat

@MainActor
final class PurchaseService: ObservableObject {
    static let shared = PurchaseService()

    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isPurchasing = false
    @Published var errorMessage: String?

    var isPremium: Bool {
        customerInfo?.entitlements["premium"]?.isActive == true
    }

    var activeTier: String? {
        guard let entitlements = customerInfo?.entitlements.active else { return nil }
        if entitlements["duo"] != nil { return "duo" }
        if entitlements["premium"] != nil { return "premium" }
        return nil
    }

    private init() {}

    // MARK: - Setup

    static func configure(apiKey: String) {
        Purchases.configure(withAPIKey: apiKey)
        Purchases.logLevel = .warn
    }

    func login(userId: String) async {
        do {
            let (info, _) = try await Purchases.shared.logIn(userId)
            customerInfo = info
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            customerInfo = try await Purchases.shared.logOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch

    func fetchOfferings() async {
        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase

    func purchase(_ package: Package) async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        let result = try await Purchases.shared.purchase(package: package)
        customerInfo = result.customerInfo
        if !result.userCancelled {
            await syncWithBackend()
        }
    }

    func restorePurchases() async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        customerInfo = try await Purchases.shared.restorePurchases()
        await syncWithBackend()
    }

    // MARK: - Backend sync

    private func syncWithBackend() async {
        guard let token = KeychainHelper.token else { return }
        let apiUrl = Bundle.main.object(forInfoDictionaryKey: "API_URL") as? String ?? "https://api.runnit.app/api"
        guard let url = URL(string: "\(apiUrl)/billing/revenuecat-sync") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        _ = try? await URLSession.shared.data(for: req)
    }
}
