@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0I1_AnyDesk_Security.ps1" %*
exit /b %errorlevel%
