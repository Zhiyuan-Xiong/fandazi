@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ai_service\start.ps1"
start "" "%~dp0build\FanDazi.exe" --main-pack "%~dp0build\FanDazi.pck"
