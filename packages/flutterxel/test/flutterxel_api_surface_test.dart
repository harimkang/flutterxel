import 'package:flutterxel/flutterxel.dart' as flutterxel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
  });

  test(
    'exposes init/run/btn/btnp/btnr/btnv/cls/blt/play/stop/load/save API surface',
    () {
      expect(flutterxel.init, isA<Function>());
      expect(flutterxel.run, isA<Function>());
      expect(flutterxel.btn, isA<Function>());
      expect(flutterxel.btnp, isA<Function>());
      expect(flutterxel.btnr, isA<Function>());
      expect(flutterxel.btnv, isA<Function>());
      expect(flutterxel.cls, isA<Function>());
      expect(flutterxel.blt, isA<Function>());
      expect(flutterxel.play, isA<Function>());
      expect(flutterxel.stop, isA<Function>());
      expect(flutterxel.load, isA<Function>());
      expect(flutterxel.save, isA<Function>());
    },
  );

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
      flutterxel.stop(0);
      expect(flutterxel.isChannelPlaying(0), isFalse);

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
    expect(flutterxel.btnp(32), isA<bool>());
    expect(flutterxel.btnr(32), isA<bool>());
    flutterxel.setBtnValue(1000, 123);
    expect(flutterxel.btnv(1000), 123);

    final frame = flutterxel.frameBufferSnapshot();
    expect(frame, isA<List<int>>());
  });

  test('btnp and btnr expose frame-based input transitions', () {
    flutterxel.init(8, 8);

    expect(flutterxel.btnp(32), isFalse);
    expect(flutterxel.btnr(32), isFalse);

    flutterxel.setBtnState(32, true);
    expect(flutterxel.btnp(32), isTrue);

    flutterxel.run(() {}, () {});
    expect(flutterxel.btnp(32), isFalse);

    flutterxel.run(() {}, () {});
    expect(flutterxel.btnp(32, hold: 2, period: 2), isTrue);

    flutterxel.setBtnState(32, false);
    expect(flutterxel.btnr(32), isTrue);

    flutterxel.run(() {}, () {});
    expect(flutterxel.btnr(32), isFalse);

    flutterxel.setBtnValue(1001, 33);
    expect(flutterxel.btnv(1001), 33);

    flutterxel.setBtnValue(flutterxel.MOUSE_WHEEL_Y, 4);
    expect(flutterxel.btnv(flutterxel.MOUSE_WHEEL_Y), 4);
    flutterxel.run(() {}, () {});
    expect(flutterxel.btnv(flutterxel.MOUSE_WHEEL_Y), 0);
  });

  test('stop controls channel playback state by channel or globally', () {
    flutterxel.init(8, 8);

    flutterxel.play(0, 1);
    flutterxel.play(1, 2);
    expect(flutterxel.isChannelPlaying(0), isTrue);
    expect(flutterxel.isChannelPlaying(1), isTrue);

    flutterxel.stop(0);
    expect(flutterxel.isChannelPlaying(0), isFalse);
    expect(flutterxel.isChannelPlaying(1), isTrue);

    flutterxel.stop();
    expect(flutterxel.isChannelPlaying(0), isFalse);
    expect(flutterxel.isChannelPlaying(1), isFalse);
  });
}
