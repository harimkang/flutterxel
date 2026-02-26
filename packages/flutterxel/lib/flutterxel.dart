// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:async';
import 'dart:collection';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'flutterxel_bindings_generated.dart';
import 'src/pyxel_constants.dart';

export 'src/pyxel_constants.dart';

const int _optionalI32None = -2147483648; // INT32_MIN
const int _optionalBoolNone = -1;
const int _optionalBoolFalse = 0;
const int _optionalBoolTrue = 1;
const int _i64Min = -0x8000000000000000;
const int _i64Max = 0x7FFFFFFFFFFFFFFF;
const Set<int> _transientValueKeys = <int>{MOUSE_WHEEL_X, MOUSE_WHEEL_Y};
const int _fallbackTileSize = TILE_SIZE;
const int _fallbackRngDefaultState = 0xA3C59AC3D12B9E5D;
const int _fallbackRngMask64 = 0xFFFFFFFFFFFFFFFF;
const int _fallbackNoiseDefaultSeed = 0;

class _FallbackTilemap {
  _FallbackTilemap({
    required this.width,
    required this.height,
    required this.imgsrc,
    required this.data,
  });

  int width;
  int height;
  int imgsrc;
  List<int> data;
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
int get frame_count => frameCount;

bool _isInitialized = false;
int _runtimeFps = 30;
Timer? _runLoopTimer;
final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
final Set<int> _fallbackPressedKeys = <int>{};
final Map<int, int> _fallbackPressedFrame = <int, int>{};
final Map<int, int> _fallbackReleasedFrame = <int, int>{};
final Map<int, int> _fallbackInputValues = <int, int>{};
String _fallbackInputText = '';
List<String> _fallbackDroppedFiles = const <String>[];
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
String _fallbackTitle = '';
List<String> _fallbackIconData = const <String>[];
int _fallbackIconScale = 1;
int? _fallbackIconColkey;
double _fallbackDitherAlpha = 1.0;
int? _fallbackLastScreenshotScale;
int? _fallbackScreencastScale;
bool _fallbackScreencastEnabled = false;
bool _fallbackPerfMonitorEnabled = false;
bool _fallbackIntegerScaleEnabled = true;
int _fallbackScreenMode = 0;
bool _fallbackFullscreenEnabled = false;
List<int> _fallbackPaletteMap = List<int>.generate(
  NUM_COLORS,
  (index) => index,
);
int _fallbackImageBankSize = IMAGE_SIZE;
final Map<int, List<int>> _fallbackImageBanks = <int, List<int>>{};
final Map<int, _FallbackTilemap> _fallbackTilemaps = <int, _FallbackTilemap>{};
int _fallbackRngState = _fallbackRngDefaultState;
int _fallbackNoiseSeed = _fallbackNoiseDefaultSeed;
FlutterxelBindings? _bindings;
Object? _bindingsLoadError;
final Finalizer<ffi.Pointer<ffi.Void>> _nativeBufferFinalizer =
    Finalizer<ffi.Pointer<ffi.Void>>((pointer) {
      calloc.free(pointer);
    });

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

class _ParsedTmxLayer {
  const _ParsedTmxLayer({
    required this.width,
    required this.height,
    required this.tilesetFirstGid,
    required this.tilesetColumns,
    required this.gids,
  });

  final int width;
  final int height;
  final int tilesetFirstGid;
  final int tilesetColumns;
  final List<int> gids;
}

Map<String, String> _parseXmlAttributes(String source) {
  final attrs = <String, String>{};
  final doubleQuote = RegExp(r'([A-Za-z_][A-Za-z0-9_:-]*)\s*=\s*"([^"]*)"');
  final singleQuote = RegExp(r"([A-Za-z_][A-Za-z0-9_:-]*)\s*=\s*'([^']*)'");
  for (final match in doubleQuote.allMatches(source)) {
    attrs[match.group(1)!] = match.group(2)!;
  }
  for (final match in singleQuote.allMatches(source)) {
    attrs[match.group(1)!] = match.group(2)!;
  }
  return attrs;
}

int _requiredIntAttr(Map<String, String> attrs, String name, String context) {
  final raw = attrs[name];
  if (raw == null) {
    throw FormatException('$context is missing "$name" attribute.');
  }
  final parsed = int.tryParse(raw);
  if (parsed == null) {
    throw FormatException('$context has invalid "$name" value.');
  }
  return parsed;
}

_ParsedTmxLayer _parseTmxLayer(String tmxText, int layerIndex) {
  final mapMatch = RegExp(r'<map\b([^>]*)>', dotAll: true).firstMatch(tmxText);
  if (mapMatch == null) {
    throw const FormatException('Failed to parse TMX file.');
  }
  final mapAttrs = _parseXmlAttributes(mapMatch.group(1)!);
  final tileWidth = _requiredIntAttr(mapAttrs, 'tilewidth', 'TMX map');
  final tileHeight = _requiredIntAttr(mapAttrs, 'tileheight', 'TMX map');
  if (tileWidth != TILE_SIZE || tileHeight != TILE_SIZE) {
    throw FormatException(
      "TMX file's tile size is not ${TILE_SIZE}x$TILE_SIZE.",
    );
  }

  final tilesetMatches = RegExp(
    r'<tileset\b([^>]*)>',
    dotAll: true,
  ).allMatches(tmxText).toList(growable: false);
  if (tilesetMatches.isEmpty) {
    throw const FormatException('Tileset not found in TMX file.');
  }
  final tilesetAttrs = _parseXmlAttributes(tilesetMatches.first.group(1)!);
  final tilesetFirstGid = _requiredIntAttr(
    tilesetAttrs,
    'firstgid',
    'TMX tileset',
  );
  final tilesetColumns = _requiredIntAttr(
    tilesetAttrs,
    'columns',
    'TMX tileset',
  );
  if (tilesetColumns <= 0) {
    throw const FormatException('TMX tileset columns must be positive.');
  }

  final layerMatches = RegExp(
    r'<layer\b([^>]*)>([\s\S]*?)</layer>',
    dotAll: true,
  ).allMatches(tmxText).toList(growable: false);
  if (layerIndex < 0 || layerIndex >= layerMatches.length) {
    throw FormatException('Layer $layerIndex not found in TMX file.');
  }
  final layerMatch = layerMatches[layerIndex];
  final layerAttrs = _parseXmlAttributes(layerMatch.group(1)!);
  final layerWidth = _requiredIntAttr(layerAttrs, 'width', 'TMX layer');
  final layerHeight = _requiredIntAttr(layerAttrs, 'height', 'TMX layer');

  final layerInner = layerMatch.group(2)!;
  final dataMatch = RegExp(
    r'<data\b([^>]*)>([\s\S]*?)</data>',
    dotAll: true,
  ).firstMatch(layerInner);
  if (dataMatch == null) {
    throw const FormatException('TMX layer data not found.');
  }
  final dataAttrs = _parseXmlAttributes(dataMatch.group(1)!);
  final encoding = dataAttrs['encoding']?.toLowerCase();
  if (encoding != 'csv') {
    throw const FormatException("TMX file's encoding is not CSV.");
  }

  final csv = dataMatch.group(2)!.replaceAll(RegExp(r'\s+'), '');
  final gids = <int>[];
  if (csv.isNotEmpty) {
    for (final token in csv.split(',')) {
      final value = int.tryParse(token);
      if (value == null) {
        throw const FormatException('Failed to parse CSV tile data.');
      }
      gids.add(value);
    }
  }

  return _ParsedTmxLayer(
    width: layerWidth,
    height: layerHeight,
    tilesetFirstGid: tilesetFirstGid,
    tilesetColumns: tilesetColumns,
    gids: gids,
  );
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

int? _parsePaletteLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
    return int.tryParse(trimmed.substring(2), radix: 16);
  }

  final hexLike = RegExp(r'^[0-9A-Fa-f]+$').hasMatch(trimmed);
  if (hexLike && (trimmed.length == 6 || trimmed.length == 8)) {
    return int.tryParse(trimmed, radix: 16);
  }

  return int.tryParse(trimmed) ??
      (hexLike ? int.tryParse(trimmed, radix: 16) : null);
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

List<int> _fallbackEnsureImageBank(int imageId) {
  final size = _fallbackImageBankSize;
  final expected = size * size;
  final existing = _fallbackImageBanks[imageId];
  if (existing != null && existing.length == expected) {
    return existing;
  }
  final created = List<int>.filled(expected, 0, growable: false);
  _fallbackImageBanks[imageId] = created;
  return created;
}

int _fallbackImageBankPixelIndex(int x, int y) {
  if (x < 0 ||
      y < 0 ||
      x >= _fallbackImageBankSize ||
      y >= _fallbackImageBankSize) {
    return -1;
  }
  return y * _fallbackImageBankSize + x;
}

void _fallbackSetImagePixel(int imageId, int x, int y, int col) {
  final index = _fallbackImageBankPixelIndex(x, y);
  if (index < 0) {
    return;
  }
  final bank = _fallbackEnsureImageBank(imageId);
  bank[index] = col;
}

int _fallbackGetImagePixel(int imageId, int x, int y) {
  final index = _fallbackImageBankPixelIndex(x, y);
  if (index < 0) {
    return 0;
  }
  final bank = _fallbackEnsureImageBank(imageId);
  return bank[index];
}

_FallbackTilemap _fallbackEnsureTilemap(int tilemapId) {
  final existing = _fallbackTilemaps[tilemapId];
  if (existing != null) {
    if (existing.width < TILEMAP_SIZE || existing.height < TILEMAP_SIZE) {
      final newWidth = TILEMAP_SIZE;
      final newHeight = TILEMAP_SIZE;
      final newData = List<int>.filled(
        newWidth * newHeight * 2,
        0,
        growable: false,
      );
      final copyWidth = math.min(existing.width, newWidth);
      final copyHeight = math.min(existing.height, newHeight);
      for (var y = 0; y < copyHeight; y++) {
        for (var x = 0; x < copyWidth; x++) {
          final oldPairIndex = (y * existing.width + x) * 2;
          final newPairIndex = (y * newWidth + x) * 2;
          if (oldPairIndex + 1 >= existing.data.length) {
            continue;
          }
          newData[newPairIndex] = existing.data[oldPairIndex];
          newData[newPairIndex + 1] = existing.data[oldPairIndex + 1];
        }
      }
      existing
        ..width = newWidth
        ..height = newHeight
        ..data = newData;
    }
    return existing;
  }
  final created = _FallbackTilemap(
    width: TILEMAP_SIZE,
    height: TILEMAP_SIZE,
    imgsrc: 0,
    data: List<int>.filled(TILEMAP_SIZE * TILEMAP_SIZE * 2, 0, growable: false),
  );
  _fallbackTilemaps[tilemapId] = created;
  return created;
}

void _fallbackSetTile(int tilemapId, int x, int y, int tileX, int tileY) {
  final tilemap = _fallbackEnsureTilemap(tilemapId);
  if (x < 0 || y < 0 || x >= tilemap.width || y >= tilemap.height) {
    return;
  }
  final pairIndex = (y * tilemap.width + x) * 2;
  if (pairIndex + 1 >= tilemap.data.length) {
    return;
  }
  tilemap.data[pairIndex] = tileX;
  tilemap.data[pairIndex + 1] = tileY;
}

(int, int) _fallbackGetTile(int tilemapId, int x, int y) {
  final tilemap = _fallbackEnsureTilemap(tilemapId);
  if (x < 0 || y < 0 || x >= tilemap.width || y >= tilemap.height) {
    return (0, 0);
  }
  final pairIndex = (y * tilemap.width + x) * 2;
  if (pairIndex + 1 >= tilemap.data.length) {
    return (0, 0);
  }
  return (tilemap.data[pairIndex], tilemap.data[pairIndex + 1]);
}

void _seedFallbackResources() {
  _fallbackImageBankSize = IMAGE_SIZE;
  final bankSize = _fallbackImageBankSize;
  final bank = List<int>.filled(bankSize * bankSize, 0, growable: false);
  for (var y = 0; y < bankSize; y++) {
    for (var x = 0; x < bankSize; x++) {
      bank[y * bankSize + x] = (x + y) % NUM_COLORS;
    }
  }
  _fallbackImageBanks
    ..clear()
    ..[0] = bank;
  _fallbackTilemaps
    ..clear()
    ..[0] = _FallbackTilemap(width: 1, height: 1, imgsrc: 0, data: <int>[0, 0]);
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
    _fallbackInputText = '';
    _fallbackDroppedFiles = const <String>[];
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
    _fallbackTitle = title ?? '';
    _fallbackIconData = const <String>[];
    _fallbackIconScale = 1;
    _fallbackIconColkey = null;
    _fallbackDitherAlpha = 1.0;
    _fallbackLastScreenshotScale = null;
    _fallbackScreencastScale = null;
    _fallbackScreencastEnabled = false;
    _fallbackPerfMonitorEnabled = false;
    _fallbackIntegerScaleEnabled = true;
    _fallbackScreenMode = 0;
    _fallbackFullscreenEnabled = false;
    _fallbackPaletteMap = List<int>.generate(NUM_COLORS, (index) => index);
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

  _clearLocalRuntimeState();
}

void _clearLocalRuntimeState() {
  width = 0;
  height = 0;
  frameCount = 0;
  _frameNotifier.value = frameCount;
  _fallbackPressedKeys.clear();
  _fallbackPressedFrame.clear();
  _fallbackReleasedFrame.clear();
  _fallbackInputValues.clear();
  _fallbackInputText = '';
  _fallbackDroppedFiles = const <String>[];
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
  _fallbackTitle = '';
  _fallbackIconData = const <String>[];
  _fallbackIconScale = 1;
  _fallbackIconColkey = null;
  _fallbackDitherAlpha = 1.0;
  _fallbackLastScreenshotScale = null;
  _fallbackScreencastScale = null;
  _fallbackScreencastEnabled = false;
  _fallbackPerfMonitorEnabled = false;
  _fallbackIntegerScaleEnabled = true;
  _fallbackScreenMode = 0;
  _fallbackFullscreenEnabled = false;
  _fallbackPaletteMap = List<int>.generate(NUM_COLORS, (index) => index);
  _fallbackImageBankSize = IMAGE_SIZE;
  _fallbackImageBanks.clear();
  _fallbackTilemaps.clear();
  _fallbackRngState = _fallbackRngDefaultState;
  _fallbackNoiseSeed = _fallbackNoiseDefaultSeed;
  _isInitialized = false;
}

/// Pyxel-compatible reset API.
void reset() {
  _ensureInitialized('reset');
  stopRunLoop();

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_reset() ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_reset failed.');
  }

  _clearLocalRuntimeState();
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

/// Pyxel-compatible show API.
void show() {
  _ensureInitialized('show');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_show() ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_show failed.');
  }

  frameCount = bindings?.flutterxel_core_frame_count() ?? (frameCount + 1);
  _fallbackReleasedFrame.removeWhere(
    (_, releasedFrame) => releasedFrame != frameCount,
  );
  _clearTransientInputValues();
  _frameNotifier.value = frameCount;
}

/// Pyxel-compatible title API.
void title(String value) {
  _ensureInitialized('title');

  final bindings = _getBindingsOrNull();
  final titlePtr = value.toNativeUtf8().cast<ffi.Char>();
  try {
    final ok = bindings?.flutterxel_core_title(titlePtr) ?? true;
    if (!ok) {
      throw StateError('flutterxel_core_title failed.');
    }
  } finally {
    calloc.free(titlePtr);
  }

  if (bindings == null) {
    _fallbackTitle = value;
  }
}

/// Pyxel-compatible icon API.
void icon(List<String> data, int scale, {int? colkey}) {
  _ensureInitialized('icon');
  if (scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'must be greater than 0.');
  }
  final encoded = data.join('\n');
  if (encoded.isEmpty) {
    throw ArgumentError.value(data, 'data', 'must not be empty.');
  }

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final dataPtr = encoded.toNativeUtf8().cast<ffi.Char>();
    try {
      final ok = bindings.flutterxel_core_icon(
        dataPtr,
        scale,
        _encodeOptionalI32(colkey),
      );
      if (!ok) {
        throw StateError('flutterxel_core_icon failed.');
      }
    } finally {
      calloc.free(dataPtr);
    }
    return;
  }

  _fallbackIconData = List<String>.from(data);
  _fallbackIconScale = scale;
  _fallbackIconColkey = colkey;
}

/// Pyxel-compatible perf_monitor API.
void perfMonitor(bool enabled) {
  _ensureInitialized('perf_monitor');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_perf_monitor(enabled) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_perf_monitor failed.');
  }

  if (bindings == null) {
    _fallbackPerfMonitorEnabled = enabled;
  }
}

void perf_monitor(bool enabled) => perfMonitor(enabled);

/// Pyxel-compatible integer_scale API.
void integerScale(bool enabled) {
  _ensureInitialized('integer_scale');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_integer_scale(enabled) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_integer_scale failed.');
  }

  if (bindings == null) {
    _fallbackIntegerScaleEnabled = enabled;
  }
}

void integer_scale(bool enabled) => integerScale(enabled);

/// Pyxel-compatible screen_mode API.
void screenMode(int scr) {
  _ensureInitialized('screen_mode');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_screen_mode(scr) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_screen_mode failed.');
  }

  if (bindings == null) {
    _fallbackScreenMode = scr;
  }
}

void screen_mode(int scr) => screenMode(scr);

/// Pyxel-compatible fullscreen API.
void fullscreen(bool enabled) {
  _ensureInitialized('fullscreen');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_fullscreen(enabled) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_fullscreen failed.');
  }

  if (bindings == null) {
    _fallbackFullscreenEnabled = enabled;
  }
}

/// Pyxel-compatible dither API.
void dither(double alpha) {
  _ensureInitialized('dither');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_dither(alpha) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_dither failed.');
  }

  if (bindings == null) {
    _fallbackDitherAlpha = alpha.clamp(0.0, 1.0).toDouble();
  }
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
  _fallbackInputText = '';
  _fallbackDroppedFiles = const <String>[];
}

bool get isRunning => _runLoopTimer?.isActive ?? false;
bool get isMouseVisible => _fallbackMouseVisible;
int get mouseX => btnv(MOUSE_POS_X);
int get mouseY => btnv(MOUSE_POS_Y);
int get mouseWheel => btnv(MOUSE_WHEEL_Y);
int get mouse_x => mouseX;
int get mouse_y => mouseY;
int get mouse_wheel => mouseWheel;
List<int> get inputKeys {
  if (!_isInitialized) {
    return const <int>[];
  }
  final values = _fallbackPressedKeys.toList()..sort();
  return List<int>.unmodifiable(values);
}

String get inputText => _fallbackInputText;
List<String> get droppedFiles =>
    List<String>.unmodifiable(_fallbackDroppedFiles);
List<int> get input_keys => inputKeys;
String get input_text => inputText;
List<String> get dropped_files => droppedFiles;
String get runtimeTitle => _fallbackTitle;
List<String> get runtimeIconData =>
    List<String>.unmodifiable(_fallbackIconData);
int get runtimeIconScale => _fallbackIconScale;
int? get runtimeIconColkey => _fallbackIconColkey;
double get runtimeDitherAlpha => _fallbackDitherAlpha;
int? get runtimeLastScreenshotScale => _fallbackLastScreenshotScale;
int? get runtimeScreencastScale => _fallbackScreencastScale;
bool get isScreencastEnabled => _fallbackScreencastEnabled;
bool get isPerfMonitorEnabled => _fallbackPerfMonitorEnabled;
bool get isIntegerScaleEnabled => _fallbackIntegerScaleEnabled;
int get runtimeScreenMode => _fallbackScreenMode;
bool get isFullscreenEnabled => _fallbackFullscreenEnabled;

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
bool btnp(
  int key, {
  int hold = 0,
  int? repeat,
  @Deprecated('Use repeat instead.') int? period,
}) {
  final repeatValue = repeat ?? period ?? 0;
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_btnp(key, hold, repeatValue);
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
  if (hold <= 0 || repeatValue <= 0) {
    return false;
  }
  if (elapsed < hold) {
    return false;
  }
  return ((elapsed - hold) % repeatValue) == 0;
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

void warp_mouse(double x, double y) => warpMouse(x, y);

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

void setInputText(String text) {
  if (!_isInitialized) {
    return;
  }
  _fallbackInputText = text;
}

void setDroppedFiles(List<String> files) {
  if (!_isInitialized) {
    return;
  }
  _fallbackDroppedFiles = List<String>.from(files);
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
      _fallbackPaletteMap = List<int>.generate(NUM_COLORS, (index) => index);
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

void _fallbackDrawBlt(
  double x,
  double y,
  int img,
  double u,
  double v,
  double w,
  double h, {
  int? colkey,
}) {
  final sourceBank = _fallbackImageBanks[img] ?? _fallbackEnsureImageBank(img);
  if (_fallbackImageBankSize <= 0) {
    return;
  }

  final drawW = w.abs().round().toInt();
  final drawH = h.abs().round().toInt();
  if (drawW <= 0 || drawH <= 0) {
    return;
  }
  final flipX = w < 0;
  final flipY = h < 0;
  final srcBaseX = u.round();
  final srcBaseY = v.round();
  final dstBaseX = x.round();
  final dstBaseY = y.round();

  for (var dy = 0; dy < drawH; dy++) {
    for (var dx = 0; dx < drawW; dx++) {
      final sx = srcBaseX + (flipX ? (drawW - 1 - dx) : dx);
      final sy = srcBaseY + (flipY ? (drawH - 1 - dy) : dy);
      final sourceIndex = _fallbackImageBankPixelIndex(sx, sy);
      if (sourceIndex < 0) {
        continue;
      }

      final color = sourceBank[sourceIndex];
      if (colkey != null && color == colkey) {
        continue;
      }
      _fallbackSetPixel(dstBaseX + dx, dstBaseY + dy, color);
    }
  }
}

/// Pyxel-compatible bltm API.
void bltm(
  double x,
  double y,
  Object tm,
  double u,
  double v,
  double w,
  double h, {
  int? colkey,
  double? rotate,
  double? scale,
}) {
  _ensureInitialized('bltm');

  final tilemapId = switch (tm) {
    int value => value,
    Tilemap value => value._resourceTilemapId(),
    _ => null,
  };
  if (tilemapId == null) {
    throw UnsupportedError(
      'bltm tm currently supports int id or resource Tilemap.',
    );
  }

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_bltm(
        x,
        y,
        tilemapId,
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
    _fallbackDrawBltm(x, y, tilemapId, u, v, w, h, colkey: colkey);
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
    Image value => value._resourceImageId(),
    _ => null,
  };
  if (imageId == null) {
    throw UnsupportedError(
      'blt img currently supports int id or resource Image.',
    );
  }

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

  if (bindings == null) {
    _fallbackDrawBlt(x, y, imageId, u, v, w, h, colkey: colkey);
  }
}

void _playImpl(int ch, Object snd, {double? sec, bool? loop, bool? resume}) {
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

/// Pyxel-compatible play API.
void play(int ch, Object snd, {double? sec, bool? loop, bool? resume}) {
  _playImpl(ch, snd, sec: sec, loop: loop, resume: resume);
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

void _stopImpl(int? ch) {
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

/// Pyxel-compatible stop API.
void stop([int? ch]) {
  _stopImpl(ch);
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

({int snd, double pos})? _playPosImpl(int ch) {
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

/// Pyxel-compatible play_pos API.
({int snd, double pos})? playPos(int ch) {
  return _playPosImpl(ch);
}

({int snd, double pos})? play_pos(int ch) => playPos(ch);

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

/// Pyxel-compatible ceil API.
int ceil(num x) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_ceil(x.toDouble());
  }
  return x.ceil();
}

/// Pyxel-compatible floor API.
int floor(num x) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_floor(x.toDouble());
  }
  return x.floor();
}

/// Pyxel-compatible clamp API.
num clamp(num x, num lower, num upper) {
  final bindings = _getBindingsOrNull();
  if (x is int && lower is int && upper is int) {
    if (bindings != null &&
        x >= _i64Min &&
        x <= _i64Max &&
        lower >= _i64Min &&
        lower <= _i64Max &&
        upper >= _i64Min &&
        upper <= _i64Max) {
      return bindings.flutterxel_core_clamp_i64(x, lower, upper);
    }
    final lo = math.min(lower, upper);
    final hi = math.max(lower, upper);
    if (x < lo) {
      return lo;
    }
    if (x > hi) {
      return hi;
    }
    return x;
  }

  final xValue = x.toDouble();
  final lowerValue = lower.toDouble();
  final upperValue = upper.toDouble();
  if (bindings != null) {
    return bindings.flutterxel_core_clamp_f64(xValue, lowerValue, upperValue);
  }
  final lo = math.min(lowerValue, upperValue);
  final hi = math.max(lowerValue, upperValue);
  if (xValue < lo) {
    return lo;
  }
  if (xValue > hi) {
    return hi;
  }
  return xValue;
}

/// Pyxel-compatible sgn API.
num sgn(num x) {
  final bindings = _getBindingsOrNull();
  if (x is int) {
    if (bindings != null && x >= _i64Min && x <= _i64Max) {
      return bindings.flutterxel_core_sgn_i64(x);
    }
    if (x > 0) {
      return 1;
    }
    if (x < 0) {
      return -1;
    }
    return 0;
  }

  final xValue = x.toDouble();
  if (bindings != null) {
    return bindings.flutterxel_core_sgn_f64(xValue);
  }
  if (xValue > 0.0) {
    return 1.0;
  }
  if (xValue < 0.0) {
    return -1.0;
  }
  return 0.0;
}

/// Pyxel-compatible sqrt API.
double sqrt(num x) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_sqrt(x.toDouble());
  }
  return math.sqrt(x.toDouble());
}

/// Pyxel-compatible sin API.
double sin(num deg) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_sin(deg.toDouble());
  }
  return math.sin(deg.toDouble() * math.pi / 180.0);
}

/// Pyxel-compatible cos API.
double cos(num deg) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_cos(deg.toDouble());
  }
  return math.cos(deg.toDouble() * math.pi / 180.0);
}

/// Pyxel-compatible atan2 API.
double atan2(num y, num x) {
  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    return bindings.flutterxel_core_atan2(y.toDouble(), x.toDouble());
  }
  return math.atan2(y.toDouble(), x.toDouble()) * 180.0 / math.pi;
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

/// Pyxel-compatible load_pal API.
void loadPal(String filename) {
  _ensureInitialized('load_pal');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final filenamePtr = filename.toNativeUtf8().cast<ffi.Char>();
    try {
      final ok = bindings.flutterxel_core_load_pal(filenamePtr);
      if (!ok) {
        throw StateError('flutterxel_core_load_pal failed.');
      }
    } finally {
      calloc.free(filenamePtr);
    }
    return;
  }

  final file = File(filename);
  if (!file.existsSync()) {
    throw StateError('flutterxel_core_load_pal failed.');
  }
  final lines = file.readAsLinesSync();
  final limit = math.min(_fallbackPaletteMap.length, lines.length);
  for (var i = 0; i < limit; i++) {
    final parsed = _parsePaletteLine(lines[i]);
    if (parsed != null) {
      _fallbackPaletteMap[i] = parsed;
    }
  }
}

void load_pal(String filename) => loadPal(filename);

/// Pyxel-compatible save_pal API.
void savePal(String filename) {
  _ensureInitialized('save_pal');

  final bindings = _getBindingsOrNull();
  if (bindings != null) {
    final filenamePtr = filename.toNativeUtf8().cast<ffi.Char>();
    try {
      final ok = bindings.flutterxel_core_save_pal(filenamePtr);
      if (!ok) {
        throw StateError('flutterxel_core_save_pal failed.');
      }
    } finally {
      calloc.free(filenamePtr);
    }
    return;
  }

  final output = StringBuffer();
  for (final value in _fallbackPaletteMap) {
    output.writeln(value);
  }
  File(filename).writeAsStringSync(output.toString());
}

void save_pal(String filename) => savePal(filename);

/// Pyxel-compatible screenshot API.
void screenshot({int? scale}) {
  _ensureInitialized('screenshot');
  if (scale != null && scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'must be greater than 0.');
  }

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_screenshot(_encodeOptionalI32(scale)) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_screenshot failed.');
  }

  if (bindings == null) {
    _fallbackLastScreenshotScale = scale;
  }
}

/// Pyxel-compatible screencast API.
void screencast({int? scale}) {
  _ensureInitialized('screencast');
  if (scale != null && scale <= 0) {
    throw ArgumentError.value(scale, 'scale', 'must be greater than 0.');
  }

  final bindings = _getBindingsOrNull();
  final ok =
      bindings?.flutterxel_core_screencast(_encodeOptionalI32(scale)) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_screencast failed.');
  }

  if (bindings == null) {
    _fallbackScreencastEnabled = true;
    _fallbackScreencastScale = scale;
  }
}

/// Pyxel-compatible reset_screencast API.
void resetScreencast() {
  _ensureInitialized('reset_screencast');

  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_reset_screencast() ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_reset_screencast failed.');
  }

  if (bindings == null) {
    _fallbackScreencastEnabled = false;
    _fallbackScreencastScale = null;
  }
}

void reset_screencast() => resetScreencast();

String _joinPath(String left, String right) {
  final separator = Platform.pathSeparator;
  if (left.endsWith(separator)) {
    return '$left$right';
  }
  return '$left$separator$right';
}

/// Pyxel-compatible user_data_dir API.
String userDataDir(String vendorName, String appName) {
  final vendor = vendorName.trim();
  final app = appName.trim();
  if (vendor.isEmpty) {
    throw ArgumentError.value(vendorName, 'vendorName', 'must not be empty.');
  }
  if (app.isEmpty) {
    throw ArgumentError.value(appName, 'appName', 'must not be empty.');
  }

  final home = Platform.environment['HOME'];
  final base = switch (Platform.operatingSystem) {
    'windows' => Platform.environment['APPDATA'] ?? Directory.systemTemp.path,
    'macos' =>
      home != null && home.isNotEmpty
          ? _joinPath(_joinPath(home, 'Library'), 'Application Support')
          : Directory.systemTemp.path,
    'linux' || 'android' =>
      (Platform.environment['XDG_DATA_HOME']?.isNotEmpty ?? false)
          ? Platform.environment['XDG_DATA_HOME']!
          : (home != null && home.isNotEmpty
                ? _joinPath(_joinPath(home, '.local'), 'share')
                : Directory.systemTemp.path),
    'ios' =>
      home != null && home.isNotEmpty
          ? _joinPath(home, 'Documents')
          : Directory.systemTemp.path,
    _ => Directory.systemTemp.path,
  };

  final dirPath = _joinPath(_joinPath(base, vendor), app);
  Directory(dirPath).createSync(recursive: true);
  return dirPath;
}

String user_data_dir(String vendorName, String appName) =>
    userDataDir(vendorName, appName);

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

class Seq<T> extends ListBase<T> {
  Seq.proxy(this._source);

  final List<T> Function() _source;

  List<T> get _list => _source();

  @override
  int get length => _list.length;

  @override
  set length(int newLength) {
    _list.length = newLength;
  }

  @override
  T operator [](int index) => _list[index];

  @override
  void operator []=(int index, T value) {
    _list[index] = value;
  }

  void append(T value) => add(value);

  void extend(List<T> values) => addAll(values);

  T pop([int? index]) {
    if (index == null) {
      return removeLast();
    }
    return removeAt(index);
  }
}

class Font {
  Font(this.filename, {double? font_size}) : fontSize = font_size;

  final String filename;
  final double? fontSize;

  int text_width(String s) => textWidth(s);

  int textWidth(String s) {
    var maxChars = 0;
    for (final line in s.split('\n')) {
      if (line.length > maxChars) {
        maxChars = line.length;
      }
    }
    return maxChars * FONT_WIDTH;
  }
}

int _runtimeWidth() => width;
int _runtimeHeight() => height;

void _screenClip(num? x, num? y, num? w, num? h) {
  clip(x?.round(), y?.round(), w?.round(), h?.round());
}

void _screenCamera(num? x, num? y) {
  camera((x ?? 0).round(), (y ?? 0).round());
}

void _screenPal(int? col1, int? col2) {
  pal(col1, col2);
}

void _screenDither(double alpha) {
  dither(alpha);
}

void _screenCls(int col) {
  cls(col);
}

int _screenPget(num x, num y) {
  return pget(x.round(), y.round());
}

void _screenPset(num x, num y, int col) {
  pset(x.round(), y.round(), col);
}

void _screenLine(num x1, num y1, num x2, num y2, int col) {
  line(x1.round(), y1.round(), x2.round(), y2.round(), col);
}

void _screenRect(num x, num y, num w, num h, int col) {
  rect(x.round(), y.round(), w.round(), h.round(), col);
}

void _screenRectb(num x, num y, num w, num h, int col) {
  rectb(x.round(), y.round(), w.round(), h.round(), col);
}

void _screenCirc(num x, num y, num r, int col) {
  circ(x.round(), y.round(), r.round(), col);
}

void _screenCircb(num x, num y, num r, int col) {
  circb(x.round(), y.round(), r.round(), col);
}

void _screenElli(num x, num y, num w, num h, int col) {
  elli(x.round(), y.round(), w.round(), h.round(), col);
}

void _screenEllib(num x, num y, num w, num h, int col) {
  ellib(x.round(), y.round(), w.round(), h.round(), col);
}

void _screenTri(num x1, num y1, num x2, num y2, num x3, num y3, int col) {
  tri(
    x1.round(),
    y1.round(),
    x2.round(),
    y2.round(),
    x3.round(),
    y3.round(),
    col,
  );
}

void _screenTrib(num x1, num y1, num x2, num y2, num x3, num y3, int col) {
  trib(
    x1.round(),
    y1.round(),
    x2.round(),
    y2.round(),
    x3.round(),
    y3.round(),
    col,
  );
}

void _screenFill(num x, num y, int col) {
  fill(x.round(), y.round(), col);
}

void _screenBlt(
  num x,
  num y,
  Object img,
  num u,
  num v,
  num w,
  num h, {
  int? colkey,
  double? rotate,
  double? scale,
}) {
  blt(
    x.toDouble(),
    y.toDouble(),
    img,
    u.toDouble(),
    v.toDouble(),
    w.toDouble(),
    h.toDouble(),
    colkey: colkey,
    rotate: rotate,
    scale: scale,
  );
}

void _screenBltm(
  num x,
  num y,
  Object tm,
  num u,
  num v,
  num w,
  num h, {
  int? colkey,
  double? rotate,
  double? scale,
}) {
  bltm(
    x.toDouble(),
    y.toDouble(),
    tm,
    u.toDouble(),
    v.toDouble(),
    w.toDouble(),
    h.toDouble(),
    colkey: colkey,
    rotate: rotate,
    scale: scale,
  );
}

void _screenText(num x, num y, String s, int col) {
  text(x.round(), y.round(), s, col);
}

class Image {
  Image(int width, int height)
    : _imageId = null,
      _isScreen = false,
      _width = width,
      _height = height,
      _pixels = List<int>.filled(width * height, 0, growable: false),
      _clipX = 0,
      _clipY = 0,
      _clipW = width,
      _clipH = height,
      _cameraX = 0,
      _cameraY = 0,
      _dataPtrCache = null,
      _dataPtrCacheLength = 0;

  Image._resource(int imageId)
    : _imageId = imageId,
      _isScreen = false,
      _width = IMAGE_SIZE,
      _height = IMAGE_SIZE,
      _pixels = null,
      _clipX = 0,
      _clipY = 0,
      _clipW = IMAGE_SIZE,
      _clipH = IMAGE_SIZE,
      _cameraX = 0,
      _cameraY = 0,
      _dataPtrCache = null,
      _dataPtrCacheLength = 0;

  Image._screen()
    : _imageId = null,
      _isScreen = true,
      _width = 0,
      _height = 0,
      _pixels = null,
      _clipX = 0,
      _clipY = 0,
      _clipW = 0,
      _clipH = 0,
      _cameraX = 0,
      _cameraY = 0,
      _dataPtrCache = null,
      _dataPtrCacheLength = 0;

  final int _width;
  final int _height;
  final int? _imageId;
  final bool _isScreen;
  final List<int>? _pixels;
  int _clipX;
  int _clipY;
  int _clipW;
  int _clipH;
  int _cameraX;
  int _cameraY;
  ffi.Pointer<ffi.Uint8>? _dataPtrCache;
  int _dataPtrCacheLength;

  int get width => _isScreen ? _runtimeWidth() : _width;
  int get height => _isScreen ? _runtimeHeight() : _height;

  static Image from_image(String filename, {bool? include_colors}) {
    return fromImage(filename, includeColors: include_colors);
  }

  static Image fromImage(String filename, {bool? includeColors}) {
    final image = Image(IMAGE_SIZE, IMAGE_SIZE);
    image.load(0, 0, filename, include_colors: includeColors);
    return image;
  }

  int? _resourceImageId() => _imageId;

  ffi.Pointer<ffi.Void> data_ptr() {
    final data = switch ((_isScreen, _imageId, _pixels)) {
      (true, _, _) => _fallbackFrameBuffer,
      (false, int imageId, _) => _fallbackEnsureImageBank(imageId),
      (false, _, List<int> pixels) => pixels,
      _ => const <int>[],
    };
    final length = data.length;
    if (length <= 0) {
      return ffi.nullptr.cast<ffi.Void>();
    }
    _ensureDataPtrCapacity(length);
    final pointer = _dataPtrCache;
    if (pointer == null) {
      return ffi.nullptr.cast<ffi.Void>();
    }
    final view = pointer.asTypedList(length);
    for (var i = 0; i < length; i++) {
      view[i] = data[i] & 0xFF;
    }
    return pointer.cast<ffi.Void>();
  }

  void _ensureDataPtrCapacity(int length) {
    if (_dataPtrCache != null && _dataPtrCacheLength == length) {
      return;
    }
    if (_dataPtrCache != null) {
      _nativeBufferFinalizer.detach(this);
      calloc.free(_dataPtrCache!);
      _dataPtrCache = null;
      _dataPtrCacheLength = 0;
    }
    final buffer = calloc<ffi.Uint8>(length);
    _dataPtrCache = buffer;
    _dataPtrCacheLength = length;
    _nativeBufferFinalizer.attach(this, buffer.cast<ffi.Void>(), detach: this);
  }

  int _resolveX(num x) => x.round();
  int _resolveY(num y) => y.round();

  bool _inLocalClip(int x, int y) {
    if (_clipW <= 0 || _clipH <= 0) {
      return false;
    }
    return x >= _clipX &&
        y >= _clipY &&
        x < _clipX + _clipW &&
        y < _clipY + _clipH;
  }

  void _setLocalPixel(int x, int y, int col) {
    if (_imageId != null) {
      _fallbackSetImagePixel(_imageId, x, y, col);
      return;
    }
    final pixels = _pixels;
    if (pixels == null) {
      return;
    }
    if (x < 0 || y < 0 || x >= _width || y >= _height) {
      return;
    }
    pixels[y * _width + x] = col;
  }

  int _getLocalPixel(int x, int y) {
    if (_imageId != null) {
      return _fallbackGetImagePixel(_imageId, x, y);
    }
    final pixels = _pixels;
    if (pixels == null) {
      return 0;
    }
    if (x < 0 || y < 0 || x >= _width || y >= _height) {
      return 0;
    }
    return pixels[y * _width + x];
  }

  void set(int x, int y, List<String> data) {
    for (var row = 0; row < data.length; row++) {
      final line = data[row];
      for (var col = 0; col < line.length; col++) {
        final ch = line[col];
        final parsed = int.tryParse(ch, radix: 16);
        if (parsed != null) {
          _setLocalPixel(x + col, y + row, parsed);
        }
      }
    }
  }

  void load(int x, int y, String filename, {bool? include_colors}) {
    final file = File(filename);
    if (!file.existsSync()) {
      return;
    }
    final lines = file.readAsLinesSync();
    set(x, y, lines);
  }

  void save(String filename, int scale) {
    final output = StringBuffer();
    final h = height;
    final w = width;
    final maxRows = math.min(h, 32);
    final maxCols = math.min(w, 64);
    for (var y = 0; y < maxRows; y++) {
      for (var x = 0; x < maxCols; x++) {
        output.write(_getLocalPixel(x, y).toRadixString(16));
      }
      output.writeln();
    }
    File(filename).writeAsStringSync(output.toString());
  }

  void clip([num? x, num? y, num? w, num? h]) {
    if (_isScreen) {
      _screenClip(x, y, w, h);
      return;
    }
    if (x == null && y == null && w == null && h == null) {
      _clipX = 0;
      _clipY = 0;
      _clipW = width;
      _clipH = height;
      return;
    }

    final clipX = (x ?? 0).round();
    final clipY = (y ?? 0).round();
    final clipW = math.max(0, (w ?? width).round());
    final clipH = math.max(0, (h ?? height).round());

    final x0 = clipX.clamp(0, width).toInt();
    final y0 = clipY.clamp(0, height).toInt();
    var x1 = (clipX + clipW).clamp(0, width).toInt();
    var y1 = (clipY + clipH).clamp(0, height).toInt();
    if (x1 < x0) {
      x1 = x0;
    }
    if (y1 < y0) {
      y1 = y0;
    }
    _clipX = x0;
    _clipY = y0;
    _clipW = x1 - x0;
    _clipH = y1 - y0;
  }

  void camera([num? x, num? y]) {
    if (_isScreen) {
      _screenCamera(x, y);
      return;
    }
    _cameraX = (x ?? 0).round();
    _cameraY = (y ?? 0).round();
  }

  void pal([int? col1, int? col2]) {
    if (_isScreen) {
      _screenPal(col1, col2);
    }
  }

  void dither(double alpha) {
    if (_isScreen) {
      _screenDither(alpha);
    }
  }

  void cls(int col) {
    if (_isScreen) {
      _screenCls(col);
      return;
    }
    if (_imageId != null) {
      final bank = _fallbackEnsureImageBank(_imageId);
      for (var i = 0; i < bank.length; i++) {
        bank[i] = col;
      }
      return;
    }
    final pixels = _pixels;
    if (pixels == null) {
      return;
    }
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = col;
    }
  }

  int pget(num x, num y) {
    if (_isScreen) {
      return _screenPget(x, y);
    }
    final xi = _resolveX(x);
    final yi = _resolveY(y);
    if (!_inLocalClip(xi, yi)) {
      return 0;
    }
    return _getLocalPixel(xi, yi);
  }

  void pset(num x, num y, int col) {
    if (_isScreen) {
      _screenPset(x, y, col);
      return;
    }
    final xi = _resolveX(x) - _cameraX;
    final yi = _resolveY(y) - _cameraY;
    if (!_inLocalClip(xi, yi)) {
      return;
    }
    _setLocalPixel(xi, yi, col);
  }

  void line(num x1, num y1, num x2, num y2, int col) {
    if (_isScreen) {
      _screenLine(x1, y1, x2, y2, col);
      return;
    }
    var cx = x1.round();
    var cy = y1.round();
    final tx = x2.round();
    final ty = y2.round();
    final dx = (tx - cx).abs();
    final sx = cx < tx ? 1 : -1;
    final dy = -(ty - cy).abs();
    final sy = cy < ty ? 1 : -1;
    var err = dx + dy;
    while (true) {
      pset(cx, cy, col);
      if (cx == tx && cy == ty) {
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

  void rect(num x, num y, num w, num h, int col) {
    if (_isScreen) {
      _screenRect(x, y, w, h, col);
      return;
    }
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = y0; py < y0 + hh; py++) {
      for (var px = x0; px < x0 + ww; px++) {
        pset(px, py, col);
      }
    }
  }

  void rectb(num x, num y, num w, num h, int col) {
    if (_isScreen) {
      _screenRectb(x, y, w, h, col);
      return;
    }
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    final right = x0 + ww - 1;
    final bottom = y0 + hh - 1;
    for (var px = x0; px <= right; px++) {
      pset(px, y0, col);
      pset(px, bottom, col);
    }
    for (var py = y0 + 1; py < bottom; py++) {
      pset(x0, py, col);
      pset(right, py, col);
    }
  }

  void circ(num x, num y, num r, int col) {
    if (_isScreen) {
      _screenCirc(x, y, r, col);
      return;
    }
    final cx = x.round();
    final cy = y.round();
    final rr = r.round();
    if (rr < 0) {
      return;
    }
    final rSq = rr * rr;
    for (var dy = -rr; dy <= rr; dy++) {
      final remain = rSq - dy * dy;
      final maxDx = math.sqrt(remain).floor();
      for (var dx = -maxDx; dx <= maxDx; dx++) {
        pset(cx + dx, cy + dy, col);
      }
    }
  }

  void circb(num x, num y, num r, int col) {
    if (_isScreen) {
      _screenCircb(x, y, r, col);
      return;
    }
    final cx = x.round();
    final cy = y.round();
    final rr = r.round();
    if (rr < 0) {
      return;
    }
    var px = rr;
    var py = 0;
    var err = 1 - px;
    while (px >= py) {
      pset(cx + px, cy + py, col);
      pset(cx - px, cy + py, col);
      pset(cx + px, cy - py, col);
      pset(cx - px, cy - py, col);
      pset(cx + py, cy + px, col);
      pset(cx - py, cy + px, col);
      pset(cx + py, cy - px, col);
      pset(cx - py, cy - px, col);
      py += 1;
      if (err < 0) {
        err += 2 * py + 1;
      } else {
        px -= 1;
        err += 2 * (py - px + 1);
      }
    }
  }

  void elli(num x, num y, num w, num h, int col) {
    if (_isScreen) {
      _screenElli(x, y, w, h, col);
      return;
    }
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = 0; py < hh; py++) {
      for (var px = 0; px < ww; px++) {
        if (_fallbackEllipseContains(px, py, ww, hh)) {
          pset(x0 + px, y0 + py, col);
        }
      }
    }
  }

  void ellib(num x, num y, num w, num h, int col) {
    if (_isScreen) {
      _screenEllib(x, y, w, h, col);
      return;
    }
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = 0; py < hh; py++) {
      for (var px = 0; px < ww; px++) {
        if (!_fallbackEllipseContains(px, py, ww, hh)) {
          continue;
        }
        final isEdge =
            !_fallbackEllipseContains(px - 1, py, ww, hh) ||
            !_fallbackEllipseContains(px + 1, py, ww, hh) ||
            !_fallbackEllipseContains(px, py - 1, ww, hh) ||
            !_fallbackEllipseContains(px, py + 1, ww, hh);
        if (isEdge) {
          pset(x0 + px, y0 + py, col);
        }
      }
    }
  }

  void tri(num x1, num y1, num x2, num y2, num x3, num y3, int col) {
    if (_isScreen) {
      _screenTri(x1, y1, x2, y2, x3, y3, col);
      return;
    }
    final ax = x1.round();
    final ay = y1.round();
    final bx = x2.round();
    final by = y2.round();
    final cx = x3.round();
    final cy = y3.round();
    final minX = [ax, bx, cx].reduce(math.min);
    final maxX = [ax, bx, cx].reduce(math.max);
    final minY = [ay, by, cy].reduce(math.min);
    final maxY = [ay, by, cy].reduce(math.max);

    int edge(int sx, int sy, int ex, int ey, int px, int py) {
      return (px - sx) * (ey - sy) - (py - sy) * (ex - sx);
    }

    for (var py = minY; py <= maxY; py++) {
      for (var px = minX; px <= maxX; px++) {
        final w1 = edge(ax, ay, bx, by, px, py);
        final w2 = edge(bx, by, cx, cy, px, py);
        final w3 = edge(cx, cy, ax, ay, px, py);
        final allNonNegative = w1 >= 0 && w2 >= 0 && w3 >= 0;
        final allNonPositive = w1 <= 0 && w2 <= 0 && w3 <= 0;
        if (allNonNegative || allNonPositive) {
          pset(px, py, col);
        }
      }
    }
  }

  void trib(num x1, num y1, num x2, num y2, num x3, num y3, int col) {
    if (_isScreen) {
      _screenTrib(x1, y1, x2, y2, x3, y3, col);
      return;
    }
    line(x1, y1, x2, y2, col);
    line(x2, y2, x3, y3, col);
    line(x3, y3, x1, y1, col);
  }

  void fill(num x, num y, int col) {
    if (_isScreen) {
      _screenFill(x, y, col);
      return;
    }
    final sx = x.round() - _cameraX;
    final sy = y.round() - _cameraY;
    if (sx < 0 ||
        sy < 0 ||
        sx >= width ||
        sy >= height ||
        !_inLocalClip(sx, sy)) {
      return;
    }
    final target = _getLocalPixel(sx, sy);
    if (target == col) {
      return;
    }

    final stack = <int>[sx, sy];
    while (stack.isNotEmpty) {
      final cy = stack.removeLast();
      final cx = stack.removeLast();
      if (cx < 0 ||
          cy < 0 ||
          cx >= width ||
          cy >= height ||
          !_inLocalClip(cx, cy)) {
        continue;
      }
      if (_getLocalPixel(cx, cy) != target) {
        continue;
      }
      _setLocalPixel(cx, cy, col);
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

  void blt(
    num x,
    num y,
    Object img,
    num u,
    num v,
    num w,
    num h, {
    int? colkey,
    double? rotate,
    double? scale,
  }) {
    if (_isScreen) {
      _screenBlt(
        x,
        y,
        img,
        u,
        v,
        w,
        h,
        colkey: colkey,
        rotate: rotate,
        scale: scale,
      );
      return;
    }

    final srcPixelAt = switch (img) {
      int imageId => (int sx, int sy) => _fallbackGetImagePixel(
        imageId,
        sx,
        sy,
      ),
      Image source => (int sx, int sy) => source._getLocalPixel(sx, sy),
      _ => throw UnsupportedError(
        'image.blt img supports int id or Image source.',
      ),
    };

    final widthPixels = w.abs().round();
    final heightPixels = h.abs().round();
    if (widthPixels <= 0 || heightPixels <= 0) {
      return;
    }
    final dstX = x.round();
    final dstY = y.round();
    final srcX = u.round();
    final srcY = v.round();
    final flipX = w < 0;
    final flipY = h < 0;

    final sampled = List<int>.filled(
      widthPixels * heightPixels,
      0,
      growable: false,
    );
    for (var dy = 0; dy < heightPixels; dy++) {
      for (var dx = 0; dx < widthPixels; dx++) {
        final sx = srcX + (flipX ? (widthPixels - 1 - dx) : dx);
        final sy = srcY + (flipY ? (heightPixels - 1 - dy) : dy);
        sampled[dy * widthPixels + dx] = srcPixelAt(sx, sy);
      }
    }

    for (var dy = 0; dy < heightPixels; dy++) {
      for (var dx = 0; dx < widthPixels; dx++) {
        final value = sampled[dy * widthPixels + dx];
        if (colkey != null && value == colkey) {
          continue;
        }
        pset(dstX + dx, dstY + dy, value);
      }
    }
  }

  void bltm(
    num x,
    num y,
    Object tm,
    num u,
    num v,
    num w,
    num h, {
    int? colkey,
    double? rotate,
    double? scale,
  }) {
    if (_isScreen) {
      _screenBltm(
        x,
        y,
        tm,
        u,
        v,
        w,
        h,
        colkey: colkey,
        rotate: rotate,
        scale: scale,
      );
      return;
    }

    final srcTileAt = switch (tm) {
      int tilemapId => (int tx, int ty) => _fallbackGetTile(tilemapId, tx, ty),
      Tilemap source => (int tx, int ty) => source._readTileRaw(tx, ty),
      _ => throw UnsupportedError(
        'image.bltm tm supports int id or Tilemap source.',
      ),
    };
    final srcImage = switch (tm) {
      int tilemapId => _fallbackEnsureTilemap(tilemapId).imgsrc,
      Tilemap source => source.imgsrc,
      _ => 0,
    };

    int imagePixel(int tileX, int tileY, int px, int py) {
      final imageX = tileX * TILE_SIZE + px;
      final imageY = tileY * TILE_SIZE + py;
      return switch (srcImage) {
        int imageId => _fallbackGetImagePixel(imageId, imageX, imageY),
        Image source => source._getLocalPixel(imageX, imageY),
        _ => 0,
      };
    }

    final widthTiles = w.abs().round();
    final heightTiles = h.abs().round();
    if (widthTiles <= 0 || heightTiles <= 0) {
      return;
    }
    final dstX = x.round();
    final dstY = y.round();
    final srcX = u.round();
    final srcY = v.round();
    final flipX = w < 0;
    final flipY = h < 0;

    for (var tileDy = 0; tileDy < heightTiles; tileDy++) {
      for (var tileDx = 0; tileDx < widthTiles; tileDx++) {
        final tileX = srcX + (flipX ? (widthTiles - 1 - tileDx) : tileDx);
        final tileY = srcY + (flipY ? (heightTiles - 1 - tileDy) : tileDy);
        final tile = srcTileAt(tileX, tileY);
        for (var py = 0; py < TILE_SIZE; py++) {
          for (var px = 0; px < TILE_SIZE; px++) {
            final value = imagePixel(tile.$1, tile.$2, px, py);
            if (colkey != null && value == colkey) {
              continue;
            }
            pset(
              dstX + tileDx * TILE_SIZE + px,
              dstY + tileDy * TILE_SIZE + py,
              value,
            );
          }
        }
      }
    }
  }

  void text(num x, num y, String s, int col, [Font? font]) {
    if (_isScreen) {
      _screenText(x, y, s, col);
    }
  }
}

class Tilemap {
  Tilemap(this.width, this.height, this.imgsrc)
    : _tilemapId = null,
      _detachedData = List<int>.filled(width * height * 2, 0, growable: false),
      _clipX = 0,
      _clipY = 0,
      _clipW = width,
      _clipH = height,
      _cameraX = 0,
      _cameraY = 0,
      _dataPtrCache = null,
      _dataPtrCacheLength = 0;

  Tilemap._resource(int tilemapId)
    : width = TILEMAP_SIZE,
      height = TILEMAP_SIZE,
      imgsrc = 0,
      _tilemapId = tilemapId,
      _detachedData = null,
      _clipX = 0,
      _clipY = 0,
      _clipW = TILEMAP_SIZE,
      _clipH = TILEMAP_SIZE,
      _cameraX = 0,
      _cameraY = 0,
      _dataPtrCache = null,
      _dataPtrCacheLength = 0;

  final int width;
  final int height;
  Object imgsrc;
  final int? _tilemapId;
  final List<int>? _detachedData;
  int _clipX;
  int _clipY;
  int _clipW;
  int _clipH;
  int _cameraX;
  int _cameraY;
  ffi.Pointer<ffi.Uint8>? _dataPtrCache;
  int _dataPtrCacheLength;

  int? _resourceTilemapId() => _tilemapId;

  static Tilemap from_tmx(String filename, int layer) {
    return fromTmx(filename, layer);
  }

  static Tilemap fromTmx(String filename, int layer) {
    final file = File(filename);
    if (!file.existsSync()) {
      throw FormatException("Failed to open file '$filename'");
    }
    final parsed = _parseTmxLayer(file.readAsStringSync(), layer);
    final tilemap = Tilemap(parsed.width, parsed.height, 0);
    for (var i = 0; i < parsed.gids.length; i++) {
      final x = i % parsed.width;
      final y = i ~/ parsed.width;
      final gid = parsed.gids[i];
      final tileId = gid > parsed.tilesetFirstGid
          ? gid - parsed.tilesetFirstGid
          : 0;
      final tileX = tileId % parsed.tilesetColumns;
      final tileY = tileId ~/ parsed.tilesetColumns;
      tilemap._writeTileRaw(x, y, (tileX, tileY));
    }
    return tilemap;
  }

  ffi.Pointer<ffi.Void> data_ptr() {
    final data = switch ((_tilemapId, _detachedData)) {
      (int tilemapId, _) => _fallbackEnsureTilemap(tilemapId).data,
      (_, List<int> detached) => detached,
      _ => const <int>[],
    };
    final length = data.length;
    if (length <= 0) {
      return ffi.nullptr.cast<ffi.Void>();
    }
    _ensureDataPtrCapacity(length);
    final pointer = _dataPtrCache;
    if (pointer == null) {
      return ffi.nullptr.cast<ffi.Void>();
    }
    final view = pointer.asTypedList(length);
    for (var i = 0; i < length; i++) {
      view[i] = data[i] & 0xFF;
    }
    return pointer.cast<ffi.Void>();
  }

  void _ensureDataPtrCapacity(int length) {
    if (_dataPtrCache != null && _dataPtrCacheLength == length) {
      return;
    }
    if (_dataPtrCache != null) {
      _nativeBufferFinalizer.detach(this);
      calloc.free(_dataPtrCache!);
      _dataPtrCache = null;
      _dataPtrCacheLength = 0;
    }
    final buffer = calloc<ffi.Uint8>(length);
    _dataPtrCache = buffer;
    _dataPtrCacheLength = length;
    _nativeBufferFinalizer.attach(this, buffer.cast<ffi.Void>(), detach: this);
  }

  void set(int x, int y, List<String> data) {
    for (var row = 0; row < data.length; row++) {
      final line = data[row].replaceAll(RegExp(r'\s+'), '').toLowerCase();
      final numTiles = line.length ~/ 4;
      for (var col = 0; col < numTiles; col++) {
        final index = col * 4;
        final chunk = line.substring(index, index + 4);
        final tile = int.tryParse(chunk, radix: 16);
        if (tile == null) {
          continue;
        }
        pset(x + col, y + row, ((tile >> 8) & 0xff, tile & 0xff));
      }
    }
  }

  void load(int x, int y, String filename, int layer) {
    final tilemap = Tilemap.fromTmx(filename, layer);
    blt(x, y, tilemap, 0, 0, tilemap.width, tilemap.height);
  }

  void clip([num? x, num? y, num? w, num? h]) {
    if (x == null && y == null && w == null && h == null) {
      _clipX = 0;
      _clipY = 0;
      _clipW = width;
      _clipH = height;
      return;
    }

    final clipX = (x ?? 0).round();
    final clipY = (y ?? 0).round();
    final clipW = math.max(0, (w ?? width).round());
    final clipH = math.max(0, (h ?? height).round());

    var x0 = clipX.clamp(0, width).toInt();
    var y0 = clipY.clamp(0, height).toInt();
    var x1 = (clipX + clipW).clamp(0, width).toInt();
    var y1 = (clipY + clipH).clamp(0, height).toInt();
    if (x1 < x0) {
      x1 = x0;
    }
    if (y1 < y0) {
      y1 = y0;
    }

    _clipX = x0;
    _clipY = y0;
    _clipW = x1 - x0;
    _clipH = y1 - y0;
  }

  void camera([num? x, num? y]) {
    _cameraX = (x ?? 0).round();
    _cameraY = (y ?? 0).round();
  }

  bool _inClipRect(int x, int y) {
    if (_clipW <= 0 || _clipH <= 0) {
      return false;
    }
    return x >= _clipX &&
        y >= _clipY &&
        x < _clipX + _clipW &&
        y < _clipY + _clipH;
  }

  (int, int) _readTileRaw(int x, int y) {
    if (_tilemapId != null) {
      return _fallbackGetTile(_tilemapId, x, y);
    }
    final data = _detachedData;
    if (data == null || x < 0 || y < 0 || x >= width || y >= height) {
      return (0, 0);
    }
    final pairIndex = (y * width + x) * 2;
    if (pairIndex + 1 >= data.length) {
      return (0, 0);
    }
    return (data[pairIndex], data[pairIndex + 1]);
  }

  void _writeTileRaw(int x, int y, (int, int) tile) {
    if (_tilemapId != null) {
      _fallbackSetTile(_tilemapId, x, y, tile.$1, tile.$2);
      return;
    }
    final data = _detachedData;
    if (data == null || x < 0 || y < 0 || x >= width || y >= height) {
      return;
    }
    final pairIndex = (y * width + x) * 2;
    if (pairIndex + 1 >= data.length) {
      return;
    }
    data[pairIndex] = tile.$1;
    data[pairIndex + 1] = tile.$2;
  }

  void cls((int, int) tile) {
    if (_tilemapId != null) {
      final tilemap = _fallbackEnsureTilemap(_tilemapId);
      for (var y = 0; y < tilemap.height; y++) {
        for (var x = 0; x < tilemap.width; x++) {
          _fallbackSetTile(_tilemapId, x, y, tile.$1, tile.$2);
        }
      }
      return;
    }
    final data = _detachedData;
    if (data == null) {
      return;
    }
    for (var i = 0; i < data.length ~/ 2; i++) {
      data[i * 2] = tile.$1;
      data[i * 2 + 1] = tile.$2;
    }
  }

  (int, int) pget(num x, num y) {
    final xi = x.round();
    final yi = y.round();
    if (!_inClipRect(xi, yi)) {
      return (0, 0);
    }
    return _readTileRaw(xi, yi);
  }

  void pset(num x, num y, (int, int) tile) {
    final xi = x.round() - _cameraX;
    final yi = y.round() - _cameraY;
    if (!_inClipRect(xi, yi)) {
      return;
    }
    _writeTileRaw(xi, yi, tile);
  }

  void line(num x1, num y1, num x2, num y2, (int, int) tile) {
    var cx = x1.round();
    var cy = y1.round();
    final tx = x2.round();
    final ty = y2.round();
    final dx = (tx - cx).abs();
    final sx = cx < tx ? 1 : -1;
    final dy = -(ty - cy).abs();
    final sy = cy < ty ? 1 : -1;
    var err = dx + dy;
    while (true) {
      pset(cx, cy, tile);
      if (cx == tx && cy == ty) {
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

  void rect(num x, num y, num w, num h, (int, int) tile) {
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = y0; py < y0 + hh; py++) {
      for (var px = x0; px < x0 + ww; px++) {
        pset(px, py, tile);
      }
    }
  }

  void rectb(num x, num y, num w, num h, (int, int) tile) {
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    final right = x0 + ww - 1;
    final bottom = y0 + hh - 1;
    for (var px = x0; px <= right; px++) {
      pset(px, y0, tile);
      pset(px, bottom, tile);
    }
    for (var py = y0 + 1; py < bottom; py++) {
      pset(x0, py, tile);
      pset(right, py, tile);
    }
  }

  void circ(num x, num y, num r, (int, int) tile) {
    final cx = x.round();
    final cy = y.round();
    final rr = r.round();
    if (rr < 0) {
      return;
    }
    final rSq = rr * rr;
    for (var dy = -rr; dy <= rr; dy++) {
      final remain = rSq - dy * dy;
      final maxDx = math.sqrt(remain).floor();
      for (var dx = -maxDx; dx <= maxDx; dx++) {
        pset(cx + dx, cy + dy, tile);
      }
    }
  }

  void circb(num x, num y, num r, (int, int) tile) {
    final cx = x.round();
    final cy = y.round();
    final rr = r.round();
    if (rr < 0) {
      return;
    }
    var px = rr;
    var py = 0;
    var err = 1 - px;
    while (px >= py) {
      pset(cx + px, cy + py, tile);
      pset(cx - px, cy + py, tile);
      pset(cx + px, cy - py, tile);
      pset(cx - px, cy - py, tile);
      pset(cx + py, cy + px, tile);
      pset(cx - py, cy + px, tile);
      pset(cx + py, cy - px, tile);
      pset(cx - py, cy - px, tile);
      py += 1;
      if (err < 0) {
        err += 2 * py + 1;
      } else {
        px -= 1;
        err += 2 * (py - px + 1);
      }
    }
  }

  void elli(num x, num y, num w, num h, (int, int) tile) {
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = 0; py < hh; py++) {
      for (var px = 0; px < ww; px++) {
        if (_fallbackEllipseContains(px, py, ww, hh)) {
          pset(x0 + px, y0 + py, tile);
        }
      }
    }
  }

  void ellib(num x, num y, num w, num h, (int, int) tile) {
    final x0 = x.round();
    final y0 = y.round();
    final ww = w.round();
    final hh = h.round();
    if (ww <= 0 || hh <= 0) {
      return;
    }
    for (var py = 0; py < hh; py++) {
      for (var px = 0; px < ww; px++) {
        if (!_fallbackEllipseContains(px, py, ww, hh)) {
          continue;
        }
        final isEdge =
            !_fallbackEllipseContains(px - 1, py, ww, hh) ||
            !_fallbackEllipseContains(px + 1, py, ww, hh) ||
            !_fallbackEllipseContains(px, py - 1, ww, hh) ||
            !_fallbackEllipseContains(px, py + 1, ww, hh);
        if (isEdge) {
          pset(x0 + px, y0 + py, tile);
        }
      }
    }
  }

  void tri(num x1, num y1, num x2, num y2, num x3, num y3, (int, int) tile) {
    final ax = x1.round();
    final ay = y1.round();
    final bx = x2.round();
    final by = y2.round();
    final cx = x3.round();
    final cy = y3.round();
    final minX = [ax, bx, cx].reduce(math.min);
    final maxX = [ax, bx, cx].reduce(math.max);
    final minY = [ay, by, cy].reduce(math.min);
    final maxY = [ay, by, cy].reduce(math.max);

    int edge(int sx, int sy, int ex, int ey, int px, int py) {
      return (px - sx) * (ey - sy) - (py - sy) * (ex - sx);
    }

    for (var py = minY; py <= maxY; py++) {
      for (var px = minX; px <= maxX; px++) {
        final w1 = edge(ax, ay, bx, by, px, py);
        final w2 = edge(bx, by, cx, cy, px, py);
        final w3 = edge(cx, cy, ax, ay, px, py);
        final allNonNegative = w1 >= 0 && w2 >= 0 && w3 >= 0;
        final allNonPositive = w1 <= 0 && w2 <= 0 && w3 <= 0;
        if (allNonNegative || allNonPositive) {
          pset(px, py, tile);
        }
      }
    }
  }

  void trib(num x1, num y1, num x2, num y2, num x3, num y3, (int, int) tile) {
    line(x1, y1, x2, y2, tile);
    line(x2, y2, x3, y3, tile);
    line(x3, y3, x1, y1, tile);
  }

  void fill(num x, num y, (int, int) tile) {
    final sx = x.round();
    final sy = y.round();
    if (sx < 0 || sy < 0 || sx >= width || sy >= height) {
      return;
    }
    final target = pget(sx, sy);
    if (target == tile) {
      return;
    }

    final stack = <int>[sx, sy];
    while (stack.isNotEmpty) {
      final cy = stack.removeLast();
      final cx = stack.removeLast();
      if (cx < 0 || cy < 0 || cx >= width || cy >= height) {
        continue;
      }
      if (pget(cx, cy) != target) {
        continue;
      }
      pset(cx, cy, tile);
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

  (double, double) collide(
    num x,
    num y,
    num w,
    num h,
    num dx,
    num dy,
    List<(int, int)> walls,
  ) {
    if (walls.isEmpty) {
      return (dx.toDouble(), dy.toDouble());
    }
    final wallSet = walls.toSet();
    final originX = x.toDouble();
    final originY = y.toDouble();
    final widthPx = w.toDouble();
    final heightPx = h.toDouble();
    final tileSize = _fallbackTileSize.toDouble();

    bool isWall(int tx, int ty) {
      if (tx < 0 || ty < 0 || tx >= width || ty >= height) {
        return false;
      }
      return wallSet.contains(_readTileRaw(tx, ty));
    }

    double resolveX(double cx, double cy, double deltaX) {
      if (deltaX == 0.0) {
        return deltaX;
      }
      final ty0 = (cy / tileSize).floor();
      final ty1 = ((cy + heightPx - 1.0) / tileSize).floor();

      if (deltaX > 0.0) {
        final currentRight = cx + widthPx - 1.0;
        final nextRight = cx + deltaX + widthPx - 1.0;
        final startTx = (currentRight / tileSize).floor() + 1;
        final endTx = (nextRight / tileSize).floor();
        if (startTx <= endTx) {
          for (var tx = startTx; tx <= endTx; tx++) {
            for (var ty = ty0; ty <= ty1; ty++) {
              if (isWall(tx, ty)) {
                return tx * tileSize - widthPx - cx;
              }
            }
          }
        }
      } else {
        final currentLeft = cx;
        final nextLeft = cx + deltaX;
        final startTx = (currentLeft / tileSize).floor() - 1;
        final endTx = (nextLeft / tileSize).floor();
        if (startTx >= endTx) {
          for (var tx = startTx; tx >= endTx; tx--) {
            for (var ty = ty0; ty <= ty1; ty++) {
              if (isWall(tx, ty)) {
                return (tx + 1) * tileSize - cx;
              }
            }
          }
        }
      }
      return deltaX;
    }

    double resolveY(double cx, double cy, double deltaY) {
      if (deltaY == 0.0) {
        return deltaY;
      }
      final tx0 = (cx / tileSize).floor();
      final tx1 = ((cx + widthPx - 1.0) / tileSize).floor();

      if (deltaY > 0.0) {
        final currentBottom = cy + heightPx - 1.0;
        final nextBottom = cy + deltaY + heightPx - 1.0;
        final startTy = (currentBottom / tileSize).floor() + 1;
        final endTy = (nextBottom / tileSize).floor();
        if (startTy <= endTy) {
          for (var ty = startTy; ty <= endTy; ty++) {
            for (var tx = tx0; tx <= tx1; tx++) {
              if (isWall(tx, ty)) {
                return ty * tileSize - heightPx - cy;
              }
            }
          }
        }
      } else {
        final currentTop = cy;
        final nextTop = cy + deltaY;
        final startTy = (currentTop / tileSize).floor() - 1;
        final endTy = (nextTop / tileSize).floor();
        if (startTy >= endTy) {
          for (var ty = startTy; ty >= endTy; ty--) {
            for (var tx = tx0; tx <= tx1; tx++) {
              if (isWall(tx, ty)) {
                return (ty + 1) * tileSize - cy;
              }
            }
          }
        }
      }
      return deltaY;
    }

    var ndx = dx.toDouble();
    var ndy = dy.toDouble();
    if (ndx.abs() >= ndy.abs()) {
      ndx = resolveX(originX, originY, ndx);
      ndy = resolveY(originX + ndx, originY, ndy);
    } else {
      ndy = resolveY(originX, originY, ndy);
      ndx = resolveX(originX, originY + ndy, ndx);
    }
    return (ndx, ndy);
  }

  void blt(
    num x,
    num y,
    Object tm,
    num u,
    num v,
    num w,
    num h, {
    (int, int)? tilekey,
    double? rotate,
    double? scale,
  }) {
    final srcTileAt = switch (tm) {
      int tmId => (int tx, int ty) => _fallbackGetTile(tmId, tx, ty),
      Tilemap source => (int tx, int ty) => source._readTileRaw(tx, ty),
      _ => throw UnsupportedError(
        'tilemap.blt tm supports int id or Tilemap source.',
      ),
    };

    final widthTiles = w.abs().round();
    final heightTiles = h.abs().round();
    if (widthTiles <= 0 || heightTiles <= 0) {
      return;
    }
    final dstX = x.round();
    final dstY = y.round();
    final srcX = u.round();
    final srcY = v.round();
    final flipX = w < 0;
    final flipY = h < 0;

    for (var dy = 0; dy < heightTiles; dy++) {
      for (var dx = 0; dx < widthTiles; dx++) {
        final sx = srcX + (flipX ? (widthTiles - 1 - dx) : dx);
        final sy = srcY + (flipY ? (heightTiles - 1 - dy) : dy);
        final tile = srcTileAt(sx, sy);
        if (tilekey != null && tile == tilekey) {
          continue;
        }
        pset(dstX + dx, dstY + dy, tile);
      }
    }
  }
}

final List<Image> _imageResources = List<Image>.unmodifiable(
  List<Image>.generate(NUM_IMAGES, Image._resource, growable: false),
);
final List<Tilemap> _tilemapResources = List<Tilemap>.unmodifiable(
  List<Tilemap>.generate(NUM_TILEMAPS, Tilemap._resource, growable: false),
);

final Seq<int> colors = Seq<int>.proxy(() => _fallbackPaletteMap);
final Seq<Image> images = Seq<Image>.proxy(() => _imageResources);
final Seq<Tilemap> tilemaps = Seq<Tilemap>.proxy(() => _tilemapResources);
final Image screen = Image._screen();
final Image cursor = Image(8, 8);
final Image font = Image(FONT_WIDTH, FONT_HEIGHT);

class Channel {
  Channel._(this._channelIndex);

  final int _channelIndex;

  double gain = 0.125;
  int detune = 0;

  void play(Object snd, {double? sec, bool? loop, bool? resume}) {
    _playImpl(_channelIndex, snd, sec: sec, loop: loop, resume: resume);
  }

  void stop() {
    _stopImpl(_channelIndex);
  }

  ({int snd, double pos})? play_pos() {
    return _playPosImpl(_channelIndex);
  }

  ({int snd, double pos})? playPos() {
    return play_pos();
  }
}

final List<Channel> channels = List<Channel>.unmodifiable(
  List<Channel>.generate(NUM_CHANNELS, Channel._, growable: false),
);

String _simplifySoundString(String source) {
  return source.replaceAll(RegExp(r'[\s\t\r\n]+'), '').toLowerCase();
}

List<int> _parseSoundNotes(String notes) {
  final source = _simplifySoundString(notes);
  final parsed = <int>[];
  var i = 0;
  while (i < source.length) {
    final c = source[i];
    if (c == 'r') {
      parsed.add(-1);
      i += 1;
      continue;
    }

    int? base;
    switch (c) {
      case 'c':
        base = 0;
      case 'd':
        base = 2;
      case 'e':
        base = 4;
      case 'f':
        base = 5;
      case 'g':
        base = 7;
      case 'a':
        base = 9;
      case 'b':
        base = 11;
      default:
        throw FormatException("Invalid sound note '$c'.");
    }
    i += 1;

    if (i < source.length) {
      final accidental = source[i];
      if (accidental == '#') {
        base += 1;
        i += 1;
      } else if (accidental == '-') {
        base -= 1;
        i += 1;
      }
    }

    if (i >= source.length) {
      throw const FormatException('Invalid sound note: missing octave.');
    }
    final octave = source.codeUnitAt(i) - 0x30;
    if (octave < 0 || octave > 4) {
      throw FormatException("Invalid sound note '${source[i]}'.");
    }
    i += 1;
    parsed.add(base + octave * 12);
  }
  return parsed;
}

List<int> _parseSoundTones(String tones) {
  final source = _simplifySoundString(tones);
  final parsed = <int>[];
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    switch (c) {
      case 't':
        parsed.add(TONE_TRIANGLE);
      case 's':
        parsed.add(TONE_SQUARE);
      case 'p':
        parsed.add(TONE_PULSE);
      case 'n':
        parsed.add(TONE_NOISE);
      default:
        final digit = int.tryParse(c);
        if (digit == null) {
          throw FormatException("Invalid sound tone '$c'.");
        }
        parsed.add(digit);
    }
  }
  return parsed;
}

List<int> _parseSoundVolumes(String volumes) {
  final source = _simplifySoundString(volumes);
  final parsed = <int>[];
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    final digit = int.tryParse(c);
    if (digit == null || digit < 0 || digit > 7) {
      throw FormatException("Invalid sound volume '$c'.");
    }
    parsed.add(digit);
  }
  return parsed;
}

List<int> _parseSoundEffects(String effects) {
  final source = _simplifySoundString(effects);
  final parsed = <int>[];
  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    switch (c) {
      case 'n':
        parsed.add(EFFECT_NONE);
      case 's':
        parsed.add(EFFECT_SLIDE);
      case 'v':
        parsed.add(EFFECT_VIBRATO);
      case 'f':
        parsed.add(EFFECT_FADEOUT);
      case 'h':
        parsed.add(EFFECT_HALF_FADEOUT);
      case 'q':
        parsed.add(EFFECT_QUARTER_FADEOUT);
      default:
        throw FormatException("Invalid sound effect '$c'.");
    }
  }
  return parsed;
}

const int _mmlAudioClockRate = 1789773;
const int _mmlTicksPerQuarterNote = 48;
const int _mmlDefaultTempo = 120;
const int _mmlDefaultOctave = 4;
const int _mmlDefaultLength = 4;
const int _soundTicksPerSecond = 120;
const int _fallbackAudioSampleRate = 22050;

sealed class _MmlEvent {
  const _MmlEvent();
}

class _MmlTempoEvent extends _MmlEvent {
  const _MmlTempoEvent(this.bpm);
  final int bpm;
}

class _MmlDurationEvent extends _MmlEvent {
  const _MmlDurationEvent(this.ticks);
  final int ticks;
}

class _MmlRepeatStartEvent extends _MmlEvent {
  const _MmlRepeatStartEvent();
}

class _MmlRepeatEndEvent extends _MmlEvent {
  const _MmlRepeatEndEvent(this.playCount);
  final int playCount;
}

class _MmlCharStream {
  _MmlCharStream(this.source);

  final String source;
  int pos = 0;

  bool get isEof => pos >= source.length;

  String error(String message) => 'MML:$pos: $message';

  String? peek() => isEof ? null : source[pos];

  String? next() {
    if (isEof) {
      return null;
    }
    final value = source[pos];
    pos += 1;
    return value;
  }

  void skipWhitespace() {
    while (!isEof) {
      final c = source[pos];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        pos += 1;
      } else {
        break;
      }
    }
  }

  bool consumeChar(String c) {
    skipWhitespace();
    if (!isEof && source[pos] == c) {
      pos += 1;
      return true;
    }
    return false;
  }

  bool consumeStringIgnoreCase(String text) {
    skipWhitespace();
    if (pos + text.length > source.length) {
      return false;
    }
    for (var i = 0; i < text.length; i++) {
      final actual = source[pos + i].toLowerCase();
      final expected = text[i].toLowerCase();
      if (actual != expected) {
        return false;
      }
    }
    pos += text.length;
    return true;
  }

  int parseRequiredInt(String name, {int? min, int? max}) {
    skipWhitespace();
    final start = pos;
    var sign = 1;
    if (!isEof && source[pos] == '-') {
      sign = -1;
      pos += 1;
    }
    final digitsStart = pos;
    while (!isEof) {
      final unit = source.codeUnitAt(pos);
      if (unit >= 0x30 && unit <= 0x39) {
        pos += 1;
      } else {
        break;
      }
    }
    if (digitsStart == pos) {
      pos = start;
      final found = isEof ? '<eof>' : source[pos];
      throw FormatException(
        error("Expected value for '$name' but found '$found'"),
      );
    }
    final value = sign * int.parse(source.substring(digitsStart, pos));
    if (min != null && value < min) {
      throw FormatException(error("'$name' is below minimum $min"));
    }
    if (max != null && value > max) {
      throw FormatException(error("'$name' exceeds maximum $max"));
    }
    return value;
  }

  int? parseOptionalUnsignedInt() {
    skipWhitespace();
    final start = pos;
    while (!isEof) {
      final unit = source.codeUnitAt(pos);
      if (unit >= 0x30 && unit <= 0x39) {
        pos += 1;
      } else {
        break;
      }
    }
    if (start == pos) {
      return null;
    }
    return int.parse(source.substring(start, pos));
  }
}

int _bpmToMmlClocksPerTick(int bpm) {
  return ((_mmlAudioClockRate * 60) / (bpm * _mmlTicksPerQuarterNote)).round();
}

int _parseMmlLengthAsTicks(_MmlCharStream stream, int currentNoteTicks) {
  const wholeNoteTicks = _mmlTicksPerQuarterNote * 4;
  var noteTicks = currentNoteTicks;
  final length = stream.parseOptionalUnsignedInt();
  if (length != null) {
    if (length <= 0 || wholeNoteTicks % length != 0) {
      throw FormatException(stream.error("Invalid note length '$length'"));
    }
    noteTicks = wholeNoteTicks ~/ length;
  }
  var dotTicks = noteTicks;
  while (stream.consumeChar('.')) {
    if (dotTicks.isOdd) {
      throw FormatException(
        stream.error('Cannot apply dot to odd note length'),
      );
    }
    dotTicks ~/= 2;
    noteTicks += dotTicks;
  }
  return noteTicks;
}

bool _looksLikeOldMml(String code) => RegExp(r'[xX~]').hasMatch(code);

List<_MmlEvent> _parseMmlEvents(String code, {bool oldSyntax = false}) {
  final stream = _MmlCharStream(code);
  final events = <_MmlEvent>[];
  var octave = _mmlDefaultOctave;
  var noteTicks = (_mmlTicksPerQuarterNote * 4) ~/ _mmlDefaultLength;

  while (true) {
    stream.skipWhitespace();
    if (stream.isEof) {
      break;
    }

    if (stream.consumeChar('[')) {
      events.add(const _MmlRepeatStartEvent());
      continue;
    }
    if (stream.consumeChar(']')) {
      final playCount = stream.parseOptionalUnsignedInt() ?? 0;
      events.add(_MmlRepeatEndEvent(playCount));
      continue;
    }
    if (stream.consumeStringIgnoreCase('T')) {
      final bpm = stream.parseRequiredInt('bpm', min: 1);
      events.add(_MmlTempoEvent(bpm));
      continue;
    }
    if (stream.consumeStringIgnoreCase('Q')) {
      stream.parseRequiredInt('gate_percent', min: 0, max: 100);
      continue;
    }
    if (stream.consumeStringIgnoreCase('V')) {
      stream.parseRequiredInt('vol', min: 0, max: 127);
      continue;
    }
    if (stream.consumeStringIgnoreCase('K')) {
      stream.parseRequiredInt('key_offset');
      continue;
    }
    if (stream.consumeStringIgnoreCase('Y')) {
      stream.parseRequiredInt('offset_cents');
      continue;
    }
    if (stream.consumeStringIgnoreCase('@ENV')) {
      stream.parseRequiredInt('slot', min: 0);
      if (stream.consumeChar('{')) {
        var depth = 1;
        while (!stream.isEof && depth > 0) {
          final c = stream.next();
          if (c == '{') {
            depth += 1;
          } else if (c == '}') {
            depth -= 1;
          }
        }
        if (depth != 0) {
          throw FormatException(stream.error("Expected '}'"));
        }
      }
      continue;
    }
    if (stream.consumeStringIgnoreCase('@VIB')) {
      stream.parseRequiredInt('slot', min: 0);
      if (stream.consumeChar('{')) {
        var depth = 1;
        while (!stream.isEof && depth > 0) {
          final c = stream.next();
          if (c == '{') {
            depth += 1;
          } else if (c == '}') {
            depth -= 1;
          }
        }
        if (depth != 0) {
          throw FormatException(stream.error("Expected '}'"));
        }
      }
      continue;
    }
    if (stream.consumeStringIgnoreCase('@GLI')) {
      stream.parseRequiredInt('slot', min: 0);
      if (stream.consumeChar('{')) {
        var depth = 1;
        while (!stream.isEof && depth > 0) {
          final c = stream.next();
          if (c == '{') {
            depth += 1;
          } else if (c == '}') {
            depth -= 1;
          }
        }
        if (depth != 0) {
          throw FormatException(stream.error("Expected '}'"));
        }
      }
      continue;
    }
    if (stream.consumeStringIgnoreCase('@')) {
      stream.parseRequiredInt('tone', min: 0);
      continue;
    }
    if (oldSyntax && stream.consumeStringIgnoreCase('X')) {
      stream.parseRequiredInt('tone', min: 0);
      continue;
    }
    if (stream.consumeStringIgnoreCase('O')) {
      octave = stream.parseRequiredInt('oct', min: -1, max: 9);
      continue;
    }
    if (stream.consumeChar('>')) {
      if (octave >= 9) {
        throw FormatException(stream.error('Octave exceeds maximum $octave'));
      }
      octave += 1;
      continue;
    }
    if (stream.consumeChar('<')) {
      if (octave <= -1) {
        throw FormatException(stream.error('Octave is below minimum $octave'));
      }
      octave -= 1;
      continue;
    }
    if (stream.consumeStringIgnoreCase('L')) {
      noteTicks = _parseMmlLengthAsTicks(stream, noteTicks);
      continue;
    }

    stream.skipWhitespace();
    final head = stream.peek()?.toLowerCase();
    if (head == null) {
      break;
    }

    const noteLetters = <String>{'c', 'd', 'e', 'f', 'g', 'a', 'b'};
    if (noteLetters.contains(head)) {
      stream.next();
      final accidental = stream.peek();
      if (accidental == '#' || accidental == '+' || accidental == '-') {
        stream.next();
      }
      var durationTicks = _parseMmlLengthAsTicks(stream, noteTicks);
      while (stream.consumeChar('&') ||
          (oldSyntax && stream.consumeChar('~'))) {
        stream.skipWhitespace();
        final next = stream.peek();
        if (next != null) {
          final unit = next.codeUnitAt(0);
          final isDigit = unit >= 0x30 && unit <= 0x39;
          if (isDigit) {
            durationTicks += _parseMmlLengthAsTicks(stream, noteTicks);
            continue;
          }
        }
        break;
      }
      events.add(_MmlDurationEvent(durationTicks));
      continue;
    }

    if (head == 'r') {
      stream.next();
      var durationTicks = _parseMmlLengthAsTicks(stream, noteTicks);
      while (stream.consumeChar('&') ||
          (oldSyntax && stream.consumeChar('~'))) {
        durationTicks += _parseMmlLengthAsTicks(stream, noteTicks);
      }
      events.add(_MmlDurationEvent(durationTicks));
      continue;
    }

    throw FormatException(stream.error("Unexpected character '$head'"));
  }
  return events;
}

double? _calcMmlDurationSec(String code, {bool oldSyntax = false}) {
  final events = _parseMmlEvents(code, oldSyntax: oldSyntax);
  var clocksPerTick = _bpmToMmlClocksPerTick(_mmlDefaultTempo);
  var totalClocks = 0;
  final repeatPoints = <(int, int)>[];
  var index = 0;
  while (index < events.length) {
    final event = events[index];
    index += 1;
    switch (event) {
      case _MmlTempoEvent(:final bpm):
        clocksPerTick = _bpmToMmlClocksPerTick(bpm);
      case _MmlDurationEvent(:final ticks):
        totalClocks += clocksPerTick * ticks;
      case _MmlRepeatStartEvent():
        repeatPoints.add((index, 0));
      case _MmlRepeatEndEvent(:final playCount):
        if (playCount == 0) {
          return null;
        }
        if (repeatPoints.isNotEmpty) {
          final point = repeatPoints.removeLast();
          if (point.$2 + 1 < playCount) {
            repeatPoints.add((point.$1, point.$2 + 1));
            index = point.$1;
          }
        }
    }
  }
  return totalClocks / _mmlAudioClockRate;
}

bool _matchAscii(List<int> bytes, int offset, String token) {
  if (offset < 0 || offset + token.length > bytes.length) {
    return false;
  }
  for (var i = 0; i < token.length; i++) {
    if (bytes[offset + i] != token.codeUnitAt(i)) {
      return false;
    }
  }
  return true;
}

int _readU16Le(List<int> bytes, int offset) {
  return bytes[offset] | (bytes[offset + 1] << 8);
}

int _readU32Le(List<int> bytes, int offset) {
  return bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);
}

bool _commandExists(String command) {
  try {
    final result = Platform.isWindows
        ? Process.runSync('where', <String>[command], runInShell: true)
        : Process.runSync('sh', <String>['-lc', 'command -v $command']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

double _loadWavDurationSec(String filename) {
  final bytes = File(filename).readAsBytesSync();
  if (bytes.length < 44 ||
      !_matchAscii(bytes, 0, 'RIFF') ||
      !_matchAscii(bytes, 8, 'WAVE')) {
    throw FormatException('Unsupported PCM file format: expected RIFF WAVE.');
  }

  int? audioFormat;
  int? channelCount;
  int? sampleRate;
  int? bitsPerSample;
  int? dataSize;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkSize = _readU32Le(bytes, offset + 4);
    final chunkDataOffset = offset + 8;
    final chunkEnd = chunkDataOffset + chunkSize;
    if (chunkEnd > bytes.length) {
      throw const FormatException('Invalid WAV: chunk exceeds file length.');
    }

    if (_matchAscii(bytes, offset, 'fmt ')) {
      if (chunkSize < 16) {
        throw const FormatException('Invalid WAV: fmt chunk is too small.');
      }
      audioFormat = _readU16Le(bytes, chunkDataOffset);
      channelCount = _readU16Le(bytes, chunkDataOffset + 2);
      sampleRate = _readU32Le(bytes, chunkDataOffset + 4);
      bitsPerSample = _readU16Le(bytes, chunkDataOffset + 14);
    } else if (_matchAscii(bytes, offset, 'data')) {
      dataSize = chunkSize;
    }

    offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
  }

  if (audioFormat != 1) {
    throw const FormatException('Unsupported WAV format: only PCM is allowed.');
  }
  if (channelCount == null ||
      channelCount <= 0 ||
      sampleRate == null ||
      sampleRate <= 0 ||
      bitsPerSample == null ||
      bitsPerSample <= 0 ||
      bitsPerSample % 8 != 0 ||
      dataSize == null) {
    throw const FormatException('Invalid WAV metadata.');
  }

  final bytesPerFrame = channelCount * (bitsPerSample ~/ 8);
  if (bytesPerFrame <= 0) {
    throw const FormatException('Invalid WAV frame layout.');
  }
  final frameCount = dataSize ~/ bytesPerFrame;
  return frameCount / sampleRate;
}

double? _probeAudioDurationWithFfprobe(String filename) {
  if (!_commandExists('ffprobe')) {
    return null;
  }
  try {
    final result = Process.runSync('ffprobe', <String>[
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      filename,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = '${result.stdout}'.trim();
    final duration = double.tryParse(output);
    if (duration == null || !duration.isFinite || duration <= 0) {
      return null;
    }
    return duration;
  } catch (_) {
    return null;
  }
}

double? _probeAudioDurationWithFfmpegDecode(String filename) {
  if (!_commandExists('ffmpeg')) {
    return null;
  }
  final workDir = Directory.systemTemp.createTempSync(
    'flutterxel-audio-probe-',
  );
  try {
    final wavPath = '${workDir.path}${Platform.pathSeparator}decoded.wav';
    final result = Process.runSync('ffmpeg', <String>[
      '-y',
      '-v',
      'error',
      '-i',
      filename,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '22050',
      wavPath,
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    return _loadWavDurationSec(wavPath);
  } catch (_) {
    return null;
  } finally {
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }
  }
}

double _loadAudioDurationSec(String filename) {
  try {
    return _loadWavDurationSec(filename);
  } on FileSystemException {
    rethrow;
  } on FormatException {
    final probedDuration =
        _probeAudioDurationWithFfprobe(filename) ??
        _probeAudioDurationWithFfmpegDecode(filename);
    if (probedDuration != null) {
      return probedDuration;
    }
    rethrow;
  }
}

String _addFileExtension(String filename, String ext) {
  if (filename.toLowerCase().endsWith(ext.toLowerCase())) {
    return filename;
  }
  return '$filename$ext';
}

void _appendU16Le(BytesBuilder builder, int value) {
  builder.add(<int>[value & 0xFF, (value >> 8) & 0xFF]);
}

void _appendU32Le(BytesBuilder builder, int value) {
  builder.add(<int>[
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}

void _writeSilentPcm16Wav(String filename, double sec) {
  if (sec <= 0) {
    throw ArgumentError.value(sec, 'sec', 'must be greater than 0.');
  }

  const channels = 1;
  const bitsPerSample = 16;
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final byteRate = _fallbackAudioSampleRate * blockAlign;
  final sampleCount = (sec * _fallbackAudioSampleRate).round();
  final dataSize = sampleCount * blockAlign;
  final riffSize = 36 + dataSize;

  final builder = BytesBuilder(copy: false);
  builder.add('RIFF'.codeUnits);
  _appendU32Le(builder, riffSize);
  builder.add('WAVE'.codeUnits);
  builder.add('fmt '.codeUnits);
  _appendU32Le(builder, 16);
  _appendU16Le(builder, 1); // PCM
  _appendU16Le(builder, channels);
  _appendU32Le(builder, _fallbackAudioSampleRate);
  _appendU32Le(builder, byteRate);
  _appendU16Le(builder, blockAlign);
  _appendU16Le(builder, bitsPerSample);
  builder.add('data'.codeUnits);
  _appendU32Le(builder, dataSize);
  builder.add(Uint8List(dataSize));

  File(filename).writeAsBytesSync(builder.takeBytes(), flush: true);
}

void _saveAudioCapture(String filename, double sec, {bool ffmpeg = false}) {
  final wavPath = _addFileExtension(filename, '.wav');
  _writeSilentPcm16Wav(wavPath, sec);
  if (!ffmpeg) {
    return;
  }

  if (!_commandExists('ffmpeg')) {
    throw UnsupportedError('ffmpeg command is required when ffmpeg=true.');
  }

  final mp4Path = wavPath.toLowerCase().endsWith('.wav')
      ? '${wavPath.substring(0, wavPath.length - 4)}.mp4'
      : '$wavPath.mp4';
  final result = Process.runSync('ffmpeg', <String>[
    '-y',
    '-v',
    'error',
    '-f',
    'lavfi',
    '-i',
    'color=c=black:s=480x360',
    '-i',
    wavPath,
    '-c:v',
    'libx264',
    '-c:a',
    'aac',
    '-b:a',
    '192k',
    '-shortest',
    mp4Path,
  ]);
  if (result.exitCode != 0) {
    throw StateError('Failed to execute ffmpeg for audio capture.');
  }
}

class Tone {
  Tone() {
    wavetable = Seq<int>.proxy(() => _wavetableData);
    waveform = Seq<int>.proxy(() => _wavetableData);
  }

  int mode = TONE_TRIANGLE;
  int sample_bits = 4;
  final List<int> _wavetableData = List<int>.filled(32, 0, growable: false);
  late final Seq<int> wavetable;
  late final Seq<int> waveform;
  double gain = 1.0;
}

class Sound {
  Sound() : _soundId = null {
    notes = Seq<int>.proxy(() => _notesData);
    tones = Seq<int>.proxy(() => _tonesData);
    volumes = Seq<int>.proxy(() => _volumesData);
    effects = Seq<int>.proxy(() => _effectsData);
  }

  Sound._resource(int soundId) : _soundId = soundId {
    notes = Seq<int>.proxy(() => _notesData);
    tones = Seq<int>.proxy(() => _tonesData);
    volumes = Seq<int>.proxy(() => _volumesData);
    effects = Seq<int>.proxy(() => _effectsData);
  }

  final int? _soundId;
  final List<int> _notesData = <int>[];
  final List<int> _tonesData = <int>[];
  final List<int> _volumesData = <int>[];
  final List<int> _effectsData = <int>[];

  late final Seq<int> notes;
  late final Seq<int> tones;
  late final Seq<int> volumes;
  late final Seq<int> effects;
  int _speed = 30;
  int get speed => _speed;
  set speed(int value) {
    _speed = value;
    _syncSpeedToCore();
  }

  String? _mmlCode;
  double? _mmlDurationSec;
  double? _pcmDurationSec;

  bool _shouldSyncToCore() =>
      _soundId != null && _isInitialized && _getBindingsOrNull() != null;

  void _syncListToCore(
    List<int> values,
    String apiName,
    bool Function(FlutterxelBindings, int, ffi.Pointer<ffi.Int32>, int) invoke,
  ) {
    if (!_shouldSyncToCore()) {
      return;
    }
    final bindings = _getBindingsOrNull();
    final soundId = _soundId;
    if (bindings == null || soundId == null) {
      return;
    }

    ffi.Pointer<ffi.Int32> ptr = ffi.nullptr;
    try {
      if (values.isNotEmpty) {
        ptr = calloc<ffi.Int32>(values.length);
        for (var i = 0; i < values.length; i++) {
          ptr[i] = values[i];
        }
      }
      final ok = invoke(bindings, soundId, ptr, values.length);
      if (!ok) {
        throw StateError('$apiName failed.');
      }
    } finally {
      if (ptr != ffi.nullptr) {
        calloc.free(ptr);
      }
    }
  }

  void _syncSpeedToCore() {
    if (!_shouldSyncToCore()) {
      return;
    }
    final bindings = _getBindingsOrNull();
    final soundId = _soundId;
    if (bindings == null || soundId == null) {
      return;
    }
    final ok = bindings.flutterxel_core_sound_set_speed(soundId, _speed);
    if (!ok) {
      throw StateError('flutterxel_core_sound_set_speed failed.');
    }
  }

  void set(
    String notes,
    String tones,
    String volumes,
    String effects,
    int speed,
  ) {
    set_notes(notes);
    set_tones(tones);
    set_volumes(volumes);
    set_effects(effects);
    this.speed = speed;
  }

  void set_notes(String notes) {
    _notesData
      ..clear()
      ..addAll(_parseSoundNotes(notes));
    _syncListToCore(
      _notesData,
      'flutterxel_core_sound_set_notes',
      (bindings, soundId, ptr, len) =>
          bindings.flutterxel_core_sound_set_notes(soundId, ptr, len),
    );
  }

  void note(String notes) {
    set_notes(notes);
  }

  void set_tones(String tones) {
    _tonesData
      ..clear()
      ..addAll(_parseSoundTones(tones));
    _syncListToCore(
      _tonesData,
      'flutterxel_core_sound_set_tones',
      (bindings, soundId, ptr, len) =>
          bindings.flutterxel_core_sound_set_tones(soundId, ptr, len),
    );
  }

  void tone(String tones) {
    set_tones(tones);
  }

  void set_volumes(String volumes) {
    _volumesData
      ..clear()
      ..addAll(_parseSoundVolumes(volumes));
    _syncListToCore(
      _volumesData,
      'flutterxel_core_sound_set_volumes',
      (bindings, soundId, ptr, len) =>
          bindings.flutterxel_core_sound_set_volumes(soundId, ptr, len),
    );
  }

  void volume(String volumes) {
    set_volumes(volumes);
  }

  void set_effects(String effects) {
    _effectsData
      ..clear()
      ..addAll(_parseSoundEffects(effects));
    _syncListToCore(
      _effectsData,
      'flutterxel_core_sound_set_effects',
      (bindings, soundId, ptr, len) =>
          bindings.flutterxel_core_sound_set_effects(soundId, ptr, len),
    );
  }

  void effect(String effects) {
    set_effects(effects);
  }

  void mml([String? code, bool? old_syntax]) {
    if (code == null) {
      _mmlCode = null;
      _mmlDurationSec = null;
      return;
    }
    _pcmDurationSec = null;
    final oldSyntax = old_syntax == true || _looksLikeOldMml(code);
    _mmlDurationSec = _calcMmlDurationSec(code, oldSyntax: oldSyntax);
    _mmlCode = code;
  }

  void pcm([String? filename]) {
    if (filename == null) {
      _pcmDurationSec = null;
      return;
    }
    _pcmDurationSec = _loadAudioDurationSec(filename);
    _mmlCode = null;
    _mmlDurationSec = null;
  }

  void save(String filename, double sec, {bool? ffmpeg}) {
    _saveAudioCapture(filename, sec, ffmpeg: ffmpeg ?? false);
  }

  double? total_sec() {
    if (_pcmDurationSec != null) {
      return _pcmDurationSec;
    }
    if (_mmlCode != null) {
      return _mmlDurationSec;
    }
    if (speed <= 0) {
      return null;
    }
    return (_notesData.length * speed) / _soundTicksPerSecond;
  }
}

class Music {
  Music()
    : _musicId = null,
      _seqData = List<List<int>>.generate(NUM_CHANNELS, (_) => <int>[]) {
    _seqViews = List<Seq<int>>.generate(
      NUM_CHANNELS,
      (index) => Seq<int>.proxy(() => _seqData[index]),
    );
    seqs = Seq<Seq<int>>.proxy(() => _seqViews);
  }

  Music._resource(int musicId)
    : _musicId = musicId,
      _seqData = List<List<int>>.generate(NUM_CHANNELS, (_) => <int>[]) {
    _seqViews = List<Seq<int>>.generate(
      NUM_CHANNELS,
      (index) => Seq<int>.proxy(() => _seqData[index]),
    );
    seqs = Seq<Seq<int>>.proxy(() => _seqViews);
  }

  final int? _musicId;
  final List<List<int>> _seqData;
  late final List<Seq<int>> _seqViews;
  late final Seq<Seq<int>> seqs;

  bool _shouldSyncToCore() =>
      _musicId != null && _isInitialized && _getBindingsOrNull() != null;

  void _syncSeqToCore(int channel) {
    if (!_shouldSyncToCore()) {
      return;
    }
    final bindings = _getBindingsOrNull();
    final musicId = _musicId;
    if (bindings == null || musicId == null) {
      return;
    }
    final seq = _seqData[channel];
    ffi.Pointer<ffi.Int32> ptr = ffi.nullptr;
    try {
      if (seq.isNotEmpty) {
        ptr = calloc<ffi.Int32>(seq.length);
        for (var i = 0; i < seq.length; i++) {
          ptr[i] = seq[i];
        }
      }
      final ok = bindings.flutterxel_core_music_set_seq(
        musicId,
        channel,
        ptr,
        seq.length,
      );
      if (!ok) {
        throw StateError('flutterxel_core_music_set_seq failed.');
      }
    } finally {
      if (ptr != ffi.nullptr) {
        calloc.free(ptr);
      }
    }
  }

  void set(
    List<int> seq1, [
    List<int>? seq2,
    List<int>? seq3,
    List<int>? seq4,
  ]) {
    final values = <List<int>?>[seq1, seq2, seq3, seq4];
    for (var i = 0; i < _seqData.length && i < values.length; i++) {
      final seq = values[i];
      _seqData[i]
        ..clear()
        ..addAll(seq ?? const <int>[]);
      _syncSeqToCore(i);
    }
  }

  void save(String filename, double sec, {bool? ffmpeg}) {
    _saveAudioCapture(filename, sec, ffmpeg: ffmpeg ?? false);
  }
}

final List<Tone> _toneResources = List<Tone>.unmodifiable(
  List<Tone>.generate(NUM_TONES, (_) => Tone(), growable: false),
);
final List<Sound> _soundResources = List<Sound>.unmodifiable(
  List<Sound>.generate(NUM_SOUNDS, Sound._resource, growable: false),
);
final List<Music> _musicResources = List<Music>.unmodifiable(
  List<Music>.generate(NUM_MUSICS, Music._resource, growable: false),
);

final Seq<Tone> tones = Seq<Tone>.proxy(() => _toneResources);
final Seq<Sound> sounds = Seq<Sound>.proxy(() => _soundResources);
final Seq<Music> musics = Seq<Music>.proxy(() => _musicResources);

List<String> gen_bgm(int preset, int instr, {int? seed, bool? play}) {
  final random = math.Random(seed ?? ((preset + 1) * 65537 + instr));
  const notes = <String>['c', 'd', 'e', 'f', 'g', 'a', 'b', 'r'];
  final generated = List<String>.generate(NUM_CHANNELS, (channel) {
    final length = 8 + random.nextInt(8);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      final note = notes[random.nextInt(notes.length)];
      if (note == 'r') {
        buffer.write('r');
      } else {
        buffer.write('$note${3 + (channel % 2)}');
      }
    }
    return buffer.toString();
  }, growable: false);

  if (play == true && _isInitialized) {
    for (var channel = 0; channel < generated.length; channel++) {
      _playImpl(channel, generated[channel], loop: true);
    }
  }
  return generated;
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
