# Pixel Snap Asset Preprocessing

Use `flutterxel_tools pixel-snap` when source images are not aligned to retro pixel-art constraints and you want consistent in-game rendering.

This command runs in the tooling layer and does not change runtime APIs in `packages/flutterxel`.

## When to Use

- AI-generated sprites with blurry anti-aliased edges
- Artwork made at arbitrary resolution that must be reduced to a fixed palette
- External assets that look inconsistent with your game's pixel style

## Prerequisites

- Rust/Cargo installed and available on `PATH`
- Repository checkout contains `reference/spritefusion-pixel-snapper`
- Input image file exists

## Command Usage

Basic conversion:

```bash
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.png
```

Conversion with explicit color count and overwrite:

```bash
dart run flutterxel_tools:flutterxel_tools pixel-snap --input assets/raw/hero.png --output assets/pixel/hero.snapped.png --colors 16 --overwrite
```

Arguments:

- `--input` (required): source image path
- `--output` (required): output image path
- `--colors` (optional): palette count (default `16`)
- `--overwrite` (optional): replace output if file already exists

## Recommended Workflow

1. Keep original files under `assets/raw/`.
2. Generate snapped files under `assets/pixel/`.
3. Reference only snapped files in app/runtime code.
4. Regenerate snapped files whenever source art changes.

This keeps source assets editable while preserving deterministic runtime visuals.

## Troubleshooting

`Input file not found`:

- Verify the `--input` path relative to your current working directory.

`Output file already exists`:

- Pass `--overwrite`, or choose a different `--output` file path.

`Invalid --colors value`:

- Use a positive integer (for example `8`, `16`, `32`).

`SpriteFusion manifest not found`:

- Confirm repository structure includes `reference/spritefusion-pixel-snapper/Cargo.toml`.
