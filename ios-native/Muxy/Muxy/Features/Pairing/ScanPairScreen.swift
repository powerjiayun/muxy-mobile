import SwiftUI

struct ScanPairScreen: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Palette.accent)
            Text("QR pairing arrives in Phase 5")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Camera scanning with AVCaptureSession is wired up in a later phase. For now, use manual entry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Scan pairing QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close")
            }
        }
    }
}

#Preview {
    NavigationStack {
        ScanPairScreen()
    }
}
