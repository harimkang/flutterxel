import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'flutterxel_bindings_generated.dart';

const int _optionalI32None = -2147483648; // INT32_MIN
const int _optionalBoolNone = -1;
const int _optionalBoolFalse = 0;
const int _optionalBoolTrue = 1;

int width = 0;
int height = 0;
int frameCount = 0;

bool _isInitialized = false;
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
    _isInitialized = true;
  } finally {
    if (titlePtr != ffi.nullptr) {
      calloc.free(titlePtr);
    }
  }
}

/// Pyxel-compatible run API.
///
/// Current skeleton executes one update/draw cycle per call.
void run(void Function() update, void Function() draw) {
  _ensureInitialized('run');

  update();
  draw();

  final bindings = _getBindingsOrNull();
  final nullFrameCallback = ffi.nullptr
      .cast<ffi.NativeFunction<FlutterxelCoreFrameCallbackFunction>>();

  final ok =
      bindings?.flutterxel_core_run(
        nullFrameCallback,
        ffi.nullptr,
        nullFrameCallback,
        ffi.nullptr,
      ) ??
      true;

  if (!ok) {
    throw StateError('flutterxel_core_run failed.');
  }

  frameCount = bindings?.flutterxel_core_frame_count() ?? (frameCount + 1);
}

/// Pyxel-compatible btn API.
bool btn(int key) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  return bindings?.flutterxel_core_btn(key) ?? false;
}

/// Runtime input bridge for forwarding external key/touch mappings.
void setBtnState(int key, bool pressed) {
  _ensureInitialized('setBtnState');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_set_btn_state(key, pressed) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_set_btn_state failed.');
  }
}

/// Pyxel-compatible cls API.
void cls(int col) {
  _ensureInitialized('cls');
  final bindings = _getBindingsOrNull();
  final ok = bindings?.flutterxel_core_cls(col) ?? true;
  if (!ok) {
    throw StateError('flutterxel_core_cls failed.');
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
  } finally {
    if (seqPtr != ffi.nullptr) {
      calloc.free(seqPtr);
    }
    if (sndStringPtr != ffi.nullptr) {
      calloc.free(sndStringPtr);
    }
  }
}

/// Returns whether a channel is currently marked as playing in the core.
bool isChannelPlaying(int ch) {
  if (!_isInitialized) {
    return false;
  }
  final bindings = _getBindingsOrNull();
  return bindings?.flutterxel_core_is_channel_playing(ch) ?? false;
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
  final len = bindings?.flutterxel_core_framebuffer_len() ?? 0;
  if (len <= 0) {
    return const [];
  }

  final ptr = bindings?.flutterxel_core_framebuffer_ptr() ?? ffi.nullptr;
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
