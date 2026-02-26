// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;

import 'package:ffi/ffi.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'flutterxel_bindings_generated.dart';

const int _optionalI32None = -2147483648; // INT32_MIN
const int _optionalBoolNone = -1;
const int _optionalBoolFalse = 0;
const int _optionalBoolTrue = 1;

// Pyxel-compatible key codes (subset used for mobile-first input mapping).
const int KEY_RETURN = 0x0D;
const int KEY_ESCAPE = 0x1B;
const int KEY_SPACE = 0x20;
const int KEY_RIGHT = 0x4000004F;
const int KEY_LEFT = 0x40000050;
const int KEY_DOWN = 0x40000051;
const int KEY_UP = 0x40000052;

const int MOUSE_KEY_START_INDEX = 0x50000100;
const int MOUSE_POS_X = MOUSE_KEY_START_INDEX;
const int MOUSE_POS_Y = MOUSE_KEY_START_INDEX + 1;
const int MOUSE_WHEEL_X = MOUSE_KEY_START_INDEX + 2;
const int MOUSE_WHEEL_Y = MOUSE_KEY_START_INDEX + 3;
const int MOUSE_BUTTON_LEFT = MOUSE_KEY_START_INDEX + 4;
const int MOUSE_BUTTON_MIDDLE = MOUSE_KEY_START_INDEX + 5;
const int MOUSE_BUTTON_RIGHT = MOUSE_KEY_START_INDEX + 6;
const Set<int> _transientValueKeys = <int>{MOUSE_WHEEL_X, MOUSE_WHEEL_Y};

final Map<LogicalKeyboardKey, int> _defaultKeyboardMapping =
    <LogicalKeyboardKey, int>{
      LogicalKeyboardKey.arrowLeft: KEY_LEFT,
      LogicalKeyboardKey.arrowRight: KEY_RIGHT,
      LogicalKeyboardKey.arrowUp: KEY_UP,
      LogicalKeyboardKey.arrowDown: KEY_DOWN,
      LogicalKeyboardKey.space: KEY_SPACE,
      LogicalKeyboardKey.enter: KEY_RETURN,
      LogicalKeyboardKey.escape: KEY_ESCAPE,
    };

int width = 0;
int height = 0;
int frameCount = 0;

bool _isInitialized = false;
int _runtimeFps = 30;
Timer? _runLoopTimer;
final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
final Set<int> _fallbackPressedKeys = <int>{};
final Map<int, int> _fallbackPressedFrame = <int, int>{};
final Map<int, int> _fallbackReleasedFrame = <int, int>{};
final Map<int, int> _fallbackInputValues = <int, int>{};
final Set<int> _fallbackPlayingChannels = <int>{};
List<int> _fallbackFrameBuffer = <int>[];
FlutterxelBindings? _bindings;
Object? _bindingsLoadError;

ffi.DynamicLibrary _openLibrary() {
  final candidates = switch (Platform.operatingSystem) {
    'ios' => const [
      'flutterxel_core.framework/flutterxel_core',
      'flutterxel.framework/flutterxel',
    ],
    'macos' => const [
      'flutterxel_core.framework/flutterxel_core',
      'flutterxel.framework/flutterxel',
      'libflutterxel_core.dylib',
      'libflutterxel.dylib',
    ],
    'android' => const ['libflutterxel_core.so', 'libflutterxel.so'],
    'linux' => const ['libflutterxel_core.so', 'libflutterxel.so'],
    'windows' => const ['flutterxel_core.dll', 'flutterxel.dll'],
    _ => throw UnsupportedError(
      'Unsupported platform: ${Platform.operatingSystem}',
    ),
  };

  Object? lastError;
  for (final candidate in candidates) {
    try {
      return ffi.DynamicLibrary.open(candidate);
    } catch (error) {
      lastError = error;
    }
  }

  throw ArgumentError(
    'Unable to load native library. Tried: ${candidates.join(", ")}'
    '${lastError == null ? "" : ". Last error: $lastError"}',
  );
}

FlutterxelBindings? _getBindingsOrNull() {
  if (_bindings != null) {
    return _bindings;
  }
  if (_bindingsLoadError != null) {
    return null;
  }

  try {
    _bindings = FlutterxelBindings(_openLibrary());
    return _bindings;
  } catch (error) {
    _bindingsLoadError = error;
    return null;
  }
}

int _encodeOptionalI32(int? value) => value ?? _optionalI32None;

double _encodeOptionalF64(double? value) => value ?? double.nan;

int _encodeOptionalBool(bool? value) {
  if (value == null) {
    return _optionalBoolNone;
  }
  return value ? _optionalBoolTrue : _optionalBoolFalse;
}

void _ensureInitialized(String apiName) {
  if (!_isInitialized) {
    throw StateError('pyxel.$apiName requires init() before use.');
  }
}

int? _fallbackPixelIndex(int x, int y) {
  if (x < 0 || x >= width || y < 0 || y >= height) {
    return null;
  }
  return y * width + x;
}

void _fallbackSetPixel(int x, int y, int col) {
  final index = _fallbackPixelIndex(x, y);
  if (index == null) {
    return;
  }
  _fallbackFrameBuffer[index] = col;
}

int _fallbackGetPixel(int x, int y) {
  final index = _fallbackPixelIndex(x, y);
  if (index == null) {
    return 0;
  }
  return _fallbackFrameBuffer[index];
}

/// Pyxel-compatible 1st-scope initialization API.
void init(
  int widthValue,
  int heightValue, {
  String? title,
  int? fps,
  int? quitKey,
  int? displayScale,
  int? captureScale,
  int? captureSec,
}) {
  final bindings = _getBindingsOrNull();
  final titlePtr = title == null
      ? ffi.nullptr
      : title.toNativeUtf8().cast<ffi.Char>();

  try {
    final ok =
        bindings?.flutterxel_core_init(
          widthValue,
          heightValue,
          titlePtr,
          _encodeOptionalI32(fps),
          _encodeOptionalI32(quitKey),
          _encodeOptionalI32(displayScale),
          _encodeOptionalI32(captureScale),
          _encodeOptionalI32(captureSec),
        ) ??
        true;

    if (!ok) {
      throw StateError('flutterxel_core_init failed.');
    }

    width = widthValue;
    height = heightValue;
    frameCount = 0;
    _runtimeFps = (fps ?? 30).clamp(1, 240).toInt();
    _frameNotifier.value = frameCount;
    _fallbackPressedKeys.clear();
    _fallbackPressedFrame.clear();
    _fallbackReleasedFrame.clear();
    _fallbackInputValues.clear();
    _fallbackPlayingChannels.clear();
    _fallbackFrameBuffer = List<int>.filled(width * height, 0, growable: false);
    _isInitialized = true;
    stopRunLoop();
  } finally {
    if (titlePtr != ffi.nullptr) {
      calloc.free(titlePtr);
    }
  }
}

/// Pyxel-compatible quit API.
void quit() {
  stopRunLoop();

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_quit() ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_quit failed.');
  }

  width = 0;
  height = 0;
  frameCount = 0;
  _frameNotifier.value = frameCount;
  _fallbackPressedKeys.clear();
  _fallbackPressedFrame.clear();
  _fallbackReleasedFrame.clear();
  _fallbackInputValues.clear();
  _fallbackPlayingChannels.clear();
  _fallbackFrameBuffer = <int>[];
  _isInitialized = false;
}

/// Pyxel-compatible run API.
///
/// In Flutter, this starts a non-blocking periodic loop.
void run(void Function() update, void Function() draw) {
  _ensureInitialized('run');

  stopRunLoop();
  _runFrame(update, draw);

  final frameIntervalMs = (1000 / _runtimeFps).round().clamp(1, 1000);
  _runLoopTimer = Timer.periodic(Duration(milliseconds: frameIntervalMs), (_) {
    _runFrame(update, draw);
  });
}

void _runFrame(void Function() update, void Function() draw) {
  update();
  draw();
  flip();
}

/// Pyxel-compatible flip API.
void flip() {
  _ensureInitialized('flip');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_flip() ?? true;

  if (!ok) {
    throw StateError('flutterxel_core_flip failed.');
  }

  frameCount = bindings?.flutterxel_core_frame_count() ?? (frameCount + 1);
  _fallbackReleasedFrame.removeWhere(
    (_, releasedFrame) => releasedFrame != frameCount,
  );
  _clearTransientInputValues();
  _frameNotifier.value = frameCount;
}

void _clearTransientInputValues() {
  if (!_isInitialized) {
    return;
  }

  for (final key in _transientValueKeys) {
    if ((_fallbackInputValues[key] ?? 0) != 0) {
      setBtnValue(key, 0);
    }
  }
}

bool get isRunning => _runLoopTimer?.isActive ?? false;

void stopRunLoop() {
  _runLoopTimer?.cancel();
  _runLoopTimer = null;
}

/// Pyxel-compatible btn API.
bool btn(int key) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  if (bindings == null) {
    return _fallbackPressedKeys.contains(key);
  }
  return bindings.flutterxel_core_btn(key);
}

/// Pyxel-compatible btnp API.
bool btnp(int key, {int hold = 0, int period = 0}) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_btnp(key, hold, period);
  }

  if (!_fallbackPressedKeys.contains(key)) {
    return false;
  }
  final pressedFrame = _fallbackPressedFrame[key];
  if (pressedFrame == null) {
    return false;
  }

  final elapsed = frameCount - pressedFrame;
  if (elapsed == 0) {
    return true;
  }
  if (hold <= 0 || period <= 0) {
    return false;
  }
  if (elapsed < hold) {
    return false;
  }
  return ((elapsed - hold) % period) == 0;
}

/// Pyxel-compatible btnr API.
bool btnr(int key) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_btnr(key);
  }
  return _fallbackReleasedFrame[key] == frameCount;
}

/// Pyxel-compatible btnv API.
int btnv(int key) {
  if (!_isInitialized) {
    return 0;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_btnv(key);
  }
  return _fallbackInputValues[key] ?? 0;
}

/// Runtime input bridge for forwarding external key/touch mappings.
void setBtnState(int key, bool pressed) {
  if (!_isInitialized) {
    return;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final ok = bindings.flutterxel_core_set_btn_state(key, pressed);
    if (!ok) {
      throw StateError('flutterxel_core_set_btn_state failed.');
    }
  }
  if (pressed) {
    final inserted = _fallbackPressedKeys.add(key);
    if (inserted) {
      _fallbackPressedFrame[key] = frameCount;
    }
    _fallbackReleasedFrame.remove(key);
    _fallbackInputValues[key] = 1;
  } else {
    final removed = _fallbackPressedKeys.remove(key);
    _fallbackPressedFrame.remove(key);
    if (removed) {
      _fallbackReleasedFrame[key] = frameCount;
    }
    _fallbackInputValues[key] = 0;
  }
}

/// Runtime input bridge for forwarding value-based key state.
void setBtnValue(int key, int value) {
  if (!_isInitialized) {
    return;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final ok = bindings.flutterxel_core_set_btn_value(key, value);
    if (!ok) {
      throw StateError('flutterxel_core_set_btn_value failed.');
    }
  }
  _fallbackInputValues[key] = value;
}

/// Pyxel-compatible cls API.
void cls(int col) {
  _ensureInitialized('cls');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_cls(col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_cls failed.');
  }
  if (bindings == null) {
    _fallbackFrameBuffer.fillRange(0, _fallbackFrameBuffer.length, col);
  }
}

/// Pyxel-compatible pset API.
void pset(int x, int y, int col) {
  _ensureInitialized('pset');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_pset(x, y, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_pset failed.');
  }
  if (bindings == null) {
    _fallbackSetPixel(x, y, col);
  }
}

/// Pyxel-compatible pget API.
int pget(int x, int y) {
  _ensureInitialized('pget');
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_pget(x, y);
  }
  return _fallbackGetPixel(x, y);
}

/// Pyxel-compatible line API.
void line(int x1, int y1, int x2, int y2, int col) {
  _ensureInitialized('line');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_line(x1, y1, x2, y2, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_line failed.');
  }
  if (bindings == null) {
    var cx = x1;
    var cy = y1;
    final dx = (x2 - x1).abs();
    final sx = x1 < x2 ? 1 : -1;
    final dy = -(y2 - y1).abs();
    final sy = y1 < y2 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      _fallbackSetPixel(cx, cy, col);
      if (cx == x2 && cy == y2) {
        break;
      }
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        cx += sx;
      }
      if (e2 <= dx) {
        err += dx;
        cy += sy;
      }
    }
  }
}

/// Pyxel-compatible rect API.
void rect(int x, int y, int w, int h, int col) {
  _ensureInitialized('rect');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_rect(x, y, w, h, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_rect failed.');
  }
  if (bindings == null) {
    if (w <= 0 || h <= 0) {
      return;
    }
    for (var py = y; py < y + h; py++) {
      for (var px = x; px < x + w; px++) {
        _fallbackSetPixel(px, py, col);
      }
    }
  }
}

/// Pyxel-compatible rectb API.
void rectb(int x, int y, int w, int h, int col) {
  _ensureInitialized('rectb');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_rectb(x, y, w, h, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_rectb failed.');
  }
  if (bindings == null) {
    if (w <= 0 || h <= 0) {
      return;
    }
    final right = x + w - 1;
    final bottom = y + h - 1;
    for (var px = x; px <= right; px++) {
      _fallbackSetPixel(px, y, col);
      _fallbackSetPixel(px, bottom, col);
    }
    for (var py = y + 1; py < bottom; py++) {
      _fallbackSetPixel(x, py, col);
      _fallbackSetPixel(right, py, col);
    }
  }
}

/// Pyxel-compatible circ API.
void circ(int x, int y, int r, int col) {
  _ensureInitialized('circ');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_circ(x, y, r, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_circ failed.');
  }
  if (bindings == null) {
    if (r < 0) {
      return;
    }
    final rr = r * r;
    for (var dy = -r; dy <= r; dy++) {
      final remain = rr - (dy * dy);
      final maxDx = math.sqrt(remain).floor();
      for (var dx = -maxDx; dx <= maxDx; dx++) {
        _fallbackSetPixel(x + dx, y + dy, col);
      }
    }
  }
}

/// Pyxel-compatible circb API.
void circb(int x, int y, int r, int col) {
  _ensureInitialized('circb');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_circb(x, y, r, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_circb failed.');
  }
  if (bindings == null) {
    if (r < 0) {
      return;
    }
    var px = r;
    var py = 0;
    var err = 1 - px;
    while (px >= py) {
      _fallbackSetPixel(x + px, y + py, col);
      _fallbackSetPixel(x - px, y + py, col);
      _fallbackSetPixel(x + px, y - py, col);
      _fallbackSetPixel(x - px, y - py, col);
      _fallbackSetPixel(x + py, y + px, col);
      _fallbackSetPixel(x - py, y + px, col);
      _fallbackSetPixel(x + py, y - px, col);
      _fallbackSetPixel(x - py, y - px, col);
      py += 1;
      if (err < 0) {
        err += 2 * py + 1;
      } else {
        px -= 1;
        err += 2 * (py - px + 1);
      }
    }
  }
}

/// Pyxel-compatible blt API.
void blt(
  double x,
  double y,
  Object img,
  double u,
  double v,
  double w,
  double h, {
  int? colkey,
  double? rotate,
  double? scale,
}) {
  _ensureInitialized('blt');

  final imageId = switch (img) {
    int value => value,
    _ => throw UnsupportedError('blt img currently supports only int id.'),
  };

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_blt(
        x,
        y,
        imageId,
        u,
        v,
        w,
        h,
        _encodeOptionalI32(colkey),
        _encodeOptionalF64(rotate),
        _encodeOptionalF64(scale),
      ) ??
      true;

  if (!ok) {
    throw StateError('flutterxel_core_blt failed.');
  }
}

/// Pyxel-compatible play API.
void play(int ch, Object snd, {double? sec, bool? loop, bool? resume}) {
  _ensureInitialized('play');

  final bindings = _getBindingsOrNull();
  ffi.Pointer<ffi.Int32> seqPtr = ffi.nullptr;
  var seqLen = 0;
  ffi.Pointer<ffi.Char> sndStringPtr = ffi.nullptr;

  try {
    late final int sndKind;
    var sndValue = 0;

    if (snd is int) {
      sndKind = FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_INT.value;
      sndValue = snd;
    } else if (snd is List<int>) {
      sndKind =
          FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_INT_LIST.value;
      seqLen = snd.length;
      if (seqLen > 0) {
        seqPtr = calloc<ffi.Int32>(seqLen);
        for (var i = 0; i < snd.length; i++) {
          seqPtr[i] = snd[i];
        }
      }
    } else if (snd is String) {
      sndKind = FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_STRING.value;
      sndStringPtr = snd.toNativeUtf8().cast<ffi.Char>();
    } else {
      throw UnsupportedError(
        'play snd supports int, List<int>, or String in current skeleton.',
      );
    }

    final ok =
        bindings?.flutterxel_core_play(
          ch,
          sndKind,
          sndValue,
          seqPtr,
          seqLen,
          sndStringPtr,
          _encodeOptionalF64(sec),
          _encodeOptionalBool(loop),
          _encodeOptionalBool(resume),
        ) ??
        true;

    if (!ok) {
      throw StateError('flutterxel_core_play failed.');
    }
    _fallbackPlayingChannels.add(ch);
  } finally {
    if (seqPtr != ffi.nullptr) {
      calloc.free(seqPtr);
    }
    if (sndStringPtr != ffi.nullptr) {
      calloc.free(sndStringPtr);
    }
  }
}

/// Pyxel-compatible playm API.
void playm(int msc, {bool loop = false}) {
  _ensureInitialized('playm');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_playm(msc, loop) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_playm failed.');
  }

  for (var channel = 0; channel < 4; channel++) {
    _fallbackPlayingChannels.remove(channel);
  }
  _fallbackPlayingChannels.add(0);
}

/// Pyxel-compatible stop API.
void stop([int? ch]) {
  _ensureInitialized('stop');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_stop(_encodeOptionalI32(ch)) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_stop failed.');
  }

  if (ch == null) {
    _fallbackPlayingChannels.clear();
  } else {
    _fallbackPlayingChannels.remove(ch);
  }
}

/// Returns whether a channel is currently marked as playing in the core.
bool isChannelPlaying(int ch) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_is_channel_playing(ch);
  }
  return _fallbackPlayingChannels.contains(ch);
}

/// Pyxel-compatible load API.
void load(
  String filename, {
  bool? excludeImages,
  bool? excludeTilemaps,
  bool? excludeSounds,
  bool? excludeMusics,
}) {
  _ensureInitialized('load');

  final bindings = _getBindingsOrNull();
  final filenamePtr = filename.toNativeUtf8().cast<ffi.Char>();

  try {
    final ok =
        bindings?.flutterxel_core_load(
          filenamePtr,
          _encodeOptionalBool(excludeImages),
          _encodeOptionalBool(excludeTilemaps),
          _encodeOptionalBool(excludeSounds),
          _encodeOptionalBool(excludeMusics),
        ) ??
        true;

    if (!ok) {
      throw StateError('flutterxel_core_load failed.');
    }
  } finally {
    calloc.free(filenamePtr);
  }
}

/// Pyxel-compatible save API.
void save(
  String filename, {
  bool? excludeImages,
  bool? excludeTilemaps,
  bool? excludeSounds,
  bool? excludeMusics,
}) {
  _ensureInitialized('save');

  final bindings = _getBindingsOrNull();
  final filenamePtr = filename.toNativeUtf8().cast<ffi.Char>();

  try {
    final ok =
        bindings?.flutterxel_core_save(
          filenamePtr,
          _encodeOptionalBool(excludeImages),
          _encodeOptionalBool(excludeTilemaps),
          _encodeOptionalBool(excludeSounds),
          _encodeOptionalBool(excludeMusics),
        ) ??
        true;

    if (!ok) {
      throw StateError('flutterxel_core_save failed.');
    }
  } finally {
    calloc.free(filenamePtr);
  }
}

/// Returns a copy of the current paletted framebuffer.
List<int> frameBufferSnapshot() {
  _ensureInitialized('frameBufferSnapshot');
  final bindings = _getBindingsOrNull();
  if (bindings == null) {
    return List<int>.from(_fallbackFrameBuffer, growable: false);
  }
  final len = bindings.flutterxel_core_framebuffer_len();
  if (len <= 0) {
    return const [];
  }

  final ptr = bindings.flutterxel_core_framebuffer_ptr();
  if (ptr == ffi.nullptr) {
    return const [];
  }

  return ptr.asTypedList(len).toList(growable: false);
}

class Flutterxel {
  Flutterxel._();

  static int versionMajor() =>
      _getBindingsOrNull()?.flutterxel_core_version_major() ?? 0;

  static int versionMinor() =>
      _getBindingsOrNull()?.flutterxel_core_version_minor() ?? 0;

  static int versionPatch() =>
      _getBindingsOrNull()?.flutterxel_core_version_patch() ?? 0;
}

const List<Color> _defaultPalette = <Color>[
  Color(0xFF000000),
  Color(0xFF2B335F),
  Color(0xFF7E2072),
  Color(0xFF19959C),
  Color(0xFF8B4852),
  Color(0xFF395C98),
  Color(0xFFA9C1FF),
  Color(0xFFEEEEEE),
  Color(0xFFD4186C),
  Color(0xFFD38441),
  Color(0xFFE9C35B),
  Color(0xFF70C6A9),
  Color(0xFF7696DE),
  Color(0xFFA3A3A3),
  Color(0xFFFF9798),
  Color(0xFFEDC7B0),
];

class FlutterxelView extends StatefulWidget {
  const FlutterxelView({
    super.key,
    this.pixelScale = 4,
    this.palette = _defaultPalette,
    this.backgroundColor = const Color(0xFF000000),
    this.captureInput = true,
    this.autofocus = true,
    this.keyboardMapping,
    this.focusNode,
  });

  final double pixelScale;
  final List<Color> palette;
  final Color backgroundColor;
  final bool captureInput;
  final bool autofocus;
  final Map<LogicalKeyboardKey, int>? keyboardMapping;
  final FocusNode? focusNode;

  @override
  State<FlutterxelView> createState() => _FlutterxelViewState();
}

class _FlutterxelViewState extends State<FlutterxelView> {
  late final FocusNode _focusNode;
  late final bool _ownsFocusNode;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'FlutterxelView');
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (!widget.captureInput || !_isInitialized) {
      return KeyEventResult.ignored;
    }

    final mapping = widget.keyboardMapping ?? _defaultKeyboardMapping;
    final mappedKey = mapping[event.logicalKey];
    if (mappedKey == null) {
      return KeyEventResult.ignored;
    }

    final pressed = event is! KeyUpEvent;
    setBtnState(mappedKey, pressed);
    return KeyEventResult.handled;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.captureInput || !_isInitialized) {
      return;
    }
    _focusNode.requestFocus();
    _updatePointerPosition(event);
    setBtnState(MOUSE_BUTTON_LEFT, true);
  }

  void _handlePointerUp(PointerEvent event) {
    if (!widget.captureInput || !_isInitialized) {
      return;
    }
    _updatePointerPosition(event);
    setBtnState(MOUSE_BUTTON_LEFT, false);
  }

  void _handlePointerMove(PointerEvent event) {
    if (!widget.captureInput || !_isInitialized) {
      return;
    }
    _updatePointerPosition(event);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (!widget.captureInput || !_isInitialized) {
      return;
    }
    if (event is! PointerScrollEvent) {
      return;
    }

    setBtnValue(MOUSE_WHEEL_X, event.scrollDelta.dx.round());
    setBtnValue(MOUSE_WHEEL_Y, event.scrollDelta.dy.round());
  }

  void _updatePointerPosition(PointerEvent event) {
    final x = (event.localPosition.dx / widget.pixelScale).floor();
    final y = (event.localPosition.dy / widget.pixelScale).floor();
    final boundedX = x.clamp(0, width > 0 ? width - 1 : 0).toInt();
    final boundedY = y.clamp(0, height > 0 ? height - 1 : 0).toInt();
    setBtnValue(MOUSE_POS_X, boundedX);
    setBtnValue(MOUSE_POS_Y, boundedY);
  }

  @override
  Widget build(BuildContext context) {
    final viewWidth = width > 0 ? width : 1;
    final viewHeight = height > 0 ? height : 1;

    final view = AnimatedBuilder(
      animation: _frameNotifier,
      builder: (context, _) {
        final frame = frameBufferSnapshot();
        return RepaintBoundary(
          child: CustomPaint(
            size: Size(
              viewWidth * widget.pixelScale,
              viewHeight * widget.pixelScale,
            ),
            painter: _FlutterxelViewPainter(
              frame: frame,
              frameWidth: viewWidth,
              frameHeight: viewHeight,
              pixelScale: widget.pixelScale,
              palette: widget.palette,
              backgroundColor: widget.backgroundColor,
            ),
          ),
        );
      },
    );

    if (!widget.captureInput) {
      return view;
    }

    return Focus(
      autofocus: widget.autofocus,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _handlePointerDown,
        onPointerHover: _handlePointerMove,
        onPointerMove: _handlePointerMove,
        onPointerSignal: _handlePointerSignal,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        child: view,
      ),
    );
  }
}

class _FlutterxelViewPainter extends CustomPainter {
  _FlutterxelViewPainter({
    required this.frame,
    required this.frameWidth,
    required this.frameHeight,
    required this.pixelScale,
    required this.palette,
    required this.backgroundColor,
  });

  final List<int> frame;
  final int frameWidth;
  final int frameHeight;
  final double pixelScale;
  final List<Color> palette;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (frame.isEmpty || palette.isEmpty) {
      return;
    }

    final maxPixels = frameWidth * frameHeight;
    final pixelsToDraw = frame.length < maxPixels ? frame.length : maxPixels;

    final paints = <Paint>[];
    for (final color in palette) {
      paints.add(Paint()..color = color);
    }

    for (var index = 0; index < pixelsToDraw; index++) {
      final colorIndex = frame[index].abs() % paints.length;
      final x = (index % frameWidth) * pixelScale;
      final y = (index ~/ frameWidth) * pixelScale;
      canvas.drawRect(
        Rect.fromLTWH(x, y, pixelScale, pixelScale),
        paints[colorIndex],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlutterxelViewPainter oldDelegate) {
    return !identical(oldDelegate.frame, frame) ||
        oldDelegate.frameWidth != frameWidth ||
        oldDelegate.frameHeight != frameHeight ||
        oldDelegate.pixelScale != pixelScale ||
        oldDelegate.palette != palette ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
