import 'dart:ffi';
import 'dart:io';

import 'flutterxel_bindings_generated.dart';

const String _libName = 'flutterxel';

DynamicLibrary _openLibrary() {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

final FlutterxelBindings _bindings = FlutterxelBindings(_openLibrary());

/// Runtime facade for the `flutterxel` plugin package.
///
/// The current implementation is a scaffold. Pyxel-compatible runtime APIs
/// will be added incrementally while the Rust core integration is completed.
class Flutterxel {
  Flutterxel._();

  /// Returns a simple native-call probe value to verify FFI wiring.
  ///
  /// This currently calls a scaffold symbol from the template native library.
  static int ffiHealthcheck() => _bindings.sum(20, 22);
}
