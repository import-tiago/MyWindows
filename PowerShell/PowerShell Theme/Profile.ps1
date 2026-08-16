function prompt {
    $previousExitCode = $global:LASTEXITCODE

    $userName = $env:USERNAME.ToLower()
    $computerName = $env:COMPUTERNAME
    $location = $ExecutionContext.SessionState.Path.CurrentLocation
    $currentPath = $location.Path
    $homePath = $HOME.TrimEnd('\')
    $esc = [char]27

    if (
        $currentPath.StartsWith(
            $homePath,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        $displayPath = '~' + $currentPath.Substring($homePath.Length)
    }
    else {
        $displayPath = $currentPath
    }

    $branchName = $null

    if (
        $location.Provider.Name -eq 'FileSystem' -and
        (Get-Command git -ErrorAction SilentlyContinue)
    ) {
        $branchOutput = git `
            -C $currentPath `
            symbolic-ref `
            --quiet `
            --short `
            HEAD `
            2>$null

        if ($LASTEXITCODE -eq 0 -and $branchOutput) {
            $branchName = [string]$branchOutput
        }
        else {
            $commitHash = git `
                -C $currentPath `
                rev-parse `
                --short `
                HEAD `
                2>$null

            if ($LASTEXITCODE -eq 0 -and $commitHash) {
                $branchName = "detached@$commitHash"
            }
        }
    }

    $orange = "$esc[38;2;255;140;0m"
    $purple = "$esc[38;2;169;112;255m"
    $blue = "$esc[38;2;97;175;239m"
    $reset = "$esc[0m"

    Write-Host ''

    Write-Host "${purple}$userName@$computerName${reset}" -NoNewline
    Write-Host " ${orange}${displayPath}${reset}" -NoNewline

    if ($branchName) {
        Write-Host " ${blue}[$branchName]${reset}" -NoNewline
    }

    Write-Host ''
    Write-Host "${orange}`$${reset}" -NoNewline

    $global:LASTEXITCODE = $previousExitCode

    return ' '
}