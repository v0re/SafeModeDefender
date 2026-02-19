<#
.SYNOPSIS
Update-Module checks for updates to PowerShell modules
.DESCRIPTION
This script checks the local PowerShell modules against the PowerShell Gallery to see if there are updates available. If updates are available, it will prompt the user to update.
#>

function Update-Module {
    param(
        [string]$ModuleName
    )

    $module = Get-Module -ListAvailable -Name $ModuleName
    if ($null -eq $module) {
        Write-Host "Module '$ModuleName' not found."
        return
    }

    $latestVersion = (Find-Module -Name $ModuleName).Version

    if ($module.Version -lt $latestVersion) {
        Write-Host "Updating '$ModuleName' to version $latestVersion..."
        Update-Module -Name $ModuleName
    } else {
        Write-Host "'$ModuleName' is up-to-date." 
    }
}

# Example usage:
# Update-Module -ModuleName 'SomeModule'