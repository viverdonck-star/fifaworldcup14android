# libadrenotools_bridge.so and libadrenotools' hooks, for Android arm64:
#   cmake -S . -B out -G Ninja -DCMAKE_TOOLCHAIN_FILE=<ndk>/build/cmake/android.toolchain.cmake \
#         -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-33 -DADRENOTOOLS_DIR=<libadrenotools>
cmake_minimum_required(VERSION 3.14)
project(adrenotools_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
add_subdirectory(${ADRENOTOOLS_DIR} adrenotools)

add_library(adrenotools_bridge SHARED bridge.cpp)
target_link_libraries(adrenotools_bridge adrenotools)
set_target_properties(adrenotools_bridge PROPERTIES CXX_VISIBILITY_PRESET hidden)
