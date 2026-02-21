@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0G1_Windows_Update.ps1" %*
exit /b %errorlevel%
