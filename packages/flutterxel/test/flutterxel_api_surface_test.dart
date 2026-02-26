import 'package:flutterxel/flutterxel.dart' as flutterxel;
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
  });

  test(
    'exposes init/run/flip/quit/camera/clip/pal/btn/btnp/btnr/btnv/cls/pset/pget/line/rect/rectb/circ/circb/elli/ellib/tri/trib/fill/text/bltm/blt/play/playm/stop/playPos/load/save API surface',
    () {
      expect(flutterxel.init, isA<Function>());
      expect(flutterxel.run, isA<Function>());
      expect(flutterxel.flip, isA<Function>());
      expect(flutterxel.quit, isA<Function>());
      expect(flutterxel.camera, isA<Function>());
      expect(flutterxel.clip, isA<Function>());
      expect(flutterxel.pal, isA<Function>());
      expect(flutterxel.btn, isA<Function>());
      expect(flutterxel.btnp, isA<Function>());
      expect(flutterxel.btnr, isA<Function>());
      expect(flutterxel.btnv, isA<Function>());
      expect(flutterxel.cls, isA<Function>());
      expect(flutterxel.pset, isA<Function>());
      expect(flutterxel.pget, isA<Function>());
      expect(flutterxel.line, isA<Function>());
      expect(flutterxel.rect, isA<Function>());
      expect(flutterxel.rectb, isA<Function>());
      expect(flutterxel.circ, isA<Function>());
      expect(flutterxel.circb, isA<Function>());
      expect(flutterxel.elli, isA<Function>());
      expect(flutterxel.ellib, isA<Function>());
      expect(flutterxel.tri, isA<Function>());
      expect(flutterxel.trib, isA<Function>());
      expect(flutterxel.fill, isA<Function>());
      expect(flutterxel.text, isA<Function>());
      expect(flutterxel.bltm, isA<Function>());
      expect(flutterxel.blt, isA<Function>());
      expect(flutterxel.play, isA<Function>());
      expect(flutterxel.playm, isA<Function>());
      expect(flutterxel.stop, isA<Function>());
      expect(flutterxel.playPos, isA<Function>());
      expect(flutterxel.load, isA<Function>());
      expect(flutterxel.save, isA<Function>());
    },
  );

  test(
    'accepts Pyxel-compatible named options for init/load/save/play/playm/blt',
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
      flutterxel.playm(0, loop: true);
      expect(flutterxel.isChannelPlaying(0), isTrue);
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

  test('flip advances frame and clears transient wheel values', () {
    flutterxel.init(8, 8);

    expect(flutterxel.frameCount, 0);
    flutterxel.setBtnValue(flutterxel.MOUSE_WHEEL_X, 7);
    expect(flutterxel.btnv(flutterxel.MOUSE_WHEEL_X), 7);

    flutterxel.flip();
    expect(flutterxel.frameCount, 1);
    expect(flutterxel.btnv(flutterxel.MOUSE_WHEEL_X), 0);
  });

  test('drawing primitives update pixel values', () {
    flutterxel.init(8, 8);
    flutterxel.cls(0);

    flutterxel.pset(1, 1, 3);
    expect(flutterxel.pget(1, 1), 3);

    flutterxel.line(0, 0, 3, 0, 4);
    expect(flutterxel.pget(0, 0), 4);
    expect(flutterxel.pget(3, 0), 4);

    flutterxel.rect(2, 2, 2, 2, 5);
    expect(flutterxel.pget(2, 2), 5);
    expect(flutterxel.pget(3, 3), 5);

    flutterxel.rectb(0, 4, 3, 3, 6);
    expect(flutterxel.pget(0, 4), 6);
    expect(flutterxel.pget(2, 6), 6);
    expect(flutterxel.pget(1, 5), 0);
  });

  test('circle primitives draw filled and border circles', () {
    flutterxel.init(10, 10);
    flutterxel.cls(0);

    flutterxel.circ(4, 4, 2, 7);
    expect(flutterxel.pget(4, 4), 7);
    expect(flutterxel.pget(4, 2), 7);
    expect(flutterxel.pget(6, 4), 7);
    expect(flutterxel.pget(4, 6), 7);
    expect(flutterxel.pget(2, 4), 7);

    flutterxel.cls(0);
    flutterxel.circb(4, 4, 2, 8);
    expect(flutterxel.pget(4, 2), 8);
    expect(flutterxel.pget(6, 4), 8);
    expect(flutterxel.pget(4, 6), 8);
    expect(flutterxel.pget(2, 4), 8);
    expect(flutterxel.pget(4, 4), 0);
  });

  test('ellipse primitives draw filled and border ellipses', () {
    flutterxel.init(12, 12);
    flutterxel.cls(0);

    flutterxel.elli(2, 2, 5, 5, 9);
    expect(flutterxel.pget(4, 4), 9);
    expect(flutterxel.pget(4, 2), 9);

    flutterxel.cls(0);
    flutterxel.ellib(2, 2, 5, 5, 10);
    expect(flutterxel.pget(4, 2), 10);
    expect(flutterxel.pget(4, 4), 0);
  });

  test('triangle primitives draw filled and border triangles', () {
    flutterxel.init(10, 10);
    flutterxel.cls(0);

    flutterxel.tri(1, 1, 5, 1, 3, 4, 9);
    expect(flutterxel.pget(3, 2), 9);

    flutterxel.cls(0);
    flutterxel.trib(1, 1, 5, 1, 3, 4, 10);
    expect(flutterxel.pget(1, 1), 10);
    expect(flutterxel.pget(3, 1), 10);
    expect(flutterxel.pget(3, 2), 0);
  });

  test('camera clip and pal affect drawing primitives', () {
    flutterxel.init(8, 8);
    flutterxel.cls(0);

    flutterxel.camera(2, 1);
    flutterxel.pset(2, 1, 3);
    expect(flutterxel.pget(0, 0), 3);
    flutterxel.camera();

    flutterxel.clip(1, 1, 2, 2);
    flutterxel.pset(0, 0, 4);
    expect(flutterxel.pget(0, 0), 3);
    flutterxel.pset(1, 1, 5);
    expect(flutterxel.pget(1, 1), 5);
    flutterxel.clip();

    flutterxel.pal(2, 7);
    flutterxel.pset(2, 2, 2);
    expect(flutterxel.pget(2, 2), 7);
    flutterxel.pal();
    flutterxel.pset(3, 2, 2);
    expect(flutterxel.pget(3, 2), 2);
  });

  test('text draws glyph pixels and skips spaces', () {
    flutterxel.init(20, 10);
    flutterxel.cls(0);

    flutterxel.text(1, 1, 'A', 11);
    expect(flutterxel.pget(1, 1), 11);

    flutterxel.text(6, 1, ' ', 12);
    expect(flutterxel.pget(6, 1), 0);
  });

  test('bltm draws tilemap region using default tile resources', () {
    flutterxel.init(16, 16);
    flutterxel.cls(0);

    flutterxel.bltm(0, 0, 0, 0, 0, 1, 1);
    expect(flutterxel.pget(1, 0), 1);
  });

  test('fill flood-fills enclosed area without crossing borders', () {
    flutterxel.init(8, 8);
    flutterxel.cls(0);

    flutterxel.rectb(1, 1, 6, 6, 3);
    flutterxel.fill(2, 2, 5);
    expect(flutterxel.pget(2, 2), 5);
    expect(flutterxel.pget(1, 1), 3);
    expect(flutterxel.pget(0, 0), 0);
  });

  test('quit stops loop and resets initialized runtime state', () {
    flutterxel.init(8, 8, fps: 60);
    flutterxel.run(() {}, () {});
    expect(flutterxel.isRunning, isTrue);

    flutterxel.quit();
    expect(flutterxel.isRunning, isFalse);
    expect(flutterxel.btn(32), isFalse);
    expect(() => flutterxel.cls(0), throwsStateError);
    expect(() => flutterxel.quit(), returnsNormally);
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

  test('playPos returns null when idle and sound index when playing', () {
    flutterxel.init(8, 8);

    expect(flutterxel.playPos(0), isNull);
    flutterxel.play(0, 7);

    final pos = flutterxel.playPos(0);
    expect(pos, isNotNull);
    expect(pos!.snd, 7);
    expect(pos.pos, 0.0);

    flutterxel.stop(0);
    expect(flutterxel.playPos(0), isNull);
  });
}
