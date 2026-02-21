@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0F2_Telemetry_Disable.ps1" %*
exit /b %errorlevel%
