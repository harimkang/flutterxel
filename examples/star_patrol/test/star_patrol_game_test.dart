import 'package:flutter_test/flutter_test.dart';
import 'package:star_patrol/src/star_patrol_game.dart';

void main() {
  group('StarPatrolGame', () {
    test('starts in title with default values', () {
      final game = StarPatrolGame();

      expect(game.phase, PatrolPhase.title);
      expect(game.score, 0);
      expect(game.bestScore, 0);
      expect(game.lives, StarPatrolGame.maxLives);
    });

    test('player movement stays in bounds', () {
      final game = StarPatrolGame()..startOrRestart();

      for (var i = 0; i < 120; i++) {
        game.setControls(
          left: true,
          right: false,
          up: true,
          down: false,
          fire: false,
        );
        game.tick();
      }

      expect(game.playerX, StarPatrolGame.playerRadius.toDouble());
      expect(game.playerY, greaterThanOrEqualTo(18));

      for (var i = 0; i < 120; i++) {
        game.setControls(
          left: false,
          right: true,
          up: false,
          down: true,
          fire: false,
        );
        game.tick();
      }

      expect(
        game.playerX,
        lessThanOrEqualTo(
          StarPatrolGame.screenWidth - StarPatrolGame.playerRadius,
        ),
      );
      expect(game.playerY, lessThanOrEqualTo(StarPatrolGame.playerMaxY));
    });

    test('firing destroys drone and increases score', () {
      final game = StarPatrolGame()..startOrRestart();

      game.debugAddDrone(
        x: game.playerX,
        y: game.playerY - 20,
        vx: 0,
        vy: 0,
        radius: 4,
      );

      game.setControls(
        left: false,
        right: false,
        up: false,
        down: false,
        fire: true,
      );
      game.tick();
      game.setControls(
        left: false,
        right: false,
        up: false,
        down: false,
        fire: false,
      );
      for (var i = 0; i < 12; i++) {
        game.tick();
      }

      expect(game.drones, isEmpty);
      expect(game.score, greaterThanOrEqualTo(15));
    });

    test('damage leads to game over at zero lives', () {
      final game = StarPatrolGame()..startOrRestart();

      for (var i = 0; i < StarPatrolGame.maxLives; i++) {
        game.debugAddDrone(
          x: game.playerX,
          y: game.playerY,
          vx: 0,
          vy: 0,
          radius: 4,
        );
        game.tick();
      }

      expect(game.lives, 0);
      expect(game.phase, PatrolPhase.gameOver);
    });

    test('restart resets run stats and keeps best score', () {
      final game = StarPatrolGame()..startOrRestart();

      game.addScoreForDebug(90);
      game.forceGameOverForDebug();
      final best = game.bestScore;

      game.startOrRestart();

      expect(game.phase, PatrolPhase.playing);
      expect(game.score, 0);
      expect(game.lives, StarPatrolGame.maxLives);
      expect(game.bestScore, best);
      expect(game.drones, isEmpty);
    });
  });
}
