import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

const double _spriteSize = 16;
double _x = 0;
double _vx = 1.5;

void main() {
  flutterxel.init(160, 120, title: 'flutterxel example', fps: 60);

  flutterxel.run(
    () {
      _x += _vx;
      if (_x <= 0 || _x >= flutterxel.width - _spriteSize) {
        _vx = -_vx;
      }
    },
    () {
      flutterxel.cls(1);
      flutterxel.blt(_x, 52, 0, 0, 0, _spriteSize, _spriteSize, colkey: 2);
      flutterxel.blt(
        flutterxel.width - _x - _spriteSize,
        72,
        0,
        0,
        0,
        -_spriteSize,
        _spriteSize,
        colkey: 2,
      );
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final version =
        '${flutterxel.Flutterxel.versionMajor()}.'
        '${flutterxel.Flutterxel.versionMinor()}.'
        '${flutterxel.Flutterxel.versionPatch()}';

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutterxel example')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const flutterxel.FlutterxelView(pixelScale: 3),
              const SizedBox(height: 16),
              Text(
                'flutterxel core ABI v$version\n'
                'screen: ${flutterxel.width}x${flutterxel.height}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
