@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0G2_System_Integrity.ps1" %*
exit /b %errorlevel%
