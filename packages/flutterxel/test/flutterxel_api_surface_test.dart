import 'package:flutterxel/flutterxel.dart' as flutterxel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
  });

  test('exposes init/run/btn/cls/blt/play/load/save API surface', () {
    expect(flutterxel.init, isA<Function>());
    expect(flutterxel.run, isA<Function>());
    expect(flutterxel.btn, isA<Function>());
    expect(flutterxel.cls, isA<Function>());
    expect(flutterxel.blt, isA<Function>());
    expect(flutterxel.play, isA<Function>());
    expect(flutterxel.load, isA<Function>());
    expect(flutterxel.save, isA<Function>());
  });

  test(
    'accepts Pyxel-compatible named options for init/load/save/play/blt',
    () {
      flutterxel.init(
        160,
        120,
        title: 'Flutterxel',
        fps: 30,
        quitKey: 27,
        displayScale: 4,
        captureScale: 2,
        captureSec: 10,
      );

      flutterxel.load(
        'assets/sample.pyxres',
        excludeImages: true,
        excludeTilemaps: false,
        excludeSounds: null,
        excludeMusics: null,
      );

      flutterxel.save(
        'assets/out.pyxres',
        excludeImages: null,
        excludeTilemaps: true,
        excludeSounds: false,
        excludeMusics: null,
      );

      flutterxel.play(0, 1, sec: 0.5, loop: true, resume: false);
      flutterxel.play(0, <int>[1, 2, 3], sec: null, loop: null, resume: null);
      flutterxel.play(0, 'c3e3g3c4r', sec: 1.5, loop: false, resume: true);
      expect(flutterxel.isChannelPlaying(0), isA<bool>());

      flutterxel.cls(0);
      flutterxel.blt(0, 0, 0, 0, 0, 8, 8, colkey: 2, rotate: 0.0, scale: 1.0);

      expect(flutterxel.btn(32), isA<bool>());
    },
  );

  test('run accepts update/draw callbacks', () {
    var updateCalled = false;
    var drawCalled = false;

    flutterxel.init(160, 120);

    flutterxel.run(
      () {
        updateCalled = true;
      },
      () {
        drawCalled = true;
      },
    );

    expect(updateCalled, isTrue);
    expect(drawCalled, isTrue);
    flutterxel.stopRunLoop();
  });

  test('exposes runtime bridge helpers for input and framebuffer', () {
    flutterxel.init(8, 8);

    flutterxel.setBtnState(32, true);
    expect(flutterxel.btn(32), isA<bool>());

    final frame = flutterxel.frameBufferSnapshot();
    expect(frame, isA<List<int>>());
  });
}
