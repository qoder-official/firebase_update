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
