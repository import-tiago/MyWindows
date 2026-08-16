# Requires administrative privileges.
# If the script is not elevated, restart itself as Administrator.

$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

$isAdmin = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdmin) {
    Write-Host "Administrator privileges are required. Requesting elevation..."

    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    exit
}

Write-Host ""
Write-Host "Wake-enabled devices:"
Write-Host ""

$wakeDevices = powercfg /devicequery wake_armed

foreach ($device in $wakeDevices) {
    if (-not [string]::IsNullOrWhiteSpace($device)) {
        Write-Host "Disabling wake: $device"

        powercfg /devicedisablewake "$device"
    }
}

Write-Host ""
Write-Host "Remaining wake-enabled devices:"
Write-Host ""

$remainingDevices = powercfg /devicequery wake_armed

if ($remainingDevices) {
    $remainingDevices
}
else {
    Write-Host "None."
}

Write-Host ""
Write-Host "Done."