@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0G3_BIOS_Update.ps1" %*
