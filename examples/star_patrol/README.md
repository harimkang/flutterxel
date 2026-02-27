# Star Patrol

A polished top-down action example built with Flutterxel. This sample focuses on real-time movement, shooting, enemy waves, and survival pacing.

## Genre

Top-down arcade shooter

## Core Loop

- Move your ship in open space.
- Fire pulse shots to destroy incoming drones.
- Avoid collisions and prevent enemies from slipping past.
- Survive as long as possible while score and difficulty scale.

## Controls

- Keyboard: Arrow keys to move, `Space` to fire/start/restart.
- Touch: On-screen `UP`, `DOWN`, `LEFT`, `RIGHT`, `FIRE` buttons.

## Design Goals

- Responsive movement on both keyboard and touch.
- Readable enemy/projectile silhouettes in a 16-color palette.
- Clear state transitions: title -> playing -> game over.
- Pure simulation layer that can be tested without Flutter rendering.

## Technical Structure

- `lib/src/star_patrol_game.dart`
  - Movement, spawning, collisions, scoring, lives
  - Input edge handling for fire/start
- `lib/main.dart`
  - Flutterxel frame loop and rendering
  - Virtual controls + keyboard bridge

## Test Coverage

- Initial game state
- Movement bounds clamping
- Projectile collision scoring
- Damage/life loss and game-over transition
- Restart behavior preserving best score

## Run

```bash
cd examples/star_patrol
flutter run
```

## Test

```bash
cd examples/star_patrol
flutter test
```
