// Intentionally kept as a minimal translation unit.
//
// iOS must link Rust core symbols from FlutterxelCore.xcframework.
// Do not include ../../src/flutterxel.c here because that would export
// flutterxel_core_* fallback symbols from the plugin binary and shadow the
// native core backend discriminator path.
static void flutterxel_ios_plugin_stub(void) {}
