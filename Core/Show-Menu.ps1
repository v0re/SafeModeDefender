# Show-Menu.ps1 - Menu UI renderer for SafeModeDefender
# All Chinese/Unicode menu text is centralized here.
# Called from SafeModeDefender.bat with -MenuName parameter.

param(
    [string]$MenuName    = "MainMenu",
    [string]$ModuleName  = "",
    [string]$CategoryName = "",
    [string]$Path        = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sep = "═" * 74  # 74 box-line chars to match the 76-char-wide box (╔ + 74 + ╗)

switch ($MenuName) {

    "AdminError" {
        Write-Host ""
        Write-Host "[錯誤] 此工具需要管理員權限才能執行！" -ForegroundColor Red
        Write-Host ""
        Write-Host "請以管理員身份重新執行此批次檔。"
        Write-Host ""
    }

    "Welcome" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                                                                          ║" -ForegroundColor Cyan
        Write-Host "║                    SafeModeDefender v2.0                                 ║" -ForegroundColor Cyan
        Write-Host "║                                                                          ║" -ForegroundColor Cyan
        Write-Host "║            Windows 安全模式深度清理工具                                 ║" -ForegroundColor Cyan
        Write-Host "║                                                                          ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "基於真實世界威脅情報的專業級安全防護套件"
        Write-Host "威脅情報來源：Exploit-DB, Shodan, CVE Database, CISA KEV"
        Write-Host ""
        Write-Host $sep
        Write-Host ""
    }

    "SafeModeOK" {
        Write-Host "[✓] 已檢測到安全模式環境（推薦）" -ForegroundColor Green
    }

    "SafeModeNetOK" {
        Write-Host "[✓] 已檢測到含網路功能的安全模式環境（推薦）" -ForegroundColor Green
    }

    "SafeModeWarn" {
        Write-Host "[!] 警告：未檢測到安全模式環境" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "為了獲得最佳的清理效果，強烈建議在安全模式下執行此工具。"
        Write-Host ""
        Write-Host "如何進入安全模式：" -ForegroundColor Cyan
        Write-Host "1. 按住 Shift 鍵並點擊「重新啟動」"
        Write-Host "2. 選擇「疑難排解」→「進階選項」→「啟動設定」"
        Write-Host "3. 按 F4 進入安全模式，或按 F5 進入含網路功能的安全模式"
        Write-Host ""
    }

    "PromptContinueNormal" {
        Write-Host "是否繼續在正常模式下執行？(Y/N)" -ForegroundColor Yellow -NoNewline
    }

    "AdminOK" {
        Write-Host ""
        Write-Host "[✓] 管理員權限已確認" -ForegroundColor Green
        Write-Host ""
        Write-Host $sep
        Write-Host ""
    }

    "PSAvailable" {
        Write-Host "[✓] PowerShell 可用（將使用 PowerShell 模塊）" -ForegroundColor Green
    }

    "PSUnavailable" {
        Write-Host "[!] PowerShell 不可用（將使用批次檔備用方案）" -ForegroundColor Yellow
    }

    "PostInit" {
        Write-Host ""
        Write-Host $sep
        Write-Host ""
    }

    "MainMenu" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                          主選單                                          ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [A] 網路服務與端口安全（9 個模塊）"
        Write-Host "  [B] 系統權限與提權防護（5 個模塊）"
        Write-Host "  [C] 註冊表與持久化防護（4 個模塊）"
        Write-Host "  [D] 檔案系統與隱藏威脅（4 個模塊）"
        Write-Host "  [E] 記憶體與漏洞防護（3 個模塊）"
        Write-Host "  [F] 隱私權與遙測（2 個模塊）"
        Write-Host "  [G] 系統完整性與更新（3 個模塊）"
        Write-Host "  [H] 環境變數與 Hosts（2 個模塊）"
        Write-Host "  [I] 防火牆與策略（3 個模塊）"
        Write-Host ""
        Write-Host "  [T] 外部工具管理器"
        Write-Host "  [O] 離線資源管理"
        Write-Host "  [S] 特殊防護工具（AnyDesk、NTLM、雲端清理）"
        Write-Host "  [X] 執行完整掃描（所有 35 個模塊）"
        Write-Host "  [R] 查看報告"
        Write-Host "  [Q] 退出"
        Write-Host ""
        Write-Host $sep
        Write-Host ""
        Write-Host "請選擇功能（A-I, T, O, S, X, R, Q）：" -NoNewline
    }

    "InvalidChoice" {
        Write-Host ""
        Write-Host "[錯誤] 無效的選擇，請重新輸入。" -ForegroundColor Red
    }

    "MenuA" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  網路服務與端口安全                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] SMB 服務安全強化"
        Write-Host "  [2] RDP 服務安全強化"
        Write-Host "  [3] UPnP/SSDP 服務禁用"
        Write-Host "  [4] mDNS/Bonjour 服務禁用"
        Write-Host "  [5] WinRM/PowerShell Remoting 安全"
        Write-Host "  [6] LLMNR/NetBIOS-NS 禁用"
        Write-Host "  [7] 危險端口全面掃描與封鎖"
        Write-Host "  [8] 增強版服務與端口檢測（雙模式）"
        Write-Host "  [9] 進程行為模式識別"
        Write-Host ""
        Write-Host "  [A] 執行所有網路安全模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-9, A, B）：" -NoNewline
    }

    "MenuB" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  系統權限與提權防護                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] UAC 設定強化"
        Write-Host "  [2] SYSTEM 權限異常檢測"
        Write-Host "  [3] 特權令牌競取與模擬防護"
        Write-Host "  [4] 服務安全與 DLL 劫持防護"
        Write-Host "  [5] 計劃任務安全審計"
        Write-Host ""
        Write-Host "  [A] 執行所有權限防護模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-5, A, B）：" -NoNewline
    }

    "MenuC" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  註冊表與持久化防護                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 自啟動項全面掃描（Run/RunOnce）"
        Write-Host "  [2] 註冊表劫持檢測"
        Write-Host "  [3] 註冊表權限異常檢測"
        Write-Host "  [4] WMI 事件訂閱檢測"
        Write-Host ""
        Write-Host "  [A] 執行所有持久化防護模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-4, A, B）：" -NoNewline
    }

    "MenuD" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  檔案系統與隱藏威脅                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 隱藏檔案與 ADS 檢測"
        Write-Host "  [2] INI 檔案安全掃描"
        Write-Host "  [3] 檔案權限異常檢測"
        Write-Host "  [4] 可疑執行檔數位簽章驗證"
        Write-Host ""
        Write-Host "  [A] 執行所有檔案系統模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-4, A, B）：" -NoNewline
    }

    "MenuE" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  記憶體與漏洞防護                                        ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 記憶體溢出漏洞緩解（DEP/ASLR）"
        Write-Host "  [2] 終端亂碼與記憶體溢出修復"
        Write-Host "  [3] 顯示卡渲染溢出防護（GPU）"
        Write-Host ""
        Write-Host "  [A] 執行所有記憶體防護模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-3, A, B）：" -NoNewline
    }

    "MenuF" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  隱私權與遙測                                            ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Windows 隱私權全面關閉"
        Write-Host "  [2] Windows 遙測與診斷禁用"
        Write-Host ""
        Write-Host "  [A] 執行所有隱私防護模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-2, A, B）：" -NoNewline
    }

    "MenuG" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  系統完整性與更新                                        ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] Windows Update 修復與強制啟用"
        Write-Host "  [2] 系統檔案完整性檢查（SFC/DISM）"
        Write-Host "  [3] BIOS/UEFI 更新檢測與引導"
        Write-Host ""
        Write-Host "  [A] 執行所有完整性模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-3, A, B）：" -NoNewline
    }

    "MenuH" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  環境變數與 Hosts                                        ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 環境變數檢測"
        Write-Host "  [2] Hosts 檔案檢查"
        Write-Host ""
        Write-Host "  [A] 執行所有環境檢查模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-2, A, B）：" -NoNewline
    }

    "MenuI" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                  防火牆與策略                                            ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [1] 防火牆規則優化工具"
        Write-Host "  [2] 本機安全策略強化"
        Write-Host "  [3] 網路登入方式檢查"
        Write-Host ""
        Write-Host "  [A] 執行所有防火牆與策略模塊"
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇模塊（1-3, A, B）：" -NoNewline
    }

    "ModuleStart" {
        Write-Host ""
        Write-Host $sep
        Write-Host ("執行模塊：" + $ModuleName)
        Write-Host $sep
        Write-Host ""
    }

    "ModuleEnd" {
        Write-Host ""
        Write-Host $sep
        Write-Host ("模塊執行完成：" + $ModuleName)
        Write-Host $sep
        Write-Host ""
    }

    "ModuleNotFoundPS" {
        Write-Host ("[錯誤] PowerShell 模塊不存在：" + $ModuleName + ".ps1") -ForegroundColor Red
    }

    "ModuleNotFoundBat" {
        Write-Host ("[錯誤] 批次檔模塊不存在：" + $ModuleName + ".bat") -ForegroundColor Red
    }

    "CategoryStart" {
        Write-Host ""
        Write-Host $sep
        Write-Host ("執行類別：" + $CategoryName)
        Write-Host $sep
        Write-Host ""
    }

    "CategoryNotImplemented" {
        Write-Host "[資訊] 類別執行功能尚未完整實現" -ForegroundColor Yellow
        Write-Host ""
    }

    "FullScan" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                          完整掃描                                        ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "即將執行所有 35 個安全模塊的完整掃描。"
        Write-Host "此過程可能需要 30-60 分鐘，具體取決於您的系統狀態。"
        Write-Host ""
        Write-Host "掃描期間將生成詳細的報告，並在必要時提示您確認修復操作。"
        Write-Host ""
    }

    "PromptFullScan" {
        Write-Host "是否繼續執行完整掃描？(Y/N)" -ForegroundColor Yellow -NoNewline
    }

    "FullScanStart" {
        Write-Host ""
        Write-Host $sep
        Write-Host "開始完整掃描..."
        Write-Host $sep
        Write-Host ""
    }

    "FullScanNotImplemented" {
        Write-Host "[資訊] 完整掃描功能尚未完整實現" -ForegroundColor Yellow
        Write-Host ""
    }

    "ViewReports" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                          查看報告                                        ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
    }

    "ReportsAvailable" {
        Write-Host "可用的報告：" -ForegroundColor Green
        Write-Host ""
    }

    "ReportDir" {
        Write-Host ""
        Write-Host ("報告目錄：" + $Path)
        Write-Host ""
    }

    "ReportsNone" {
        Write-Host "[資訊] 尚無可用的報告" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "請先執行掃描以生成報告。"
    }

    "SpecialTools" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                          特殊防護工具                                    ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "請選擇要執行的特殊防護工具："
        Write-Host ""
        Write-Host "  [1] AnyDesk 安全防護"
        Write-Host "      - 檢測 AnyDesk 安裝和配置"
        Write-Host "      - 檢測無人值守訪問"
        Write-Host "      - 檢測 AnyDesk 模式 (可攜式/安裝版)"
        Write-Host ""
        Write-Host "  [2] NTLM 欺騙式防禦"
        Write-Host "      - 禁用 NTLM 並強制使用 Kerberos"
        Write-Host "      - 啟用 NTLM 審計日誌"
        Write-Host "      - 記錄所有 NTLM 攻擊嘗試"
        Write-Host ""
        Write-Host "  [3] NTLM 佔位符反制系統"
        Write-Host "      - 將 NTLM DLL 替換為反制腳本"
        Write-Host "      - 自動收集攻擊者資訊"
        Write-Host "      - 可自定義佔位符目標"
        Write-Host ""
        Write-Host "  [4] 通用佔位符防禦"
        Write-Host "      - 可自定義要替換的 DLL/服務/註冊表"
        Write-Host "      - 支援 NTLM/SMB/RDP/WinRM/AnyDesk"
        Write-Host "      - JSON 配置檔案管理"
        Write-Host ""
        Write-Host "  [B] 返回主選單"
        Write-Host ""
        Write-Host "請選擇 (1-4, B): " -NoNewline
    }

    "SpecialToolsInvalid" {
        Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
    }

    "Exit" {
        Write-Host ""
        Write-Host $sep
        Write-Host ""
        Write-Host "感謝使用 SafeModeDefender v2.0！" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "如果此工具對您有幫助，請考慮："
        Write-Host "- 在 GitHub 上給我們一個 Star"
        Write-Host "- 分享給需要的朋友"
        Write-Host "- 報告問題或提供建議"
        Write-Host ""
        Write-Host "GitHub: https://github.com/v0re/SafeModeDefender"
        Write-Host ""
        Write-Host $sep
        Write-Host ""
    }

    "OfflineResources" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                      離線資源管理器                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "正在啟動離線資源管理器..." -ForegroundColor Cyan
        Write-Host ""
    }

    "ExternalTools" {
        Write-Host "╔$($sep)╗" -ForegroundColor Cyan
        Write-Host "║                      外部工具管理器                                      ║" -ForegroundColor Cyan
        Write-Host "╚$($sep)╝" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "正在啟動外部工具管理器..." -ForegroundColor Cyan
        Write-Host ""
    }

}
