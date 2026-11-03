@echo off
call C:\wc14\scripts\env.cmd
cd /d C:\wc14\src\sdk
cmake --preset win-amd64 -B out/build/vk -DREXGLUE_USE_VULKAN=ON -DCMAKE_INSTALL_PREFIX=C:/wc14/src/sdk/out/install/vk || exit /b 1
cmake --build out/build/vk --config Release --target install -j 8 || exit /b 2
echo SDK_VK_OK
