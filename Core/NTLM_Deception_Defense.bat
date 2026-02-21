@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0NTLM_Deception_Defense.ps1" %*
exit /b %errorlevel%
