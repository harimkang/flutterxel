import 'dart:collection';
import 'dart:math' as math;

enum RunnerPhase { title, playing, gameOver }

class Obstacle {
  Obstacle({
    required this.x,
    required this.width,
    required this.height,
    required this.speed,
  });

  double x;
  int width;
  int height;
  double speed;
}

class VoidRunnerGame {
  VoidRunnerGame({math.Random? random}) : _random = random ?? math.Random();

  static const int screenWidth = 160;
  static const int screenHeight = 240;
  static const int groundY = 208;
  static const int playerX = 34;
  static const int playerWidth = 12;
  static const int playerHeight = 14;

  static const double gravity = 0.35;
  static const double jumpVelocity = -6.4;

  final math.Random _random;
  final List<Obstacle> _obstacles = <Obstacle>[];

  RunnerPhase _phase = RunnerPhase.title;
  double _playerY = groundY - playerHeight.toDouble();
  double _playerVy = 0;

  int _score = 0;
  int _bestScore = 0;
  int _frames = 0;
  int _spawnTimer = 42;

  bool _jump = false;
  bool _prevJump = false;

  RunnerPhase get phase => _phase;
  double get playerY => _playerY;
  int get score => _score;
  int get bestScore => _bestScore;
  UnmodifiableListView<Obstacle> get obstacles =>
      UnmodifiableListView(_obstacles);

  void setControls({required bool jump}) {
    _jump = jump;
  }

  void startOrRestart() {
    _phase = RunnerPhase.playing;
    _playerY = groundY - playerHeight.toDouble();
    _playerVy = 0;
    _score = 0;
    _frames = 0;
    _spawnTimer = 40;
    _obstacles.clear();
  }

  void tick() {
    final jumpPressed = _jump && !_prevJump;

    if (_phase != RunnerPhase.playing) {
      if (jumpPressed) {
        startOrRestart();
      }
      _prevJump = _jump;
      return;
    }

    if (jumpPressed && _isGrounded()) {
      _playerVy = jumpVelocity;
    }

    _playerVy += gravity;
    _playerY += _playerVy;

    final floor = groundY - playerHeight.toDouble();
    if (_playerY > floor) {
      _playerY = floor;
      _playerVy = 0;
    }

    _frames += 1;
    if (_frames % 4 == 0) {
      _score += 1;
    }

    for (final obstacle in _obstacles) {
      obstacle.x -= obstacle.speed;
    }

    _resolvePasses();
    _resolveCollision();
    _spawnObstacles();

    _prevJump = _jump;
  }

  bool _isGrounded() {
    final floor = groundY - playerHeight.toDouble();
    return (_playerY - floor).abs() < 0.001;
  }

  void _resolvePasses() {
    _obstacles.removeWhere((obstacle) {
      if (obstacle.x + obstacle.width < 0) {
        _score += 6;
        return true;
      }
      return false;
    });
  }

  void _resolveCollision() {
    final playerLeft = playerX;
    final playerTop = _playerY;
    final playerRight = playerX + playerWidth;
    final playerBottom = _playerY + playerHeight;

    for (final obstacle in _obstacles) {
      final obstacleLeft = obstacle.x;
      final obstacleRight = obstacle.x + obstacle.width;
      final obstacleTop = groundY - obstacle.height;
      const obstacleBottom = groundY;

      final overlap =
          playerRight > obstacleLeft &&
          playerLeft < obstacleRight &&
          playerBottom > obstacleTop &&
          playerTop < obstacleBottom;
      if (overlap) {
        _phase = RunnerPhase.gameOver;
        if (_score > _bestScore) {
          _bestScore = _score;
        }
        return;
      }
    }
  }

  void _spawnObstacles() {
    _spawnTimer -= 1;
    if (_spawnTimer > 0) {
      return;
    }

    _obstacles.add(
      Obstacle(
        x: screenWidth + 4,
        width: 8 + _random.nextInt(10),
        height: 14 + _random.nextInt(18),
        speed: (2.2 + _score / 500).clamp(2.2, 4.2),
      ),
    );

    final base = 42 - (_score ~/ 140);
    _spawnTimer = base.clamp(20, 42);
  }

  void debugAddObstacle({
    required double x,
    required int width,
    required int height,
    required double speed,
  }) {
    _obstacles.add(Obstacle(x: x, width: width, height: height, speed: speed));
  }

  void addScoreForDebug(int amount) {
    _score += amount;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }
}
