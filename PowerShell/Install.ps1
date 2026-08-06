[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$sourceProfile = Join-Path $PSScriptRoot 'Profile.ps1'
$targetProfile = $PROFILE.CurrentUserCurrentHost
$targetDirectory = Split-Path $targetProfile -Parent

$blockStart = '# BEGIN MYWINDOWS MANAGED BLOCK'
$blockEnd = '# END MYWINDOWS MANAGED BLOCK'

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[MyWindows] $Message"
}

function Remove-ManagedBlock {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $escapedStart = [regex]::Escape($blockStart)
    $escapedEnd = [regex]::Escape($blockEnd)
    $pattern = "(?ms)^\s*$escapedStart.*?$escapedEnd\s*\r?\n?"

    return [regex]::Replace($Content, $pattern, '')
}

function Set-RequiredExecutionPolicy {
    $policyList = Get-ExecutionPolicy -List

    $machinePolicy = (
        $policyList |
        Where-Object Scope -eq 'MachinePolicy'
    ).ExecutionPolicy

    $userPolicy = (
        $policyList |
        Where-Object Scope -eq 'UserPolicy'
    ).ExecutionPolicy

    if (
        $machinePolicy -ne 'Undefined' -or
        $userPolicy -ne 'Undefined'
    ) {
        Write-Status 'A Group Policy execution policy is configured.'
        Write-Status "MachinePolicy: $machinePolicy"
        Write-Status "UserPolicy: $userPolicy"

        if (
            $machinePolicy -in @('Restricted', 'AllSigned') -or
            $userPolicy -in @('Restricted', 'AllSigned')
        ) {
            throw @"
PowerShell script execution is restricted by Group Policy.

The installer cannot override MachinePolicy or UserPolicy.
Contact the system administrator.
"@
        }

        return
    }

    $currentUserPolicy = Get-ExecutionPolicy -Scope CurrentUser

    if ($currentUserPolicy -eq 'RemoteSigned') {
        Write-Status 'CurrentUser execution policy is already RemoteSigned.'
        return
    }

    Write-Status 'Setting CurrentUser execution policy to RemoteSigned.'

    try {
        Set-ExecutionPolicy `
            -Scope CurrentUser `
            -ExecutionPolicy RemoteSigned `
            -Force `
            -ErrorAction Stop
    }
    catch {
        $updatedPolicy = Get-ExecutionPolicy -Scope CurrentUser

        if ($updatedPolicy -ne 'RemoteSigned') {
            throw
        }

        Write-Status 'RemoteSigned was saved for CurrentUser.'
        Write-Status 'The current installer remains Bypass until it closes.'
    }

    $savedPolicy = Get-ExecutionPolicy -Scope CurrentUser

    if ($savedPolicy -ne 'RemoteSigned') {
        throw "Unable to configure CurrentUser execution policy. Current value: $savedPolicy"
    }

    Write-Status "CurrentUser execution policy: $savedPolicy"
}

function Unblock-RepositoryFiles {
    Write-Status 'Unblocking PowerShell files in the repository.'

    Get-ChildItem `
        -Path $PSScriptRoot `
        -Filter '*.ps1' `
        -File `
        -Recurse `
        -ErrorAction Stop |
        Unblock-File
}

function Install-ProfileLoader {
    if (-not (Test-Path $sourceProfile -PathType Leaf)) {
        throw "Source profile not found: $sourceProfile"
    }

    if (-not (Test-Path $targetDirectory -PathType Container)) {
        New-Item `
            -ItemType Directory `
            -Path $targetDirectory `
            -Force |
            Out-Null

        Write-Status "Created profile directory: $targetDirectory"
    }

    $currentContent = ''

    if (Test-Path $targetProfile -PathType Leaf) {
        $currentContent = Get-Content `
            -Path $targetProfile `
            -Raw `
            -ErrorAction Stop
    }

    $currentContent = Remove-ManagedBlock -Content $currentContent
    $currentContent = $currentContent.TrimEnd()

    $escapedSourceProfile = $sourceProfile.Replace("'", "''")

    $managedBlock = @"
$blockStart
`$myWindowsProfile = '$escapedSourceProfile'

if (Test-Path `$myWindowsProfile -PathType Leaf) {
    . `$myWindowsProfile
}
else {
    Write-Warning "MyWindows profile not found: `$myWindowsProfile"
}
$blockEnd
"@

    if ([string]::IsNullOrWhiteSpace($currentContent)) {
        $newContent = "$managedBlock`r`n"
    }
    else {
        $newContent = "$currentContent`r`n`r`n$managedBlock`r`n"
    }

    Set-Content `
        -Path $targetProfile `
        -Value $newContent `
        -Encoding UTF8 `
        -Force

    Unblock-File -Path $targetProfile

    Write-Status "Profile loader installed: $targetProfile"
}

function Test-Installation {
    Write-Status 'Testing the profile files.'

    & powershell.exe `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -Command @"
. '$targetProfile'

if (-not (Get-Command prompt -CommandType Function -ErrorAction SilentlyContinue)) {
    exit 1
}
"@

    if ($LASTEXITCODE -ne 0) {
        throw 'PowerShell profile validation failed.'
    }

    Write-Status 'Profile validation completed successfully.'
}

Write-Host ''
Write-Status 'Starting PowerShell configuration.'

Set-RequiredExecutionPolicy
Unblock-RepositoryFiles
Install-ProfileLoader
Test-Installation

Write-Host ''
Write-Status 'Installation completed successfully.'
Write-Status 'Close this window and open a new PowerShell terminal.'