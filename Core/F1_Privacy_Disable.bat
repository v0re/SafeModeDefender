@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0F1_Privacy_Disable.ps1" %*
exit /b %errorlevel%
