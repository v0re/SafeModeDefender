@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0D2_INI_Scanner.ps1" %*
