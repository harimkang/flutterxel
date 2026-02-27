# First App

This is a minimal flutterxel app that initializes runtime state, runs update/draw callbacks, and renders the frame buffer in Flutter.

```dart
import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

double playerX = 72;

void main() {
  flutterxel.init(160, 120, title: 'My First flutterxel App', fps: 60);

  flutterxel.run(
    () {
      if (flutterxel.btn(flutterxel.KEY_LEFT)) {
        playerX -= 2;
      }
      if (flutterxel.btn(flutterxel.KEY_RIGHT)) {
        playerX += 2;
      }
      playerX = playerX.clamp(0, flutterxel.width - 8);
    },
    () {
      flutterxel.cls(flutterxel.COLOR_BLACK);
      flutterxel.rect(playerX.floor(), 56, 8, 8, flutterxel.COLOR_LIME);
      flutterxel.text(4, 4, 'LEFT/RIGHT TO MOVE', flutterxel.COLOR_WHITE);
    },
  );

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: const flutterxel.FlutterxelView(pixelScale: 4),
          ),
        ),
      ),
    );
  }
}
```

## Notes

- Call `init(...)` before `run(...)`.
- `run(update, draw)` starts a non-blocking periodic loop.
- `FlutterxelView` renders the current frame buffer and captures keyboard/pointer input by default.
