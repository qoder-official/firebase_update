## 0.0.1

Initial development release.

- Firebase Remote Config driven update state (optional update, force update, maintenance mode)
- Configurable field mapping so any existing Remote Config schema works without migration
- Real-time Remote Config listening with opt-out support
- Package-managed default UI for optional update dialog, optional update bottom sheet, force update dialog, and maintenance dialog
- Custom builder hooks to replace any default presentation with app-specific UI
- `FirebaseUpdateBuilder` widget for reactive, stream-driven update state in any part of the widget tree
- Skip-version behavior for optional updates: tapping Later suppresses re-presentation of the same version
- Patch notes support with read-more expansion for plain text and HTML content
- Configurable per-platform fallback store URLs
- Native store listing launch via `app_review` with URL fallback
- Theme tokens for surface, accent, content, outline, barrier, blur intensity, and hero gradient
- Integration test coverage for initialization, optional update, force update, maintenance, overlap flows, and skip-version behavior
