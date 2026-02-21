# ============================================================================
# External_Tools_Manager.ps1 - 外部工具管理器（v2.1）
# 
# 功能：
# - 管理外部安全工具的整合
# - 提供統一的中文化交互式介面
# - 支援命令列和圖形化雙模式
# - 使用 Wrapper 腳本架構實現工具封裝
# ============================================================================

param(
    [string]$Tool = "",
    [string]$Action = "",
    [switch]$CLI,
    [switch]$Silent
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 工具定義（基於 GitHub 搜尋結果的精選工具）
$ToolsDatabase = @{
    "winutil" = @{
        Name = "Chris Titus Tech's Windows Utility"
        ShortName = "WinUtil"
        Description = "全能 Windows 工具，涵蓋系統優化、修復、調整、安全強化等功能"
        GitHub = "https://github.com/ChrisTitusTech/winutil"
        Stars = "47,600+"
        Wrapper = "WinUtil_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "系統工具"
        Priority = "High"
    }
    
    "optimizer" = @{
        Name = "Optimizer"
        ShortName = "Optimizer"
        Description = "先進的 Windows 隱私和安全增強工具，修復註冊表、禁用服務、關閉遙測"
        GitHub = "https://github.com/hellzerg/optimizer"
        Stars = "18,000+"
        Wrapper = "Optimizer_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "隱私與安全"
        Priority = "High"
    }
    
    "testdisk" = @{
        Name = "TestDisk & PhotoRec"
        ShortName = "TestDisk"
        Description = "強大的磁碟分區恢復和引導扇區修復工具，支援 480+ 檔案格式恢復"
        GitHub = "https://github.com/cgsecurity/testdisk"
        Stars = "2,300+"
        Wrapper = "TestDisk_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "資料救援"
        Priority = "High"
    }
    
    "clamav" = @{
        Name = "ClamAV"
        ShortName = "ClamAV"
        Description = "開源跨平台防毒引擎，檢測木馬、病毒、惡意軟體"
        GitHub = "https://github.com/Cisco-Talos/clamav"
        Stars = "6,256+"
        Wrapper = "ClamAV_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "惡意軟體檢測"
        Priority = "High"
    }
    
    "simplewall" = @{
        Name = "simplewall"
        ShortName = "simplewall"
        Description = "輕量級 Windows 過濾平台 (WFP) 管理工具"
        GitHub = "https://github.com/henrypp/simplewall"
        Stars = "8,000+"
        Wrapper = "simplewall_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "防火牆管理"
        Priority = "Medium"
    }
    
    "privesccheck" = @{
        Name = "PrivescCheck"
        ShortName = "PrivescCheck"
        Description = "PowerShell 權限提升漏洞檢測工具"
        GitHub = "https://github.com/itm4n/PrivescCheck"
        Stars = "3,700+"
        Wrapper = "PrivescCheck_Wrapper.ps1"
        SafeModeSupport = $true
        Category = "安全審計"
        Priority = "Medium"
    }
}

# 工具目錄
$ToolsDir = "$PSScriptRoot\..\Tools"
$WrappersDir = "$PSScriptRoot\Tool_Wrappers"

if (-not (Test-Path $ToolsDir)) {
    New-Item -ItemType Directory -Path $ToolsDir -Force | Out-Null
}

# 顯示工具列表
function Show-ToolsList {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      可用的外部工具                                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    Write-Host "  基於 GitHub 搜尋結果精選的優質開源安全工具" -ForegroundColor Gray
    Write-Host "  所有工具均保留原始授權，SafeModeDefender 僅提供統一介面" -ForegroundColor Gray
    Write-Host ""
    
    # 按優先級分組顯示
    $highPriority = $ToolsDatabase.GetEnumerator() | Where-Object { $_.Value.Priority -eq "High" } | Sort-Object { $_.Value.Stars } -Descending
    $mediumPriority = $ToolsDatabase.GetEnumerator() | Where-Object { $_.Value.Priority -eq "Medium" } | Sort-Object { $_.Value.Stars } -Descending
    
    Write-Host "  【高優先級工具】" -ForegroundColor Yellow
    Write-Host ""
    
    $index = 1
    foreach ($entry in $highPriority) {
        $key = $entry.Key
        $tool = $entry.Value
        $wrapperExists = Test-Path (Join-Path $WrappersDir $tool.Wrapper)
        $status = if ($wrapperExists) { "[✓ 已整合]" } else { "[⏳ 開發中]" }
        $safeMode = if ($tool.SafeModeSupport) { "✓" } else { "✗" }
        
        Write-Host "  [$index] $($tool.Name) $status" -ForegroundColor Yellow
        Write-Host "      描述：$($tool.Description)" -ForegroundColor Gray
        Write-Host "      類別：$($tool.Category) | 星級：$($tool.Stars) ⭐ | 安全模式：$safeMode" -ForegroundColor Gray
        Write-Host "      GitHub：$($tool.GitHub)" -ForegroundColor DarkGray
        Write-Host ""
        $index++
    }
    
    Write-Host "  【中優先級工具】" -ForegroundColor Cyan
    Write-Host ""
    
    foreach ($entry in $mediumPriority) {
        $key = $entry.Key
        $tool = $entry.Value
        $wrapperExists = Test-Path (Join-Path $WrappersDir $tool.Wrapper)
        $status = if ($wrapperExists) { "[✓ 已整合]" } else { "[⏳ 開發中]" }
        $safeMode = if ($tool.SafeModeSupport) { "✓" } else { "✗" }
        
        Write-Host "  [$index] $($tool.Name) $status" -ForegroundColor Cyan
        Write-Host "      描述：$($tool.Description)" -ForegroundColor Gray
        Write-Host "      類別：$($tool.Category) | 星級：$($tool.Stars) ⭐ | 安全模式：$safeMode" -ForegroundColor Gray
        Write-Host "      GitHub：$($tool.GitHub)" -ForegroundColor DarkGray
        Write-Host ""
        $index++
    }
}

# 執行工具（使用 Wrapper 腳本）
function Invoke-ToolWrapper {
    param(
        [string]$ToolKey,
        [string]$Action = ""
    )
    
    if (-not $ToolsDatabase.ContainsKey($ToolKey)) {
        Write-Host "[錯誤] 未知的工具：$ToolKey" -ForegroundColor Red
        return
    }
    
    $tool = $ToolsDatabase[$ToolKey]
    $wrapperPath = Join-Path $WrappersDir $tool.Wrapper
    
    if (-not (Test-Path $wrapperPath)) {
        Write-Host "[錯誤] 工具封裝腳本不存在：$($tool.Wrapper)" -ForegroundColor Red
        Write-Host "[資訊] 此工具可能尚未完成整合" -ForegroundColor Yellow
        return
    }
    
    # 執行 Wrapper 腳本
    $params = @{
        FilePath = "powershell.exe"
        ArgumentList = @(
            "-ExecutionPolicy", "Bypass",
            "-File", $wrapperPath
        )
        Wait = $true
        NoNewWindow = $true
    }
    
    if ($CLI) {
        $params.ArgumentList += "-CLI"
    }
    
    if ($Action) {
        $params.ArgumentList += "-Action", $Action
    }
    
    if ($Silent) {
        $params.ArgumentList += "-Silent"
    }
    
    Start-Process @params
}

# 顯示交互式選單
function Show-InteractiveMenu {
    Write-Host "`n請選擇要使用的工具：" -ForegroundColor Cyan
    Write-Host ""
    
    # 建立工具索引
    $toolsList = @()
    $index = 1
    
    # 高優先級工具
    $highPriority = $ToolsDatabase.GetEnumerator() | Where-Object { $_.Value.Priority -eq "High" } | Sort-Object { $_.Value.Stars } -Descending
    foreach ($entry in $highPriority) {
        $wrapperExists = Test-Path (Join-Path $WrappersDir $entry.Value.Wrapper)
        if ($wrapperExists) {
            Write-Host "  [$index] $($entry.Value.Name)" -ForegroundColor Yellow
            $toolsList += $entry.Key
            $index++
        }
    }
    
    # 中優先級工具
    $mediumPriority = $ToolsDatabase.GetEnumerator() | Where-Object { $_.Value.Priority -eq "Medium" } | Sort-Object { $_.Value.Stars } -Descending
    foreach ($entry in $mediumPriority) {
        $wrapperExists = Test-Path (Join-Path $WrappersDir $entry.Value.Wrapper)
        if ($wrapperExists) {
            Write-Host "  [$index] $($entry.Value.Name)" -ForegroundColor Cyan
            $toolsList += $entry.Key
            $index++
        }
    }
    
    Write-Host ""
    Write-Host "  [L] 顯示完整工具列表（包含未整合的工具）" -ForegroundColor Gray
    Write-Host "  [O] 離線資源管理" -ForegroundColor Gray
    Write-Host "  [B] 返回主選單" -ForegroundColor Gray
    Write-Host ""
    
    $choice = Read-Host "請選擇 (1-$($toolsList.Count), L, B)"
    
    if ($choice -eq "L" -or $choice -eq "l") {
        Show-ToolsList
        Read-Host "`n按 Enter 繼續..."
        return "menu"
    }
    elseif ($choice -eq "O" -or $choice -eq "o") {
        & "$PSScriptRoot\Offline_Resources_Manager.ps1"
        Read-Host "`n按 Enter 繼續..."
        return "menu"
    }
    elseif ($choice -eq "B" -or $choice -eq "b") {
        return "exit"
    }
    elseif ($choice -match '^\d+$') {
        $choiceNum = [int]$choice
        if ($choiceNum -ge 1 -and $choiceNum -le $toolsList.Count) {
            $selectedTool = $toolsList[$choiceNum - 1]
            Invoke-ToolWrapper -ToolKey $selectedTool
            return "menu"
        }
        else {
            Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
            Start-Sleep -Seconds 1
            return "menu"
        }
    }
    else {
        Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
        Start-Sleep -Seconds 1
        return "menu"
    }
}

# 主邏輯
if ($Tool) {
    # 命令列模式：直接執行指定工具
    if ($Tool.ToLower() -eq "list") {
        Show-ToolsList
    }
    else {
        Invoke-ToolWrapper -ToolKey $Tool.ToLower() -Action $Action
    }
}
else {
    # 交互式模式
    if ($CLI) {
        # CLI 模式但未指定工具，顯示列表
        Show-ToolsList
    }
    else {
        # GUI 交互模式
        do {
            $result = Show-InteractiveMenu
        } while ($result -eq "menu")
    }
}
