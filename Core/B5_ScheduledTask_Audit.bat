@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0B5_ScheduledTask_Audit.ps1" %*
exit /b %errorlevel%
