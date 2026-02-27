import 'dart:collection';
import 'dart:math' as math;

enum GamePhase { title, playing, gameOver }

class Hazard {
  Hazard({
    required this.lane,
    required this.y,
    required this.speed,
    required this.radius,
  });

  int lane;
  double y;
  double speed;
  int radius;
}

class PulseShot {
  PulseShot({required this.lane, required this.y, required this.speed});

  int lane;
  double y;
  double speed;
}

class CosmicSurvivorGame {
  CosmicSurvivorGame({math.Random? random}) : _random = random ?? math.Random();

  static const int screenWidth = 160;
  static const int screenHeight = 240;
  static const int laneCount = 5;
  static const int maxLives = 3;
  static const int initialPlayerLane = 2;
  static const int laneWidth = screenWidth ~/ laneCount;
  static const int playerY = screenHeight - 14;
  static const int scorePerMeteor = 10;
  static const int scorePerDodge = 1;
  static const int shotCooldownFrames = 8;

  final math.Random _random;
  final List<Hazard> _hazards = <Hazard>[];
  final List<PulseShot> _shots = <PulseShot>[];

  GamePhase _phase = GamePhase.title;
  int _playerLane = initialPlayerLane;
  int _lives = maxLives;
  int _score = 0;
  int _bestScore = 0;
  bool _left = false;
  bool _right = false;
  bool _fire = false;
  bool _prevLeft = false;
  bool _prevRight = false;
  bool _prevFire = false;
  int _fireCooldown = 0;
  int _spawnTimer = 30;

  GamePhase get phase => _phase;
  int get playerLane => _playerLane;
  int get lives => _lives;
  int get score => _score;
  int get bestScore => _bestScore;
  UnmodifiableListView<Hazard> get hazards => UnmodifiableListView(_hazards);
  UnmodifiableListView<PulseShot> get shots => UnmodifiableListView(_shots);

  int laneCenterX(int lane) => lane * laneWidth + laneWidth ~/ 2;

  void setControls({
    required bool left,
    required bool right,
    required bool fire,
  }) {
    _left = left;
    _right = right;
    _fire = fire;
  }

  void startOrRestart() {
    _phase = GamePhase.playing;
    _playerLane = initialPlayerLane;
    _lives = maxLives;
    _score = 0;
    _fireCooldown = 0;
    _spawnTimer = 25;
    _hazards.clear();
    _shots.clear();
  }

  void tick() {
    final firePressed = _fire && !_prevFire;

    if (_phase != GamePhase.playing) {
      if (firePressed) {
        startOrRestart();
      }
      _capturePreviousControlState();
      return;
    }

    _handleMovement();
    if (firePressed && _fireCooldown == 0) {
      _shots.add(PulseShot(lane: _playerLane, y: playerY - 4, speed: 4.5));
      _fireCooldown = shotCooldownFrames;
    }

    if (_fireCooldown > 0) {
      _fireCooldown -= 1;
    }

    for (final shot in _shots) {
      shot.y -= shot.speed;
    }

    for (final hazard in _hazards) {
      hazard.y += hazard.speed;
    }

    _resolveCollisions();
    _cleanupOutOfBounds();
    _spawnHazards();
    _capturePreviousControlState();
  }

  void _handleMovement() {
    final leftPressed = _left && !_prevLeft;
    final rightPressed = _right && !_prevRight;

    if (leftPressed && !rightPressed) {
      _playerLane = (_playerLane - 1).clamp(0, laneCount - 1);
    } else if (rightPressed && !leftPressed) {
      _playerLane = (_playerLane + 1).clamp(0, laneCount - 1);
    }
  }

  void _resolveCollisions() {
    final removedShots = <PulseShot>{};
    final removedHazards = <Hazard>{};

    for (final shot in _shots) {
      for (final hazard in _hazards) {
        if (shot.lane != hazard.lane) {
          continue;
        }
        if ((shot.y - hazard.y).abs() <= hazard.radius + 2) {
          removedShots.add(shot);
          removedHazards.add(hazard);
          _score += scorePerMeteor;
          break;
        }
      }
    }

    if (removedShots.isNotEmpty) {
      _shots.removeWhere(removedShots.contains);
    }
    if (removedHazards.isNotEmpty) {
      _hazards.removeWhere(removedHazards.contains);
    }

    final playerHits = <Hazard>[];
    for (final hazard in _hazards) {
      if (hazard.lane == _playerLane && hazard.y >= playerY - hazard.radius) {
        playerHits.add(hazard);
      }
    }

    if (playerHits.isNotEmpty) {
      _hazards.removeWhere(playerHits.contains);
      _lives = (_lives - playerHits.length).clamp(0, maxLives);
      if (_lives == 0) {
        _phase = GamePhase.gameOver;
        if (_score > _bestScore) {
          _bestScore = _score;
        }
      }
    }
  }

  void _cleanupOutOfBounds() {
    _shots.removeWhere((shot) => shot.y < -8);

    _hazards.removeWhere((hazard) {
      if (hazard.y > screenHeight + hazard.radius) {
        _score += scorePerDodge;
        return true;
      }
      return false;
    });
  }

  void _spawnHazards() {
    _spawnTimer -= 1;
    if (_spawnTimer > 0) {
      return;
    }

    _hazards.add(
      Hazard(
        lane: _random.nextInt(laneCount),
        y: -6,
        speed: _hazardSpeed(),
        radius: 3 + _random.nextInt(3),
      ),
    );

    final base = 30 - (_score ~/ 40);
    _spawnTimer = base.clamp(10, 30);
  }

  double _hazardSpeed() {
    final base = 1.2 + (_score / 350);
    return base.clamp(1.2, 3.4);
  }

  void _capturePreviousControlState() {
    _prevLeft = _left;
    _prevRight = _right;
    _prevFire = _fire;
  }

  void debugAddHazard({
    required int lane,
    required double y,
    required double speed,
    required int radius,
  }) {
    _hazards.add(Hazard(lane: lane, y: y, speed: speed, radius: radius));
  }

  void addScoreForDebug(int amount) {
    _score += amount;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }

  void forceGameOverForDebug() {
    _phase = GamePhase.gameOver;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }
}
