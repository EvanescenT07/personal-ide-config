<#
.SYNOPSIS
Deploys sanitized IDE and AI agent configuration templates to local system paths.

.DESCRIPTION
Copies configuration templates from this repository to VS Code-family IDE user
directories and AI agent config directories (Antigravity, OpenCode, CommandCode,
MCP, and project .agents workspace). Creates timestamped backups before
overwriting existing files unless -NoBackup is specified.

.PARAMETER Target
One or more deployment targets: all, ide, antigravity, opencode, commandcode,
mcp, or workspace.

.PARAMETER Ide
Target IDE selection when deploying ide settings: auto (detected IDEs), all,
vscode, antigravity, cursor, windsurf, or codium.

.PARAMETER WorkspacePath
Target project root for the workspace target (<WorkspacePath>/.agents/). Defaults
to the current directory.

.PARAMETER DryRun
Print planned backups and file writes without modifying disk state.

.PARAMETER NoBackup
Overwrite existing target files directly without creating *.bak.<timestamp> copies.

.PARAMETER ResolvePaths
Auto-detect local flutter, java JDK, and home paths and substitute ${HOME},
${env:FLUTTER_ROOT}, ${env:JAVA_HOME}, and any already-set ${env:*} variables
in deployed JSON/JSONC templates. Unset secret placeholders remain intact.
#>
[CmdletBinding()]
param(
    [ValidateSet('all', 'ide', 'antigravity', 'opencode', 'commandcode', 'mcp', 'workspace')]
    [string[]]$Target = @('all'),

    [ValidateSet('auto', 'all', 'vscode', 'antigravity', 'cursor', 'windsurf', 'codium')]
    [string]$Ide = 'auto',

    [string]$WorkspacePath = '.',

    [switch]$DryRun,

    [switch]$NoBackup,

    [switch]$ResolvePaths
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:IdeDefinitions = @(
    @{ Key = 'vscode';      DisplayName = 'VS Code';     Cli = 'code';     Folder = 'Code' }
    @{ Key = 'antigravity'; DisplayName = 'Antigravity'; Cli = 'agy';      Folder = 'Antigravity' }
    @{ Key = 'cursor';      DisplayName = 'Cursor';      Cli = 'cursor';   Folder = 'Cursor' }
    @{ Key = 'windsurf';    DisplayName = 'Windsurf';    Cli = 'windsurf'; Folder = 'Windsurf' }
    @{ Key = 'codium';      DisplayName = 'VSCodium';    Cli = 'codium';   Folder = 'VSCodium' }
)

$script:RunTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:Stats = @{
    Written  = 0
    BackedUp = 0
    Skipped  = 0
    Errors   = 0
}
$script:UnresolvedVars = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

function Get-PlatformName {
    if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
        return 'Windows'
    }
    if ($IsMacOS) {
        return 'macOS'
    }
    return 'Linux'
}

function Get-HomeDirectory {
    if (-not [string]::IsNullOrWhiteSpace($HOME)) {
        return $HOME
    }
    return [Environment]::GetFolderPath('UserProfile')
}

function Test-PathSafe {
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Any', 'Container', 'Leaf')]
        [string]$PathType = 'Any'
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    try {
        return (Test-Path -LiteralPath $Path -PathType $PathType -ErrorAction Stop)
    }
    catch [System.UnauthorizedAccessException] {
        return $false
    }
    catch [System.IO.IOException] {
        return $false
    }
}

function Get-IdeLocationInfo {
    param(
        [Parameter(Mandatory)][hashtable]$Definition,
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][string]$HomeDir
    )

    if ($Platform -eq 'Windows') {
        $appData = if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
            Join-Path (Join-Path $HomeDir 'AppData') 'Roaming'
        }
        else {
            $env:APPDATA
        }
        $baseDir = Join-Path $appData $Definition.Folder
    }
    elseif ($Platform -eq 'macOS') {
        $appSupport = Join-Path (Join-Path $HomeDir 'Library') 'Application Support'
        $baseDir = Join-Path $appSupport $Definition.Folder
    }
    else {
        $xdgConfig = if ([string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
            Join-Path $HomeDir '.config'
        }
        else {
            $env:XDG_CONFIG_HOME
        }
        $baseDir = Join-Path $xdgConfig $Definition.Folder
    }

    $userDir = Join-Path $baseDir 'User'
    return @{
        Key          = $Definition.Key
        DisplayName  = $Definition.DisplayName
        Cli          = $Definition.Cli
        BaseDir      = $baseDir
        UserDir      = $userDir
        SettingsPath = Join-Path $userDir 'settings.json'
    }
}

function Test-CliAvailable {
    param([Parameter(Mandatory)][string]$BinaryName)

    $cmd = Get-Command -Name $BinaryName -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
    return ($null -ne $cmd)
}

function Resolve-TargetIdeLocations {
    param(
        [Parameter(Mandatory)][string]$Selection,
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][string]$HomeDir
    )

    $locations = [System.Collections.Generic.List[hashtable]]::new()

    if ($Selection -eq 'auto') {
        foreach ($def in $script:IdeDefinitions) {
            $loc = Get-IdeLocationInfo -Definition $def -Platform $Platform -HomeDir $HomeDir
            if ((Test-CliAvailable -BinaryName $def.Cli) -or (Test-PathSafe -Path $loc.BaseDir -PathType Container)) {
                $locations.Add($loc)
            }
        }
        return ,$locations.ToArray()
    }

    if ($Selection -eq 'all') {
        foreach ($def in $script:IdeDefinitions) {
            $locations.Add((Get-IdeLocationInfo -Definition $def -Platform $Platform -HomeDir $HomeDir))
        }
        return ,$locations.ToArray()
    }

    $match = $script:IdeDefinitions | Where-Object { $_.Key -eq $Selection } | Select-Object -First 1
    $locations.Add((Get-IdeLocationInfo -Definition $match -Platform $Platform -HomeDir $HomeDir))
    return ,$locations.ToArray()
}

function Resolve-SymlinkTargetPath {
    param([Parameter(Mandatory)][string]$Path)

    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($null -ne $item.LinkType -and -not [string]::IsNullOrWhiteSpace($item.Target)) {
            $target = @($item.Target)[0]
            if ([System.IO.Path]::IsPathRooted($target)) {
                return $target
            }
            return [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $Path) $target))
        }
    }
    catch [System.IO.IOException] {
        return $Path
    }
    catch [System.UnauthorizedAccessException] {
        return $Path
    }

    return $Path
}

function Find-FlutterRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_ROOT) -and (Test-PathSafe -Path $env:FLUTTER_ROOT -PathType Container)) {
        return $env:FLUTTER_ROOT
    }

    $cmd = Get-Command -Name 'flutter' -CommandType Application, ExternalScript -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $cmd) {
        return $null
    }

    $resolvedBin = Resolve-SymlinkTargetPath -Path $cmd.Source
    $binDir = Split-Path -Parent $resolvedBin
    if ((Split-Path -Leaf $binDir) -ieq 'bin') {
        $candidate = Split-Path -Parent $binDir
        if (Test-PathSafe -Path $candidate -PathType Container) {
            return $candidate
        }
    }
    return $null
}

function Find-JavaHome {
    param([Parameter(Mandatory)][string]$Platform)

    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME) -and (Test-PathSafe -Path $env:JAVA_HOME -PathType Container)) {
        return $env:JAVA_HOME
    }

    if ($Platform -eq 'macOS' -and (Test-PathSafe -Path '/usr/libexec/java_home' -PathType Leaf)) {
        $previousPref = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $macJavaHome = (& /usr/libexec/java_home 2>$null | Select-Object -First 1)
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($macJavaHome)) {
                $trimmed = $macJavaHome.Trim()
                if (Test-PathSafe -Path $trimmed -PathType Container) {
                    return $trimmed
                }
            }
        }
        finally {
            $ErrorActionPreference = $previousPref
        }
    }

    $cmd = Get-Command -Name 'java' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $cmd) {
        return $null
    }

    $resolvedBin = Resolve-SymlinkTargetPath -Path $cmd.Source
    $binDir = Split-Path -Parent $resolvedBin
    if ((Split-Path -Leaf $binDir) -ine 'bin') {
        return $null
    }

    $candidate = Split-Path -Parent $binDir
    $leaf = Split-Path -Leaf $candidate
    if ($leaf -ieq 'javapath' -or $candidate -ieq $env:SystemRoot -or $candidate -eq '/usr') {
        return $null
    }

    $hasRelease = Test-PathSafe -Path (Join-Path $candidate 'release') -PathType Leaf
    $hasJavac = (Test-PathSafe -Path (Join-Path $binDir 'javac.exe') -PathType Leaf) -or
                (Test-PathSafe -Path (Join-Path $binDir 'javac') -PathType Leaf)
    if ($hasRelease -or $hasJavac) {
        return $candidate
    }
    return $null
}

function New-PathResolutionContext {
    param(
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][string]$HomeDir
    )

    $flutterRoot = Find-FlutterRoot
    $javaHome = Find-JavaHome -Platform $Platform

    Write-Host 'Path resolution summary:' -ForegroundColor Cyan
    Write-Host "  HOME         : $($HomeDir -replace '\\', '/')" -ForegroundColor Gray
    Write-Host "  FLUTTER_ROOT : $(if ($flutterRoot) { $flutterRoot } else { '<not detected; keeping placeholder>' })" -ForegroundColor Gray
    Write-Host "  JAVA_HOME    : $(if ($javaHome) { $javaHome } else { '<not detected; keeping placeholder>' })" -ForegroundColor Gray

    return @{
        HomeForward = ($HomeDir -replace '\\', '/')
        FlutterRoot = $flutterRoot
        JavaHome    = $javaHome
    }
}

function ConvertTo-JsonEscapedValue {
    param([Parameter(Mandatory)][string]$Value)

    return ($Value -replace '\\', '\\' -replace '"', '\"')
}

function Resolve-JsonTemplateContent {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][hashtable]$Context
    )

    $lines = $Content -split "`r?`n", -1
    $newline = if ($Content -match "`r`n") { "`r`n" } else { "`n" }
    $envPattern = [regex]'\$\{env:([A-Za-z_][A-Za-z0-9_]*)\}'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Skip single-line JSONC comments so adaptation instructions stay readable.
        if ($line -match '^\s*//') {
            continue
        }

        if ($line.Contains('${HOME}')) {
            $escapedHome = ConvertTo-JsonEscapedValue -Value $Context.HomeForward
            $line = $line.Replace('${HOME}', $escapedHome)
        }

        $line = $envPattern.Replace($line, {
            param($m)
            $varName = $m.Groups[1].Value

            if ($varName -eq 'FLUTTER_ROOT') {
                if (-not [string]::IsNullOrWhiteSpace($Context.FlutterRoot)) {
                    return (ConvertTo-JsonEscapedValue -Value $Context.FlutterRoot)
                }
                [void]$script:UnresolvedVars.Add($varName)
                return $m.Value
            }

            if ($varName -eq 'JAVA_HOME') {
                if (-not [string]::IsNullOrWhiteSpace($Context.JavaHome)) {
                    return (ConvertTo-JsonEscapedValue -Value $Context.JavaHome)
                }
                [void]$script:UnresolvedVars.Add($varName)
                return $m.Value
            }

            $envVal = [Environment]::GetEnvironmentVariable($varName)
            if (-not [string]::IsNullOrWhiteSpace($envVal)) {
                return (ConvertTo-JsonEscapedValue -Value $envVal)
            }

            [void]$script:UnresolvedVars.Add($varName)
            return $m.Value
        })

        $lines[$i] = $line
    }

    return ($lines -join $newline)
}

function Deploy-SingleFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$DestinationPath,
        [bool]$AllowResolve = $false,
        [hashtable]$ResolutionContext = $null
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        Write-Warning "Missing template source: $SourcePath"
        $script:Stats.Errors++
        return
    }

    $destDir = Split-Path -Parent $DestinationPath
    $exists = Test-PathSafe -Path $DestinationPath -PathType Leaf
    $backupPath = "$DestinationPath.bak.$script:RunTimestamp"

    $ext = [System.IO.Path]::GetExtension($SourcePath).ToLowerInvariant()
    $shouldSubstitute = $ResolvePaths.IsPresent -and $AllowResolve -and ($null -ne $ResolutionContext) -and ($ext -in @('.json', '.jsonc'))

    if ($DryRun) {
        if ($exists -and -not $NoBackup) {
            Write-Host "  [DRY-RUN] Backup : $DestinationPath -> $backupPath" -ForegroundColor DarkYellow
        }
        $resolveNote = if ($shouldSubstitute) { ' (with path/env resolution)' } else { '' }
        Write-Host "  [DRY-RUN] Write  : $SourcePath -> $DestinationPath$resolveNote" -ForegroundColor Yellow
        $script:Stats.Written++
        if ($exists -and -not $NoBackup) {
            $script:Stats.BackedUp++
        }
        return
    }

    try {
        if (-not (Test-Path -LiteralPath $destDir -PathType Container)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        if ($exists -and -not $NoBackup) {
            Copy-Item -LiteralPath $DestinationPath -Destination $backupPath -Force
            Write-Host "  [BACKUP] $backupPath" -ForegroundColor DarkYellow
            $script:Stats.BackedUp++
        }

        if ($shouldSubstitute) {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            $rawContent = [System.IO.File]::ReadAllText($SourcePath, $utf8NoBom)
            $resolvedContent = Resolve-JsonTemplateContent -Content $rawContent -Context $ResolutionContext
            [System.IO.File]::WriteAllText($DestinationPath, $resolvedContent, $utf8NoBom)
        }
        else {
            Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
        }

        Write-Host "  [WRITE]  $DestinationPath" -ForegroundColor Green
        $script:Stats.Written++
    }
    catch [System.IO.IOException] {
        Write-Warning "I/O error deploying '$DestinationPath': $($_.Exception.Message)"
        $script:Stats.Errors++
    }
    catch [System.UnauthorizedAccessException] {
        Write-Warning "Permission denied deploying '$DestinationPath': $($_.Exception.Message)"
        $script:Stats.Errors++
    }
}

function Deploy-DirectoryTree {
    param(
        [Parameter(Mandatory)][string]$SourceDir,
        [Parameter(Mandatory)][string]$DestinationDir,
        [string[]]$ExcludeFileNames = @('README.md'),
        [bool]$AllowResolve = $true,
        [hashtable]$ResolutionContext = $null
    )

    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
        Write-Warning "Missing template directory: $SourceDir"
        $script:Stats.Errors++
        return
    }

    $normalizedBase = [System.IO.Path]::GetFullPath($SourceDir).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $files = Get-ChildItem -LiteralPath $SourceDir -Recurse -File | Where-Object {
        $ExcludeFileNames -notcontains $_.Name
    }

    foreach ($file in $files) {
        $fullSource = [System.IO.Path]::GetFullPath($file.FullName)
        $relative = $fullSource.Substring($normalizedBase.Length)
        $destFile = Join-Path $DestinationDir $relative
        Deploy-SingleFile -SourcePath $fullSource -DestinationPath $destFile -AllowResolve $AllowResolve -ResolutionContext $ResolutionContext
    }
}

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$platform = Get-PlatformName
$homeDir = Get-HomeDirectory
$resolvedWorkspace = [System.IO.Path]::GetFullPath(
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkspacePath)
)

$includeAll = $Target -contains 'all'
$explicitWorkspace = $Target -contains 'workspace'

$selectedTargets = [System.Collections.Generic.List[string]]::new()
if ($includeAll) {
    foreach ($name in @('ide', 'antigravity', 'mcp', 'opencode', 'commandcode', 'workspace')) {
        $selectedTargets.Add($name)
    }
}
else {
    foreach ($t in $Target) {
        if (-not $selectedTargets.Contains($t)) {
            $selectedTargets.Add($t)
        }
    }
}

Write-Host "Deploying configs (platform=$platform, targets=$($selectedTargets -join ','), dryRun=$($DryRun.IsPresent), backup=$(-not $NoBackup.IsPresent))." -ForegroundColor Cyan

$resolutionContext = $null
if ($ResolvePaths) {
    $resolutionContext = New-PathResolutionContext -Platform $platform -HomeDir $homeDir
}

$geminiDir = Join-Path $homeDir '.gemini'
$geminiConfigDir = Join-Path $geminiDir 'config'
$xdgConfigHome = if ([string]::IsNullOrWhiteSpace($env:XDG_CONFIG_HOME)) {
    Join-Path $homeDir '.config'
}
else {
    $env:XDG_CONFIG_HOME
}

foreach ($activeTarget in $selectedTargets) {
    switch ($activeTarget) {
        'ide' {
            Write-Host "`n==> Target: ide" -ForegroundColor Cyan
            $ideSettingsSource = Join-Path (Join-Path $repoRoot 'ide') 'settings.json'
            $ideLocations = Resolve-TargetIdeLocations -Selection $Ide -Platform $platform -HomeDir $homeDir
            if ($ideLocations.Count -eq 0) {
                Write-Warning 'No supported IDE installation detected (checked VS Code, Antigravity, Cursor, Windsurf, VSCodium). Pass -Ide <name> or -Ide all to force.'
                $script:Stats.Skipped++
                break
            }
            foreach ($loc in $ideLocations) {
                Write-Host "  IDE: $($loc.DisplayName)" -ForegroundColor Gray
                Deploy-SingleFile -SourcePath $ideSettingsSource -DestinationPath $loc.SettingsPath -AllowResolve $true -ResolutionContext $resolutionContext
            }
        }

        'antigravity' {
            Write-Host "`n==> Target: antigravity" -ForegroundColor Cyan
            $agentsMd = Join-Path $repoRoot 'AGENTS.md'
            $skillsJson = Join-Path (Join-Path (Join-Path $repoRoot 'agent') 'antigravity') 'skills.json'
            $configTemplate = Join-Path (Join-Path (Join-Path $repoRoot 'agent') 'antigravity') 'config.template.json'

            Deploy-SingleFile -SourcePath $agentsMd -DestinationPath (Join-Path $geminiDir 'GEMINI.md') -AllowResolve $false -ResolutionContext $resolutionContext
            Deploy-SingleFile -SourcePath $skillsJson -DestinationPath (Join-Path $geminiConfigDir 'skills.json') -AllowResolve $true -ResolutionContext $resolutionContext

            $liveConfigPath = Join-Path $geminiConfigDir 'config.json'
            if (Test-PathSafe -Path $configTemplate -PathType Leaf) {
                Deploy-SingleFile -SourcePath $configTemplate -DestinationPath (Join-Path $geminiConfigDir 'config.template.json') -AllowResolve $true -ResolutionContext $resolutionContext
            }
            if (Test-PathSafe -Path $liveConfigPath -PathType Leaf) {
                Write-Host "  [NOTE] Preserved live '$liveConfigPath'. Merge plugins/permissions manually from config.template.json." -ForegroundColor Yellow
            }
            else {
                Write-Host "  [NOTE] '$liveConfigPath' is not overwritten automatically. Review config.template.json and copy/adapt if initializing fresh." -ForegroundColor Yellow
            }
        }

        'mcp' {
            Write-Host "`n==> Target: mcp" -ForegroundColor Cyan
            $mcpSource = Join-Path (Join-Path (Join-Path $repoRoot 'agent') 'mcp') 'mcp_config.json'
            Deploy-SingleFile -SourcePath $mcpSource -DestinationPath (Join-Path $geminiConfigDir 'mcp_config.json') -AllowResolve $true -ResolutionContext $resolutionContext
        }

        'opencode' {
            Write-Host "`n==> Target: opencode" -ForegroundColor Cyan
            $opencodeSourceDir = Join-Path (Join-Path $repoRoot 'agent') 'opencode'
            $opencodeDestDir = Join-Path $xdgConfigHome 'opencode'
            Deploy-DirectoryTree -SourceDir $opencodeSourceDir -DestinationDir $opencodeDestDir -AllowResolve $true -ResolutionContext $resolutionContext
        }

        'commandcode' {
            Write-Host "`n==> Target: commandcode" -ForegroundColor Cyan
            $ccSourceDir = Join-Path (Join-Path $repoRoot 'agent') 'commandcode'
            $ccDestDir = Join-Path $homeDir '.opencode'
            Deploy-DirectoryTree -SourceDir $ccSourceDir -DestinationDir $ccDestDir -AllowResolve $true -ResolutionContext $resolutionContext
        }

        'workspace' {
            Write-Host "`n==> Target: workspace" -ForegroundColor Cyan
            if ($includeAll -and -not $explicitWorkspace -and ($resolvedWorkspace.TrimEnd('\', '/') -ieq $repoRoot.TrimEnd('\', '/'))) {
                Write-Host '  [SKIP] WorkspacePath resolves to this config repository. Pass -Target workspace or -WorkspacePath <project> to deploy .agents/.' -ForegroundColor DarkGray
                $script:Stats.Skipped++
                break
            }
            $wsSourceDir = Join-Path (Join-Path $repoRoot 'agent') 'workspace'
            $wsDestDir = Join-Path $resolvedWorkspace '.agents'
            Deploy-DirectoryTree -SourceDir $wsSourceDir -DestinationDir $wsDestDir -AllowResolve $true -ResolutionContext $resolutionContext
        }
    }
}

Write-Host "`n--- Config Deployment Summary ---" -ForegroundColor Cyan
Write-Host ("written={0}, backed_up={1}, skipped={2}, errors={3}" -f $script:Stats.Written, $script:Stats.BackedUp, $script:Stats.Skipped, $script:Stats.Errors) -ForegroundColor $(if ($script:Stats.Errors -gt 0) { 'Red' } else { 'Green' })

if ($ResolvePaths -and $script:UnresolvedVars.Count -gt 0) {
    $pending = ($script:UnresolvedVars | Sort-Object) -join ', '
    Write-Host "[NOTE] Unresolved placeholders kept intact (set env vars or edit deployed files manually): $pending" -ForegroundColor Yellow
}

if ($script:Stats.Errors -gt 0) {
    exit 1
}
