@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A9_Process_Behavior_Analysis.ps1" %*
exit /b %errorlevel%
