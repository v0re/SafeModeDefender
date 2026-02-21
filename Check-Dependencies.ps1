<#
.SYNOPSIS
    SafeModeDefender 依賴檢查和環境修復工具

.DESCRIPTION
    此腳本檢查並修復 SafeModeDefender 運行所需的所有依賴和環境配置。
    適用於離線和在線環境。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-19
    編碼：UTF-8 with BOM
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          SafeModeDefender 依賴檢查和環境修復工具 v1.0                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$AllPassed = $true

# 1. 檢查管理員權限
Write-Host "[1/7] 檢查管理員權限..." -ForegroundColor Cyan
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($IsAdmin) {
    Write-Host "  ✓ 已確認管理員權限" -ForegroundColor Green
} else {
    Write-Host "  ✗ 需要管理員權限" -ForegroundColor Red
    Write-Host "    請右鍵點擊腳本，選擇「以管理員身份執行」" -ForegroundColor Yellow
    $AllPassed = $false
}

# 2. 檢查 PowerShell 版本
Write-Host "`n[2/7] 檢查 PowerShell 版本..." -ForegroundColor Cyan
$PSVersion = $PSVersionTable.PSVersion
Write-Host "  當前版本：PowerShell $($PSVersion.Major).$($PSVersion.Minor)" -ForegroundColor Gray
if ($PSVersion.Major -ge 5) {
    Write-Host "  ✓ PowerShell 版本符合要求 (>= 5.0)" -ForegroundColor Green
} else {
    Write-Host "  ✗ PowerShell 版本過舊 (需要 >= 5.0)" -ForegroundColor Red
    Write-Host "    請升級到 PowerShell 5.1 或更高版本" -ForegroundColor Yellow
    Write-Host "    下載：https://aka.ms/wmf5download" -ForegroundColor Yellow
    $AllPassed = $false
}

# 3. 檢查執行策略
Write-Host "`n[3/7] 檢查 PowerShell 執行策略..." -ForegroundColor Cyan
$ExecutionPolicy = Get-ExecutionPolicy
Write-Host "  當前策略：$ExecutionPolicy" -ForegroundColor Gray
if ($ExecutionPolicy -eq "Restricted") {
    Write-Host "  ⚠ 執行策略過於嚴格，可能導致腳本無法執行" -ForegroundColor Yellow
    if ($IsAdmin) {
        Write-Host "    正在嘗試修復..." -ForegroundColor Cyan
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
            Write-Host "  ✓ 已將執行策略設置為 RemoteSigned" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ 無法修改執行策略：$($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    請手動執行：Set-ExecutionPolicy RemoteSigned" -ForegroundColor Yellow
            $AllPassed = $false
        }
    } else {
        Write-Host "  ✗ 需要管理員權限才能修改執行策略" -ForegroundColor Red
        $AllPassed = $false
    }
} else {
    Write-Host "  ✓ 執行策略允許腳本運行" -ForegroundColor Green
}

# 4. 檢查 Windows 版本
Write-Host "`n[4/7] 檢查 Windows 版本..." -ForegroundColor Cyan
$OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$OSVersion = $OSInfo.Version
$OSCaption = $OSInfo.Caption
Write-Host "  系統：$OSCaption" -ForegroundColor Gray
Write-Host "  版本：$OSVersion" -ForegroundColor Gray
if ($OSVersion -ge "10.0") {
    Write-Host "  ✓ Windows 版本符合要求 (>= Windows 10)" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Windows 版本較舊，部分功能可能不可用" -ForegroundColor Yellow
}

# 5. 檢查必要的 PowerShell 模塊
Write-Host "`n[5/7] 檢查必要的 PowerShell 模塊..." -ForegroundColor Cyan

$RequiredModules = @(
    @{Name="Microsoft.PowerShell.Management"; Required=$true},
    @{Name="Microsoft.PowerShell.Security"; Required=$true},
    @{Name="Microsoft.PowerShell.Utility"; Required=$true}
)

foreach ($Module in $RequiredModules) {
    $ModuleName = $Module.Name
    $IsAvailable = Get-Module -ListAvailable -Name $ModuleName
    if ($IsAvailable) {
        Write-Host "  ✓ $ModuleName" -ForegroundColor Green
    } else {
        if ($Module.Required) {
            Write-Host "  ✗ $ModuleName (必需)" -ForegroundColor Red
            $AllPassed = $false
        } else {
            Write-Host "  ⚠ $ModuleName (可選)" -ForegroundColor Yellow
        }
    }
}

# 6. 檢查網路連線狀態
Write-Host "`n[6/7] 檢查網路連線狀態..." -ForegroundColor Cyan
try {
    $TestConnection = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
    if ($TestConnection) {
        Write-Host "  ✓ 網路連線正常（在線模式）" -ForegroundColor Green
        Write-Host "    可以下載和更新外部工具" -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ 無法連接到網際網路（離線模式）" -ForegroundColor Yellow
        Write-Host "    將使用預先打包的離線資源" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ⚠ 無法檢測網路狀態（可能處於離線模式）" -ForegroundColor Yellow
    Write-Host "    將使用預先打包的離線資源" -ForegroundColor Gray
}

# 7. 檢查檔案編碼
Write-Host "`n[7/7] 檢查核心模塊檔案..." -ForegroundColor Cyan
$CoreDir = Join-Path $PSScriptRoot "Core"
if (Test-Path $CoreDir) {
    $ModuleCount = (Get-ChildItem -Path $CoreDir -Filter "*.ps1" -File | Where-Object { $_.Name -match "^[A-I]\d+_" }).Count
    Write-Host "  ✓ 找到 $ModuleCount 個核心模塊" -ForegroundColor Green
} else {
    Write-Host "  ✗ 找不到 Core 目錄" -ForegroundColor Red
    Write-Host "    請確保在 SafeModeDefender 根目錄下執行此腳本" -ForegroundColor Yellow
    $AllPassed = $false
}

# 總結
Write-Host "`n╔══════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                          檢查結果總結                                    ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($AllPassed) {
    Write-Host "  ✓ 所有依賴檢查通過！" -ForegroundColor Green
    Write-Host "  SafeModeDefender 已準備就緒，可以開始使用。`n" -ForegroundColor Green
    Write-Host "  執行方式：" -ForegroundColor Cyan
    Write-Host "    1. 交互式選單：.\SafeModeDefender.bat" -ForegroundColor Gray
    Write-Host "    2. 命令列模式：.\SafeModeDefender.bat --cli --action scan --category A" -ForegroundColor Gray
    Write-Host "    3. 外部工具：.\SafeModeDefender.bat --cli --tool winutil`n" -ForegroundColor Gray
    exit 0
} else {
    Write-Host "  ✗ 部分檢查未通過，請根據上述提示修復問題。`n" -ForegroundColor Red
    Write-Host "  常見解決方案：" -ForegroundColor Cyan
    Write-Host "    1. 以管理員身份執行：右鍵 → 以管理員身份執行" -ForegroundColor Gray
    Write-Host "    2. 修改執行策略：Set-ExecutionPolicy RemoteSigned" -ForegroundColor Gray
    Write-Host "    3. 升級 PowerShell：https://aka.ms/wmf5download`n" -ForegroundColor Gray
    exit 1
}
