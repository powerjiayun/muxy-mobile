# Migrate Muxy Mobile To Native iOS

## Goal

Rewrite the current Expo React Native iOS app as a native Swift iOS app first, using standard Apple APIs and SwiftTerm for terminal rendering. Keep the Expo app working during the migration. Migrate in small, testable phases so each phase can be installed, tested, and reviewed before continuing.

Android should be treated as a later Kotlin rewrite. This plan focuses only on native iOS.

## Current App Scope

The current Expo app includes:

- Device list and saved device state.
- Bonjour/mDNS discovery for `_muxy._tcp`.
- Manual pairing and QR pairing.
- WebSocket transport with request/response/event protocol.
- Device authentication, pairing, reconnect, and app-state reconnect behavior.
- Project list.
- Workspace and tab state.
- Terminal takeover, release, resize, input, output, and snapshots.
- Terminal rendering through WebView and xterm.js.
- Git/VCS screens and actions.
- Settings, theme handling, and onboarding.
- Billing, trial, paywall, and in-app purchase handling.
- Demo mode and demo backend.

## Native Replacement Map

- `react-native-zeroconf` -> `Network.NWBrowser` with Bonjour.
- `react-native-webview` and xterm.js -> SwiftTerm.
- `AsyncStorage` -> Codable storage backed by `UserDefaults` or app files.
- `expo-secure-store` -> Keychain.
- `expo-camera` QR scanning -> `AVFoundation`.
- `react-native-iap` -> StoreKit 2.
- `expo-router` -> SwiftUI `NavigationStack`.
- Zustand stores -> Swift observable view models, services, and actors.
- React Native app lifecycle bindings -> SwiftUI scene phase and UIKit lifecycle hooks where needed.

## Recommended Native Architecture

Use a SwiftUI-first app with explicit service boundaries.

```text
ios-native/
  Muxy/
    App/
      MuxyApp.swift
      AppEnvironment.swift
      AppRouter.swift

    Core/
      Models/
      Protocol/
      Persistence/
      Security/
      Networking/
      Discovery/

    Features/
      Onboarding/
      Devices/
      Pairing/
      Projects/
      Workspace/
      Terminal/
      Git/
      Billing/
      Settings/

    DesignSystem/
      Theme/
      Components/

  MuxyTests/
  MuxyUITests/
```

Core choices:

- UI: SwiftUI.
- Terminal: SwiftTerm.
- Async model: async/await and AsyncStream.
- WebSocket: URLSessionWebSocketTask.
- Reconnect: dedicated connection service with backoff.
- Persistence: Codable repositories.
- Secrets: Keychain.
- Discovery: NWBrowser.
- Billing: StoreKit 2.
- QR scanning: AVCaptureSession.

Avoid:

- Embedding the old web terminal as a fallback.
- Reusing JavaScript inside native iOS.
- Hybrid bridge layers.
- Copying Expo storage formats unless persisted production migration is explicitly required.

## Phase 0: Protocol And Migration Prep

Goal: define the native contract before UI work.

Build:

- Swift Codable models matching `src/transport/protocol.ts`.
- Request, response, and event envelope types.
- Method names and event names.
- Error model matching current WebSocket errors.
- JSON fixtures based on real Muxy frames.

Testable checkpoint:

- Unit tests decode response and event envelopes.
- Unit tests encode native requests matching the current JSON shape.
- Unit tests cover representative protocol models: projects, workspace, terminal output, terminal snapshot, pane ownership, and VCS data.

Acceptance:

- Swift protocol models round-trip the same JSON shape used by the Expo app.
- No UI is required yet.

## Phase 1: Native iOS Skeleton

Goal: create an installable native app with the correct app identity and navigation shell.

Build:

- New native iOS project under `ios-native/`.
- SwiftUI app shell.
- App environment and dependency container.
- Placeholder screens for onboarding, devices, add device, projects, workspace, settings, and paywall.
- Basic native theme tokens.
- Required plist entries:
  - `NSLocalNetworkUsageDescription`.
  - `NSBonjourServices` with `_muxy._tcp`.
  - App Transport Security local networking allowance if needed.

Testable checkpoint:

- App builds and runs on simulator and device.
- Navigation works between placeholder screens.
- Light and dark appearance work.

Acceptance:

- The native app can be installed and navigated without Expo.

## Phase 2: Persistence And Secure Local State

Goal: store local device and settings state safely.

Build:

- `DeviceRepository`.
- `SettingsRepository`.
- `InstallIdentityService`.
- Keychain token storage.
- Codable persisted models for devices, install device ID, last applied theme, and settings.

Testable checkpoint:

- Add, edit, and delete mock devices locally.
- Restart the app and verify devices/settings persist.
- Verify install token is stored in Keychain, not plain app preferences.

Acceptance:

- Device list state survives relaunch.
- Sensitive token data is stored only in Keychain.

## Phase 3: WebSocket Transport And Pairing

Goal: connect to a known Muxy desktop manually and authenticate.

Build:

- `MuxyWebSocketClient` using URLSessionWebSocketTask.
- Request ID generation.
- Pending request map and timeout handling.
- Response routing.
- Event stream.
- Connection state stream.
- Error mapping.
- Reconnect backoff.
- Foreground/background connection handling.
- Manual pairing and authentication.

Native equivalents:

- `src/transport/WSClient.ts`.
- `src/transport/reconnect.ts`.
- `src/transport/events.ts`.
- `src/transport/errors.ts`.
- `src/state/connection.ts`.
- `src/state/pair.ts`.

Testable checkpoint:

- Manual host/port screen connects to a desktop.
- Pairing flow works.
- Authenticated reconnect works after app restart.
- Turning the desktop server off shows disconnected or reconnecting state.
- Turning the desktop server back on reconnects.

Acceptance:

- Native iOS can pair and authenticate without Expo.

## Phase 4: Bonjour Discovery

Goal: discover nearby Muxy desktops natively.

Build:

- `DiscoveryService` using NWBrowser.
- Browse `_muxy._tcp`.
- Resolve service name to host and port.
- Display nearby devices on Add Device.
- Update a saved device host/port when its saved Bonjour service resolves to a new address.

Testable checkpoint:

- Add Device screen lists nearby Muxy desktops.
- Selecting a discovered device fills name, host, and port.
- A previously saved service reconnects after its IP changes.

Acceptance:

- Manual entry and Bonjour discovery both work natively.

## Phase 5: QR Pairing

Goal: replace Expo camera QR pairing with native camera scanning.

Build:

- QR scanner view using AVCaptureSession.
- Pair URI parser ported from `src/state/pairUri.ts`.
- Camera permission flow.
- Invalid QR error state.
- Valid QR route into Add Device with auto-pairing.

Testable checkpoint:

- Camera permission prompt appears.
- Invalid QR code shows an error.
- Valid Muxy pairing QR starts pairing automatically.

Acceptance:

- QR pairing matches current Expo behavior.

## Phase 6: Project List

Goal: after connection, show real projects.

Build:

- `ProjectService`.
- `ProjectsViewModel`.
- Native projects screen.
- `listProjects` request.
- `projectsChanged` event handling.
- Optional project logo loading can be deferred unless needed for parity.

Testable checkpoint:

- Connect to a paired desktop.
- Project list loads.
- Pull-to-refresh or refresh action reloads projects.
- Desktop-side project changes update the native app.

Acceptance:

- Native iOS can browse connected desktop projects.

## Phase 7: Workspace And Tabs

Goal: show workspace and tab structure, then support selecting and creating terminal tabs.

Build:

- `WorkspaceService`.
- `WorkspaceViewModel`.
- Swift helpers equivalent to `src/state/workspaceTree.ts` and `src/state/workspaceCommands.ts`.
- Workspace screen.
- Tab strip.
- Active tab selection.
- Create terminal tab action.
- `getWorkspace`, `selectTab`, and `createTab` requests.
- `workspaceChanged` event handling.

Testable checkpoint:

- Open a project.
- See tabs.
- Switch tabs.
- Create a terminal tab.
- Native app reflects desktop workspace changes.

Acceptance:

- Workspace navigation works without terminal rendering yet.

## Phase 8: SwiftTerm Terminal MVP

Goal: replace WebView and xterm.js with native SwiftTerm.

Build:

- Terminal feature using SwiftTerm.
- SwiftUI wrapper around SwiftTerm terminal view.
- `PaneSessionController` for takeover, release, resize, snapshot, and streaming state.
- Base64 byte handling for terminal input and output.
- Terminal dimension calculation for columns and rows.
- `takeOverPane`, `releasePane`, `terminalInput`, and `terminalResize` requests.
- `terminalOutput`, `terminalSnapshot`, and `paneOwnershipChanged` event handling.

Design rule:

- Keep WebSocket logic out of the terminal view.
- Keep terminal ownership/session logic out of generic workspace UI.
- The terminal view should expose only rendering, input, resize, focus, and theme operations.

Testable checkpoint:

- Open a terminal tab.
- SwiftTerm renders shell output.
- Typing sends input to the desktop.
- Rotation or size changes send `terminalResize`.
- Leaving the screen releases the pane.
- Reopening the terminal takes over the pane again.

Acceptance:

- Basic terminal interaction works end-to-end natively.

## Phase 9: Terminal Polish

Goal: make the native terminal usable for daily work.

Build:

- Keyboard focus behavior.
- Accessory key bar equivalent to the current `KeyBar`.
- Escape, tab, arrows, control, and modifier handling.
- New terminal shortcut.
- Tab selection shortcuts.
- Ownership lost overlay.
- Take-over retry overlay.
- Reconnecting banner.
- Desktop terminal theme mapping.
- Nerd Font strategy.

Nerd Font options:

- Bundle a supported font if the license allows.
- Defer dynamic font loading for the MVP.
- Avoid runtime font downloads unless there is a strong product reason.

Testable checkpoint:

- Special keys work.
- Terminal colors match desktop theme.
- Ownership loss from desktop is handled.
- Reconnect does not corrupt the terminal session.

Acceptance:

- Native terminal UX is close enough to replace the current Expo terminal for beta testing.

## Phase 10: Git And VCS Screens

Goal: migrate Git functionality after terminal core is stable.

Build native equivalents for:

- Overview.
- Branches.
- Worktrees.
- Commit.
- Pull request.
- Create PR.
- File diff.

Requests:

- `getVCSStatus`.
- `vcsRefresh`.
- `vcsCommit`.
- `vcsPush`.
- `vcsPull`.
- `vcsStageFiles`.
- `vcsUnstageFiles`.
- `vcsDiscardFiles`.
- `vcsListBranches`.
- `vcsSwitchBranch`.
- `vcsCreateBranch`.
- `vcsCreatePR`.
- `vcsMergePullRequest`.
- `vcsAddWorktree`.
- `vcsRemoveWorktree`.
- `vcsGetDiff`.

Testable checkpoint:

- View status.
- Stage and unstage files.
- Commit.
- Push and pull.
- Switch branch.
- View diff.
- Create and remove worktrees.

Acceptance:

- Native Git functionality reaches current app parity.

## Phase 11: Billing And Trial

Goal: replace React Native IAP with StoreKit 2.

Build:

- `BillingService`.
- `EntitlementStore`.
- Product loading.
- Purchase flow.
- Restore purchases.
- Transaction listener.
- Trial logic if trial remains local.
- Paywall screen.

Testable checkpoint:

- StoreKit local testing config works.
- Product loads.
- Purchase unlocks entitlement.
- Restore works.
- Expired trial shows paywall.

Acceptance:

- Native billing behavior matches production requirements.

## Phase 12: Settings, Onboarding, And Final Parity

Goal: finish non-core UX and app behavior.

Build:

- Settings screen.
- Onboarding screen.
- Theme mode preferences.
- Auto-focus terminal preference.
- Demo mode decision: port native demo backend or drop demo mode from native MVP.
- App icon and splash equivalents.
- iPad layout pass.

Testable checkpoint:

- Fresh install shows onboarding.
- Existing settings persist.
- Settings affect workspace and terminal behavior.
- iPhone and iPad layouts are acceptable.

Acceptance:

- Native app is feature-complete enough for TestFlight.

## Phase 13: Hardening And TestFlight

Goal: prepare native iOS for external testing.

Build and verify:

- Unit tests for protocol, URI parser, storage, reconnect backoff, and workspace helpers.
- Integration tests for WebSocket client against a local mock server.
- Manual QA checklist.
- App Store privacy strings.
- Local network permission behavior.
- Background and foreground reconnect behavior.
- Poor network behavior.
- Terminal memory and performance.
- StoreKit sandbox.
- Crash and logging strategy.

Testable checkpoint:

- TestFlight build installs on a real device.
- App connects to a real desktop over LAN.
- Terminal is usable for long sessions.
- Billing works in sandbox.
- No Expo dependency exists in the native app.

Acceptance:

- Native iOS app can replace Expo iOS for beta users.

## Recommended Execution Order

Do not start with terminal rendering. The safest order is:

1. Native shell.
2. Protocol and transport.
3. Pairing and discovery.
4. Projects and workspace.
5. SwiftTerm terminal.
6. Git.
7. Billing, settings, onboarding, and polish.

This gives useful feedback early: first whether the native app can connect, then whether it can show real workspace data, then whether SwiftTerm can handle the terminal UX.

## First Concrete Milestone

Build the smallest useful native iOS milestone:

- Create `ios-native/` SwiftUI app.
- Add protocol models.
- Add WebSocket client.
- Add manual Add Device screen.
- Pair and authenticate with host and port.
- Show connection state.

This proves the hardest foundation before investing in full UI parity.
