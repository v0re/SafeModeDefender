@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A5_WinRM_Security.ps1" %*
exit /b %errorlevel%
