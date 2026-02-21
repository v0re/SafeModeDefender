@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0simplewall_Wrapper.ps1" %*
