# Muxy Mobile

Monorepo for the Muxy mobile clients.

```
.
├── ios/        Native SwiftUI app (iOS 17+)
├── android/    Native Kotlin / Jetpack Compose app
├── docs/
└── .github/workflows/
    ├── ios-checks.yml
    ├── ios-release.yml
    ├── android-checks.yml
    └── android-release.yml
```

The two apps are completely separate — no shared code between them. They each
talk to a Muxy server (the macOS app in `~/Projects/muxy`) over WebSocket using
the protocol defined in `ios/MuxyShared/`. The Android side has its own
re-implementation of that protocol in Kotlin.

## iOS

```sh
cd ios
open MuxyMobile.xcodeproj
# or run on a simulator:
scripts/run-mobile.sh
```

`MuxyShared/` is a local Swift package consumed by the Xcode project via
`XCLocalSwiftPackageReference "."` (i.e. it picks up `ios/Package.swift`).

## Android

```sh
cd android
./gradlew assembleDebug
```

Open `android/` in Android Studio for development.

## CI

- `ios-checks` — SwiftFormat, SwiftLint, simulator build on every PR touching `ios/**`.
- `ios-release` — manual `workflow_dispatch`; archives, signs, uploads to App Store Connect.
- `android-checks` — Gradle lint, debug assemble, unit tests on every PR touching `android/**`.
- `android-release` — scaffold; signing + Play Store upload are TODO (see workflow comments).

iOS release secrets carried over from the original repo:
`APPLE_DISTRIBUTION_CERTIFICATE`, `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`,
`KEYCHAIN_PASSWORD`, `APP_STORE_CONNECT_API_KEY`, `APP_STORE_CONNECT_KEY_ID`,
`APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_PROVISIONING_PROFILE`, `APPLE_TEAM_ID`.

## Migration

This repo was extracted from `~/Projects/muxy` (mac app + iOS app + shared)
and `~/Projects/muxy-android`. See `docs/migration-task.md` for the cleanup
checklist on the source mac repo.

## License

This project is source-available under the Functional Source License 1.1 with
an Apache 2.0 future grant (`FSL-1.1-ALv2`). See `LICENSE` for the full terms
and `LICENSE-NOTES.md` for a plain-language summary.
