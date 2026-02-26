#ifndef FLUTTERXEL_PLUGIN_H_
#define FLUTTERXEL_PLUGIN_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Optional parameter encoding in ABI:
// - optional int32: INT32_MIN means None
// - optional float64: NaN means None
// - optional bool: -1 means None, 0 means false, 1 means true

typedef enum FlutterxelCorePlaySndKind {
  FLUTTERXEL_CORE_PLAY_SND_INT = 0,
  FLUTTERXEL_CORE_PLAY_SND_INT_LIST = 1,
  FLUTTERXEL_CORE_PLAY_SND_STRING = 2,
} FlutterxelCorePlaySndKind;

typedef void (*FlutterxelCoreFrameCallback)(void* user_data);

FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_major(void);
FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_minor(void);
FFI_PLUGIN_EXPORT uint32_t flutterxel_core_version_patch(void);

FFI_PLUGIN_EXPORT bool flutterxel_core_init(
    int32_t width,
    int32_t height,
    const char* title,
    int32_t fps,
    int32_t quit_key,
    int32_t display_scale,
    int32_t capture_scale,
    int32_t capture_sec);

FFI_PLUGIN_EXPORT bool flutterxel_core_quit(void);

FFI_PLUGIN_EXPORT bool flutterxel_core_run(
    FlutterxelCoreFrameCallback update,
    void* update_user_data,
    FlutterxelCoreFrameCallback draw,
    void* draw_user_data);

FFI_PLUGIN_EXPORT bool flutterxel_core_flip(void);

FFI_PLUGIN_EXPORT uint64_t flutterxel_core_frame_count(void);
FFI_PLUGIN_EXPORT const int32_t* flutterxel_core_framebuffer_ptr(void);
FFI_PLUGIN_EXPORT size_t flutterxel_core_framebuffer_len(void);

FFI_PLUGIN_EXPORT bool flutterxel_core_btn(int32_t key);
FFI_PLUGIN_EXPORT bool flutterxel_core_btnp(int32_t key,
                                             int32_t hold,
                                             int32_t period);
FFI_PLUGIN_EXPORT bool flutterxel_core_btnr(int32_t key);
FFI_PLUGIN_EXPORT int32_t flutterxel_core_btnv(int32_t key);
FFI_PLUGIN_EXPORT bool flutterxel_core_set_btn_state(int32_t key,
                                                      bool pressed);
FFI_PLUGIN_EXPORT bool flutterxel_core_set_btn_value(int32_t key,
                                                      int32_t value);
FFI_PLUGIN_EXPORT bool flutterxel_core_cls(int32_t col);

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
    double scale);

FFI_PLUGIN_EXPORT bool flutterxel_core_play(
    int32_t ch,
    int32_t snd_kind,
    int32_t snd_value,
    const int32_t* snd_sequence_ptr,
    size_t snd_sequence_len,
    const char* snd_string,
    double sec,
    int8_t loop,
    int8_t resume);

FFI_PLUGIN_EXPORT bool flutterxel_core_playm(int32_t msc, bool loop);

FFI_PLUGIN_EXPORT bool flutterxel_core_stop(int32_t ch);

FFI_PLUGIN_EXPORT bool flutterxel_core_is_channel_playing(int32_t ch);

FFI_PLUGIN_EXPORT bool flutterxel_core_load(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics);

FFI_PLUGIN_EXPORT bool flutterxel_core_save(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // FLUTTERXEL_PLUGIN_H_
