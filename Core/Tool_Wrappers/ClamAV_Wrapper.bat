@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0ClamAV_Wrapper.ps1" %*
exit /b %errorlevel%
