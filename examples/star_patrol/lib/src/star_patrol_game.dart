import 'dart:collection';
import 'dart:math' as math;

enum PatrolPhase { title, playing, gameOver }

class Drone {
  Drone({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
  });

  double x;
  double y;
  double vx;
  double vy;
  int radius;
}

class Bolt {
  Bolt({required this.x, required this.y, required this.speed});

  double x;
  double y;
  double speed;
}

class StarPatrolGame {
  StarPatrolGame({math.Random? random}) : _random = random ?? math.Random();

  static const int screenWidth = 160;
  static const int screenHeight = 240;
  static const int maxLives = 3;
  static const int playerRadius = 6;
  static const double playerMinY = 18;
  static const double playerMaxY = screenHeight - 72;
  static const double escapeY = playerMaxY + 24;

  final math.Random _random;
  final List<Drone> _drones = <Drone>[];
  final List<Bolt> _bolts = <Bolt>[];

  PatrolPhase _phase = PatrolPhase.title;
  double _playerX = screenWidth / 2;
  double _playerY = playerMaxY;
  int _lives = maxLives;
  int _score = 0;
  int _bestScore = 0;

  bool _left = false;
  bool _right = false;
  bool _up = false;
  bool _down = false;
  bool _fire = false;
  bool _prevFire = false;

  int _fireCooldown = 0;
  int _spawnTimer = 24;

  PatrolPhase get phase => _phase;
  double get playerX => _playerX;
  double get playerY => _playerY;
  int get lives => _lives;
  int get score => _score;
  int get bestScore => _bestScore;
  UnmodifiableListView<Drone> get drones => UnmodifiableListView(_drones);
  UnmodifiableListView<Bolt> get bolts => UnmodifiableListView(_bolts);

  void setControls({
    required bool left,
    required bool right,
    required bool up,
    required bool down,
    required bool fire,
  }) {
    _left = left;
    _right = right;
    _up = up;
    _down = down;
    _fire = fire;
  }

  void startOrRestart() {
    _phase = PatrolPhase.playing;
    _playerX = screenWidth / 2;
    _playerY = playerMaxY;
    _lives = maxLives;
    _score = 0;
    _fireCooldown = 0;
    _spawnTimer = 22;
    _drones.clear();
    _bolts.clear();
  }

  void tick() {
    final firePressed = _fire && !_prevFire;

    if (_phase != PatrolPhase.playing) {
      if (firePressed) {
        startOrRestart();
      }
      _prevFire = _fire;
      return;
    }

    _movePlayer();

    if (firePressed && _fireCooldown == 0) {
      _bolts.add(Bolt(x: _playerX, y: _playerY - 8, speed: 4.8));
      _fireCooldown = 6;
    }
    if (_fireCooldown > 0) {
      _fireCooldown -= 1;
    }

    for (final bolt in _bolts) {
      bolt.y -= bolt.speed;
    }
    for (final drone in _drones) {
      drone.x += drone.vx;
      drone.y += drone.vy;
    }

    _resolveShotHits();
    _resolveDamageAndEscapes();
    _cleanupEntities();
    _spawnDrones();

    _prevFire = _fire;
  }

  void _movePlayer() {
    if (_left) {
      _playerX -= 2.2;
    }
    if (_right) {
      _playerX += 2.2;
    }
    if (_up) {
      _playerY -= 2.2;
    }
    if (_down) {
      _playerY += 2.2;
    }

    _playerX = _playerX
        .clamp(playerRadius.toDouble(), screenWidth - playerRadius)
        .toDouble();
    _playerY = _playerY.clamp(playerMinY, playerMaxY).toDouble();
  }

  void _resolveShotHits() {
    final hitBolts = <Bolt>{};
    final hitDrones = <Drone>{};

    for (final bolt in _bolts) {
      for (final drone in _drones) {
        final dx = bolt.x - drone.x;
        final dy = bolt.y - drone.y;
        final limit = drone.radius + 2;
        if (dx * dx + dy * dy <= limit * limit) {
          hitBolts.add(bolt);
          hitDrones.add(drone);
          _score += 15;
          break;
        }
      }
    }

    if (hitBolts.isNotEmpty) {
      _bolts.removeWhere(hitBolts.contains);
    }
    if (hitDrones.isNotEmpty) {
      _drones.removeWhere(hitDrones.contains);
    }
  }

  void _resolveDamageAndEscapes() {
    final removed = <Drone>{};
    var damage = 0;

    for (final drone in _drones) {
      final dx = _playerX - drone.x;
      final dy = _playerY - drone.y;
      final limit = playerRadius + drone.radius;
      if (dx * dx + dy * dy <= limit * limit) {
        removed.add(drone);
        damage += 1;
        continue;
      }
      if (drone.y > escapeY) {
        removed.add(drone);
        damage += 1;
      }
    }

    if (removed.isNotEmpty) {
      _drones.removeWhere(removed.contains);
      _lives = (_lives - damage).clamp(0, maxLives);
      if (_lives == 0) {
        _phase = PatrolPhase.gameOver;
        if (_score > _bestScore) {
          _bestScore = _score;
        }
      }
    }
  }

  void _cleanupEntities() {
    _bolts.removeWhere((bolt) => bolt.y < -8);
    _drones.removeWhere((drone) => drone.x < -16 || drone.x > screenWidth + 16);
  }

  void _spawnDrones() {
    _spawnTimer -= 1;
    if (_spawnTimer > 0) {
      return;
    }

    _drones.add(
      Drone(
        x: 14 + _random.nextDouble() * (screenWidth - 28),
        y: -8,
        vx: (_random.nextDouble() - 0.5) * 1.0,
        vy: 1.1 + _random.nextDouble() * 1.2 + (_score / 500),
        radius: 4 + _random.nextInt(2),
      ),
    );

    final base = 28 - (_score ~/ 120);
    _spawnTimer = base.clamp(10, 28);
  }

  void debugAddDrone({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required int radius,
  }) {
    _drones.add(Drone(x: x, y: y, vx: vx, vy: vy, radius: radius));
  }

  void addScoreForDebug(int amount) {
    _score += amount;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }

  void forceGameOverForDebug() {
    _phase = PatrolPhase.gameOver;
    if (_score > _bestScore) {
      _bestScore = _score;
    }
  }
}
