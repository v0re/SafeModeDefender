@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Build-OfflinePackage.ps1" %*
exit /b %errorlevel%
