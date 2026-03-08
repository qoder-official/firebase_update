# Example Integration Tests

These tests validate the `firebase_update` example app as a user would
experience it.

They focus on visible flows:

- optional update appears and dismisses
- force update appears after optional update
- maintenance mode appears over active update flows

Run from the `example/` directory:

```bash
flutter test integration_test/update_flow_test.dart
```

These tests currently use the example app's local state simulator. A future
pass should add a real Remote Config-backed integration path that uses
`../test/firebase_config/service_account.json`.
