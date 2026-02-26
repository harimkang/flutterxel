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
const int _fallbackTileSize = 8;
const int _fallbackRngDefaultState = 0xA3C59AC3D12B9E5D;
const int _fallbackRngMask64 = 0xFFFFFFFFFFFFFFFF;
const int _fallbackNoiseDefaultSeed = 0;

class _FallbackTilemap {
  const _FallbackTilemap({
    required this.width,
    required this.height,
    required this.imgsrc,
    required this.data,
  });

  final int width;
  final int height;
  final int imgsrc;
  final List<int> data;
}

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
final Map<int, ({int snd, double pos})> _fallbackPlayPositions =
    <int, ({int snd, double pos})>{};
List<int> _fallbackFrameBuffer = <int>[];
int _fallbackCameraX = 0;
int _fallbackCameraY = 0;
int _fallbackClipX = 0;
int _fallbackClipY = 0;
int _fallbackClipW = 0;
int _fallbackClipH = 0;
bool _fallbackMouseVisible = true;
List<int> _fallbackPaletteMap = List<int>.generate(16, (index) => index);
int _fallbackImageBankSize = 16;
final Map<int, List<int>> _fallbackImageBanks = <int, List<int>>{};
final Map<int, _FallbackTilemap> _fallbackTilemaps = <int, _FallbackTilemap>{};
int _fallbackRngState = _fallbackRngDefaultState;
int _fallbackNoiseSeed = _fallbackNoiseDefaultSeed;
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

int _seedToFallbackRngState(int seed) {
  final unsignedSeed = seed & 0xFFFFFFFF;
  return (unsignedSeed ^ _fallbackRngDefaultState) & _fallbackRngMask64;
}

int _fallbackNextRandomU32() {
  _fallbackRngState =
      ((_fallbackRngState * 6364136223846793005) + 1) & _fallbackRngMask64;
  return (_fallbackRngState >> 32) & 0xFFFFFFFF;
}

double _fallbackNoiseFade(double t) {
  return t * t * (3.0 - 2.0 * t);
}

double _fallbackNoiseLerp(double a, double b, double t) {
  return a + (b - a) * t;
}

double _fallbackNoiseHash(int seed, int x, int y, int z) {
  var n =
      (x * 374761393) +
      (y * 668265263) +
      (z * 2147483647) +
      ((seed & 0xFFFFFFFF) * 1274126177);
  n = (n ^ (n >> 13)) * 1274126177;
  final value = (n ^ (n >> 16)) & 0xFFFFFFFF;
  return (value / 0xFFFFFFFF) * 2.0 - 1.0;
}

double _fallbackSampleNoise(double x, double y, double z) {
  final x0 = x.floor();
  final y0 = y.floor();
  final z0 = z.floor();
  final tx = x - x0;
  final ty = y - y0;
  final tz = z - z0;
  final fx = _fallbackNoiseFade(tx);
  final fy = _fallbackNoiseFade(ty);
  final fz = _fallbackNoiseFade(tz);

  final c000 = _fallbackNoiseHash(_fallbackNoiseSeed, x0, y0, z0);
  final c100 = _fallbackNoiseHash(_fallbackNoiseSeed, x0 + 1, y0, z0);
  final c010 = _fallbackNoiseHash(_fallbackNoiseSeed, x0, y0 + 1, z0);
  final c110 = _fallbackNoiseHash(_fallbackNoiseSeed, x0 + 1, y0 + 1, z0);
  final c001 = _fallbackNoiseHash(_fallbackNoiseSeed, x0, y0, z0 + 1);
  final c101 = _fallbackNoiseHash(_fallbackNoiseSeed, x0 + 1, y0, z0 + 1);
  final c011 = _fallbackNoiseHash(_fallbackNoiseSeed, x0, y0 + 1, z0 + 1);
  final c111 = _fallbackNoiseHash(_fallbackNoiseSeed, x0 + 1, y0 + 1, z0 + 1);

  final x00 = _fallbackNoiseLerp(c000, c100, fx);
  final x10 = _fallbackNoiseLerp(c010, c110, fx);
  final x01 = _fallbackNoiseLerp(c001, c101, fx);
  final x11 = _fallbackNoiseLerp(c011, c111, fx);
  final y0v = _fallbackNoiseLerp(x00, x10, fy);
  final y1v = _fallbackNoiseLerp(x01, x11, fy);
  return _fallbackNoiseLerp(y0v, y1v, fz);
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

int _fallbackMapColor(int col) {
  if (col >= 0 && col < _fallbackPaletteMap.length) {
    return _fallbackPaletteMap[col];
  }
  return col;
}

void _fallbackSetPixel(int x, int y, int col) {
  final sx = x - _fallbackCameraX;
  final sy = y - _fallbackCameraY;
  if (sx < _fallbackClipX || sy < _fallbackClipY) {
    return;
  }
  if (sx >= _fallbackClipX + _fallbackClipW ||
      sy >= _fallbackClipY + _fallbackClipH) {
    return;
  }

  final index = _fallbackPixelIndex(sx, sy);
  if (index == null) {
    return;
  }
  _fallbackFrameBuffer[index] = _fallbackMapColor(col);
}

int _fallbackGetPixel(int x, int y) {
  final index = _fallbackPixelIndex(x, y);
  if (index == null) {
    return 0;
  }
  return _fallbackFrameBuffer[index];
}

bool _fallbackEllipseContains(int px, int py, int w, int h) {
  if (w <= 0 || h <= 0) {
    return false;
  }
  final dx = px * 2 + 1 - w;
  final dy = py * 2 + 1 - h;
  final wSq = w * w;
  final hSq = h * h;
  final lhs = dx * dx * hSq + dy * dy * wSq;
  final rhs = wSq * hSq;
  return lhs <= rhs;
}

void _seedFallbackResources() {
  _fallbackImageBankSize = 16;
  final bankSize = _fallbackImageBankSize;
  final bank = List<int>.filled(bankSize * bankSize, 0, growable: false);
  for (var y = 0; y < bankSize; y++) {
    for (var x = 0; x < bankSize; x++) {
      bank[y * bankSize + x] = (x + y) % 16;
    }
  }
  _fallbackImageBanks
    ..clear()
    ..[0] = bank;
  _fallbackTilemaps
    ..clear()
    ..[0] = const _FallbackTilemap(
      width: 1,
      height: 1,
      imgsrc: 0,
      data: <int>[0, 0],
    );
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
    _fallbackPlayPositions.clear();
    _fallbackFrameBuffer = List<int>.filled(width * height, 0, growable: false);
    _fallbackCameraX = 0;
    _fallbackCameraY = 0;
    _fallbackClipX = 0;
    _fallbackClipY = 0;
    _fallbackClipW = width;
    _fallbackClipH = height;
    _fallbackMouseVisible = true;
    _fallbackPaletteMap = List<int>.generate(16, (index) => index);
    _seedFallbackResources();
    _fallbackRngState = _fallbackRngDefaultState;
    _fallbackNoiseSeed = _fallbackNoiseDefaultSeed;
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
  _fallbackPlayPositions.clear();
  _fallbackFrameBuffer = <int>[];
  _fallbackCameraX = 0;
  _fallbackCameraY = 0;
  _fallbackClipX = 0;
  _fallbackClipY = 0;
  _fallbackClipW = 0;
  _fallbackClipH = 0;
  _fallbackMouseVisible = true;
  _fallbackPaletteMap = List<int>.generate(16, (index) => index);
  _fallbackImageBankSize = 16;
  _fallbackImageBanks.clear();
  _fallbackTilemaps.clear();
  _fallbackRngState = _fallbackRngDefaultState;
  _fallbackNoiseSeed = _fallbackNoiseDefaultSeed;
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
bool get isMouseVisible => _fallbackMouseVisible;

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

/// Pyxel-compatible mouse API.
void mouse(bool visible) {
  _ensureInitialized('mouse');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_mouse(visible) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_mouse failed.');
  }

  if (bindings == null) {
    _fallbackMouseVisible = visible;
  }
}

/// Pyxel-compatible warp_mouse API.
void warpMouse(double x, double y) {
  _ensureInitialized('warp_mouse');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final ok = bindings.flutterxel_core_warp_mouse(x, y);
    if (!ok) {
      throw StateError('flutterxel_core_warp_mouse failed.');
    }
    return;
  }

  final xi = x.round();
  final yi = y.round();
  setBtnValue(MOUSE_POS_X, xi);
  setBtnValue(MOUSE_POS_Y, yi);
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

/// Pyxel-compatible camera API.
void camera([int x = 0, int y = 0]) {
  _ensureInitialized('camera');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_camera(x, y) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_camera failed.');
  }
  if (bindings == null) {
    _fallbackCameraX = x;
    _fallbackCameraY = y;
  }
}

/// Pyxel-compatible clip API.
void clip([int? x, int? y, int? w, int? h]) {
  _ensureInitialized('clip');
  final clipX = x ?? 0;
  final clipY = y ?? 0;
  final clipW = w ?? width;
  final clipH = h ?? height;

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_clip(clipX, clipY, clipW, clipH) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_clip failed.');
  }
  if (bindings == null) {
    var x0 = clipX.clamp(0, width).toInt();
    var y0 = clipY.clamp(0, height).toInt();
    var x1 = (clipX + clipW).clamp(0, width).toInt();
    var y1 = (clipY + clipH).clamp(0, height).toInt();
    if (x1 < x0) {
      final temp = x1;
      x1 = x0;
      x0 = temp;
    }
    if (y1 < y0) {
      final temp = y1;
      y1 = y0;
      y0 = temp;
    }
    _fallbackClipX = x0;
    _fallbackClipY = y0;
    _fallbackClipW = x1 - x0;
    _fallbackClipH = y1 - y0;
  }
}

/// Pyxel-compatible pal API.
void pal([int? col1, int? col2]) {
  _ensureInitialized('pal');
  if (col1 == null && col2 != null) {
    throw ArgumentError('pal(col1, col2): col1 is required when col2 is set.');
  }

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_pal(
        _encodeOptionalI32(col1),
        _encodeOptionalI32(col2),
      ) ??
      true;
  if (!ok) {
    throw StateError('flutterxel_core_pal failed.');
  }
  if (bindings == null) {
    if (col1 == null && col2 == null) {
      _fallbackPaletteMap = List<int>.generate(16, (index) => index);
      return;
    }
    if (col1 != null && col1 >= 0 && col1 < _fallbackPaletteMap.length) {
      _fallbackPaletteMap[col1] = col2 ?? col1;
    }
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

/// Pyxel-compatible elli API.
void elli(int x, int y, int w, int h, int col) {
  _ensureInitialized('elli');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_elli(x, y, w, h, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_elli failed.');
  }
  if (bindings == null) {
    if (w <= 0 || h <= 0) {
      return;
    }
    for (var py = 0; py < h; py++) {
      for (var px = 0; px < w; px++) {
        if (_fallbackEllipseContains(px, py, w, h)) {
          _fallbackSetPixel(x + px, y + py, col);
        }
      }
    }
  }
}

/// Pyxel-compatible ellib API.
void ellib(int x, int y, int w, int h, int col) {
  _ensureInitialized('ellib');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_ellib(x, y, w, h, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_ellib failed.');
  }
  if (bindings == null) {
    if (w <= 0 || h <= 0) {
      return;
    }
    for (var py = 0; py < h; py++) {
      for (var px = 0; px < w; px++) {
        if (!_fallbackEllipseContains(px, py, w, h)) {
          continue;
        }
        final isEdge =
            !_fallbackEllipseContains(px - 1, py, w, h) ||
            !_fallbackEllipseContains(px + 1, py, w, h) ||
            !_fallbackEllipseContains(px, py - 1, w, h) ||
            !_fallbackEllipseContains(px, py + 1, w, h);
        if (isEdge) {
          _fallbackSetPixel(x + px, y + py, col);
        }
      }
    }
  }
}

/// Pyxel-compatible tri API.
void tri(int x1, int y1, int x2, int y2, int x3, int y3, int col) {
  _ensureInitialized('tri');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_tri(x1, y1, x2, y2, x3, y3, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_tri failed.');
  }
  if (bindings == null) {
    final minX = [x1, x2, x3].reduce(math.min);
    final maxX = [x1, x2, x3].reduce(math.max);
    final minY = [y1, y2, y3].reduce(math.min);
    final maxY = [y1, y2, y3].reduce(math.max);

    int edge(int ax, int ay, int bx, int by, int px, int py) {
      return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
    }

    for (var py = minY; py <= maxY; py++) {
      for (var px = minX; px <= maxX; px++) {
        final w1 = edge(x1, y1, x2, y2, px, py);
        final w2 = edge(x2, y2, x3, y3, px, py);
        final w3 = edge(x3, y3, x1, y1, px, py);
        final allNonNegative = w1 >= 0 && w2 >= 0 && w3 >= 0;
        final allNonPositive = w1 <= 0 && w2 <= 0 && w3 <= 0;
        if (allNonNegative || allNonPositive) {
          _fallbackSetPixel(px, py, col);
        }
      }
    }
  }
}

/// Pyxel-compatible trib API.
void trib(int x1, int y1, int x2, int y2, int x3, int y3, int col) {
  _ensureInitialized('trib');
  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_trib(x1, y1, x2, y2, x3, y3, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_trib failed.');
  }
  if (bindings == null) {
    line(x1, y1, x2, y2, col);
    line(x2, y2, x3, y3, col);
    line(x3, y3, x1, y1, col);
  }
}

/// Pyxel-compatible fill API.
void fill(int x, int y, int col) {
  _ensureInitialized('fill');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_fill(x, y, col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_fill failed.');
  }
  if (bindings == null) {
    final sx = x - _fallbackCameraX;
    final sy = y - _fallbackCameraY;
    if (sx < 0 || sx >= width || sy < 0 || sy >= height) {
      return;
    }
    if (sx < _fallbackClipX || sy < _fallbackClipY) {
      return;
    }
    if (sx >= _fallbackClipX + _fallbackClipW ||
        sy >= _fallbackClipY + _fallbackClipH) {
      return;
    }

    final startIndex = _fallbackPixelIndex(sx, sy)!;
    final targetColor = _fallbackFrameBuffer[startIndex];
    final fillColor = _fallbackMapColor(col);
    if (targetColor == fillColor) {
      return;
    }

    final stack = <int>[sx, sy];
    while (stack.isNotEmpty) {
      final cy = stack.removeLast();
      final cx = stack.removeLast();

      if (cx < 0 || cx >= width || cy < 0 || cy >= height) {
        continue;
      }
      if (cx < _fallbackClipX || cy < _fallbackClipY) {
        continue;
      }
      if (cx >= _fallbackClipX + _fallbackClipW ||
          cy >= _fallbackClipY + _fallbackClipH) {
        continue;
      }

      final index = _fallbackPixelIndex(cx, cy);
      if (index == null || _fallbackFrameBuffer[index] != targetColor) {
        continue;
      }
      _fallbackFrameBuffer[index] = fillColor;

      stack
        ..add(cx - 1)
        ..add(cy)
        ..add(cx + 1)
        ..add(cy)
        ..add(cx)
        ..add(cy - 1)
        ..add(cx)
        ..add(cy + 1);
    }
  }
}

/// Pyxel-compatible text API.
void text(int x, int y, String s, int col) {
  _ensureInitialized('text');

  final bindings = _getBindingsOrNull();
  final textPtr = s.toNativeUtf8().cast<ffi.Char>();
  try {
    final ok = bindings?.flutterxel_core_text(x, y, textPtr, col) ?? true;
    if (!ok) {
      throw StateError('flutterxel_core_text failed.');
    }
  } finally {
    calloc.free(textPtr);
  }

  if (bindings == null) {
    var cursorX = x;
    var cursorY = y;
    final lineStartX = x;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '\n') {
        cursorX = lineStartX;
        cursorY += 6;
        continue;
      }
      if (ch != ' ') {
        for (var dy = 0; dy < 6; dy++) {
          for (var dx = 0; dx < 4; dx++) {
            _fallbackSetPixel(cursorX + dx, cursorY + dy, col);
          }
        }
      }
      cursorX += 4;
    }
  }
}

void _fallbackDrawBltm(
  double x,
  double y,
  int tm,
  double u,
  double v,
  double w,
  double h, {
  int? colkey,
}) {
  final tilemap = _fallbackTilemaps[tm];
  if (tilemap == null) {
    return;
  }
  final sourceBank = _fallbackImageBanks[tilemap.imgsrc];
  if (sourceBank == null || _fallbackImageBankSize <= 0) {
    return;
  }

  final tilesW = w.abs().round().toInt();
  final tilesH = h.abs().round().toInt();
  if (tilesW <= 0 || tilesH <= 0) {
    return;
  }
  final flipX = w < 0;
  final flipY = h < 0;
  final baseDx = x.round();
  final baseDy = y.round();
  final baseTx = u.round();
  final baseTy = v.round();

  for (var dy = 0; dy < tilesH; dy++) {
    for (var dx = 0; dx < tilesW; dx++) {
      final srcTx = baseTx + (flipX ? (tilesW - 1 - dx) : dx);
      final srcTy = baseTy + (flipY ? (tilesH - 1 - dy) : dy);
      if (srcTx < 0 ||
          srcTx >= tilemap.width ||
          srcTy < 0 ||
          srcTy >= tilemap.height) {
        continue;
      }

      final tileIndex = srcTy * tilemap.width + srcTx;
      final pairIndex = tileIndex * 2;
      if (pairIndex + 1 >= tilemap.data.length) {
        continue;
      }
      final tileX = tilemap.data[pairIndex];
      final tileY = tilemap.data[pairIndex + 1];

      for (var py = 0; py < _fallbackTileSize; py++) {
        for (var px = 0; px < _fallbackTileSize; px++) {
          final srcX = tileX * _fallbackTileSize + px;
          final srcY = tileY * _fallbackTileSize + py;
          if (srcX < 0 ||
              srcX >= _fallbackImageBankSize ||
              srcY < 0 ||
              srcY >= _fallbackImageBankSize) {
            continue;
          }

          final color = sourceBank[srcY * _fallbackImageBankSize + srcX];
          if (colkey != null && color == colkey) {
            continue;
          }

          _fallbackSetPixel(
            baseDx + dx * _fallbackTileSize + px,
            baseDy + dy * _fallbackTileSize + py,
            color,
          );
        }
      }
    }
  }
}

/// Pyxel-compatible bltm API.
void bltm(
  double x,
  double y,
  int tm,
  double u,
  double v,
  double w,
  double h, {
  int? colkey,
}) {
  _ensureInitialized('bltm');

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_bltm(
        x,
        y,
        tm,
        u,
        v,
        w,
        h,
        _encodeOptionalI32(colkey),
      ) ??
      true;
  if (!ok) {
    throw StateError('flutterxel_core_bltm failed.');
  }

  if (bindings == null) {
    _fallbackDrawBltm(x, y, tm, u, v, w, h, colkey: colkey);
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
    var fallbackSnd = 0;

    if (snd is int) {
      sndKind = FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_INT.value;
      sndValue = snd;
      fallbackSnd = snd;
    } else if (snd is List<int>) {
      sndKind =
          FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_INT_LIST.value;
      seqLen = snd.length;
      fallbackSnd = snd.isEmpty ? 0 : snd.first;
      if (seqLen > 0) {
        seqPtr = calloc<ffi.Int32>(seqLen);
        for (var i = 0; i < snd.length; i++) {
          seqPtr[i] = snd[i];
        }
      }
    } else if (snd is String) {
      sndKind = FlutterxelCorePlaySndKind.FLUTTERXEL_CORE_PLAY_SND_STRING.value;
      sndStringPtr = snd.toNativeUtf8().cast<ffi.Char>();
      fallbackSnd = 0;
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
    _fallbackPlayPositions[ch] = (snd: fallbackSnd, pos: 0.0);
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
    _fallbackPlayPositions.remove(channel);
  }
  _fallbackPlayingChannels.add(0);
  _fallbackPlayPositions[0] = (snd: msc, pos: 0.0);
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
    _fallbackPlayPositions.clear();
  } else {
    _fallbackPlayingChannels.remove(ch);
    _fallbackPlayPositions.remove(ch);
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

/// Pyxel-compatible play_pos API.
({int snd, double pos})? playPos(int ch) {
  _ensureInitialized('play_pos');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final sndOut = calloc<ffi.Int32>();
    final posOut = calloc<ffi.Double>();
    try {
      final ok = bindings.flutterxel_core_play_pos(ch, sndOut, posOut);
      if (!ok) {
        return null;
      }
      return (snd: sndOut.value, pos: posOut.value);
    } finally {
      calloc.free(sndOut);
      calloc.free(posOut);
    }
  }

  return _fallbackPlayPositions[ch];
}

/// Pyxel-compatible rseed API.
void rseed(int seed) {
  _ensureInitialized('rseed');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_rseed(seed) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_rseed failed.');
  }

  if (bindings == null) {
    _fallbackRngState = _seedToFallbackRngState(seed);
  }
}

/// Pyxel-compatible rndi API.
int rndi(int a, int b) {
  _ensureInitialized('rndi');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_rndi(a, b);
  }

  final lo = math.min(a, b);
  final hi = math.max(a, b);
  final range = hi - lo + 1;
  if (range <= 0) {
    return lo;
  }
  final value = _fallbackNextRandomU32() % range;
  return lo + value;
}

/// Pyxel-compatible rndf API.
double rndf(double a, double b) {
  _ensureInitialized('rndf');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_rndf(a, b);
  }

  final lo = math.min(a, b);
  final hi = math.max(a, b);
  if ((hi - lo).abs() <= 0.0) {
    return lo;
  }
  final unit = _fallbackNextRandomU32() / 0xFFFFFFFF;
  return lo + (hi - lo) * unit;
}

/// Pyxel-compatible nseed API.
void nseed(int seed) {
  _ensureInitialized('nseed');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_nseed(seed) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_nseed failed.');
  }

  if (bindings == null) {
    _fallbackNoiseSeed = seed;
  }
}

/// Pyxel-compatible noise API.
double noise(double x, [double? y, double? z]) {
  _ensureInitialized('noise');

  final yValue = y ?? 0.0;
  final zValue = z ?? 0.0;
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_noise(x, yValue, zValue);
  }
  return _fallbackSampleNoise(x, yValue, zValue);
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
