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
