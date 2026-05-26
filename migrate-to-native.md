# Migrate Muxy Mobile To Native iOS

## House Rules (read this first — written for sessions that start fresh per phase)

We work one phase at a time. Each phase opens with a fresh context. The user types something like *"implement phase 7 of migrate-to-native.md"* and you pick it up cold.

**Before writing code for phase N:**

1. **Read the memory file** at `~/.claude/projects/-Users-saeed-Projects-muxy-mobile/memory/project_native_migration.md` — it has the per-phase completion summary, key decisions, and any cross-phase notes left for you.
2. **Read this file's phase section** for the phase you're implementing — most phases now carry "What's already there" + "Notes for the implementer" subsections.
3. **Inspect the codebase before adding files.** What's already in `ios-native/MuxyCore/Sources/MuxyCore/`? What types exist in `ios-native/MuxyProtocol/Sources/MuxyProtocol/`? Don't duplicate.
4. **Honor the simplicity rule** ([[feedback-native-simplicity]]): no orphaned components, no defensive abstractions for cases that can't fire on iOS, no parallel state machines. Before adding new files, list anything from the prior phase that ended up unused and delete it in the same change.

**After implementing phase N:**

1. Update the memory file's phase status (mark N done, add a short DONE summary).
2. Add a "What's already there" section to phase N+1 in this file if there are non-obvious things the next session needs (e.g., "events() is multicast — don't add a second event bus", "MuxyCore is a separate Swift package — new types go there unless they're UI").
3. Run tests + build before declaring done. The user always asks "what to test" — provide a concise checklist.

**Bundle id, signing, and run scripts:** the simulator builds with `CODE_SIGNING_ALLOWED=NO`. There's a `InstallIdentityService` fallback for keychain error `-34018` (simulator without entitlements). Bundle id is `com.muxy.app` (same as the Expo app — this is intentional so the App Store update will land as an upgrade, not a new install). Don't change this.

**Tests:** `cd ios-native/MuxyCore && swift test` runs the Swift package tests. Phase-by-phase test counts are tracked in memory. The app target itself has no unit tests; tests live in MuxyCore.

**Run + smoke test:** `ios-native/scripts/run-mobile.sh restart` builds for iPhone 16e simulator and launches.

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

### What's already there (read before starting)

- `MuxyProtocol.Workspace`, `SplitNode`, `Split`, `TabArea`, `Tab`, `TabKind` are all defined in `ios-native/MuxyProtocol/Sources/MuxyProtocol/Models.swift` with round-trip tests in `Tests/MuxyProtocolTests/ModelTests.swift`. Don't redefine.
- `Method.getWorkspace`, `.createTab`, `.closeTab`, `.selectTab`, `.splitArea`, `.closeArea`, `.focusArea` already in `MethodsAndEvents.swift`.
- `EventName.workspaceChanged` already in `MethodsAndEvents.swift`.
- `MuxyWebSocketClient.events()` is **multicast** — multiple consumers OK. `ConnectionManager.waitForDrop` is one consumer; `ProjectsService` is another; you can subscribe a third for workspace events without breaking either.
- Pattern to copy: look at `ios-native/MuxyCore/Sources/MuxyCore/ProjectsService.swift`. Same shape applies — actor takes a client, calls `listProjects` equivalent (`getWorkspace`), subscribes to its event, emits via `AsyncStream<WorkspaceUpdate>`.
- `AppEnvironment` already has the pattern for spinning a per-connection service up on `.connected` and tearing it down on any other state. Just add `workspaceState` + `workspaceService` next to `projectsState` + `projectsService`. Tear down on disconnect.
- Routing: `AppRouter.AppRoute.workspace(deviceID:projectID:)` already exists. `WorkspaceScreen(deviceID:projectID:)` is a placeholder you'll replace.
- The Workspace screen is **inside the NavigationStack** below ProjectsScreen — you can push to terminal tabs via a route or render them inline. Recommend inline (workspace IS the tab strip + content) so Phase 8's terminal lives inside the same screen.

### Notes for the implementer

- Don't port the TS `workspaceTree.ts` helpers verbatim. Tab area selection logic is small — write Swift equivalents that match the Swift data model.
- Phase 8 will render a real terminal inside the active tab area. For Phase 7, the active terminal tab can show "(Phase 8 — terminal goes here)" placeholder content. Other tab kinds (vcs, editor, diffViewer) can show similar placeholders or "not yet supported."
- Keep the tab strip simple: horizontally scrolling pill row. Tap to switch via `selectTab`. Long-press → close via `closeTab`. New-tab "+" button creates a terminal tab via `createTab`.
- Workspace can have nested splits via `SplitNode.split(Split)`. **For Phase 7, render just the focused TabArea** (the one whose id matches `workspace.focusedAreaID`). Multi-area splits can wait — desktop multi-pane mobile UX is a Phase 9+ problem.

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

### What's already there (read before starting)

- `MuxyProtocol.TerminalOutput`, `TerminalSnapshot`, `TerminalCells`, `TerminalCell`, `PaneOwner`, `PaneOwnership` already in `Models.swift`.
- `Method.takeOverPane`, `.releasePane`, `.terminalInput`, `.terminalResize`, `.terminalScroll`, `.getTerminalContent` already in `MethodsAndEvents.swift`.
- `EventName.terminalOutput`, `.terminalSnapshot`, `.paneOwnershipChanged` already in `MethodsAndEvents.swift`.
- `MuxyWebSocketClient.events()` is multicast. Phase 7's `WorkspaceService` already consumes the events stream for `workspaceChanged` — you'll add a new consumer for terminal events.
- `Tab.paneID` is the join key between a tab in the workspace tree and its terminal pane.
- Phase 7 added `WorkspaceService` in MuxyCore (per-project actor, `stream() -> AsyncStream<WorkspaceUpdate>`, methods: `createTerminalTab`, `selectTab`, `closeTab`). It is started in `AppEnvironment.startWorkspace(projectID:)` when `WorkspaceScreen.task` fires and stopped in `onDisappear`. Same lifecycle pattern works for `PaneSessionController`.
- Workspace tree helpers live on `SplitNode`/`Workspace` extensions in `MuxyProtocol/WorkspaceTree.swift` — `findArea(id:)`, `flattenAreas()`, `workspace.focusedArea`. Use these to find the active tab's `paneID`.
- `WorkspaceScreen` renders `TabContentView` for the active tab. For a terminal tab it currently shows a "Phase 8" placeholder — replace `TabContentView`'s terminal branch with the SwiftTerm wrapper. The tab strip and create/select/close plumbing are already done; don't rebuild them.
- **Note on `Tab` naming collision**: `MuxyProtocol.Tab` clashes with `SwiftUI.Tab`. In any SwiftUI view that imports both, qualify as `MuxyProtocol.Tab`. WorkspaceScreen.swift already does this.

### Notes for the implementer

- Add **SwiftTerm as a Swift Package dependency** to `ios-native/Muxy/Muxy.xcodeproj`. URL: `https://github.com/migueldeicaza/SwiftTerm.git`. Pin to a version, don't track `main`. Reference the package in the pbxproj's `XCRemoteSwiftPackageReference` section (currently only local refs exist — you'll be the first to add a remote one; copy the structure from an Xcode-generated project).
- `PaneSessionController` lives in MuxyCore (alongside ProjectsService, WorkspaceService). Owns one paneID at a time. Calls `takeOverPane` on `attach(paneID:cols:rows:)`. Buffers incoming `terminalOutput` events. On detach, calls `releasePane`.
- **Terminal bytes are base64-encoded both ways.** Look at `src/transport/protocol.ts` for the exact shape: `terminalInput` sends `{ paneID, bytes: base64string }`. `terminalOutput` events arrive with the same shape. SwiftTerm's `Terminal.feed(byteArray:)` wants `[UInt8]` — decode the base64 first.
- SwiftTerm's `TerminalView` (UIKit) needs to be wrapped in a `UIViewRepresentable`. Existing pattern: `Muxy/Features/Pairing/QRScannerView.swift` is the closest analog in the codebase — UIViewControllerRepresentable but the wrapping shape is similar.
- **Don't use `terminalSnapshot` for the rendering path.** Snapshots are for catch-up: when we attach to a pane that's been running, the desktop sends a one-shot `terminalSnapshot` event with the current scrollback. Feed it once, then start consuming `terminalOutput` for live updates.
- Don't put the WebSocket client in the terminal view. The view receives bytes via a callback and emits input via a callback. `PaneSessionController` mediates.
- **Memory rule**: there are existing user-feedback memories about xterm.js input quirks (`feedback_terminal_input.md`, `feedback_terminal_input_sentinel.md`) — those are about the RN/WebView path. They do NOT apply to SwiftTerm. Read them to know they exist; ignore their guidance for the native terminal.

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

### What's already there (read before starting)

- Phase 8 built `PaneSessionController` and the SwiftTerm wrapper. This phase only adds chrome around them — no new transport.
- Reconnect banner was once a `DesignSystem/Components/ConnectionBanner.swift` (deleted in cleanup). If you need to bring it back, do it lightly — overlay above content on Devices/Projects/Workspace screens driven by `environment.connectionState`. Don't make it a multi-purpose component until you have a second use site.
- Theme mapping: `MuxyProtocol.DeviceTheme` (themeFg/themeBg/themePalette) is what the desktop sends in the `pairing` payload. `Pairing` is stored in `DeviceRecord.pairing`. Read theme palette from there to seed SwiftTerm colors. There's also `themeChanged` event for live updates.

### Notes for the implementer

- Look at the existing Expo `src/components/terminal/KeyBar.tsx` for the accessory bar key set (Esc/Tab/Ctrl/etc). Port the layout, not the implementation — SwiftUI buttons that emit byte sequences via the same input path.
- Tab selection shortcuts (Cmd+1..9): use `.keyboardShortcut` on hidden buttons in the workspace toolbar.
- Ownership-lost overlay: when `paneOwnershipChanged` event arrives with a different owner than us, show an overlay over the terminal saying "This pane is now controlled by {name}." with a "Take back" button that calls `takeOverPane` again.
- Take-over retry: if `takeOverPane` fails (server error, transient), show a retry button rather than auto-retrying. Phase 3's lifecycle backoff handles the WS-level reconnect; pane takeover is a separate concern.
- Nerd Font: bundle JetBrains Mono Nerd Font as a target resource. `SettingsRecord.useNerdFont` already exists (in MuxyCore) and is wired in Settings. Just need to actually swap the SwiftTerm font when the toggle changes.

Nerd Font options:

- Bundle a supported font if the license allows.
- Defer dynamic font loading for the MVP.
- Avoid runtime font downloads unless there is a strong product reason.

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

Testable checkpoint:

- Special keys work.
- Terminal colors match desktop theme.
- Ownership loss from desktop is handled.
- Reconnect does not corrupt the terminal session.

Acceptance:

- Native terminal UX is close enough to replace the current Expo terminal for beta testing.

## Phase 10: Git And VCS Screens

Goal: migrate Git functionality after terminal core is stable.

### What's already there (read before starting)

- All VCS types in `MuxyProtocol.Models.swift`: `GitFile`, `GitFileStatus`, `VCSStatus`, `VCSBranches`, `VCSDiff`, `VCSDiffRow`, `VCSPullRequest`, `VCSPRChecks`, `VCSPRMergeStateStatus`, `VCSPRCreated`, `VCSMergeMethod`.
- All `vcs*` methods already in `MethodsAndEvents.swift`.
- No VCS-related events in the protocol — VCS state is pull-based via `vcsRefresh` + `getVCSStatus`.

### Notes for the implementer

- New `VCSService` actor in MuxyCore, same pattern as ProjectsService/WorkspaceService. Per-project state (status, branches, diff). Refresh on demand and via a poll timer when the VCS screen is visible.
- The Expo UI lives in `app/projects/[id]/index.tsx` and various components — read for layout reference but write fresh Swift.
- Each VCS view should be a separate sheet or pushed screen, not crammed into the Workspace. Recommend: a "Git" tab kind that pushes a dedicated VCS NavigationStack.
- File diff: `VCSDiff.rows` is pre-formatted by the desktop. Just render hunk/context/addition/deletion lines with appropriate colors. No client-side diffing.

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

### What's already there (read before starting)

- `PaywallScreen.swift` is a Phase 1 placeholder under `Muxy/Features/Billing/`. Replace its body.
- `AppSheet.paywall` route exists in `AppRouter.swift`.
- The Expo app uses `react-native-iap`. Look at `src/billing/` for product IDs and entitlement gating logic.
- **App Store reviewer skill**: a project skill named `apple-appstore-reviewer` exists — invoke it to check rejection risks before TestFlight (Phase 13).

### Notes for the implementer

- New `BillingService` in MuxyCore. StoreKit 2 (iOS 15+) — async/await native, no observers. Product IDs come from the Expo config; reuse them.
- `EntitlementStore` is just a Codable struct in `SettingsRepository` or a separate JSON file. Holds trial start date and active entitlement state.
- Trial logic from the Expo `src/billing/trial.ts` — port to Swift, keep local (no server check). Trial expiration triggers paywall on next entitlement-gated action.
- The Devices screen gates connecting on `entitlement.kind === 'expired'` in the Expo app (`app/index.tsx`). Reapply that gate on the native side: tap row when expired → present `.paywall` sheet instead of connecting.

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

### What's already there (read before starting)

- `OnboardingScreen.swift` is real (3-slide TabView pager with Muxy logo, brand pink) — see `Muxy/Features/Onboarding/`.
- `SettingsScreen.swift` shows Terminal (Use Nerd Font, Auto-focus terminal) + Demo + About sections. Toggles persist via `SettingsRepository` in MuxyCore.
- `AppEnvironment.settings` is the in-memory `SettingsRecord`. Setters: `setUseNerdFont`, `setAutoFocusTerminal`, `setDemoMode`. `markOnboardingComplete()` for the onboarding finish.
- Brand color is the magenta `#D460BC` accent in `Assets.xcassets/AccentColor.colorset`. Don't change.
- App icon is the cyan→magenta chevrons (`AppIcon.appiconset` + `MuxyLogo.imageset`). Don't change.

### Notes for the implementer

- This phase is mostly polish, not new architecture. Walk every screen on a fresh install and an existing install. iPad layout pass = mostly `.frame(maxWidth: 600)` on content containers + check toolbar placement.
- Demo mode decision: drop it from native MVP unless there's a strong reason to keep it (the Expo demo backend was a hack for App Review). Discuss with the user.
- Theme mode preferences: SwiftUI already follows system. If the user wants explicit Light/Dark/Auto in Settings, add a `ThemePreference` field to `SettingsRecord` and `.preferredColorScheme(_:)` on `RootView`.

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

### What's already there (read before starting)

- `NoopLegacyExpoMigrator` in MuxyCore is the cutover stub. **This phase is where you implement the real `ExpoLegacyMigrator`** that reads the Expo app's AsyncStorage SQLite + expo-secure-store Keychain entries on first launch, ingests devices, and marks `muxy.migration.expoLegacy.v1`. The migrator was designed with this seam from Phase 2.
- Code-signing for TestFlight: bundle id is already `com.muxy.app` (matches the Expo app — same-id App Store update). You'll need a real Apple Developer Team set in the Release config. Currently builds with `CODE_SIGNING_ALLOWED=NO` for simulator development.
- App Store privacy strings: `NSLocalNetworkUsageDescription`, `NSBonjourServices`, `NSCameraUsageDescription` already in `Info.plist`. `PrivacyInfo.xcprivacy` exists with the UserDefaults usage declaration. Add any new privacy strings StoreKit needs.
- Keychain access groups: `Muxy.entitlements` already declares one. Verify it matches the prod App ID prefix when the signing team is set.

### Notes for the implementer

- **Don't ship with the noop migrator.** Before TestFlight, swap `NoopLegacyExpoMigrator` for the real `ExpoLegacyMigrator` in `AppEnvironment` defaults. The migrator's contract from Phase 2: read Expo storage, write to native repositories, set `muxy.migration.expoLegacy.v1` UserDefaults flag, return `LegacyMigrationResult(didRun: true, importedDeviceCount: N)`.
- Run the `apple-appstore-reviewer` skill before submitting. It catches common rejection reasons.
- Integration tests for WebSocket: spin up a tiny local server in a swift test target that speaks the Muxy JSON envelope. Not strictly required for v1.

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
