@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0External_Tools_Manager.ps1" %*
exit /b %errorlevel%
