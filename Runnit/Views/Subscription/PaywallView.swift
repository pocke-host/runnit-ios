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
                    if let offering = purchases.offerings?.current {
                        packagePicker(offering: offering)
                        subscribeButton(offering: offering)
                    } else {
                        ProgressView()
                            .padding(.top, 40)
                    }
                    restoreButton
                    legalText
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task { await purchases.fetchOfferings() }
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
                .foregroundStyle(.orange)
                .padding(.top, 16)

            Text("Go Premium")
                .font(.system(size: 28, weight: .black))

            Text("Unlock the full Runnit experience")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced performance analytics")
            FeatureRow(icon: "figure.run.circle.fill", text: "AI-powered training plans")
            FeatureRow(icon: "person.2.fill", text: "Club creation & coaching tools")
            FeatureRow(icon: "trophy.fill", text: "Unlimited challenges & leaderboards")
            FeatureRow(icon: "waveform.path.ecg", text: "HR zone analysis & recovery insights")
        }
        .padding(20)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
            .background(Color.orange)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
        .foregroundStyle(.secondary)
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
                .foregroundStyle(.orange)
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
                                .background(Color.orange)
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
            .background(isSelected ? Color.orange.opacity(0.08) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
