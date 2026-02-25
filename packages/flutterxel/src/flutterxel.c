#include "flutterxel.h"

#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define ABI_VERSION_MAJOR 0
#define ABI_VERSION_MINOR 2
#define ABI_VERSION_PATCH 0

typedef struct FlutterxelState {
  bool initialized;
  int32_t width;
  int32_t height;
  uint64_t frame_count;
  int32_t clear_color;
} FlutterxelState;

static FlutterxelState g_state = {0};

static bool is_valid_optional_bool(int8_t value) {
  return value == -1 || value == 0 || value == 1;
}

FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_major(void) {
  return ABI_VERSION_MAJOR;
}

FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_minor(void) {
  return ABI_VERSION_MINOR;
}

FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_patch(void) {
  return ABI_VERSION_PATCH;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_init(
    int32_t width,
    int32_t height,
    const char* title,
    int32_t fps,
    int32_t quit_key,
    int32_t display_scale,
    int32_t capture_scale,
    int32_t capture_sec) {
  (void)title;
  (void)fps;
  (void)quit_key;
  (void)display_scale;
  (void)capture_scale;
  (void)capture_sec;

  if (width <= 0 || height <= 0) {
    return false;
  }

  g_state.initialized = true;
  g_state.width = width;
  g_state.height = height;
  g_state.frame_count = 0;
  g_state.clear_color = 0;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_run(
    FlutterxelCoreFrameCallback update,
    void* update_user_data,
    FlutterxelCoreFrameCallback draw,
    void* draw_user_data) {
  if (!g_state.initialized) {
    return false;
  }

  g_state.frame_count += 1;

  if (update != NULL) {
    update(update_user_data);
  }
  if (draw != NULL) {
    draw(draw_user_data);
  }

  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_btn(int32_t key) {
  (void)key;
  if (!g_state.initialized) {
    return false;
  }
  return false;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_cls(int32_t col) {
  if (!g_state.initialized) {
    return false;
  }
  g_state.clear_color = col;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_blt(
    double x,
    double y,
    int32_t img,
    double u,
    double v,
    double w,
    double h,
    int32_t colkey,
    double rotate,
    double scale) {
  (void)x;
  (void)y;
  (void)img;
  (void)u;
  (void)v;
  (void)w;
  (void)h;
  (void)colkey;
  (void)rotate;
  (void)scale;

  if (!g_state.initialized) {
    return false;
  }

  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_play(
    int32_t ch,
    int32_t snd_kind,
    int32_t snd_value,
    const int32_t* snd_sequence_ptr,
    size_t snd_sequence_len,
    const char* snd_string,
    double sec,
    int8_t loop,
    int8_t resume) {
  (void)ch;
  (void)snd_value;
  (void)sec;

  if (!g_state.initialized) {
    return false;
  }

  if (!is_valid_optional_bool(loop) || !is_valid_optional_bool(resume)) {
    return false;
  }

  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_INT) {
    return true;
  }

  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_INT_LIST) {
    if (snd_sequence_len > 0 && snd_sequence_ptr == NULL) {
      return false;
    }
    return true;
  }

  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_STRING) {
    if (snd_string == NULL || strlen(snd_string) == 0) {
      return false;
    }
    return true;
  }

  return false;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_load(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics) {
  (void)exclude_images;
  (void)exclude_tilemaps;
  (void)exclude_sounds;
  (void)exclude_musics;

  if (!g_state.initialized) {
    return false;
  }

  if (filename == NULL || strlen(filename) == 0) {
    return false;
  }

  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_save(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics) {
  (void)exclude_images;
  (void)exclude_tilemaps;
  (void)exclude_sounds;
  (void)exclude_musics;

  if (!g_state.initialized) {
    return false;
  }

  if (filename == NULL || strlen(filename) == 0) {
    return false;
  }

  return true;
}
