## 1.0.7

### Reliability hardening — bulletproof force updates

This release focuses entirely on making force update and maintenance gates impossible to miss, dismiss, or bypass. Every edge case where a blocking dialog could be silently dropped has been addressed.

### New features

- **Store version fallback**: New `storeVersionSource` config option compares the running app version against the latest store version on startup. When the store is ahead, a cache-busting Remote Config fetch is triggered immediately — guaranteeing the update dialog appears even if the real-time listener missed the push. Ships two built-in implementations:
  - `PlayStoreVersionSource` — scrapes the Google Play Store listing page using a multi-strategy version extraction heuristic (no extra dependencies, uses `dart:io`)
  - `AppStoreVersionSource` — queries the iTunes Lookup API by bundle ID or track ID (no extra dependencies, uses `dart:io`)
  - `CallbackStoreVersionSource` — wrap any `Future<String?>` callback for maximum flexibility (e.g. your own backend API)
- **Periodic re-check timer**: New `recheckInterval` config option (e.g. `Duration(hours: 6)`) starts a safety-net timer that re-fetches Remote Config on a schedule. Each tick runs the full reliability check: store version comparison first, then a cache-busting or regular RC fetch as appropriate
- **App lifecycle resume re-check**: New `checkStoreVersionOnResume` config flag. When enabled alongside a `storeVersionSource`, every app foreground triggers a store version comparison and cache-busting fetch if the app is behind — catches the "went to store, didn't update, came back" scenario
- **Blocking state re-emit on resume**: Force update and maintenance states are automatically re-emitted when the app returns to the foreground, so the dialog re-presents itself even if it was somehow dismissed during the app-switch

### Real-time listener resilience

- **Exponential backoff retry for `onConfigUpdated`**: The real-time Remote Config stream (`onConfigUpdated`) now wraps in a retry loop with exponential backoff (2s, 4s, 8s, 16s, 32s — up to 5 attempts). This fixes the core issue where the stream silently dies in release builds due to Android battery optimization (Doze), network changes, or gRPC transport errors. On each successful event the retry counter resets to zero
- **Cache-busting fetch (`fetchPayloadFresh`)**: New method on `RemoteConfigPayloadSource` that temporarily sets `minimumFetchInterval` to `Duration.zero` before fetching, then restores the caller's preferred interval. Used by the store version fallback and periodic re-check to bypass stale cached responses

### Presentation hardening

- **Navigator mount retry (50 frames)**: When the navigator context is not yet mounted at the time a blocking state is emitted (e.g. `initialize()` runs before the widget tree is built), the presenter now retries across up to 50 post-frame callbacks for force update and maintenance states. Non-blocking states get a single retry
- **3-second blocking retry timer**: After emitting a force update or maintenance state, a delayed 3-second timer re-invokes the presenter as a safety net. Catches silent failures from context races, hot reloads, or generation counter mismatches
- **`onError` handler on real-time subscription**: Errors that propagate past the stream's internal retry are now caught gracefully instead of crashing. The package falls back to the last known state and relies on periodic/lifecycle re-checks

### Bug fixes

- **Real-time updates silently failing in release mode**: Root cause was `onConfigUpdated` stream dying without notification in release builds. Fixed with the retry+backoff mechanism described above

### Code quality

- Removed redundant `package:flutter/foundation.dart` import from `firebase_update_config.dart` — all used symbols are re-exported by `package:flutter/widgets.dart`. Clears the `unnecessary_import` lint that pub.dev static analysis was flagging

## 1.0.6

### UI refresh
- **Refined default overlays**: Refreshed the package-managed dialog and sheet UI for optional update, force update, and maintenance flows. The latest pass simplifies the header area down to a single centered icon, tightens vertical rhythm around the title and notes, and removes the extra status/version strip so the defaults feel cleaner and easier to scan
- **Balanced maintenance spacing**: Maintenance dialogs and sheets now trim the empty action gap and use cleaner top/bottom padding when no buttons are rendered, so the default blocking maintenance UI no longer looks vertically off-balance
- **Overlay preloading hook**: Added `onBeforePresent` to `FirebaseUpdateConfig`, allowing apps to await GIF/image precaching or any other async preparation before a package-managed overlay is shown
- **More theme control**: Added new optional `FirebaseUpdatePresentationTheme` tokens for `panelGradient`, `heroGlowColor`, `noteBackgroundColor`, `statusBackgroundColor`, and `statusForegroundColor` so apps can tune the richer default UI without replacing it entirely
- **Optional sheet dismiss parity**: Tapping outside a dismissible optional-update bottom sheet now follows the same path as pressing `Later`, including session-dismiss and `snoozeDuration` timer behavior. Previously a barrier tap could close the sheet without starting the expected snooze flow
- **Expanded sheet safety**: Long patch-note bottom sheets now keep their action row above the safe area while the notes body scrolls independently, so `Read more` / `Show less` does not push buttons off-screen
- **Simplified example app**: Reworked the example app into a cleaner, lighter demo surface focused on state simulation, long-content testing, and live JSON preview, and removed the customization preview section
- **Full-screen maintenance example**: Rebuilt the example app's custom maintenance takeover using a Stitch-guided full-screen layout with a preloaded network GIF, and moved the demo alongside the long-content/custom-surface examples instead of the basic simulator grid
- **Debug back escape hatch**: Added `allowDebugBack` to `FirebaseUpdateConfig`. When enabled, force-update and maintenance presentations show a subtle debug-only back action outside the blocking overlay in Flutter debug mode, allowing developers to temporarily bypass the gate locally without affecting release builds. The example app now enables this for blocking simulator previews and live JSON testing, while screenshot capture pins it off so README assets stay clean

### Bug fixes
- **Custom builder dismissal parity**: `FirebaseUpdatePresentationData.onLaterClick`, `onSkipClick`, and dismissible custom action callbacks now dismiss package-managed dialogs and sheets consistently when used inside custom `optionalUpdateWidget`, `forceUpdateWidget`, and `maintenanceWidget` builders. Previously the built-in UI auto-dismissed, but custom builders only received the state-update callback, so "Later" could snooze correctly while leaving the dialog visible unless the app manually popped it
- **Blocking dialog recovery after external navigation**: Force-update and maintenance gates now re-present themselves if some unrelated navigator mutation removes the overlay route while the app is still in a blocking state. Previously the presenter could keep stale internal state and assume the gate was still active, leaving the app accessible until the next state change
- **Full-screen maintenance rendering cleanup**: The example app's full-screen maintenance takeover now renders inside a proper Material surface instead of a raw decorated widget tree, fixing the yellow debug underlines/text styling glitches and making the takeover behave like a real screen. The blocking dialog debug-back control was also repositioned as a screen overlay so custom full-screen maintenance widgets are not forced into centered-card layout constraints

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
