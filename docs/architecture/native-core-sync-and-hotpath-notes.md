# Native Core Sync And Hot-Path Notes

## Context

Flutterxel runs with either native Rust core bindings or fallback Dart logic.
Resource mutation APIs (`Image`, `Tilemap`) were previously able to diverge between
Dart-side resource state and native-side resource state. In that mixed mode, native
`blt`/`bltm` sampled stale data while fallback paths sampled updated data.

The optimization work also identified avoidable hot-path overhead:
- Rust rendering paths allocated temporary buffers and cloned resource maps.
- Flutter view rendering rebuilt `Paint` objects every frame and copied frame data
  through pointer-based reads that held extra lock/copy overhead.

## Why Explicit Sync Is Required

Resource objects are mutable on the Dart API surface, but native rendering samples
state stored inside the Rust runtime. To keep behavior deterministic across backend
modes, resource mutations must explicitly cross the ABI boundary when native bindings
are active.

Without explicit sync, the same public call sequence can produce different pixels
between native and fallback paths.

## ABI Additions And Call Sites

### Tilemap sync ABI (Task 2)

- `flutterxel_core_tilemap_pset`
- `flutterxel_core_tilemap_pget`
- `flutterxel_core_tilemap_cls`
- `flutterxel_core_tilemap_set_imgsrc`

Dart call sites:
- `Tilemap._writeTileRaw` -> `tilemap_pset`
- `Tilemap.cls` -> `tilemap_cls`
- `Tilemap.imgsrc` setter -> `tilemap_set_imgsrc`
- `Tilemap._readTileRaw` prefers `tilemap_pget` when bindings are available

### Image bulk sync ABI (Task 4)

- `flutterxel_core_image_replace`

Dart call sites:
- `Image.set` performs local writes then one `image_replace` flush
- `Image._loadDecodedRaster` performs local writes then one `image_replace` flush
- Per-pixel `pset` behavior stays immediate, preserving API expectations

### Framebuffer copy ABI (Task 5)

- `flutterxel_core_copy_framebuffer`

Dart call site:
- `_frameBufferSnapshotForView` now performs one native call into a reusable
  `Int32` buffer instead of `framebuffer_ptr` + Dart `setAll` copy flow

## Rust Hot-Path Changes

### `draw_blt`

- Removed temporary `Vec<Option<i32>>` sampling buffers.
- Switched to direct per-pixel read/transform/write in a single pass.
- Kept colkey and flip behavior, validated with regression tests.

### `draw_bltm`

- Removed tilemap and image-bank cloning in render path.
- Uses borrowed resources with cached scalar render context fields.
- Preserves tile sampling behavior while reducing allocation/copy overhead.

## Flutter View Rendering Changes

- Added reusable native-frame typed buffer lifecycle helpers:
  - `_ensureNativeViewFrameBuffer`
  - `_disposeNativeViewFrameBuffer`
- Added palette/background `Paint` caches in `_FlutterxelViewPainter`.
  - Paint objects are reused by palette signature/color values.
  - New paints are only created on cache misses.

## Safety And Compatibility Notes

- Public Flutter API shape remains unchanged.
- Fallback-mode behavior remains unchanged.
- ABI contract script now validates the new exported symbols.
- `flutterxel_core_init` resets `image_bank_size` to default to prevent
  cross-test/runtime state contamination.

## Verification Summary

Executed after optimization tasks:
- `dart run melos run analyze`
- `dart run melos run test`
- `cd native/flutterxel_core && cargo test`
- `./packages/flutterxel/tool/check_abi_contract.sh`

All commands passed on 2026-03-05.
