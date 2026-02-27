import 'package:cosmic_survivor/src/cosmic_survivor_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CosmicSurvivorGame', () {
    test('starts in title state with default stats', () {
      final game = CosmicSurvivorGame();

      expect(game.phase, GamePhase.title);
      expect(game.score, 0);
      expect(game.bestScore, 0);
      expect(game.lives, CosmicSurvivorGame.maxLives);
      expect(game.playerLane, CosmicSurvivorGame.initialPlayerLane);
    });

    test('moves player within lane bounds', () {
      final game = CosmicSurvivorGame()..startOrRestart();

      game.setControls(left: true, right: false, fire: false);
      game.tick();
      game.setControls(left: false, right: false, fire: false);
      game.tick();

      expect(game.playerLane, CosmicSurvivorGame.initialPlayerLane - 1);

      for (var i = 0; i < 20; i++) {
        game.setControls(left: true, right: false, fire: false);
        game.tick();
        game.setControls(left: false, right: false, fire: false);
        game.tick();
      }

      expect(game.playerLane, 0);
    });

    test('fire destroys hazard in the same lane and increases score', () {
      final game = CosmicSurvivorGame()..startOrRestart();

      game.debugAddHazard(
        lane: game.playerLane,
        y: CosmicSurvivorGame.playerY - 24,
        speed: 0,
        radius: 4,
      );

      game.setControls(left: false, right: false, fire: true);
      game.tick();
      game.setControls(left: false, right: false, fire: false);

      for (var i = 0; i < 10; i++) {
        game.tick();
      }

      expect(game.hazards, isEmpty);
      expect(game.score, greaterThanOrEqualTo(10));
    });

    test('player hit removes one life and game over at zero lives', () {
      final game = CosmicSurvivorGame()..startOrRestart();

      for (var i = 0; i < CosmicSurvivorGame.maxLives; i++) {
        game.debugAddHazard(
          lane: game.playerLane,
          y: CosmicSurvivorGame.playerY - 1,
          speed: 0,
          radius: 4,
        );
        game.tick();

        if (i < CosmicSurvivorGame.maxLives - 1) {
          expect(game.phase, GamePhase.playing);
        }
      }

      expect(game.lives, 0);
      expect(game.phase, GamePhase.gameOver);
      expect(game.bestScore, game.score);
    });

    test('restart resets run stats and keeps best score', () {
      final game = CosmicSurvivorGame()..startOrRestart();

      game.addScoreForDebug(42);
      game.forceGameOverForDebug();
      final best = game.bestScore;

      game.startOrRestart();

      expect(game.phase, GamePhase.playing);
      expect(game.score, 0);
      expect(game.lives, CosmicSurvivorGame.maxLives);
      expect(game.bestScore, best);
      expect(game.hazards, isEmpty);
    });
  });
}
