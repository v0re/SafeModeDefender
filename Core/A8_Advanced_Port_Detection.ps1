# A8_Advanced_Port_Detection.ps1
# 增強版服務與端口檢測模塊 - 雙模式檢測（安全模式 + 正常模式）
# 作者: SafeModeDefender Team
# 版本: 2.1
# 編碼: UTF-8

<#
.SYNOPSIS
    增強版服務與端口檢測模塊，支持雙模式檢測

.DESCRIPTION
    此模塊實現以下功能：
    1. 檢測當前是否在安全模式下運行
    2. 安全模式：檢測任何監聽端口（應該全部為空）
    3. 正常模式：檢測服務端口是否被轉移或劫持
    4. 識別服務 → 檢查狀態 → 定位進程 → 分析端口 → 比對標準
    5. 檢測持久化到安全模式的惡意服務

.NOTES
    需要管理員權限
#>

# 設定輸出編碼為 UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 定義標準服務與端口映射表
$StandardServicePorts = @{
    'LanmanServer' = @{
        Name = 'Server (SMB)'
        Ports = @(445, 139)
        Protocol = 'TCP'
        Description = 'SMB 檔案共享服務'
    }
    'TermService' = @{
        Name = 'Remote Desktop Services (RDP)'
        Ports = @(3389)
        Protocol = 'TCP'
        Description = 'RDP 遠端桌面服務'
    }
    'SSDPSRV' = @{
        Name = 'SSDP Discovery (UPnP)'
        Ports = @(1900)
        Protocol = 'UDP'
        Description = 'UPnP/SSDP 設備發現服務'
    }
    'Dnscache' = @{
        Name = 'DNS Client (mDNS)'
        Ports = @(5353)
        Protocol = 'UDP'
        Description = 'mDNS/Bonjour 服務'
    }
    'WinRM' = @{
        Name = 'Windows Remote Management'
        Ports = @(5985, 5986)
        Protocol = 'TCP'
        Description = 'WinRM/PowerShell Remoting'
    }
    'RemoteRegistry' = @{
        Name = 'Remote Registry'
        Ports = @(135)
        Protocol = 'TCP'
        Description = '遠端註冊表服務'
    }
    'RpcSs' = @{
        Name = 'Remote Procedure Call (RPC)'
        Ports = @(135)
        Protocol = 'TCP'
        Description = 'RPC 服務'
    }
    'NetBT' = @{
        Name = 'NetBIOS over TCP/IP'
        Ports = @(137, 138, 139)
        Protocol = 'TCP/UDP'
        Description = 'NetBIOS 服務'
    }
}

# 檢測是否在安全模式下運行
function Test-SafeMode {
    try {
        $safeMode = (Get-CimInstance -ClassName Win32_ComputerSystem).BootupState
        return $safeMode -match "Safe"
    } catch {
        # 備用方法：檢查註冊表
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Option"
        if (Test-Path $regPath) {
            $optionValue = Get-ItemProperty -Path $regPath -Name "OptionValue" -ErrorAction SilentlyContinue
            return $optionValue.OptionValue -gt 0
        }
        return $false
    }
}

# 獲取所有監聽端口及其對應的進程
function Get-ListeningPorts {
    $connections = @()
    
    # TCP 連接
    try {
        $tcpConnections = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | 
            Select-Object LocalAddress, LocalPort, OwningProcess, State
        
        foreach ($conn in $tcpConnections) {
            $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            $connections += [PSCustomObject]@{
                Protocol = 'TCP'
                LocalAddress = $conn.LocalAddress
                LocalPort = $conn.LocalPort
                ProcessId = $conn.OwningProcess
                ProcessName = if ($process) { $process.Name } else { "Unknown" }
                ProcessPath = if ($process) { $process.Path } else { "Unknown" }
            }
        }
    } catch {
        Write-Warning "無法獲取 TCP 連接：$($_.Exception.Message)"
    }
    
    # UDP 連接
    try {
        $udpConnections = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | 
            Select-Object LocalAddress, LocalPort, OwningProcess
        
        foreach ($conn in $udpConnections) {
            $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
            $connections += [PSCustomObject]@{
                Protocol = 'UDP'
                LocalAddress = $conn.LocalAddress
                LocalPort = $conn.LocalPort
                ProcessId = $conn.OwningProcess
                ProcessName = if ($process) { $process.Name } else { "Unknown" }
                ProcessPath = if ($process) { $process.Path } else { "Unknown" }
            }
        }
    } catch {
        Write-Warning "無法獲取 UDP 連接：$($_.Exception.Message)"
    }
    
    return $connections
}

# 檢查進程數位簽章
function Test-ProcessSignature {
    param([string]$ProcessPath)
    
    if ($ProcessPath -eq "Unknown" -or -not (Test-Path $ProcessPath)) {
        return $false
    }
    
    try {
        $signature = Get-AuthenticodeSignature -FilePath $ProcessPath
        return $signature.Status -eq 'Valid'
    } catch {
        return $false
    }
}

# 檢查服務是否被設定為在安全模式下啟動
function Get-SafeModeServices {
    $safeModeServices = @()
    $safeModeKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal",
        "HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network"
    )
    
    foreach ($key in $safeModeKeys) {
        if (Test-Path $key) {
            $services = Get-ChildItem -Path $key -ErrorAction SilentlyContinue
            foreach ($service in $services) {
                $safeModeServices += [PSCustomObject]@{
                    ServiceName = $service.PSChildName
                    SafeModeType = if ($key -match "Minimal") { "最小安全模式" } else { "含網路功能的安全模式" }
                }
            }
        }
    }
    
    return $safeModeServices
}

# 主檢測函數
function Start-AdvancedPortDetection {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  增強版服務與端口檢測" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    $isSafeMode = Test-SafeMode
    $results = @()
    
    if ($isSafeMode) {
        Write-Host "[模式] 檢測到當前在安全模式下運行" -ForegroundColor Yellow
        Write-Host "[提示] 在安全模式下，任何監聽端口都是高度可疑的！`n" -ForegroundColor Yellow
    } else {
        Write-Host "[模式] 當前在正常模式下運行" -ForegroundColor Green
        Write-Host "[提示] 將檢測服務端口是否被轉移或劫持`n" -ForegroundColor Green
    }
    
    # 1. 檢測所有監聽端口
    Write-Host "[階段 1] 掃描所有監聽端口..." -ForegroundColor Cyan
    $listeningPorts = Get-ListeningPorts
    
    if ($isSafeMode) {
        # 安全模式：任何監聽端口都是可疑的
        if ($listeningPorts.Count -gt 0) {
            Write-Host "[警告] 在安全模式下發現 $($listeningPorts.Count) 個監聽端口！" -ForegroundColor Red
            foreach ($port in $listeningPorts) {
                $isSigned = Test-ProcessSignature -ProcessPath $port.ProcessPath
                $results += [PSCustomObject]@{
                    檢測項目 = "安全模式監聽端口"
                    風險等級 = "高"
                    協議 = $port.Protocol
                    端口 = $port.LocalPort
                    進程名稱 = $port.ProcessName
                    進程路徑 = $port.ProcessPath
                    數位簽章 = if ($isSigned) { "有效" } else { "無效或缺失" }
                    狀態 = "可疑"
                }
            }
        } else {
            Write-Host "[正常] 安全模式下沒有監聽端口" -ForegroundColor Green
        }
    } else {
        # 正常模式：檢測服務端口映射
        Write-Host "[階段 2] 檢測標準服務的端口映射..." -ForegroundColor Cyan
        
        foreach ($serviceName in $StandardServicePorts.Keys) {
            $serviceInfo = $StandardServicePorts[$serviceName]
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($service) {
                Write-Host "`n[服務] $($serviceInfo.Name) ($serviceName)" -ForegroundColor White
                Write-Host "  狀態: $($service.Status)" -ForegroundColor $(if ($service.Status -eq 'Running') { 'Yellow' } else { 'Gray' })
                
                if ($service.Status -eq 'Running') {
                    # 獲取服務對應的進程
                    $serviceProcess = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'" | 
                        Select-Object -ExpandProperty ProcessId
                    
                    if ($serviceProcess) {
                        # 查找該進程綁定的端口
                        $servicePorts = $listeningPorts | Where-Object { $_.ProcessId -eq $serviceProcess }
                        
                        if ($servicePorts) {
                            $actualPorts = $servicePorts | Select-Object -ExpandProperty LocalPort -Unique
                            $standardPorts = $serviceInfo.Ports
                            
                            # 檢查是否使用標準端口
                            $isStandard = $true
                            foreach ($port in $actualPorts) {
                                if ($port -notin $standardPorts) {
                                    $isStandard = $false
                                    Write-Host "  [異常] 發現非標準端口: $port" -ForegroundColor Red
                                    
                                    $results += [PSCustomObject]@{
                                        檢測項目 = "服務端口轉移"
                                        風險等級 = "高"
                                        服務名稱 = $serviceInfo.Name
                                        標準端口 = ($standardPorts -join ', ')
                                        實際端口 = $port
                                        進程ID = $serviceProcess
                                        狀態 = "端口被轉移"
                                    }
                                }
                            }
                            
                            # 檢查標準端口是否缺失
                            foreach ($stdPort in $standardPorts) {
                                if ($stdPort -notin $actualPorts) {
                                    Write-Host "  [異常] 標準端口 $stdPort 未被綁定" -ForegroundColor Red
                                    
                                    $results += [PSCustomObject]@{
                                        檢測項目 = "服務端口缺失"
                                        風險等級 = "中"
                                        服務名稱 = $serviceInfo.Name
                                        標準端口 = $stdPort
                                        實際端口 = "無"
                                        進程ID = $serviceProcess
                                        狀態 = "端口未綁定"
                                    }
                                }
                            }
                            
                            if ($isStandard) {
                                Write-Host "  [正常] 使用標準端口: $($actualPorts -join ', ')" -ForegroundColor Green
                            }
                        } else {
                            Write-Host "  [異常] 服務運行但未綁定任何端口" -ForegroundColor Red
                            
                            $results += [PSCustomObject]@{
                                檢測項目 = "服務無端口"
                                風險等級 = "高"
                                服務名稱 = $serviceInfo.Name
                                標準端口 = ($standardPorts -join ', ')
                                實際端口 = "無"
                                進程ID = $serviceProcess
                                狀態 = "服務運行但無端口綁定"
                            }
                        }
                    }
                }
            }
        }
        
        # 檢測非服務進程綁定到標準端口
        Write-Host "`n[階段 3] 檢測非服務進程綁定到標準端口..." -ForegroundColor Cyan
        $allStandardPorts = $StandardServicePorts.Values | ForEach-Object { $_.Ports } | Select-Object -Unique
        
        foreach ($port in $listeningPorts) {
            if ($port.LocalPort -in $allStandardPorts) {
                # 檢查是否為已知服務
                $isKnownService = $false
                foreach ($serviceName in $StandardServicePorts.Keys) {
                    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
                    if ($service -and $service.ProcessId -eq $port.ProcessId) {
                        $isKnownService = $true
                        break
                    }
                }
                
                if (-not $isKnownService) {
                    $isSigned = Test-ProcessSignature -ProcessPath $port.ProcessPath
                    Write-Host "[警告] 非服務進程綁定到標準端口 $($port.LocalPort): $($port.ProcessName)" -ForegroundColor Red
                    
                    $results += [PSCustomObject]@{
                        檢測項目 = "非服務進程綁定標準端口"
                        風險等級 = "高"
                        端口 = $port.LocalPort
                        進程名稱 = $port.ProcessName
                        進程路徑 = $port.ProcessPath
                        數位簽章 = if ($isSigned) { "有效" } else { "無效或缺失" }
                        狀態 = "可疑"
                    }
                }
            }
        }
    }
    
    # 3. 檢測持久化到安全模式的服務
    Write-Host "`n[階段 4] 檢測持久化到安全模式的服務..." -ForegroundColor Cyan
    $safeModeServices = Get-SafeModeServices
    
    if ($safeModeServices.Count -gt 0) {
        Write-Host "[發現] $($safeModeServices.Count) 個服務被設定為在安全模式下啟動" -ForegroundColor Yellow
        foreach ($svc in $safeModeServices) {
            Write-Host "  - $($svc.ServiceName) ($($svc.SafeModeType))" -ForegroundColor Yellow
            
            # 檢查是否為標準系統服務
            $isStandard = $svc.ServiceName -in @('Base', 'Boot Bus Extender', 'Boot file system', 'System Bus Extender', 'SCSI Class', 'Primary disk')
            
            if (-not $isStandard) {
                $results += [PSCustomObject]@{
                    檢測項目 = "安全模式持久化"
                    風險等級 = "高"
                    服務名稱 = $svc.ServiceName
                    安全模式類型 = $svc.SafeModeType
                    狀態 = "可疑"
                }
            }
        }
    } else {
        Write-Host "[正常] 沒有發現異常的安全模式持久化服務" -ForegroundColor Green
    }
    
    # 生成報告
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  檢測結果摘要" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    if ($results.Count -gt 0) {
        Write-Host "[發現] 總共發現 $($results.Count) 個可疑項目" -ForegroundColor Red
        $results | Format-Table -AutoSize
        
        # 儲存報告
        $reportPath = "$PSScriptRoot\..\..\Reports\AdvancedPortDetection_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
        $results | Export-Csv -Path $reportPath -NoTypeInformation -Encoding UTF8
        Write-Host "`n[報告] 詳細報告已儲存至: $reportPath" -ForegroundColor Green
    } else {
        Write-Host "[正常] 沒有發現可疑的端口或服務異常" -ForegroundColor Green
    }
    
    return $results
}

# 執行檢測
Start-AdvancedPortDetection
