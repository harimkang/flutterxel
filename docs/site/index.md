# flutterxel

`flutterxel` is a Flutter plugin that provides a Pyxel-style runtime API backed by a Rust core.

![flutterxel showcase](assets/images/flutterxel.png)

This documentation focuses on practical usage of the plugin package at:

- `packages/flutterxel`

If you want to explore complete sample games, see:

- `examples/star_patrol`
- `examples/pixel_puzzle`
- `examples/void_runner`
- `examples/cosmic_survivor`

## What You Get

- Pyxel-style drawing and input APIs (`cls`, `pset`, `line`, `rect`, `btn`, `btnp`, etc.)
- Audio APIs (`play`, `playm`, `stop`, `sounds`, `musics`, `channels`)
- Resource objects (`Image`, `Tilemap`, `Sound`, `Music`, `Tone`, `Seq`)
- A Flutter widget (`FlutterxelView`) to render the frame buffer and bridge input
- Camel-case and snake_case API aliases for compatibility

## Start Here

1. [Installation](getting-started/installation.md)
2. [Build your first app](getting-started/first-app.md)
3. [Read the guides](guides/game-loop-and-rendering.md)
4. [Open API reference](reference/api.md)

## Tooling Guide

- [Pixel Snap Asset Preprocessing](guides/pixel-snap-asset-preprocessing.md): preprocess external/AI-generated images into grid-aligned palette assets before runtime use.

## API Reference Policy

The API reference is generated automatically from source code with `dart doc` during docs build/deploy.
No hand-written API signatures are maintained in this site.
