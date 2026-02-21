@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0D3_File_Permissions.ps1" %*
exit /b %errorlevel%
