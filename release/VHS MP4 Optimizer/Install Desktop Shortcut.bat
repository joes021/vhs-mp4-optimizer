@echo off
setlocal
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\install-vhs-mp4-shortcut.ps1"
pause
endlocal
