@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0C2_Registry_Hijack.ps1" %*
