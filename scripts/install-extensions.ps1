<#
.SYNOPSIS
Installs curated VS Code-family extensions across detected or selected IDEs.

.DESCRIPTION
Reads extension IDs from an extensions list file (default: <repo>/ide/extensions.txt),
ignoring blank lines and # comments, and installs them into one or more VS Code-family
IDEs (VS Code, Antigravity, Cursor, Windsurf, VSCodium).

.PARAMETER Ide
Target IDE selection: auto (all detected CLIs), all (attempt every supported IDE),
or a single IDE key (vscode, antigravity, cursor, windsurf, codium).

.PARAMETER Mode
Installation mode: all (install every extension in the list) or missing (query
--list-extensions first and install only extensions not yet present).

.PARAMETER ExtensionsFile
Path to the newline-delimited extension ID list. Defaults to <repo>/ide/extensions.txt.

.PARAMETER Force
Pass --force to the IDE CLI when installing each extension.

.PARAMETER DryRun
Print planned extension install actions without modifying any IDE installation.
#>
[CmdletBinding()]
param(
    [ValidateSet('auto', 'all', 'vscode', 'antigravity', 'cursor', 'windsurf', 'codium')]
    [string]$Ide = 'auto',

    [ValidateSet('all', 'missing')]
    [string]$Mode = 'all',

    [string]$ExtensionsFile,

    [switch]$Force,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:IdeCatalog = @(
    @{ Key = 'vscode';      DisplayName = 'VS Code';     Cli = 'code' }
    @{ Key = 'antigravity'; DisplayName = 'Antigravity'; Cli = 'agy' }
    @{ Key = 'cursor';      DisplayName = 'Cursor';      Cli = 'cursor' }
    @{ Key = 'windsurf';    DisplayName = 'Windsurf';    Cli = 'windsurf' }
    @{ Key = 'codium';      DisplayName = 'VSCodium';    Cli = 'codium' }
)

function Resolve-CliPath {
    param([Parameter(Mandatory)][string]$BinaryName)

    $cmd = Get-Command -Name $BinaryName -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -ne $cmd) {
        return $cmd.Source
    }
    return $null
}

function Read-ExtensionIds {
    param([Parameter(Mandatory)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("Extensions file not found: $FilePath", $FilePath)
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $ids = [System.Collections.Generic.List[string]]::new()

    foreach ($rawLine in [System.IO.File]::ReadAllLines($FilePath)) {
        $cleaned = ($rawLine -replace '#.*$', '').Trim()
        if ([string]::IsNullOrWhiteSpace($cleaned)) {
            continue
        }
        if ($seen.Add($cleaned)) {
            $ids.Add($cleaned)
        }
    }

    return ,$ids.ToArray()
}

function Invoke-NativeCli {
    param(
        [Parameter(Mandatory)][string]$CliPath,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    # PowerShell 5.1 converts native stderr warnings into terminating errors under Stop.
    $previousPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $CliPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        return @{
            ExitCode = $exitCode
            Output   = @($output | ForEach-Object { $_.ToString() })
        }
    }
    finally {
        $ErrorActionPreference = $previousPref
    }
}

function Get-InstalledExtensionSet {
    param([Parameter(Mandatory)][string]$CliPath)

    $result = Invoke-NativeCli -CliPath $CliPath -Arguments @('--list-extensions')
    if ($result.ExitCode -ne 0) {
        return $null
    }

    $installed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($line in $result.Output) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9.-]*$') {
            [void]$installed.Add($trimmed)
        }
    }

    return $installed
}

function Resolve-TargetIdes {
    param([Parameter(Mandatory)][string]$Selection)

    $targets = [System.Collections.Generic.List[hashtable]]::new()

    if ($Selection -eq 'auto') {
        foreach ($entry in $script:IdeCatalog) {
            $cliPath = Resolve-CliPath -BinaryName $entry.Cli
            if ($null -ne $cliPath) {
                $targets.Add(@{
                    Key         = $entry.Key
                    DisplayName = $entry.DisplayName
                    Cli         = $entry.Cli
                    CliPath     = $cliPath
                })
            }
        }
        return ,$targets.ToArray()
    }

    if ($Selection -eq 'all') {
        foreach ($entry in $script:IdeCatalog) {
            $cliPath = Resolve-CliPath -BinaryName $entry.Cli
            $targets.Add(@{
                Key         = $entry.Key
                DisplayName = $entry.DisplayName
                Cli         = $entry.Cli
                CliPath     = $cliPath
            })
        }
        return ,$targets.ToArray()
    }

    $match = $script:IdeCatalog | Where-Object { $_.Key -eq $Selection } | Select-Object -First 1
    $resolvedPath = Resolve-CliPath -BinaryName $match.Cli
    if ($null -eq $resolvedPath) {
        Write-Error "$($match.DisplayName) CLI ($($match.Cli)) was not found in PATH."
        exit 1
    }

    $targets.Add(@{
        Key         = $match.Key
        DisplayName = $match.DisplayName
        Cli         = $match.Cli
        CliPath     = $resolvedPath
    })
    return ,$targets.ToArray()
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ExtensionsFile)) {
    $ExtensionsFile = Join-Path (Join-Path $repoRoot 'ide') 'extensions.txt'
}
else {
    $ExtensionsFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExtensionsFile)
}

try {
    $extensionIds = Read-ExtensionIds -FilePath $ExtensionsFile
}
catch [System.IO.FileNotFoundException] {
    Write-Error $_.Exception.Message
    exit 1
}

if ($extensionIds.Count -eq 0) {
    Write-Warning "No extension IDs found in $ExtensionsFile."
    exit 0
}

$targets = Resolve-TargetIdes -Selection $Ide
if ($targets.Count -eq 0) {
    $checked = ($script:IdeCatalog | ForEach-Object { $_.Cli }) -join ', '
    Write-Warning "No supported IDE CLI found in PATH (checked: $checked)."
    exit 0
}

Write-Host "Loaded $($extensionIds.Count) extension(s) from $ExtensionsFile (mode=$Mode, dryRun=$($DryRun.IsPresent))." -ForegroundColor Cyan

$summaries = [System.Collections.Generic.List[hashtable]]::new()
$anyFailures = $false
$foundAnyCli = $false

foreach ($target in $targets) {
    $stats = @{
        Ide          = $target.DisplayName
        Cli          = $target.Cli
        Installed    = 0
        Skipped      = 0
        Failed       = 0
        WouldInstall = 0
        Status       = 'OK'
    }

    if ($null -eq $target.CliPath) {
        Write-Host "[SKIP] $($target.DisplayName): CLI '$($target.Cli)' not found in PATH." -ForegroundColor DarkGray
        $stats.Status = 'NotInstalled'
        $summaries.Add($stats)
        continue
    }

    $foundAnyCli = $true
    Write-Host "`n==> $($target.DisplayName) ($($target.CliPath))" -ForegroundColor Cyan

    $installedSet = $null
    if ($Mode -eq 'missing') {
        $installedSet = Get-InstalledExtensionSet -CliPath $target.CliPath
        if ($null -eq $installedSet) {
            Write-Warning "Failed to list existing extensions via $($target.Cli); skipping $($target.DisplayName)."
            $stats.Status = 'ListFailed'
            $stats.Failed = $extensionIds.Count
            $anyFailures = $true
            $summaries.Add($stats)
            continue
        }
        Write-Host "Detected $($installedSet.Count) already installed extension(s)." -ForegroundColor Gray
    }

    foreach ($extId in $extensionIds) {
        if ($Mode -eq 'missing' -and $installedSet.Contains($extId)) {
            $stats.Skipped++
            continue
        }

        $cliArgs = @('--install-extension', $extId)
        if ($Force) {
            $cliArgs += '--force'
        }

        if ($DryRun) {
            Write-Host "  [DRY-RUN] $($target.Cli) $($cliArgs -join ' ')" -ForegroundColor Yellow
            $stats.WouldInstall++
            continue
        }

        Write-Host "  Installing $extId..." -ForegroundColor White
        $installResult = Invoke-NativeCli -CliPath $target.CliPath -Arguments $cliArgs
        if ($installResult.ExitCode -eq 0) {
            $stats.Installed++
        }
        else {
            $stats.Failed++
            $anyFailures = $true
            $stats.Status = 'PartialFailure'
            Write-Warning "Failed to install '$extId' for $($target.DisplayName) (exit $($installResult.ExitCode))."
        }
    }

    $summaries.Add($stats)
}

if (-not $foundAnyCli) {
    $checked = ($script:IdeCatalog | ForEach-Object { $_.Cli }) -join ', '
    Write-Warning "No supported IDE CLI found in PATH (checked: $checked)."
}

Write-Host "`n--- Extension Install Summary ---" -ForegroundColor Cyan
foreach ($row in $summaries) {
    if ($row.Status -eq 'NotInstalled') {
        Write-Host ("{0,-12} ({1,-8}) : skipped (CLI missing)" -f $row.Ide, $row.Cli) -ForegroundColor DarkGray
    }
    elseif ($row.Status -eq 'ListFailed') {
        Write-Host ("{0,-12} ({1,-8}) : list failed (skipped)" -f $row.Ide, $row.Cli) -ForegroundColor Red
    }
    elseif ($DryRun) {
        Write-Host ("{0,-12} ({1,-8}) : would_install={2}, skipped={3}" -f $row.Ide, $row.Cli, $row.WouldInstall, $row.Skipped) -ForegroundColor Yellow
    }
    else {
        $color = if ($row.Failed -gt 0) { 'Red' } else { 'Green' }
        Write-Host ("{0,-12} ({1,-8}) : installed={2}, skipped={3}, failed={4}" -f $row.Ide, $row.Cli, $row.Installed, $row.Skipped, $row.Failed) -ForegroundColor $color
    }
}

if ($anyFailures) {
    exit 1
}
