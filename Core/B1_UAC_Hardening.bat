@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0B1_UAC_Hardening.ps1" %*
exit /b %errorlevel%
