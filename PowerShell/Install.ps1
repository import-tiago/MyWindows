[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$powerShellDirectory = $PSScriptRoot
$sourceProfile = Join-Path $powerShellDirectory 'Profile.ps1'
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

if (-not (Test-Path $sourceProfile -PathType Leaf)) {
    throw "Source profile not found: $sourceProfile"
}

Write-Status "Source profile: $sourceProfile"
Write-Status "Target profile: $targetProfile"

if (-not (Test-Path $targetDirectory -PathType Container)) {
    New-Item `
        -ItemType Directory `
        -Path $targetDirectory `
        -Force |
        Out-Null

    Write-Status 'Created the standard PowerShell profile directory.'
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

if ($currentContent) {
    $newContent = "$currentContent`r`n`r`n$managedBlock`r`n"
}
else {
    $newContent = "$managedBlock`r`n"
}

Set-Content `
    -Path $targetProfile `
    -Value $newContent `
    -Encoding UTF8 `
    -Force

Write-Status 'PowerShell profile configured successfully.'

. $targetProfile

Write-Status 'Configuration loaded in the current session.'
Write-Host ''
Write-Host 'Installation completed.'
Write-Host 'Open a new PowerShell terminal to verify the configuration.'