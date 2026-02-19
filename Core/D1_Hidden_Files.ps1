<#
.SYNOPSIS
    D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊
    掃描指定路徑下的隱藏檔案和 NTFS 替代資料流 (ADS)。

.DESCRIPTION
    此 PowerShell 腳本旨在檢測 Windows 系統中可能被惡意軟體利用的隱藏檔案和 ADS。
    它支援詳細日誌記錄、進度顯示、錯誤處理，並可生成 JSON 格式的檢測報告。

.PARAMETER Path
    指定要掃描的根目錄路徑。預設為系統磁碟機。

.PARAMETER ScanADS
    布林值，指示是否掃描 NTFS 替代資料流 (ADS)。預設為 $true。

.PARAMETER LogPath
    指定日誌檔案的儲存路徑。預設為腳本所在目錄下的 Logs 子目錄。

.PARAMETER ReportPath
    指定 JSON 報告檔案的儲存路徑。預設為腳本所在目錄下的 Reports 子目錄。

.PARAMETER Verbose
    啟用詳細輸出。

.PARAMETER Debug
    啟用調試輸出。

.EXAMPLE
    .\D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊.ps1 -Path "C:\"

.EXAMPLE
    .\D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊.ps1 -Path "C:\Users" -ScanADS $false -WhatIf

.EXAMPLE
    .\D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊.ps1 -Confirm
#>

# 設置 UTF-8 with BOM 編碼
$PSDefaultParameterValues['*:Encoding'] = [System.Text.UTF8Encoding]::new($true)

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = $env:SystemDrive,

    [Parameter(Mandatory=$false)]
    [bool]$ScanADS = $true,

    [Parameter(Mandatory=$false)]
    [string]$LogPath,

    [Parameter(Mandatory=$false)]
    [string]$ReportPath
)

#region 函數定義

# 寫入日誌函數
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"

    try {
        if (-not (Test-Path $script:LogPath)) {
            New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
        }
        Add-Content -Path (Join-Path $script:LogPath "D1_Hidden_Files_Scan.log") -Value $logEntry -Encoding UTF8

        switch ($Level) {
            "INFO"  { Write-Host $logEntry -ForegroundColor Green }
            "WARN"  { Write-Warning $logEntry }
            "ERROR" { Write-Error $logEntry }
            "DEBUG" { if ($DebugPreference -eq "Continue") { Write-Debug $logEntry } }
        }
    }
    catch {
        Write-Error "寫入日誌失敗: $($_.Exception.Message)"
    }
}

# 掃描隱藏檔案函數
function Find-HiddenFiles {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DirectoryPath
    )

    $hiddenFiles = @()
    try {
        Write-Log -Message "開始掃描隱藏檔案於: $DirectoryPath" -Level "INFO"
        $files = Get-ChildItem -Path $DirectoryPath -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::Hidden }

        foreach ($file in $files) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "檢測隱藏檔案")) {
                Write-Log -Message "發現隱藏檔案: $($file.FullName)" -Level "WARN"
                $hiddenFiles += [pscustomobject]@{ Type = "HiddenFile"; Path = $file.FullName; Attributes = $file.Attributes.ToString() }
            }
        }
        Write-Log -Message "完成掃描隱藏檔案於: $DirectoryPath" -Level "INFO"
    }
    catch {
        Write-Log -Message "掃描隱藏檔案時發生錯誤於 $DirectoryPath: $($_.Exception.Message)" -Level "ERROR"
    }
    return $hiddenFiles
}

# 掃描 ADS 函數
function Find-ADS {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $adsList = @()
    try {
        Write-Log -Message "開始掃描 ADS 於: $FilePath" -Level "DEBUG"
        $ads = Get-Item -Path $FilePath -Stream * -ErrorAction SilentlyContinue | Where-Object { $_.Stream -ne ":$DATA" }

        foreach ($stream in $ads) {
            if ($PSCmdlet.ShouldProcess($stream.FileName, "檢測替代資料流 (ADS)")) {
                Write-Log -Message "發現 ADS: $($stream.FileName):$($stream.Stream)" -Level "WARN"
                $adsList += [pscustomobject]@{ Type = "ADS"; Path = $stream.FileName; StreamName = $stream.Stream; Size = $stream.Length }
            }
        }
        Write-Log -Message "完成掃描 ADS 於: $FilePath" -Level "DEBUG"
    }
    catch {
        Write-Log -Message "掃描 ADS 時發生錯誤於 $FilePath: $($_.Exception.Message)" -Level "ERROR"
    }
    return $adsList
}

#endregion

#region 主邏輯

# 初始化報告數據
$scanResults = @{
    ScanTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    ScanPath = $Path
    HiddenFilesFound = @()
    ADSFound = @()
    Errors = @()
}

# 設置日誌和報告路徑
if (-not $LogPath) {
    $script:LogPath = Join-Path (Split-Path $MyInvocation.MyCommand.Definition) "Logs"
}
if (-not $ReportPath) {
    $script:ReportPath = Join-Path (Split-Path $MyInvocation.MyCommand.Definition) "Reports"
}

Write-Log -Message "D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊 啟動" -Level "INFO"
Write-Log -Message "掃描路徑: $Path" -Level "INFO"
Write-Log -Message "掃描 ADS: $ScanADS" -Level "INFO"

try {
    # 檢查路徑是否存在
    if (-not (Test-Path $Path)) {
        $errorMessage = "指定的掃描路徑不存在: $Path"
        Write-Log -Message $errorMessage -Level "ERROR"
        $scanResults.Errors += $errorMessage
        throw $errorMessage
    }

    # 獲取所有檔案和目錄，用於進度顯示和 ADS 掃描
    $allItems = Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    $totalItems = $allItems.Count
    $processedItems = 0

    # 掃描隱藏檔案
    Write-Log -Message "開始掃描隱藏檔案..." -Level "INFO"
    $hiddenFiles = Find-HiddenFiles -DirectoryPath $Path
    $scanResults.HiddenFilesFound += $hiddenFiles
    Write-Log -Message "完成隱藏檔案掃描。發現 $($hiddenFiles.Count) 個隱藏檔案。" -Level "INFO"

    # 掃描 ADS
    if ($ScanADS) {
        Write-Log -Message "開始掃描替代資料流 (ADS)..." -Level "INFO"
        foreach ($item in $allItems) {
            $processedItems++
            Write-Progress -Activity "掃描替代資料流 (ADS)" -Status "正在處理: $($item.FullName)" -PercentComplete (($processedItems / $totalItems) * 100)

            if ($item.PSIsContainer -eq $false) { # 只掃描檔案的 ADS
                $ads = Find-ADS -FilePath $item.FullName
                $scanResults.ADSFound += $ads
            }
        }
        Write-Log -Message "完成替代資料流 (ADS) 掃描。發現 $($scanResults.ADSFound.Count) 個 ADS。" -Level "INFO"
    }

    # 生成 JSON 報告
    if ($PSCmdlet.ShouldProcess("生成 JSON 報告", "生成報告")) {
        if (-not (Test-Path $ReportPath)) {
            New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
        }
        $reportFileName = "D1_Hidden_Files_Scan_Report_$(Get-Date -Format "yyyyMMdd_HHmmss").json"
        $reportFullPath = Join-Path $ReportPath $reportFileName
        $scanResults | ConvertTo-Json -Depth 100 | Set-Content -Path $reportFullPath -Encoding UTF8
        Write-Log -Message "JSON 報告已生成: $reportFullPath" -Level "INFO"
    }
}
catch {
    $errorMessage = "腳本執行期間發生未預期錯誤: $($_.Exception.Message)"
    Write-Log -Message $errorMessage -Level "ERROR"
    $scanResults.Errors += $errorMessage
}
finally {
    Write-Log -Message "D1_Hidden_Files - 隱藏檔案與 ADS 掃描模塊 執行結束" -Level "INFO"
}

#endregion
