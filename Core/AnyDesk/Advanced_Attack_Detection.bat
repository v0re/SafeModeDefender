@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Advanced_Attack_Detection.ps1" %*
exit /b %errorlevel%
