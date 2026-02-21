@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0B2_SYSTEM_Audit.ps1" %*
