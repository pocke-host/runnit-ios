import SwiftUI

// MARK: - Archetype definitions (client-side for display)

private struct ArchetypeOption: Identifiable {
    let id: String
    let label: String
    let tagline: String
    let icon: String
}

private let archetypes: [ArchetypeOption] = [
    ArchetypeOption(id: "THE_HYBRID_ATHLETE",    label: "The Hybrid Athlete",    tagline: "Multi-sport. No limits. All in.",             icon: "bolt.fill"),
    ArchetypeOption(id: "THE_ENDURANCE_BEAST",   label: "The Endurance Beast",   tagline: "You don't stop. You don't quit.",              icon: "flame.fill"),
    ArchetypeOption(id: "THE_EXPLORER",          label: "The Explorer",          tagline: "Every trail is a new story.",                  icon: "map.fill"),
    ArchetypeOption(id: "THE_COMPETITOR",        label: "The Competitor",        tagline: "PRs are personal. Podiums are better.",        icon: "trophy.fill"),
    ArchetypeOption(id: "THE_GRINDER",           label: "The Grinder",           tagline: "Consistent. Relentless. No excuses.",          icon: "gearshape.fill"),
]

// MARK: - OnboardingView

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var city = ""
    @State private var sport = "RUN"
    @State private var selectedArchetype: String?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let sports = ["RUN", "BIKE", "SWIM", "HIKE", "WALK", "OTHER"]

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            ProgressIndicator(currentStep: currentStep, totalSteps: 3)
                .padding(.top, 20)
                .padding(.horizontal, 24)

            TabView(selection: $currentStep) {
                WelcomeStep(onContinue: { withAnimation { currentStep = 1 } })
                    .tag(0)

                CityStep(
                    city: $city,
                    sport: $sport,
                    sports: sports,
                    onContinue: { withAnimation { currentStep = 2 } }
                )
                .tag(1)

                ArchetypeStep(
                    selectedArchetype: $selectedArchetype,
                    isLoading: isSaving,
                    errorMessage: errorMessage,
                    onFinish: completeOnboarding
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)
        }
        .background(Color(.systemBackground))
        .interactiveDismissDisabled() // prevent swipe-down dismissal
    }

    // MARK: - Complete onboarding

    private func completeOnboarding() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                struct OnboardingBody: Encodable {
                    let city: String?
                    let sport: String?
                }
                let updated: User = try await APIClient.shared.request(
                    "/auth/onboarding",
                    method: "POST",
                    body: OnboardingBody(
                        city: city.trimmingCharacters(in: .whitespaces).isEmpty ? nil : city.trimmingCharacters(in: .whitespaces),
                        sport: sport
                    )
                )
                auth.currentUser = updated
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Progress Indicator

private struct ProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentStep ? Color.black : Color(.systemGray4))
                    .frame(height: 4)
                    .animation(.easeInOut, value: currentStep)
            }
        }
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("RUNNIT")
                    .font(.system(size: 52, weight: .black))
                    .tracking(4)

                Rectangle()
                    .fill(.black)
                    .frame(width: 40, height: 3)

                Text("Your run crew,\nin an app.")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("Connect with athletes, find your crew, and track what matters.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()

            Button(action: onContinue) {
                Text("Let's Get Started")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 2: City + Sport

private struct CityStep: View {
    @Binding var city: String
    @Binding var sport: String
    let sports: [String]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where do you run?")
                        .font(.system(size: 30, weight: .black))
                    Text("We'll find your local crew.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 20) {
                    // City field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR CITY")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Austin", text: $city)
                            .font(.system(size: 16))
                            .padding(14)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }

                    // Sport picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PRIMARY SPORT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                            ForEach(sports, id: \.self) { s in
                                Button {
                                    sport = s
                                } label: {
                                    Text(s)
                                        .font(.system(size: 14, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(sport == s ? Color.black : Color(.systemGray6))
                                        .foregroundStyle(sport == s ? Color.white : Color.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onContinue) {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

// MARK: - Step 3: Archetype

private struct ArchetypeStep: View {
    @Binding var selectedArchetype: String?
    let isLoading: Bool
    let errorMessage: String?
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Here's your athlete identity.")
                    .font(.system(size: 28, weight: .black))
                Text("Pick the archetype that's you.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 32)

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(archetypes) { option in
                        ArchetypeCard(
                            option: option,
                            isSelected: selectedArchetype == option.id
                        )
                        .onTapGesture {
                            selectedArchetype = option.id
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 120) // leave room for button
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: onFinish) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        } else {
                            Text("Let's Go")
                                .font(.system(size: 17, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(.black)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }
}

// MARK: - ArchetypeCard

private struct ArchetypeCard: View {
    let option: ArchetypeOption
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white : Color(.systemGray5))
                    .frame(width: 48, height: 48)
                Image(systemName: option.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.black : Color(.systemGray))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(option.label)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(option.tagline)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color(.systemGray3) : .secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(isSelected ? Color.black : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
