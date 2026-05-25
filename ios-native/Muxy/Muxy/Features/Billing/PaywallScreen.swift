import SwiftUI

struct PaywallScreen: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.Palette.accent)
            Text("Muxy Pro")
                .font(.title.weight(.semibold))
            Text("StoreKit purchase flow arrives in Phase 11.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding()
        .navigationTitle("Paywall")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PaywallScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
