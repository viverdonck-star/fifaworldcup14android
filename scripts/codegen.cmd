@echo off
call C:\wc14\scripts\env.cmd
cd /d C:\wc14\src\projet\pc
C:\wc14\src\sdk\out\install\win-amd64\bin\rexglue.exe codegen fifawc14_manifest.toml || exit /b 1
echo CODEGEN_OK
