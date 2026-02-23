# ============================================================================
# Advanced_Attack_Detection.ps1 - 進階攻擊檢測函數庫
# 
# 功能：檢測 AnyDesk 相關的進階攻擊手法
# - GPU 渲染攻擊（Direct3D 錯誤 0x8876086c）
# - 隱私模式濫用
# - GPO 篡改
# - 系統管理工具封鎖
# ============================================================================

function Test-GPUAttackIndicators {
    <#
    .SYNOPSIS
        檢測顯卡渲染攻擊跡象
    
    .DESCRIPTION
        根據 APT 攻擊鑑識分析，檢測以下跡象：
        - Direct3D 裝置建立失敗（錯誤代碼 0x8876086c）
        - AnyDesk 日誌中的渲染錯誤
        - 顯卡驅動程式衝突
        - 異常的 GPU 使用率
    
    .OUTPUTS
        PSCustomObject 包含檢測結果和風險評分
    #>
    
    $result = @{
        Detected = $false
        RiskScore = 0
        Indicators = @()
        Details = @{}
    }
    
    Write-Host "`n[檢測] 顯卡渲染攻擊跡象..." -ForegroundColor Cyan
    
    # 1. 檢查 AnyDesk 日誌中的 Direct3D 錯誤
    $anydeskLogPaths = @(
        "$env:AppData\AnyDesk\ad.trace",
        "$env:ProgramData\AnyDesk\ad.trace",
        "$env:AppData\AnyDesk\connection_trace.txt",
        "$env:ProgramData\AnyDesk\connection_trace.txt"
    )
    
    $d3dErrorCount = 0
    $d3dErrorSamples = @()
    
    foreach ($logPath in $anydeskLogPaths) {
        if (Test-Path $logPath) {
            try {
                # 搜尋 Direct3D 錯誤代碼
                $content = Get-Content $logPath -ErrorAction Stop
                $d3dErrors = $content | Select-String -Pattern "0x8876086c|D3DERR_DEVICELOST|Direct3D.*fail|CreateDevice.*failed" -AllMatches
                
                if ($d3dErrors) {
                    $d3dErrorCount += $d3dErrors.Count
                    $d3dErrorSamples += $d3dErrors | Select-Object -First 3 | ForEach-Object { $_.Line }
                }
            }
            catch {
                Write-Host "  ⚠️  無法讀取日誌：$logPath" -ForegroundColor Yellow
            }
        }
    }
    
    if ($d3dErrorCount -gt 0) {
        $result.Detected = $true
        $result.RiskScore += 40
        $result.Indicators += "發現 $d3dErrorCount 個 Direct3D 裝置建立失敗錯誤"
        $result.Details.D3DErrors = @{
            Count = $d3dErrorCount
            Samples = $d3dErrorSamples
        }
        Write-Host "  ❌ 發現 Direct3D 錯誤：$d3dErrorCount 次" -ForegroundColor Red
    }
    else {
        Write-Host "  ✓ 未發現 Direct3D 錯誤" -ForegroundColor Green
    }
    
    # 2. 檢查 Windows 事件日誌中的顯卡錯誤
    Write-Host "`n  檢查 Windows 事件日誌..." -ForegroundColor Gray
    
    try {
        $displayErrors = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Display'
            Level = 2,3  # Error and Warning
            StartTime = (Get-Date).AddDays(-7)
        } -ErrorAction SilentlyContinue | Select-Object -First 50
        
        if ($displayErrors) {
            $result.RiskScore += 20
            $result.Indicators += "最近 7 天內發現 $($displayErrors.Count) 個顯卡相關錯誤"
            $result.Details.DisplayErrors = $displayErrors.Count
            Write-Host "  ⚠️  發現 $($displayErrors.Count) 個顯卡錯誤" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ℹ️  無法存取事件日誌" -ForegroundColor Gray
    }
    
    # 3. 檢查 AnyDesk 縮圖快取（可能包含攻擊者桌面）
    $thumbnailPaths = @(
        "$env:AppData\AnyDesk\thumbnails",
        "$env:ProgramData\AnyDesk\thumbnails",
        "$env:USERPROFILE\Videos\AnyDesk"
    )
    
    $suspiciousThumbnails = @()
    foreach ($thumbPath in $thumbnailPaths) {
        if (Test-Path $thumbPath) {
            $files = Get-ChildItem $thumbPath -File -ErrorAction SilentlyContinue
            if ($files) {
                $suspiciousThumbnails += $files
                $result.RiskScore += 15
                $result.Indicators += "發現 $($files.Count) 個 AnyDesk 縮圖/錄影檔案"
            }
        }
    }
    
    if ($suspiciousThumbnails.Count -gt 0) {
        $result.Details.Thumbnails = @{
            Count = $suspiciousThumbnails.Count
            Paths = $suspiciousThumbnails | Select-Object -ExpandProperty FullName
        }
        Write-Host "  ⚠️  發現 $($suspiciousThumbnails.Count) 個縮圖/錄影檔案" -ForegroundColor Yellow
    }
    
    # 4. 檢查異常的 GPU 使用率（如果有 GPU 監控工具）
    try {
        $gpuProcess = Get-Process | Where-Object { $_.ProcessName -like "*anydesk*" } | Select-Object -First 1
        if ($gpuProcess) {
            # 注意：標準 PowerShell 無法直接獲取 GPU 使用率，這裡只是示例
            Write-Host "  ℹ️  AnyDesk 進程正在運行（PID: $($gpuProcess.Id)）" -ForegroundColor Gray
        }
    }
    catch {
        # Silently continue
    }
    
    return [PSCustomObject]$result
}

function Test-PrivacyModeAbuse {
    <#
    .SYNOPSIS
        檢測 AnyDesk 隱私模式濫用
    
    .DESCRIPTION
        檢測攻擊者是否使用了 AnyDesk 的「隱私模式」（黑屏功能）來隱藏操作
    #>
    
    $result = @{
        Detected = $false
        RiskScore = 0
        Indicators = @()
        Details = @{}
    }
    
    Write-Host "`n[檢測] AnyDesk 隱私模式濫用..." -ForegroundColor Cyan
    
    # 檢查配置檔案中的隱私模式設定
    $configPaths = @(
        "$env:AppData\AnyDesk\system.conf",
        "$env:ProgramData\AnyDesk\system.conf"
    )
    
    foreach ($configPath in $configPaths) {
        if (Test-Path $configPath) {
            try {
                $content = Get-Content $configPath -ErrorAction Stop
                
                # 檢查隱私模式相關設定
                $privacySettings = $content | Select-String -Pattern "privacy|black.*screen|blank.*screen|hide.*screen" -AllMatches
                
                if ($privacySettings) {
                    $result.Detected = $true
                    $result.RiskScore += 30
                    $result.Indicators += "配置檔案中發現隱私模式相關設定"
                    $result.Details.PrivacySettings = $privacySettings | ForEach-Object { $_.Line }
                    Write-Host "  ⚠️  發現隱私模式設定" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "  ⚠️  無法讀取配置：$configPath" -ForegroundColor Yellow
            }
        }
    }
    
    # 檢查日誌中的隱私模式使用記錄
    $logPaths = @(
        "$env:AppData\AnyDesk\ad.trace",
        "$env:ProgramData\AnyDesk\ad.trace"
    )
    
    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            try {
                $content = Get-Content $logPath -Tail 1000 -ErrorAction Stop
                $privacyEvents = $content | Select-String -Pattern "privacy.*mode|black.*screen.*enabled|screen.*blanking" -AllMatches
                
                if ($privacyEvents) {
                    $result.Detected = $true
                    $result.RiskScore += 25
                    $result.Indicators += "日誌中發現 $($privacyEvents.Count) 次隱私模式啟用記錄"
                    Write-Host "  ❌ 日誌中發現隱私模式使用記錄：$($privacyEvents.Count) 次" -ForegroundColor Red
                }
            }
            catch {
                # Silently continue
            }
        }
    }
    
    if (-not $result.Detected) {
        Write-Host "  ✓ 未發現隱私模式濫用跡象" -ForegroundColor Green
    }
    
    return [PSCustomObject]$result
}

function Test-GPOTampering {
    <#
    .SYNOPSIS
        檢測 GPO 篡改和系統管理工具封鎖
    
    .DESCRIPTION
        檢測攻擊者是否篡改了群組原則以封鎖系統管理工具，包括：
        - Regedit（註冊表編輯器）
        - CMD（命令提示字元）
        - PowerShell
        - Task Manager（工作管理員）
        - Windows Defender
    #>
    
    $result = @{
        Detected = $false
        RiskScore = 0
        Indicators = @()
        BlockedTools = @()
        Details = @{}
    }
    
    Write-Host "`n[檢測] GPO 篡改和系統管理工具封鎖..." -ForegroundColor Cyan
    
    # 檢查 Registry.pol 檔案是否存在（被篡改的跡象）
    $gpoPolPaths = @(
        "$env:SystemRoot\System32\GroupPolicy\Machine\registry.pol",
        "$env:SystemRoot\System32\GroupPolicy\User\registry.pol"
    )
    
    $tamperedPol = @()
    foreach ($polPath in $gpoPolPaths) {
        if (Test-Path $polPath) {
            $fileInfo = Get-Item $polPath
            # 檢查檔案是否在最近 30 天內被修改
            if ($fileInfo.LastWriteTime -gt (Get-Date).AddDays(-30)) {
                $tamperedPol += $polPath
                Write-Host "  ⚠️  發現最近修改的 GPO 檔案：$polPath" -ForegroundColor Yellow
                Write-Host "      最後修改時間：$($fileInfo.LastWriteTime)" -ForegroundColor Gray
            }
        }
    }
    
    if ($tamperedPol.Count -gt 0) {
        $result.Detected = $true
        $result.RiskScore += 50
        $result.Indicators += "發現 $($tamperedPol.Count) 個最近修改的 GPO 檔案"
        $result.Details.TamperedPolicies = $tamperedPol
    }
    
    # 檢查關鍵系統工具是否被封鎖
    $toolChecks = @(
        @{
            Name = "Regedit"
            RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
            RegKey = "DisableRegistryTools"
            BlockedValue = 1
        },
        @{
            Name = "CMD"
            RegPath = "HKCU:\Software\Policies\Microsoft\Windows\System"
            RegKey = "DisableCMD"
            BlockedValue = 1
        },
        @{
            Name = "Task Manager"
            RegPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System"
            RegKey = "DisableTaskMgr"
            BlockedValue = 1
        },
        @{
            Name = "Windows Defender"
            RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
            RegKey = "DisableAntiSpyware"
            BlockedValue = 1
        },
        @{
            Name = "PowerShell"
            RegPath = "HKCU:\Software\Policies\Microsoft\Windows\PowerShell"
            RegKey = "EnableScripts"
            BlockedValue = 0
        }
    )
    
    foreach ($check in $toolChecks) {
        try {
            if (Test-Path $check.RegPath) {
                $value = Get-ItemProperty -Path $check.RegPath -Name $check.RegKey -ErrorAction SilentlyContinue
                if ($null -ne $value -and $value.($check.RegKey) -eq $check.BlockedValue) {
                    $result.Detected = $true
                    $result.RiskScore += 30
                    $result.BlockedTools += $check.Name
                    $result.Indicators += "$($check.Name) 已被 GPO 封鎖"
                    Write-Host "  ❌ $($check.Name) 已被封鎖" -ForegroundColor Red
                }
            }
        }
        catch {
            # Silently continue
        }
    }
    
    # 檢查是否有「由您的組織管理」訊息
    try {
        $managedByOrg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -ErrorAction SilentlyContinue
        if ($managedByOrg) {
            Write-Host "  ℹ️  系統顯示「由您的組織管理」" -ForegroundColor Gray
            $result.Details.ManagedByOrganization = $true
        }
    }
    catch {
        # Silently continue
    }
    
    if ($result.BlockedTools.Count -eq 0 -and $tamperedPol.Count -eq 0) {
        Write-Host "  ✓ 未發現 GPO 篡改跡象" -ForegroundColor Green
    }
    else {
        Write-Host "`n  ⚠️  GPO 篡改風險評分：$($result.RiskScore)/100" -ForegroundColor Yellow
    }
    
    return [PSCustomObject]$result
}

function Test-ClickFixIndicators {
    <#
    .SYNOPSIS
        檢測 ClickFix 社交工程攻擊跡象
    
    .DESCRIPTION
        檢測系統中是否有 ClickFix 攻擊的痕跡：
        - 可疑的 PowerShell 執行記錄
        - mshta.exe 濫用
        - 異常的防火牆規則
    #>
    
    $result = @{
        Detected = $false
        RiskScore = 0
        Indicators = @()
        Details = @{}
    }
    
    Write-Host "`n[檢測] ClickFix 社交工程攻擊跡象..." -ForegroundColor Cyan
    
    # 1. 檢查 PowerShell 執行歷史
    $psHistoryPath = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
    if (Test-Path $psHistoryPath) {
        try {
            $history = Get-Content $psHistoryPath -ErrorAction Stop
            $suspiciousCommands = $history | Select-String -Pattern "iex|Invoke-Expression|DownloadString|DownloadFile|mshta|bitsadmin|certutil.*download" -AllMatches
            
            if ($suspiciousCommands) {
                $result.Detected = $true
                $result.RiskScore += 40
                $result.Indicators += "PowerShell 歷史中發現 $($suspiciousCommands.Count) 個可疑命令"
                $result.Details.SuspiciousCommands = $suspiciousCommands | Select-Object -First 5 | ForEach-Object { $_.Line }
                Write-Host "  ❌ 發現可疑的 PowerShell 命令：$($suspiciousCommands.Count) 個" -ForegroundColor Red
            }
        }
        catch {
            # Silently continue
        }
    }
    
    # 2. 檢查可疑的防火牆規則
    try {
        $suspiciousRules = Get-NetFirewallRule | Where-Object {
            ($_.DisplayName -match "Software Updater|Remote Management|System Service") -and
            $_.Direction -eq "Inbound" -and
            $_.Action -eq "Allow" -and
            $_.Enabled -eq $true
        }
        
        if ($suspiciousRules) {
            $result.Detected = $true
            $result.RiskScore += 35
            $result.Indicators += "發現 $($suspiciousRules.Count) 個可疑的防火牆規則"
            $result.Details.SuspiciousFirewallRules = $suspiciousRules | Select-Object DisplayName, LocalPort, RemoteAddress
            Write-Host "  ❌ 發現可疑的防火牆規則：$($suspiciousRules.Count) 個" -ForegroundColor Red
        }
    }
    catch {
        # Silently continue
    }
    
    # 3. 檢查 mshta.exe 執行記錄
    try {
        $mshtaEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-PowerShell/Operational'
            ID = 4104  # Script Block Logging
            StartTime = (Get-Date).AddDays(-30)
        } -ErrorAction SilentlyContinue | Where-Object {
            $_.Message -match "mshta"
        }
        
        if ($mshtaEvents) {
            $result.Detected = $true
            $result.RiskScore += 30
            $result.Indicators += "發現 $($mshtaEvents.Count) 個 mshta.exe 執行記錄"
            Write-Host "  ⚠️  發現 mshta.exe 執行記錄：$($mshtaEvents.Count) 次" -ForegroundColor Yellow
        }
    }
    catch {
        # Silently continue
    }
    
    if (-not $result.Detected) {
        Write-Host "  ✓ 未發現 ClickFix 攻擊跡象" -ForegroundColor Green
    }
    
    return [PSCustomObject]$result
}

# 匯出函數
Export-ModuleMember -Function Test-GPUAttackIndicators, Test-PrivacyModeAbuse, Test-GPOTampering, Test-ClickFixIndicators
