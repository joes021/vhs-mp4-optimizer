@echo off
setlocal
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0optimize-vhs-mp4-gui.ps1"
endlocal
