@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0E2_Terminal_Fix.ps1" %*
exit /b %errorlevel%
