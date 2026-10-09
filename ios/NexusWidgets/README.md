# Nexus widgets & F1 Live Activity (iOS)

The Swift sources here are complete and type-check against the iOS SDK. They
aren't wired into `Runner.xcodeproj` yet, because adding an extension target
needs your Apple team for signing and App Group provisioning. The Flutter side
(`lib/features/home/home_widgets.dart`, `lib/features/f1/f1_live_activity.dart`)
already writes the data these widgets read.

## One-time Xcode setup

1. Open `ios/Runner.xcworkspace`.
2. **File → New → Target → Widget Extension**
   - Product name: `NexusWidgets`
   - Tick **Include Live Activity**; untick **Include Configuration App Intent**.
   - Bundle id: `app.nexus.nexusMobile.NexusWidgets`
   - Deployment target: **iOS 16.2**
3. Delete the template Swift files Xcode generated. Add `NexusWidgets.swift` and
   `F1LiveActivity.swift` from this folder to the `NexusWidgets` target.
4. **App Group** on both the `Runner` and `NexusWidgets` targets, under Signing &
   Capabilities → + Capability → App Groups: `group.app.nexus.nexusMobile`.
   This must match `AppConfig.appGroupId`.
5. Runner → Build Phases: drag **Embed Foundation Extensions** above
   **Run Script** (the "Thin Binary" phase). Otherwise Flutter builds fail
   with a dependency cycle.
6. Runner `Info.plist` already has `NSSupportsLiveActivities = YES`.

## Push notifications

1. Add **Push Notifications** and **Background Modes → Remote notifications** to
   the Runner target. `UIBackgroundModes` is already in `Info.plist`.
2. Upload an APNs auth key (`.p8`) to the Firebase project under
   Project settings → Cloud Messaging.
3. Fill `FIREBASE_IOS_APP_ID` / `FIREBASE_IOS_API_KEY` (and the shared
   `FIREBASE_PROJECT_ID` / `FIREBASE_SENDER_ID`) in `config/<env>.json`.
   Alternatively, drop `GoogleService-Info.plist` into `ios/Runner/`.

Without Firebase config the app skips push registration silently.

## Universal links

1. Add **Associated Domains** to Runner with `applinks:nexus.barforge.co.za`.
2. Serve `https://nexus.barforge.co.za/.well-known/apple-app-site-association`
   from nexus-web:

```json
{
  "applinks": {
    "details": [
      { "appIDs": ["<TEAM_ID>.app.nexus.nexusMobile"], "components": [{ "/": "/*" }] }
    ]
  }
}
```

Android's equivalent is `/.well-known/assetlinks.json`, with the release
signing certificate's SHA-256 fingerprint for package `app.nexus.nexus_mobile`.

## Already in the Runner target

`Runner/NexusShortcuts.swift` adds Siri / Shortcuts / Spotlight actions:
"Log a wine", "Log a beer" and "Scan a book". Each opens the matching
`nexus://open/capture?...` link.

The home-screen quick actions come from `lib/core/native/shortcuts.dart`.
They use SF Symbol–style template images named `ic_shortcut_wine`,
`ic_shortcut_beer`, `ic_shortcut_book` and `ic_shortcut_music`. Add image sets
with those names to `Assets.xcassets` to give the quick actions icons; without
them the actions still work, they just have no icon.
