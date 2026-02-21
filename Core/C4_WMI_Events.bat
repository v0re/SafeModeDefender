@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0C4_WMI_Events.ps1" %*
exit /b %errorlevel%
