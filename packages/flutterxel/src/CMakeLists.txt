# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutterxel_library VERSION 0.0.13 LANGUAGES C)

add_library(flutterxel SHARED
  "flutterxel.c"
)

set_target_properties(flutterxel PROPERTIES
  PUBLIC_HEADER flutterxel.h
  OUTPUT_NAME "flutterxel"
)

target_compile_definitions(flutterxel PUBLIC DART_SHARED_LIB)

if (NOT WIN32)
  target_link_libraries(flutterxel PRIVATE m)
endif()

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(flutterxel PRIVATE "-Wl,-z,max-page-size=16384")
endif()
