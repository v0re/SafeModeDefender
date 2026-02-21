@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0I2_Security_Policy.ps1" %*
exit /b %errorlevel%
