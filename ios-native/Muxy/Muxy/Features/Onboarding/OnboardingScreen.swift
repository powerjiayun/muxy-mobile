import SwiftUI

struct OnboardingScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var index: Int = 0

    private let slides: [OnboardingSlide] = [
        .logo(
            title: "Welcome to Muxy",
            body: "The remote control for your desktop terminal. Drive sessions, switch projects, and ship changes from your phone."
        ),
        .list(
            title: "How it works",
            rows: [
                OnboardingRow(symbol: "wifi", title: "Same network", body: "Your phone and desktop talk directly over your local network."),
                OnboardingRow(symbol: "switch.2", title: "Enable the Mobile server", body: "On your desktop: Muxy → Settings → Mobile, then toggle the server on."),
                OnboardingRow(symbol: "bolt.fill", title: "Stay in sync", body: "Open projects, run commands, and review changes in real time.")
            ]
        ),
        .hero(
            symbol: "key.fill",
            title: "Pair your desktop",
            body: "Enter your desktop’s IP address and the port shown in Muxy’s Mobile settings. Default port is 4865."
        )
    ]

    private var isLast: Bool { index == slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $index) {
                ForEach(Array(slides.enumerated()), id: \.offset) { offset, slide in
                    slideView(slide)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button("Skip", action: skip)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .accessibilityLabel("Skip onboarding")
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.md)
    }

    private var footer: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<slides.count, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? Theme.Palette.accent : Color.secondary.opacity(0.3))
                        .frame(width: i == index ? 22 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: index)
                }
            }
            Button(action: advance) {
                Text(isLast ? "Pair your desktop" : "Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
    }

    @ViewBuilder
    private func slideView(_ slide: OnboardingSlide) -> some View {
        switch slide {
        case .logo(let title, let body):
            VStack(spacing: Theme.Spacing.lg) {
                Image("MuxyLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .hero(let symbol, let title, let body):
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(Theme.Palette.accent, in: RoundedRectangle(cornerRadius: 24))
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .list(let title, let rows):
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                VStack(spacing: Theme.Spacing.lg) {
                    ForEach(rows) { row in
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: row.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.Palette.accent)
                                .frame(width: 44, height: 44)
                                .background(Theme.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                                )
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text(row.title)
                                    .font(.body.weight(.semibold))
                                Text(row.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func advance() {
        if isLast {
            environment.markOnboardingComplete()
            router.present(.addDevice)
            return
        }
        withAnimation { index += 1 }
    }

    private func skip() {
        environment.markOnboardingComplete()
    }
}

private enum OnboardingSlide {
    case logo(title: String, body: String)
    case hero(symbol: String, title: String, body: String)
    case list(title: String, rows: [OnboardingRow])
}

private struct OnboardingRow: Identifiable {
    let symbol: String
    let title: String
    let body: String
    var id: String { title }
}

#Preview {
    OnboardingScreen()
        .environment(AppEnvironment())
        .environment(AppRouter())
}
