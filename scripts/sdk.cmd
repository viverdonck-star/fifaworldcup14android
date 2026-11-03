@echo off
call C:\wc14\scripts\env.cmd
cd /d C:\wc14\src\sdk
clang --version
cmake --preset win-amd64 || exit /b 1
cmake --build out/build/win-amd64 --config RelWithDebInfo --target install -j 8 || exit /b 2
cmake --build out/build/win-amd64 --config Release --target install -j 8 || exit /b 3
echo SDK_OK
