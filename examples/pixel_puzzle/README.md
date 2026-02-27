# Pixel Puzzle

A polished puzzle example built with Flutterxel. This app demonstrates a complete game loop, deterministic game logic, touch/keyboard controls, and test-first gameplay rules.

## Genre

Grid puzzle (Lights Out style)

## Core Loop

- Move a cursor on a 5x5 board.
- Activate a tile to toggle itself and its four neighbors.
- Turn every lit tile off.
- Clear the board in as few moves as possible.

## Controls

- Keyboard: Arrow keys to move, `Space` to activate/start/restart.
- Touch: On-screen `UP`, `DOWN`, `LEFT`, `RIGHT`, `ACT` buttons.

## Design Goals

- Clear, readable puzzle state at a glance.
- Fast restart flow for repeated attempts.
- Best-move tracking to encourage mastery.
- Pure simulation layer (`lib/src`) separated from rendering layer (`lib/main.dart`).

## Technical Structure

- `lib/src/pixel_puzzle_game.dart`
  - Puzzle state machine and board logic
  - Cursor movement and input edge handling
  - Win detection and best score tracking
- `lib/main.dart`
  - Flutterxel initialization and frame loop
  - Rendering of board/HUD/overlay
  - Touch control panel and keyboard integration

## Test Coverage

- Initial state defaults
- Restart creates a valid unsolved puzzle
- Activation toggles center + neighbors
- Win transition and best-move update
- Restart keeps best record and resets run state

## Run

```bash
cd examples/pixel_puzzle
flutter run
```

## Test

```bash
cd examples/pixel_puzzle
flutter test
```
