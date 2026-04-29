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

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ReleaseRoot)) {
    $ReleaseRoot = Join-Path $projectRoot "release\VHS MP4 Optimizer"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot "dist\VHS MP4 Optimizer"
}

$releaseRootFull = [System.IO.Path]::GetFullPath($ReleaseRoot)
$outputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)

if ([string]::IsNullOrWhiteSpace($GitRef)) {
    $GitRef = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = (Get-Date -Format "yyyy.MM.dd") + "-" + $GitRef
}

if (-not $SkipReleaseRefresh) {
    $releaseBuilder = Join-Path $PSScriptRoot "build-vhs-mp4-release.ps1"
    & $releaseBuilder `
        -ReleaseRoot $releaseRootFull `
        -Version $Version `
        -GitRef $GitRef `
        -ReleaseTag ("vhs-mp4-optimizer-" + $Version) `
        -Repository "joes021/vhs-mp4-optimizer"
}

if (-not (Test-Path -LiteralPath $releaseRootFull)) {
    throw "Release folder ne postoji: $releaseRootFull"
}

$null = New-Item -ItemType Directory -Path $outputRootFull -Force

$portableZipName = "VHS-MP4-Optimizer-portable-$Version.zip"
$portableZipPath = Join-Path $outputRootFull $portableZipName
if (Test-Path -LiteralPath $portableZipPath) {
    Remove-Item -LiteralPath $portableZipPath -Force
}
Compress-Archive -LiteralPath $releaseRootFull -DestinationPath $portableZipPath -CompressionLevel Optimal -Force

$compilerPath = Get-InnoSetupCompilerPath -PreferredPath $InnoSetupCompilerPath
$setupExePath = Join-Path $outputRootFull ("VHS-MP4-Optimizer-Setup-" + $Version + ".exe")
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
        $issPath = Join-Path $projectRoot "packaging\vhs-mp4-optimizer.iss"
        if (-not (Test-Path -LiteralPath $issPath)) {
            throw "Inno Setup skripta ne postoji: $issPath"
        }

        if (Test-Path -LiteralPath $setupExePath) {
            Remove-Item -LiteralPath $setupExePath -Force
        }

        $isccArgs = @(
            "/Qp",
            "/DMyAppVersion=$Version",
            "/DMyReleaseId=$Version",
            "/DMyReleaseRoot=$releaseRootFull",
            "/DMyOutputRoot=$outputRootFull",
            $issPath
        )

        & $compilerPath @isccArgs
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
    ReleaseTag = ("vhs-mp4-optimizer-" + $Version)
    Repository = "joes021/vhs-mp4-optimizer"
    AppManifestPath = (Join-Path $releaseRootFull "app-manifest.json")
    ProjectRoot = $projectRoot
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

$manifestPath = Join-Path $outputRootFull "installer-manifest.json"
$manifestJson = $manifest | ConvertTo-Json -Depth 6
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)

Write-Host ("Portable ZIP: " + $portableZipPath)
if ($setupBuilt) {
    Write-Host ("Setup EXE: " + $setupExePath)
}
else {
    Write-Host ("Setup EXE: " + $setupMessage)
}
Write-Host ("Manifest: " + $manifestPath)
