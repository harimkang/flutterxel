import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_puzzle/src/pixel_puzzle_game.dart';

void main() {
  group('PixelPuzzleGame', () {
    test('starts at title with zero moves', () {
      final game = PixelPuzzleGame();

      expect(game.phase, PuzzlePhase.title);
      expect(game.moves, 0);
      expect(game.bestMoves, isNull);
      expect(game.cursorRow, PixelPuzzleGame.boardSize ~/ 2);
      expect(game.cursorCol, PixelPuzzleGame.boardSize ~/ 2);
    });

    test('restart begins playing with unsolved puzzle', () {
      final game = PixelPuzzleGame();

      game.startOrRestart();

      expect(game.phase, PuzzlePhase.playing);
      expect(game.moves, 0);
      expect(game.litTiles, greaterThan(0));
    });

    test('action toggles selected tile and neighbors', () {
      final game = PixelPuzzleGame()..startOrRestart();
      game.debugSetBoard(
        List<List<bool>>.generate(
          PixelPuzzleGame.boardSize,
          (_) => List<bool>.filled(PixelPuzzleGame.boardSize, false),
        ),
      );
      game.debugSetCursor(2, 2);

      game.setControls(
        left: false,
        right: false,
        up: false,
        down: false,
        action: true,
      );
      game.tick();

      expect(game.isLit(2, 2), isTrue);
      expect(game.isLit(1, 2), isTrue);
      expect(game.isLit(3, 2), isTrue);
      expect(game.isLit(2, 1), isTrue);
      expect(game.isLit(2, 3), isTrue);
      expect(game.moves, 1);
    });

    test('clears puzzle and records best moves', () {
      final game = PixelPuzzleGame()..startOrRestart();
      game.debugSetBoard(
        List<List<bool>>.generate(
          PixelPuzzleGame.boardSize,
          (_) => List<bool>.filled(PixelPuzzleGame.boardSize, false),
        ),
      );
      game.debugSetBoard(<List<bool>>[
        <bool>[false, false, false, false, false],
        <bool>[false, false, true, false, false],
        <bool>[false, true, true, true, false],
        <bool>[false, false, true, false, false],
        <bool>[false, false, false, false, false],
      ]);
      game.debugSetCursor(2, 2);

      game.setControls(
        left: false,
        right: false,
        up: false,
        down: false,
        action: true,
      );
      game.tick();

      expect(game.phase, PuzzlePhase.cleared);
      expect(game.litTiles, 0);
      expect(game.bestMoves, 1);
    });

    test('restart after clear keeps best moves', () {
      final game = PixelPuzzleGame()..startOrRestart();
      game.debugSetBoard(<List<bool>>[
        <bool>[false, false, false, false, false],
        <bool>[false, false, true, false, false],
        <bool>[false, true, true, true, false],
        <bool>[false, false, true, false, false],
        <bool>[false, false, false, false, false],
      ]);
      game.debugSetCursor(2, 2);
      game.setControls(
        left: false,
        right: false,
        up: false,
        down: false,
        action: true,
      );
      game.tick();
      expect(game.bestMoves, 1);

      game.startOrRestart();

      expect(game.phase, PuzzlePhase.playing);
      expect(game.moves, 0);
      expect(game.bestMoves, 1);
      expect(game.litTiles, greaterThan(0));
    });
  });
}
