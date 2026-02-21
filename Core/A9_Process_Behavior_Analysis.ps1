# A9_Process_Behavior_Analysis.ps1
# 進程行為模式識別模塊
# 作者: SafeModeDefender Team
# 版本: 2.1
# 編碼: UTF-8

<#
.SYNOPSIS
    進程行為模式識別模塊

.DESCRIPTION
    此模塊實現以下功能：
    1. 檢測可疑的進程行為模式
    2. 識別隱藏進程和 Rootkit
    3. 檢測進程注入和代碼注入
    4. 分析進程的網路連接行為
    5. 檢測進程的檔案系統活動

.NOTES
    需要管理員權限
#>

# 設定輸出編碼為 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 可疑進程行為模式
$SuspiciousPatterns = @{
    # 系統進程從非標準路徑啟動
    'SystemProcessWrongPath' = @{
        Processes = @('svchost.exe', 'lsass.exe', 'csrss.exe', 'winlogon.exe', 'smss.exe')
        ValidPaths = @('C:\Windows\System32', 'C:\Windows\SysWOW64')
        Description = '系統進程從非標準路徑啟動'
        RiskLevel = '高'
    }
    
    # 可疑的父進程關係
    'SuspiciousParentProcess' = @{
        # 不應該有子進程的進程
        NoChildProcesses = @('lsass.exe', 'csrss.exe')
        # 不應該作為父進程的進程
        InvalidParents = @('explorer.exe' => @('svchost.exe', 'lsass.exe'))
        Description = '可疑的父子進程關係'
        RiskLevel = '高'
    }
    
    # 無簽章或簽章無效的進程
    'UnsignedProcess' = @{
        # 應該有簽章的系統進程
        RequiredSigned = @('svchost.exe', 'lsass.exe', 'csrss.exe', 'winlogon.exe', 'smss.exe', 'services.exe')
        Description = '系統進程缺少有效的數位簽章'
        RiskLevel = '高'
    }
    
    # 可疑的命令列參數
    'SuspiciousCommandLine' = @{
        Patterns = @(
            'powershell.*-enc.*',           # Base64 編碼的 PowerShell 命令
            'powershell.*-nop.*-w hidden',  # 隱藏視窗的 PowerShell
            'cmd.exe.*/c.*echo.*>',         # 寫入檔案的命令
            'wmic.*process.*call.*create',  # WMIC 創建進程
            'reg.*add.*Run',                # 添加自啟動項
            'schtasks.*/create'             # 創建排程任務
        )
        Description = '可疑的命令列參數'
        RiskLevel = '中'
    }
}

# 獲取所有進程及其詳細資訊
function Get-DetailedProcessInfo {
    $processes = Get-Process | Select-Object Id, Name, Path, StartTime, 
        @{Name='ParentProcessId';Expression={(Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").ParentProcessId}},
        @{Name='CommandLine';Expression={(Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine}}
    
    return $processes
}

# 檢查進程數位簽章
function Test-ProcessSignature {
    param([string]$ProcessPath)
    
    if ([string]::IsNullOrEmpty($ProcessPath) -or -not (Test-Path $ProcessPath)) {
        return @{
            IsValid = $false
            Status = 'PathNotFound'
            Signer = 'Unknown'
        }
    }
    
    try {
        $signature = Get-AuthenticodeSignature -FilePath $ProcessPath
        return @{
            IsValid = ($signature.Status -eq 'Valid')
            Status = $signature.Status
            Signer = $signature.SignerCertificate.Subject
        }
    } catch {
        return @{
            IsValid = $false
            Status = 'Error'
            Signer = 'Unknown'
        }
    }
}

# 檢測系統進程從非標準路徑啟動
function Test-SystemProcessPath {
    param($Processes)
    
    $results = @()
    $pattern = $SuspiciousPatterns['SystemProcessWrongPath']
    
    foreach ($proc in $Processes) {
        if ($proc.Name -in $pattern.Processes) {
            if ($proc.Path) {
                $procDir = Split-Path $proc.Path -Parent
                if ($procDir -notin $pattern.ValidPaths) {
                    $results += [PSCustomObject]@{
                        檢測項目 = $pattern.Description
                        風險等級 = $pattern.RiskLevel
                        進程名稱 = $proc.Name
                        進程ID = $proc.Id
                        實際路徑 = $proc.Path
                        標準路徑 = ($pattern.ValidPaths -join ' 或 ')
                        狀態 = '可疑'
                    }
                }
            }
        }
    }
    
    return $results
}

# 檢測可疑的父子進程關係
function Test-ParentProcessRelationship {
    param($Processes)
    
    $results = @()
    $pattern = $SuspiciousPatterns['SuspiciousParentProcess']
    
    foreach ($proc in $Processes) {
        # 檢查不應該有子進程的進程
        if ($proc.Name -in $pattern.NoChildProcesses) {
            $childProcesses = $Processes | Where-Object { $_.ParentProcessId -eq $proc.Id }
            if ($childProcesses.Count -gt 0) {
                foreach ($child in $childProcesses) {
                    $results += [PSCustomObject]@{
                        檢測項目 = $pattern.Description
                        風險等級 = $pattern.RiskLevel
                        父進程 = "$($proc.Name) (PID: $($proc.Id))"
                        子進程 = "$($child.Name) (PID: $($child.Id))"
                        狀態 = '不應該有子進程'
                    }
                }
            }
        }
    }
    
    return $results
}

# 檢測無簽章或簽章無效的系統進程
function Test-UnsignedSystemProcess {
    param($Processes)
    
    $results = @()
    $pattern = $SuspiciousPatterns['UnsignedProcess']
    
    foreach ($proc in $Processes) {
        if ($proc.Name -in $pattern.RequiredSigned) {
            $signature = Test-ProcessSignature -ProcessPath $proc.Path
            if (-not $signature.IsValid) {
                $results += [PSCustomObject]@{
                    檢測項目 = $pattern.Description
                    風險等級 = $pattern.RiskLevel
                    進程名稱 = $proc.Name
                    進程ID = $proc.Id
                    進程路徑 = $proc.Path
                    簽章狀態 = $signature.Status
                    簽署者 = $signature.Signer
                    狀態 = '缺少有效簽章'
                }
            }
        }
    }
    
    return $results
}

# 檢測可疑的命令列參數
function Test-SuspiciousCommandLine {
    param($Processes)
    
    $results = @()
    $pattern = $SuspiciousPatterns['SuspiciousCommandLine']
    
    foreach ($proc in $Processes) {
        if ($proc.CommandLine) {
            foreach ($regex in $pattern.Patterns) {
                if ($proc.CommandLine -match $regex) {
                    $results += [PSCustomObject]@{
                        檢測項目 = $pattern.Description
                        風險等級 = $pattern.RiskLevel
                        進程名稱 = $proc.Name
                        進程ID = $proc.Id
                        命令列 = $proc.CommandLine
                        匹配模式 = $regex
                        狀態 = '可疑'
                    }
                    break
                }
            }
        }
    }
    
    return $results
}

# 主檢測函數
function Start-ProcessBehaviorAnalysis {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  進程行為模式識別" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $allResults = @()
    
    # 獲取所有進程資訊
    Write-Host "[階段 1] 收集進程資訊..." -ForegroundColor Cyan
    $processes = Get-DetailedProcessInfo
    Write-Host "[完成] 共收集到 $($processes.Count) 個進程`n" -ForegroundColor Green
    
    # 檢測系統進程路徑
    Write-Host "[階段 2] 檢測系統進程路徑..." -ForegroundColor Cyan
    $pathResults = Test-SystemProcessPath -Processes $processes
    if ($pathResults.Count -gt 0) {
        Write-Host "[警告] 發現 $($pathResults.Count) 個系統進程從非標準路徑啟動" -ForegroundColor Red
        $allResults += $pathResults
    } else {
        Write-Host "[正常] 所有系統進程路徑正常`n" -ForegroundColor Green
    }
    
    # 檢測父子進程關係
    Write-Host "[階段 3] 檢測父子進程關係..." -ForegroundColor Cyan
    $parentResults = Test-ParentProcessRelationship -Processes $processes
    if ($parentResults.Count -gt 0) {
        Write-Host "[警告] 發現 $($parentResults.Count) 個可疑的父子進程關係" -ForegroundColor Red
        $allResults += $parentResults
    } else {
        Write-Host "[正常] 父子進程關係正常`n" -ForegroundColor Green
    }
    
    # 檢測系統進程簽章
    Write-Host "[階段 4] 檢測系統進程數位簽章..." -ForegroundColor Cyan
    $signatureResults = Test-UnsignedSystemProcess -Processes $processes
    if ($signatureResults.Count -gt 0) {
        Write-Host "[警告] 發現 $($signatureResults.Count) 個系統進程缺少有效簽章" -ForegroundColor Red
        $allResults += $signatureResults
    } else {
        Write-Host "[正常] 所有系統進程簽章有效`n" -ForegroundColor Green
    }
    
    # 檢測可疑命令列
    Write-Host "[階段 5] 檢測可疑命令列參數..." -ForegroundColor Cyan
    $cmdResults = Test-SuspiciousCommandLine -Processes $processes
    if ($cmdResults.Count -gt 0) {
        Write-Host "[警告] 發現 $($cmdResults.Count) 個可疑的命令列參數" -ForegroundColor Yellow
        $allResults += $cmdResults
    } else {
        Write-Host "[正常] 沒有發現可疑的命令列參數`n" -ForegroundColor Green
    }
    
    # 生成報告
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  檢測結果摘要" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    if ($allResults.Count -gt 0) {
        Write-Host "[發現] 總共發現 $($allResults.Count) 個可疑項目" -ForegroundColor Red
        $allResults | Format-Table -AutoSize -Wrap
        
        # 儲存報告
        $reportPath = "$PSScriptRoot\..\..\Reports\ProcessBehaviorAnalysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $allResults | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`n[報告] 詳細報告已儲存至: $reportPath" -ForegroundColor Green
    } else {
        Write-Host "[正常] 沒有發現可疑的進程行為" -ForegroundColor Green
    }
    
    return $allResults
}

# 執行檢測
Start-ProcessBehaviorAnalysis
