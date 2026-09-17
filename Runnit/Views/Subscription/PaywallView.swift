import SwiftUI
import RevenueCat

struct PaywallView: View {
    @StateObject private var purchases = PurchaseService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackage: Package?
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    header
                    featureList
                    freeAccessCard
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(RunnitTheme.muted)
                }
            }
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(RunnitTheme.signal)
                .padding(.top, 16)

            Text("Runnit is free for athletes")
                .font(.system(size: 28, weight: .black, design: .rounded))

            Text("Track, connect, plan, and train with your crew without a subscription or paywall.")
                .font(.subheadline)
                .foregroundStyle(RunnitTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "record.circle", text: "Record and sync your training")
            FeatureRow(icon: "person.2.fill", text: "Join the community and challenges")
            FeatureRow(icon: "calendar", text: "Use plans, folders, races, and the journal")
            FeatureRow(icon: "heart.fill", text: "Connect your health and training devices")
        }
        .padding(20)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: RunnitTheme.radius).stroke(RunnitTheme.rule))
        .clipShape(RoundedRectangle(cornerRadius: RunnitTheme.radius))
    }

    private var freeAccessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Runnit earns")
                .font(.system(size: 18, weight: .black, design: .rounded))
            Text("Coaches can offer paid plans and services through Runnit. We earn a commission when a coach earns—athletes keep the core app free.")
                .font(.subheadline)
                .foregroundStyle(RunnitTheme.muted)
        }
        .padding(20)
        .background(RunnitTheme.yellow.opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: RunnitTheme.radius).stroke(RunnitTheme.rule))
    }

    private func packagePicker(offering: Offering) -> some View {
        VStack(spacing: 10) {
            ForEach(offering.availablePackages, id: \.identifier) { pkg in
                PackageCard(
                    package: pkg,
                    isSelected: selectedPackage?.identifier == pkg.identifier
                ) {
                    selectedPackage = pkg
                }
            }
        }
        .onAppear {
            if selectedPackage == nil {
                selectedPackage = offering.annual ?? offering.monthly ?? offering.availablePackages.first
            }
        }
    }

    private func subscribeButton(offering: Offering) -> some View {
        Button {
            guard let pkg = selectedPackage ?? offering.availablePackages.first else { return }
            Task {
                do {
                    try await purchases.purchase(pkg)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        } label: {
            Group {
                if purchases.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Start Free Trial")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RunnitTheme.signal)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: RunnitTheme.radius))
        }
        .disabled(purchases.isPurchasing)
    }

    private var restoreButton: some View {
        Button("Restore Purchases") {
            Task {
                do {
                    try await purchases.restorePurchases()
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(RunnitTheme.muted)
    }

    private var legalText: some View {
        Text("Subscription auto-renews. Cancel anytime in Settings. Payment charged to Apple ID on confirmation.")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(RunnitTheme.signal)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void

    private var isAnnual: Bool {
        package.packageType == .annual
    }

    private var label: String {
        switch package.packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        default: return package.storeProduct.localizedTitle
        }
    }

    private var savingsLabel: String? {
        guard isAnnual else { return nil }
        return "Best Value"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                        if let badge = savingsLabel {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(RunnitTheme.yellow)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(package.storeProduct.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 16, weight: .bold))
                    if isAnnual {
                        Text("per year")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("per month")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? RunnitTheme.signal.opacity(0.08) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? RunnitTheme.signal : RunnitTheme.rule, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
