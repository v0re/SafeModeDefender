<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
# ============================================================================
# Offline_Resources_Manager.ps1 - 離線資源管理器
# 
# 功能：
# - 檢測網路狀態
# - 管理離線資源（工具執行檔、病毒資料庫、配置檔）
# - 提供資源更新機制
# - 顯示資源狀態和時效性
# ============================================================================

param(
    [switch]$CheckStatus,
    [switch]$Update,
    [switch]$Force,
    [switch]$CLI
)

# 設定 UTF-8 編碼
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 離線資源定義
$OfflineResources = @{
    "ClamAV_Database" = @{
        Name = "ClamAV 病毒資料庫"
        Files = @(
            @{
                Name = "main.cvd"
                URL = "http://database.clamav.net/main.cvd"
                Size = "~160 MB"
                UpdateFrequency = "每週"
            }
            @{
                Name = "daily.cvd"
                URL = "http://database.clamav.net/daily.cvd"
                Size = "~80 MB"
                UpdateFrequency = "每日"
            }
            @{
                Name = "bytecode.cvd"
                URL = "http://database.clamav.net/bytecode.cvd"
                Size = "~300 KB"
                UpdateFrequency = "每月"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\ClamAV\database"
        Critical = $true
        MaxAge = 30  # 天數
    }
    
    "WinUtil_Scripts" = @{
        Name = "WinUtil 腳本和配置"
        Files = @(
            @{
                Name = "winutil.ps1"
                URL = "https://github.com/ChrisTitusTech/winutil/raw/main/winutil.ps1"
                Size = "~50 KB"
                UpdateFrequency = "不定期"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\WinUtil"
        Critical = $false
        MaxAge = 90  # 天數
    }
    
    "Optimizer" = @{
        Name = "Optimizer 執行檔"
        Files = @(
            @{
                Name = "Optimizer.exe"
                URL = "https://github.com/hellzerg/optimizer/releases/latest/download/Optimizer-16.7.exe"
                Size = "~2 MB"
                UpdateFrequency = "每月"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\Optimizer"
        Critical = $false
        MaxAge = 180  # 天數
    }
    
    "TestDisk" = @{
        Name = "TestDisk & PhotoRec"
        Files = @(
            @{
                Name = "testdisk-7.2.win64.zip"
                URL = "https://www.cgsecurity.org/Download_and_donate.php/testdisk-7.2.win64.zip"
                Size = "~5 MB"
                UpdateFrequency = "不定期"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\TestDisk"
        Critical = $false
        MaxAge = 365  # 天數
    }
    
    "simplewall" = @{
        Name = "simplewall 防火牆工具"
        Files = @(
            @{
                Name = "simplewall.exe"
                URL = "https://github.com/henrypp/simplewall/releases/latest/download/simplewall-3.8.3-setup.exe"
                Size = "~2 MB"
                UpdateFrequency = "每月"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\simplewall"
        Critical = $false
        MaxAge = 180  # 天數
    }
    
    "PrivescCheck" = @{
        Name = "PrivescCheck 腳本"
        Files = @(
            @{
                Name = "PrivescCheck.ps1"
                URL = "https://github.com/itm4n/PrivescCheck/raw/master/PrivescCheck.ps1"
                Size = "~200 KB"
                UpdateFrequency = "不定期"
            }
        )
        LocalPath = "$PSScriptRoot\..\Tools\PrivescCheck"
        Critical = $false
        MaxAge = 180  # 天數
    }
}

# 檢測網路狀態
function Test-NetworkConnection {
    try {
        $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        return $ping
    }
    catch {
        return $false
    }
}

# 檢查資源狀態
function Get-ResourceStatus {
    param([string]$ResourceKey)
    
    $resource = $OfflineResources[$ResourceKey]
    $localPath = $resource.LocalPath
    
    $status = @{
        Name = $resource.Name
        Exists = $false
        Files = @()
        TotalSize = 0
        OldestFile = $null
        Age = $null
        IsOutdated = $false
    }
    
    if (-not (Test-Path $localPath)) {
        return $status
    }
    
    $status.Exists = $true
    $oldestDate = Get-Date
    
    foreach ($file in $resource.Files) {
        $filePath = Join-Path $localPath $file.Name
        
        if (Test-Path $filePath) {
            $fileInfo = Get-Item $filePath
            $status.Files += @{
                Name = $file.Name
                Size = $fileInfo.Length
                LastModified = $fileInfo.LastWriteTime
            }
            
            $status.TotalSize += $fileInfo.Length
            
            if ($fileInfo.LastWriteTime -lt $oldestDate) {
                $oldestDate = $fileInfo.LastWriteTime
                $status.OldestFile = $file.Name
            }
        }
    }
    
    if ($status.Files.Count -gt 0) {
        $status.Age = (Get-Date) - $oldestDate
        $status.IsOutdated = $status.Age.Days -gt $resource.MaxAge
    }
    
    return $status
}

# 顯示所有資源狀態
function Show-AllResourcesStatus {
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      離線資源狀態檢查                                    ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # 檢測網路狀態
    $hasNetwork = Test-NetworkConnection
    if ($hasNetwork) {
        Write-Host "  網路狀態：✓ 已連線（可以更新資源）" -ForegroundColor Green
    }
    else {
        Write-Host "  網路狀態：✗ 無連線（離線模式）" -ForegroundColor Yellow
    }
    Write-Host ""
    
    foreach ($key in $OfflineResources.Keys | Sort-Object) {
        $resource = $OfflineResources[$key]
        $status = Get-ResourceStatus -ResourceKey $key
        
        Write-Host "  【$($resource.Name)】" -ForegroundColor Cyan
        
        if ($status.Exists -and $status.Files.Count -gt 0) {
            $sizeInMB = [math]::Round($status.TotalSize / 1MB, 2)
            $ageText = "$($status.Age.Days) 天前"
            
            if ($status.IsOutdated) {
                Write-Host "    狀態：⚠ 已過期（$ageText）" -ForegroundColor Yellow
            }
            else {
                Write-Host "    狀態：✓ 正常（$ageText）" -ForegroundColor Green
            }
            
            Write-Host "    大小：$sizeInMB MB" -ForegroundColor Gray
            Write-Host "    檔案：$($status.Files.Count) 個" -ForegroundColor Gray
            
            if ($resource.Critical -and $status.IsOutdated) {
                Write-Host "    建議：此資源為關鍵資源，建議盡快更新" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    狀態：✗ 未安裝" -ForegroundColor Red
            
            if ($resource.Critical) {
                Write-Host "    警告：此資源為關鍵資源，必須安裝才能使用相關功能" -ForegroundColor Red
            }
        }
        
        Write-Host ""
    }
}

# 下載單一資源
function Download-Resource {
    param(
        [string]$ResourceKey,
        [switch]$Force
    )
    
    $resource = $OfflineResources[$ResourceKey]
    $localPath = $resource.LocalPath
    
    # 檢查網路
    if (-not (Test-NetworkConnection)) {
        Write-Host "[錯誤] 無網路連線，無法下載資源" -ForegroundColor Red
        return $false
    }
    
    # 檢查是否需要更新
    $status = Get-ResourceStatus -ResourceKey $ResourceKey
    if ($status.Exists -and -not $status.IsOutdated -and -not $Force) {
        Write-Host "[資訊] $($resource.Name) 已是最新版本，無需更新" -ForegroundColor Green
        return $true
    }
    
    # 創建目錄
    if (-not (Test-Path $localPath)) {
        New-Item -ItemType Directory -Path $localPath -Force | Out-Null
    }
    
    Write-Host "`n[資訊] 正在下載 $($resource.Name)..." -ForegroundColor Cyan
    
    $success = $true
    foreach ($file in $resource.Files) {
        $filePath = Join-Path $localPath $file.Name
        
        Write-Host "  下載：$($file.Name) ($($file.Size))" -ForegroundColor Gray
        
        try {
            Invoke-WebRequest -Uri $file.URL -OutFile $filePath -UseBasicParsing -ErrorAction Stop
            Write-Host "  ✓ 完成" -ForegroundColor Green
        }
        catch {
            Write-Host "  ✗ 失敗：$($_.Exception.Message)" -ForegroundColor Red
            $success = $false
        }
    }
    
    if ($success) {
        Write-Host "`n[成功] $($resource.Name) 下載完成！" -ForegroundColor Green
    }
    else {
        Write-Host "`n[警告] $($resource.Name) 部分檔案下載失敗" -ForegroundColor Yellow
    }
    
    return $success
}

# 更新所有資源
function Update-AllResources {
    param([switch]$Force)
    
    Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      更新離線資源                                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # 檢查網路
    if (-not (Test-NetworkConnection)) {
        Write-Host "[錯誤] 無網路連線，無法更新資源" -ForegroundColor Red
        Write-Host "[提示] 請在有網路的環境下執行更新，或使用含網路功能的安全模式" -ForegroundColor Yellow
        return
    }
    
    $totalSuccess = 0
    $totalFail = 0
    
    foreach ($key in $OfflineResources.Keys | Sort-Object) {
        if (Download-Resource -ResourceKey $key -Force:$Force) {
            $totalSuccess++
        }
        else {
            $totalFail++
        }
    }
    
    Write-Host "`n══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "更新完成：成功 $totalSuccess 個，失敗 $totalFail 個" -ForegroundColor $(if ($totalFail -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "══════════════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
}

# 主邏輯
if ($CheckStatus) {
    Show-AllResourcesStatus
}
elseif ($Update) {
    Update-AllResources -Force:$Force
}
else {
    # 預設顯示狀態
    Show-AllResourcesStatus
    
    if (-not $CLI) {
        Write-Host "請選擇操作：" -ForegroundColor Cyan
        Write-Host "  [U] 更新所有資源" -ForegroundColor Yellow
        Write-Host "  [F] 強制更新所有資源（覆蓋現有檔案）" -ForegroundColor Yellow
        Write-Host "  [Q] 退出" -ForegroundColor Gray
        Write-Host ""
        
        $choice = Read-Host "請選擇"
        
        switch ($choice.ToUpper()) {
            "U" {
                Update-AllResources
            }
            "F" {
                Update-AllResources -Force
            }
            "Q" {
                Write-Host "退出" -ForegroundColor Gray
            }
            default {
                Write-Host "[錯誤] 無效的選擇" -ForegroundColor Red
            }
        }
    }
}
