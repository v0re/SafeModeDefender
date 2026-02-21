@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0E1_Memory_Mitigation.ps1" %*
exit /b %errorlevel%
