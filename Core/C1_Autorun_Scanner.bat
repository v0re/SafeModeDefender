@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0C1_Autorun_Scanner.ps1" %*
exit /b %errorlevel%
