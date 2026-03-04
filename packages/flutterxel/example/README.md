# flutterxel_example

Flutterxel example app with an Agent Map MVP scene.

## Sync Character Assets

From repository root:

```bash
./packages/flutterxel/example/tool/sync_reference_characters.sh
```

This copies `reference/characters/*/*_sheet.png` and `*_sheet.meta.json` into:

- `packages/flutterxel/example/assets/characters/<character>/`

## Run Example

```bash
cd packages/flutterxel/example
flutter run
```

## Tests

```bash
cd packages/flutterxel/example
flutter test test/character_manifest_test.dart
flutter test test/agent_state_machine_test.dart
flutter test test/agent_map_scene_smoke_test.dart
flutter test test/jsonl_activity_feed_test.dart
```
