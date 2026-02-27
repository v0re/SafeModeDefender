@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: Parse command line arguments
set CLI_MODE=0
set CLI_ACTION=
set CLI_CATEGORY=
set CLI_MODULE=
set CLI_TOOL=
set CLI_CONFIG=
set CLI_SILENT=0
set CLI_AUTOFIX=0

:PARSE_ARGS
if "%~1"=="" goto END_PARSE_ARGS
if /i "%~1"=="--cli" set CLI_MODE=1
if /i "%~1"=="--action" set CLI_ACTION=%~2& shift
if /i "%~1"=="--category" set CLI_CATEGORY=%~2& shift
if /i "%~1"=="--module" set CLI_MODULE=%~2& shift
if /i "%~1"=="--tool" set CLI_TOOL=%~2& shift
if /i "%~1"=="--config" set CLI_CONFIG=%~2& shift
if /i "%~1"=="--silent" set CLI_SILENT=1
if /i "%~1"=="--autofix" set CLI_AUTOFIX=1
if /i "%~1"=="--help" goto SHOW_CLI_HELP
shift
goto PARSE_ARGS

:END_PARSE_ARGS

:: ============================================================================
:: SafeModeDefender v2.0 - Windows Safe Mode Deep Cleaning Tool
::
:: Professional security protection suite based on real-world threat intelligence
:: Threat intel sources: Exploit-DB, Shodan, CVE Database, CISA KEV
::
:: Date: 2026-02-19
:: License: MIT License
:: GitHub: https://github.com/v0re/SafeModeDefender
:: ============================================================================

title SafeModeDefender v2.0

:: Set color
color 0A

:: Check administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "AdminError"
    pause
    exit /b 1
)

:: Check if running in safe mode
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" /v OptionValue 2^>nul') do set SAFEMODE=%%a
if not defined SAFEMODE set SAFEMODE=0

:: Display welcome screen
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "Welcome"

if %SAFEMODE% equ 1 (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "SafeModeOK"
) else if %SAFEMODE% equ 2 (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "SafeModeNetOK"
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "SafeModeWarn"
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "PromptContinueNormal"
    choice /c YN /n
    if errorlevel 2 exit /b 0
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "AdminOK"

:: Check PowerShell availability
powershell -Command "Write-Host 'OK'" >nul 2>&1
if %errorLevel% equ 0 (
    set POWERSHELL_AVAILABLE=1
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "PSAvailable"
) else (
    set POWERSHELL_AVAILABLE=0
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "PSUnavailable"
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "PostInit"
pause

:: Skip menu if in CLI mode
if %CLI_MODE% equ 1 goto CLI_HANDLER

:MAIN_MENU
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MainMenu"
set /p CHOICE=

if /i "%CHOICE%"=="A" goto MENU_A
if /i "%CHOICE%"=="B" goto MENU_B
if /i "%CHOICE%"=="C" goto MENU_C
if /i "%CHOICE%"=="D" goto MENU_D
if /i "%CHOICE%"=="E" goto MENU_E
if /i "%CHOICE%"=="F" goto MENU_F
if /i "%CHOICE%"=="G" goto MENU_G
if /i "%CHOICE%"=="H" goto MENU_H
if /i "%CHOICE%"=="I" goto MENU_I
if /i "%CHOICE%"=="O" goto OFFLINE_RESOURCES
if /i "%CHOICE%"=="T" goto EXTERNAL_TOOLS
if /i "%CHOICE%"=="S" goto SPECIAL_TOOLS
if /i "%CHOICE%"=="X" goto RUN_FULL_SCAN
if /i "%CHOICE%"=="R" goto VIEW_REPORTS
if /i "%CHOICE%"=="Q" goto EXIT

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "InvalidChoice"
timeout /t 2 >nul
goto MAIN_MENU

:MENU_A
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuA"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "NetworkSecurity" "A1_SMB_Security"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "NetworkSecurity" "A2_RDP_Security"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "NetworkSecurity" "A3_UPnP_Disable"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "NetworkSecurity" "A4_mDNS_Disable"
if "%SUBCHOICE%"=="5" call :RUN_MODULE "NetworkSecurity" "A5_WinRM_Security"
if "%SUBCHOICE%"=="6" call :RUN_MODULE "NetworkSecurity" "A6_LLMNR_Disable"
if "%SUBCHOICE%"=="7" call :RUN_MODULE "NetworkSecurity" "A7_Port_Scanner"
if "%SUBCHOICE%"=="8" call :RUN_MODULE "NetworkSecurity" "A8_Advanced_Port_Detection"
if "%SUBCHOICE%"=="9" call :RUN_MODULE "NetworkSecurity" "A9_Process_Behavior_Analysis"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "NetworkSecurity"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_A

:MENU_B
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuB"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "PrivilegeEscalation" "B1_UAC_Hardening"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "PrivilegeEscalation" "B2_SYSTEM_Audit"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "PrivilegeEscalation" "B3_Token_Protection"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "PrivilegeEscalation" "B4_Service_Security"
if "%SUBCHOICE%"=="5" call :RUN_MODULE "PrivilegeEscalation" "B5_ScheduledTask_Audit"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "PrivilegeEscalation"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_B

:MENU_C
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuC"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "RegistryPersistence" "C1_Autorun_Scanner"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "RegistryPersistence" "C2_Registry_Hijack"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "RegistryPersistence" "C3_Registry_Permissions"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "RegistryPersistence" "C4_WMI_Events"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "RegistryPersistence"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_C

:MENU_D
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuD"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "FileSystem" "D1_Hidden_Files"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "FileSystem" "D2_INI_Scanner"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "FileSystem" "D3_File_Permissions"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "FileSystem" "D4_Digital_Signature"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "FileSystem"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_D

:MENU_E
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuE"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "MemoryProtection" "E1_Memory_Mitigation"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "MemoryProtection" "E2_Terminal_Fix"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "MemoryProtection" "E3_GPU_Protection"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "MemoryProtection"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_E

:MENU_F
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuF"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "Privacy" "F1_Privacy_Disable"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "Privacy" "F2_Telemetry_Disable"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "Privacy"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_F

:MENU_G
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuG"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "SystemIntegrity" "G1_Windows_Update"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "SystemIntegrity" "G2_System_Integrity"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "SystemIntegrity" "G3_BIOS_Update"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "SystemIntegrity"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_G

:MENU_H
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuH"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "Environment" "H1_Environment_Variables"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "Environment" "H2_Hosts_File"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "Environment"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_H

:MENU_I
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "MenuI"
set /p SUBCHOICE=

if "%SUBCHOICE%"=="1" call :RUN_MODULE "FirewallPolicy" "I1_Firewall_Optimizer"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "FirewallPolicy" "I2_Security_Policy"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "FirewallPolicy" "I3_Network_Logon"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "FirewallPolicy"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_I

:RUN_MODULE
set CATEGORY=%~1
set MODULE=%~2

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ModuleStart" -ModuleName "%MODULE%"

if %POWERSHELL_AVAILABLE% equ 1 (
    if exist "%~dp0Core\%MODULE%.ps1" (
        powershell -ExecutionPolicy Bypass -File "%~dp0Core\%MODULE%.ps1"
    ) else (
        powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ModuleNotFoundPS" -ModuleName "%MODULE%"
    )
) else (
    if exist "%~dp0Core\%MODULE%.bat" (
        call "%~dp0Core\%MODULE%.bat"
    ) else (
        powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ModuleNotFoundBat" -ModuleName "%MODULE%"
    )
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ModuleEnd" -ModuleName "%MODULE%"
goto :EOF

:RUN_CATEGORY
set CATEGORY=%~1
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "CategoryStart" -CategoryName "%CATEGORY%"

:: List all modules in the category and execute (not yet fully implemented)
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "CategoryNotImplemented"

goto :EOF

:RUN_FULL_SCAN
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "FullScan"
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "PromptFullScan"
choice /c YN /n
if errorlevel 2 goto MAIN_MENU

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "FullScanStart"

:: Execute all modules (not yet fully implemented)
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "FullScanNotImplemented"

pause
goto MAIN_MENU

:VIEW_REPORTS
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ViewReports"

if exist "%~dp0Reports\*.html" (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ReportsAvailable"
    dir /b "%~dp0Reports\*.html"
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ReportDir" -Path "%~dp0Reports\"
    start "" "%~dp0Reports\"
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ReportsNone"
)

echo.
pause
goto MAIN_MENU

:SPECIAL_TOOLS
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "SpecialTools"
set /p STCHOICE=

if "%STCHOICE%"=="1" (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Core\I1_AnyDesk_Security.ps1"
    pause
    goto SPECIAL_TOOLS
) else if "%STCHOICE%"=="2" (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Core\NTLM_Deception_Defense.ps1" -EnableDeception
    pause
    goto SPECIAL_TOOLS
) else if "%STCHOICE%"=="3" (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Core\NTLM_Reverse_Exploit.ps1" -Enable
    pause
    goto SPECIAL_TOOLS
) else if "%STCHOICE%"=="4" (
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0Core\Universal_Placeholder_Defense.ps1" -ListTargets
    pause
    goto SPECIAL_TOOLS
) else if /i "%STCHOICE%"=="B" (
    goto MAIN_MENU
) else (
    powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "SpecialToolsInvalid"
    timeout /t 2 >nul
    goto SPECIAL_TOOLS
)

:EXIT
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "Exit"
timeout /t 3
exit /b 0

:SHOW_CLI_HELP
powershell -ExecutionPolicy Bypass -File "%~dp0Core\CLI_Handler.ps1" -Help
exit /b 0

:CLI_HANDLER
if defined CLI_TOOL (
    powershell -ExecutionPolicy Bypass -File "%~dp0Core\External_Tools_Manager.ps1" -Tool "%CLI_TOOL%" -Action "%CLI_ACTION%" -CLI
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0Core\CLI_Handler.ps1" -Action "%CLI_ACTION%" -Category "%CLI_CATEGORY%" -Module "%CLI_MODULE%" -ConfigFile "%CLI_CONFIG%"
)
exit /b %errorlevel%

:OFFLINE_RESOURCES
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "OfflineResources"
powershell -ExecutionPolicy Bypass -File "%~dp0Core\Offline_Resources_Manager.ps1"
echo.
pause
goto MAIN_MENU

:EXTERNAL_TOOLS
cls
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Core\Show-Menu.ps1" -MenuName "ExternalTools"
powershell -ExecutionPolicy Bypass -File "%~dp0Core\External_Tools_Manager.ps1"
echo.
pause
goto MAIN_MENU
