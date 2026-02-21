<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# PrivescCheck_Wrapper.ps1 - PrivescCheck 中文化封裝腳本
# 
# 功能：
# - 自動下載和執行 PrivescCheck
# - 提供中文化輸出和報告
# - 翻譯所有檢測結果
# ============================================================================

param(
    [string]$Action = "",
    [switch]$CLI,
    [switch]$Silent,
    [switch]$Extended
)

# 設定 UTF-8 編碼
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 工具資訊
$ToolName = "PrivescCheck"
$ToolDescription = "PowerShell 權限提升漏洞檢測工具"
$GitHubRepo = "itm4n/PrivescCheck"
$DownloadURL = "https://raw.githubusercontent.com/itm4n/PrivescCheck/master/PrivescCheck.ps1"
$ToolsDir = "$PSScriptRoot\..\..\Tools\PrivescCheck"
$ReportsDir = "$PSScriptRoot\..\..\Reports"

# 創建目錄
if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}
if (-not (Test-Path $ReportsDir)) {
    New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
}

# 中文翻譯對照表
$Translations = @{
    # 類別翻譯
    "TA0001 - Initial Access" = "TA0001 - 初始訪問"
    "TA0002 - Execution" = "TA0002 - 執行"
    "TA0003 - Persistence" = "TA0003 - 持久化"
    "TA0004 - Privilege Escalation" = "TA0004 - 權限提升"
    "TA0005 - Defense Evasion" = "TA0005 - 防禦規避"
    "TA0006 - Credential Access" = "TA0006 - 憑證訪問"
    "TA0007 - Discovery" = "TA0007 - 發現"
    "TA0008 - Lateral Movement" = "TA0008 - 橫向移動"
    "Misc - Process and Thread Permissions" = "雜項 - 進程和執行緒權限"
    "Misc - User Sessions" = "雜項 - 使用者會話"
    
    # 嚴重性翻譯
    "High" = "高"
    "Medium" = "中"
    "Low" = "低"
    "Informational" = "資訊"
    
    # 檢查項目翻譯
    "Hardening - BitLocker" = "強化 - BitLocker 加密"
    "Hardening - Credential Guard" = "強化 - 憑證防護"
    "Hardening - LSA Protection" = "強化 - LSA 保護"
    "Hardening - LAPS" = "強化 - 本地管理員密碼解決方案"
    "Hardening - PowerShell Logging" = "強化 - PowerShell 日誌記錄"
    "Hardening - UAC" = "強化 - 使用者帳戶控制"
    
    # 狀態翻譯
    "Vulnerable" = "存在漏洞"
    "Not vulnerable" = "無漏洞"
    "Enabled" = "已啟用"
    "Disabled" = "已禁用"
    "Active" = "活動"
    "Disconnected" = "已斷開"
}

# 顯示工具資訊
function Show-ToolInfo {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                          $ToolName                                       ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  描述：$ToolDescription" -ForegroundColor Gray
    Write-Host "  GitHub：https://github.com/$GitHubRepo" -ForegroundColor Gray
    Write-Host "  授權：BSD 3-Clause" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  此工具會檢測系統中可能被利用來提升權限的漏洞" -ForegroundColor Yellow
    Write-Host "  包括：配置錯誤、弱權限、未修補的漏洞等" -ForegroundColor Yellow
    Write-Host ""
}

# 翻譯文本
function Translate-Text {
    param([string]$Text)
    
    foreach ($key in $Translations.Keys) {
        $Text = $Text -replace [regex]::Escape($key), $Translations[$key]
    }
    
    return $Text
}

# 下載 PrivescCheck
function Download-PrivescCheck {
    Write-Host "`n[資訊] 正在下載 $ToolName..." -ForegroundColor Yellow
    
    $scriptPath = Join-Path $ToolsDir "PrivescCheck.ps1"
    
    try {
        Invoke-WebRequest -Uri $DownloadURL -OutFile $scriptPath -UseBasicParsing
        Write-Host "[✓] 下載完成" -ForegroundColor Green
        return $scriptPath
    }
    catch {
        Write-Host "[錯誤] 下載失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# 執行 PrivescCheck 並翻譯輸出
function Invoke-PrivescCheckChinese {
    param([string]$ScriptPath)
    
    Write-Host "`n[資訊] 正在執行 $ToolName..." -ForegroundColor Yellow
    Write-Host "[資訊] 這可能需要幾分鐘時間..." -ForegroundColor Gray
    Write-Host ""
    
    try {
        # 載入 PrivescCheck
        . $ScriptPath
        
        # 執行檢測
        $results = if ($Extended) {
            Invoke-PrivescCheck -Extended
        } else {
            Invoke-PrivescCheck
        }
        
        # 生成中文報告
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $reportPath = Join-Path $ReportsDir "PrivescCheck_$timestamp.txt"
        
        # 翻譯並保存結果
        $translatedResults = $results | ForEach-Object {
            $line = $_.ToString()
            Translate-Text -Text $line
        }
        
        $translatedResults | Out-File -FilePath $reportPath -Encoding UTF8
        
        # 顯示翻譯後的結果
        Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                      PrivescCheck 檢測結果摘要                           ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
        
        $translatedResults | ForEach-Object {
            $line = $_
            
            # 根據嚴重性著色
            if ($line -match "高") {
                Write-Host $line -ForegroundColor Red
            }
            elseif ($line -match "中") {
                Write-Host $line -ForegroundColor Yellow
            }
            elseif ($line -match "低") {
                Write-Host $line -ForegroundColor Cyan
            }
            elseif ($line -match "資訊") {
                Write-Host $line -ForegroundColor Gray
            }
            else {
                Write-Host $line
            }
        }
        
        Write-Host "`n[✓] 檢測完成" -ForegroundColor Green
        Write-Host "[資訊] 完整報告已保存到：$reportPath" -ForegroundColor Gray
        
        # 生成 HTML 報告
        Generate-HTMLReport -Results $translatedResults -ReportPath $reportPath
        
        return $true
    }
    catch {
        Write-Host "[錯誤] 執行失敗：$($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# 生成 HTML 報告
function Generate-HTMLReport {
    param(
        [array]$Results,
        [string]$ReportPath
    )
    
    $htmlPath = $ReportPath -replace '\.txt$', '.html'
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $html = @"
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PrivescCheck 檢測報告</title>
    <style>
        body {
            font-family: 'Microsoft YaHei', 'Segoe UI', Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0;
            font-size: 32px;
        }
        .header p {
            margin: 10px 0 0 0;
            opacity: 0.9;
        }
        .result-item {
            background: white;
            padding: 20px;
            margin-bottom: 15px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-left: 4px solid #ccc;
        }
        .result-item.high {
            border-left-color: #e74c3c;
        }
        .result-item.medium {
            border-left-color: #f39c12;
        }
        .result-item.low {
            border-left-color: #3498db;
        }
        .result-item.info {
            border-left-color: #95a5a6;
        }
        .severity {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 4px;
            font-weight: bold;
            font-size: 12px;
            margin-left: 10px;
        }
        .severity.high {
            background-color: #e74c3c;
            color: white;
        }
        .severity.medium {
            background-color: #f39c12;
            color: white;
        }
        .severity.low {
            background-color: #3498db;
            color: white;
        }
        .severity.info {
            background-color: #95a5a6;
            color: white;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding: 20px;
            color: #7f8c8d;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 PrivescCheck 權限提升漏洞檢測報告</h1>
        <p>生成時間：$timestamp</p>
        <p>工具版本：PrivescCheck (中文化版本)</p>
    </div>
    
    <div class="results">
"@

    foreach ($line in $Results) {
        $severity = "info"
        $severityText = "資訊"
        
        if ($line -match "高") {
            $severity = "high"
            $severityText = "高"
        }
        elseif ($line -match "中") {
            $severity = "medium"
            $severityText = "中"
        }
        elseif ($line -match "低") {
            $severity = "low"
            $severityText = "低"
        }
        
        $html += @"
        <div class="result-item $severity">
            <span class="severity $severity">$severityText</span>
            <p>$line</p>
        </div>
"@
    }
    
    $html += @"
    </div>
    
    <div class="footer">
        <p>此報告由 SafeModeDefender 生成</p>
        <p>PrivescCheck 原作者：Thomas DIOT (itm4n)</p>
        <p>GitHub：<a href="https://github.com/itm4n/PrivescCheck">https://github.com/itm4n/PrivescCheck</a></p>
    </div>
</body>
</html>
"@
    
    $html | Out-File -FilePath $htmlPath -Encoding UTF8
    Write-Host "[✓] HTML 報告已生成：$htmlPath" -ForegroundColor Green
}

# 主程式
function Main {
    Show-ToolInfo
    
    # 檢查是否已下載
    $scriptPath = Join-Path $ToolsDir "PrivescCheck.ps1"
    
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = Download-PrivescCheck
        if (-not $scriptPath) {
            return
        }
    }
    else {
        Write-Host "[✓] $ToolName 腳本已存在" -ForegroundColor Green
        
        if (-not $Silent) {
            $choice = Read-Host "`n是否重新下載最新版本？(Y/N)"
            if ($choice -eq "Y" -or $choice -eq "y") {
                $scriptPath = Download-PrivescCheck
                if (-not $scriptPath) {
                    return
                }
            }
        }
    }
    
    # 執行檢測
    Invoke-PrivescCheckChinese -ScriptPath $scriptPath
}

# 執行主程式
Main

if (-not $CLI) {
    Write-Host "`n按任意鍵繼續..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
