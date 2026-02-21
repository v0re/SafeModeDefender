@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A6_LLMNR_Disable.ps1" %*
exit /b %errorlevel%
