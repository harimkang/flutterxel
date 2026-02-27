# Installation

## Prerequisites

- Flutter (stable channel)
- Dart (included with Flutter)

`flutterxel` plugin metadata currently declares native plugin support for:

- Android
- iOS

## Add Dependency

Use a Git dependency to consume the package from this monorepo:

```yaml
dependencies:
  flutterxel:
    git:
      url: https://github.com/harimkang/flutterxel.git
      path: packages/flutterxel
```

Then run:

```bash
flutter pub get
```

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
