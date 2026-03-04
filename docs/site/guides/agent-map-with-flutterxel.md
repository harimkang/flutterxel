# Agent Map with Flutterxel

This guide describes the minimum flow for running the Flutterxel-based Agent Map example.

## 1) Sync Character Assets

From repository root:

```bash
./packages/flutterxel/example/tool/sync_reference_characters.sh
```

This copies:

- `reference/characters/*/*_sheet.png`
- `reference/characters/*/*_sheet.meta.json`

into:

- `packages/flutterxel/example/assets/characters/<character>/...`

## 2) Run Example

```bash
cd packages/flutterxel/example
flutter run
```

The example scene uses:

- character manifest parser (`*_sheet.meta.json`)
- service-zone state machine (`idle`, `work`, `error`)
- Flutterxel rendering (`blt` with transparent `colkey`)

## 3) Backend-Aware Branching

When integrating with a real app, branch by backend mode:

```dart
switch (Flutterxel.backendMode) {
  case BackendMode.native_core:
    // preferred path
    break;
  case BackendMode.c_fallback:
    // compatibility path
    break;
  case BackendMode.dart_fallback:
    // minimal runtime path
    break;
}
```

## 4) Verification Commands

```bash
cd packages/flutterxel/example
flutter test test/character_manifest_test.dart
flutter test test/agent_state_machine_test.dart
flutter test test/agent_map_scene_smoke_test.dart
flutter test test/jsonl_activity_feed_test.dart
```
