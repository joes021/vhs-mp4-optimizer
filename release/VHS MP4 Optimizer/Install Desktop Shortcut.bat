@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install-vhs-mp4-shortcut.ps1"
pause
endlocal
