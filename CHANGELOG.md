## 1.0.5

### Bug fixes
- **Force→optional snooze regression**: When a snooze was active and the server raised the minimum version (triggering a force update), rolling the minimum back to optional would silently suppress the optional dialog — the force dialog dismissed but nothing appeared. Fixed by clearing any active optional snooze as soon as a force update state is presented. The user was blocked by the server, not voluntarily deferring, so the snooze should not persist through a force update event
- **`snoozedForVersion` not persisted**: `_snoozedForVersion` was held in-memory only. After a restart the version-mismatch check that clears a stale snooze when a newer version is offered was always skipped, meaning a snooze for v1.x could silently suppress an optional prompt for v1.y in a new session. Fixed by persisting the snooze target version via the new `setSnoozedForVersion` / `getSnoozedForVersion` methods on `FirebaseUpdatePreferencesStore` — both with no-op defaults so custom store implementations are not broken

### Store interface additions (non-breaking)
- `FirebaseUpdatePreferencesStore.getSnoozedForVersion()` — default returns `null`
- `FirebaseUpdatePreferencesStore.setSnoozedForVersion(String version)` — default is a no-op
- `clearSnoozedUntil()` now also removes the persisted `snoozedForVersion` in `SharedPreferencesFirebaseUpdateStore`

## 1.0.4

- **Integration test screenshots**: Added `example/integration_test/screenshot_test.dart` — captures 8 UI states (optional dialog, optional sheet, force dialog, force sheet, maintenance dialog, maintenance sheet, patch notes expanded, home screen) via `flutter drive`. Added `scripts/take_screenshots.sh` to run screenshot capture against a connected device or simulator. Screenshots are saved to `screenshots/` at the package root and used as README assets
- **Analytics callbacks** (zero new dependencies): Four new optional callbacks on `FirebaseUpdateConfig` — `onDialogShown(state)`, `onDialogDismissed(state)`, `onSnoozed(version, duration)`, `onVersionSkipped(version)`. Wire these to Firebase Analytics, Mixpanel, Amplitude, or any SDK your app already uses
- **`FirebaseUpdateCard` inline widget**: New `FirebaseUpdateCard` widget using `FirebaseUpdateBuilder` internally. Renders nothing when state is `idle` or `upToDate`. Shows a styled tinted card for `optionalUpdate`, `forceUpdate`, `maintenance`, and `shorebirdPatch` states. Accepts optional `onUpdateTap` and `onLaterTap` overrides. Drop into settings screens, home feeds, or any scrollable layout
- **`checkNow()` already existed** — no new API required. Wired `listenToRealtimeUpdates: false` properly: when set, the real-time RC subscription is not started and `checkNow()` is the only way to refresh state
- **Desktop layout**: New `desktopMaxDialogWidth` (default `480`) on `FirebaseUpdatePresentationTheme`. On macOS, Windows, and Linux the dialog content is capped at this width so it doesn't stretch across wide monitors. Has no effect on mobile
- **Allowed flavors whitelist**: New `allowedFlavors: List<String>?` on `FirebaseUpdateConfig`. Reads `String.fromEnvironment('FLAVOR')` at runtime — when set, all UI and state emission is suppressed if the current flavor is not in the list. Default `null` = always active. Pass `--dart-define=FLAVOR=production` at build time to activate

## 1.0.3

- **Renamed presentation callbacks**: `FirebaseUpdatePresentationData` callbacks renamed from `onPrimaryTap`/`onSecondaryTap`/`onTertiaryTap` to `onUpdateClick`/`onLaterClick`/`onSkipClick` for clarity
- **Dismiss booleans**: Added `dismissOnUpdateClick`, `dismissOnLaterClick`, `dismissOnSkipClick` (all default `true`) to `FirebaseUpdatePresentationData` — controls whether the modal auto-dismisses after each button tap; custom widget builders can set any to `false` to handle navigation themselves
- **Real-time snooze**: Tapping "Later" now starts a timer internally — the optional update dialog re-appears automatically after the snooze duration elapses, without requiring an app restart or a new Remote Config push. Version-aware: a different `latestVersion` clears the snooze immediately and re-prompts
- **Store fallback always opens**: When the app is not found on the store (e.g. staging build), the launcher now opens the store home page (`https://apps.apple.com/` on iOS/macOS, `market://search` on Android, `ms-windows-store://` on Windows) instead of showing an error toast
- **Removed error toast**: The "Unable to open the update link" snackbar is gone — the store always opens via one of the four priority tiers

## 1.0.2

- **RC-driven store URLs**: `store_url_android`, `store_url_ios`, `store_url_macos`, `store_url_windows`, `store_url_linux`, `store_url_web` can now be set in the Remote Config JSON payload. When present, they take priority over the local `FirebaseUpdateConfig.fallbackStoreUrls` values, allowing store URLs to be updated without a rebuild.

## 1.0.1

- **Topics**: Added pub.dev topics (`updates`, `versioning`, `remote-config`, `firebase`, `app-management`)
- **Store launch override**: New `onStoreLaunch` callback on `FirebaseUpdateConfig` — replaces the default `app_review` + `url_launcher` store-open flow with your own logic; dialog dismisses automatically after the callback returns
- **Button callback hooks**: `onForceUpdateTap`, `onOptionalUpdateTap`, `onOptionalLaterTap` on `FirebaseUpdateConfig` — fire in addition to default behavior for analytics and side effects
- **Skip version**: Opt-in `showSkipVersion: bool` config flag adds a persistent "Skip this version" tertiary button to optional-update prompts; persists across restarts via `shared_preferences`
- **Session dismiss (default)**: Tapping "Later" now suppresses the optional-update prompt for the current app session. The prompt reappears on the next launch
- **Timed snooze (opt-in)**: Set `snoozeDuration` (e.g. `Duration(hours: 24)`) to persist the snooze across restarts — the prompt stays hidden until the duration elapses
- **Persistence**: New `FirebaseUpdatePreferencesStore` abstract interface + `SharedPreferencesFirebaseUpdateStore` default implementation; inject a custom store via `FirebaseUpdateConfig.preferencesStore`
- **Programmatic skip/snooze API**: `FirebaseUpdate.instance.snoozeOptionalUpdate()`, `skipVersion()`, `dismissOptionalUpdateForSession()`, `clearSnooze()`, `clearSkippedVersion()` — lets custom `optionalUpdateWidget` builders drive SDK state without relying on built-in buttons
- **Shorebird patches**: New `FirebaseUpdatePatchSource` abstract interface, `FirebaseUpdateKind.shorebirdPatch` state, `patchSource` + `onPatchApplied` + `shorebirdPatchWidget` config fields, and a built-in patch dialog/sheet with async download progress indicator; `onPatchApplied` callback lets you trigger your own restart logic
- **Labels**: Added `skipVersion`, `patchAvailableTitle`, `patchAvailableMessage`, `applyPatch` to `FirebaseUpdateLabels`
- **Presentation data**: Added `tertiaryLabel` and `onTertiaryTap` to `FirebaseUpdatePresentationData` (and `copyWith`)
- **Dependencies**: Added `shared_preferences: ">=2.2.0 <4.0.0"`

## 1.0.0

First stable release.

- Firebase Remote Config driven update state: optional update, force update, maintenance mode
- Fixed Remote Config schema — `FirebaseUpdateConfig()` works with zero required parameters
- `remoteConfigKey` defaults to `firebase_update_config`, override if needed
- Real-time Remote Config listening via `onConfigUpdated` with opt-out support
- Package-managed default UI: optional update dialog, optional update bottom sheet, force update dialog, maintenance dialog
- Custom builder hooks to replace any default surface with your own widget
- `FirebaseUpdateBuilder` — reactive widget for building in-screen update surfaces
- `FirebaseUpdateContentAlignment` enum to control icon, title, and body alignment across all surfaces
- Skip-version behavior: tapping Later suppresses the same version; clears when a newer version arrives
- Patch notes with read-more expansion for plain text (5-line threshold) and HTML content
- Per-platform store URLs via `FirebaseUpdateStoreUrls`
- Native store listing launch via `app_review` with URL fallback
- Theme tokens: surface, accent, content, outline, barrier, blur, hero gradient, border radius
- 19 widget tests covering initialization, optional update, force update, maintenance, escalation, skip-version, and patch notes rendering
