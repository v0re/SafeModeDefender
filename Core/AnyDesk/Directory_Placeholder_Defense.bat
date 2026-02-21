@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0Directory_Placeholder_Defense.ps1" %*
