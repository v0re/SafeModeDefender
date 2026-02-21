@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A3_UPnP_Disable.ps1" %*
