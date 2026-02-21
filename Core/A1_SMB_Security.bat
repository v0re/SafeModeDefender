@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A1_SMB_Security.ps1" %*
exit /b %errorlevel%
