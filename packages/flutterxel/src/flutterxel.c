#include "flutterxel.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ABI_VERSION_MAJOR 0
#define ABI_VERSION_MINOR 3
#define ABI_VERSION_PATCH 0
#define OPTIONAL_I32_NONE INT32_MIN
#define RESOURCE_MAGIC "FLUTTERXEL_RES_V1"
#define PRESSED_KEY_CAPACITY 1024
#define CHANNEL_CAPACITY 64
#define DEFAULT_IMAGE_BANK_SIZE 16

typedef struct FlutterxelState {
  bool initialized;
  int32_t width;
  int32_t height;
  uint64_t frame_count;
  int32_t clear_color;
  int32_t* frame_buffer;
  size_t frame_buffer_len;
  int32_t pressed_keys[PRESSED_KEY_CAPACITY];
  uint64_t pressed_key_frames[PRESSED_KEY_CAPACITY];
  size_t pressed_key_count;
  int32_t released_keys[PRESSED_KEY_CAPACITY];
  uint64_t released_key_frames[PRESSED_KEY_CAPACITY];
  size_t released_key_count;
  int32_t value_keys[PRESSED_KEY_CAPACITY];
  int32_t value_values[PRESSED_KEY_CAPACITY];
  size_t value_count;
  uint8_t channel_state[CHANNEL_CAPACITY];
  int32_t image_bank_size;
  int32_t image_bank0[DEFAULT_IMAGE_BANK_SIZE * DEFAULT_IMAGE_BANK_SIZE];
} FlutterxelState;

static FlutterxelState g_state = {0};

static bool is_valid_optional_bool(int8_t value) {
  return value == -1 || value == 0 || value == 1;
}

static void seed_default_image_bank(void) {
  g_state.image_bank_size = DEFAULT_IMAGE_BANK_SIZE;
  for (int y = 0; y < DEFAULT_IMAGE_BANK_SIZE; y++) {
    for (int x = 0; x < DEFAULT_IMAGE_BANK_SIZE; x++) {
      g_state.image_bank0[y * DEFAULT_IMAGE_BANK_SIZE + x] = (x + y) % 16;
    }
  }
}

static bool validate_resource_flags(
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics) {
  return is_valid_optional_bool(exclude_images) &&
         is_valid_optional_bool(exclude_tilemaps) &&
         is_valid_optional_bool(exclude_sounds) &&
         is_valid_optional_bool(exclude_musics);
}

static int find_pressed_key_index(int32_t key) {
  for (size_t i = 0; i < g_state.pressed_key_count; i++) {
    if (g_state.pressed_keys[i] == key) {
      return (int)i;
    }
  }
  return -1;
}

static int find_released_key_index(int32_t key) {
  for (size_t i = 0; i < g_state.released_key_count; i++) {
    if (g_state.released_keys[i] == key) {
      return (int)i;
    }
  }
  return -1;
}

static void remove_released_key_at(size_t index) {
  if (index >= g_state.released_key_count) {
    return;
  }
  size_t last_index = g_state.released_key_count - 1;
  if (index != last_index) {
    g_state.released_keys[index] = g_state.released_keys[last_index];
    g_state.released_key_frames[index] = g_state.released_key_frames[last_index];
  }
  g_state.released_keys[last_index] = 0;
  g_state.released_key_frames[last_index] = 0;
  g_state.released_key_count -= 1;
}

static int find_value_key_index(int32_t key) {
  for (size_t i = 0; i < g_state.value_count; i++) {
    if (g_state.value_keys[i] == key) {
      return (int)i;
    }
  }
  return -1;
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

  if (g_state.frame_buffer != NULL) {
    free(g_state.frame_buffer);
    g_state.frame_buffer = NULL;
  }

  g_state.frame_buffer_len = (size_t)width * (size_t)height;
  g_state.frame_buffer = (int32_t*)calloc(g_state.frame_buffer_len, sizeof(int32_t));
  if (g_state.frame_buffer == NULL) {
    g_state.frame_buffer_len = 0;
    return false;
  }

  g_state.initialized = true;
  g_state.width = width;
  g_state.height = height;
  g_state.frame_count = 0;
  g_state.clear_color = 0;
  g_state.pressed_key_count = 0;
  g_state.released_key_count = 0;
  g_state.value_count = 0;
  memset(g_state.pressed_keys, 0, sizeof(g_state.pressed_keys));
  memset(g_state.pressed_key_frames, 0, sizeof(g_state.pressed_key_frames));
  memset(g_state.released_keys, 0, sizeof(g_state.released_keys));
  memset(g_state.released_key_frames, 0, sizeof(g_state.released_key_frames));
  memset(g_state.value_keys, 0, sizeof(g_state.value_keys));
  memset(g_state.value_values, 0, sizeof(g_state.value_values));
  memset(g_state.channel_state, 0, sizeof(g_state.channel_state));
  seed_default_image_bank();
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
  for (size_t i = 0; i < g_state.released_key_count;) {
    if (g_state.released_key_frames[i] == g_state.frame_count) {
      i += 1;
      continue;
    }
    remove_released_key_at(i);
  }

  if (update != NULL) {
    update(update_user_data);
  }
  if (draw != NULL) {
    draw(draw_user_data);
  }

  return true;
}

FFI_PLUGIN_EXPORT uint64_t flutterxel_core_frame_count(void) {
  if (!g_state.initialized) {
    return 0;
  }
  return g_state.frame_count;
}

FFI_PLUGIN_EXPORT const int32_t* flutterxel_core_framebuffer_ptr(void) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return NULL;
  }
  return g_state.frame_buffer;
}

FFI_PLUGIN_EXPORT size_t flutterxel_core_framebuffer_len(void) {
  if (!g_state.initialized) {
    return 0;
  }
  return g_state.frame_buffer_len;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_btn(int32_t key) {
  if (!g_state.initialized) {
    return false;
  }
  return find_pressed_key_index(key) >= 0;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_btnp(int32_t key,
                                             int32_t hold,
                                             int32_t period) {
  if (!g_state.initialized) {
    return false;
  }

  int pressed_index = find_pressed_key_index(key);
  if (pressed_index < 0) {
    return false;
  }

  uint64_t pressed_frame = g_state.pressed_key_frames[(size_t)pressed_index];
  uint64_t elapsed = g_state.frame_count - pressed_frame;
  if (elapsed == 0) {
    return true;
  }
  if (hold <= 0 || period <= 0) {
    return false;
  }

  uint64_t hold_u = (uint64_t)hold;
  uint64_t period_u = (uint64_t)period;
  if (elapsed < hold_u) {
    return false;
  }
  return ((elapsed - hold_u) % period_u) == 0;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_btnr(int32_t key) {
  if (!g_state.initialized) {
    return false;
  }

  int released_index = find_released_key_index(key);
  if (released_index < 0) {
    return false;
  }
  return g_state.released_key_frames[(size_t)released_index] == g_state.frame_count;
}

FFI_PLUGIN_EXPORT int32_t flutterxel_core_btnv(int32_t key) {
  if (!g_state.initialized) {
    return 0;
  }
  int value_index = find_value_key_index(key);
  if (value_index < 0) {
    return 0;
  }
  return g_state.value_values[(size_t)value_index];
}

FFI_PLUGIN_EXPORT bool flutterxel_core_set_btn_state(int32_t key, bool pressed) {
  if (!g_state.initialized) {
    return false;
  }

  int existing_index = find_pressed_key_index(key);
  if (pressed) {
    if (existing_index >= 0) {
      return true;
    }
    if (g_state.pressed_key_count >= PRESSED_KEY_CAPACITY) {
      return false;
    }
    size_t index = g_state.pressed_key_count;
    g_state.pressed_keys[index] = key;
    g_state.pressed_key_frames[index] = g_state.frame_count;
    g_state.pressed_key_count += 1;
    int released_index = find_released_key_index(key);
    if (released_index >= 0) {
      remove_released_key_at((size_t)released_index);
    }
    int value_index = find_value_key_index(key);
    if (value_index >= 0) {
      g_state.value_values[(size_t)value_index] = 1;
    } else {
      if (g_state.value_count >= PRESSED_KEY_CAPACITY) {
        return false;
      }
      size_t slot = g_state.value_count;
      g_state.value_keys[slot] = key;
      g_state.value_values[slot] = 1;
      g_state.value_count += 1;
    }
    return true;
  }

  if (existing_index < 0) {
    return true;
  }

  size_t index = (size_t)existing_index;
  size_t last_index = g_state.pressed_key_count - 1;
  if (index != last_index) {
    g_state.pressed_keys[index] = g_state.pressed_keys[last_index];
    g_state.pressed_key_frames[index] = g_state.pressed_key_frames[last_index];
  }
  g_state.pressed_keys[last_index] = 0;
  g_state.pressed_key_frames[last_index] = 0;
  g_state.pressed_key_count -= 1;

  int released_index = find_released_key_index(key);
  if (released_index >= 0) {
    g_state.released_key_frames[(size_t)released_index] = g_state.frame_count;
    return true;
  }
  if (g_state.released_key_count >= PRESSED_KEY_CAPACITY) {
    return false;
  }
  size_t release_slot = g_state.released_key_count;
  g_state.released_keys[release_slot] = key;
  g_state.released_key_frames[release_slot] = g_state.frame_count;
  g_state.released_key_count += 1;

  int value_index = find_value_key_index(key);
  if (value_index >= 0) {
    g_state.value_values[(size_t)value_index] = 0;
  } else {
    if (g_state.value_count >= PRESSED_KEY_CAPACITY) {
      return false;
    }
    size_t slot = g_state.value_count;
    g_state.value_keys[slot] = key;
    g_state.value_values[slot] = 0;
    g_state.value_count += 1;
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_set_btn_value(int32_t key, int32_t value) {
  if (!g_state.initialized) {
    return false;
  }

  int value_index = find_value_key_index(key);
  if (value_index >= 0) {
    g_state.value_values[(size_t)value_index] = value;
    return true;
  }

  if (g_state.value_count >= PRESSED_KEY_CAPACITY) {
    return false;
  }
  size_t slot = g_state.value_count;
  g_state.value_keys[slot] = key;
  g_state.value_values[slot] = value;
  g_state.value_count += 1;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_cls(int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  g_state.clear_color = col;
  for (size_t i = 0; i < g_state.frame_buffer_len; i++) {
    g_state.frame_buffer[i] = col;
  }
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
  (void)img;
  (void)rotate;
  (void)scale;

  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  int32_t width = (int32_t)llround(fabs(w));
  int32_t height = (int32_t)llround(fabs(h));
  if (width <= 0 || height <= 0) {
    return true;
  }

  int32_t base_dx = (int32_t)llround(x);
  int32_t base_dy = (int32_t)llround(y);
  int32_t base_sx = (int32_t)llround(u);
  int32_t base_sy = (int32_t)llround(v);
  bool flip_x = w < 0;
  bool flip_y = h < 0;

  for (int32_t dy = 0; dy < height; dy++) {
    for (int32_t dx = 0; dx < width; dx++) {
      int32_t src_x = base_sx + (flip_x ? (width - 1 - dx) : dx);
      int32_t src_y = base_sy + (flip_y ? (height - 1 - dy) : dy);

      if (src_x < 0 || src_x >= g_state.image_bank_size || src_y < 0 ||
          src_y >= g_state.image_bank_size) {
        continue;
      }

      int32_t src_color = g_state.image_bank0[src_y * g_state.image_bank_size + src_x];
      if (colkey != OPTIONAL_I32_NONE && src_color == colkey) {
        continue;
      }

      int32_t dst_x = base_dx + dx;
      int32_t dst_y = base_dy + dy;
      if (dst_x < 0 || dst_x >= g_state.width || dst_y < 0 || dst_y >= g_state.height) {
        continue;
      }

      size_t dst_index = (size_t)dst_y * (size_t)g_state.width + (size_t)dst_x;
      g_state.frame_buffer[dst_index] = src_color;
    }
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
  (void)snd_value;
  (void)sec;

  if (!g_state.initialized) {
    return false;
  }
  if (!is_valid_optional_bool(loop) || !is_valid_optional_bool(resume)) {
    return false;
  }
  if (ch < 0 || ch >= CHANNEL_CAPACITY) {
    return false;
  }

  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_INT) {
    g_state.channel_state[ch] = 1;
    return true;
  }
  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_INT_LIST) {
    if (snd_sequence_len > 0 && snd_sequence_ptr == NULL) {
      return false;
    }
    g_state.channel_state[ch] = 1;
    return true;
  }
  if (snd_kind == FLUTTERXEL_CORE_PLAY_SND_STRING) {
    if (snd_string == NULL || strlen(snd_string) == 0) {
      return false;
    }
    g_state.channel_state[ch] = 1;
    return true;
  }

  return false;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_is_channel_playing(int32_t ch) {
  if (!g_state.initialized || ch < 0 || ch >= CHANNEL_CAPACITY) {
    return false;
  }
  return g_state.channel_state[ch] != 0;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_load(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics) {
  if (!g_state.initialized || filename == NULL || strlen(filename) == 0) {
    return false;
  }
  if (!validate_resource_flags(exclude_images, exclude_tilemaps, exclude_sounds,
                               exclude_musics)) {
    return false;
  }

  FILE* fp = fopen(filename, "rb");
  if (fp == NULL) {
    return false;
  }

  char magic[32] = {0};
  size_t read_count = fread(magic, 1, strlen(RESOURCE_MAGIC), fp);
  fclose(fp);

  if (read_count != strlen(RESOURCE_MAGIC)) {
    return false;
  }
  return memcmp(magic, RESOURCE_MAGIC, strlen(RESOURCE_MAGIC)) == 0;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_save(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics) {
  if (!g_state.initialized || filename == NULL || strlen(filename) == 0) {
    return false;
  }
  if (!validate_resource_flags(exclude_images, exclude_tilemaps, exclude_sounds,
                               exclude_musics)) {
    return false;
  }

  FILE* fp = fopen(filename, "wb");
  if (fp == NULL) {
    return false;
  }

  fprintf(fp,
          "%s\nwidth=%d\nheight=%d\nframe_count=%llu\nclear_color=%d\n",
          RESOURCE_MAGIC,
          g_state.width,
          g_state.height,
          (unsigned long long)g_state.frame_count,
          g_state.clear_color);
  fclose(fp);
  return true;
}
