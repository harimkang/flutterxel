import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:flutterxel/flutterxel.dart' as flutterxel;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

String _writeTestPcm16Wav(
  Directory dir, {
  required String name,
  required int sampleRate,
  required int channels,
  required int frames,
}) {
  final file = File('${dir.path}/$name');
  final bytesPerSample = 2;
  final blockAlign = channels * bytesPerSample;
  final byteRate = sampleRate * blockAlign;
  final dataSize = frames * blockAlign;
  final riffSize = 36 + dataSize;
  final bytes = <int>[
    // RIFF header
    0x52,
    0x49,
    0x46,
    0x46,
    riffSize & 0xFF,
    (riffSize >> 8) & 0xFF,
    (riffSize >> 16) & 0xFF,
    (riffSize >> 24) & 0xFF,
    0x57,
    0x41,
    0x56,
    0x45,
    // fmt chunk
    0x66,
    0x6D,
    0x74,
    0x20,
    16,
    0,
    0,
    0,
    1,
    0,
    channels & 0xFF,
    (channels >> 8) & 0xFF,
    sampleRate & 0xFF,
    (sampleRate >> 8) & 0xFF,
    (sampleRate >> 16) & 0xFF,
    (sampleRate >> 24) & 0xFF,
    byteRate & 0xFF,
    (byteRate >> 8) & 0xFF,
    (byteRate >> 16) & 0xFF,
    (byteRate >> 24) & 0xFF,
    blockAlign & 0xFF,
    (blockAlign >> 8) & 0xFF,
    16,
    0,
    // data chunk
    0x64,
    0x61,
    0x74,
    0x61,
    dataSize & 0xFF,
    (dataSize >> 8) & 0xFF,
    (dataSize >> 16) & 0xFF,
    (dataSize >> 24) & 0xFF,
  ];
  bytes.addAll(List<int>.filled(dataSize, 0, growable: false));
  file.writeAsBytesSync(bytes, flush: true);
  return file.path;
}

String _writeTestPng(
  Directory dir, {
  required String name,
  required int width,
  required int height,
  required List<int> rgb24Pixels,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rgb = rgb24Pixels[y * width + x];
      final r = (rgb >> 16) & 0xFF;
      final g = (rgb >> 8) & 0xFF;
      final b = rgb & 0xFF;
      image.setPixelRgb(x, y, r, g, b);
    }
  }

  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodePng(image), flush: true);
  return file.path;
}

String _writeTestRgbaPng(
  Directory dir, {
  required String name,
  required int width,
  required int height,
  required List<int> rgba32Pixels,
}) {
  final image = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final rgba = rgba32Pixels[y * width + x];
      final r = (rgba >> 24) & 0xFF;
      final g = (rgba >> 16) & 0xFF;
      final b = (rgba >> 8) & 0xFF;
      final a = rgba & 0xFF;
      image.setPixelRgba(x, y, r, g, b, a);
    }
  }

  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodePng(image), flush: true);
  return file.path;
}

bool _hasCommand(String command) {
  final result = Platform.isWindows
      ? Process.runSync('where', <String>[command], runInShell: true)
      : Process.runSync('sh', <String>['-lc', 'command -v $command']);
  return result.exitCode == 0;
}

String? _readPyxresManifest(String path) {
  if (!_hasCommand('unzip')) {
    return null;
  }
  final result = Process.runSync('unzip', <String>[
    '-p',
    path,
    'pyxel_resource.toml',
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  return (result.stdout as String).trim();
}

void main() {
  tearDown(() {
    flutterxel.stopRunLoop();
  });

  bool nativeBindingsAvailable() {
    final major = flutterxel.Flutterxel.versionMajor();
    final minor = flutterxel.Flutterxel.versionMinor();
    final patch = flutterxel.Flutterxel.versionPatch();
    return major != 0 || minor != 0 || patch != 0;
  }

  test('backend mode resolves to supported discriminator', () {
    final mode = flutterxel.Flutterxel.backendMode;
    expect(
      mode,
      anyOf(
        flutterxel.BackendMode.native_core,
        flutterxel.BackendMode.c_fallback,
        flutterxel.BackendMode.dart_fallback,
      ),
    );
  });

  test('backend mode capability getters are deterministic in one process', () {
    final mode1 = flutterxel.Flutterxel.backendMode;
    final mode2 = flutterxel.Flutterxel.backendMode;
    expect(mode2, mode1);

    final capability1 = flutterxel.Flutterxel.supportsNativeBltSourceSelection;
    final capability2 = flutterxel.Flutterxel.supportsNativeBltSourceSelection;
    expect(capability2, capability1);
    expect(capability1, mode1 == flutterxel.BackendMode.native_core);
  });

  test('backend mode throws explicit error when backend symbol is missing', () {
    expect(
      () => flutterxel.Flutterxel.resolveBackendModeFromLookup(
        <T extends ffi.NativeType>(String symbolName) {
          throw ArgumentError('missing symbol: $symbolName');
        },
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('flutterxel_core_backend_kind'),
        ),
      ),
    );
  });

  test('forced c fallback mode enforces c fallback backend path', () {
    if (Platform.environment['FLUTTERXEL_FORCE_BACKEND'] != 'c_fallback') {
      return;
    }

    final overridePath = Platform.environment['FLUTTERXEL_LIBRARY_OVERRIDE'];
    expect(
      overridePath != null && overridePath.isNotEmpty,
      isTrue,
      reason:
          'Set FLUTTERXEL_LIBRARY_OVERRIDE to a host-built flutterxel.c shared library path.',
    );

    expect(
      flutterxel.Flutterxel.backendMode,
      flutterxel.BackendMode.c_fallback,
      reason:
          'FLUTTERXEL_FORCE_BACKEND=c_fallback requested but backend mode did not switch.',
    );

    flutterxel.init(4, 4);
    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].pset(0, 0, 11);
    flutterxel.blt(0, 0, 0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), 11);
  });

  test('c fallback blt image bank respects img source bank id', () {
    if (Platform.environment['FLUTTERXEL_FORCE_BACKEND'] != 'c_fallback') {
      return;
    }

    expect(
      flutterxel.Flutterxel.backendMode,
      flutterxel.BackendMode.c_fallback,
      reason:
          'This regression test must run in forced c_fallback mode. '
          'Use FLUTTERXEL_FORCE_BACKEND=c_fallback with FLUTTERXEL_LIBRARY_OVERRIDE.',
    );

    flutterxel.init(8, 8);
    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[1].cls(0);
    flutterxel.images[0].pset(0, 0, 4);
    flutterxel.images[1].pset(0, 0, 9);

    flutterxel.blt(0, 0, 0, 0, 0, 1, 1);
    flutterxel.blt(1, 0, 1, 0, 0, 1, 1);

    expect(flutterxel.pget(0, 0), 4);
    expect(flutterxel.pget(1, 0), 9);
  });

  test('c fallback bltm tilemap id selects tilemap-dependent source', () {
    if (Platform.environment['FLUTTERXEL_FORCE_BACKEND'] != 'c_fallback') {
      return;
    }

    expect(
      flutterxel.Flutterxel.backendMode,
      flutterxel.BackendMode.c_fallback,
      reason:
          'This regression test must run in forced c_fallback mode. '
          'Use FLUTTERXEL_FORCE_BACKEND=c_fallback with FLUTTERXEL_LIBRARY_OVERRIDE.',
    );

    flutterxel.init(16, 16);
    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[1].cls(0);
    flutterxel.images[0].pset(0, 0, 3);
    flutterxel.images[1].pset(0, 0, 12);

    flutterxel.bltm(0, 0, 0, 0, 0, 1, 1);
    flutterxel.bltm(8, 0, 1, 0, 0, 1, 1);

    expect(flutterxel.pget(0, 0), 3);
    expect(flutterxel.pget(8, 0), 12);
  });

  test(
    'exposes init/run/show/flip/quit/reset/title/icon/perfMonitor/integerScale/screenMode/fullscreen/camera/clip/pal/dither/btn/btnp/btnr/btnv/mouse/warpMouse/mouseX/mouseY/mouseWheel/inputKeys/inputText/droppedFiles/setInputText/setDroppedFiles/cls/pset/pget/line/rect/rectb/circ/circb/elli/ellib/tri/trib/fill/text/bltm/blt/play/playm/stop/playPos/load/save/loadPal/savePal/screenshot/screencast/resetScreencast/userDataDir/rseed/rndi/rndf/nseed/noise/ceil/floor/clamp/sgn/sqrt/sin/cos/atan2 API surface',
    () {
      expect(flutterxel.init, isA<Function>());
      expect(flutterxel.run, isA<Function>());
      expect(flutterxel.show, isA<Function>());
      expect(flutterxel.flip, isA<Function>());
      expect(flutterxel.quit, isA<Function>());
      expect(flutterxel.reset, isA<Function>());
      expect(flutterxel.title, isA<Function>());
      expect(flutterxel.icon, isA<Function>());
      expect(flutterxel.perfMonitor, isA<Function>());
      expect(flutterxel.integerScale, isA<Function>());
      expect(flutterxel.screenMode, isA<Function>());
      expect(flutterxel.fullscreen, isA<Function>());
      expect(flutterxel.camera, isA<Function>());
      expect(flutterxel.clip, isA<Function>());
      expect(flutterxel.pal, isA<Function>());
      expect(flutterxel.dither, isA<Function>());
      expect(flutterxel.btn, isA<Function>());
      expect(flutterxel.btnp, isA<Function>());
      expect(flutterxel.btnr, isA<Function>());
      expect(flutterxel.btnv, isA<Function>());
      expect(flutterxel.mouse, isA<Function>());
      expect(flutterxel.warpMouse, isA<Function>());
      expect(flutterxel.mouseX, isA<int>());
      expect(flutterxel.mouseY, isA<int>());
      expect(flutterxel.mouseWheel, isA<int>());
      expect(flutterxel.inputKeys, isA<List<int>>());
      expect(flutterxel.inputText, isA<String>());
      expect(flutterxel.droppedFiles, isA<List<String>>());
      expect(flutterxel.setInputText, isA<Function>());
      expect(flutterxel.setDroppedFiles, isA<Function>());
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
      expect(flutterxel.loadPal, isA<Function>());
      expect(flutterxel.savePal, isA<Function>());
      expect(flutterxel.screenshot, isA<Function>());
      expect(flutterxel.screencast, isA<Function>());
      expect(flutterxel.resetScreencast, isA<Function>());
      expect(flutterxel.userDataDir, isA<Function>());
      expect(flutterxel.rseed, isA<Function>());
      expect(flutterxel.rndi, isA<Function>());
      expect(flutterxel.rndf, isA<Function>());
      expect(flutterxel.nseed, isA<Function>());
      expect(flutterxel.noise, isA<Function>());
      expect(flutterxel.ceil, isA<Function>());
      expect(flutterxel.floor, isA<Function>());
      expect(flutterxel.clamp, isA<Function>());
      expect(flutterxel.sgn, isA<Function>());
      expect(flutterxel.sqrt, isA<Function>());
      expect(flutterxel.sin, isA<Function>());
      expect(flutterxel.cos, isA<Function>());
      expect(flutterxel.atan2, isA<Function>());
    },
  );

  test('exposes Pyxel-compatible core constants', () {
    expect(flutterxel.VERSION, '2.7.1');
    expect(flutterxel.BASE_DIR, '.pyxel');
    expect(flutterxel.WINDOW_STATE_ENV, 'PYXEL_WINDOW_STATE');
    expect(flutterxel.WATCH_STATE_FILE_ENV, 'PYXEL_WATCH_STATE_FILE');
    expect(flutterxel.WATCH_RESET_EXIT_CODE, 82);
    expect(flutterxel.APP_FILE_EXTENSION, '.pyxapp');
    expect(flutterxel.RESOURCE_FILE_EXTENSION, '.pyxres');
    expect(flutterxel.PALETTE_FILE_EXTENSION, '.pyxpal');
    expect(flutterxel.NUM_COLORS, 16);
    expect(flutterxel.NUM_IMAGES, 3);
    expect(flutterxel.IMAGE_SIZE, 256);
    expect(flutterxel.NUM_TILEMAPS, 8);
    expect(flutterxel.TILEMAP_SIZE, 256);
    expect(flutterxel.TILE_SIZE, 8);
    expect(flutterxel.FONT_WIDTH, 4);
    expect(flutterxel.FONT_HEIGHT, 6);
    expect(flutterxel.NUM_CHANNELS, 4);
    expect(flutterxel.NUM_TONES, 4);
    expect(flutterxel.NUM_SOUNDS, 64);
    expect(flutterxel.NUM_MUSICS, 8);
    expect(flutterxel.DEFAULT_COLORS.length, flutterxel.NUM_COLORS);
    expect(flutterxel.COLOR_BLACK, 0);
    expect(flutterxel.COLOR_PEACH, 15);
    expect(flutterxel.KEY_UNKNOWN, 0x00);
    expect(flutterxel.KEY_BACKSPACE, 0x08);
    expect(flutterxel.KEY_F1, 0x4000003A);
    expect(flutterxel.KEY_MODE, 0x40000101);
    expect(flutterxel.KEY_AUDIOFASTFORWARD, 0x4000011E);
    expect(flutterxel.MOUSE_BUTTON_X1, flutterxel.MOUSE_KEY_START_INDEX + 7);
    expect(flutterxel.MOUSE_BUTTON_X2, flutterxel.MOUSE_KEY_START_INDEX + 8);
    expect(
      flutterxel.MOUSE_BUTTON_UNKNOWN,
      flutterxel.MOUSE_KEY_START_INDEX + 9,
    );
    expect(flutterxel.GAMEPAD1_BUTTON_A, flutterxel.GAMEPAD1_AXIS_LEFTX + 6);
    expect(flutterxel.TONE_TRIANGLE, 0);
    expect(flutterxel.TONE_NOISE, 3);
    expect(flutterxel.EFFECT_NONE, 0);
    expect(flutterxel.EFFECT_QUARTER_FADEOUT, 5);
  });

  test('exposes Pyxel-compatible snake_case aliases', () {
    expect(flutterxel.frame_count, isA<int>());
    expect(flutterxel.perf_monitor, isA<Function>());
    expect(flutterxel.integer_scale, isA<Function>());
    expect(flutterxel.screen_mode, isA<Function>());
    expect(flutterxel.warp_mouse, isA<Function>());
    expect(flutterxel.play_pos, isA<Function>());
    expect(flutterxel.load_pal, isA<Function>());
    expect(flutterxel.save_pal, isA<Function>());
    expect(flutterxel.reset_screencast, isA<Function>());
    expect(flutterxel.user_data_dir, isA<Function>());
    expect(flutterxel.mouse_x, isA<int>());
    expect(flutterxel.mouse_y, isA<int>());
    expect(flutterxel.mouse_wheel, isA<int>());
    expect(flutterxel.input_keys, isA<List<int>>());
    expect(flutterxel.input_text, isA<String>());
    expect(flutterxel.dropped_files, isA<List<String>>());
  });

  test('init accepts num_colors=64/256 and rejects unsupported values', () {
    expect(() => flutterxel.init(16, 16, num_colors: 64), returnsNormally);
    expect(flutterxel.numColors, 64);
    expect(flutterxel.num_colors, 64);
    flutterxel.quit();
    expect(() => flutterxel.init(16, 16, numColors: 256), returnsNormally);
    expect(flutterxel.numColors, 256);
    flutterxel.quit();
    expect(() => flutterxel.init(16, 16, num_colors: 32), throwsArgumentError);
  });

  test('pal supports 63/255 indices when runtime num_colors is expanded', () {
    flutterxel.init(16, 16, num_colors: 64);
    flutterxel.cls(0);
    flutterxel.pal(63, 5);
    flutterxel.pset(0, 0, 63);
    expect(flutterxel.pget(0, 0), 5);
    flutterxel.quit();

    flutterxel.init(16, 16, num_colors: 256);
    flutterxel.cls(0);
    flutterxel.pal(255, 12);
    flutterxel.pset(0, 0, 255);
    expect(flutterxel.pget(0, 0), 12);
    flutterxel.quit();
  });

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

      Object? loadError;
      try {
        flutterxel.load(
          'assets/sample.pyxres',
          excludeImages: true,
          excludeTilemaps: false,
          excludeSounds: null,
          excludeMusics: null,
        );
      } catch (error) {
        loadError = error;
      }
      if (loadError != null) {
        expect(loadError, anyOf(isA<UnsupportedError>(), isA<StateError>()));
      }

      Object? saveError;
      try {
        flutterxel.save(
          'assets/out.pyxres',
          excludeImages: null,
          excludeTilemaps: true,
          excludeSounds: false,
          excludeMusics: null,
        );
      } catch (error) {
        saveError = error;
      }
      if (saveError != null) {
        expect(saveError, anyOf(isA<UnsupportedError>(), isA<StateError>()));
      }

      flutterxel.play(0, 1, sec: 0.5, loop: true, resume: false);
      flutterxel.play(0, <int>[1, 2, 3], sec: null, loop: null, resume: null);
      flutterxel.play(0, 'c3e3g3c4r', sec: 1.5, loop: false, resume: true);
      flutterxel.play(0, flutterxel.sounds[0], sec: 0.1);
      flutterxel.play(0, <flutterxel.Sound>[flutterxel.sounds[0]], loop: true);
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

  test('channels exposes Channel-style audio control API', () {
    flutterxel.init(8, 8);

    expect(flutterxel.channels.length, flutterxel.NUM_CHANNELS);
    expect(flutterxel.channels.first, isA<flutterxel.Channel>());

    final channel0 = flutterxel.channels.first;
    channel0.play(1);
    channel0.play(flutterxel.sounds[0], sec: 0.2);
    channel0.play(<flutterxel.Sound>[flutterxel.sounds[0]], loop: true);
    expect(channel0.play_pos(), isNotNull);
    channel0.stop();
    expect(channel0.play_pos(), isNull);
  });

  test('graphics resources expose Image/Tilemap-style API', () {
    flutterxel.init(8, 8);

    expect(flutterxel.colors.length, flutterxel.NUM_COLORS);
    expect(flutterxel.images.length, flutterxel.NUM_IMAGES);
    expect(flutterxel.tilemaps.length, flutterxel.NUM_TILEMAPS);
    expect(flutterxel.screen, isA<flutterxel.Image>());
    expect(flutterxel.cursor, isA<flutterxel.Image>());
    expect(flutterxel.font, isA<flutterxel.Image>());

    final image0 = flutterxel.images.first;
    expect(image0.width, flutterxel.IMAGE_SIZE);
    expect(image0.height, flutterxel.IMAGE_SIZE);

    image0.cls(1);
    image0.pset(0, 0, 2);
    expect(image0.pget(0, 0), 2);

    final tilemap0 = flutterxel.tilemaps.first;
    tilemap0.cls((0, 0));
    tilemap0.pset(0, 0, (1, 2));
    expect(tilemap0.pget(0, 0), (1, 2));

    flutterxel.screen.cls(0);
    flutterxel.screen.pset(1, 1, 3);
    expect(flutterxel.pget(1, 1), 3);
    flutterxel.blt(0, 0, image0, 0, 0, 1, 1);
    flutterxel.bltm(0, 0, tilemap0, 0, 0, 1, 1);
  });

  test('resource image pset is reflected by native blt source', () {
    flutterxel.init(8, 8);
    if (!nativeBindingsAvailable()) {
      return;
    }

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].pset(0, 0, 9);

    flutterxel.blt(0, 0, 0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), 9);
  });

  test('resource image load is reflected by native blt source', () {
    flutterxel.init(8, 8);
    if (!nativeBindingsAvailable()) {
      return;
    }

    final tempDir = Directory.systemTemp.createTempSync(
      'flutterxel_native_img_',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final pngPath = _writeTestPng(
      tempDir,
      name: 'single.png',
      width: 1,
      height: 1,
      rgb24Pixels: const <int>[0x2B335F], // COLOR_NAVY
    );

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].load(0, 0, pngPath);

    flutterxel.blt(0, 0, 0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), flutterxel.COLOR_NAVY);
  });

  test('resource image set is reflected by native blt source', () {
    flutterxel.init(8, 8);
    if (!nativeBindingsAvailable()) {
      return;
    }

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].set(0, 0, const <String>['a']);

    flutterxel.blt(0, 0, 0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), 10);
  });

  test('resource tilemap pset is reflected by native bltm source', () {
    flutterxel.init(16, 16);
    if (!nativeBindingsAvailable()) {
      return;
    }

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].pset(0, 0, 2);
    flutterxel.images[0].pset(8, 8, 11);

    final tm0 = flutterxel.tilemaps[0];
    tm0.cls((0, 0));
    tm0.pset(0, 0, (1, 1));

    flutterxel.bltm(0, 0, tm0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), 11);
  });

  test('resource tilemap non-zero pset is reflected by native bltm source', () {
    flutterxel.init(24, 24);
    if (!nativeBindingsAvailable()) {
      return;
    }

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].pset(16, 24, 13);

    final tm0 = flutterxel.tilemaps[0];
    tm0.cls((0, 0));
    tm0.pset(5, 4, (2, 3));

    flutterxel.bltm(0, 0, tm0, 5, 4, 1, 1);
    expect(flutterxel.pget(0, 0), 13);
  });

  test('resource tilemap cls is reflected by native bltm source', () {
    flutterxel.init(16, 16);
    if (!nativeBindingsAvailable()) {
      return;
    }

    flutterxel.cls(0);
    flutterxel.images[0].cls(0);
    flutterxel.images[0].pset(0, 0, 3);
    flutterxel.images[0].pset(8, 8, 12);

    final tm0 = flutterxel.tilemaps[0];
    tm0.cls((1, 1));

    flutterxel.bltm(0, 0, tm0, 0, 0, 1, 1);
    expect(flutterxel.pget(0, 0), 12);
  });

  test('resource tilemap imgsrc setter keeps value on invalid input', () {
    flutterxel.init(16, 16);
    final tm0 = flutterxel.tilemaps[0];
    tm0.imgsrc = 3;

    expect(() => tm0.imgsrc = 'invalid', throwsA(isA<ArgumentError>()));
    expect(tm0.imgsrc, 3);
  });

  test('audio resources expose Tone/Sound/Music-style API', () {
    flutterxel.init(8, 8);

    expect(flutterxel.tones.length, flutterxel.NUM_TONES);
    expect(flutterxel.sounds.length, flutterxel.NUM_SOUNDS);
    expect(flutterxel.musics.length, flutterxel.NUM_MUSICS);
    expect(flutterxel.tones.first, isA<flutterxel.Tone>());
    expect(flutterxel.sounds.first, isA<flutterxel.Sound>());
    expect(flutterxel.musics.first, isA<flutterxel.Music>());

    final sound0 = flutterxel.sounds.first;
    sound0.set_notes('c3e3g3');
    sound0.set_tones('tspn');
    sound0.set_volumes('7654');
    sound0.set_effects('nsvf');
    expect(sound0.notes.isNotEmpty, isTrue);
    expect(sound0.total_sec(), isA<double>());

    final music0 = flutterxel.musics.first;
    music0.set(<int>[0, 1], <int>[2, 3]);
    expect(music0.seqs.first, isA<flutterxel.Seq<int>>());

    final generated = flutterxel.gen_bgm(0, 0, seed: 7, play: true);
    expect(generated.length, flutterxel.NUM_CHANNELS);
    expect(flutterxel.isChannelPlaying(0), isTrue);
  });

  test(
    'Seq mutation APIs support addAll/clear on Sound and Music resources',
    () {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutterxel-seq-sync-',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      if (!_hasCommand('unzip')) {
        return;
      }

      flutterxel.init(8, 8);

      final sound = flutterxel.sounds[3];
      sound.notes
        ..clear()
        ..addAll(<int>[12, 24, -1]);
      sound.tones
        ..clear()
        ..addAll(<int>[0, 1, 2]);
      sound.volumes
        ..clear()
        ..addAll(<int>[7, 6, 5]);
      sound.effects
        ..clear()
        ..addAll(<int>[0, 2, 3]);

      final music = flutterxel.musics[2];
      music.seqs[0]
        ..clear()
        ..addAll(<int>[3, 4, 5]);
      music.seqs[2]
        ..clear()
        ..addAll(<int>[6]);

      expect(sound.notes.toList(), <int>[12, 24, -1]);
      expect(sound.tones.toList(), <int>[0, 1, 2]);
      expect(sound.volumes.toList(), <int>[7, 6, 5]);
      expect(sound.effects.toList(), <int>[0, 2, 3]);
      expect(music.seqs[0].toList(), <int>[3, 4, 5]);
      expect(music.seqs[2].toList(), <int>[6]);

      flutterxel.play(0, sound, sec: 0.1);
      expect(flutterxel.playPos(0), isNotNull);
      expect(flutterxel.playPos(0)!.snd, 3);
      flutterxel.stop(0);

      final resourcePath = '${tempDir.path}/seq_sync.pyxres';
      try {
        flutterxel.save(resourcePath);
      } on UnsupportedError {
        return;
      }
      final manifest = _readPyxresManifest(resourcePath);
      if (manifest != null) {
        expect(manifest, contains(RegExp(r'notes\s*=\s*\[12,\s*24,\s*-1\]')));
        expect(manifest, contains(RegExp(r'tones\s*=\s*\[0,\s*1,\s*2\]')));
        expect(manifest, contains(RegExp(r'volumes\s*=\s*\[7,\s*6,\s*5\]')));
        expect(manifest, contains(RegExp(r'effects\s*=\s*\[0,\s*2,\s*3\]')));
        expect(
          manifest,
          contains(RegExp(r'seqs\s*=\s*\[\[3,\s*4,\s*5\],\s*\[\],\s*\[6\]')),
        );
      }
    },
  );

  test('sound parsing helpers and mml mode update runtime sound state', () {
    flutterxel.init(8, 8);
    final sound = flutterxel.Sound();

    sound.set('c3 d#3 e-3 r', 'tspn', '7654', 'nsvf', 24);
    expect(sound.notes.toList(), <int>[36, 39, 39, -1]);
    expect(sound.tones.toList(), <int>[0, 1, 2, 3]);
    expect(sound.volumes.toList(), <int>[7, 6, 5, 4]);
    expect(sound.effects.toList(), <int>[0, 1, 2, 3]);
    expect(sound.speed, 24);

    sound.note('g2 b-2 d3 r');
    expect(sound.notes.toList(), <int>[31, 34, 38, -1]);

    sound.tone('TSPN0123');
    expect(sound.tones.toList(), <int>[0, 1, 2, 3, 0, 1, 2, 3]);

    sound.volume('7 5 3 1');
    expect(sound.volumes.toList(), <int>[7, 5, 3, 1]);

    sound.effect('N S V F H Q');
    expect(sound.effects.toList(), <int>[0, 1, 2, 3, 4, 5]);

    sound.set_notes('c3c3');
    sound.speed = 2;
    expect(sound.total_sec(), closeTo(2 * 2 / 120, 1e-9));
    sound.mml('T120 CDE');
    expect(sound.total_sec(), closeTo(1.49996, 1e-4));
    sound.mml('[C]2');
    expect(sound.total_sec(), closeTo(0.99997, 1e-4));
    sound.mml('[C]');
    expect(sound.total_sec(), isNull);
    sound.mml();
    expect(sound.total_sec(), closeTo(2 * 2 / 120, 1e-9));

    expect(() => sound.set_notes('c'), throwsFormatException);
    expect(() => sound.set_tones('x'), throwsFormatException);
    expect(() => sound.set_volumes('9'), throwsFormatException);
    expect(() => sound.set_effects('z'), throwsFormatException);
    expect(() => sound.mml('T0 C'), throwsFormatException);
  });

  test('sound pcm mode and save/music save wav output behavior', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync('flutterxel-audio-');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final sound = flutterxel.Sound();
    sound.set_notes('c3c3');
    sound.speed = 30;
    expect(sound.total_sec(), closeTo(2 * 30 / 120, 1e-9));

    final pcmPath = _writeTestPcm16Wav(
      tempDir,
      name: 'input.wav',
      sampleRate: 22050,
      channels: 1,
      frames: 2205,
    );
    sound.pcm(pcmPath);
    expect(sound.total_sec(), closeTo(0.1, 1e-6));
    sound.pcm();
    expect(sound.total_sec(), closeTo(2 * 30 / 120, 1e-9));
    expect(
      () => sound.pcm('${tempDir.path}/missing.wav'),
      throwsA(isA<FileSystemException>()),
    );

    final soundOut = File('${tempDir.path}/sound_out.wav');
    expect(() => sound.save(soundOut.path, 0), throwsArgumentError);
    sound.save(soundOut.path, 0.05);
    expect(soundOut.existsSync(), isTrue);
    final soundBytes = soundOut.readAsBytesSync();
    expect(soundBytes.length, greaterThanOrEqualTo(44));
    expect(String.fromCharCodes(soundBytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(soundBytes.sublist(8, 12)), 'WAVE');

    final music = flutterxel.Music();
    final musicOut = File('${tempDir.path}/music_out.wav');
    expect(() => music.save(musicOut.path, -1), throwsArgumentError);
    music.save(musicOut.path, 0.05);
    expect(musicOut.existsSync(), isTrue);
    final musicBytes = musicOut.readAsBytesSync();
    expect(musicBytes.length, greaterThanOrEqualTo(44));
    expect(String.fromCharCodes(musicBytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(musicBytes.sublist(8, 12)), 'WAVE');
  });

  test(
    'sound save with ffmpeg true produces mp4 or throws when unavailable',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel-ffmpeg-');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final sound = flutterxel.Sound();
      sound.set_notes('c3');
      sound.speed = 30;
      final wavBase = '${tempDir.path}/sound_capture.wav';
      final mp4Path = '${tempDir.path}/sound_capture.mp4';

      if (_hasCommand('ffmpeg')) {
        sound.save(wavBase, 0.05, ffmpeg: true);
        expect(File(wavBase).existsSync(), isTrue);
        expect(File(mp4Path).existsSync(), isTrue);
      } else {
        expect(
          () => sound.save(wavBase, 0.05, ffmpeg: true),
          throwsA(isA<UnsupportedError>()),
        );
      }
    },
  );

  test(
    'sound pcm can read compressed audio duration when ffmpeg is available',
    () {
      if (!_hasCommand('ffmpeg')) {
        return;
      }

      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync(
        'flutterxel-compressed-',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final wavPath = _writeTestPcm16Wav(
        tempDir,
        name: 'source.wav',
        sampleRate: 22050,
        channels: 1,
        frames: 2205,
      );
      final mp3Path = '${tempDir.path}/source.mp3';
      final encode = Process.runSync('ffmpeg', <String>[
        '-y',
        '-v',
        'error',
        '-i',
        wavPath,
        mp3Path,
      ]);
      if (encode.exitCode != 0 || !File(mp3Path).existsSync()) {
        return;
      }

      final sound = flutterxel.Sound();
      sound.pcm(mp3Path);
      expect(sound.total_sec(), closeTo(0.1, 0.02));
    },
  );

  test('old mml tokens x/X/~ are accepted for duration parsing', () {
    flutterxel.init(8, 8);
    final sound = flutterxel.Sound();

    sound.mml('T120 X2 C~C');
    expect(sound.total_sec(), closeTo(0.99997, 1e-4));

    sound.mml('t120 x1 c~r', true);
    expect(sound.total_sec(), closeTo(0.99997, 1e-4));
  });

  test('tilemap primitives, blt and collide update tile data', () {
    flutterxel.init(8, 8);

    final tm0 = flutterxel.tilemaps[0];
    final tm1 = flutterxel.tilemaps[1];

    tm0.cls((0, 0));
    tm0.line(0, 0, 3, 0, (1, 1));
    expect(tm0.pget(0, 0), (1, 1));
    expect(tm0.pget(3, 0), (1, 1));

    tm0.rect(1, 1, 2, 2, (2, 2));
    expect(tm0.pget(1, 1), (2, 2));
    expect(tm0.pget(2, 2), (2, 2));

    tm0.rectb(0, 3, 3, 3, (3, 3));
    expect(tm0.pget(0, 3), (3, 3));
    expect(tm0.pget(2, 5), (3, 3));
    expect(tm0.pget(1, 4), (0, 0));

    tm0.cls((0, 0));
    tm0.rectb(0, 0, 4, 4, (9, 9));
    tm0.fill(1, 1, (4, 4));
    expect(tm0.pget(1, 1), (4, 4));
    expect(tm0.pget(0, 0), (9, 9));

    tm1.cls((0, 0));
    tm1.pset(0, 0, (7, 7));
    tm0.blt(0, 0, tm1, 0, 0, 1, 1);
    expect(tm0.pget(0, 0), (7, 7));

    tm0.cls((0, 0));
    tm0.pset(2, 2, (5, 5));
    expect(tm0.collide(0, 0, 8, 8, 16, 16, <(int, int)>[(5, 5)]), (16.0, 8.0));
    tm0.pset(1, 0, (6, 6));
    expect(tm0.collide(0, 0, 8, 8, 8, 0, <(int, int)>[(6, 6)]), (0.0, 0.0));
  });

  test('tilemap clip and camera affect tile writes and reads', () {
    flutterxel.init(8, 8);
    final tm = flutterxel.tilemaps[0];

    tm.cls((0, 0));
    tm.camera(1, 0);
    tm.pset(1, 0, (1, 1));
    tm.camera();
    expect(tm.pget(0, 0), (1, 1));

    tm.clip(1, 1, 1, 1);
    tm.pset(0, 0, (2, 2));
    tm.pset(1, 1, (3, 3));
    expect(tm.pget(1, 1), (3, 3));
    expect(tm.pget(0, 0), (0, 0));

    tm.line(0, 0, 2, 2, (4, 4));
    expect(tm.pget(1, 1), (4, 4));
    expect(tm.pget(2, 2), (0, 0));

    tm.clip();
    expect(tm.pget(0, 0), (1, 1));
  });

  test('tilemap set parses pyxel-style 4-hex tile rows', () {
    flutterxel.init(8, 8);
    final tm = flutterxel.tilemaps[0];

    tm.cls((0, 0));
    tm.set(0, 0, ['0102 0A0B']);
    expect(tm.pget(0, 0), (1, 2));
    expect(tm.pget(1, 0), (10, 11));

    tm.set(1, 1, [' 0C0D ', '\t0E0F']);
    expect(tm.pget(1, 1), (12, 13));
    expect(tm.pget(1, 2), (14, 15));
  });

  test('tilemap from_tmx and load parse csv layers', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync('flutterxel_tmx_');
    final tmxPath = '${tempDir.path}${Platform.pathSeparator}map.tmx';
    try {
      File(tmxPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="2" height="2" tilewidth="8" tileheight="8">
 <tileset firstgid="1" name="test" tilewidth="8" tileheight="8" tilecount="16" columns="4">
  <image source="test.png" width="32" height="32"/>
 </tileset>
 <layer id="1" name="L1" width="2" height="2">
  <data encoding="csv">
1,2,
5,0
  </data>
 </layer>
 <layer id="2" name="L2" width="2" height="2">
  <data encoding="csv">
3,4,
5,6
  </data>
 </layer>
</map>
''');

      final loaded = flutterxel.Tilemap.from_tmx(tmxPath, 1);
      expect(loaded.width, 2);
      expect(loaded.height, 2);
      expect(loaded.pget(0, 0), (2, 0));
      expect(loaded.pget(1, 0), (3, 0));
      expect(loaded.pget(0, 1), (0, 1));
      expect(loaded.pget(1, 1), (1, 1));

      final tm = flutterxel.tilemaps[0];
      tm.cls((0, 0));
      tm.load(0, 0, tmxPath, 0);
      expect(tm.pget(0, 0), (0, 0));
      expect(tm.pget(1, 0), (1, 0));
      expect(tm.pget(0, 1), (0, 1));
      expect(tm.pget(1, 1), (0, 0));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('tilemap from_tmx normalizes 16x16 TMX tiles into 8x8 tiles', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync('flutterxel_tmx_16_');
    final tmxPath = '${tempDir.path}${Platform.pathSeparator}map16.tmx';
    try {
      File(tmxPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="1" height="1" tilewidth="16" tileheight="16">
 <tileset firstgid="1" name="test16" tilewidth="16" tileheight="16" tilecount="2" columns="2">
  <image source="test16.png" width="32" height="16"/>
 </tileset>
 <layer id="1" name="L1" width="1" height="1">
  <data encoding="csv">
2
  </data>
 </layer>
</map>
''');

      final loaded = flutterxel.Tilemap.from_tmx(tmxPath, 0);
      expect(loaded.width, 2);
      expect(loaded.height, 2);
      expect(loaded.pget(0, 0), (2, 0));
      expect(loaded.pget(1, 0), (3, 0));
      expect(loaded.pget(0, 1), (2, 1));
      expect(loaded.pget(1, 1), (3, 1));
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test('tilemap from_tmx rejects TMX tile sizes not divisible by 8', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync('flutterxel_tmx_bad_');
    final tmxPath = '${tempDir.path}${Platform.pathSeparator}map_bad.tmx';
    try {
      File(tmxPath).writeAsStringSync('''
<?xml version="1.0" encoding="UTF-8"?>
<map version="1.10" tiledversion="1.10.2" orientation="orthogonal" renderorder="right-down" width="1" height="1" tilewidth="12" tileheight="12">
 <tileset firstgid="1" name="test" tilewidth="12" tileheight="12" tilecount="1" columns="1">
  <image source="test.png" width="12" height="12"/>
 </tileset>
 <layer id="1" name="L1" width="1" height="1">
  <data encoding="csv">
1
  </data>
 </layer>
</map>
''');

      expect(
        () => flutterxel.Tilemap.from_tmx(tmxPath, 0),
        throwsFormatException,
      );
    } finally {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    }
  });

  test(
    'Image.fromImage loads PNG with source dimensions and palette-mapped pixels',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel_png_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestPng(
        tempDir,
        name: 'palette.png',
        width: 2,
        height: 2,
        rgb24Pixels: const <int>[
          0x000000, // COLOR_BLACK
          0x2b335f, // COLOR_NAVY
          0xeeeeee, // COLOR_WHITE
          0xff9798, // COLOR_PINK
        ],
      );

      final loaded = flutterxel.Image.fromImage(pngPath);
      expect(loaded.width, 2);
      expect(loaded.height, 2);
      expect(loaded.pget(0, 0), flutterxel.COLOR_BLACK);
      expect(loaded.pget(1, 0), flutterxel.COLOR_NAVY);
      expect(loaded.pget(0, 1), flutterxel.COLOR_WHITE);
      expect(loaded.pget(1, 1), flutterxel.COLOR_PINK);
    },
  );

  test(
    'Image.load decodes PNG into an existing image at the requested offset',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync(
        'flutterxel_png_load_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestPng(
        tempDir,
        name: 'offset.png',
        width: 1,
        height: 1,
        rgb24Pixels: const <int>[0x010101],
      );

      final target = flutterxel.Image(4, 4);
      target.cls(flutterxel.COLOR_RED);
      target.load(2, 1, pngPath);

      expect(target.pget(0, 0), flutterxel.COLOR_RED);
      expect(target.pget(2, 1), flutterxel.COLOR_BLACK);
    },
  );

  test(
    'Image.load alpha policy keeps legacy mapping when options are unset',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel_alpha_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestRgbaPng(
        tempDir,
        name: 'alpha_legacy.png',
        width: 2,
        height: 1,
        rgba32Pixels: const <int>[
          0xD4186C00, // COLOR_RED with alpha=0
          0x2B335FFF, // COLOR_NAVY opaque
        ],
      );

      final image = flutterxel.Image(2, 1);
      image.cls(flutterxel.COLOR_BLACK);
      image.load(0, 0, pngPath);

      expect(image.pget(0, 0), flutterxel.COLOR_RED);
      expect(image.pget(1, 0), flutterxel.COLOR_NAVY);
    },
  );

  test(
    'Image.load alpha policy maps low-alpha pixels to transparent index when opted in',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel_alpha_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestRgbaPng(
        tempDir,
        name: 'alpha_map.png',
        width: 2,
        height: 1,
        rgba32Pixels: const <int>[
          0xD4186C01, // alpha=1 (threshold-hit)
          0x2B335FFF, // opaque navy
        ],
      );

      final image = flutterxel.Image(2, 1);
      image.load(
        0,
        0,
        pngPath,
        preserve_transparent: true,
        transparent_index: flutterxel.COLOR_BLACK,
        alpha_threshold: 1,
      );

      expect(image.pget(0, 0), flutterxel.COLOR_BLACK);
      expect(image.pget(1, 0), flutterxel.COLOR_NAVY);
    },
  );

  test(
    'Image.load alpha policy works with blt colkey to remove transparent background',
    () {
      flutterxel.init(16, 16);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel_alpha_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestRgbaPng(
        tempDir,
        name: 'alpha_colkey.png',
        width: 2,
        height: 1,
        rgba32Pixels: const <int>[
          0xD4186C00, // fully transparent
          0x2B335FFF, // opaque navy
        ],
      );

      flutterxel.images[0].cls(flutterxel.COLOR_RED);
      flutterxel.images[0].load(
        0,
        0,
        pngPath,
        preserve_transparent: true,
        transparent_index: flutterxel.COLOR_BLACK,
        alpha_threshold: 0,
      );

      flutterxel.cls(flutterxel.COLOR_PINK);
      flutterxel.blt(0, 0, 0, 0, 0, 2, 1, colkey: flutterxel.COLOR_BLACK);

      expect(flutterxel.pget(0, 0), flutterxel.COLOR_PINK);
      expect(flutterxel.pget(1, 0), flutterxel.COLOR_NAVY);
    },
  );

  test(
    'include_colors semantics use discovered-palette order for local index mapping',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync(
        'flutterxel_include_colors_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pngPath = _writeTestPng(
        tempDir,
        name: 'discovered_palette.png',
        width: 3,
        height: 1,
        rgb24Pixels: const <int>[
          0xD4186C, // first discovered -> 0
          0x70C6A9, // second discovered -> 1
          0xD4186C, // repeats first -> 0
        ],
      );

      final includeColorsImage = flutterxel.Image.fromImage(
        pngPath,
        include_colors: true,
      );
      expect(includeColorsImage.pget(0, 0), 0);
      expect(includeColorsImage.pget(1, 0), 1);
      expect(includeColorsImage.pget(2, 0), 0);
    },
  );

  test('include_colors semantics clearer alias matches include_colors', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync(
      'flutterxel_include_colors_',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final pngPath = _writeTestPng(
      tempDir,
      name: 'discovered_alias.png',
      width: 2,
      height: 1,
      rgb24Pixels: const <int>[0x123456, 0xABCDEF],
    );

    final legacy = flutterxel.Image.fromImage(pngPath, include_colors: true);
    final alias = flutterxel.Image.fromImage(
      pngPath,
      use_discovered_palette: true,
    );

    expect(alias.pget(0, 0), legacy.pget(0, 0));
    expect(alias.pget(1, 0), legacy.pget(1, 0));
  });

  test('use_discovered_palette respects runtime num colors limit', () {
    final tempDir = Directory.systemTemp.createTempSync(
      'flutterxel_runtime_palette_limit_',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final pixels = List<int>.generate(
      70,
      (index) =>
          (((index * 3) & 0xFF) << 16) |
          (((index * 5) & 0xFF) << 8) |
          ((index * 7) & 0xFF),
      growable: false,
    );
    final pngPath = _writeTestPng(
      tempDir,
      name: 'runtime_palette_limit.png',
      width: 70,
      height: 1,
      rgb24Pixels: pixels,
    );

    flutterxel.init(80, 8, num_colors: 64);
    final limited = flutterxel.Image.fromImage(
      pngPath,
      use_discovered_palette: true,
    );
    final limitedIndices = List<int>.generate(
      70,
      (index) => limited.pget(index, 0),
      growable: false,
    );
    expect(limitedIndices.every((index) => index >= 0 && index < 64), isTrue);

    flutterxel.quit();
    flutterxel.init(80, 8, num_colors: 256);
    final expanded = flutterxel.Image.fromImage(
      pngPath,
      use_discovered_palette: true,
    );
    expect(expanded.pget(69, 0), 69);
    flutterxel.quit();
  });

  test('image and tilemap data_ptr expose raw byte layout snapshots', () {
    flutterxel.init(8, 8);

    final img = flutterxel.Image(2, 2);
    img.pset(0, 0, 1);
    img.pset(1, 0, 2);
    img.pset(0, 1, 3);
    img.pset(1, 1, 4);
    final imgPtr = img.data_ptr().cast<ffi.Uint8>();
    expect(imgPtr.address, isNonZero);
    expect(imgPtr.asTypedList(4), <int>[1, 2, 3, 4]);

    final tm = flutterxel.Tilemap(2, 2, 0);
    tm.pset(0, 0, (1, 2));
    tm.pset(1, 0, (3, 4));
    tm.pset(0, 1, (5, 6));
    tm.pset(1, 1, (7, 8));
    final tmPtr = tm.data_ptr().cast<ffi.Uint8>();
    expect(tmPtr.address, isNonZero);
    expect(tmPtr.asTypedList(8), <int>[1, 2, 3, 4, 5, 6, 7, 8]);
  });

  test('detached image clip/camera and blt work on local buffers', () {
    flutterxel.init(8, 8);

    final img = flutterxel.Image(8, 8);
    final src = flutterxel.Image(2, 2);

    img.cls(0);
    img.camera(1, 0);
    img.pset(1, 0, 3);
    img.camera();
    expect(img.pget(0, 0), 3);

    img.clip(1, 1, 2, 2);
    img.pset(0, 0, 9);
    img.rect(0, 0, 3, 3, 4);
    expect(img.pget(1, 1), 4);
    expect(img.pget(0, 0), 0);
    expect(img.pget(2, 2), 4);
    expect(img.pget(3, 3), 0);

    img.clip();
    expect(img.pget(0, 0), 3);

    src.cls(0);
    src.pset(0, 0, 7);
    src.pset(1, 0, 8);
    img.cls(0);
    img.blt(0, 0, src, 0, 0, 2, 1);
    expect(img.pget(0, 0), 7);
    expect(img.pget(1, 0), 8);

    img.blt(0, 1, src, 0, 0, -2, 1);
    expect(img.pget(0, 1), 8);
    expect(img.pget(1, 1), 7);

    img.cls(0);
    img.blt(0, 0, src, 0, 0, 2, 1, colkey: 7);
    expect(img.pget(0, 0), 0);
    expect(img.pget(1, 0), 8);
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

  test('text draws builtin glyph shape instead of a filled block', () {
    flutterxel.init(20, 10);
    flutterxel.cls(0);

    flutterxel.text(1, 1, 'A', 11);
    // Built-in 4x6 'A' glyph starts with an empty top-left pixel.
    expect(flutterxel.pget(1, 1), 0);
    expect(flutterxel.pget(2, 1), 11);
    expect(flutterxel.pget(3, 1), 0);

    flutterxel.text(6, 1, ' ', 12);
    expect(flutterxel.pget(6, 1), 0);
  });

  test('text skips non-ASCII glyphs without advancing cursor', () {
    flutterxel.init(20, 10);
    flutterxel.cls(0);

    flutterxel.text(1, 1, '한A', 12);

    // Non-ASCII glyph is skipped, so 'A' starts immediately at x=1.
    expect(flutterxel.pget(1, 1), 0);
    expect(flutterxel.pget(2, 1), 12);
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
    expect(flutterxel.btnp(32, hold: 2, repeat: 2), isTrue);

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
    flutterxel.flip();
    final nextPos = flutterxel.playPos(0);
    expect(nextPos, isNotNull);
    expect(nextPos!.pos, greaterThan(0.0));

    flutterxel.stop(0);
    expect(flutterxel.playPos(0), isNull);
  });

  test('rseed/rndi/rndf produce deterministic seeded random ranges', () {
    flutterxel.init(8, 8);

    flutterxel.rseed(1234);
    final int1 = flutterxel.rndi(10, 20);
    final double1 = flutterxel.rndf(-1.0, 1.0);

    flutterxel.rseed(1234);
    final int2 = flutterxel.rndi(10, 20);
    final double2 = flutterxel.rndf(-1.0, 1.0);

    expect(int2, int1);
    expect(double2, double1);
    expect(int1, inInclusiveRange(10, 20));
    expect(double1, inInclusiveRange(-1.0, 1.0));
  });

  test('warpMouse updates mouse position input values', () {
    flutterxel.init(8, 8);

    flutterxel.mouse(false);
    flutterxel.warpMouse(3, 4);
    expect(flutterxel.btnv(flutterxel.MOUSE_POS_X), 3);
    expect(flutterxel.btnv(flutterxel.MOUSE_POS_Y), 4);
  });

  test('nseed/noise produce deterministic seeded noise values', () {
    flutterxel.init(8, 8);

    flutterxel.nseed(77);
    final value1 = flutterxel.noise(0.25, 0.5, 0.75);
    final value2 = flutterxel.noise(0.25, 0.5, 0.75);

    flutterxel.nseed(77);
    final value3 = flutterxel.noise(0.25, 0.5, 0.75);

    expect(value2, value1);
    expect(value3, value1);
    expect(value1, inInclusiveRange(-1.0, 1.0));
  });

  test('math helpers follow Pyxel-compatible numeric behavior', () {
    expect(flutterxel.ceil(1.2), 2);
    expect(flutterxel.floor(-1.2), -2);

    expect(flutterxel.clamp(10, 0, 5), 5);
    expect(flutterxel.clamp(10, 5, 0), 5);
    expect(flutterxel.clamp(0.25, 0.5, -0.5), 0.25);

    expect(flutterxel.sgn(-12), -1);
    expect(flutterxel.sgn(0), 0);
    expect(flutterxel.sgn(9), 1);
    expect(flutterxel.sgn(-0.1), -1.0);

    expect(flutterxel.sqrt(9), 3);
    expect(flutterxel.sin(30), closeTo(0.5, 1e-9));
    expect(flutterxel.cos(60), closeTo(0.5, 1e-9));
    expect(flutterxel.atan2(1, 0), closeTo(90.0, 1e-9));
  });

  test('icon and dither are callable while initialized', () {
    flutterxel.init(8, 8);

    expect(
      () => flutterxel.icon(<String>['0123', '4567'], 1, colkey: 2),
      returnsNormally,
    );
    expect(() => flutterxel.dither(0.5), returnsNormally);
    expect(() => flutterxel.dither(-1.0), returnsNormally);
    expect(() => flutterxel.dither(2.0), returnsNormally);

    flutterxel.quit();
    expect(() => flutterxel.icon(<String>['0123'], 1), throwsStateError);
    expect(() => flutterxel.dither(0.5), throwsStateError);
  });

  test(
    'loadPal/savePal roundtrip palette map and userDataDir returns path',
    () {
      flutterxel.init(8, 8);
      final tempDir = Directory.systemTemp.createTempSync('flutterxel_pal_');
      final filePath = '${tempDir.path}${Platform.pathSeparator}palette.pyxpal';
      try {
        flutterxel.pal(0, 6);
        flutterxel.savePal(filePath);

        flutterxel.pal(0, 1);
        flutterxel.loadPal(filePath);
        flutterxel.cls(0);
        flutterxel.pset(0, 0, 0);
        expect(flutterxel.pget(0, 0), 6);

        final userDir = flutterxel.userDataDir(
          'FlutterxelVendor',
          'FlutterxelGame',
        );
        expect(userDir, contains('FlutterxelVendor'));
        expect(userDir, contains('FlutterxelGame'));
        expect(Directory(userDir).existsSync(), isTrue);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    },
  );

  test('screenshot/screencast/resetScreencast are callable and stateful', () {
    flutterxel.init(8, 8);

    expect(() => flutterxel.screenshot(), returnsNormally);
    expect(() => flutterxel.screenshot(scale: 2), returnsNormally);
    expect(flutterxel.runtimeLastScreenshotScale, 2);

    flutterxel.screencast();
    expect(flutterxel.isScreencastEnabled, isTrue);
    expect(flutterxel.runtimeScreencastScale, isNull);

    flutterxel.screencast(scale: 3);
    expect(flutterxel.isScreencastEnabled, isTrue);
    expect(flutterxel.runtimeScreencastScale, 3);

    flutterxel.resetScreencast();
    expect(flutterxel.isScreencastEnabled, isFalse);
    expect(flutterxel.runtimeScreencastScale, isNull);

    flutterxel.quit();
    expect(() => flutterxel.screenshot(), throwsStateError);
  });

  test(
    'input mirror getters expose mouse/text/drop state and clear transients',
    () {
      flutterxel.init(8, 8);

      flutterxel.setBtnState(flutterxel.KEY_SPACE, true);
      flutterxel.setBtnValue(flutterxel.MOUSE_POS_X, 3);
      flutterxel.setBtnValue(flutterxel.MOUSE_POS_Y, 4);
      flutterxel.setBtnValue(flutterxel.MOUSE_WHEEL_Y, 2);
      flutterxel.setInputText('ab');
      flutterxel.setDroppedFiles(<String>['a.txt', 'b.txt']);

      expect(flutterxel.mouseX, 3);
      expect(flutterxel.mouseY, 4);
      expect(flutterxel.mouseWheel, 2);
      expect(flutterxel.inputKeys, contains(flutterxel.KEY_SPACE));
      expect(flutterxel.inputText, 'ab');
      expect(flutterxel.droppedFiles, <String>['a.txt', 'b.txt']);

      flutterxel.flip();
      expect(flutterxel.mouseWheel, 0);
      expect(flutterxel.inputText, isEmpty);
      expect(flutterxel.droppedFiles, isEmpty);
    },
  );

  test('show advances frame and title accepts runtime title update', () {
    flutterxel.init(8, 8);
    expect(flutterxel.frameCount, 0);

    flutterxel.show();
    expect(flutterxel.frameCount, 1);

    expect(() => flutterxel.title('Flutterxel Game'), returnsNormally);
  });

  test(
    'perfMonitor/integerScale/screenMode/fullscreen are callable and reset clears runtime state',
    () {
      flutterxel.init(8, 8);
      expect(() => flutterxel.perfMonitor(true), returnsNormally);
      expect(() => flutterxel.integerScale(true), returnsNormally);
      expect(() => flutterxel.screenMode(1), returnsNormally);
      expect(() => flutterxel.fullscreen(true), returnsNormally);

      flutterxel.reset();
      expect(() => flutterxel.cls(0), throwsStateError);
    },
  );

  test('load reports failure for missing resources (no silent success)', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync(
      'flutterxel-load-miss-',
    );
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final missingPath =
        '${tempDir.path}${Platform.pathSeparator}missing.pyxres';
    expect(
      () => flutterxel.load(missingPath),
      throwsA(
        anyOf(
          isA<UnsupportedError>(),
          isA<StateError>(),
          isA<FileSystemException>(),
        ),
      ),
    );
  });

  test('save either writes output or throws (no silent no-op)', () {
    flutterxel.init(8, 8);
    final tempDir = Directory.systemTemp.createTempSync('flutterxel-save-out-');
    addTearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    final outPath = '${tempDir.path}${Platform.pathSeparator}out.pyxres';
    Object? error;
    try {
      flutterxel.save(outPath);
    } catch (e) {
      error = e;
    }

    if (error != null) {
      expect(
        error,
        anyOf(
          isA<UnsupportedError>(),
          isA<StateError>(),
          isA<FileSystemException>(),
        ),
      );
      return;
    }

    expect(File(outPath).existsSync(), isTrue);
  });

  test('quit then init clears sound/music resource proxy caches', () {
    flutterxel.init(8, 8);

    final sound = flutterxel.sounds[0];
    sound.set_notes('c3e3g3');
    sound.set_tones('tsp');
    sound.set_volumes('765');
    sound.set_effects('nsv');
    sound.speed = 12;

    final music = flutterxel.musics[0];
    music.set(<int>[1, 2, 3], <int>[4, 5], <int>[6], <int>[7, 8]);

    expect(sound.notes, isNotEmpty);
    expect(sound.tones, isNotEmpty);
    expect(sound.volumes, isNotEmpty);
    expect(sound.effects, isNotEmpty);
    expect(sound.speed, 12);
    expect(music.seqs[0], isNotEmpty);
    expect(music.seqs[1], isNotEmpty);
    expect(music.seqs[2], isNotEmpty);
    expect(music.seqs[3], isNotEmpty);

    flutterxel.quit();
    flutterxel.init(8, 8);

    expect(sound.notes, isEmpty);
    expect(sound.tones, isEmpty);
    expect(sound.volumes, isEmpty);
    expect(sound.effects, isEmpty);
    expect(sound.speed, 30);
    expect(music.seqs[0], isEmpty);
    expect(music.seqs[1], isEmpty);
    expect(music.seqs[2], isEmpty);
    expect(music.seqs[3], isEmpty);
  });
}
