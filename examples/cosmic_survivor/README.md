# Cosmic Survivor

A complete arcade-style Flutterxel example designed to be small in code size but polished in gameplay quality.

## Game Concept

**Cosmic Survivor** is a lane-based space survival shooter.

- You pilot a small ship at the bottom of the screen.
- Meteor clusters fall from orbit in five lanes.
- You can move left/right and fire pulse shots.
- Destroying meteors increases score.
- Missing too many threats costs lives.
- The game ends when all lives are lost.

The design goal is a short-session game that feels responsive on both keyboard and touch devices.

## Design Goals

- Demonstrate realistic Flutterxel usage in a production-like mini game.
- Keep the code understandable for plugin users who want to learn by reading.
- Support both desktop (keyboard) and mobile (on-screen buttons).
- Maintain stable 60 FPS update/draw loop with clear game-state transitions.

## Core Mechanics

- **States:** `title -> playing -> gameOver`
- **Player movement:** lane-based (5 lanes)
- **Combat:** single-lane pulse shots with cooldown
- **Hazards:** random meteor spawns with increasing speed and spawn rate
- **Progression:** score and difficulty increase over time
- **Failure condition:** lives reach zero

## Controls

- Keyboard:
  - `Left Arrow` / `Right Arrow`: move ship
  - `Space`: fire and start/restart
- Touch:
  - Holdable `LEFT` and `RIGHT` buttons
  - Tap/hold `FIRE` button

## Technical Architecture

- `lib/src/cosmic_survivor_game.dart`
  - Pure game simulation layer (state machine, movement, collisions, scoring)
  - No Flutter UI dependencies
  - Unit-tested for deterministic behavior
- `lib/main.dart`
  - Flutter shell + control buttons + `FlutterxelView`
  - Feeds input into the simulation
  - Renders simulation state each frame using Flutterxel APIs (`cls`, `line`, `rect`, `circ`, `tri`, `text`)

This split keeps gameplay logic testable and rendering easy to iterate.

## Visual Direction

- Retro 16-color palette with high contrast
- Layered starfield background for motion depth
- Lane guide lines to improve readability
- Distinct shapes/colors for player, shots, and meteors
- Pixel-HUD for score/lives/best score

## Test Plan

Unit tests focus on gameplay invariants:

- Initial state and defaults
- Lane movement clamping
- Firing cooldown behavior
- Shot-vs-meteor collision scoring
- Player hit handling and game-over transition
- Restart flow preserving best score

Run tests:

```bash
cd examples/cosmic_survivor
flutter test
```

Run app:

```bash
cd examples/cosmic_survivor
flutter run
```
