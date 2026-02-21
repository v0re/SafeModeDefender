@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A4_mDNS_Disable.ps1" %*
exit /b %errorlevel%
