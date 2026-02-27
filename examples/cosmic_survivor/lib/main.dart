import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'src/cosmic_survivor_font.dart';
import 'src/cosmic_survivor_game.dart';

void main() {
  runApp(const CosmicSurvivorApp());
}

class CosmicSurvivorApp extends StatelessWidget {
  const CosmicSurvivorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cosmic Survivor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4A9F),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF090D1D),
        useMaterial3: true,
      ),
      home: const CosmicSurvivorPage(),
    );
  }
}

class CosmicSurvivorPage extends StatefulWidget {
  const CosmicSurvivorPage({super.key});

  @override
  State<CosmicSurvivorPage> createState() => _CosmicSurvivorPageState();
}

class _CosmicSurvivorPageState extends State<CosmicSurvivorPage> {
  final CosmicSurvivorGame _game = CosmicSurvivorGame();
  bool _leftPressed = false;
  bool _rightPressed = false;
  bool _firePressed = false;

  @override
  void initState() {
    super.initState();
    flutterxel.init(
      CosmicSurvivorGame.screenWidth,
      CosmicSurvivorGame.screenHeight,
      title: 'Cosmic Survivor',
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
    final left = _leftPressed || flutterxel.btn(flutterxel.KEY_LEFT);
    final right = _rightPressed || flutterxel.btn(flutterxel.KEY_RIGHT);
    final fire = _firePressed || flutterxel.btn(flutterxel.KEY_SPACE);

    _game.setControls(left: left, right: right, fire: fire);
    _game.tick();
  }

  void _draw() {
    flutterxel.cls(flutterxel.COLOR_BLACK);
    _drawStarfield();
    _drawLaneGuides();
    _drawHazards();
    _drawShots();
    _drawPlayer();
    _drawHud();

    if (_game.phase == GamePhase.title) {
      _drawTitleOverlay();
    } else if (_game.phase == GamePhase.gameOver) {
      _drawGameOverOverlay();
    }
  }

  void _drawStarfield() {
    final frame = flutterxel.frameCount;
    for (var i = 0; i < 52; i++) {
      final layer = (i % 3) + 1;
      final x = (i * 53 + frame * layer) % CosmicSurvivorGame.screenWidth;
      final y =
          (i * 29 + frame * (layer + 1)) % CosmicSurvivorGame.screenHeight;
      final color = switch (layer) {
        1 => flutterxel.COLOR_NAVY,
        2 => flutterxel.COLOR_DARK_BLUE,
        _ => flutterxel.COLOR_LIGHT_BLUE,
      };
      flutterxel.pset(x, y, color);
    }
  }

  void _drawLaneGuides() {
    for (var lane = 1; lane < CosmicSurvivorGame.laneCount; lane++) {
      final x = lane * CosmicSurvivorGame.laneWidth;
      flutterxel.line(
        x,
        0,
        x,
        CosmicSurvivorGame.screenHeight - 1,
        flutterxel.COLOR_DARK_BLUE,
      );
    }
  }

  void _drawPlayer() {
    final x = _game.laneCenterX(_game.playerLane);
    const y = CosmicSurvivorGame.playerY;

    flutterxel.tri(x, y - 7, x - 6, y + 5, x + 6, y + 5, flutterxel.COLOR_LIME);
    flutterxel.trib(
      x,
      y - 7,
      x - 6,
      y + 5,
      x + 6,
      y + 5,
      flutterxel.COLOR_WHITE,
    );
    flutterxel.rect(x - 1, y + 5, 3, 3, flutterxel.COLOR_WHITE);

    if (_firePressed) {
      flutterxel.rect(x - 1, y + 9, 3, 2, flutterxel.COLOR_YELLOW);
    }
  }

  void _drawHazards() {
    for (final hazard in _game.hazards) {
      final x = _game.laneCenterX(hazard.lane);
      final y = hazard.y.round();
      flutterxel.circ(x, y, hazard.radius, flutterxel.COLOR_ORANGE);
      flutterxel.circb(x, y, hazard.radius + 1, flutterxel.COLOR_YELLOW);
      flutterxel.pset(x - 1, y - 1, flutterxel.COLOR_RED);
      flutterxel.pset(x + 1, y + 1, flutterxel.COLOR_RED);
    }
  }

  void _drawShots() {
    for (final shot in _game.shots) {
      final x = _game.laneCenterX(shot.lane);
      final y = shot.y.round();
      flutterxel.line(x, y, x, y - 5, flutterxel.COLOR_CYAN);
      flutterxel.pset(x, y - 6, flutterxel.COLOR_WHITE);
    }
  }

  void _drawHud() {
    flutterxel.rect(
      0,
      0,
      CosmicSurvivorGame.screenWidth,
      9,
      flutterxel.COLOR_NAVY,
    );

    _drawText(2, 2, 'S ${_game.score}', flutterxel.COLOR_WHITE);
    _drawText(56, 2, 'BEST ${_game.bestScore}', flutterxel.COLOR_LIGHT_BLUE);

    final lifeColor = _game.lives <= 1
        ? flutterxel.COLOR_RED
        : flutterxel.COLOR_LIME;
    _drawText(128, 2, 'L ${_game.lives}', lifeColor);
  }

  void _drawTitleOverlay() {
    _drawOverlayBox();
    _drawCenteredText(44, 'COSMIC SURVIVOR', flutterxel.COLOR_WHITE);
    _drawCenteredText(56, 'MOVE  FIRE  SURVIVE', flutterxel.COLOR_CYAN);
    _drawCenteredText(68, 'PRESS FIRE TO START', flutterxel.COLOR_YELLOW);
  }

  void _drawGameOverOverlay() {
    _drawOverlayBox();
    _drawCenteredText(44, 'MISSION FAILED', flutterxel.COLOR_RED);
    _drawCenteredText(56, 'SCORE ${_game.score}', flutterxel.COLOR_WHITE);
    _drawCenteredText(68, 'PRESS FIRE TO RETRY', flutterxel.COLOR_YELLOW);
  }

  void _drawOverlayBox() {
    const overlayX = 18;
    const overlayY = 36;
    const overlayW = 124;
    const overlayH = 42;

    flutterxel.rect(
      overlayX,
      overlayY,
      overlayW,
      overlayH,
      flutterxel.COLOR_NAVY,
    );
    flutterxel.rectb(
      overlayX,
      overlayY,
      overlayW,
      overlayH,
      flutterxel.COLOR_CYAN,
    );
  }

  void _drawCenteredText(int y, String text, int col) {
    final textWidth = CosmicSurvivorFont.textWidth(text);
    final x = ((CosmicSurvivorGame.screenWidth - textWidth) / 2).floor();
    _drawText(x, y, text, col);
  }

  void _drawText(int x, int y, String text, int col) {
    CosmicSurvivorFont.draw(
      (px, py, c) {
        flutterxel.pset(px, py, c);
      },
      x,
      y,
      text,
      col,
    );
  }

  void _setLeft(bool pressed) {
    if (_leftPressed == pressed) {
      return;
    }
    setState(() {
      _leftPressed = pressed;
    });
  }

  void _setRight(bool pressed) {
    if (_rightPressed == pressed) {
      return;
    }
    setState(() {
      _rightPressed = pressed;
    });
  }

  void _setFire(bool pressed) {
    if (_firePressed == pressed) {
      return;
    }
    setState(() {
      _firePressed = pressed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxSize = constraints.biggest;
          final scaleByWidth = maxSize.width / CosmicSurvivorGame.screenWidth;
          final scaleByHeight =
              maxSize.height / CosmicSurvivorGame.screenHeight;
          final viewScale = scaleByWidth < scaleByHeight
              ? scaleByWidth
              : scaleByHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF040710)),
                child: Center(
                  child: flutterxel.FlutterxelView(
                    pixelScale: viewScale.clamp(1.0, 12.0).toDouble(),
                    backgroundColor: const Color(0xFF050814),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xAA0D1730),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF395AA0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: HoldButton(
                            label: 'LEFT',
                            pressed: _leftPressed,
                            activeColor: const Color(0xFF2E6BE9),
                            onChanged: _setLeft,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HoldButton(
                            label: 'FIRE',
                            pressed: _firePressed,
                            activeColor: const Color(0xFFDA4C2A),
                            onChanged: _setFire,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HoldButton(
                            label: 'RIGHT',
                            pressed: _rightPressed,
                            activeColor: const Color(0xFF2E6BE9),
                            onChanged: _setRight,
                          ),
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
    final bgColor = pressed ? activeColor : const Color(0xFF1A2745);

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6A87CC)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
