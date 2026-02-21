@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A7_Port_Scanner.ps1" %*
