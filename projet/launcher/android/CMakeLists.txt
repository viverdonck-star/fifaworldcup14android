# The launcher for Android (liblauncher.so, run by LauncherActivity): the PC
# launcher's menu (../src) on SDL3's renderer, with the Android parts here.
#
#   cmake -S launcher/android -B <out> -G Ninja \
#         -DCMAKE_TOOLCHAIN_FILE=<ndk>/build/cmake/android.toolchain.cmake \
#         -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DANDROID_STL=c++_shared \
#         -DREXSDK_DIR=<rexglue-sdk checkout> -DREXSDK_INSTALL=<its Android install>
#
# Uses the SDK for its third-party sources (Dear ImGui, libmspack's LZX
# decoder, stb) and its Android build of SDL3 and FFmpeg (the XMA2 decoder,
# SHA-256 and AES); the launcher doesn't link the game runtime.

cmake_minimum_required(VERSION 3.25)
project(launcher_android LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT EXISTS "${REXSDK_DIR}/thirdparty/imgui/imgui.h")
  message(FATAL_ERROR "Set REXSDK_DIR to the rexglue-sdk checkout")
endif()
set(TP "${REXSDK_DIR}/thirdparty")
set(IMGUI "${TP}/imgui")
set(MSPACK "${TP}/libmspack/libmspack/mspack")
set(SRC "${CMAKE_CURRENT_SOURCE_DIR}/../src")

add_library(launcher SHARED
  main_android.cpp
  updater_stub.cpp
  ${SRC}/about.cpp
  ${SRC}/audio.cpp
  ${SRC}/game_check.cpp
  ${SRC}/game_files.cpp
  ${SRC}/game_source.cpp
  ${SRC}/i18n.cpp
  ${SRC}/language_picker.cpp
  ${SRC}/log.cpp
  ${SRC}/settings.cpp
  ${SRC}/setup.cpp
  ${SRC}/textures.cpp
  ${SRC}/ui.cpp
  ${IMGUI}/imgui.cpp
  ${IMGUI}/imgui_draw.cpp
  ${IMGUI}/imgui_tables.cpp
  ${IMGUI}/imgui_widgets.cpp
  ${IMGUI}/backends/imgui_impl_sdl3.cpp
  ${IMGUI}/backends/imgui_impl_sdlgpu3.cpp
  ${MSPACK}/lzxd.c
)
target_include_directories(launcher PRIVATE ${SRC} ${IMGUI} ${IMGUI}/backends ${TP}/stb ${MSPACK}
                                            ${TP}/FFmpeg ${REXSDK_INSTALL}/include
                                            ${TP}/inja/third_party/include)
target_compile_definitions(launcher PRIVATE IMGUI_DISABLE_OBSOLETE_FUNCTIONS)
file(READ ${CMAKE_CURRENT_SOURCE_DIR}/../../VERSION LAUNCHER_VERSION)
string(STRIP "${LAUNCHER_VERSION}" LAUNCHER_VERSION)
string(TIMESTAMP LAUNCHER_DATE "%d %B %Y" UTC)
set_source_files_properties(${SRC}/about.cpp PROPERTIES COMPILE_DEFINITIONS
  "LAUNCHER_VERSION=\"${LAUNCHER_VERSION}-android\";LAUNCHER_DATE=\"${LAUNCHER_DATE}\"")
target_link_libraries(launcher PRIVATE
  ${REXSDK_INSTALL}/lib/libSDL3.a
  ${REXSDK_INSTALL}/lib/liblibavcodec.a
  ${REXSDK_INSTALL}/lib/liblibavutil.a
  android log GLESv2 EGL OpenSLES aaudio dl m)
# SDL's JNI_OnLoad registers its Java natives; nothing else names it.
target_link_options(launcher PRIVATE "-Wl,-u,JNI_OnLoad" "-Wl,--no-undefined")
