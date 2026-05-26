import AVFoundation
import MuxyProtocol
import SwiftUI
import UIKit

struct ScanPairScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router

    @State private var status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var error: String?

    var body: some View {
        ZStack {
            content
        }
        .background(Theme.Palette.background.ignoresSafeArea())
        .navigationTitle("Scan pairing QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Close")
            }
        }
        .task {
            if status == .notDetermined {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                status = granted ? .authorized : .denied
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch status {
        case .authorized:
            scannerLayer
        case .notDetermined:
            ProgressView()
        case .denied, .restricted:
            permissionDeniedView
        @unknown default:
            permissionDeniedView
        }
    }

    private var scannerLayer: some View {
        ZStack {
            QRScannerView { payload in
                handle(payload: payload)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                if let error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.red.opacity(0.85), in: Capsule())
                        .padding(.bottom, Theme.Spacing.lg)
                } else {
                    Text("Point your camera at the QR code shown in Muxy › Settings › Mobile.")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Theme.Radius.md))
                        .padding(.bottom, Theme.Spacing.xl)
                        .padding(.horizontal, Theme.Spacing.lg)
                }
            }
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Camera access is off.")
                .font(.title3.weight(.semibold))
            Text("Enable camera access in Settings → Muxy to scan pairing QR codes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handle(payload: String) {
        guard let parsed = PairURIParser.parse(payload) else {
            error = "That QR code isn't a Muxy pairing code."
            return
        }
        router.pendingScanResult = parsed
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ScanPairScreen()
    }
    .environment(AppRouter())
}
