<#
.SYNOPSIS
    提供所有外部工具下載連結

.DESCRIPTION
    提供 SafeModeDefender 所需的所有外部工具的官方下載連結
    包括：ClamAV, WinUtil, TestDisk, Optimizer, simplewall, PrivescCheck
    
.NOTES
    Author: SafeModeDefender Team
    Version: 1.0
#>

[CmdletBinding()]
param()

# 設定輸出編碼為 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 設定下載目錄
$DownloadDir = Join-Path $PSScriptRoot "External_Tools"
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
}

Write-Host "╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                  提供所有外部工具下載連結                               ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 工具列表
$tools = @(
    @{
        Name = "ClamAV"
        Url = "https://www.clamav.net/downloads/production/clamav-1.4.1.win.x64.zip"
        FileName = "clamav-1.4.1.win.x64.zip"
        Description = "開源防毒引擎"
    },
    @{
        Name = "Chris Titus Tech's Windows Utility"
        Url = "https://github.com/ChrisTitusTech/winutil/releases/latest/download/winutil.ps1"
        FileName = "winutil.ps1"
        Description = "全能 Windows 工具"
    },
    @{
        Name = "TestDisk & PhotoRec"
        Url = "https://www.cgsecurity.org/testdisk-7.2.win64.zip"
        FileName = "testdisk-7.2.win64.zip"
        Description = "資料救援工具"
    },
    @{
        Name = "Optimizer"
        Url = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
        FileName = "Optimizer-16.7.exe"
        Description = "隱私與安全增強工具"
    },
    @{
        Name = "simplewall"
        Url = "https://github.com/henrypp/simplewall/releases/download/v.3.8.3/simplewall-3.8.3-bin.zip"
        FileName = "simplewall-3.8.3-bin.zip"
        Description = "輕量級防火牆管理工具"
    },
    @{
        Name = "PrivescCheck"
        Url = "https://github.com/itm4n/PrivescCheck/raw/master/PrivescCheck.ps1"
        FileName = "PrivescCheck.ps1"
        Description = "權限提升漏洞檢測工具"
    }
)

# 提供下載連結
function Show-ToolLink {
    param(
        [string]$Name,
        [string]$Url,
        [string]$FileName,
        [string]$Description
    )
    
    $FilePath = Join-Path $DownloadDir $FileName
    
    Write-Host "[$Name]" -ForegroundColor Yellow
    Write-Host "  描述: $Description" -ForegroundColor Gray
    
    if (Test-Path $FilePath) {
        Write-Host "  狀態: [已存在]" -ForegroundColor Green
        return $true
    }
    
    Write-Host "  下載連結: $Url" -ForegroundColor Cyan
    Write-Host "  放置路徑: $FilePath" -ForegroundColor Gray
    
    return $false
}

# 顯示所有工具下載連結
$existCount = 0
$pendingUrls = @()

foreach ($tool in $tools) {
    $result = Show-ToolLink -Name $tool.Name -Url $tool.Url -FileName $tool.FileName -Description $tool.Description
    if ($result) {
        $existCount++
    } else {
        $pendingUrls += $tool.Url
    }
    Write-Host ""
}

# 顯示結果
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "連結提供完成！" -ForegroundColor Green
Write-Host "  已存在: $existCount" -ForegroundColor Green
Write-Host "  待下載: $($pendingUrls.Count)" -ForegroundColor $(if ($pendingUrls.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host "  放置目錄: $DownloadDir" -ForegroundColor Cyan
Write-Host ""

if ($pendingUrls.Count -gt 0) {
    Write-Host "請手動下載上述工具並放置到對應的放置路徑，然後即可在 SafeModeDefender 中使用。" -ForegroundColor Yellow
    Write-Host ""
    $openAll = Read-Host "是否在瀏覽器中開啟所有待下載工具的頁面？(Y/N)"
    if ($openAll -eq 'Y' -or $openAll -eq 'y') {
        foreach ($url in $pendingUrls) {
            Start-Process $url
            Start-Sleep -Milliseconds 500
        }
        Write-Host "[資訊] 已在瀏覽器中開啟所有下載頁面" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
