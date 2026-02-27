import 'package:flutter_test/flutter_test.dart';
import 'package:void_runner/src/void_runner_game.dart';

void main() {
  group('VoidRunnerGame', () {
    test('starts in title with defaults', () {
      final game = VoidRunnerGame();

      expect(game.phase, RunnerPhase.title);
      expect(game.score, 0);
      expect(game.bestScore, 0);
      expect(
        game.playerY,
        VoidRunnerGame.groundY - VoidRunnerGame.playerHeight,
      );
    });

    test('jump arc rises and lands back on ground', () {
      final game = VoidRunnerGame()..startOrRestart();
      final ground = game.playerY;

      game.setControls(jump: true);
      game.tick();
      game.setControls(jump: false);

      var highest = game.playerY;
      for (var i = 0; i < 120; i++) {
        game.tick();
        if (game.playerY < highest) {
          highest = game.playerY;
        }
      }

      expect(highest, lessThan(ground));
      expect(
        game.playerY,
        closeTo(
          VoidRunnerGame.groundY - VoidRunnerGame.playerHeight.toDouble(),
          0.001,
        ),
      );
    });

    test('passing obstacle increases score', () {
      final game = VoidRunnerGame()..startOrRestart();

      game.debugAddObstacle(x: 8, width: 10, height: 20, speed: 3);
      final before = game.score;

      for (var i = 0; i < 20; i++) {
        game.tick();
      }

      expect(game.score, greaterThan(before));
    });

    test('collision transitions to game over and updates best', () {
      final game = VoidRunnerGame()..startOrRestart();
      game.addScoreForDebug(50);

      game.debugAddObstacle(
        x: VoidRunnerGame.playerX.toDouble(),
        width: 14,
        height: 24,
        speed: 0,
      );
      game.tick();

      expect(game.phase, RunnerPhase.gameOver);
      expect(game.bestScore, game.score);
    });

    test('restart clears run score but keeps best', () {
      final game = VoidRunnerGame()..startOrRestart();
      game.addScoreForDebug(80);
      game.debugAddObstacle(
        x: VoidRunnerGame.playerX.toDouble(),
        width: 14,
        height: 24,
        speed: 0,
      );
      game.tick();
      final best = game.bestScore;

      game.startOrRestart();

      expect(game.phase, RunnerPhase.playing);
      expect(game.score, 0);
      expect(game.bestScore, best);
      expect(game.obstacles, isEmpty);
    });
  });
}
