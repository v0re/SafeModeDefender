@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0I1_Firewall_Optimizer.ps1" %*
