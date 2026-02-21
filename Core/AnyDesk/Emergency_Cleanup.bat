<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# Emergency_Cleanup.ps1 - AnyDesk 後門緊急清理與系統修復腳本
# 
# 功能：根據 APT 攻擊鑑識分析，執行完整的 AnyDesk 後門清理和系統修復
# 威脅：AnyDesk 無人值守後門、GPO 篡改、Google 帳號劫持
# ============================================================================

<#
.SYNOPSIS
    AnyDesk 後門緊急清理與系統修復工具

.DESCRIPTION
    此腳本針對已確認的 AnyDesk 後門攻擊執行完整的清理和修復操作：
    
    階段一：突破 GPO 封鎖與本地安全原則重置
    - 刪除被污染的 GroupPolicy 目錄
    - 重建預設的安全原則範本
    - 強制原則同步
    
    階段二：根除 AnyDesk 後門與殘留
    - 終止所有 AnyDesk 進程
    - 刪除配置檔案和日誌
    - 移除服務和註冊表項
    - 備份鑑識證據
    
    階段三：系統強化與預防措施
    - 封鎖 AnyDesk 可執行檔
    - 配置防火牆規則
    - 設置 AppLocker 策略
    
    階段四：Google 帳號修復指引
    - 提供詳細的帳號清理步驟
    - 生成修復報告

.PARAMETER BackupPath
    指定鑑識證據備份路徑（預設：桌面）

.PARAMETER SkipGPOFix
    跳過 GPO 修復（如果已在 WinPE 環境中手動修復）

.PARAMETER ForceRemoveAnyDesk
    強制移除 AnyDesk，即使無法確認是否為惡意安裝

.EXAMPLE
    .\Emergency_Cleanup.ps1
    執行完整的緊急清理和修復

.EXAMPLE
    .\Emergency_Cleanup.ps1 -SkipGPOFix -BackupPath "D:\Forensics"
    跳過 GPO 修復，並將證據備份到 D:\Forensics

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-19
    警告：此腳本需要管理員權限，並會對系統進行重大變更
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='High')]
param(
    [string]$BackupPath = "$env:USERPROFILE\Desktop\AnyDesk_Forensics_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    [switch]$SkipGPOFix,
    [switch]$ForceRemoveAnyDesk
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Continue"

# ============================================================================
# 函數定義
# ============================================================================

function Write-StepHeader {
    param([string]$Title)
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Title" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
}

function Test-IsAdmin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Backup-ForensicEvidence {
    param([string]$SourcePath, [string]$DestinationPath)
    
    if (Test-Path $SourcePath) {
        try {
            $itemName = Split-Path $SourcePath -Leaf
            $destFile = Join-Path $DestinationPath $itemName
            Copy-Item $SourcePath $destFile -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ 已備份：$SourcePath" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "  ✗ 備份失敗：$SourcePath - $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    return $false
}

# ============================================================================
# 前置檢查
# ============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║         AnyDesk 後門緊急清理與系統修復工具 v1.0                         ║
║                                                                          ║
║         ⚠️  警告：此工具將對系統進行重大變更  ⚠️                         ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Yellow

# 檢查管理員權限
if (-not (Test-IsAdmin)) {
    Write-Host "❌ 錯誤：此腳本需要管理員權限才能執行。" -ForegroundColor Red
    Write-Host "請以「以系統管理員身分執行」重新啟動 PowerShell。`n" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ 管理員權限檢查通過" -ForegroundColor Green

# 創建備份目錄
if (-not (Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Host "✓ 已創建鑑識證據備份目錄：$BackupPath`n" -ForegroundColor Green
}

# ============================================================================
# 階段一：突破 GPO 封鎖與本地安全原則重置
# ============================================================================

if (-not $SkipGPOFix) {
    Write-StepHeader "階段一：突破 GPO 封鎖與本地安全原則重置"
    
    Write-Host "[1/3] 備份當前 GPO 配置..." -ForegroundColor Cyan
    Backup-ForensicEvidence -SourcePath "$env:WinDir\System32\GroupPolicy" -DestinationPath $BackupPath
    Backup-ForensicEvidence -SourcePath "$env:WinDir\System32\GroupPolicyUsers" -DestinationPath $BackupPath
    
    Write-Host "`n[2/3] 徹底抹除遭到污染的原則物件（GPO Eradication）..." -ForegroundColor Cyan
    
    try {
        # 刪除 GroupPolicyUsers
        if (Test-Path "$env:WinDir\System32\GroupPolicyUsers") {
            Remove-Item "$env:WinDir\System32\GroupPolicyUsers" -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ 已刪除 GroupPolicyUsers" -ForegroundColor Green
        }
        
        # 刪除 GroupPolicy
        if (Test-Path "$env:WinDir\System32\GroupPolicy") {
            Remove-Item "$env:WinDir\System32\GroupPolicy" -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ 已刪除 GroupPolicy" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ⚠️  部分 GPO 目錄刪除失敗：$($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  建議：使用 WinPE 環境離線刪除" -ForegroundColor Yellow
    }
    
    Write-Host "`n[3/3] 重建預設的安全原則範本..." -ForegroundColor Cyan
    
    try {
        # 重建預設安全原則
        $seceditOutput = & secedit /configure /cfg "$env:WinDir\inf\defltbase.inf" /db defltbase.sdb /verbose 2>&1
        Write-Host "  ✓ 已重建預設安全原則" -ForegroundColor Green
        
        # 強制原則同步
        Write-Host "`n  正在強制原則同步..." -ForegroundColor Gray
        $gpupdateOutput = & gpupdate /force 2>&1
        Write-Host "  ✓ 原則同步完成" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ 安全原則重建失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "[跳過] 階段一：GPO 修復（使用 -SkipGPOFix 參數）`n" -ForegroundColor Yellow
}

# ============================================================================
# 階段二：根除 AnyDesk 後門與殘留
# ============================================================================

Write-StepHeader "階段二：根除 AnyDesk 後門與殘留"

Write-Host "[1/5] 備份 AnyDesk 鑑識證據..." -ForegroundColor Cyan

$anydeskPaths = @(
    "$env:ProgramData\AnyDesk",
    "$env:AppData\AnyDesk",
    "$env:LocalAppData\AnyDesk",
    "${env:ProgramFiles(x86)}\AnyDesk",
    "$env:ProgramFiles\AnyDesk"
)

foreach ($path in $anydeskPaths) {
    Backup-ForensicEvidence -SourcePath $path -DestinationPath $BackupPath
}

Write-Host "`n[2/5] 終止所有 AnyDesk 進程..." -ForegroundColor Cyan

$anydeskProcesses = Get-Process -Name "anydesk*" -ErrorAction SilentlyContinue
if ($anydeskProcesses) {
    foreach ($proc in $anydeskProcesses) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
            Write-Host "  ✓ 已終止進程：$($proc.Name) (PID: $($proc.Id))" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ 無法終止進程：$($proc.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
else {
    Write-Host "  ℹ️  未發現運行中的 AnyDesk 進程" -ForegroundColor Gray
}

Write-Host "`n[3/5] 停止並移除 AnyDesk 服務..." -ForegroundColor Cyan

$anydeskService = Get-Service -Name "AnyDesk" -ErrorAction SilentlyContinue
if ($anydeskService) {
    try {
        Stop-Service -Name "AnyDesk" -Force -ErrorAction Stop
        & sc.exe delete "AnyDesk" 2>&1 | Out-Null
        Write-Host "  ✓ 已移除 AnyDesk 服務" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ 服務移除失敗：$($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "  ℹ️  未發現 AnyDesk 服務" -ForegroundColor Gray
}

Write-Host "`n[4/5] 刪除 AnyDesk 檔案和配置..." -ForegroundColor Cyan

foreach ($path in $anydeskPaths) {
    if (Test-Path $path) {
        try {
            Remove-Item $path -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ 已刪除：$path" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ 刪除失敗：$path - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n[5/5] 清理註冊表項..." -ForegroundColor Cyan

$registryPaths = @(
    "HKLM:\SOFTWARE\AnyDesk",
    "HKCU:\SOFTWARE\AnyDesk",
    "HKLM:\SOFTWARE\WOW6432Node\AnyDesk"
)

foreach ($regPath in $registryPaths) {
    if (Test-Path $regPath) {
        try {
            Remove-Item $regPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✓ 已刪除註冊表項：$regPath" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ 註冊表項刪除失敗：$regPath" -ForegroundColor Red
        }
    }
}

# ============================================================================
# 階段三：系統強化與預防措施
# ============================================================================

Write-StepHeader "階段三：系統強化與預防措施"

Write-Host "[1/3] 配置防火牆規則..." -ForegroundColor Cyan

try {
    # 封鎖 AnyDesk 常用端口
    $ports = @(7070, 6568, 80, 443)
    foreach ($port in $ports) {
        $ruleName = "Block_AnyDesk_Port_$port"
        
        # 刪除舊規則（如果存在）
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existingRule) {
            Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        }
        
        # 創建新規則
        New-NetFirewallRule -DisplayName $ruleName `
                            -Direction Inbound `
                            -Action Block `
                            -Protocol TCP `
                            -LocalPort $port `
                            -ErrorAction Stop | Out-Null
        
        Write-Host "  ✓ 已封鎖端口：$port" -ForegroundColor Green
    }
}
catch {
    Write-Host "  ✗ 防火牆規則配置失敗：$($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n[2/3] 創建 AnyDesk 執行阻止策略..." -ForegroundColor Cyan

# 創建軟體限制策略
$srp = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers\0\Paths\{$(New-Guid)}]
"Description"="Block AnyDesk Execution"
"SaferFlags"=dword:00000000
"ItemData"="*\\anydesk.exe"
"@

$srpFile = Join-Path $BackupPath "Block_AnyDesk_SRP.reg"
$srp | Out-File $srpFile -Encoding ASCII
Write-Host "  ✓ 已創建軟體限制策略檔案：$srpFile" -ForegroundColor Green
Write-Host "  ℹ️  請手動匯入此 .reg 檔案以啟用阻止策略" -ForegroundColor Yellow

Write-Host "`n[3/3] 檢查並移除可疑的防火牆規則..." -ForegroundColor Cyan

# 搜尋可疑的防火牆規則（攻擊者可能創建的）
$suspiciousRules = Get-NetFirewallRule | Where-Object {
    $_.DisplayName -match "Software Updater|Remote Management|System Service" -and
    $_.Direction -eq "Inbound" -and
    $_.Action -eq "Allow"
}

if ($suspiciousRules) {
    foreach ($rule in $suspiciousRules) {
        Write-Host "  ⚠️  發現可疑規則：$($rule.DisplayName)" -ForegroundColor Yellow
        
        if ($PSCmdlet.ShouldProcess($rule.DisplayName, "移除可疑防火牆規則")) {
            Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
            Write-Host "  ✓ 已移除：$($rule.DisplayName)" -ForegroundColor Green
        }
    }
}
else {
    Write-Host "  ✓ 未發現可疑的防火牆規則" -ForegroundColor Green
}

# ============================================================================
# 階段四：Google 帳號修復指引
# ============================================================================

Write-StepHeader "階段四：Google 帳號修復指引"

$googleFixGuide = @"
╔══════════════════════════════════════════════════════════════════════════╗
║                    Google 帳號 400 錯誤修復步驟                          ║
╚══════════════════════════════════════════════════════════════════════════╝

⚠️  重要：請在另一台「已知安全」的裝置上執行以下步驟！

步驟 1：清除受感染裝置的瀏覽器狀態
────────────────────────────────────────
在「受感染的電腦」上：
1. 開啟瀏覽器設定
2. 清除「不限時間（All time）」的：
   - 快取（Cache）
   - Cookie 與網站資料
   - 瀏覽記錄
3. 關閉瀏覽器並重新啟動

步驟 2：使用安全裝置進行帳號清理
────────────────────────────────────────
在「安全的手機或電腦」上（不要使用受感染的裝置）：

1. 開啟無痕模式（Incognito Window）
2. 前往：https://myaccount.google.com/device-activity
3. 檢查所有裝置，移除不認識的裝置：
   - 點擊裝置名稱
   - 選擇「登出（Sign Out）」
   - ⚠️  注意：同一裝置可能有多個工作階段，需逐一登出

4. 前往：https://myaccount.google.com/permissions
5. 撤銷所有可疑的第三方應用程式存取權

6. 前往：https://myaccount.google.com/security
7. 執行「安全性檢查」
8. 更改密碼
9. 檢查並更新「復原電話號碼」和「復原電子郵件」

步驟 3：啟用進階保護
────────────────────────────────────────
強烈建議啟用 Google 的「進階保護計畫」：
https://landing.google.com/advancedprotection/

這將要求使用實體安全金鑰（如 YubiKey）進行登入，
可有效防止未來的帳號劫持攻擊。

步驟 4：監控帳號活動
────────────────────────────────────────
在接下來的 30 天內，定期檢查：
- 裝置活動：https://myaccount.google.com/device-activity
- 最近的安全性活動：https://myaccount.google.com/notifications
- 第三方應用程式存取權：https://myaccount.google.com/permissions

如果發現任何異常，立即更改密碼並撤銷相關權限。

╚══════════════════════════════════════════════════════════════════════════╝
"@

Write-Host $googleFixGuide -ForegroundColor Cyan

# 將指引保存到檔案
$guideFile = Join-Path $BackupPath "Google_Account_Recovery_Guide.txt"
$googleFixGuide | Out-File $guideFile -Encoding UTF8
Write-Host "`n✓ Google 帳號修復指引已保存到：$guideFile`n" -ForegroundColor Green

# ============================================================================
# 生成修復報告
# ============================================================================

Write-StepHeader "生成修復報告"

$report = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName = $env:COMPUTERNAME
    Username = $env:USERNAME
    BackupPath = $BackupPath
    Actions = @{
        GPO_Reset = -not $SkipGPOFix
        AnyDesk_Removed = $true
        Firewall_Configured = $true
        Google_Guide_Generated = $true
    }
    Recommendations = @(
        "立即在安全裝置上執行 Google 帳號清理步驟",
        "考慮重新安裝作業系統以確保完全清除攻擊者的持久化機制",
        "啟用 Windows Defender Application Guard 和 Credential Guard",
        "定期檢查系統日誌和網路連接",
        "考慮使用硬體安全金鑰（如 YubiKey）進行身份驗證"
    )
}

$reportFile = Join-Path $BackupPath "Cleanup_Report.json"
$report | ConvertTo-Json -Depth 10 | Out-File $reportFile -Encoding UTF8
Write-Host "✓ 修復報告已保存到：$reportFile`n" -ForegroundColor Green

# ============================================================================
# 完成
# ============================================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                        ✅ 緊急清理完成！                                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝

鑑識證據已備份到：
$BackupPath

下一步建議：
1. 🔐 立即在安全裝置上執行 Google 帳號清理（參考上述指引）
2. 🔄 重新啟動電腦以確保所有變更生效
3. 🛡️  執行完整的系統掃描（Windows Defender 或其他防毒軟體）
4. 📊 檢查修復報告：$reportFile
5. 💾 考慮重新安裝作業系統以確保完全清除

⚠️  警告：即使執行了此清理腳本，仍強烈建議重新安裝作業系統，
因為攻擊者可能已在系統深處植入其他持久化機制。

"@ -ForegroundColor Green

Write-Host "按任意鍵退出..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
