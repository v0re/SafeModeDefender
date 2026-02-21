@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0D1_Hidden_Files.ps1" %*
exit /b %errorlevel%
