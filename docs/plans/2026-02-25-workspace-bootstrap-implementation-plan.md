# Flutterxel Workspace Bootstrap Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a mobile-first Flutter + Rust FFI monorepo baseline with separated runtime and tooling packages.

**Architecture:** Use a single repository with two publishable Dart/Flutter packages (`flutterxel`, `flutterxel_tools`) and one Rust core crate (`native/flutterxel_core`). Keep runtime dependencies slim and move editor/CLI functionality to tools.

**Tech Stack:** Flutter plugin (FFI), Dart workspace, Melos, Rust `cdylib`/`staticlib`

---

### Task 1: Create Monorepo Workspace Baseline

**Files:**
- Create: `.gitignore`
- Create: `pubspec.yaml`
- Create: `melos.yaml`
- Create: `README.md`

**Step 1: Add root repository ignore rules**
- Add Flutter/Dart generated artifacts and IDE files.
- Add `reference/` to exclude mirrored reference source.

**Step 2: Add root workspace pubspec**
- Define non-publishable workspace root.
- Register both package paths in `workspace`.
- Add `melos` as dev dependency.

**Step 3: Add Melos orchestration config**
- Register package globs.
- Add shared scripts for analysis and tests.

**Step 4: Add root README**
- Document package boundaries, workspace commands, and license policy.

### Task 2: Add Architecture Documentation

**Files:**
- Create: `docs/architecture/2026-02-25-flutterxel-ffi-mobile-architecture.md`

**Step 1: Capture approved architecture decisions**
- Runtime package boundary (`flutterxel`)
- Tool package boundary (`flutterxel_tools`)
- Rust core location (`native/flutterxel_core`)

**Step 2: Define data flow**
- Dart API -> FFI -> Rust core.
- Rendering/input/audio responsibilities.

**Step 3: Define delivery/testing strategy**
- Binary distribution expectations.
- Multi-layer verification plan.

### Task 3: Add Rust Core Scaffold

**Files:**
- Create: `native/flutterxel_core/Cargo.toml`
- Create: `native/flutterxel_core/src/lib.rs`
- Create: `native/flutterxel_core/include/flutterxel_core.h`

**Step 1: Create Rust crate metadata**
- Set crate type for FFI consumption (`cdylib`, `staticlib`).

**Step 2: Add C ABI placeholder exports**
- Version exports.
- Engine lifecycle handle exports.
- Minimal frame buffer access exports.

**Step 3: Add C header for ABI contract**
- Define function signatures matching Rust exports.

### Task 4: Add Tooling Package CLI Skeleton

**Files:**
- Modify: `packages/flutterxel_tools/pubspec.yaml`
- Modify: `packages/flutterxel_tools/lib/flutterxel_tools.dart`
- Create: `packages/flutterxel_tools/bin/flutterxel_tools.dart`
- Modify: `packages/flutterxel_tools/README.md`

**Step 1: Register executable entrypoint in pubspec**
- Add `executables` section.

**Step 2: Replace placeholder library implementation**
- Provide command dispatch placeholder API.

**Step 3: Add CLI entrypoint**
- Add command parser with scaffolded command names.

**Step 4: Update README with current command status**
- Mark commands as scaffolded placeholders.

### Task 5: Align Licensing Metadata

**Files:**
- Create: `LICENSE`
- Modify: `packages/flutterxel/LICENSE`
- Modify: `packages/flutterxel_tools/LICENSE`

**Step 1: Add MIT license at repository root**

**Step 2: Sync package-level license files**
- Point to or copy MIT text for publishable packages.

### Task 6: Verify Workspace Bootstraps

**Files:**
- Verify: root workspace and package metadata

**Step 1: Run dependency bootstrap**
- Run `dart pub get` at repository root.

**Step 2: Run package discovery bootstrap**
- Run `dart run melos bootstrap`.

**Step 3: Run static analysis and tests**
- Run `dart run melos run analyze`.
- Run `dart run melos run test`.

**Step 4: Capture any failures and follow-up work**
- Record blockers and unresolved platform build tasks.
