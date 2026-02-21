@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0I3_Network_Logon.ps1" %*
