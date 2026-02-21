@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~dp0H1_Environment_Variables.ps1" %*
