[CmdletBinding()]
param(
    [string]$OutputRoot,
    [string]$Version,
    [string]$Tag,
    [string]$Repo = "joes021/vhs-mp4-optimizer",
    [string]$Target = "main",
    [string]$GitRemote = "origin",
    [string]$NotesPath,
    [switch]$Draft,
    [switch]$Prerelease
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# GitHub release workflow uses:
# - gh release view
# - gh release create
# - gh release upload

function Invoke-Gh {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$Quiet
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        & gh @Arguments 1>$stdoutPath 2>$stderrPath
        $exitCode = $LASTEXITCODE
        $outputLines = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $outputLines += @(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $outputLines += @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
        }

        if (-not $Quiet -and $null -ne $outputLines) {
            foreach ($line in @($outputLines)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                    Write-Host $line
                }
            }
        }

        return [int]$exitCode
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$Quiet
    )

    $stdoutPath = [System.IO.Path]::GetTempFileName()
    $stderrPath = [System.IO.Path]::GetTempFileName()

    try {
        & git @Arguments 1>$stdoutPath 2>$stderrPath
        $exitCode = $LASTEXITCODE
        $outputLines = @()
        if (Test-Path -LiteralPath $stdoutPath) {
            $outputLines += @(Get-Content -LiteralPath $stdoutPath -ErrorAction SilentlyContinue)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $outputLines += @(Get-Content -LiteralPath $stderrPath -ErrorAction SilentlyContinue)
        }

        if (-not $Quiet -and $null -ne $outputLines) {
            foreach ($line in @($outputLines)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                    Write-Host $line
                }
            }
        }

        return [int]$exitCode
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-GhReleaseExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReleaseTag,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseRepo
    )

    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $exitCode = Invoke-Gh -Arguments @("release", "view", $ReleaseTag, "--repo", $ReleaseRepo, "--json", "tagName") -Quiet
        if ($exitCode -eq 0) {
            return $true
        }

        Start-Sleep -Seconds 2
    }

    return $false
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot "dist\VHS MP4 Optimizer"
}
$outputRootFull = [System.IO.Path]::GetFullPath($OutputRoot)
$manifestPath = Join-Path $outputRootFull "installer-manifest.json"

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "installer-manifest.json nije pronadjen. Pokreni build-vhs-mp4-installer.ps1 prvo."
}

$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
if ($null -eq $ghCommand) {
    throw "gh CLI nije pronadjen. Instaliraj GitHub CLI ili uradi samo git push."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($Version)) {
    $Version = [string]$manifest.Version
}
if ([string]::IsNullOrWhiteSpace($Tag)) {
    $Tag = "vhs-mp4-optimizer-" + $Version
}

$assets = New-Object System.Collections.Generic.List[string]
if ([bool]$manifest.PortableZipExists -and (Test-Path -LiteralPath ([string]$manifest.PortableZipPath))) {
    $assets.Add([string]$manifest.PortableZipPath)
}
if ([bool]$manifest.SetupBuilt -and (Test-Path -LiteralPath ([string]$manifest.SetupExePath))) {
    $assets.Add([string]$manifest.SetupExePath)
}

if ($assets.Count -eq 0) {
    throw "Nema release artefakata za upload."
}

if ([string]::IsNullOrWhiteSpace($NotesPath)) {
    $notesPath = Join-Path $outputRootFull "github-release-notes.txt"
    $notes = @"
VHS MP4 Optimizer

- Portable ZIP paket za rucno raspakivanje
- Setup.exe installer paket kada je Inno Setup bio dostupan pri build-u
- Git ref: $($manifest.GitRef)
"@
    Set-Content -LiteralPath $notesPath -Value $notes -Encoding UTF8
    $NotesPath = $notesPath
}

$title = "VHS MP4 Optimizer $Version"
$releaseExists = Test-GhReleaseExists -ReleaseTag $Tag -ReleaseRepo $Repo

if ($releaseExists) {
    $uploadArgs = @("release", "upload", $Tag)
    $uploadArgs += $assets.ToArray()
    $uploadArgs += @("--repo", $Repo, "--clobber")
    if ((Invoke-Gh -Arguments $uploadArgs) -ne 0) {
        throw "gh release upload nije uspeo za tag $Tag."
    }

    $editArgs = @("release", "edit", $Tag, "--repo", $Repo, "--title", $title, "--notes-file", $NotesPath)
    if ($Draft) {
        $editArgs += "--draft"
    }
    if ($Prerelease) {
        $editArgs += "--prerelease"
    }
    if ((Invoke-Gh -Arguments $editArgs) -ne 0) {
        throw "gh release edit nije uspeo za tag $Tag."
    }
}
else {
    $tagRef = "refs/tags/$Tag"
    $tagVerifyExitCode = Invoke-Git -Arguments @("show-ref", "--verify", "--quiet", $tagRef) -Quiet
    if ($tagVerifyExitCode -ne 0) {
        $tagTarget = if ([string]::IsNullOrWhiteSpace($Target)) { "HEAD" } else { $Target }
        if ((Invoke-Git -Arguments @("tag", $Tag, $tagTarget)) -ne 0) {
            throw "git tag nije uspeo za $Tag na targetu $tagTarget."
        }
    }

    if ((Invoke-Git -Arguments @("push", $GitRemote, $tagRef)) -ne 0) {
        throw "git push taga nije uspeo za $Tag."
    }

    $createArgs = @("release", "create", $Tag)
    $createArgs += $assets.ToArray()
    $createArgs += @("--repo", $Repo, "--title", $title, "--notes-file", $NotesPath)
    if ($Draft) {
        $createArgs += "--draft"
    }
    if ($Prerelease) {
        $createArgs += "--prerelease"
    }
    if ((Invoke-Gh -Arguments $createArgs) -ne 0) {
        throw "gh release create nije uspeo za tag $Tag."
    }
}

Write-Host ("GitHub release tag: " + $Tag)
Write-Host ("Assets: " + ($assets -join ", "))
