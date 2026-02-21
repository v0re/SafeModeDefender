@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0GPU_Attack_Detector.ps1" %*
exit /b %errorlevel%
