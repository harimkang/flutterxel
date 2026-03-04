# Flutterxel Upstream Followups + Agent Map Enablement Implementation Plan (Rebaselined)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

## Rebaseline Context (2026-03-04)

- Baseline branch: `main`
- Baseline commit: `cf9a786`
- This plan supersedes the earlier fail-first draft.
- The backend discriminator, backend mode API, c_fallback forcing, c_fallback regressions, alpha import extension, include_colors docs/tests, and agent-map files already exist on this baseline.

Already-landed commits covered by this rebaseline:

- `a946bd9` feat: add backend discriminator ABI and tighten contract checks
- `03fffd1` feat: add reliable runtime backend mode and capability API
- `3d6d678` test: add deterministic backend forcing for c fallback coverage
- `a22714b` fix: honor image id in c fallback image APIs and blt
- `f0a4173` fix: honor tilemap id in c fallback bltm
- `03e9fe7` feat: add opt-in alpha-aware image import policy
- `38c9e4b` docs: clarify include_colors semantics and lock with tests
- `5d0b14b` feat: add reference character asset ingestion pipeline
- `a254b09` feat: add service-zone character state machine
- `86ac516` feat: add flutterxel agent-map renderer mvp
- `20b7c38` feat: add activity feed adapter for agent map states
- `cf9a786` docs: add alpha policy, backend mode, and agent-map integration guide

## Goal

Keep the already-implemented upstream fixes and Agent Map MVP reproducible on current `HEAD` by running verification-first tasks and applying only drift fixes.

## Architecture

Preserve existing Pyxel-compatible defaults and validate that opt-in extensions keep working:

- ABI discriminator and contract parity across native/plugin/Dart
- Backend mode and capability introspection
- Forced `c_fallback` path for deterministic fallback-only regression tests
- Alpha-aware image import and explicit `include_colors` semantics
- Character asset sync + manifest parsing + state machine + renderer + activity feed adapter

## Tech Stack

Dart/Flutter (`flutter_test`), C scaffold (`packages/flutterxel/src/flutterxel.c`), Rust core ABI (`native/flutterxel_core`), ffigen, docs (MkDocs), example app.

---

### Task 1: Verify Backend ABI Discriminator and Contract Parity

**Files (only if drift exists):**
- Modify: `native/flutterxel_core/include/flutterxel_core.h`
- Modify: `native/flutterxel_core/src/lib.rs`
- Modify: `packages/flutterxel/src/flutterxel.h`
- Modify: `packages/flutterxel/src/flutterxel.c`
- Modify: `packages/flutterxel/tool/check_abi_contract.sh`
- Modify: `packages/flutterxel/lib/flutterxel_bindings_generated.dart` (generated)

**Step 1: Verify Rust backend discriminator test baseline**
- Run: `cd native/flutterxel_core && cargo test backend_kind`
- Expected: PASS

**Step 2: Verify ABI contract parity script baseline**
- Run: `./packages/flutterxel/tool/check_abi_contract.sh`
- Expected: PASS

**Step 3: Repair only if verification fails**
- Restore symbol parity in native header, plugin header, generated bindings, and implementations.

**Step 4: Re-run checks**
- Run Task 1 Step 1-2 again
- Expected: PASS

**Step 5: Commit (only if code changed)**
- `git add native/flutterxel_core/include/flutterxel_core.h native/flutterxel_core/src/lib.rs packages/flutterxel/src/flutterxel.h packages/flutterxel/src/flutterxel.c packages/flutterxel/tool/check_abi_contract.sh packages/flutterxel/lib/flutterxel_bindings_generated.dart`
- `git commit -m "fix: restore backend discriminator abi parity"`

---

### Task 2: Verify Backend Mode/Capability API Stability (2.4)

**Files (only if drift exists):**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Modify: `docs/site/reference/constants-and-compatibility.md`

**Step 1: Verify backend mode API tests on current baseline**
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "backend mode"`
- Expected: PASS

**Step 2: Repair only if verification fails**
- Re-align `BackendMode`, fail-closed ABI mismatch handling, and capability getters.

**Step 3: Re-run targeted tests**
- Run Task 2 Step 1 again
- Expected: PASS

**Step 4: Commit (only if code changed)**
- `git add packages/flutterxel/lib/flutterxel.dart packages/flutterxel/test/flutterxel_api_surface_test.dart docs/site/reference/constants-and-compatibility.md`
- `git commit -m "fix: restore backend mode and capability api invariants"`

---

### Task 3: Verify Deterministic `c_fallback` Forcing Harness

**Files (only if drift exists):**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Modify: `packages/flutterxel/tool/build_c_scaffold_host.sh`
- Modify: `packages/flutterxel/README.md`

**Step 1: Verify forced fallback path**
- Run:
  - `HOST_LIB="$(./packages/flutterxel/tool/build_c_scaffold_host.sh)" && cd packages/flutterxel && FLUTTERXEL_FORCE_BACKEND=c_fallback FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" flutter test test/flutterxel_api_surface_test.dart --plain-name "forced c fallback mode"`
- Expected: PASS

**Step 2: Verify tests do not silently skip fallback regressions**
- Check fallback-specific tests are gated to forced mode and fail with actionable output when force-mode precondition is unmet.

**Step 3: Repair only if verification fails**
- Re-align env-based loader overrides and test precondition enforcement.

**Step 4: Commit (only if code changed)**
- `git add packages/flutterxel/lib/flutterxel.dart packages/flutterxel/test/flutterxel_api_surface_test.dart packages/flutterxel/tool/build_c_scaffold_host.sh packages/flutterxel/README.md`
- `git commit -m "fix: restore deterministic c fallback test forcing"`

---

### Task 4: Verify `c_fallback` Source-Selection Regressions (2.1)

**Files (only if drift exists):**
- Modify: `packages/flutterxel/src/flutterxel.c`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`

**Step 1: Verify `blt` image-bank regression test**
- Run:
  - `HOST_LIB="$(./packages/flutterxel/tool/build_c_scaffold_host.sh)" && cd packages/flutterxel && FLUTTERXEL_FORCE_BACKEND=c_fallback FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" flutter test test/flutterxel_api_surface_test.dart --plain-name "c fallback blt image bank"`
- Expected: PASS

**Step 2: Verify `bltm` tilemap-id regression test**
- Run:
  - `HOST_LIB="$(./packages/flutterxel/tool/build_c_scaffold_host.sh)" && cd packages/flutterxel && FLUTTERXEL_FORCE_BACKEND=c_fallback FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" flutter test test/flutterxel_api_surface_test.dart --plain-name "c fallback bltm tilemap id"`
- Expected: PASS

**Step 3: Repair only if verification fails**
- Re-align C scaffold image/tilemap source selection and regression tests.

**Step 4: Commit (only if code changed)**
- `git add packages/flutterxel/src/flutterxel.c packages/flutterxel/test/flutterxel_api_surface_test.dart`
- `git commit -m "fix: restore c fallback source-selection contracts"`

---

### Task 5: Verify Alpha Import and `include_colors` Semantics (2.2, 2.3)

**Files (only if drift exists):**
- Modify: `packages/flutterxel/lib/flutterxel.dart`
- Modify: `packages/flutterxel/test/flutterxel_api_surface_test.dart`
- Modify: `docs/site/guides/resources-and-persistence.md`
- Modify: `docs/site/reference/constants-and-compatibility.md`

**Step 1: Verify alpha policy tests**
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "Image.load alpha policy"`
- Expected: PASS

**Step 2: Verify include_colors semantics tests**
- Run: `cd packages/flutterxel && flutter test test/flutterxel_api_surface_test.dart --plain-name "include_colors semantics"`
- Expected: PASS

**Step 3: Repair only if verification fails**
- Restore opt-in alpha mapping behavior and include_colors semantics docs/tests.

**Step 4: Commit (only if code changed)**
- `git add packages/flutterxel/lib/flutterxel.dart packages/flutterxel/test/flutterxel_api_surface_test.dart docs/site/guides/resources-and-persistence.md docs/site/reference/constants-and-compatibility.md`
- `git commit -m "fix: restore alpha policy and include_colors behavior contracts"`

---

### Task 6: Verify Agent Map Pipeline (No New File Creation)

**Files (only if drift exists):**
- Modify: `packages/flutterxel/example/tool/sync_reference_characters.sh`
- Modify: `packages/flutterxel/example/pubspec.yaml`
- Modify: `packages/flutterxel/example/lib/agent_map/character_manifest.dart`
- Modify: `packages/flutterxel/example/test/character_manifest_test.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/agent_state.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/agent_state_machine.dart`
- Modify: `packages/flutterxel/example/test/agent_state_machine_test.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/agent_map_controller.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/agent_map_scene.dart`
- Modify: `packages/flutterxel/example/lib/main.dart`
- Modify: `packages/flutterxel/example/test/agent_map_scene_smoke_test.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/activity_feed.dart`
- Modify: `packages/flutterxel/example/lib/agent_map/jsonl_activity_feed.dart`
- Modify: `packages/flutterxel/example/test/jsonl_activity_feed_test.dart`

**Step 1: Verify character sync + parser baseline**
- Run:
  - `./packages/flutterxel/example/tool/sync_reference_characters.sh`
  - `cd packages/flutterxel/example && flutter test test/character_manifest_test.dart`
- Expected: PASS

**Step 2: Verify state machine and scene baseline**
- Run:
  - `cd packages/flutterxel/example && flutter test test/agent_state_machine_test.dart`
  - `cd packages/flutterxel/example && flutter test test/agent_map_scene_smoke_test.dart`
- Expected: PASS

**Step 3: Verify activity feed adapter baseline**
- Run: `cd packages/flutterxel/example && flutter test test/jsonl_activity_feed_test.dart`
- Expected: PASS

**Step 4: Repair only if verification fails**
- Apply focused fixes to parser/state/render/feed files above. Do not introduce duplicate feature work.

**Step 5: Commit (only if code changed)**
- `git add packages/flutterxel/example/tool/sync_reference_characters.sh packages/flutterxel/example/pubspec.yaml packages/flutterxel/example/lib/agent_map/character_manifest.dart packages/flutterxel/example/test/character_manifest_test.dart packages/flutterxel/example/lib/agent_map/agent_state.dart packages/flutterxel/example/lib/agent_map/agent_state_machine.dart packages/flutterxel/example/test/agent_state_machine_test.dart packages/flutterxel/example/lib/agent_map/agent_map_controller.dart packages/flutterxel/example/lib/agent_map/agent_map_scene.dart packages/flutterxel/example/lib/main.dart packages/flutterxel/example/test/agent_map_scene_smoke_test.dart packages/flutterxel/example/lib/agent_map/activity_feed.dart packages/flutterxel/example/lib/agent_map/jsonl_activity_feed.dart packages/flutterxel/example/test/jsonl_activity_feed_test.dart`
- `git commit -m "fix: restore agent-map pipeline invariants"`

---

### Task 7: Docs Sync and End-to-End Verification

**Files:**
- Modify: `docs/site/guides/resources-and-persistence.md`
- Modify: `docs/site/reference/constants-and-compatibility.md`
- Modify: `docs/site/guides/agent-map-with-flutterxel.md`
- Modify: `packages/flutterxel/example/README.md`

**Step 1: Verify docs are aligned with runtime behavior**
- Confirm examples for:
  - alpha-aware import + `colkey`
  - backend mode/capability branching
  - character sync + example run/test commands

**Step 2: Run full verification commands**
- `dart run melos bootstrap`
- `cd packages/flutterxel && dart run ffigen --config ffigen.yaml`
- `./packages/flutterxel/tool/check_abi_contract.sh`
- `cd native/flutterxel_core && cargo fmt --check`
- `cd native/flutterxel_core && cargo test`
- `dart run melos run analyze`
- `dart run melos run test`
- `cd packages/flutterxel/example && flutter test`
- `HOST_LIB="$(./packages/flutterxel/tool/build_c_scaffold_host.sh)" && cd packages/flutterxel && FLUTTERXEL_FORCE_BACKEND=c_fallback FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" flutter test test/flutterxel_api_surface_test.dart --plain-name "c fallback blt image bank"`
- `HOST_LIB="$(./packages/flutterxel/tool/build_c_scaffold_host.sh)" && cd packages/flutterxel && FLUTTERXEL_FORCE_BACKEND=c_fallback FLUTTERXEL_LIBRARY_OVERRIDE="$HOST_LIB" flutter test test/flutterxel_api_surface_test.dart --plain-name "c fallback bltm tilemap id"`

**Step 3: Commit docs/plan rebaseline updates**
- `git add docs/site/guides/resources-and-persistence.md docs/site/reference/constants-and-compatibility.md docs/site/guides/agent-map-with-flutterxel.md packages/flutterxel/example/README.md docs/plans/2026-03-04-flutterxel-upstream-followups-and-agent-map-plan.md`
- `git commit -m "docs: rebaseline flutterxel upstream followups plan to current head"`

---

## Explicit Success Criteria

- All baseline verification commands in Tasks 1-7 pass on current `HEAD`.
- No task depends on a missing symbol/file that already exists on baseline.
- Agent-map related tasks use existing files as `Modify`, not `Create`.
- `2.1` source-selection regressions remain locked to forced `c_fallback` test mode.
- `2.2` and `2.3` behavior remains documented and test-locked.
- `2.4` backend mode/capability API remains stable and fail-closed on ABI mismatch.

## Risks and Mitigations

- Risk: backend loader behavior differs across host environments.
- Mitigation: keep forced fallback tests using `FLUTTERXEL_FORCE_BACKEND` + `FLUTTERXEL_LIBRARY_OVERRIDE`.

- Risk: docs drift from behavior.
- Mitigation: keep Task 7 as mandatory before completion claims.

- Risk: follow-up edits accidentally duplicate already-landed feature work.
- Mitigation: this plan is verification-first; apply only drift fixes when checks fail.
