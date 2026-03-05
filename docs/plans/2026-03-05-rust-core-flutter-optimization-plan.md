# Flutterxel Native Core And Flutter Hot-Path Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Resolve the native/fallback tilemap sync bug and remove avoidable hot-path allocation/copy overhead in Rust core rendering and Flutter view/image bridges.

**Architecture:** Keep Pyxel-compatible API behavior unchanged while moving expensive work from per-pixel/per-frame dynamic allocations to preallocated buffers and bulk synchronization paths. For correctness, make resource tilemap/image mutations explicitly synchronized into native core state via ABI calls. For rendering throughput, refactor Rust `draw_blt`/`draw_bltm` into zero-extra-allocation paths and reduce Flutter frame snapshot lock/copy overhead.

**Tech Stack:** Flutter/Dart (`ffi`, widget painter), Rust (`std`, FFI C ABI), ffigen, flutter_test, cargo test.

---

### Task 0: Preflight Workspace Setup

**Files:**
- Create: none
- Modify: none
- Test: none

**Step 1: Create isolated worktree**

Run:
```bash
git worktree add ../flutterxel-opt-2026-03-05 -b chore/opt-hotpaths-20260305
```
Expected: new worktree directory created with new branch.

**Step 2: Bootstrap workspace dependencies**

Run:
```bash
cd ../flutterxel-opt-2026-03-05
dart run melos bootstrap
```
Expected: melos bootstrap completes with no dependency errors.

**Step 3: Commit (empty setup marker for traceability)**

```bash
git commit --allow-empty -m "chore: start hot-path optimization workstream"
```

### Task 1: Lock Reproduction With Native Tilemap Sync Regression Tests

**Files:**
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Test: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Write failing test for resource tilemap `pset` sync**

Add:
```dart
test('resource tilemap pset is reflected by native bltm source', () {
  flutterxel.init(16, 16);
  if (!nativeBindingsAvailable()) return;

  flutterxel.cls(0);
  flutterxel.images[0].cls(0);
  flutterxel.images[0].pset(0, 0, 2);      // tile (0,0) pixel
  flutterxel.images[0].pset(8, 16, 11);    // tile (1,2) pixel

  final tm0 = flutterxel.tilemaps[0];
  tm0.cls((0, 0));
  tm0.pset(0, 0, (1, 2));

  flutterxel.bltm(0, 0, tm0, 0, 0, 1, 1);
  expect(flutterxel.pget(0, 0), 11);
});
```

**Step 2: Write failing test for resource tilemap `cls` sync**

Add:
```dart
test('resource tilemap cls is reflected by native bltm source', () {
  flutterxel.init(16, 16);
  if (!nativeBindingsAvailable()) return;

  flutterxel.cls(0);
  flutterxel.images[0].cls(0);
  flutterxel.images[0].pset(0, 0, 3);
  flutterxel.images[0].pset(8, 8, 12); // tile (1,1) pixel

  final tm0 = flutterxel.tilemaps[0];
  tm0.cls((1, 1));

  flutterxel.bltm(0, 0, tm0, 0, 0, 1, 1);
  expect(flutterxel.pget(0, 0), 12);
});
```

**Step 3: Run test to verify current failure in native mode**

Run:
```bash
cd packages/flutterxel
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource tilemap pset is reflected by native bltm source"
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource tilemap cls is reflected by native bltm source"
```
Expected: at least one test fails before implementation when native core is available.

**Step 4: Commit failing regression tests**

```bash
git add packages/flutterxel/test/flutterxel_api_surface_test.dart
git commit -m "test: add native tilemap sync regression coverage"
```

### Task 2: Add Native Tilemap Mutation ABI And Wire Dart Resource Tilemap Sync

**Files:**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart`
- Test: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Add C ABI declarations for tilemap mutation/query**

Add to header:
```c
bool flutterxel_core_tilemap_pset(int32_t tm, int32_t x, int32_t y, int32_t tile_x, int32_t tile_y);
bool flutterxel_core_tilemap_pget(int32_t tm, int32_t x, int32_t y, int32_t* tile_x_out, int32_t* tile_y_out);
bool flutterxel_core_tilemap_cls(int32_t tm, int32_t tile_x, int32_t tile_y);
bool flutterxel_core_tilemap_set_imgsrc(int32_t tm, int32_t imgsrc);
```

**Step 2: Implement Rust exports with bounds-safe map access**

Add to `lib.rs`:
```rust
#[no_mangle]
pub extern "C" fn flutterxel_core_tilemap_pset(...) -> bool { /* ensure/init tm, set pair */ }

#[no_mangle]
pub extern "C" fn flutterxel_core_tilemap_cls(...) -> bool { /* fill all cells */ }
```
Include validation for initialized state, non-negative tilemap id, and output pointers for `pget`.

**Step 3: Regenerate Dart bindings**

Run:
```bash
cd packages/flutterxel
dart run ffigen --config ffigen.yaml
```
Expected: `flutterxel_bindings_generated.dart` includes new symbols.

**Step 4: Sync resource `Tilemap` operations into native core**

Implement in Dart:
```dart
void _syncResourceTilePsetToCore(int tmId, int x, int y, (int, int) tile) { ... }
void _syncResourceTileClsToCore(int tmId, (int, int) tile) { ... }
```
Call from:
- `Tilemap._writeTileRaw` when `_tilemapId != null`
- `Tilemap.cls` when `_tilemapId != null`
- `Tilemap._readTileRaw` prefer native `pget` when bindings available

Also convert `Tilemap.imgsrc` to getter/setter-backed field and call `flutterxel_core_tilemap_set_imgsrc` for resource tilemaps.

**Step 5: Run targeted tests and ensure pass**

Run:
```bash
cd packages/flutterxel
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource tilemap pset is reflected by native bltm source"
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource tilemap cls is reflected by native bltm source"
```
Expected: PASS.

**Step 6: Commit**

```bash
git add native/flutterxel_core/include/flutterxel_core.h native/flutterxel_core/src/lib.rs packages/flutterxel/lib/flutterxel_bindings_generated.dart packages/flutterxel/lib/flutterxel.dart
git commit -m "feat: sync resource tilemap mutations to native core"
```

### Task 3: Remove Rust `blt`/`bltm` Clone And Temporary Allocation Hotspots

**Files:**
- Modify: `native/flutterxel_core/src/lib.rs`
- Test: `native/flutterxel_core/src/lib.rs` (existing test module)

**Step 1: Add behavior-preserving tests before refactor**

Add tests for:
- `blt` with negative `w/h` (flip)
- `blt` with `colkey` skip
- `bltm` sampling from non-zero tile coordinates

Snippet:
```rust
#[test]
fn blt_with_colkey_skips_source_pixels() { /* setup + assert */ }
```

**Step 2: Run new tests and verify baseline**

Run:
```bash
cd native/flutterxel_core
cargo test blt_with_colkey_skips_source_pixels
```
Expected: PASS on baseline behavior tests.

**Step 3: Refactor `draw_blt` to single-pass write**

Replace `Vec<Option<i32>>` sampling with direct per-pixel read/write:
```rust
for dy in 0..height {
    for dx in 0..width {
        // compute src, skip OOB, colkey gate, set pixel
    }
}
```
Do not allocate intermediate sample buffers.

**Step 4: Refactor `draw_bltm` to avoid cloning tilemap/source bank**

Use borrowed views and cached scalar runtime fields; avoid `.cloned()` for:
- `state.tilemaps.get(&tm)`
- `state.image_banks.get(&imgsrc)`

**Step 5: Run Rust test suite**

Run:
```bash
cd native/flutterxel_core
cargo test
```
Expected: all Rust tests pass.

**Step 6: Commit**

```bash
git add native/flutterxel_core/src/lib.rs
git commit -m "perf: remove blt and bltm clone-allocation overhead"
```

### Task 4: Batch Resource Image Synchronization To Avoid Per-Pixel FFI Calls

**Files:**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart`
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Test: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Add bulk image sync ABI**

Add C ABI:
```c
bool flutterxel_core_image_replace(int32_t img, const int32_t* data, uintptr_t len);
```

**Step 2: Implement Rust bulk image replacement**

Implement:
```rust
#[no_mangle]
pub extern "C" fn flutterxel_core_image_replace(img: i32, data: *const i32, len: usize) -> bool {
    // validate pointer/len, ensure bank, copy slice
}
```

**Step 3: Regenerate ffigen bindings**

Run:
```bash
cd packages/flutterxel
dart run ffigen --config ffigen.yaml
```

**Step 4: Use deferred sync for bulk image write paths**

In `Image`:
- Add internal helper `_setLocalPixelInternal(..., {required bool syncNative})`
- Keep `pset` using `syncNative: true`
- In `set`, `_loadDecodedRaster`, and other bulk loops use `syncNative: false`
- After loop, if resource image + native bindings:
```dart
void _flushResourceImageToCore() {
  final bank = _fallbackEnsureImageBank(_imageId!);
  // allocate once, copy ints, call flutterxel_core_image_replace
}
```

**Step 5: Run targeted tests**

Run:
```bash
cd packages/flutterxel
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource image load is reflected by native blt source"
flutter test test/flutterxel_api_surface_test.dart --plain-name "resource image pset is reflected by native blt source"
```
Expected: PASS, with unchanged external behavior.

**Step 6: Commit**

```bash
git add native/flutterxel_core/include/flutterxel_core.h native/flutterxel_core/src/lib.rs packages/flutterxel/lib/flutterxel_bindings_generated.dart packages/flutterxel/lib/flutterxel.dart
git commit -m "perf: batch resource image sync to native core"
```

### Task 5: Optimize Framebuffer View Snapshot And Painter Allocation

**Files:**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart`
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Test: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Add single-call framebuffer copy ABI**

Add:
```c
bool flutterxel_core_copy_framebuffer(int32_t* dst, uintptr_t dst_len);
```

**Step 2: Implement Rust framebuffer copy export**

Implement with one lock scope:
```rust
#[no_mangle]
pub extern "C" fn flutterxel_core_copy_framebuffer(dst: *mut i32, dst_len: usize) -> bool { ... }
```
Validate null pointers and exact/compatible length handling.

**Step 3: Regenerate ffigen**

Run:
```bash
cd packages/flutterxel
dart run ffigen --config ffigen.yaml
```

**Step 4: Switch `_frameBufferSnapshotForView` to single FFI copy + paint cache**

In Dart:
- Maintain reusable typed buffer for view frames.
- Replace dual `framebuffer_len + framebuffer_ptr` flow with `flutterxel_core_copy_framebuffer`.
- Cache `Paint` objects by palette identity/hash in `_FlutterxelViewPainter` to avoid per-paint rebuild.

**Step 5: Run Flutter tests**

Run:
```bash
cd packages/flutterxel
flutter test
```
Expected: PASS.

**Step 6: Commit**

```bash
git add native/flutterxel_core/include/flutterxel_core.h native/flutterxel_core/src/lib.rs packages/flutterxel/lib/flutterxel_bindings_generated.dart packages/flutterxel/lib/flutterxel.dart
git commit -m "perf: reduce frame snapshot locking and painter allocations"
```

### Task 6: Full Verification, ABI Contract Checks, And Documentation

**Files:**
- Create: `docs/architecture/native-core-sync-and-hotpath-notes.md`
- Modify: `docs/plans/2026-03-05-rust-core-flutter-optimization-plan.md` (status notes/checklist)
- Test: workspace-level verification commands

**Step 1: Run workspace static analysis**

Run:
```bash
dart run melos run analyze
```
Expected: no analyzer errors.

**Step 2: Run workspace tests**

Run:
```bash
dart run melos run test
```
Expected: all Flutter/Dart tests pass.

**Step 3: Run Rust tests**

Run:
```bash
cd native/flutterxel_core
cargo test
```
Expected: all Rust tests pass.

**Step 4: Validate ABI surface**

Run:
```bash
cd /Users/harimkang/develop/applications/flutterxel
./packages/flutterxel/tool/check_abi_contract.sh
```
Expected: ABI contract check passes with newly added symbols.

**Step 5: Document architectural changes**

Add document describing:
- Why tilemap/image sync must be explicit in mixed native/fallback mode
- New ABI functions and intended call sites
- Hot-path changes in `draw_blt`, `draw_bltm`, and Flutter view rendering

**Step 6: Commit**

```bash
git add docs/architecture/native-core-sync-and-hotpath-notes.md docs/plans/2026-03-05-rust-core-flutter-optimization-plan.md
git commit -m "docs: record native sync and hot-path optimization design"
```

---

## Execution Notes

- Keep commits atomic per task to isolate regressions.
- Request code review after Task 2, Task 4, and Task 5 because they cross ABI + runtime boundaries.
- If any ABI addition changes behavior in fallback mode, add explicit regression tests in `flutterxel_api_surface_test.dart` before merging.

## Status Notes (2026-03-05)

- Task 0: skipped by explicit user request to continue work on the current branch.
- Task 1: completed in commit `f1239b7` (`test: add native tilemap sync regression coverage`).
- Task 2: completed in commit `ae73e24` (`feat: sync resource tilemap mutations to native core`).
- Task 3: completed in commit `54a4278` (`perf: remove blt and bltm clone-allocation overhead`).
- Task 4: completed in commit `777d65b` (`perf: batch resource image sync to native core`).
- Task 5: completed in commit `439e5ed` (`perf: reduce frame snapshot locking and painter allocations`).
- Task 6 verification status:
  - `dart run melos run analyze`: pass
  - `dart run melos run test`: pass
  - `cd native/flutterxel_core && cargo test`: pass
  - `./packages/flutterxel/tool/check_abi_contract.sh`: pass
