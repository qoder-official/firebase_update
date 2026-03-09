# Integration Tests

Three test files, two purposes.

---

## `update_flow_test.dart` — Core flow tests (fast)

Basic smoke tests for individual flows: optional update appears/dismisses,
force update blocks, maintenance appears, skip-version logic.

Uses `applyPayload()` with `initializeFirebase: false` — no network required.

```bash
flutter test integration_test/update_flow_test.dart -d <device>
```

---

## `priority_sequence_test.dart` — Comprehensive priority & timing tests (fast)

The definitive regression test for the package. Covers:

- **Single-overlay rule**: only one overlay is ever visible at a time
- **Full priority chain**: maintenance > force > optional, all transitions
- **Both presentation forms**: dialog and bottom sheet variants
- **Mixed form transitions**: dialog → sheet, sheet → dialog
- **Rapid-fire bursts**: multiple state changes before a frame settles
- **Navigator-key timing**: overlays applied before the widget tree exists
- **Skip-version interactions**: skip + escalation, skip + maintenance cycles

Uses `applyPayload()` — no network required. This is the test to run after
any refactor or change to the package.

```bash
flutter test integration_test/priority_sequence_test.dart -d <device>
```

---

## `live_rc_test.dart` — Live Firebase RC end-to-end test (requires network)

Calls the Firebase Remote Config REST API directly from the device using the
test service account, then waits for the `onConfigUpdated` real-time listener
to fire and verifies the correct overlay appears.

Validates the full pipeline:

```
Firebase RC REST API
  → Firebase real-time infrastructure
    → onConfigUpdated stream on device
      → state resolver → presenter → navigator overlay
```

Test groups:
- **Priority chain**: optional → force → maintenance → clear over real RC
- **Deescalation**: force → optional, maintenance → idle over real RC
- **checkNow smoke**: `checkNow()` reflects the current RC value immediately

Each step waits up to 30 s for the real-time update to propagate.

```bash
flutter test integration_test/live_rc_test.dart -d <device>
```

> Run this test separately from the others — it calls `Firebase.initializeApp()`
> which can only happen once per process.
