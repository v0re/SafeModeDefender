@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Emergency_Cleanup.ps1" %*
exit /b %errorlevel%
