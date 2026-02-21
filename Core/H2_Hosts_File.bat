@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0H2_Hosts_File.ps1" %*
