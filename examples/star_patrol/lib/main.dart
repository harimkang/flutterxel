import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'src/star_patrol_font.dart';
import 'src/star_patrol_game.dart';

void main() {
  runApp(const StarPatrolApp());
}

class StarPatrolApp extends StatelessWidget {
  const StarPatrolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Star Patrol',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5DC8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const StarPatrolPage(),
    );
  }
}

class StarPatrolPage extends StatefulWidget {
  const StarPatrolPage({super.key});

  @override
  State<StarPatrolPage> createState() => _StarPatrolPageState();
}

class _StarPatrolPageState extends State<StarPatrolPage> {
  final StarPatrolGame _game = StarPatrolGame();

  bool _left = false;
  bool _right = false;
  bool _up = false;
  bool _down = false;
  bool _fire = false;

  @override
  void initState() {
    super.initState();
    flutterxel.init(
      StarPatrolGame.screenWidth,
      StarPatrolGame.screenHeight,
      title: 'Star Patrol',
      fps: 60,
    );
    flutterxel.run(_update, _draw);
  }

  @override
  void dispose() {
    flutterxel.stopRunLoop();
    super.dispose();
  }

  void _update() {
    _game.setControls(
      left: _left || flutterxel.btn(flutterxel.KEY_LEFT),
      right: _right || flutterxel.btn(flutterxel.KEY_RIGHT),
      up: _up || flutterxel.btn(flutterxel.KEY_UP),
      down: _down || flutterxel.btn(flutterxel.KEY_DOWN),
      fire: _fire || flutterxel.btn(flutterxel.KEY_SPACE),
    );
    _game.tick();
  }

  void _draw() {
    flutterxel.cls(flutterxel.COLOR_BLACK);
    _drawStars();
    _drawPlayer();
    _drawBolts();
    _drawDrones();
    _drawHud();

    if (_game.phase == PatrolPhase.title) {
      _drawOverlay(
        title: 'STAR PATROL',
        line1: 'DODGE + SHOOT',
        line2: 'PRESS FIRE TO START',
        titleColor: flutterxel.COLOR_CYAN,
      );
    } else if (_game.phase == PatrolPhase.gameOver) {
      _drawOverlay(
        title: 'SHIP LOST',
        line1: 'SCORE ${_game.score}',
        line2: 'PRESS FIRE TO RETRY',
        titleColor: flutterxel.COLOR_RED,
      );
    }
  }

  void _drawStars() {
    final frame = flutterxel.frameCount;
    for (var i = 0; i < 70; i++) {
      final speed = (i % 3) + 1;
      final x = (i * 29 + frame * speed) % StarPatrolGame.screenWidth;
      final y = (i * 17 + frame * (speed + 1)) % StarPatrolGame.screenHeight;
      final col = switch (speed) {
        1 => flutterxel.COLOR_DARK_BLUE,
        2 => flutterxel.COLOR_LIGHT_BLUE,
        _ => flutterxel.COLOR_WHITE,
      };
      flutterxel.pset(x, y, col);
    }
  }

  void _drawPlayer() {
    final x = _game.playerX.round();
    final y = _game.playerY.round();
    flutterxel.tri(x, y - 8, x - 7, y + 6, x + 7, y + 6, flutterxel.COLOR_LIME);
    flutterxel.trib(
      x,
      y - 8,
      x - 7,
      y + 6,
      x + 7,
      y + 6,
      flutterxel.COLOR_WHITE,
    );

    if (_fire) {
      flutterxel.rect(x - 1, y + 6, 3, 2, flutterxel.COLOR_YELLOW);
    }
  }

  void _drawBolts() {
    for (final bolt in _game.bolts) {
      final x = bolt.x.round();
      final y = bolt.y.round();
      flutterxel.line(x, y, x, y - 6, flutterxel.COLOR_CYAN);
      flutterxel.pset(x, y - 7, flutterxel.COLOR_WHITE);
    }
  }

  void _drawDrones() {
    for (final drone in _game.drones) {
      final x = drone.x.round();
      final y = drone.y.round();
      flutterxel.circ(x, y, drone.radius, flutterxel.COLOR_ORANGE);
      flutterxel.circb(x, y, drone.radius + 1, flutterxel.COLOR_RED);
      flutterxel.pset(x - 1, y - 1, flutterxel.COLOR_WHITE);
      flutterxel.pset(x + 1, y + 1, flutterxel.COLOR_WHITE);
    }
  }

  void _drawHud() {
    flutterxel.rect(
      0,
      0,
      StarPatrolGame.screenWidth,
      12,
      flutterxel.COLOR_NAVY,
    );
    _drawText(3, 3, 'S ${_game.score}', flutterxel.COLOR_WHITE);
    _drawText(48, 3, 'BEST ${_game.bestScore}', flutterxel.COLOR_LIGHT_BLUE);
    final lifeColor = _game.lives <= 1
        ? flutterxel.COLOR_RED
        : flutterxel.COLOR_LIME;
    _drawText(130, 3, 'L ${_game.lives}', lifeColor);
  }

  void _drawOverlay({
    required String title,
    required String line1,
    required String line2,
    required int titleColor,
  }) {
    const x = 16;
    const y = 34;
    const w = 128;
    const h = 32;
    flutterxel.rect(x, y, w, h, flutterxel.COLOR_BLACK);
    flutterxel.rectb(x, y, w, h, flutterxel.COLOR_CYAN);
    _drawCenteredText(40, title, titleColor);
    _drawCenteredText(48, line1, flutterxel.COLOR_WHITE);
    _drawCenteredText(56, line2, flutterxel.COLOR_YELLOW);
  }

  void _drawCenteredText(int y, String text, int color) {
    final width = StarPatrolFont.textWidth(text);
    final x = ((StarPatrolGame.screenWidth - width) / 2).floor();
    _drawText(x, y, text, color);
  }

  void _drawText(int x, int y, String text, int color) {
    StarPatrolFont.draw(
      (px, py, col) {
        flutterxel.pset(px, py, col);
      },
      x,
      y,
      text,
      color,
    );
  }

  void _setLeft(bool v) => setState(() => _left = v);
  void _setRight(bool v) => setState(() => _right = v);
  void _setUp(bool v) => setState(() => _up = v);
  void _setDown(bool v) => setState(() => _down = v);
  void _setFire(bool v) => setState(() => _fire = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scale =
              (size.width / StarPatrolGame.screenWidth) <
                  (size.height / StarPatrolGame.screenHeight)
              ? (size.width / StarPatrolGame.screenWidth)
              : (size.height / StarPatrolGame.screenHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF04070F)),
                child: Center(
                  child: flutterxel.FlutterxelView(
                    pixelScale: scale.clamp(1.0, 12.0).toDouble(),
                    backgroundColor: const Color(0xFF02040A),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 10,
                      right: 10,
                      bottom: 10,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xAA121E3B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3E63A2)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 94,
                              child: HoldButton(
                                label: 'UP',
                                pressed: _up,
                                activeColor: const Color(0xFF2A6AE8),
                                onChanged: _setUp,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: HoldButton(
                                label: 'LEFT',
                                pressed: _left,
                                activeColor: const Color(0xFF2A6AE8),
                                onChanged: _setLeft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HoldButton(
                                label: 'FIRE',
                                pressed: _fire,
                                activeColor: const Color(0xFFD1562D),
                                onChanged: _setFire,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HoldButton(
                                label: 'RIGHT',
                                pressed: _right,
                                activeColor: const Color(0xFF2A6AE8),
                                onChanged: _setRight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 94,
                              child: HoldButton(
                                label: 'DOWN',
                                pressed: _down,
                                activeColor: const Color(0xFF2A6AE8),
                                onChanged: _setDown,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HoldButton extends StatelessWidget {
  const HoldButton({
    required this.label,
    required this.pressed,
    required this.activeColor,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool pressed;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = pressed ? activeColor : const Color(0xFF1A2745);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF738DCA)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
