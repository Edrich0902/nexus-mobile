# Nexus mobile

Flutter + Riverpod client for Nexus on iOS and Android. It talks to the same
`nexus-api` as `nexus-web` and mirrors its look, routes and behaviour.

## Run

```bash
flutter pub get
flutter run --dart-define-from-file=config/dev.json    # Laradock API at http://api.nexus.test
flutter run --dart-define-from-file=config/prod.json   # https://api.nexus.barforge.co.za
```

`api.nexus.test` must resolve on the device. The iOS simulator uses the Mac's
`/etc/hosts`; an Android emulator or a physical phone needs a DNS entry (or
point `API_BASE_URL` at your Mac's LAN address and add it to
`android/app/src/main/res/xml/network_security_config.xml`). Cleartext HTTP is
only allowed for `*.nexus.test`.

## Structure

| Path | What |
|---|---|
| `lib/core` | API client (Dio), auth + secure session, router, Cloudinary, config |
| `lib/design` | Tokens (generated from web), ambient engine, `Nx*` widget kit |
| `lib/shell` | Top bar, phone bar + Spotify strip, More, search, account |
| `lib/features/*` | One folder per section, mirroring web `routes/` |
| `tool/` | `tokens.json` exported from web + `gen_tokens.dart` |

## Design tokens

Tokens come from `nexus-web/src/design/tokens.ts`:

```bash
cd ../nexus-web && npm run tokens:export     # writes ../nexus-mobile/tool/tokens.json
cd ../nexus-mobile && dart run tool/gen_tokens.dart
```

CI fails if `lib/design/tokens.g.dart` is out of date.

## Media (Cloudinary)

- **Delivery** uses the official `cloudinary_url_gen` SDK with the account's
  named transforms only (`t_nexus_thumb`, `t_nexus_card`, `t_nexus_hero`, …),
  because the account runs Strict transformations. `NxImage` picks the variant
  from the box size and device pixel ratio. The cloud name comes from
  `GET /v1/meta`, falling back to `CLOUDINARY_CLOUD_NAME`.
- **Uploads** go through `POST /v1/media`; the API signs the upload with
  server-held credentials. The app never ships a Cloudinary key or an unsigned
  preset. Photos are downscaled to 2560px / JPEG 85 on device first.

## Native integrations

All of them start from `lib/shell/native_bootstrap.dart` once you're signed in,
and each one degrades quietly when its platform setup is missing.

| Feature | Dart | Native |
|---|---|---|
| Deep links `nexus://open/<web path>` and `https://nexus.barforge.co.za/<path>` | `core/native/deep_links.dart` | intent filters / URL scheme |
| Push (FCM) → `POST /v1/devices`; taps open `data.route` | `core/native/push.dart` | Firebase config (below) |
| Home-screen widgets: Listening, Next race, Tonight, Quick log | `features/home/home_widgets.dart` | Android `widgets/NexusWidgets.kt`; iOS `ios/NexusWidgets/` |
| F1 Live Activity / Android ongoing countdown | `features/f1/f1_live_activity.dart` | iOS `ios/NexusWidgets/F1LiveActivity.swift` |
| Quick actions (long-press icon) | `core/native/shortcuts.dart` | `ic_shortcut_*` drawables |
| Siri / Shortcuts: Log a wine, Log a beer, Scan a book | — | `ios/Runner/NexusShortcuts.swift` |

The API can switch push and Live Activities off with
`MOBILE_FEATURE_PUSH` / `MOBILE_FEATURE_LIVE_ACTIVITIES`.

### Still needs your accounts

- **Firebase:** fill the `FIREBASE_*` keys in `config/<env>.json` (or drop in
  `google-services.json` / `GoogleService-Info.plist`), upload an APNs key to
  Firebase, and set `FCM_*` on the API.
- **iOS widget + Live Activity target, App Group, Push and Associated Domains
  capabilities:** see `ios/NexusWidgets/README.md`.
- **App links verification:** host `/.well-known/assetlinks.json` and
  `apple-app-site-association` on the web domain.
- **Release signing:** `android/key.properties` (git-ignored) and an Apple team in Xcode.

## Release

```bash
flutter test                                   # unit, widget + golden tests
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols \
  --dart-define-from-file=config/prod.json
flutter build ipa --release --obfuscate --split-debug-info=build/symbols \
  --dart-define-from-file=config/prod.json
```

- **Version gate:** bump `version:` in `pubspec.yaml`. Set
  `MOBILE_MIN_VERSION_IOS` / `MOBILE_MIN_VERSION_ANDROID` on the API to force
  older builds onto the "Update required" screen. Set `APP_STORE_ID` in
  `config/prod.json` so that screen links to the App Store.
- **Phased release:** start Play at 10% staged rollout and enable App Store
  phased release (7 days). Ship API changes behind `/v1/meta` feature flags so
  they can be turned off without a new build.
- **Fonts** are bundled in `assets/fonts` with no runtime fetching. Their OFL
  licences appear on the licences page. After a `google_fonts` upgrade, re-run
  `python3 tool/fetch_fonts.py`.
- **Icon and splash** come from the web brand assets: `dart run
  flutter_launcher_icons` and `dart run flutter_native_splash:create`. Check
  the diff afterwards, because both tools reformat `AndroidManifest.xml` /
  `Info.plist`.
- **Goldens** (`test/goldens`) are recorded on macOS. Re-record after an
  intentional design change with `flutter test --update-goldens --tags golden`,
  and skip them on other hosts with `--exclude-tags golden`.

### Store privacy answers

| Data | Collected | Purpose | Linked to user |
|---|---|---|---|
| Email, name | Yes | Account | Yes |
| Photos (labels, covers) | Yes, only when you upload | App functionality | Yes |
| Music listening history (via Spotify) | Yes, when connected | App functionality | Yes |
| Crash data (Sentry) | Yes | App functionality | No |
| Device push token | Yes | Notifications | Yes |
| Tracking / ads | No | — | — |
