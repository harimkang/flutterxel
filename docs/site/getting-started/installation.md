# Installation

## Prerequisites

- Flutter (stable channel)
- Dart (included with Flutter)

`flutterxel` plugin metadata currently declares native plugin support for:

- Android
- iOS

## Add Dependency

Use the published package from pub.dev:

```yaml
dependencies:
  flutterxel: ^0.0.7
```

Then run:

```bash
flutter pub get
```

Package pages:

- https://pub.dev/packages/flutterxel
- https://pub.dev/packages/flutterxel_tools

If you need to test unreleased changes from this repository, you can switch to a Git dependency temporarily.

## If You Are Working Inside This Repository

From the repository root:

```bash
dart run melos bootstrap
```

## Run a Full Example Game

```bash
cd examples/star_patrol
flutter run
```

You can replace `star_patrol` with:

- `pixel_puzzle`
- `void_runner`
- `cosmic_survivor`
