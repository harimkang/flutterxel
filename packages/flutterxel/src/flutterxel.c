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
#define TILE_SIZE 8

typedef struct FlutterxelState {
  bool initialized;
  int32_t width;
  int32_t height;
  uint64_t frame_count;
  int32_t clear_color;
  int32_t camera_x;
  int32_t camera_y;
  int32_t clip_x;
  int32_t clip_y;
  int32_t clip_w;
  int32_t clip_h;
  int32_t palette_map[16];
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

static void reset_palette_map(void) {
  for (int32_t i = 0; i < 16; i++) {
    g_state.palette_map[i] = i;
  }
}

static int32_t apply_palette(int32_t col) {
  if (col < 0 || col >= 16) {
    return col;
  }
  return g_state.palette_map[col];
}

static bool set_frame_pixel(int32_t x, int32_t y, int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  int32_t sx = x - g_state.camera_x;
  int32_t sy = y - g_state.camera_y;
  if (sx < 0 || sx >= g_state.width || sy < 0 || sy >= g_state.height) {
    return true;
  }
  if (sx < g_state.clip_x || sy < g_state.clip_y) {
    return true;
  }
  if (sx >= g_state.clip_x + g_state.clip_w || sy >= g_state.clip_y + g_state.clip_h) {
    return true;
  }

  size_t index = (size_t)sy * (size_t)g_state.width + (size_t)sx;
  g_state.frame_buffer[index] = apply_palette(col);
  return true;
}

static int32_t get_frame_pixel(int32_t x, int32_t y) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return 0;
  }
  if (x < 0 || x >= g_state.width || y < 0 || y >= g_state.height) {
    return 0;
  }

  size_t index = (size_t)y * (size_t)g_state.width + (size_t)x;
  return g_state.frame_buffer[index];
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
  g_state.camera_x = 0;
  g_state.camera_y = 0;
  g_state.clip_x = 0;
  g_state.clip_y = 0;
  g_state.clip_w = width;
  g_state.clip_h = height;
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
  reset_palette_map();
  seed_default_image_bank();
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_quit(void) {
  if (g_state.frame_buffer != NULL) {
    free(g_state.frame_buffer);
    g_state.frame_buffer = NULL;
  }

  g_state.initialized = false;
  g_state.width = 0;
  g_state.height = 0;
  g_state.frame_count = 0;
  g_state.clear_color = 0;
  g_state.camera_x = 0;
  g_state.camera_y = 0;
  g_state.clip_x = 0;
  g_state.clip_y = 0;
  g_state.clip_w = 0;
  g_state.clip_h = 0;
  g_state.frame_buffer_len = 0;
  g_state.pressed_key_count = 0;
  g_state.released_key_count = 0;
  g_state.value_count = 0;
  g_state.image_bank_size = 0;
  memset(g_state.pressed_keys, 0, sizeof(g_state.pressed_keys));
  memset(g_state.pressed_key_frames, 0, sizeof(g_state.pressed_key_frames));
  memset(g_state.released_keys, 0, sizeof(g_state.released_keys));
  memset(g_state.released_key_frames, 0, sizeof(g_state.released_key_frames));
  memset(g_state.value_keys, 0, sizeof(g_state.value_keys));
  memset(g_state.value_values, 0, sizeof(g_state.value_values));
  memset(g_state.channel_state, 0, sizeof(g_state.channel_state));
  memset(g_state.image_bank0, 0, sizeof(g_state.image_bank0));
  reset_palette_map();
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

FFI_PLUGIN_EXPORT bool flutterxel_core_flip(void) {
  return flutterxel_core_run(NULL, NULL, NULL, NULL);
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

FFI_PLUGIN_EXPORT bool flutterxel_core_camera(int32_t x, int32_t y) {
  if (!g_state.initialized) {
    return false;
  }
  g_state.camera_x = x;
  g_state.camera_y = y;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_clip(
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h) {
  if (!g_state.initialized) {
    return false;
  }

  int32_t x0 = x;
  int32_t y0 = y;
  int32_t x1 = x + w;
  int32_t y1 = y + h;

  if (x0 < 0) x0 = 0;
  if (y0 < 0) y0 = 0;
  if (x1 < 0) x1 = 0;
  if (y1 < 0) y1 = 0;
  if (x0 > g_state.width) x0 = g_state.width;
  if (y0 > g_state.height) y0 = g_state.height;
  if (x1 > g_state.width) x1 = g_state.width;
  if (y1 > g_state.height) y1 = g_state.height;

  if (x1 < x0) {
    int32_t tmp = x1;
    x1 = x0;
    x0 = tmp;
  }
  if (y1 < y0) {
    int32_t tmp = y1;
    y1 = y0;
    y0 = tmp;
  }

  g_state.clip_x = x0;
  g_state.clip_y = y0;
  g_state.clip_w = x1 - x0;
  g_state.clip_h = y1 - y0;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_pal(int32_t col1, int32_t col2) {
  if (!g_state.initialized) {
    return false;
  }

  bool col1_none = col1 == OPTIONAL_I32_NONE;
  bool col2_none = col2 == OPTIONAL_I32_NONE;
  if (col1_none && col2_none) {
    reset_palette_map();
    return true;
  }
  if (col1_none && !col2_none) {
    return false;
  }

  if (col1 >= 0 && col1 < 16) {
    if (col2_none) {
      g_state.palette_map[col1] = col1;
    } else {
      g_state.palette_map[col1] = col2;
    }
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_pset(int32_t x, int32_t y, int32_t col) {
  return set_frame_pixel(x, y, col);
}

FFI_PLUGIN_EXPORT int32_t flutterxel_core_pget(int32_t x, int32_t y) {
  return get_frame_pixel(x, y);
}

FFI_PLUGIN_EXPORT bool flutterxel_core_line(
    int32_t x1,
    int32_t y1,
    int32_t x2,
    int32_t y2,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  int32_t dx = abs(x2 - x1);
  int32_t sx = x1 < x2 ? 1 : -1;
  int32_t dy = -abs(y2 - y1);
  int32_t sy = y1 < y2 ? 1 : -1;
  int32_t err = dx + dy;

  while (true) {
    set_frame_pixel(x1, y1, col);
    if (x1 == x2 && y1 == y2) {
      break;
    }
    int32_t e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x1 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y1 += sy;
    }
  }

  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_rect(
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }
  if (w <= 0 || h <= 0) {
    return true;
  }

  for (int32_t py = y; py < y + h; py++) {
    for (int32_t px = x; px < x + w; px++) {
      set_frame_pixel(px, py, col);
    }
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_rectb(
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }
  if (w <= 0 || h <= 0) {
    return true;
  }

  int32_t right = x + w - 1;
  int32_t bottom = y + h - 1;
  for (int32_t px = x; px <= right; px++) {
    set_frame_pixel(px, y, col);
    set_frame_pixel(px, bottom, col);
  }
  for (int32_t py = y + 1; py < bottom; py++) {
    set_frame_pixel(x, py, col);
    set_frame_pixel(right, py, col);
  }
  return true;
}

static void draw_circle_outline_points(
    int32_t cx,
    int32_t cy,
    int32_t x,
    int32_t y,
    int32_t col) {
  set_frame_pixel(cx + x, cy + y, col);
  set_frame_pixel(cx - x, cy + y, col);
  set_frame_pixel(cx + x, cy - y, col);
  set_frame_pixel(cx - x, cy - y, col);
  set_frame_pixel(cx + y, cy + x, col);
  set_frame_pixel(cx - y, cy + x, col);
  set_frame_pixel(cx + y, cy - x, col);
  set_frame_pixel(cx - y, cy - x, col);
}

FFI_PLUGIN_EXPORT bool flutterxel_core_circ(int32_t x, int32_t y, int32_t r, int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }
  if (r < 0) {
    return true;
  }

  for (int32_t dy = -r; dy <= r; dy++) {
    int64_t remain = (int64_t)r * (int64_t)r - (int64_t)dy * (int64_t)dy;
    int32_t max_dx = (int32_t)floor(sqrt((double)remain));
    for (int32_t dx = -max_dx; dx <= max_dx; dx++) {
      set_frame_pixel(x + dx, y + dy, col);
    }
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_circb(int32_t x, int32_t y, int32_t r, int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }
  if (r < 0) {
    return true;
  }

  int32_t px = r;
  int32_t py = 0;
  int32_t err = 1 - px;
  while (px >= py) {
    draw_circle_outline_points(x, y, px, py, col);
    py += 1;
    if (err < 0) {
      err += 2 * py + 1;
    } else {
      px -= 1;
      err += 2 * (py - px + 1);
    }
  }
  return true;
}

static int64_t edge_function(
    int32_t ax,
    int32_t ay,
    int32_t bx,
    int32_t by,
    int32_t px,
    int32_t py) {
  return (int64_t)(px - ax) * (int64_t)(by - ay) - (int64_t)(py - ay) * (int64_t)(bx - ax);
}

static int32_t min3_i32(int32_t a, int32_t b, int32_t c) {
  int32_t ab = a < b ? a : b;
  return ab < c ? ab : c;
}

static int32_t max3_i32(int32_t a, int32_t b, int32_t c) {
  int32_t ab = a > b ? a : b;
  return ab > c ? ab : c;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_tri(
    int32_t x1,
    int32_t y1,
    int32_t x2,
    int32_t y2,
    int32_t x3,
    int32_t y3,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  int32_t min_x = min3_i32(x1, x2, x3);
  int32_t max_x = max3_i32(x1, x2, x3);
  int32_t min_y = min3_i32(y1, y2, y3);
  int32_t max_y = max3_i32(y1, y2, y3);

  for (int32_t py = min_y; py <= max_y; py++) {
    for (int32_t px = min_x; px <= max_x; px++) {
      int64_t w1 = edge_function(x1, y1, x2, y2, px, py);
      int64_t w2 = edge_function(x2, y2, x3, y3, px, py);
      int64_t w3 = edge_function(x3, y3, x1, y1, px, py);
      bool all_non_negative = (w1 >= 0) && (w2 >= 0) && (w3 >= 0);
      bool all_non_positive = (w1 <= 0) && (w2 <= 0) && (w3 <= 0);
      if (all_non_negative || all_non_positive) {
        set_frame_pixel(px, py, col);
      }
    }
  }

  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_trib(
    int32_t x1,
    int32_t y1,
    int32_t x2,
    int32_t y2,
    int32_t x3,
    int32_t y3,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  if (!flutterxel_core_line(x1, y1, x2, y2, col)) {
    return false;
  }
  if (!flutterxel_core_line(x2, y2, x3, y3, col)) {
    return false;
  }
  if (!flutterxel_core_line(x3, y3, x1, y1, col)) {
    return false;
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_text(
    int32_t x,
    int32_t y,
    const char* text,
    int32_t col) {
  if (!g_state.initialized || g_state.frame_buffer == NULL || text == NULL) {
    return false;
  }

  int32_t cursor_x = x;
  int32_t cursor_y = y;
  int32_t line_start_x = x;
  for (size_t i = 0; text[i] != '\0'; i++) {
    char ch = text[i];
    if (ch == '\n') {
      cursor_x = line_start_x;
      cursor_y += 6;
      continue;
    }

    if (ch != ' ') {
      for (int32_t dy = 0; dy < 6; dy++) {
        for (int32_t dx = 0; dx < 4; dx++) {
          set_frame_pixel(cursor_x + dx, cursor_y + dy, col);
        }
      }
    }
    cursor_x += 4;
  }
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_bltm(
    double x,
    double y,
    int32_t tm,
    double u,
    double v,
    double w,
    double h,
    int32_t colkey) {
  (void)tm;
  if (!g_state.initialized || g_state.frame_buffer == NULL) {
    return false;
  }

  int32_t tiles_w = (int32_t)llround(fabs(w));
  int32_t tiles_h = (int32_t)llround(fabs(h));
  if (tiles_w <= 0 || tiles_h <= 0) {
    return true;
  }

  int32_t base_dx = (int32_t)llround(x);
  int32_t base_dy = (int32_t)llround(y);
  int32_t base_tx = (int32_t)llround(u);
  int32_t base_ty = (int32_t)llround(v);
  bool flip_x = w < 0;
  bool flip_y = h < 0;

  for (int32_t dy = 0; dy < tiles_h; dy++) {
    for (int32_t dx = 0; dx < tiles_w; dx++) {
      int32_t src_tile_x = base_tx + (flip_x ? (tiles_w - 1 - dx) : dx);
      int32_t src_tile_y = base_ty + (flip_y ? (tiles_h - 1 - dy) : dy);

      for (int32_t py = 0; py < TILE_SIZE; py++) {
        for (int32_t px = 0; px < TILE_SIZE; px++) {
          int32_t src_x = src_tile_x * TILE_SIZE + px;
          int32_t src_y = src_tile_y * TILE_SIZE + py;
          if (src_x < 0 || src_x >= g_state.image_bank_size || src_y < 0 ||
              src_y >= g_state.image_bank_size) {
            continue;
          }

          int32_t src_color = g_state.image_bank0[src_y * g_state.image_bank_size + src_x];
          if (colkey != OPTIONAL_I32_NONE && src_color == colkey) {
            continue;
          }

          int32_t dst_x = base_dx + dx * TILE_SIZE + px;
          int32_t dst_y = base_dy + dy * TILE_SIZE + py;
          set_frame_pixel(dst_x, dst_y, src_color);
        }
      }
    }
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
      set_frame_pixel(dst_x, dst_y, src_color);
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

FFI_PLUGIN_EXPORT bool flutterxel_core_playm(int32_t msc, bool loop) {
  (void)loop;

  if (!g_state.initialized || msc < 0) {
    return false;
  }

  memset(g_state.channel_state, 0, sizeof(g_state.channel_state));
  g_state.channel_state[0] = 1;
  return true;
}

FFI_PLUGIN_EXPORT bool flutterxel_core_stop(int32_t ch) {
  if (!g_state.initialized) {
    return false;
  }

  if (ch == OPTIONAL_I32_NONE) {
    memset(g_state.channel_state, 0, sizeof(g_state.channel_state));
    return true;
  }

  if (ch < 0 || ch >= CHANNEL_CAPACITY) {
    return true;
  }
  g_state.channel_state[ch] = 0;
  return true;
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
