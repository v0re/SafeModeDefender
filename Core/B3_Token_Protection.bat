@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0B3_Token_Protection.ps1" %*
