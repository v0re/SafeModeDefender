<# : batch wrapper
@echo off
chcp 65001 >nul
powershell -ExecutionPolicy Bypass -File "%~f0" %*
exit /b %errorlevel%
: end batch #>

<#
.SYNOPSIS
    D4_Digital_Signature - 可疑執行檔與數位簽章驗證模塊

.DESCRIPTION
    此 PowerShell 腳本用於驗證指定路徑下可執行文件的數位簽章。它會檢查簽章的有效性、發行者信息，並生成詳細的 JSON 格式報告。
    支援 -WhatIf 和 -Confirm 參數，並提供多級別日誌記錄和進度顯示。

.PARAMETER Path
    指定要掃描的目錄路徑。腳本將遞歸掃描此路徑下的所有可執行文件。

.PARAMETER LogPath
    指定日誌文件的儲存路徑。如果未指定，將在腳本所在目錄創建一個 Log 文件夾。

.PARAMETER ReportPath
    指定檢測報告的儲存路徑。如果未指定，將在腳本所在目錄創建一個 Report 文件夾。

.EXAMPLE
    .\D4_Digital_Signature.ps1 -Path 'C:\Program Files' -WhatIf
    此命令將預覽在 'C:\Program Files' 目錄下將執行的操作，但不會實際執行。

.EXAMPLE
    .\D4_Digital_Signature.ps1 -Path 'C:\Windows\System32' -Confirm
    此命令將在掃描 'C:\Windows\System32' 目錄下的每個文件前提示用戶確認。

.EXAMPLE
    .\D4_Digital_Signature.ps1 -Path 'C:\Users\Public\Downloads' -LogPath 'C:\Logs' -ReportPath 'C:\Reports'
    此命令將掃描指定下載目錄，並將日誌和報告儲存到指定路徑。

.NOTES
    作者：Manus AI
    版本：1.0
    日期：2026-02-18
#>

[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param
(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [string]$LogPath = (Join-Path $PSScriptRoot 'Log'),

    [string]$ReportPath = (Join-Path $PSScriptRoot 'Report')
)

# 設置 UTF-8 with BOM 編碼
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# 函數：寫入日誌
function Write-Log
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $LogEntry = "$Timestamp [$Level] $Message"

    try
    {
        # 確保日誌目錄存在
        if (-not (Test-Path -Path $LogPath -PathType Container))
        {
            New-Item -Path $LogPath -ItemType Directory -ErrorAction Stop | Out-Null
        }
        $LogFile = Join-Path $LogPath "D4_Digital_Signature_$(Get-Date -Format 'yyyyMMdd').log"
        Add-Content -Path $LogFile -Value $LogEntry -Encoding UTF8
    }
    catch
    {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERROR] 無法寫入日誌文件: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 函數：驗證文件數位簽章
function Test-DigitalSignature
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $SignatureStatus = @{
        FilePath = $FilePath
        HasSignature = $false
        IsValid = $false
        IsTrusted = $false
        Signer = $null
        Timestamp = $null
        HashAlgorithm = $null
        Error = $null
    }

    try
    {
        $Signature = Get-AuthenticodeSignature -FilePath $FilePath -ErrorAction SilentlyContinue

        if ($Signature.Status -ne 'NotSigned')
        {
            $SignatureStatus.HasSignature = $true
            $SignatureStatus.IsValid = ($Signature.Status -eq 'Valid')
            $SignatureStatus.IsTrusted = ($Signature.IsTrusted -eq $true)
            $SignatureStatus.Signer = $Signature.SignerCertificate.Subject
            $SignatureStatus.Timestamp = $Signature.Timestamp.ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ssZ')
            $SignatureStatus.HashAlgorithm = $Signature.HashAlgorithm.FriendlyName

            if ($Signature.Status -ne 'Valid')
            {
                $SignatureStatus.Error = $Signature.StatusMessage
            }
        }
        else
        {
            $SignatureStatus.Error = "文件沒有數位簽章。"
        }
    }
    catch
    {
        $SignatureStatus.Error = "驗證簽章時發生錯誤: $($_.Exception.Message)"
        Write-Log -Message "驗證文件 '$FilePath' 簽章時發生錯誤: $($_.Exception.Message)" -Level ERROR
    }

    return $SignatureStatus
}

# 主邏輯
function Main
{
    Write-Log -Message "模塊啟動：D4_Digital_Signature - 可疑執行檔與數位簽章驗證模塊" -Level INFO
    Write-Log -Message "掃描路徑：$Path" -Level INFO
    Write-Log -Message "日誌路徑：$LogPath" -Level INFO
    Write-Log -Message "報告路徑：$ReportPath" -Level INFO

    # 確保報告目錄存在
    try
    {
        if (-not (Test-Path -Path $ReportPath -PathType Container))
        {
            New-Item -Path $ReportPath -ItemType Directory -ErrorAction Stop | Out-Null
            Write-Log -Message "已創建報告目錄：$ReportPath" -Level INFO
        }
    }
    catch
    {
        Write-Log -Message "無法創建報告目錄 '$ReportPath': $($_.Exception.Message)" -Level ERROR
        Write-Error "無法創建報告目錄 '$ReportPath': $($_.Exception.Message)"
        exit 1
    }

    $ExecutableFiles = Get-ChildItem -Path $Path -Recurse -Include @('*.exe', '*.dll', '*.sys', '*.ocx', '*.cpl', '*.drv') -ErrorAction SilentlyContinue
    $TotalFiles = $ExecutableFiles.Count
    $ProcessedFiles = 0
    $ReportData = @()

    Write-Log -Message "找到 $TotalFiles 個可執行文件進行掃描。" -Level INFO

    foreach ($File in $ExecutableFiles)
    {
        $ProcessedFiles++
        $ProgressPercentage = [Math]::Round(($ProcessedFiles / $TotalFiles) * 100, 2)

        Write-Progress -Activity "掃描數位簽章" -Status "正在處理文件: $($File.Name)" -PercentComplete $ProgressPercentage -CurrentOperation "已處理 $ProcessedFiles / $TotalFiles 個文件"

        if ($PSCmdlet.ShouldProcess($File.FullName, "驗證數位簽章"))
        {
            Write-Log -Message "正在驗證文件簽章：$($File.FullName)" -Level DEBUG
            $SignatureResult = Test-DigitalSignature -FilePath $File.FullName
            $ReportData += $SignatureResult
        }
        else
        {
            Write-Log -Message "跳過文件簽章驗證 (WhatIf/Confirm)：$($File.FullName)" -Level INFO
        }
    }

    # 生成 JSON 報告
    $ReportFileName = Join-Path $ReportPath "D4_Digital_Signature_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    try
    {
        $ReportData | ConvertTo-Json -Depth 100 | Out-File -FilePath $ReportFileName -Encoding UTF8 -Force
        Write-Log -Message "已生成 JSON 報告：$ReportFileName" -Level INFO
        Write-Host "JSON 報告已生成：$ReportFileName" -ForegroundColor Green
    }
    catch
    {
        Write-Log -Message "無法生成 JSON 報告 '$ReportFileName': $($_.Exception.Message)" -Level ERROR
        Write-Error "無法生成 JSON 報告 '$ReportFileName': $($_.Exception.Message)"
    }

    Write-Log -Message "模塊執行完畢。" -Level INFO
}

# 執行主邏輯
Main
# 錯誤處理：捕獲未處理的異常
try
{
    Main
}
catch
{
    Write-Log -Message "腳本執行期間發生未處理的錯誤: $($_.Exception.Message)" -Level ERROR
    Write-Error "腳本執行期間發生未處理的錯誤: $($_.Exception.Message)"
    exit 1
}
