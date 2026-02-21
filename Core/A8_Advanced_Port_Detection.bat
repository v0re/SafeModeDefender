@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0A8_Advanced_Port_Detection.ps1" %*
