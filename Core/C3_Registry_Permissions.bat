@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0C3_Registry_Permissions.ps1" %*
exit /b %errorlevel%
