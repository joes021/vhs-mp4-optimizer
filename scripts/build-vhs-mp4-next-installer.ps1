[CmdletBinding()]
param(
    [string]$OutputRoot,
    [string]$ReleaseRoot,
    [string]$Version,
    [string]$GitRef,
    [string]$InnoSetupCompilerPath,
    [switch]$SkipReleaseRefresh,
    [switch]$SkipInstallerBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitValue {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [string]$Fallback = "unknown"
    )

    try {
        $result = & git @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $Fallback
        }

        $text = [string]($result | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $Fallback
        }

        return $text.Trim()
    }
    catch {
        return $Fallback
    }
}

function Get-ProjectVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $versionPath = Join-Path $ProjectRoot "version.json"
    $parsed = Get-Content -LiteralPath $versionPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $version = [string]$parsed.Version
    if ([string]::IsNullOrWhiteSpace($version) -or $version -notmatch '^\d+\.\d+\.\d+$') {
        throw "version.json mora imati Version u formatu a.b.c"
    }

    return $version
}

function Get-InnoSetupCompilerPath {
    param(
        [string]$PreferredPath
    )

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath) -and (Test-Path -LiteralPath $PreferredPath)) {
        return (Resolve-Path -LiteralPath $PreferredPath).Path
    }

    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    foreach ($candidate in @(
            (Join-Path $env:LOCALAPPDATA "Programs\Inno\ISCC.exe"),
            "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
            "C:\Program Files\Inno Setup 6\ISCC.exe"
        )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Get-VersionInfoNumber {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if ($Version -match '^(\d+)\.(\d+)\.(\d+)$') {
        return ("{0}.{1}.{2}.0" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
    }

    return "0.0.0.0"
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
    $ReleaseRoot = Join-Path $projectRoot "dist\VHS MP4 Optimizer Next"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot "dist\VHS MP4 Optimizer Next Installer"
}

$releaseRootFull = [System.IO.Path]::GetFullPath($ReleaseRoot)
$outputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)

if ([string]::IsNullOrWhiteSpace($GitRef)) {
    $GitRef = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-ProjectVersion -ProjectRoot $projectRoot
}
$versionInfoVersion = Get-VersionInfoNumber -Version $Version

if (-not $SkipReleaseRefresh) {
    & (Join-Path $PSScriptRoot "build-vhs-mp4-next-release.ps1") `
        -ReleaseRoot $releaseRootFull `
        -Version $Version `
        -GitRef $GitRef `
        -ReleaseTag ("vhs-mp4-optimizer-next-" + $Version)
}

if (-not (Test-Path -LiteralPath $releaseRootFull)) {
    throw "Avalonia release folder ne postoji: $releaseRootFull"
}

$null = New-Item -ItemType Directory -Path $outputRootFull -Force

$portableZipName = "VHS-MP4-Optimizer-Next-portable-$Version.zip"
$portableZipPath = Join-Path $outputRootFull $portableZipName
if (Test-Path -LiteralPath $portableZipPath) {
    Remove-Item -LiteralPath $portableZipPath -Force
}
Compress-Archive -LiteralPath $releaseRootFull -DestinationPath $portableZipPath -CompressionLevel Optimal -Force

$compilerPath = Get-InnoSetupCompilerPath -PreferredPath $InnoSetupCompilerPath
$setupExePath = Join-Path $outputRootFull ("VHS-MP4-Optimizer-Next-Setup-" + $Version + ".exe")
$setupBuilt = $false
$setupAttempted = $false
$setupMessage = "Skip installer build."

if (-not $SkipInstallerBuild) {
    $setupAttempted = $true
    if ([string]::IsNullOrWhiteSpace($compilerPath)) {
        $setupMessage = "Inno Setup compiler nije pronadjen. Portable ZIP je ipak spreman."
        Write-Warning $setupMessage
    }
    else {
        $issPath = Join-Path $projectRoot "packaging\vhs-mp4-optimizer-next.iss"
        if (-not (Test-Path -LiteralPath $issPath)) {
            throw "Inno Setup skripta ne postoji: $issPath"
        }

        if (Test-Path -LiteralPath $setupExePath) {
            Remove-Item -LiteralPath $setupExePath -Force
        }

        & $compilerPath @(
            "/Qp",
            "/DMyAppVersion=$Version",
            "/DMyReleaseId=$Version",
            "/DMyVersionInfoVersion=$versionInfoVersion",
            "/DMyReleaseRoot=$releaseRootFull",
            "/DMyOutputRoot=$outputRootFull",
            $issPath
        )
        if ($LASTEXITCODE -ne 0) {
            throw "ISCC.exe nije uspeo za $issPath"
        }

        $setupBuilt = Test-Path -LiteralPath $setupExePath
        if ($setupBuilt) {
            $setupMessage = "Setup.exe je napravljen."
        }
        else {
            $setupMessage = "ISCC.exe je pokrenut, ali Setup.exe nije nadjen."
        }
    }
}

$manifest = [pscustomobject]@{
    Version = $Version
    GitRef = $GitRef
    ReleaseTag = ("vhs-mp4-optimizer-next-" + $Version)
    Repository = "joes021/vhs-mp4-optimizer"
    Branch = "codex/avalonia-migration"
    ReleaseRoot = $releaseRootFull
    OutputRoot = $outputRootFull
    PortableZipPath = $portableZipPath
    PortableZipExists = (Test-Path -LiteralPath $portableZipPath)
    SetupExePath = $setupExePath
    SetupBuilt = $setupBuilt
    SetupAttempted = $setupAttempted
    SetupMessage = $setupMessage
    InnoSetupCompilerPath = if ([string]::IsNullOrWhiteSpace($compilerPath)) { "" } else { $compilerPath }
    BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Join-Path $outputRootFull "installer-manifest.json"),
    ($manifest | ConvertTo-Json -Depth 6),
    $utf8NoBom)

Write-Host ("Portable ZIP: " + $portableZipPath)
if ($setupBuilt) {
    Write-Host ("Setup EXE: " + $setupExePath)
}
else {
    Write-Host ("Setup EXE: " + $setupMessage)
}
