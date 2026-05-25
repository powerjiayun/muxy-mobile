import MuxyCore
import SwiftUI

struct DevicesScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppRouter.self) private var router

    @State private var deviceToDelete: DeviceRecord?

    var body: some View {
        Group {
            if environment.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    router.present(.settings)
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.present(.addDevice)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add device")
            }
        }
        .confirmationDialog(
            deviceToDelete?.label ?? "",
            isPresented: Binding(
                get: { deviceToDelete != nil },
                set: { newValue in
                    if !newValue { deviceToDelete = nil }
                }
            ),
            titleVisibility: .visible,
            presenting: deviceToDelete
        ) { record in
            Button("Remove", role: .destructive) {
                Task { await environment.removeDevice(id: record.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Remove this device?")
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("No devices yet")
                .font(.title3.weight(.semibold))
            Text("Tap the + icon to add your first Muxy desktop.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    private var deviceList: some View {
        List {
            ForEach(environment.devices) { record in
                DeviceRow(record: record)
                    .listRowBackground(Theme.Palette.surface)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deviceToDelete = record
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deviceToDelete = record
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.Palette.background.ignoresSafeArea())
    }
}

private struct DeviceRow: View {
    let record: DeviceRecord

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 20))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 36, height: 36)
                .background(Theme.Palette.background, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.label)
                    .font(.body.weight(.medium))
                Text("\(record.host):\(record.port)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DevicesScreen()
    }
    .environment(AppEnvironment())
    .environment(AppRouter())
}
