# Flutterxel Audio FFI and Old MML Compatibility Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make audio resource edits in Dart reflect into the Rust runtime over FFI, and close fallback compatibility gaps for `Sound.pcm/save` and old MML (`x/X/~`) handling.

**Architecture:** Extend the Rust C ABI with focused resource mutation endpoints for `Sound` and `Music`, then wire Dart `Sound/Music` resource instances to call these endpoints on mutation. Keep fallback behavior deterministic by preserving existing in-memory models while adding ffmpeg-backed compatibility paths and old-MML token support to duration parsing.

**Tech Stack:** Flutter/Dart FFI, Rust `extern "C"` ABI, ffigen-generated bindings, Flutter test + Rust unit tests

---

### Task 1: Add Rust ABI for Sound/Music Resource Mutation

**Files:**
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Test: `native/flutterxel_core/src/lib.rs` (existing test module)

**Step 1: Write failing Rust tests for sound/music mutation ABI**
- Add tests that call new ABI functions and assert `RuntimeState.sounds/musics` content is updated.

**Step 2: Run Rust tests to verify failures**
- Run: `cargo test`
- Expect: missing symbol/function compile errors.

**Step 3: Implement minimal ABI exports**
- Add:
  - `flutterxel_core_sound_set_notes`
  - `flutterxel_core_sound_set_tones`
  - `flutterxel_core_sound_set_volumes`
  - `flutterxel_core_sound_set_effects`
  - `flutterxel_core_sound_set_speed`
  - `flutterxel_core_music_set_seq`
- Validate pointers/length and initialized runtime state.

**Step 4: Re-run Rust tests**
- Run: `cargo test`
- Expect: new tests pass.

### Task 2: Sync Public C Header and Plugin Header Contract

**Files:**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `packages/flutterxel/src/flutterxel.h`
- Modify: `packages/flutterxel/tool/check_abi_contract.sh`

**Step 1: Add new function declarations to both headers**
- Keep signatures byte-for-byte aligned between core header and plugin header.

**Step 2: Update ABI contract script symbol list**
- Include all new exported function names.

**Step 3: Verify ABI contract script**
- Run: `bash packages/flutterxel/tool/check_abi_contract.sh`
- Expect: contract passes.

### Task 3: Regenerate Dart Bindings and Wire Sound/Music FFI Sync

**Files:**
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart` (generated)
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Test: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Write failing Dart tests for resource mutation behavior assumptions**
- Add tests that verify `sounds[i]` and `musics[i]` remain mutable and compatible after structural changes.

**Step 2: Run targeted Dart tests to verify failure**
- Run: `flutter test packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 3: Regenerate bindings**
- Run: `dart run ffigen --config packages/flutterxel/ffigen.yaml`

**Step 4: Implement Dart sync hooks**
- Add resource id fields/constructors for `Sound` and `Music`.
- On `set_notes/tones/volumes/effects/speed` and `Music.set`, push changes via FFI when bindings are loaded and instance is a resource.
- Keep fallback local data path intact.

**Step 5: Re-run targeted Dart tests**
- Run: `flutter test packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Expect: pass.

### Task 4: Add Fallback ffmpeg Compatibility for `Sound.pcm/save` and `Music.save`

**Files:**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Write failing tests for compressed/ffmpeg behavior**
- Cover:
  - `Sound.pcm(non-wav)` duration probing fallback path
  - `save(..., ffmpeg: true)` behavior and error handling when ffmpeg unavailable

**Step 2: Run targeted Dart test and verify RED**
- Run: `flutter test packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 3: Implement ffmpeg-backed helper paths**
- Add probe/convert helpers (`ffprobe`/`ffmpeg`) with explicit error reporting.
- Keep deterministic WAV output path as baseline.

**Step 4: Re-run targeted Dart test**
- Expect: pass.

### Task 5: Implement old MML (`x/X/~`) compatibility mode in fallback parser

**Files:**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Write failing tests for old syntax acceptance**
- Add tests ensuring `Sound.mml` accepts old tokens and computes non-null duration where finite.

**Step 2: Run targeted Dart tests and verify RED**
- Run: `flutter test packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 3: Implement parser extensions**
- Add old-syntax toggle and token handling:
  - `x/X` tone command
  - `~` tie operator
- Support explicit `old_syntax` and auto-detection fallback.

**Step 4: Re-run targeted Dart tests**
- Expect: pass.

### Task 6: Final Verification and Commits

**Files:**
- Verify repository-wide health

**Step 1: Run full Dart checks**
- `dart run melos run analyze`
- `dart run melos run test`

**Step 2: Run Rust tests**
- `cargo test` in `native/flutterxel_core`

**Step 3: Commit in logical units**
- Suggested commits:
  - `feat: add sound and music resource mutation abi`
  - `feat: sync dart sound/music resources to rust core`
  - `feat: support fallback ffmpeg audio probe and old mml tokens`
