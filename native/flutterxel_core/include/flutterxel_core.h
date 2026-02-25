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

FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_major(void);
FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_minor(void);
FLUTTERXEL_CORE_EXPORT uint32_t flutterxel_core_version_patch(void);

FLUTTERXEL_CORE_EXPORT uint64_t flutterxel_core_engine_new(uint32_t width, uint32_t height,
                                                           uint32_t fps);
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_engine_free(uint64_t handle);
FLUTTERXEL_CORE_EXPORT bool flutterxel_core_engine_tick(uint64_t handle, float delta_ms);
FLUTTERXEL_CORE_EXPORT const uint8_t* flutterxel_core_engine_frame_ptr(uint64_t handle);
FLUTTERXEL_CORE_EXPORT size_t flutterxel_core_engine_frame_len(uint64_t handle);
FLUTTERXEL_CORE_EXPORT uint64_t flutterxel_core_engine_frame_count(uint64_t handle);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // FLUTTERXEL_CORE_H_

