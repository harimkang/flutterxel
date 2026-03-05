#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"
NATIVE_HEADER="$ROOT_DIR/native/flutterxel_core/include/flutterxel_core.h"
PLUGIN_HEADER="$ROOT_DIR/packages/flutterxel/src/flutterxel.h"
BINDINGS="$ROOT_DIR/packages/flutterxel/lib/flutterxel_bindings_generated.dart"

SYMBOLS=(
  flutterxel_core_version_major
  flutterxel_core_version_minor
  flutterxel_core_version_patch
  flutterxel_core_backend_kind
  flutterxel_core_init
  flutterxel_core_quit
  flutterxel_core_run
  flutterxel_core_flip
  flutterxel_core_show
  flutterxel_core_title
  flutterxel_core_icon
  flutterxel_core_reset
  flutterxel_core_perf_monitor
  flutterxel_core_integer_scale
  flutterxel_core_screen_mode
  flutterxel_core_fullscreen
  flutterxel_core_btn
  flutterxel_core_btnp
  flutterxel_core_btnr
  flutterxel_core_btnv
  flutterxel_core_mouse
  flutterxel_core_warp_mouse
  flutterxel_core_set_btn_state
  flutterxel_core_set_btn_value
  flutterxel_core_cls
  flutterxel_core_camera
  flutterxel_core_clip
  flutterxel_core_pal
  flutterxel_core_dither
  flutterxel_core_pset
  flutterxel_core_pget
  flutterxel_core_line
  flutterxel_core_rect
  flutterxel_core_rectb
  flutterxel_core_circ
  flutterxel_core_circb
  flutterxel_core_elli
  flutterxel_core_ellib
  flutterxel_core_tri
  flutterxel_core_trib
  flutterxel_core_fill
  flutterxel_core_text
  flutterxel_core_bltm
  flutterxel_core_blt
  flutterxel_core_image_pset
  flutterxel_core_image_pget
  flutterxel_core_image_cls
  flutterxel_core_image_replace
  flutterxel_core_tilemap_pset
  flutterxel_core_tilemap_pget
  flutterxel_core_tilemap_cls
  flutterxel_core_tilemap_set_imgsrc
  flutterxel_core_sound_set_notes
  flutterxel_core_sound_set_tones
  flutterxel_core_sound_set_volumes
  flutterxel_core_sound_set_effects
  flutterxel_core_sound_set_speed
  flutterxel_core_music_set_seq
  flutterxel_core_play
  flutterxel_core_playm
  flutterxel_core_stop
  flutterxel_core_is_channel_playing
  flutterxel_core_play_pos
  flutterxel_core_rseed
  flutterxel_core_rndi
  flutterxel_core_rndf
  flutterxel_core_nseed
  flutterxel_core_noise
  flutterxel_core_ceil
  flutterxel_core_floor
  flutterxel_core_clamp_i64
  flutterxel_core_clamp_f64
  flutterxel_core_sgn_i64
  flutterxel_core_sgn_f64
  flutterxel_core_sqrt
  flutterxel_core_sin
  flutterxel_core_cos
  flutterxel_core_atan2
  flutterxel_core_load
  flutterxel_core_save
  flutterxel_core_load_pal
  flutterxel_core_save_pal
  flutterxel_core_screenshot
  flutterxel_core_screencast
  flutterxel_core_reset_screencast
  flutterxel_core_frame_count
  flutterxel_core_framebuffer_ptr
  flutterxel_core_framebuffer_len
  flutterxel_core_copy_framebuffer
)

contains_symbol() {
  local symbol="$1"
  local file_path="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q --fixed-strings "$symbol" "$file_path"
    return
  fi
  grep -Fq -- "$symbol" "$file_path"
}

for symbol in "${SYMBOLS[@]}"; do
  if ! contains_symbol "$symbol" "$NATIVE_HEADER"; then
    echo "Missing symbol in native header: $symbol" >&2
    exit 1
  fi
  if ! contains_symbol "$symbol" "$PLUGIN_HEADER"; then
    echo "Missing symbol in plugin header: $symbol" >&2
    exit 1
  fi
  if ! contains_symbol "$symbol" "$BINDINGS"; then
    echo "Missing symbol in Dart bindings: $symbol" >&2
    exit 1
  fi

done

echo "ABI contract check passed (${#SYMBOLS[@]} symbols)."
