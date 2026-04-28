[CmdletBinding()]
param(
    [string]$InputDir = ".",
    [string]$OutputDir,
    [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
    [string]$QualityMode = "Standard VHS",
    [ValidateRange(0, 51)]
    [int]$Crf = 22,
    [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
    [string]$Preset = "slow",
    [ValidatePattern("^\d+k$")]
    [string]$AudioBitrate = "160k",
    [string]$FfmpegPath = "ffmpeg",
    [switch]$SplitOutput,
    [ValidateRange(0.001, 1024)]
    [double]$MaxPartGb = 3.8,
    [string]$TrimStart = "",
    [string]$TrimEnd = "",
    [ValidateSet("Off", "YADIF", "YADIF Bob")]
    [string]$Deinterlace = "Off",
    [ValidateSet("Off", "Light", "Medium")]
    [string]$Denoise = "Off",
    [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
    [string]$RotateFlip = "None",
    [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
    [string]$ScaleMode = "Original",
    [switch]$AudioNormalize
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"
Import-Module $modulePath -Force

try {
    $summary = Invoke-VhsMp4Batch `
        -InputDir $InputDir `
        -OutputDir $OutputDir `
        -QualityMode $QualityMode `
        -Crf $Crf `
        -Preset $Preset `
        -AudioBitrate $AudioBitrate `
        -FfmpegPath $FfmpegPath `
        -SplitOutput:$SplitOutput `
        -MaxPartGb $MaxPartGb `
        -TrimStart $TrimStart `
        -TrimEnd $TrimEnd `
        -Deinterlace $Deinterlace `
        -Denoise $Denoise `
        -RotateFlip $RotateFlip `
        -ScaleMode $ScaleMode `
        -AudioNormalize:$AudioNormalize
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}

Write-Host "Processed: $($summary.ProcessedCount)"
Write-Host "Skipped: $($summary.SkippedCount)"
Write-Host "Failed: $($summary.FailedCount)"
Write-Host "Stopped: $($summary.StoppedCount)"
Write-Host "OutputDir: $($summary.OutputDir)"
Write-Host "Log: $($summary.LogPath)"
Write-Host "Report: $($summary.ReportPath)"

if (($summary.FailedCount + $summary.StoppedCount) -gt 0) {
    exit 1
}
