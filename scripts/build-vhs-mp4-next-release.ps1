[CmdletBinding()]
param(
    [string]$ReleaseRoot,
    [string]$Version,
    [string]$GitRef,
    [string]$ReleaseTag,
    [string]$Runtime = "win-x64",
    [switch]$SelfContained
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

function Get-NumericVersionInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    if ($Version -match '^(\d+)\.(\d+)\.(\d+)') {
        return @{
            AssemblyVersion = ("{0}.{1}.{2}.0" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
            FileVersion = ("{0}.{1}.{2}.0" -f [int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
        }
    }

    return @{
        AssemblyVersion = "0.0.0.0"
        FileVersion = "0.0.0.0"
    }
}

function Get-DotNetPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot
    )

    $localDotNet = Join-Path $ProjectRoot ".dotnet\dotnet.exe"
    if (Test-Path -LiteralPath $localDotNet) {
        return $localDotNet
    }

    return "dotnet"
}

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$nextRoot = Join-Path $projectRoot "next"
$appProject = Join-Path $nextRoot "src\VhsMp4Optimizer.App\VhsMp4Optimizer.App.csproj"
$dotnet = Get-DotNetPath -ProjectRoot $projectRoot

if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = Get-ProjectVersion -ProjectRoot $projectRoot
}
if ([string]::IsNullOrWhiteSpace($GitRef)) {
    $GitRef = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($ReleaseTag)) {
    $ReleaseTag = "vhs-mp4-optimizer-next-" + $Version
}
if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
    $ReleaseRoot = Join-Path $projectRoot "dist\VHS MP4 Optimizer Next"
}

$releaseRootFull = [System.IO.Path]::GetFullPath($ReleaseRoot)
if (Test-Path -LiteralPath $releaseRootFull) {
    Remove-Item -LiteralPath $releaseRootFull -Recurse -Force
}
$null = New-Item -ItemType Directory -Path $releaseRootFull -Force

$publishDir = Join-Path $releaseRootFull "app"
$guideDir = Join-Path $releaseRootFull "docs"
$guideMediaDir = Join-Path $guideDir "media"
$null = New-Item -ItemType Directory -Path $publishDir -Force
$null = New-Item -ItemType Directory -Path $guideMediaDir -Force

$numericVersion = Get-NumericVersionInfo -Version $Version
$assemblyVersion = $numericVersion.AssemblyVersion
$fileVersion = $numericVersion.FileVersion
$selfContainedText = if ($SelfContained.IsPresent) { "true" } else { "false" }
$publishArgs = @(
    "publish",
    $appProject,
    "-c", "Release",
    "-r", $Runtime,
    "--self-contained", $selfContainedText,
    "-o", $publishDir,
    "/p:Version=$Version",
    "/p:AssemblyVersion=$assemblyVersion",
    "/p:FileVersion=$fileVersion",
    "/p:InformationalVersion=$Version+$GitRef"
)

& $dotnet @publishArgs
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish nije uspeo za Avalonia release."
}

$iconSource = Join-Path $nextRoot "src\VhsMp4Optimizer.App\Assets\avalonia-logo.ico"
if (Test-Path -LiteralPath $iconSource) {
    Copy-Item -LiteralPath $iconSource -Destination (Join-Path $publishDir "avalonia-logo.ico") -Force
}

Copy-Item -LiteralPath (Join-Path $projectRoot "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.html") -Destination (Join-Path $guideDir "VHS_MP4_OPTIMIZER_UPUTSTVO.html") -Force
Copy-Item -LiteralPath (Join-Path $projectRoot "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.md") -Destination (Join-Path $guideDir "VHS_MP4_OPTIMIZER_UPUTSTVO.md") -Force
foreach ($mediaName in @("readme-main-overview.png", "readme-player-trim.png", "readme-batch-controls.png")) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ("docs\media\" + $mediaName)) -Destination (Join-Path $guideMediaDir $mediaName) -Force
}

$manifest = [pscustomobject]@{
    AppName = "VHS MP4 Optimizer Next"
    Version = $Version
    GitRef = $GitRef
    ReleaseTag = $ReleaseTag
    Runtime = $Runtime
    SelfContained = $SelfContained.IsPresent
    BuiltAtUtc = (Get-Date).ToUniversalTime().ToString("o")
    EntryExecutable = "app\VhsMp4Optimizer.App.exe"
    GuidePath = "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.html"
    Branch = Get-GitValue -Arguments @("branch", "--show-current")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    (Join-Path $releaseRootFull "app-manifest.json"),
    ($manifest | ConvertTo-Json -Depth 5),
    $utf8NoBom)

$readme = @"
VHS MP4 Optimizer Next
======================

Ovo je Avalonia/.NET migraciona verzija nove aplikacije.

Pokretanje:
1. Udji u folder `app`
2. Pokreni `VhsMp4Optimizer.App.exe`

Sta je vec preneto:
- scan foldera i eksplicitnih fajlova
- planned output compare
- workflow presets
- test sample
- copy-only split/join
- queue save/load
- floating Player / Trim sa timeline osnovom, crop i aspect opcijama

Sta jos nije potpuni parity:
- pun release/installer tok kao stari sistem
- dublji playback engine
- preostali polish oko naprednog editora
"@
[System.IO.File]::WriteAllText((Join-Path $releaseRootFull "README.txt"), $readme.Trim(), $utf8NoBom)

Write-Host "Avalonia release spreman:" $releaseRootFull
