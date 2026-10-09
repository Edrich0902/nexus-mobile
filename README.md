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

## Native setup still needed

- Firebase: add `android/app/google-services.json` and
  `ios/Runner/GoogleService-Info.plist`, then set `FCM_*` on the API. Push is
  skipped gracefully until they exist.
- iOS home-screen widget and Live Activity targets (see `ios/NexusWidgets/README.md`).
- Release signing: `android/key.properties` (git-ignored) and an Apple team in Xcode.
