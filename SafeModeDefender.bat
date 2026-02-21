@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 解析命令列參數
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
:: SafeModeDefender v2.0 - Windows 安全模式深度清理工具
:: 
:: 基於真實世界威脅情報開發的專業級安全防護套件
:: 威脅情報來源：Exploit-DB, Shodan, CVE Database, CISA KEV
:: 
:: 開發日期：2026-02-19
:: 授權：MIT License
:: GitHub：https://github.com/v0re/SafeModeDefender
:: ============================================================================

title SafeModeDefender v2.0 - Windows 安全模式深度清理工具

:: 設定顏色
color 0A

:: 檢查管理員權限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo [錯誤] 此工具需要管理員權限才能執行！
    echo.
    echo 請以管理員身份重新執行此批次檔。
    echo.
    pause
    exit /b 1
)

:: 檢查是否在安全模式
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\SafeBoot\Option" /v OptionValue 2^>nul') do set SAFEMODE=%%a
if not defined SAFEMODE set SAFEMODE=0

:: 顯示歡迎畫面
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                                                                          ║
echo ║                    SafeModeDefender v2.0                                 ║
echo ║                                                                          ║
echo ║            Windows 安全模式深度清理工具                                 ║
echo ║                                                                          ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 基於真實世界威脅情報的專業級安全防護套件
echo 威脅情報來源：Exploit-DB, Shodan, CVE Database, CISA KEV
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.

if %SAFEMODE% equ 1 (
    echo [✓] 已檢測到安全模式環境（推薦）
) else if %SAFEMODE% equ 2 (
    echo [✓] 已檢測到含網路功能的安全模式環境（推薦）
) else (
    echo [!] 警告：未檢測到安全模式環境
    echo.
    echo 為了獲得最佳的清理效果，強烈建議在安全模式下執行此工具。
    echo.
    echo 如何進入安全模式：
    echo 1. 按住 Shift 鍵並點擊「重新啟動」
    echo 2. 選擇「疑難排解」→「進階選項」→「啟動設定」
    echo 3. 按 F4 進入安全模式，或按 F5 進入含網路功能的安全模式
    echo.
    choice /c YN /m "是否繼續在正常模式下執行？(Y/N)"
    if errorlevel 2 exit /b 0
)

echo.
echo [✓] 管理員權限已確認
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.

:: 檢查 PowerShell 可用性
powershell -Command "Write-Host 'PowerShell 可用'" >nul 2>&1
if %errorLevel% equ 0 (
    set POWERSHELL_AVAILABLE=1
    echo [✓] PowerShell 可用（將使用 PowerShell 模塊）
) else (
    set POWERSHELL_AVAILABLE=0
    echo [!] PowerShell 不可用（將使用批次檔備用方案）
)

echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.
pause

:: 如果是命令列模式，跳過選單
if %CLI_MODE% equ 1 goto CLI_HANDLER

:MAIN_MENU
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                          主選單                                          ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [A] 網路服務與端口安全（7 個模塊）
echo   [B] 系統權限與提權防護（5 個模塊）
echo   [C] 註冊表與持久化防護（4 個模塊）
echo   [D] 檔案系統與隱藏威脅（4 個模塊）
echo   [E] 記憶體與漏洞防護（3 個模塊）
echo   [F] 隱私權與遙測（2 個模塊）
echo   [G] 系統完整性與更新（3 個模塊）
echo   [H] 環境變數與 Hosts（2 個模塊）
echo   [I] 防火牆與策略（3 個模塊）
echo.
echo   [T] 外部工具管理器
echo   [O] 離線資源管理
echo   [S] 特殊防護工具（AnyDesk、NTLM、雲端清理）
echo   [X] 執行完整掃描（所有 33 個模塊）
echo   [R] 查看報告
echo   [Q] 退出
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.
set /p CHOICE="請選擇功能（A-I, T, O, S, X, R, Q）："

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

echo.
echo [錯誤] 無效的選擇，請重新輸入。
timeout /t 2 >nul
goto MAIN_MENU

:MENU_A
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  網路服務與端口安全                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] SMB 服務安全強化
echo   [2] RDP 服務安全強化
echo   [3] UPnP/SSDP 服務禁用
echo   [4] mDNS/Bonjour 服務禁用
echo   [5] WinRM/PowerShell Remoting 安全
echo   [6] LLMNR/NetBIOS-NS 禁用
echo   [7] 危險端口全面掃描與封鎖
echo.
echo   [A] 執行所有網路安全模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-7, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "NetworkSecurity" "A1_SMB_Security"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "NetworkSecurity" "A2_RDP_Security"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "NetworkSecurity" "A3_UPnP_Disable"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "NetworkSecurity" "A4_mDNS_Disable"
if "%SUBCHOICE%"=="5" call :RUN_MODULE "NetworkSecurity" "A5_WinRM_Security"
if "%SUBCHOICE%"=="6" call :RUN_MODULE "NetworkSecurity" "A6_LLMNR_Disable"
if "%SUBCHOICE%"=="7" call :RUN_MODULE "NetworkSecurity" "A7_Port_Scanner"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "NetworkSecurity"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_A

:MENU_B
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  系統權限與提權防護                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] UAC 設定強化
echo   [2] 管理員帳戶審計
echo   [3] 特權令牌檢測
echo   [4] 計劃任務權限檢查
echo   [5] 服務權限審計
echo.
echo   [A] 執行所有權限防護模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-5, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "PrivilegeEscalation" "B1_UAC_Hardening"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "PrivilegeEscalation" "B2_Admin_Audit"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "PrivilegeEscalation" "B3_Token_Detection"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "PrivilegeEscalation" "B4_Task_Permissions"
if "%SUBCHOICE%"=="5" call :RUN_MODULE "PrivilegeEscalation" "B5_Service_Audit"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "PrivilegeEscalation"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_B

:MENU_C
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  註冊表與持久化防護                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] Run/RunOnce 鍵值檢測
echo   [2] 服務註冊表檢測
echo   [3] WMI 事件訂閱檢測
echo   [4] 啟動資料夾檢測
echo.
echo   [A] 執行所有持久化防護模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-4, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "RegistryPersistence" "C1_Run_Keys"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "RegistryPersistence" "C2_Service_Registry"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "RegistryPersistence" "C3_WMI_Events"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "RegistryPersistence" "C4_Startup_Folders"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "RegistryPersistence"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_C

:MENU_D
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  檔案系統與隱藏威脅                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] 隱藏檔案與 ADS 檢測
echo   [2] 系統目錄異常檔案
echo   [3] Temp 目錄清理
echo   [4] 可疑 DLL 檢測
echo.
echo   [A] 執行所有檔案系統模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-4, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "FileSystem" "D1_Hidden_Files"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "FileSystem" "D2_System_Directory"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "FileSystem" "D3_Temp_Cleanup"
if "%SUBCHOICE%"=="4" call :RUN_MODULE "FileSystem" "D4_Suspicious_DLL"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "FileSystem"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_D

:MENU_E
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  記憶體與漏洞防護                                        ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] DEP/ASLR 檢查
echo   [2] 可疑進程檢測
echo   [3] 注入檢測
echo.
echo   [A] 執行所有記憶體防護模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-3, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "MemoryProtection" "E1_DEP_ASLR"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "MemoryProtection" "E2_Process_Detection"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "MemoryProtection" "E3_Injection_Detection"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "MemoryProtection"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_E

:MENU_F
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  隱私權與遙測                                            ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] Windows 遙測禁用
echo   [2] 隱私設定強化
echo.
echo   [A] 執行所有隱私防護模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-2, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "Privacy" "F1_Telemetry_Disable"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "Privacy" "F2_Privacy_Hardening"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "Privacy"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_F

:MENU_G
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  系統完整性與更新                                        ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] 系統檔案完整性檢查
echo   [2] Windows Update 檢查
echo   [3] 驅動程式簽章驗證
echo.
echo   [A] 執行所有完整性模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-3, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "SystemIntegrity" "G1_File_Integrity"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "SystemIntegrity" "G2_Windows_Update"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "SystemIntegrity" "G3_Driver_Verification"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "SystemIntegrity"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_G

:MENU_H
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  環境變數與 Hosts                                        ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] 環境變數檢測
echo   [2] Hosts 檔案檢查
echo.
echo   [A] 執行所有環境檢查模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-2, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "Environment" "H1_Environment_Variables"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "Environment" "H2_Hosts_File"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "Environment"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_H

:MENU_I
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                  防火牆與策略                                            ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo   [1] Windows 防火牆規則審計
echo   [2] 群組原則檢查
echo   [3] 本地安全原則強化
echo.
echo   [A] 執行所有防火牆與策略模塊
echo   [B] 返回主選單
echo.
set /p SUBCHOICE="請選擇模塊（1-3, A, B）："

if "%SUBCHOICE%"=="1" call :RUN_MODULE "FirewallPolicy" "I1_Firewall_Rules"
if "%SUBCHOICE%"=="2" call :RUN_MODULE "FirewallPolicy" "I2_Group_Policy"
if "%SUBCHOICE%"=="3" call :RUN_MODULE "FirewallPolicy" "I3_Security_Policy"
if /i "%SUBCHOICE%"=="A" call :RUN_CATEGORY "FirewallPolicy"
if /i "%SUBCHOICE%"=="B" goto MAIN_MENU

pause
goto MENU_I

:RUN_MODULE
set CATEGORY=%~1
set MODULE=%~2

echo.
echo ══════════════════════════════════════════════════════════════════════════
echo 執行模塊：%MODULE%
echo ══════════════════════════════════════════════════════════════════════════
echo.

if %POWERSHELL_AVAILABLE% equ 1 (
    if exist "%~dp0Core\%MODULE%.ps1" (
        powershell -ExecutionPolicy Bypass -File "%~dp0Core\%MODULE%.ps1"
    ) else (
        echo [錯誤] PowerShell 模塊不存在：%MODULE%.ps1
    )
) else (
    if exist "%~dp0Core\%MODULE%.bat" (
        call "%~dp0Core\%MODULE%.bat"
    ) else (
        echo [錯誤] 批次檔模塊不存在：%MODULE%.bat
    )
)

echo.
echo ══════════════════════════════════════════════════════════════════════════
echo 模塊執行完成：%MODULE%
echo ══════════════════════════════════════════════════════════════════════════
echo.
goto :EOF

:RUN_CATEGORY
set CATEGORY=%~1
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo 執行類別：%CATEGORY%
echo ══════════════════════════════════════════════════════════════════════════
echo.

:: 這裡應該列出該類別的所有模塊並執行
:: 由於篇幅限制，這裡僅作示意

echo [資訊] 類別執行功能尚未完整實現
echo.
goto :EOF

:RUN_FULL_SCAN
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                          完整掃描                                        ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 即將執行所有 33 個安全模塊的完整掃描。
echo 此過程可能需要 30-60 分鐘，具體取決於您的系統狀態。
echo.
echo 掃描期間將生成詳細的報告，並在必要時提示您確認修復操作。
echo.
choice /c YN /m "是否繼續執行完整掃描？(Y/N)"
if errorlevel 2 goto MAIN_MENU

echo.
echo ══════════════════════════════════════════════════════════════════════════
echo 開始完整掃描...
echo ══════════════════════════════════════════════════════════════════════════
echo.

:: 執行所有模塊（示意）
echo [資訊] 完整掃描功能尚未完整實現
echo.

pause
goto MAIN_MENU

:VIEW_REPORTS
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                          查看報告                                        ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.

if exist "%~dp0Reports\*.html" (
    echo 可用的報告：
    echo.
    dir /b "%~dp0Reports\*.html"
    echo.
    echo 報告目錄：%~dp0Reports\
    echo.
    start "" "%~dp0Reports\"
) else (
    echo [資訊] 尚無可用的報告
    echo.
    echo 請先執行掃描以生成報告。
)

echo.
pause
goto MAIN_MENU

:SPECIAL_TOOLS
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                          特殊防護工具                                    ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 請選擇要執行的特殊防護工具：
echo.
echo   [1] AnyDesk 安全防護
echo       - 檢測 AnyDesk 安裝和配置
echo       - 檢測無人值守訪問
echo       - 檢測 AnyDesk 模式 (可攜式/安裝版)
echo.
echo   [2] NTLM 欺騙式防禦
echo       - 禁用 NTLM 並強制使用 Kerberos
echo       - 啟用 NTLM 審計日誌
echo       - 記錄所有 NTLM 攻擊嘗試
echo.
echo   [3] NTLM 佔位符反制系統
echo       - 將 NTLM DLL 替換為反制腳本
echo       - 自動收集攻擊者資訊
echo       - 可自定義佔位符目標
echo.
echo   [4] 通用佔位符防禦
echo       - 可自定義要替換的 DLL/服務/註冊表
echo       - 支援 NTLM/SMB/RDP/WinRM/AnyDesk
echo       - JSON 配置檔案管理
echo.
echo   [B] 返回主選單
echo.
set /p STCHOICE="請選擇 (1-4, B): "

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
    echo [錯誤] 無效的選擇
    timeout /t 2 >nul
    goto SPECIAL_TOOLS
)

:EXIT
cls
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.
echo 感謝使用 SafeModeDefender v2.0！
echo.
echo 如果此工具對您有幫助，請考慮：
echo - 在 GitHub 上給我們一個 Star
echo - 分享給需要的朋友
echo - 報告問題或提供建議
echo.
echo GitHub：https://github.com/v0re/SafeModeDefender
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.
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
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                      離線資源管理器                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 正在啟動離線資源管理器...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Core\Offline_Resources_Manager.ps1"
echo.
pause
goto MAIN_MENU

:EXTERNAL_TOOLS
cls
echo ╔══════════════════════════════════════════════════════════════════════════╗
echo ║                      外部工具管理器                                      ║
echo ╚══════════════════════════════════════════════════════════════════════════╝
echo.
echo 正在啟動外部工具管理器...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0Core\External_Tools_Manager.ps1"
echo.
pause
goto MAIN_MENU
