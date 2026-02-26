#ifndef FLUTTERXEL_CORE_H_
#define FLUTTERXEL_CORE_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined(_WIN32)
#define FLUTTERXEL_CORE_EXPORT __declspec(dllexport)
#else
#define FLUTTERXEL_CORE_EXPORT
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

FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_major(void);
FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_minor(void);
FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_patch(void);

// pyxel.init(width, height, *, title=None, fps=None, quit_key=None,
//            display_scale=None, capture_scale=None, capture_sec=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_init(
    int32_t width,
    int32_t height,
    const char* title,
    int32_t fps,
    int32_t quit_key,
    int32_t display_scale,
    int32_t capture_scale,
    int32_t capture_sec);

// pyxel.quit()
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_quit(void);

// pyxel.run(update, draw)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_run(
    FlutterxelCoreFrameCallback update,
    void* update_user_data,
    FlutterxelCoreFrameCallback draw,
    void* draw_user_data);

// pyxel.flip()
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_flip(void);

FLUTTERXEL_CORE_EXPORT uint64_t flutterxel_core_frame_count(void);
FLUTTERXEL_CORE_EXPORT const int32_t* flutterxel_core_framebuffer_ptr(void);
FLUTTERXEL_CORE_EXPORT size_t flutterxel_core_framebuffer_len(void);

// pyxel.btn(key)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_btn(int32_t key);
// pyxel.btnp(key, *, hold=0, period=0)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_btnp(int32_t key,
                                                  int32_t hold,
                                                  int32_t period);
// pyxel.btnr(key)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_btnr(int32_t key);
// pyxel.btnv(key)
FLUTTERXEL_CORE_EXPORT int32_t flutterxel_core_btnv(int32_t key);
// pyxel.mouse(visible)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_mouse(bool visible);
// pyxel.warp_mouse(x, y)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_warp_mouse(double x, double y);

// runtime input bridge
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_set_btn_state(int32_t key,
                                                           bool pressed);
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_set_btn_value(int32_t key,
                                                           int32_t value);

// pyxel.cls(col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_cls(int32_t col);
// pyxel.camera(x=0, y=0)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_camera(int32_t x, int32_t y);
// pyxel.clip(x=None, y=None, w=None, h=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_clip(int32_t x,
                                                 int32_t y,
                                                 int32_t w,
                                                 int32_t h);
// pyxel.pal(col1=None, col2=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_pal(int32_t col1, int32_t col2);

// pyxel.pset(x, y, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_pset(int32_t x,
                                                 int32_t y,
                                                 int32_t col);
// pyxel.pget(x, y)
FLUTTERXEL_CORE_EXPORT int32_t flutterxel_core_pget(int32_t x, int32_t y);
// pyxel.line(x1, y1, x2, y2, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_line(int32_t x1,
                                                 int32_t y1,
                                                 int32_t x2,
                                                 int32_t y2,
                                                 int32_t col);
// pyxel.rect(x, y, w, h, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_rect(int32_t x,
                                                 int32_t y,
                                                 int32_t w,
                                                 int32_t h,
                                                 int32_t col);
// pyxel.rectb(x, y, w, h, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_rectb(int32_t x,
                                                  int32_t y,
                                                  int32_t w,
                                                  int32_t h,
                                                  int32_t col);
// pyxel.circ(x, y, r, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_circ(int32_t x,
                                                 int32_t y,
                                                 int32_t r,
                                                 int32_t col);
// pyxel.circb(x, y, r, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_circb(int32_t x,
                                                  int32_t y,
                                                  int32_t r,
                                                  int32_t col);
// pyxel.elli(x, y, w, h, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_elli(int32_t x,
                                                 int32_t y,
                                                 int32_t w,
                                                 int32_t h,
                                                 int32_t col);
// pyxel.ellib(x, y, w, h, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_ellib(int32_t x,
                                                  int32_t y,
                                                  int32_t w,
                                                  int32_t h,
                                                  int32_t col);
// pyxel.tri(x1, y1, x2, y2, x3, y3, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_tri(int32_t x1,
                                                int32_t y1,
                                                int32_t x2,
                                                int32_t y2,
                                                int32_t x3,
                                                int32_t y3,
                                                int32_t col);
// pyxel.trib(x1, y1, x2, y2, x3, y3, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_trib(int32_t x1,
                                                 int32_t y1,
                                                 int32_t x2,
                                                 int32_t y2,
                                                 int32_t x3,
                                                 int32_t y3,
                                                 int32_t col);
// pyxel.fill(x, y, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_fill(int32_t x,
                                                 int32_t y,
                                                 int32_t col);
// pyxel.text(x, y, s, col)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_text(int32_t x,
                                                 int32_t y,
                                                 const char* text,
                                                 int32_t col);
// pyxel.bltm(x, y, tm, u, v, w, h, colkey=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_bltm(double x,
                                                 double y,
                                                 int32_t tm,
                                                 double u,
                                                 double v,
                                                 double w,
                                                 double h,
                                                 int32_t colkey);

// pyxel.blt(x, y, img, u, v, w, h, colkey=None, *, rotate=None, scale=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_blt(
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

// pyxel.play(ch, snd, *, sec=None, loop=None, resume=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_play(
    int32_t ch,
    int32_t snd_kind,
    int32_t snd_value,
    const int32_t* snd_sequence_ptr,
    size_t snd_sequence_len,
    const char* snd_string,
    double sec,
    int8_t loop,
    int8_t resume);

// pyxel.playm(msc, *, loop=False)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_playm(int32_t msc, bool loop);

// pyxel.stop(ch=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_stop(int32_t ch);

FLUTTERXEL_CORE_EXPORT bool flutterxel_core_is_channel_playing(int32_t ch);
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_play_pos(int32_t ch,
                                                     int32_t* snd,
                                                     double* pos);

// pyxel.rseed(seed)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_rseed(int32_t seed);
// pyxel.rndi(a, b)
FLUTTERXEL_CORE_EXPORT int32_t flutterxel_core_rndi(int32_t a, int32_t b);
// pyxel.rndf(a, b)
FLUTTERXEL_CORE_EXPORT double flutterxel_core_rndf(double a, double b);

// pyxel.load(filename, *, exclude_images=None, exclude_tilemaps=None,
//            exclude_sounds=None, exclude_musics=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_load(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics);

// pyxel.save(filename, *, exclude_images=None, exclude_tilemaps=None,
//            exclude_sounds=None, exclude_musics=None)
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_save(
    const char* filename,
    int8_t exclude_images,
    int8_t exclude_tilemaps,
    int8_t exclude_sounds,
    int8_t exclude_musics);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // FLUTTERXEL_CORE_H_
