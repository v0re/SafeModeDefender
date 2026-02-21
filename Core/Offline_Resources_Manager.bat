@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Offline_Resources_Manager.ps1" %*
exit /b %errorlevel%
