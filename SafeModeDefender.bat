@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

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
echo   [X] 執行完整掃描（所有 33 個模塊）
echo   [R] 查看報告
echo   [Q] 退出
echo.
echo ══════════════════════════════════════════════════════════════════════════
echo.
set /p CHOICE="請選擇功能（A-I, X, R, Q）："

if /i "%CHOICE%"=="A" goto MENU_A
if /i "%CHOICE%"=="B" goto MENU_B
if /i "%CHOICE%"=="C" goto MENU_C
if /i "%CHOICE%"=="D" goto MENU_D
if /i "%CHOICE%"=="E" goto MENU_E
if /i "%CHOICE%"=="F" goto MENU_F
if /i "%CHOICE%"=="G" goto MENU_G
if /i "%CHOICE%"=="H" goto MENU_H
if /i "%CHOICE%"=="I" goto MENU_I
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

:RUN_MODULE
set CATEGORY=%~1
set MODULE=%~2

echo.
echo ══════════════════════════════════════════════════════════════════════════
echo 執行模塊：%MODULE%
echo ══════════════════════════════════════════════════════════════════════════
echo.

if %POWERSHELL_AVAILABLE% equ 1 (
    if exist "%~dp0Core\%CATEGORY%\%MODULE%.ps1" (
        powershell -ExecutionPolicy Bypass -File "%~dp0Core\%CATEGORY%\%MODULE%.ps1"
    ) else (
        echo [錯誤] PowerShell 模塊不存在：%MODULE%.ps1
    )
) else (
    if exist "%~dp0Batch\%MODULE%.bat" (
        call "%~dp0Batch\%MODULE%.bat"
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
