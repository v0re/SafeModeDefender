@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
exit /b %errorlevel%
