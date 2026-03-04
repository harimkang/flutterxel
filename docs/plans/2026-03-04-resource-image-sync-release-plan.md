# Resource Image Sync + v0.0.5 Release Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix native rendering mismatch by synchronizing resource `Image` mutations to core image banks, then release/document `0.0.5` with CI + pub.dev publish path.

**Architecture:** Add explicit image mutation ABI (`image_pset`, `image_pget`, `image_cls`) in both Rust core and plugin C header surface, regenerate Dart FFI bindings, and route `Image._resource` operations through these ABI calls when bindings are loaded while preserving fallback behavior. Then verify end-to-end with Rust/Dart tests, release metadata bump, release notes/docs updates, and CI publish workflow.

**Tech Stack:** Dart/Flutter (`flutter_test`, FFI), Rust (`cargo test`), C plugin shim, GitHub Actions workflows, pub.dev publish automation.

---

### Task 1: Add failing tests for image resource sync behavior (RED)

**Files:**
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Modify: `native/flutterxel_core/src/lib.rs`

**Step 1: Write Dart failing tests (native path aware)**
- Add tests that assert (when native bindings are available):
  - `images[0].pset(...)` is reflected by `blt(..., 0, ...)` output.
  - `images[0].cls(...)` is reflected by `blt(..., 0, ...)` output.
- Guard tests to skip when bindings are unavailable in runtime test environment.

**Step 2: Write Rust failing tests for new image mutation ABI expectations**
- Add tests for:
  - `flutterxel_core_image_pset` mutating source bank used by `flutterxel_core_blt`.
  - `flutterxel_core_image_cls` clearing source bank for subsequent `blt`.
  - `flutterxel_core_image_pget` returning written values and handling out-of-range safely.

**Step 3: Run targeted tests and confirm failure**
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "resource image"`
- Run: `cd native/flutterxel_core && cargo test image_resource`
- Expected: fail for missing ABI/sync behavior.

### Task 2: Implement core + plugin ABI for image resource mutation (GREEN)

**Files:**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `packages/flutterxel/src/flutterxel.h`
- Modify: `packages/flutterxel/src/flutterxel.c`

**Step 1: Add ABI declarations to headers**
- Add `flutterxel_core_image_pset`, `flutterxel_core_image_pget`, `flutterxel_core_image_cls` declarations.

**Step 2: Implement ABI in Rust core**
- Implement exported functions that mutate/read `state.image_banks`.
- Preserve existing API safety style (return bool, no panic, bounds-safe).

**Step 3: Implement matching ABI in C shim**
- Add compatible behavior in `flutterxel.c` fallback core shim (`image_bank0` based).
- Keep compatibility behavior for unsupported image ids (non-resource banks).

**Step 4: Re-run targeted tests and confirm pass**
- Run: `cd native/flutterxel_core && cargo test image_resource`
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "resource image"`

### Task 3: Wire Dart resource `Image` operations to new ABI (GREEN)

**Files:**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart` (generated)

**Step 1: Regenerate bindings after header changes**
- Run: `cd packages/flutterxel && dart run ffigen --config ffigen.yaml`

**Step 2: Update resource image read/write paths**
- For `_imageId != null` with bindings loaded:
  - `_setLocalPixel` must call `flutterxel_core_image_pset`.
  - `cls` must call `flutterxel_core_image_cls`.
  - `_getLocalPixel` must call `flutterxel_core_image_pget` and return core value.
- Keep fallback data path intact when bindings are unavailable.

**Step 3: Keep behavior consistent for `load`/`set`**
- Ensure existing `load`/`set` code paths flow through updated write path so native resource bank is synced.

**Step 4: Run targeted tests**
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "resource image"`
- Run: `cd native/flutterxel_core && cargo test`

### Task 4: Update ABI contract checks and docs for behavior boundaries

**Files:**
- Modify: `packages/flutterxel/tool/check_abi_contract.sh`
- Modify: `docs/site/guides/resources-and-persistence.md`
- Modify: `docs/site/reference/constants-and-compatibility.md`
- Modify: `README.md`

**Step 1: Include new ABI symbols in contract check**
- Add image mutation symbols in expected list.

**Step 2: Document updated behavior + remaining constraints**
- Clarify:
  - resource image mutations now sync to native render path.
  - global `blt` detached image constraint remains (resource image id or resource image object).
  - text ASCII-only behavior explicitly remains.

**Step 3: Run docs/reference grep validation**
- Run: `rg -n "resource|blt|ASCII|non-ASCII|Image" README.md docs/site/guides/resources-and-persistence.md docs/site/reference/constants-and-compatibility.md`

### Task 5: Prepare release metadata and release notes for 0.0.5

**Files:**
- Modify: `packages/flutterxel/pubspec.yaml`
- Modify: `packages/flutterxel_tools/pubspec.yaml`
- Modify: `CHANGELOG.md`
- Modify: `packages/flutterxel/CHANGELOG.md`
- Modify: `packages/flutterxel_tools/CHANGELOG.md`
- Create: `docs/site/release-notes/v0.0.5.md`
- Modify: `docs/mkdocs.yml`
- Modify: `docs/site/getting-started/installation.md`
- Modify: `README.md`

**Step 1: Bump versions using release helper**
- Run: `bash packages/flutterxel_tools/tool/bump_release_versions.sh --version 0.0.5`

**Step 2: Replace TODO changelog content with concrete release notes**
- Fill all `0.0.5` sections with implemented changes.

**Step 3: Add docs site release note page and nav entry**
- Add `v0.0.5` page and update MkDocs nav ordering.

**Step 4: Update install snippets to `^0.0.5`**
- Update repository/docs snippets referencing `^0.0.4`.

**Step 5: Validate release metadata consistency**
- Run: `bash packages/flutterxel_tools/tool/check_release_versions.sh --version 0.0.5`

### Task 6: Add CI workflow for actual pub.dev publishing on release tags

**Files:**
- Create: `.github/workflows/publish_pub_dev.yml`

**Step 1: Implement workflow structure**
- Trigger on `push tags v*` and manual dispatch.
- Reuse release version check script.
- Add matrix publish for `flutterxel` and `flutterxel_tools`.

**Step 2: Configure auth pattern for pub.dev token**
- Use secret env var for token (`PUB_DEV_PUBLISH_TOKEN`) and `dart pub token add`.
- Publish with `flutter pub publish --force`.

**Step 3: Keep dry-run workflow unchanged as preflight**
- Ensure new workflow complements `publish_dry_run.yml`.

**Step 4: Validate workflow syntax**
- Run: `rg -n "name: publish-pub-dev|flutter pub publish --force|PUB_DEV_PUBLISH_TOKEN" .github/workflows/publish_pub_dev.yml`

### Task 7: Full verification, commit, tag, and deployment attempt

**Files:**
- Modify: release-related files from prior tasks

**Step 1: Run full verification suite**
- `dart run melos bootstrap`
- `dart run melos run analyze`
- `dart run melos run test`
- `cd native/flutterxel_core && cargo fmt --check`
- `cd native/flutterxel_core && cargo test`
- `cd packages/flutterxel && dart run ffigen --config ffigen.yaml`
- `./packages/flutterxel/tool/check_abi_contract.sh`
- `bash packages/flutterxel_tools/tool/check_release_versions.sh --version 0.0.5`

**Step 2: Commit changes atomically**
- `git add ...`
- `git commit -m "fix: sync resource image mutations to native core path"`
- If needed, separate docs/release workflow commit with `docs:` and `feat:` per repo convention.

**Step 3: Create release tag**
- `git tag v0.0.5`

**Step 4: Push branch and tag to trigger CI workflows**
- `git push origin main`
- `git push origin v0.0.5`

**Step 5: Trigger/confirm pub.dev publish path**
- CI-based: verify `publish-pub-dev` workflow run status on tag.
- Local fallback/manual: run from each package if credentials exist:
  - `cd packages/flutterxel && flutter pub publish --force`
  - `cd packages/flutterxel_tools && flutter pub publish --force`

**Step 6: Record deployment evidence**
- Capture workflow run URLs/status and publish command outcomes.
- If blocked by missing credentials/secrets/permissions, report exact blocker and required user action.
