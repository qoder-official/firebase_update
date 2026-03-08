# Firebase Test Config

This folder is reserved for real Firebase integration test credentials.

## Required path

Place your Firebase service account at:

```text
test/firebase_config/service_account.json
```

This matches the path convention used in Qoder's `firebase_messaging_handler`
reference package.

## Important

- `service_account.json` is git-ignored in this repository.
- Do not commit real credentials.
- Keep this file local or restore it in CI from secrets.

## Planned usage

This credential will back the future real Firebase integration test pass for:

- remote optional update publication
- optional update dismissal then re-show
- force update escalation over optional update
- maintenance escalation over force update
- clearing blocking state and restoring normal app usage
