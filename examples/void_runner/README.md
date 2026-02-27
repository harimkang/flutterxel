# Void Runner

A polished runner example built with Flutterxel. This sample demonstrates jump physics, obstacle timing, score pacing, and fast restart flow.

## Genre

Endless side runner

## Core Loop

- Auto-run through a hostile terrain.
- Time jumps to avoid incoming obstacles.
- Survive longer to increase score and speed.
- Beat your own best distance score.

## Controls

- Keyboard: `Space` or `Up Arrow` to jump/start/restart.
- Touch: On-screen `JUMP` button.

## Design Goals

- Simple one-button gameplay with satisfying timing.
- Readable obstacle silhouettes and ground contrast.
- Deterministic simulation separated from rendering.
- High replayability with quick restart.

## Technical Structure

- `lib/src/void_runner_game.dart`
  - Jump physics, obstacle spawning, collision checks, scoring
  - State transitions (`title -> playing -> gameOver`)
- `lib/main.dart`
  - Flutterxel rendering and HUD
  - Touch + keyboard control bridge

## Test Coverage

- Initial state defaults
- Jump arc and landing behavior
- Obstacle pass scoring
- Collision -> game over transition
- Restart keeps best score

## Run

```bash
cd examples/void_runner
flutter run
```

## Test

```bash
cd examples/void_runner
flutter test
```
