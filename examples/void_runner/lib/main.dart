import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'src/void_runner_font.dart';
import 'src/void_runner_game.dart';

void main() {
  runApp(const VoidRunnerApp());
}

class VoidRunnerApp extends StatelessWidget {
  const VoidRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Void Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F70D4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const VoidRunnerPage(),
    );
  }
}

class VoidRunnerPage extends StatefulWidget {
  const VoidRunnerPage({super.key});

  @override
  State<VoidRunnerPage> createState() => _VoidRunnerPageState();
}

class _VoidRunnerPageState extends State<VoidRunnerPage> {
  final VoidRunnerGame _game = VoidRunnerGame();

  bool _jumpPressed = false;

  @override
  void initState() {
    super.initState();
    flutterxel.init(
      VoidRunnerGame.screenWidth,
      VoidRunnerGame.screenHeight,
      title: 'Void Runner',
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
      jump:
          _jumpPressed ||
          flutterxel.btn(flutterxel.KEY_SPACE) ||
          flutterxel.btn(flutterxel.KEY_UP),
    );
    _game.tick();
  }

  void _draw() {
    flutterxel.cls(flutterxel.COLOR_DARK_BLUE);
    _drawSky();
    _drawGround();
    _drawRunner();
    _drawObstacles();
    _drawHud();

    if (_game.phase == RunnerPhase.title) {
      _drawOverlay(
        title: 'VOID RUNNER',
        line1: 'JUMP OVER OBSTACLES',
        line2: 'PRESS JUMP TO START',
        titleColor: flutterxel.COLOR_CYAN,
      );
    } else if (_game.phase == RunnerPhase.gameOver) {
      _drawOverlay(
        title: 'CRASHED',
        line1: 'SCORE ${_game.score}',
        line2: 'PRESS JUMP TO RETRY',
        titleColor: flutterxel.COLOR_RED,
      );
    }
  }

  void _drawSky() {
    final frame = flutterxel.frameCount;
    for (var i = 0; i < 56; i++) {
      final speed = (i % 4) + 1;
      final x = (i * 23 + frame * speed) % VoidRunnerGame.screenWidth;
      final y =
          (i * 11 + frame * (speed ~/ 2 + 1)) % (VoidRunnerGame.groundY - 8);
      final color = switch (speed) {
        1 => flutterxel.COLOR_NAVY,
        2 => flutterxel.COLOR_DARK_BLUE,
        3 => flutterxel.COLOR_LIGHT_BLUE,
        _ => flutterxel.COLOR_WHITE,
      };
      flutterxel.pset(x, y, color);
    }
  }

  void _drawGround() {
    flutterxel.rect(
      0,
      VoidRunnerGame.groundY,
      VoidRunnerGame.screenWidth,
      VoidRunnerGame.screenHeight - VoidRunnerGame.groundY,
      flutterxel.COLOR_PURPLE,
    );
    for (var x = 0; x < VoidRunnerGame.screenWidth; x += 8) {
      final offset = (flutterxel.frameCount ~/ 2) % 8;
      flutterxel.rect(
        (x - offset) % VoidRunnerGame.screenWidth,
        VoidRunnerGame.groundY + 6,
        4,
        2,
        flutterxel.COLOR_PINK,
      );
    }
  }

  void _drawRunner() {
    final x = VoidRunnerGame.playerX;
    final y = _game.playerY.round();

    flutterxel.rect(
      x,
      y,
      VoidRunnerGame.playerWidth,
      VoidRunnerGame.playerHeight,
      flutterxel.COLOR_LIME,
    );
    flutterxel.rectb(
      x,
      y,
      VoidRunnerGame.playerWidth,
      VoidRunnerGame.playerHeight,
      flutterxel.COLOR_WHITE,
    );
    flutterxel.pset(x + 9, y + 4, flutterxel.COLOR_BLACK);
    flutterxel.line(x + 2, y + 12, x + 8, y + 12, flutterxel.COLOR_GREEN);
  }

  void _drawObstacles() {
    for (final obstacle in _game.obstacles) {
      final x = obstacle.x.round();
      final y = VoidRunnerGame.groundY - obstacle.height;
      flutterxel.rect(
        x,
        y,
        obstacle.width,
        obstacle.height,
        flutterxel.COLOR_ORANGE,
      );
      flutterxel.rectb(
        x,
        y,
        obstacle.width,
        obstacle.height,
        flutterxel.COLOR_RED,
      );
    }
  }

  void _drawHud() {
    flutterxel.rect(
      0,
      0,
      VoidRunnerGame.screenWidth,
      12,
      flutterxel.COLOR_NAVY,
    );
    _drawText(3, 3, 'DIST ${_game.score}', flutterxel.COLOR_WHITE);
    _drawText(96, 3, 'BEST ${_game.bestScore}', flutterxel.COLOR_LIGHT_BLUE);
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
    const h = 30;
    flutterxel.rect(x, y, w, h, flutterxel.COLOR_BLACK);
    flutterxel.rectb(x, y, w, h, flutterxel.COLOR_CYAN);
    _drawCenteredText(40, title, titleColor);
    _drawCenteredText(48, line1, flutterxel.COLOR_WHITE);
    _drawCenteredText(56, line2, flutterxel.COLOR_YELLOW);
  }

  void _drawCenteredText(int y, String text, int color) {
    final width = VoidRunnerFont.textWidth(text);
    final x = ((VoidRunnerGame.screenWidth - width) / 2).floor();
    _drawText(x, y, text, color);
  }

  void _drawText(int x, int y, String text, int color) {
    VoidRunnerFont.draw(
      (px, py, col) {
        flutterxel.pset(px, py, col);
      },
      x,
      y,
      text,
      color,
    );
  }

  void _setJump(bool v) => setState(() => _jumpPressed = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scale =
              (size.width / VoidRunnerGame.screenWidth) <
                  (size.height / VoidRunnerGame.screenHeight)
              ? (size.width / VoidRunnerGame.screenWidth)
              : (size.height / VoidRunnerGame.screenHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF03050D)),
                child: Center(
                  child: flutterxel.FlutterxelView(
                    pixelScale: scale.clamp(1.0, 12.0).toDouble(),
                    backgroundColor: const Color(0xFF040912),
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
                      color: const Color(0xAA121C35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3E5E9B)),
                    ),
                    child: HoldButton(
                      label: 'JUMP',
                      pressed: _jumpPressed,
                      activeColor: const Color(0xFFD35C2C),
                      onChanged: _setJump,
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
        padding: const EdgeInsets.symmetric(vertical: 14),
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
