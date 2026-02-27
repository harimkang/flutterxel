import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'src/pixel_puzzle_font.dart';
import 'src/pixel_puzzle_game.dart';

void main() {
  runApp(const PixelPuzzleApp());
}

class PixelPuzzleApp extends StatelessWidget {
  const PixelPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pixel Puzzle',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6BD8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const PixelPuzzlePage(),
    );
  }
}

class PixelPuzzlePage extends StatefulWidget {
  const PixelPuzzlePage({super.key});

  @override
  State<PixelPuzzlePage> createState() => _PixelPuzzlePageState();
}

class _PixelPuzzlePageState extends State<PixelPuzzlePage> {
  final PixelPuzzleGame _game = PixelPuzzleGame();

  bool _leftPressed = false;
  bool _rightPressed = false;
  bool _upPressed = false;
  bool _downPressed = false;
  bool _actPressed = false;

  @override
  void initState() {
    super.initState();
    flutterxel.init(
      PixelPuzzleGame.screenWidth,
      PixelPuzzleGame.screenHeight,
      title: 'Pixel Puzzle',
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
      left: _leftPressed || flutterxel.btn(flutterxel.KEY_LEFT),
      right: _rightPressed || flutterxel.btn(flutterxel.KEY_RIGHT),
      up: _upPressed || flutterxel.btn(flutterxel.KEY_UP),
      down: _downPressed || flutterxel.btn(flutterxel.KEY_DOWN),
      action: _actPressed || flutterxel.btn(flutterxel.KEY_SPACE),
    );
    _game.tick();
  }

  void _draw() {
    flutterxel.cls(flutterxel.COLOR_BLACK);
    _drawBackground();
    _drawBoard();
    _drawHud();

    if (_game.phase == PuzzlePhase.title) {
      _drawOverlay(
        title: 'PIXEL PUZZLE',
        line1: 'TOGGLE CENTER + SIDES',
        line2: 'PRESS ACT TO START',
        titleColor: flutterxel.COLOR_CYAN,
      );
    } else if (_game.phase == PuzzlePhase.cleared) {
      _drawOverlay(
        title: 'BOARD CLEARED',
        line1: 'MOVES ${_game.moves}',
        line2: 'PRESS ACT TO RESTART',
        titleColor: flutterxel.COLOR_LIME,
      );
    }
  }

  void _drawBackground() {
    for (var y = 0; y < PixelPuzzleGame.screenHeight; y += 8) {
      final shade = (y ~/ 8).isEven
          ? flutterxel.COLOR_DARK_BLUE
          : flutterxel.COLOR_NAVY;
      flutterxel.rect(0, y, PixelPuzzleGame.screenWidth, 8, shade);
    }
  }

  void _drawBoard() {
    final boardPixels = PixelPuzzleGame.boardSize * PixelPuzzleGame.tileSize;
    final originX = ((PixelPuzzleGame.screenWidth - boardPixels) / 2).floor();
    const originY = 58;

    for (var row = 0; row < PixelPuzzleGame.boardSize; row++) {
      for (var col = 0; col < PixelPuzzleGame.boardSize; col++) {
        final x = originX + col * PixelPuzzleGame.tileSize;
        final y = originY + row * PixelPuzzleGame.tileSize;
        final lit = _game.isLit(row, col);
        final fill = lit ? flutterxel.COLOR_YELLOW : flutterxel.COLOR_PURPLE;
        final border = lit
            ? flutterxel.COLOR_WHITE
            : flutterxel.COLOR_DARK_BLUE;

        flutterxel.rect(x + 2, y + 2, 20, 20, fill);
        flutterxel.rectb(x + 1, y + 1, 22, 22, border);
      }
    }

    if (_game.phase == PuzzlePhase.playing) {
      final blink = flutterxel.frameCount % 20 < 10;
      final cursorColor = blink ? flutterxel.COLOR_RED : flutterxel.COLOR_PEACH;
      final cx = originX + _game.cursorCol * PixelPuzzleGame.tileSize;
      final cy = originY + _game.cursorRow * PixelPuzzleGame.tileSize;
      flutterxel.rectb(cx, cy, 24, 24, cursorColor);
    }
  }

  void _drawHud() {
    flutterxel.rect(
      0,
      0,
      PixelPuzzleGame.screenWidth,
      14,
      flutterxel.COLOR_NAVY,
    );
    _drawText(3, 4, 'MOVES ${_game.moves}', flutterxel.COLOR_WHITE);
    final bestText = _game.bestMoves == null ? '--' : '${_game.bestMoves}';
    _drawText(92, 4, 'BEST $bestText', flutterxel.COLOR_LIGHT_BLUE);
  }

  void _drawOverlay({
    required String title,
    required String line1,
    required String line2,
    required int titleColor,
  }) {
    const x = 16;
    const y = 28;
    const w = 128;
    const h = 30;
    flutterxel.rect(x, y, w, h, flutterxel.COLOR_BLACK);
    flutterxel.rectb(x, y, w, h, flutterxel.COLOR_CYAN);

    _drawCenteredText(34, title, titleColor);
    _drawCenteredText(42, line1, flutterxel.COLOR_WHITE);
    _drawCenteredText(50, line2, flutterxel.COLOR_YELLOW);
  }

  void _drawCenteredText(int y, String text, int color) {
    final width = PixelPuzzleFont.textWidth(text);
    final x = ((PixelPuzzleGame.screenWidth - width) / 2).floor();
    _drawText(x, y, text, color);
  }

  void _drawText(int x, int y, String text, int color) {
    PixelPuzzleFont.draw(
      (px, py, col) {
        flutterxel.pset(px, py, col);
      },
      x,
      y,
      text,
      color,
    );
  }

  void _setLeft(bool v) => setState(() => _leftPressed = v);
  void _setRight(bool v) => setState(() => _rightPressed = v);
  void _setUp(bool v) => setState(() => _upPressed = v);
  void _setDown(bool v) => setState(() => _downPressed = v);
  void _setAct(bool v) => setState(() => _actPressed = v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final scale =
              (size.width / PixelPuzzleGame.screenWidth) <
                  (size.height / PixelPuzzleGame.screenHeight)
              ? (size.width / PixelPuzzleGame.screenWidth)
              : (size.height / PixelPuzzleGame.screenHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF030510)),
                child: Center(
                  child: flutterxel.FlutterxelView(
                    pixelScale: scale.clamp(1.0, 12.0).toDouble(),
                    backgroundColor: const Color(0xFF050814),
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
                      color: const Color(0xAA101C3D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4564AA)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 92,
                              child: HoldButton(
                                label: 'UP',
                                activeColor: const Color(0xFF2A6AE8),
                                pressed: _upPressed,
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
                                activeColor: const Color(0xFF2A6AE8),
                                pressed: _leftPressed,
                                onChanged: _setLeft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HoldButton(
                                label: 'ACT',
                                activeColor: const Color(0xFFD35A2B),
                                pressed: _actPressed,
                                onChanged: _setAct,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HoldButton(
                                label: 'RIGHT',
                                activeColor: const Color(0xFF2A6AE8),
                                pressed: _rightPressed,
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
                              width: 92,
                              child: HoldButton(
                                label: 'DOWN',
                                activeColor: const Color(0xFF2A6AE8),
                                pressed: _downPressed,
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
    required this.activeColor,
    required this.pressed,
    required this.onChanged,
    super.key,
  });

  final String label;
  final Color activeColor;
  final bool pressed;
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
