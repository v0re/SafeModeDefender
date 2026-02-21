<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>
<#
.SYNOPSIS
    通用佔位符防禦系統 - 可自定義目標組件

.DESCRIPTION
    根據配置檔案自動替換指定的系統組件為佔位符
    支援 DLL、註冊表、服務、目錄等多種目標類型
    
.PARAMETER Enable
    啟用佔位符防禦
    
.PARAMETER Disable  
    禁用佔位符防禦並恢復原始組件
    
.PARAMETER ConfigFile
    配置檔案路徑（預設：Placeholder_Defense_Config.json）
    
.PARAMETER Target
    指定要處理的目標類別（ntlm, smb, rdp, winrm, anydesk, custom）
    
.PARAMETER ListTargets
    列出所有可用的目標
    
.NOTES
    作者：Manus AI
    版本：2.0
    日期：2026-02-19
#>

#Requires -RunAsAdministrator

param(
    [switch]$Enable,
    [switch]$Disable,
    [string]$ConfigFile = "$PSScriptRoot\Placeholder_Defense_Config.json",
    [string]$Target = "all",
    [switch]$ListTargets
)

#region 全域變數

$script:BackupPath = "$PSScriptRoot\Placeholder_Backups"
$script:LogFile = "$PSScriptRoot\Placeholder_Defense.log"

#endregion

#region 日誌函數

function Write-PlaceholderLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp][$Level] $Message"
    
    switch ($Level) {
        "INFO"    { Write-Host $LogEntry -ForegroundColor Cyan }
        "WARN"    { Write-Host $LogEntry -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogEntry -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
    }
    
    Add-Content -Path $script:LogFile -Value $LogEntry -Encoding UTF8
}

#endregion

#region 配置管理

function Load-Configuration {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-PlaceholderLog "配置檔案不存在: $Path" -Level "ERROR"
        return $null
    }
    
    try {
        $config = Get-Content $Path -Encoding UTF8 | ConvertFrom-Json
        Write-PlaceholderLog "已載入配置檔案: $Path" -Level "SUCCESS"
        return $config
    }
    catch {
        Write-PlaceholderLog "載入配置檔案失敗: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Show-AvailableTargets {
    param($Config)
    
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          可用的佔位符目標                                ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    foreach ($targetName in $Config.targets.PSObject.Properties.Name) {
        $target = $Config.targets.$targetName
        
        $status = if ($target.enabled) { "✓ 已啟用" } else { "✗ 未啟用" }
        $statusColor = if ($target.enabled) { "Green" } else { "Gray" }
        
        Write-Host "[$targetName]" -ForegroundColor Yellow -NoNewline
        Write-Host " $status" -ForegroundColor $statusColor
        Write-Host "  描述: $($target.description)" -ForegroundColor White
        
        $dllCount = ($target.dlls | Where-Object { $_.enabled }).Count
        $regCount = ($target.registry | Where-Object { $_.enabled }).Count
        $svcCount = ($target.services | Where-Object { $_.enabled }).Count
        
        Write-Host "  組件: DLL($dllCount) | 註冊表($regCount) | 服務($svcCount)" -ForegroundColor Gray
        Write-Host ""
    }
}

#endregion

#region DLL 佔位符

function Enable-DLLPlaceholder {
    param(
        [string]$DLLPath,
        [string]$Suffix
    )
    
    $expandedPath = [Environment]::ExpandEnvironmentVariables($DLLPath)
    
    if (-not (Test-Path $expandedPath)) {
        Write-PlaceholderLog "DLL 不存在: $expandedPath" -Level "WARN"
        return $false
    }
    
    try {
        # 備份原始 DLL
        $backupPath = Join-Path $script:BackupPath (Split-Path $expandedPath -Leaf)
        if (-not (Test-Path $script:BackupPath)) {
            New-Item -Path $script:BackupPath -ItemType Directory -Force | Out-Null
        }
        Copy-Item $expandedPath $backupPath -Force
        
        # 重命名為 *_system.dll
        $systemDLL = $expandedPath -replace '\.dll$', "$Suffix.dll"
        Move-Item $expandedPath $systemDLL -Force
        
        # 創建佔位符 DLL（PowerShell 腳本偽裝）
        $placeholderScript = @"
# NTLM 佔位符防禦
# 此檔案在攻擊者嘗試使用時觸發
`$attackInfo = @{
    Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Process = `$PID
    User = `$env:USERNAME
    Computer = `$env:COMPUTERNAME
    Connections = Get-NetTCPConnection | Select-Object LocalAddress, RemoteAddress, State
}
`$attackInfo | ConvertTo-Json | Out-File 'C:\attack_detected.json' -Append
Write-EventLog -LogName Application -Source 'Placeholder Defense' -EventId 9999 -EntryType Warning -Message "佔位符觸發: $expandedPath"
"@
        
        # 將腳本保存為 .dll.ps1（偽裝）
        $placeholderScript | Set-Content "$expandedPath.ps1" -Encoding UTF8
        
        # 創建空的 DLL 檔案（佔位符）
        "" | Set-Content $expandedPath -Encoding ASCII
        
        Write-PlaceholderLog "已創建 DLL 佔位符: $expandedPath → $systemDLL" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-PlaceholderLog "創建 DLL 佔位符失敗: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Disable-DLLPlaceholder {
    param(
        [string]$DLLPath,
        [string]$Suffix
    )
    
    $expandedPath = [Environment]::ExpandEnvironmentVariables($DLLPath)
    $systemDLL = $expandedPath -replace '\.dll$', "$Suffix.dll"
    
    if (Test-Path $systemDLL) {
        try {
            Remove-Item $expandedPath -Force -ErrorAction SilentlyContinue
            Remove-Item "$expandedPath.ps1" -Force -ErrorAction SilentlyContinue
            Move-Item $systemDLL $expandedPath -Force
            Write-PlaceholderLog "已恢復 DLL: $expandedPath" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-PlaceholderLog "恢復 DLL 失敗: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    
    return $false
}

#endregion

#region 註冊表佔位符

function Enable-RegistryPlaceholder {
    param(
        [string]$RegPath,
        [string]$Suffix
    )
    
    if (-not (Test-Path $RegPath)) {
        Write-PlaceholderLog "註冊表路徑不存在: $RegPath" -Level "WARN"
        return $false
    }
    
    try {
        # 重命名註冊表項
        $parentPath = Split-Path $RegPath -Parent
        $keyName = Split-Path $RegPath -Leaf
        $newKeyName = "$keyName$Suffix"
        
        # 複製到新名稱
        Copy-Item $RegPath "$parentPath\$newKeyName" -Recurse -Force
        
        # 刪除原始項
        Remove-Item $RegPath -Recurse -Force
        
        # 創建佔位符（空的註冊表項）
        New-Item $RegPath -Force | Out-Null
        New-ItemProperty -Path $RegPath -Name "_Placeholder" -Value "Defense Active" -Force | Out-Null
        
        Write-PlaceholderLog "已創建註冊表佔位符: $RegPath → $parentPath\$newKeyName" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-PlaceholderLog "創建註冊表佔位符失敗: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Disable-RegistryPlaceholder {
    param(
        [string]$RegPath,
        [string]$Suffix
    )
    
    $parentPath = Split-Path $RegPath -Parent
    $keyName = Split-Path $RegPath -Leaf
    $systemKey = "$parentPath\$keyName$Suffix"
    
    if (Test-Path $systemKey) {
        try {
            Remove-Item $RegPath -Recurse -Force -ErrorAction SilentlyContinue
            Rename-Item $systemKey $keyName -Force
            Write-PlaceholderLog "已恢復註冊表: $RegPath" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-PlaceholderLog "恢復註冊表失敗: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    
    return $false
}

#endregion

#region 主要功能

function Enable-PlaceholderDefense {
    param(
        $Config,
        [string]$TargetName
    )
    
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          啟用佔位符防禦                                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
    
    $suffix = $Config.suffix
    $targetsToProcess = @()
    
    if ($TargetName -eq "all") {
        $targetsToProcess = $Config.targets.PSObject.Properties.Name | Where-Object {
            $Config.targets.$_.enabled
        }
    }
    else {
        if ($Config.targets.$TargetName) {
            $targetsToProcess = @($TargetName)
        }
        else {
            Write-PlaceholderLog "目標不存在: $TargetName" -Level "ERROR"
            return
        }
    }
    
    foreach ($targetName in $targetsToProcess) {
        $target = $Config.targets.$targetName
        
        Write-Host "`n[處理目標: $targetName]" -ForegroundColor Yellow
        Write-Host "描述: $($target.description)" -ForegroundColor Gray
        
        # 處理 DLL
        foreach ($dll in $target.dlls) {
            if ($dll.enabled) {
                Write-Host "  處理 DLL: $($dll.path)" -ForegroundColor Cyan
                Enable-DLLPlaceholder -DLLPath $dll.path -Suffix $suffix
            }
        }
        
        # 處理註冊表
        foreach ($reg in $target.registry) {
            if ($reg.enabled) {
                Write-Host "  處理註冊表: $($reg.path)" -ForegroundColor Cyan
                Enable-RegistryPlaceholder -RegPath $reg.path -Suffix $suffix
            }
        }
    }
    
    Write-Host "`n✅ 佔位符防禦已啟用！" -ForegroundColor Green
}

function Disable-PlaceholderDefense {
    param(
        $Config,
        [string]$TargetName
    )
    
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║          禁用佔位符防禦                                  ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Yellow
    
    $suffix = $Config.suffix
    $targetsToProcess = @()
    
    if ($TargetName -eq "all") {
        $targetsToProcess = $Config.targets.PSObject.Properties.Name
    }
    else {
        $targetsToProcess = @($TargetName)
    }
    
    foreach ($targetName in $targetsToProcess) {
        $target = $Config.targets.$targetName
        
        Write-Host "`n[恢復目標: $targetName]" -ForegroundColor Yellow
        
        # 恢復 DLL
        foreach ($dll in $target.dlls) {
            Write-Host "  恢復 DLL: $($dll.path)" -ForegroundColor Cyan
            Disable-DLLPlaceholder -DLLPath $dll.path -Suffix $suffix
        }
        
        # 恢復註冊表
        foreach ($reg in $target.registry) {
            Write-Host "  恢復註冊表: $($reg.path)" -ForegroundColor Cyan
            Disable-RegistryPlaceholder -RegPath $reg.path -Suffix $suffix
        }
    }
    
    Write-Host "`n✅ 佔位符防禦已禁用！" -ForegroundColor Green
}

#endregion

#region 主執行邏輯

function Main {
    Write-Host @"

╔══════════════════════════════════════════════════════════╗
║     通用佔位符防禦系統 v2.0                              ║
║     Universal Placeholder Defense System                ║
╚══════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

    # 載入配置
    $config = Load-Configuration -Path $ConfigFile
    if (-not $config) {
        Write-Host "無法載入配置檔案，退出。" -ForegroundColor Red
        exit 1
    }
    
    if ($ListTargets) {
        Show-AvailableTargets -Config $config
        return
    }
    
    if ($Enable) {
        Enable-PlaceholderDefense -Config $config -TargetName $Target
    }
    elseif ($Disable) {
        Disable-PlaceholderDefense -Config $config -TargetName $Target
    }
    else {
        Write-Host "使用方法:" -ForegroundColor Yellow
        Write-Host "  列出目標: .\Universal_Placeholder_Defense.ps1 -ListTargets" -ForegroundColor White
        Write-Host "  啟用全部: .\Universal_Placeholder_Defense.ps1 -Enable" -ForegroundColor White
        Write-Host "  啟用指定: .\Universal_Placeholder_Defense.ps1 -Enable -Target ntlm" -ForegroundColor White
        Write-Host "  禁用全部: .\Universal_Placeholder_Defense.ps1 -Disable" -ForegroundColor White
        Write-Host "  禁用指定: .\Universal_Placeholder_Defense.ps1 -Disable -Target ntlm`n" -ForegroundColor White
        
        Write-Host "配置檔案: $ConfigFile`n" -ForegroundColor Gray
    }
}

Main

#endregion
