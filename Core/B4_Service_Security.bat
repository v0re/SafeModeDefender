@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0B4_Service_Security.ps1" %*
exit /b %errorlevel%
