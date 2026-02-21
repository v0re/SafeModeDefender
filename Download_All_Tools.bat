@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Download_All_Tools.ps1" %*
