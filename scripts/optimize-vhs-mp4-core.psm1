Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-VhsMp4CommandPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandPath
    )

    if (Test-Path -LiteralPath $CommandPath) {
        return [System.IO.Path]::GetFullPath($CommandPath)
    }

    $command = Get-Command -Name $CommandPath -ErrorAction Stop
    if ($command.Source) {
        return $command.Source
    }
    if ($command.Path) {
        return $command.Path
    }

    return $command.Definition
}

function Find-VhsMp4InstalledFfmpeg {
    param(
        [string[]]$SearchRoots
    )

    if (-not $SearchRoots -or $SearchRoots.Count -eq 0) {
        $SearchRoots = @(
            (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"),
            (Join-Path $env:LOCALAPPDATA "Programs\FFmpeg"),
            (Join-Path $env:LOCALAPPDATA "Programs\ffmpeg")
        )
    }

    $candidates = foreach ($root in $SearchRoots) {
        if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -Recurse -Filter "ffmpeg.exe" -File -ErrorAction SilentlyContinue
    }

    $preferred = $candidates |
        Sort-Object @{ Expression = { if ($_.FullName -match "Gyan\.FFmpeg|WinGet|\\bin\\ffmpeg\.exe$") { 0 } else { 1 } } }, FullName |
        Select-Object -First 1

    if ($preferred) {
        return $preferred.FullName
    }

    return $null
}

function Add-VhsMp4DirectoryToUserPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    if (-not (Test-Path -LiteralPath $Directory)) {
        throw "FFmpeg direktorijum ne postoji: $Directory"
    }

    $resolvedDirectory = [System.IO.Path]::GetFullPath($Directory)
    $currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @()
    if (-not [string]::IsNullOrWhiteSpace($currentUserPath)) {
        $entries = $currentUserPath.Split(";") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    }

    if ($entries -notcontains $resolvedDirectory) {
        $updatedEntries = @($entries + $resolvedDirectory) | Select-Object -Unique
        [Environment]::SetEnvironmentVariable("Path", ($updatedEntries -join ";"), "User")
        return ($updatedEntries -join ";")
    }

    return $currentUserPath
}

function Update-VhsMp4ProcessPathFromEnvironment {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $processPath = [Environment]::GetEnvironmentVariable("Path", "Process")

    $entries = @($machinePath, $userPath, $processPath) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Split(";") } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -Unique

    $merged = $entries -join ";"
    [Environment]::SetEnvironmentVariable("Path", $merged, "Process")
    $env:Path = $merged
    return $merged
}

function Get-VhsMp4ErrorMessage {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorObject
    )

    if ($ErrorObject -is [System.Management.Automation.ErrorRecord]) {
        if ($ErrorObject.Exception -and -not [string]::IsNullOrWhiteSpace($ErrorObject.Exception.Message)) {
            return $ErrorObject.Exception.Message
        }
        return [string]$ErrorObject
    }

    if ($ErrorObject -is [System.Exception]) {
        return $ErrorObject.Message
    }

    $exceptionProperty = $ErrorObject.PSObject.Properties["Exception"]
    if ($exceptionProperty -and $exceptionProperty.Value -and $exceptionProperty.Value.Message) {
        return $exceptionProperty.Value.Message
    }

    $messageProperty = $ErrorObject.PSObject.Properties["Message"]
    if ($messageProperty -and -not [string]::IsNullOrWhiteSpace([string]$messageProperty.Value)) {
        return [string]$messageProperty.Value
    }

    return [string]$ErrorObject
}

function Get-VhsMp4ResolvedFfmpegPath {
    param(
        [string]$CandidatePath,
        [string[]]$SearchRoots
    )

    if (-not [string]::IsNullOrWhiteSpace($CandidatePath)) {
        try {
            return (Resolve-VhsMp4CommandPath -CommandPath $CandidatePath)
        }
        catch {
        }
    }

    try {
        return (Resolve-VhsMp4CommandPath -CommandPath "ffmpeg")
    }
    catch {
    }

    return (Find-VhsMp4InstalledFfmpeg -SearchRoots $SearchRoots)
}

function Resolve-VhsMp4FfprobePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    $resolvedFfmpeg = Resolve-VhsMp4CommandPath -CommandPath $FfmpegPath
    $ffmpegDirectory = Split-Path -Path $resolvedFfmpeg -Parent
    foreach ($ffprobeName in @("ffprobe.exe", "ffprobe.ps1", "ffprobe.cmd", "ffprobe.bat")) {
        $siblingFfprobe = Join-Path $ffmpegDirectory $ffprobeName
        if (Test-Path -LiteralPath $siblingFfprobe) {
            return [System.IO.Path]::GetFullPath($siblingFfprobe)
        }
    }

    return (Resolve-VhsMp4CommandPath -CommandPath "ffprobe")
}

function Invoke-VhsMp4Ffprobe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FfprobeArguments
    )

    $ffprobePath = Resolve-VhsMp4FfprobePath -FfmpegPath $FfmpegPath
    $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $ffprobePath -FfmpegArguments @($FfprobeArguments + $SourcePath)

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "ffprobe exit code: $($process.ExitCode) | $stderr"
    }

    return $stdout
}

function Get-VhsMp4ObjectPropertyValue {
    param(
        $Object,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function Convert-VhsMp4OptionalDouble {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $parsed = 0.0
    $style = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse([string]$Value, $style, $culture, [ref]$parsed)) {
        if ([double]::IsNaN($parsed) -or [double]::IsInfinity($parsed)) {
            return $null
        }
        return $parsed
    }

    return $null
}

function Convert-VhsMp4OptionalInt64 {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $parsed = 0L
    if ([int64]::TryParse([string]$Value, [ref]$parsed)) {
        return $parsed
    }

    return $null
}

function Convert-VhsMp4BitsPerSecondToKbps {
    param($Value)

    $bitsPerSecond = Convert-VhsMp4OptionalDouble -Value $Value
    if ($null -eq $bitsPerSecond -or $bitsPerSecond -le 0) {
        return $null
    }

    return [int][Math]::Round($bitsPerSecond / 1000.0, 0, [System.MidpointRounding]::AwayFromZero)
}

function Format-VhsMp4DurationText {
    param($Seconds)

    $duration = Convert-VhsMp4OptionalDouble -Value $Seconds
    if ($null -eq $duration -or $duration -le 0) {
        return "--"
    }

    $roundedSeconds = [int][Math]::Round($duration, 0, [System.MidpointRounding]::AwayFromZero)
    $timeSpan = [System.TimeSpan]::FromSeconds($roundedSeconds)
    return "{0:00}:{1:00}:{2:00}" -f [int][Math]::Floor($timeSpan.TotalHours), $timeSpan.Minutes, $timeSpan.Seconds
}

function Convert-VhsMp4TimeTextToSeconds {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $text = ([string]$Value).Trim()
    $normalized = $text.Replace(",", ".")
    $style = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture

    $numericSeconds = 0.0
    if ([double]::TryParse($normalized, $style, $culture, [ref]$numericSeconds)) {
        if ($numericSeconds -lt 0) {
            throw "Vreme ne moze biti negativno: $text"
        }
        return $numericSeconds
    }

    $parts = $normalized.Split(":")
    if ($parts.Count -ne 2 -and $parts.Count -ne 3) {
        throw "Neispravan format vremena: $text. Koristi HH:MM:SS, MM:SS ili sekunde."
    }

    $hours = 0.0
    $minutes = 0.0
    $seconds = 0.0
    if ($parts.Count -eq 3) {
        if (-not [double]::TryParse($parts[0], $style, $culture, [ref]$hours) -or
            -not [double]::TryParse($parts[1], $style, $culture, [ref]$minutes) -or
            -not [double]::TryParse($parts[2], $style, $culture, [ref]$seconds)) {
            throw "Neispravan format vremena: $text. Koristi HH:MM:SS, MM:SS ili sekunde."
        }
        if ($hours -lt 0 -or $minutes -lt 0 -or $minutes -ge 60 -or $seconds -lt 0 -or $seconds -ge 60) {
            throw "Neispravan opseg vremena: $text"
        }
    }
    else {
        if (-not [double]::TryParse($parts[0], $style, $culture, [ref]$minutes) -or
            -not [double]::TryParse($parts[1], $style, $culture, [ref]$seconds)) {
            throw "Neispravan format vremena: $text. Koristi HH:MM:SS, MM:SS ili sekunde."
        }
        if ($minutes -lt 0 -or $seconds -lt 0 -or $seconds -ge 60) {
            throw "Neispravan opseg vremena: $text"
        }
    }

    return (($hours * 3600.0) + ($minutes * 60.0) + $seconds)
}

function Format-VhsMp4FfmpegTime {
    param($Seconds)

    $duration = Convert-VhsMp4OptionalDouble -Value $Seconds
    if ($null -eq $duration -or $duration -lt 0) {
        return ""
    }

    $timeSpan = [System.TimeSpan]::FromSeconds($duration)
    $totalHours = [int][Math]::Floor($timeSpan.TotalHours)
    $baseText = "{0:00}:{1:00}:{2:00}" -f $totalHours, $timeSpan.Minutes, $timeSpan.Seconds
    if ($timeSpan.Milliseconds -gt 0) {
        return ($baseText + "." + ($timeSpan.Milliseconds.ToString("000").TrimEnd("0")))
    }

    return $baseText
}

function Format-VhsMp4FilterTimeValue {
    param($Seconds)

    $duration = Convert-VhsMp4OptionalDouble -Value $Seconds
    if ($null -eq $duration -or $duration -lt 0) {
        return ""
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([Math]::Abs($duration - [Math]::Round($duration, 0, [System.MidpointRounding]::AwayFromZero)) -lt 0.0001) {
        return ([Math]::Round($duration, 0, [System.MidpointRounding]::AwayFromZero)).ToString($culture)
    }

    return $duration.ToString("0.###", $culture)
}

function Get-VhsMp4TrimWindow {
    param(
        [string]$TrimStart = "",
        [string]$TrimEnd = ""
    )

    $startSeconds = Convert-VhsMp4TimeTextToSeconds -Value $TrimStart
    $endSeconds = Convert-VhsMp4TimeTextToSeconds -Value $TrimEnd

    if ($null -ne $startSeconds -and $null -ne $endSeconds -and $endSeconds -le $startSeconds) {
        throw "Trim End mora biti posle Trim Start."
    }

    $durationSeconds = $null
    if ($null -ne $startSeconds -and $null -ne $endSeconds) {
        $durationSeconds = $endSeconds - $startSeconds
    }
    elseif ($null -eq $startSeconds -and $null -ne $endSeconds) {
        $durationSeconds = $endSeconds
    }

    $startText = if ($null -ne $startSeconds) { Format-VhsMp4FfmpegTime -Seconds $startSeconds } else { "" }
    $endText = if ($null -ne $endSeconds) { Format-VhsMp4FfmpegTime -Seconds $endSeconds } else { "" }
    $durationText = if ($null -ne $durationSeconds) { Format-VhsMp4FfmpegTime -Seconds $durationSeconds } else { "" }

    $summary = ""
    if ($startText -and $endText) {
        $summary = "$startText - $endText"
    }
    elseif ($startText) {
        $summary = "from $startText"
    }
    elseif ($endText) {
        $summary = "to $endText"
    }

    return [pscustomobject]@{
        StartSeconds = $startSeconds
        EndSeconds = $endSeconds
        DurationSeconds = $durationSeconds
        StartText = $startText
        EndText = $endText
        DurationText = $durationText
        Summary = $summary
    }
}

function Get-VhsMp4TrimSegments {
    param(
        [object[]]$TrimSegments
    )

    $segments = New-Object System.Collections.Generic.List[object]
    foreach ($segment in @($TrimSegments)) {
        if ($null -eq $segment) {
            continue
        }

        $startText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "StartText")
        if ([string]::IsNullOrWhiteSpace($startText)) {
            $startText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "TrimStart")
        }
        if ([string]::IsNullOrWhiteSpace($startText)) {
            $startText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "Start")
        }

        $endText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "EndText")
        if ([string]::IsNullOrWhiteSpace($endText)) {
            $endText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "TrimEnd")
        }
        if ([string]::IsNullOrWhiteSpace($endText)) {
            $endText = [string](Get-VhsMp4ObjectPropertyValue -Object $segment -Name "End")
        }

        if ([string]::IsNullOrWhiteSpace($startText) -and [string]::IsNullOrWhiteSpace($endText)) {
            continue
        }

        if ([string]::IsNullOrWhiteSpace($startText) -or [string]::IsNullOrWhiteSpace($endText)) {
            throw "Svaki multi-cut segment mora imati i Start i End."
        }

        $window = Get-VhsMp4TrimWindow -TrimStart $startText -TrimEnd $endText
        if ($null -eq $window.StartSeconds -or $null -eq $window.EndSeconds -or $null -eq $window.DurationSeconds -or $window.DurationSeconds -le 0) {
            throw "Svaki multi-cut segment mora imati i Start i End."
        }

        $segments.Add([pscustomobject]@{
            StartSeconds = $window.StartSeconds
            EndSeconds = $window.EndSeconds
            DurationSeconds = $window.DurationSeconds
            StartText = $window.StartText
            EndText = $window.EndText
            DurationText = $window.DurationText
            Summary = $window.Summary
        })
    }

    $orderedSegments = @($segments | Sort-Object StartSeconds, EndSeconds)
    for ($index = 1; $index -lt $orderedSegments.Count; $index++) {
        $previousSegment = $orderedSegments[$index - 1]
        $currentSegment = $orderedSegments[$index]
        if ([double]$currentSegment.StartSeconds -lt [double]$previousSegment.EndSeconds) {
            throw "Multi-cut segmenti ne smeju da se preklapaju."
        }
    }

    $totalDuration = 0.0
    foreach ($segment in $orderedSegments) {
        $totalDuration += [double]$segment.DurationSeconds
    }

    $summary = ""
    if ($orderedSegments.Count -eq 1) {
        $summary = [string]$orderedSegments[0].Summary
    }
    elseif ($orderedSegments.Count -gt 1) {
        $summary = ("{0} seg | {1}" -f $orderedSegments.Count, (($orderedSegments | ForEach-Object { $_.Summary }) -join " ; "))
    }

    return [pscustomobject]@{
        Count = $orderedSegments.Count
        Segments = $orderedSegments
        Summary = $summary
        TotalDurationSeconds = $totalDuration
    }
}

function Get-VhsMp4EffectiveTrimPlan {
    param(
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [object[]]$TrimSegments
    )

    $segments = Get-VhsMp4TrimSegments -TrimSegments $TrimSegments
    if ($segments.Count -gt 1) {
        return [pscustomobject]@{
            Mode = "multi"
            Segments = $segments.Segments
            Count = $segments.Count
            StartSeconds = $null
            EndSeconds = $null
            DurationSeconds = $segments.TotalDurationSeconds
            StartText = ""
            EndText = ""
            DurationText = Format-VhsMp4FfmpegTime -Seconds $segments.TotalDurationSeconds
            Summary = $segments.Summary
        }
    }

    if ($segments.Count -eq 1) {
        $segment = $segments.Segments[0]
        return [pscustomobject]@{
            Mode = "single"
            Segments = $segments.Segments
            Count = 1
            StartSeconds = $segment.StartSeconds
            EndSeconds = $segment.EndSeconds
            DurationSeconds = $segment.DurationSeconds
            StartText = $segment.StartText
            EndText = $segment.EndText
            DurationText = $segment.DurationText
            Summary = $segment.Summary
        }
    }

    $window = Get-VhsMp4TrimWindow -TrimStart $TrimStart -TrimEnd $TrimEnd
    return [pscustomobject]@{
        Mode = if ([string]::IsNullOrWhiteSpace($window.Summary)) { "none" } else { "single" }
        Segments = @()
        Count = if ([string]::IsNullOrWhiteSpace($window.Summary)) { 0 } else { 1 }
        StartSeconds = $window.StartSeconds
        EndSeconds = $window.EndSeconds
        DurationSeconds = $window.DurationSeconds
        StartText = $window.StartText
        EndText = $window.EndText
        DurationText = $window.DurationText
        Summary = $window.Summary
    }
}

function Get-VhsMp4CropState {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = $null
            SourceHeight = $null
            Summary = ""
        }
    }

    $sourceWidth = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SourceWidth")
    if ($null -eq $sourceWidth) {
        $sourceWidth = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Width")
    }
    $sourceHeight = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SourceHeight")
    if ($null -eq $sourceHeight) {
        $sourceHeight = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Height")
    }

    $existingMode = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Mode")
    if (-not [string]::IsNullOrWhiteSpace($existingMode)) {
        $left = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Left")
        $top = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Top")
        $right = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Right")
        $bottom = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Bottom")
        if ($existingMode -eq "None") {
            return [pscustomobject]@{
                Mode = "None"
                Left = 0
                Top = 0
                Right = 0
                Bottom = 0
                Width = $null
                Height = $null
                SourceWidth = $sourceWidth
                SourceHeight = $sourceHeight
                Summary = ""
            }
        }

        if ($null -eq $left -or $null -eq $top -or $null -eq $right -or $null -eq $bottom) {
            throw "Crop mora da sadrzi Left, Top, Right i Bottom vrednosti."
        }
        $cropWidth = [double]$sourceWidth - [double]$left - [double]$right
        $cropHeight = [double]$sourceHeight - [double]$top - [double]$bottom
        if ($cropWidth -le 0 -or $cropHeight -le 0) {
            throw "Crop vrednosti prelaze dimenzije izvora."
        }

        foreach ($value in @($left, $top, $right, $bottom)) {
            if ($value -lt 0) {
                throw "Crop vrednosti ne mogu biti negativne."
            }
            if ([Math]::Abs($value - [Math]::Round($value, 0, [System.MidpointRounding]::AwayFromZero)) -gt 0.0001) {
                throw "Crop vrednosti moraju biti cele vrednosti."
            }
        }

        if ($null -eq $sourceWidth -or $null -eq $sourceHeight) {
            throw "Crop zahteva SourceWidth i SourceHeight."
        }
        if ($sourceWidth -le 0 -or $sourceHeight -le 0) {
            throw "Crop zahteva validne SourceWidth i SourceHeight vrednosti."
        }

        $cropWidthInt = [int][Math]::Round($cropWidth, 0, [System.MidpointRounding]::AwayFromZero)
        $cropHeightInt = [int][Math]::Round($cropHeight, 0, [System.MidpointRounding]::AwayFromZero)
        $leftInt = [int][Math]::Round($left, 0, [System.MidpointRounding]::AwayFromZero)
        $topInt = [int][Math]::Round($top, 0, [System.MidpointRounding]::AwayFromZero)
        $rightInt = [int][Math]::Round($right, 0, [System.MidpointRounding]::AwayFromZero)
        $bottomInt = [int][Math]::Round($bottom, 0, [System.MidpointRounding]::AwayFromZero)

        return [pscustomobject]@{
            Mode = if ($existingMode -eq "Auto") { "Auto" } else { "Manual" }
            Left = $leftInt
            Top = $topInt
            Right = $rightInt
            Bottom = $bottomInt
            Width = $cropWidthInt
            Height = $cropHeightInt
            SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
            SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
            Summary = ("{0} crop: {1}x{2} @ {3},{4}" -f $existingMode, $cropWidthInt, $cropHeightInt, $leftInt, $topInt)
        }
    }

    $mode = "None"
    $left = $null
    $top = $null
    $right = $null
    $bottom = $null

    $candidateSets = @(
        @{
            Mode = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "ManualCropMode")
            Left = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "ManualCropLeft"
            Top = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "ManualCropTop"
            Right = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "ManualCropRight"
            Bottom = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "ManualCropBottom"
        }
        @{
            Mode = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "AutoCropMode")
            Left = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "AutoCropLeft"
            Top = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "AutoCropTop"
            Right = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "AutoCropRight"
            Bottom = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "AutoCropBottom"
        }
        @{
            Mode = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "CropMode")
            Left = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "CropLeft"
            Top = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "CropTop"
            Right = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "CropRight"
            Bottom = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "CropBottom"
        }
    )

    foreach ($candidate in $candidateSets) {
        $candidateMode = [string]$candidate.Mode
        $candidateLeft = Convert-VhsMp4OptionalDouble -Value $candidate.Left
        $candidateTop = Convert-VhsMp4OptionalDouble -Value $candidate.Top
        $candidateRight = Convert-VhsMp4OptionalDouble -Value $candidate.Right
        $candidateBottom = Convert-VhsMp4OptionalDouble -Value $candidate.Bottom

        $hasValues = ($null -ne $candidateLeft -and $candidateLeft -gt 0) -or
            ($null -ne $candidateTop -and $candidateTop -gt 0) -or
            ($null -ne $candidateRight -and $candidateRight -gt 0) -or
            ($null -ne $candidateBottom -and $candidateBottom -gt 0)

        if (-not [string]::IsNullOrWhiteSpace($candidateMode) -or $hasValues) {
            if (-not [string]::IsNullOrWhiteSpace($candidateMode) -and $candidateMode -ne "None") {
                $mode = $candidateMode
            }
            elseif ($hasValues) {
                $mode = "Manual"
            }

            $left = $candidateLeft
            $top = $candidateTop
            $right = $candidateRight
            $bottom = $candidateBottom
            break
        }
    }

    if ($mode -eq "None") {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = $sourceWidth
            SourceHeight = $sourceHeight
            Summary = ""
        }
    }

    if ($null -eq $left -or $null -eq $top -or $null -eq $right -or $null -eq $bottom) {
        throw "Crop mora da sadrzi Left, Top, Right i Bottom vrednosti."
    }

    foreach ($value in @($left, $top, $right, $bottom)) {
        if ($value -lt 0) {
            throw "Crop vrednosti ne mogu biti negativne."
        }
        if ([Math]::Abs($value - [Math]::Round($value, 0, [System.MidpointRounding]::AwayFromZero)) -gt 0.0001) {
            throw "Crop vrednosti moraju biti cele vrednosti."
        }
    }

    if ($null -eq $sourceWidth -or $null -eq $sourceHeight) {
        throw "Crop zahteva SourceWidth i SourceHeight."
    }
    if ($sourceWidth -le 0 -or $sourceHeight -le 0) {
        throw "Crop zahteva validne SourceWidth i SourceHeight vrednosti."
    }

    $cropWidth = [double]$sourceWidth - [double]$left - [double]$right
    $cropHeight = [double]$sourceHeight - [double]$top - [double]$bottom
    if ($cropWidth -le 0 -or $cropHeight -le 0) {
        throw "Crop vrednosti prelaze dimenzije izvora."
    }

    $cropWidthInt = [int][Math]::Round($cropWidth, 0, [System.MidpointRounding]::AwayFromZero)
    $cropHeightInt = [int][Math]::Round($cropHeight, 0, [System.MidpointRounding]::AwayFromZero)
    $leftInt = [int][Math]::Round($left, 0, [System.MidpointRounding]::AwayFromZero)
    $topInt = [int][Math]::Round($top, 0, [System.MidpointRounding]::AwayFromZero)
    $rightInt = [int][Math]::Round($right, 0, [System.MidpointRounding]::AwayFromZero)
    $bottomInt = [int][Math]::Round($bottom, 0, [System.MidpointRounding]::AwayFromZero)

    return [pscustomobject]@{
        Mode = if ($mode -eq "Auto") { "Auto" } else { "Manual" }
        Left = $leftInt
        Top = $topInt
        Right = $rightInt
        Bottom = $bottomInt
        Width = $cropWidthInt
        Height = $cropHeightInt
        SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
        SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
        Summary = ("{0} crop: {1}x{2} @ {3},{4}" -f $mode, $cropWidthInt, $cropHeightInt, $leftInt, $topInt)
    }
}

function Test-VhsMp4CropState {
    param(
        [AllowNull()]
        $CropState
    )

    try {
        $normalizedState = Get-VhsMp4CropState -InputObject $CropState
        return ($normalizedState.Mode -ne "None")
    }
    catch {
        return $false
    }
}

function Get-VhsMp4CropFilter {
    param(
        [AllowNull()]
        $CropState
    )

    if ($null -eq $CropState) {
        return ""
    }

    try {
        $normalizedState = Get-VhsMp4CropState -InputObject $CropState
    }
    catch {
        return ""
    }

    if ($normalizedState.Mode -eq "None") {
        return ""
    }

    return ("crop={0}:{1}:{2}:{3}" -f $normalizedState.Width, $normalizedState.Height, $normalizedState.Left, $normalizedState.Top)
}

function Get-VhsMp4CropDetectionSampleTimes {
    param(
        [Parameter(Mandatory = $true)]
        [double]$DurationSeconds,
        [ValidateRange(1, 99)]
        [int]$SampleCount = 5
    )

    if ($DurationSeconds -le 0 -or $SampleCount -lt 1) {
        return @()
    }

    $step = $DurationSeconds / ([double]$SampleCount + 1.0)
    $samples = for ($index = 1; $index -le $SampleCount; $index++) {
        $sampleTime = $step * $index
        if ([Math]::Abs($sampleTime - [Math]::Round($sampleTime, 0, [System.MidpointRounding]::AwayFromZero)) -lt 0.0001) {
            [int][Math]::Round($sampleTime, 0, [System.MidpointRounding]::AwayFromZero)
        }
        else {
            [Math]::Round($sampleTime, 3, [System.MidpointRounding]::AwayFromZero)
        }
    }

    return @($samples)
}

function Get-VhsMp4CropDetectionSample {
    param(
        [Parameter(Mandatory = $true)]
        $Sample
    )

    $left = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "Left")
    if ($null -eq $left) {
        $left = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "CropLeft")
    }

    $top = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "Top")
    if ($null -eq $top) {
        $top = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "CropTop")
    }

    $right = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "Right")
    if ($null -eq $right) {
        $right = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "CropRight")
    }

    $bottom = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "Bottom")
    if ($null -eq $bottom) {
        $bottom = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $Sample -Name "CropBottom")
    }

    if ($null -eq $left -or $null -eq $top -or $null -eq $right -or $null -eq $bottom) {
        return $null
    }

    foreach ($value in @($left, $top, $right, $bottom)) {
        if ($value -lt 0) {
            return $null
        }
        if ([Math]::Abs($value - [Math]::Round($value, 0, [System.MidpointRounding]::AwayFromZero)) -gt 0.0001) {
            return $null
        }
    }

    return [pscustomobject]@{
        Left = [int][Math]::Round($left, 0, [System.MidpointRounding]::AwayFromZero)
        Top = [int][Math]::Round($top, 0, [System.MidpointRounding]::AwayFromZero)
        Right = [int][Math]::Round($right, 0, [System.MidpointRounding]::AwayFromZero)
        Bottom = [int][Math]::Round($bottom, 0, [System.MidpointRounding]::AwayFromZero)
    }
}

function Get-VhsMp4DetectedCrop {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [ValidateRange(1, 99)]
        [int]$MinimumStableSampleCount = 3,
        [ValidateRange(0.5, 1.0)]
        [double]$MinimumAgreementRatio = 0.6
    )

    if ($null -eq $InputObject) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = $null
            SourceHeight = $null
            SampleCount = 0
            StableSampleCount = 0
            Summary = ""
        }
    }

    $sourceWidth = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SourceWidth")
    if ($null -eq $sourceWidth) {
        $sourceWidth = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Width")
    }
    $sourceHeight = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SourceHeight")
    if ($null -eq $sourceHeight) {
        $sourceHeight = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Height")
    }

    if ($null -eq $sourceWidth -or $null -eq $sourceHeight -or $sourceWidth -le 0 -or $sourceHeight -le 0) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = $sourceWidth
            SourceHeight = $sourceHeight
            SampleCount = 0
            StableSampleCount = 0
            Summary = ""
        }
    }

    $samples = @()
    foreach ($samplePropertyName in @("Samples", "CropSamples", "DetectionSamples")) {
        $candidateSamples = Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name $samplePropertyName
        if ($null -ne $candidateSamples) {
            $samples = @($candidateSamples)
            break
        }
    }

    $normalizedSamples = @()
    foreach ($sample in $samples) {
        $normalizedSample = Get-VhsMp4CropDetectionSample -Sample $sample
        if ($null -ne $normalizedSample) {
            $normalizedSamples += $normalizedSample
        }
    }

    $attemptedSampleCount = $samples.Count
    $validSampleCount = $normalizedSamples.Count
    $failedSampleCount = [Math]::Max(0, $attemptedSampleCount - $validSampleCount)

    if ($attemptedSampleCount -eq 0 -or $failedSampleCount -gt 0 -or $validSampleCount -lt $MinimumStableSampleCount) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
            SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
            SampleCount = $attemptedSampleCount
            ValidSampleCount = $validSampleCount
            FailedSampleCount = $failedSampleCount
            StableSampleCount = 0
            Summary = ""
        }
    }

    $sampleGroups = $normalizedSamples |
        Group-Object -Property { "{0}|{1}|{2}|{3}" -f $_.Left, $_.Top, $_.Right, $_.Bottom } |
        Sort-Object -Property @{ Expression = "Count"; Descending = $true }, @{ Expression = "Name"; Descending = $false }

    $bestGroup = $sampleGroups | Select-Object -First 1
    $bestCount = if ($null -ne $bestGroup) { [int]$bestGroup.Count } else { 0 }
    $bestKey = if ($null -ne $bestGroup) { [string]$bestGroup.Name } else { "" }

    $uniqueCounts = @($sampleGroups | Select-Object -ExpandProperty Count)
    $isTied = $false
    if ($uniqueCounts.Count -gt 1) {
        $isTied = ($uniqueCounts[0] -eq $uniqueCounts[1])
    }

    $agreementRatio = $bestCount / [double]$validSampleCount
    if ($bestCount -lt $MinimumStableSampleCount -or $agreementRatio -lt $MinimumAgreementRatio -or $isTied) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
            SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
            SampleCount = $attemptedSampleCount
            ValidSampleCount = $validSampleCount
            FailedSampleCount = $failedSampleCount
            StableSampleCount = $bestCount
            Summary = ""
        }
    }

    $bestParts = $bestKey.Split("|")
    $left = [int]$bestParts[0]
    $top = [int]$bestParts[1]
    $right = [int]$bestParts[2]
    $bottom = [int]$bestParts[3]
    $cropWidth = [double]$sourceWidth - [double]$left - [double]$right
    $cropHeight = [double]$sourceHeight - [double]$top - [double]$bottom

    if ($cropWidth -le 0 -or $cropHeight -le 0 -or ($left -eq 0 -and $top -eq 0 -and $right -eq 0 -and $bottom -eq 0)) {
        return [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Width = $null
            Height = $null
            SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
            SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
            SampleCount = $normalizedSamples.Count
            StableSampleCount = $bestCount
            Summary = ""
        }
    }

    $cropWidthInt = [int][Math]::Round($cropWidth, 0, [System.MidpointRounding]::AwayFromZero)
    $cropHeightInt = [int][Math]::Round($cropHeight, 0, [System.MidpointRounding]::AwayFromZero)

    return [pscustomobject]@{
        Mode = "Auto"
        Left = $left
        Top = $top
        Right = $right
        Bottom = $bottom
        Width = $cropWidthInt
        Height = $cropHeightInt
        SourceWidth = [int][Math]::Round($sourceWidth, 0, [System.MidpointRounding]::AwayFromZero)
        SourceHeight = [int][Math]::Round($sourceHeight, 0, [System.MidpointRounding]::AwayFromZero)
        SampleCount = $attemptedSampleCount
        ValidSampleCount = $validSampleCount
        FailedSampleCount = $failedSampleCount
        StableSampleCount = $bestCount
        Summary = ("Auto crop: {0}x{1} @ {2},{3}" -f $cropWidthInt, $cropHeightInt, $left, $top)
    }
}

function Get-VhsMp4CropDetectionSampleFromText {
    param(
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [int]$SourceWidth,
        [Parameter(Mandatory = $true)]
        [int]$SourceHeight
    )

    if ([string]::IsNullOrWhiteSpace($Text) -or $SourceWidth -le 0 -or $SourceHeight -le 0) {
        return $null
    }

    $matches = [System.Text.RegularExpressions.Regex]::Matches($Text, 'crop=(\d+):(\d+):(\d+):(\d+)')
    if ($matches.Count -lt 1) {
        return $null
    }

    $match = $matches[$matches.Count - 1]
    $width = [int]$match.Groups[1].Value
    $height = [int]$match.Groups[2].Value
    $left = [int]$match.Groups[3].Value
    $top = [int]$match.Groups[4].Value
    $right = $SourceWidth - $width - $left
    $bottom = $SourceHeight - $height - $top

    if ($width -le 0 -or $height -le 0 -or $left -lt 0 -or $top -lt 0 -or $right -lt 0 -or $bottom -lt 0) {
        return $null
    }

    return [pscustomobject]@{
        Left = $left
        Top = $top
        Right = $right
        Bottom = $bottom
    }
}

function Get-VhsMp4DetectedCropFromSourcePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [string]$FfmpegPath = "ffmpeg",
        [Parameter(Mandatory = $true)]
        [double]$DurationSeconds,
        [Parameter(Mandatory = $true)]
        [int]$SourceWidth,
        [Parameter(Mandatory = $true)]
        [int]$SourceHeight,
        [ValidateRange(1, 99)]
        [int]$SampleCount = 5
    )

    if (-not (Test-Path -LiteralPath $SourcePath) -or $DurationSeconds -le 0 -or $SourceWidth -le 0 -or $SourceHeight -le 0) {
        return (Get-VhsMp4DetectedCrop -InputObject ([pscustomobject]@{
                    SourceWidth = $SourceWidth
                    SourceHeight = $SourceHeight
                    Samples = @()
                }))
    }

    $sampleTimes = @(Get-VhsMp4CropDetectionSampleTimes -DurationSeconds $DurationSeconds -SampleCount $SampleCount)
    $samples = New-Object System.Collections.Generic.List[object]

    foreach ($sampleTime in $sampleTimes) {
        $sampleText = Format-VhsMp4FfmpegTime -Seconds $sampleTime
        if ([string]::IsNullOrWhiteSpace($sampleText)) {
            $sampleText = "00:00:00"
        }

        $arguments = @(
            "-hide_banner",
            "-y",
            "-ss", $sampleText,
            "-i", $SourcePath,
            "-map", "0:v:0",
            "-frames:v", "1",
            "-vf", "cropdetect=24:16:0",
            "-f", "null",
            "-"
        )

        $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $arguments
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdOut = $process.StandardOutput.ReadToEnd()
        $stdErr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $sample = Get-VhsMp4CropDetectionSampleFromText -Text ($stdErr + [Environment]::NewLine + $stdOut) -SourceWidth $SourceWidth -SourceHeight $SourceHeight
        if ($null -ne $sample) {
            [void]$samples.Add($sample)
        }
        else {
            [void]$samples.Add([pscustomobject]@{})
        }
    }

    $sampleArray = $samples.ToArray()
    return (Get-VhsMp4DetectedCrop -InputObject ([pscustomobject]@{
                SourceWidth = $SourceWidth
                SourceHeight = $SourceHeight
                Samples = $sampleArray
            }))
}

function New-VhsMp4MultiTrimFilterComplex {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TrimSegments,
        [string]$VideoFilterChain = "",
        [string]$AudioFilterChain = "",
        [bool]$SourceHasAudio = $true
    )

    if (@($TrimSegments).Count -lt 2) {
        return ""
    }

    $filterParts = New-Object System.Collections.Generic.List[string]
    $concatInputs = New-Object System.Collections.Generic.List[string]

    for ($index = 0; $index -lt $TrimSegments.Count; $index++) {
        $segment = $TrimSegments[$index]
        $startValue = Format-VhsMp4FilterTimeValue -Seconds $segment.StartSeconds
        $endValue = Format-VhsMp4FilterTimeValue -Seconds $segment.EndSeconds
        $videoLabel = "v$index"
        $videoChain = "[0:v]trim=start=${startValue}:end=${endValue},setpts=PTS-STARTPTS"
        if (-not [string]::IsNullOrWhiteSpace($VideoFilterChain)) {
            $videoChain += "," + $VideoFilterChain
        }
        $videoChain += "[$videoLabel]"
        $filterParts.Add($videoChain)
        $concatInputs.Add("[$videoLabel]")

        if ($SourceHasAudio) {
            $audioLabel = "a$index"
            $audioChain = "[0:a]atrim=start=${startValue}:end=${endValue},asetpts=PTS-STARTPTS"
            if (-not [string]::IsNullOrWhiteSpace($AudioFilterChain)) {
                $audioChain += "," + $AudioFilterChain
            }
            $audioChain += "[$audioLabel]"
            $filterParts.Add($audioChain)
            $concatInputs.Add("[$audioLabel]")
        }
    }

    if ($SourceHasAudio) {
        $filterParts.Add(($concatInputs -join "") + "concat=n=$($TrimSegments.Count):v=1:a=1[vout][aout]")
    }
    else {
        $filterParts.Add(($concatInputs -join "") + "concat=n=$($TrimSegments.Count):v=1:a=0[vout]")
    }

    return ($filterParts -join ";")
}

function Format-VhsMp4ByteSize {
    param($Bytes)

    $sizeBytes = Convert-VhsMp4OptionalDouble -Value $Bytes
    if ($null -eq $sizeBytes -or $sizeBytes -lt 0) {
        return "--"
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($sizeBytes -ge [Math]::Pow(1024, 3)) {
        return (($sizeBytes / [Math]::Pow(1024, 3)).ToString("0.00", $culture) + " GB")
    }
    if ($sizeBytes -ge [Math]::Pow(1024, 2)) {
        return (($sizeBytes / [Math]::Pow(1024, 2)).ToString("0.00", $culture) + " MB")
    }
    if ($sizeBytes -ge 1024) {
        return (($sizeBytes / 1024.0).ToString("0.00", $culture) + " KB")
    }

    return ([int64]$sizeBytes).ToString($culture) + " B"
}

function Format-VhsMp4KbpsText {
    param($Kbps)

    if ($null -eq $Kbps -or $Kbps -le 0) {
        return "--"
    }

    return "$Kbps kbps"
}

function Convert-VhsMp4RationalToDouble {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $text = [string]$Value
    if ($text -match "^([0-9.]+)[/:]([0-9.]+)$") {
        $numerator = Convert-VhsMp4OptionalDouble -Value $Matches[1]
        $denominator = Convert-VhsMp4OptionalDouble -Value $Matches[2]
        if ($null -ne $numerator -and $null -ne $denominator -and $denominator -ne 0) {
            return [Math]::Round($numerator / $denominator, 2)
        }
    }

    $number = Convert-VhsMp4OptionalDouble -Value $text
    if ($null -eq $number) {
        return $null
    }

    return [Math]::Round($number, 2)
}

function Convert-VhsMp4PreciseRationalToDouble {
    param($Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $text = [string]$Value
    if ($text -match "^([0-9.]+)[/:]([0-9.]+)$") {
        $numerator = Convert-VhsMp4OptionalDouble -Value $Matches[1]
        $denominator = Convert-VhsMp4OptionalDouble -Value $Matches[2]
        if ($null -ne $numerator -and $null -ne $denominator -and $denominator -ne 0) {
            return ($numerator / $denominator)
        }
    }

    return (Convert-VhsMp4OptionalDouble -Value $text)
}

function Format-VhsMp4FrameRateText {
    param($FrameRate)

    if ($null -eq $FrameRate -or $FrameRate -le 0) {
        return "--"
    }

    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([Math]::Abs($FrameRate - [Math]::Round($FrameRate)) -lt 0.01) {
        return ([Math]::Round($FrameRate).ToString($culture) + " fps")
    }

    return ($FrameRate.ToString("0.##", $culture) + " fps")
}

function Get-VhsMp4GreatestCommonDivisor {
    param(
        [int]$Left,
        [int]$Right
    )

    $a = [Math]::Abs($Left)
    $b = [Math]::Abs($Right)
    while ($b -ne 0) {
        $temporary = $b
        $b = $a % $b
        $a = $temporary
    }

    return [Math]::Max(1, $a)
}

function Get-VhsMp4NormalizedAspectMode {
    param(
        [string]$AspectMode = "Auto"
    )

    $text = [string]$AspectMode
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "Auto"
    }

    $normalized = $text.Trim().ToLowerInvariant()
    switch ($normalized) {
        "auto" { return "Auto" }
        "keeporiginal" { return "KeepOriginal" }
        "keep original" { return "KeepOriginal" }
        "keep-original" { return "KeepOriginal" }
        "force4x3" { return "Force4x3" }
        "force 4:3" { return "Force4x3" }
        "force 4x3" { return "Force4x3" }
        "force4:3" { return "Force4x3" }
        "force16x9" { return "Force16x9" }
        "force 16:9" { return "Force16x9" }
        "force 16x9" { return "Force16x9" }
        "force16:9" { return "Force16x9" }
        default { return "Auto" }
    }
}

function Get-VhsMp4AspectConfidence {
    param(
        [AllowNull()]
        $Confidence
    )

    if ($null -eq $Confidence) {
        return "Unknown"
    }

    $text = [string]$Confidence
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "Unknown"
    }

    switch ($text.Trim().ToLowerInvariant()) {
        "high" { return "High" }
        "medium" { return "Medium" }
        "low" { return "Low" }
        "unknown" { return "Unknown" }
        default { return "Unknown" }
    }
}

function Get-VhsMp4AspectRatioLabel {
    param(
        [double]$AspectRatio
    )

    if ($AspectRatio -le 0) {
        return $null
    }

    $fourThree = 4.0 / 3.0
    $sixteenNine = 16.0 / 9.0
    if ([Math]::Abs($AspectRatio - $fourThree) -le 0.03) {
        return "Force4x3"
    }
    if ([Math]::Abs($AspectRatio - $sixteenNine) -le 0.03) {
        return "Force16x9"
    }

    return $null
}

function Get-VhsMp4AspectRatioTextToLabel {
    param(
        [string]$AspectRatioText,
        [int]$Width = 0,
        [int]$Height = 0
    )

    if ([string]::IsNullOrWhiteSpace($AspectRatioText)) {
        return $null
    }

    $text = $AspectRatioText.Trim()
    $ratio = Convert-VhsMp4RationalToDouble -Value $text
    if ($null -eq $ratio) {
        return $null
    }

    return (Get-VhsMp4AspectRatioLabel -AspectRatio $ratio)
}

function Get-VhsMp4DetectedAspect {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return [pscustomobject]@{
            DetectedAspectMode = "KeepOriginal"
            DetectedAspectConfidence = "Unknown"
            DisplayAspectRatio = "--"
            SampleAspectRatio = "--"
            SourceWidth = $null
            SourceHeight = $null
            AspectSummary = ""
        }
    }

    $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "width")
    if ($null -eq $sourceWidth) {
        $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Width")
    }
    $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "height")
    if ($null -eq $sourceHeight) {
        $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Height")
    }

    $displayAspectRatio = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "display_aspect_ratio")
    if ([string]::IsNullOrWhiteSpace($displayAspectRatio)) {
        $displayAspectRatio = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "DisplayAspectRatio")
    }
    $sampleAspectRatio = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "sample_aspect_ratio")
    if ([string]::IsNullOrWhiteSpace($sampleAspectRatio)) {
        $sampleAspectRatio = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SampleAspectRatio")
    }

    $darLabel = Get-VhsMp4AspectRatioTextToLabel -AspectRatioText $displayAspectRatio
    $sarLabel = $null
    if ($sourceWidth -and $sourceHeight -and -not [string]::IsNullOrWhiteSpace($sampleAspectRatio)) {
        $sarValue = Convert-VhsMp4RationalToDouble -Value $sampleAspectRatio
        if ($null -ne $sarValue -and $sarValue -gt 0) {
            $effectiveRatio = ([double]$sourceWidth * [double]$sarValue) / [double]$sourceHeight
            $sarLabel = Get-VhsMp4AspectRatioLabel -AspectRatio $effectiveRatio
        }
    }

    $detectedAspectMode = "KeepOriginal"
    $confidence = "Unknown"
    if ($darLabel -and $sarLabel) {
        if ($darLabel -eq $sarLabel) {
            $detectedAspectMode = $darLabel
            $confidence = "High"
        }
        else {
            $detectedAspectMode = "KeepOriginal"
            $confidence = "Low"
        }
    }
    elseif ($darLabel) {
        $detectedAspectMode = $darLabel
        $confidence = "High"
    }
    elseif ($sarLabel) {
        $detectedAspectMode = $sarLabel
        $confidence = "High"
    }

    $summaryParts = @()
    if (-not [string]::IsNullOrWhiteSpace($displayAspectRatio)) {
        $summaryParts += "DAR=$displayAspectRatio"
    }
    if (-not [string]::IsNullOrWhiteSpace($sampleAspectRatio)) {
        $summaryParts += "SAR=$sampleAspectRatio"
    }
    $confidence = Get-VhsMp4AspectConfidence -Confidence $confidence

    return [pscustomobject]@{
        DetectedAspectMode = $detectedAspectMode
        DetectedAspectConfidence = $confidence
        DisplayAspectRatio = if ([string]::IsNullOrWhiteSpace($displayAspectRatio)) { "--" } else { $displayAspectRatio }
        SampleAspectRatio = if ([string]::IsNullOrWhiteSpace($sampleAspectRatio)) { "--" } else { $sampleAspectRatio }
        SourceWidth = $sourceWidth
        SourceHeight = $sourceHeight
        AspectSummary = (($summaryParts + @("Result=$detectedAspectMode", "Confidence=$confidence")) -join " | ")
    }
}

function Get-VhsMp4AspectState {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$AspectMode = "Auto"
    )

    $normalizedAspectMode = Get-VhsMp4NormalizedAspectMode -AspectMode $AspectMode
    $detectedAspect = Get-VhsMp4DetectedAspect -InputObject $InputObject

    return [pscustomobject]@{
        AspectMode = $normalizedAspectMode
        DetectedAspectMode = $detectedAspect.DetectedAspectMode
        DetectedAspectConfidence = $detectedAspect.DetectedAspectConfidence
        DetectedDisplayAspectRatio = $detectedAspect.DisplayAspectRatio
        DetectedSampleAspectRatio = $detectedAspect.SampleAspectRatio
        OutputAspectMode = if ($normalizedAspectMode -eq "Auto") { $detectedAspect.DetectedAspectMode } else { $normalizedAspectMode }
        AspectSummary = if ([string]::IsNullOrWhiteSpace([string]$detectedAspect.AspectSummary)) {
            $normalizedAspectMode
        }
        else {
            "$normalizedAspectMode | $($detectedAspect.AspectSummary)"
        }
    }
}

function Convert-VhsMp4EvenInt {
    param(
        [double]$Value
    )

    $rounded = [int][Math]::Round($Value, 0, [System.MidpointRounding]::AwayFromZero)
    if (($rounded % 2) -ne 0) {
        $rounded++
    }

    return [Math]::Max(2, $rounded)
}

function Get-VhsMp4AspectBaseGeometry {
    param(
        [int]$Width,
        [int]$Height
    )

    if ($Height -eq 576 -and $Width -in @(704, 720)) {
        return "PAL"
    }
    if ($Height -eq 480 -and $Width -in @(704, 720)) {
        return "NTSC"
    }

    return $null
}

function Get-VhsMp4CanonicalAspectDimensions {
    param(
        [int]$Width,
        [int]$Height,
        [string]$AspectLabel
    )

    $baseGeometry = Get-VhsMp4AspectBaseGeometry -Width $Width -Height $Height
    if ($baseGeometry -eq "PAL") {
        switch ($AspectLabel) {
            "Force4x3" { return [pscustomobject]@{ Width = 768; Height = 576 } }
            "Force16x9" { return [pscustomobject]@{ Width = 1024; Height = 576 } }
        }
    }
    elseif ($baseGeometry -eq "NTSC") {
        switch ($AspectLabel) {
            "Force4x3" { return [pscustomobject]@{ Width = 640; Height = 480 } }
            "Force16x9" { return [pscustomobject]@{ Width = 854; Height = 480 } }
        }
    }

    return $null
}

function Get-VhsMp4AspectPixelRatio {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [Parameter(Mandatory = $true)]
        [string]$OutputAspectMode,
        [int]$WorkingWidth,
        [int]$WorkingHeight
    )

    $displayAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "DisplayAspectRatio")
    if ([string]::IsNullOrWhiteSpace($displayAspectRatioText)) {
        $displayAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "display_aspect_ratio")
    }
    $sampleAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SampleAspectRatio")
    if ([string]::IsNullOrWhiteSpace($sampleAspectRatioText)) {
        $sampleAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "sample_aspect_ratio")
    }

    if ($OutputAspectMode -eq "KeepOriginal") {
        $sampleAspectRatio = Convert-VhsMp4PreciseRationalToDouble -Value $sampleAspectRatioText
        if ($null -ne $sampleAspectRatio -and $sampleAspectRatio -gt 0) {
            return $sampleAspectRatio
        }

        $displayAspectRatio = Convert-VhsMp4PreciseRationalToDouble -Value $displayAspectRatioText
        if ($null -ne $displayAspectRatio -and $displayAspectRatio -gt 0 -and $WorkingWidth -gt 0 -and $WorkingHeight -gt 0) {
            return (($displayAspectRatio * [double]$WorkingHeight) / [double]$WorkingWidth)
        }

        return 1.0
    }

    $baseGeometry = Get-VhsMp4AspectBaseGeometry -Width $WorkingWidth -Height $WorkingHeight
    if ($baseGeometry -eq "PAL") {
        if ($OutputAspectMode -eq "Force4x3") {
            return (16.0 / 15.0)
        }
        if ($OutputAspectMode -eq "Force16x9") {
            return (64.0 / 45.0)
        }
    }
    if ($baseGeometry -eq "NTSC") {
        if ($OutputAspectMode -eq "Force4x3") {
            return (8.0 / 9.0)
        }
        if ($OutputAspectMode -eq "Force16x9") {
            return (32.0 / 27.0)
        }
    }

    if ($OutputAspectMode -eq "Force4x3" -and $WorkingHeight -gt 0) {
        return ((4.0 / 3.0) * [double]$WorkingHeight / [double]$WorkingWidth)
    }
    if ($OutputAspectMode -eq "Force16x9" -and $WorkingHeight -gt 0) {
        return ((16.0 / 9.0) * [double]$WorkingHeight / [double]$WorkingWidth)
    }

    return 1.0
}

function Get-VhsMp4GeometryAspectLabel {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [Parameter(Mandatory = $true)]
        [string]$OutputAspectMode
    )

    if ($OutputAspectMode -in @("Force4x3", "Force16x9")) {
        return $OutputAspectMode
    }

    if ($OutputAspectMode -eq "KeepOriginal") {
        $detectedAspect = Get-VhsMp4DetectedAspect -InputObject $InputObject
        if ($detectedAspect.DetectedAspectMode -eq "KeepOriginal" -and $detectedAspect.DetectedAspectConfidence -in @("Low", "Unknown")) {
            return $null
        }

        $displayAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "DisplayAspectRatio")
        if ([string]::IsNullOrWhiteSpace($displayAspectRatioText)) {
            $displayAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "display_aspect_ratio")
        }
        $sampleAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "SampleAspectRatio")
        if ([string]::IsNullOrWhiteSpace($sampleAspectRatioText)) {
            $sampleAspectRatioText = [string](Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "sample_aspect_ratio")
        }

        $darLabel = Get-VhsMp4AspectRatioTextToLabel -AspectRatioText $displayAspectRatioText
        if ($darLabel) {
            return $darLabel
        }

        $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Width")
        if ($null -eq $sourceWidth) {
            $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "width")
        }
        $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Height")
        if ($null -eq $sourceHeight) {
            $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "height")
        }

        if ($sourceWidth -and $sourceHeight -and -not [string]::IsNullOrWhiteSpace($sampleAspectRatioText)) {
            $sarValue = Convert-VhsMp4PreciseRationalToDouble -Value $sampleAspectRatioText
            if ($null -ne $sarValue -and $sarValue -gt 0) {
                return (Get-VhsMp4AspectRatioLabel -AspectRatio (([double]$sourceWidth * $sarValue) / [double]$sourceHeight))
            }
        }
    }

    return $null
}

function Get-VhsMp4AspectTargetGeometry {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$AspectMode = "Auto",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [object]$CropState
    )

    $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Width")
    if ($null -eq $sourceWidth) {
        $sourceWidth = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "width")
    }
    $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "Height")
    if ($null -eq $sourceHeight) {
        $sourceHeight = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $InputObject -Name "height")
    }

    $cropWidth = $sourceWidth
    $cropHeight = $sourceHeight
    $cropFilter = Get-VhsMp4CropFilter -CropState $CropState
    if (-not [string]::IsNullOrWhiteSpace($cropFilter)) {
        $resolvedCropState = Get-VhsMp4CropState -InputObject $CropState
        $cropWidth = [int]$resolvedCropState.Width
        $cropHeight = [int]$resolvedCropState.Height
    }

    $workingWidth = [int]$cropWidth
    $workingHeight = [int]$cropHeight
    $isQuarterTurn = $RotateFlip -in @("90 CW", "90 CCW")
    if ($isQuarterTurn) {
        $workingWidth = [int]$cropHeight
        $workingHeight = [int]$cropWidth
    }

    $aspectState = Get-VhsMp4AspectState -InputObject $InputObject -AspectMode $AspectMode
    $outputAspectMode = [string]$aspectState.OutputAspectMode
    $isConservativeKeepOriginal = ($outputAspectMode -eq "KeepOriginal" -and $aspectState.DetectedAspectMode -eq "KeepOriginal" -and $aspectState.DetectedAspectConfidence -in @("Low", "Unknown"))
    $geometryAspectLabel = Get-VhsMp4GeometryAspectLabel -InputObject $InputObject -OutputAspectMode $outputAspectMode
    $canonicalGeometry = if ($geometryAspectLabel) { Get-VhsMp4CanonicalAspectDimensions -Width $cropWidth -Height $cropHeight -AspectLabel $geometryAspectLabel } else { $null }

    $pixelAspectRatio = 1.0
    $displayWidth = [Math]::Max(2, [int]$cropWidth)
    $displayHeight = [Math]::Max(2, [int]$cropHeight)
    if ($isConservativeKeepOriginal) {
        $pixelAspectRatio = 1.0
    }
    elseif ($canonicalGeometry) {
        $displayWidth = [int]$canonicalGeometry.Width
        $displayHeight = [int]$canonicalGeometry.Height
        $pixelAspectRatio = [double]$displayWidth / [double]$cropWidth
    }
    else {
        $pixelAspectRatio = Get-VhsMp4AspectPixelRatio -InputObject $InputObject -OutputAspectMode $outputAspectMode -WorkingWidth $cropWidth -WorkingHeight $cropHeight
        if ($null -eq $pixelAspectRatio -or $pixelAspectRatio -le 0) {
            $pixelAspectRatio = 1.0
        }

        $displayWidth = Convert-VhsMp4EvenInt -Value ([double]$cropWidth * $pixelAspectRatio)
    }
    if ($isQuarterTurn) {
        $displayWidth, $displayHeight = $displayHeight, $displayWidth
    }

    $scaledWidth = $displayWidth
    $scaledHeight = $displayHeight
    switch ($ScaleMode) {
        "PAL 576p" {
            $scaledHeight = 576
            $scaledWidth = Convert-VhsMp4EvenInt -Value ([double]$displayWidth * 576.0 / [double]$displayHeight)
        }
        "720p" {
            $scaledHeight = 720
            $scaledWidth = Convert-VhsMp4EvenInt -Value ([double]$displayWidth * 720.0 / [double]$displayHeight)
        }
        "1080p" {
            $scaledHeight = 1080
            $scaledWidth = Convert-VhsMp4EvenInt -Value ([double]$displayWidth * 1080.0 / [double]$displayHeight)
        }
    }

    return [pscustomobject]@{
        WorkingWidth = $workingWidth
        WorkingHeight = $workingHeight
        OutputAspectMode = $outputAspectMode
        PixelAspectRatio = $pixelAspectRatio
        DisplayWidth = $displayWidth
        DisplayHeight = $displayHeight
        OutputWidth = $scaledWidth
        OutputHeight = $scaledHeight
        RequiresAspectCorrection = ($displayWidth -ne $workingWidth -or $displayHeight -ne $workingHeight)
        RequiresScale = ($scaledWidth -ne $workingWidth -or $scaledHeight -ne $workingHeight)
    }
}

function Get-VhsMp4AspectAwareScaleFilter {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$AspectMode = "Auto",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [object]$CropState
    )

    $geometry = Get-VhsMp4AspectTargetGeometry -InputObject $InputObject -AspectMode $AspectMode -RotateFlip $RotateFlip -ScaleMode $ScaleMode -CropState $CropState
    if (-not $geometry.RequiresScale) {
        return ""
    }

    return ("scale={0}:{1}:flags=lanczos" -f $geometry.OutputWidth, $geometry.OutputHeight)
}

function Get-VhsMp4AspectSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$AspectMode = "Auto",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [object]$CropState
    )

    $aspectState = Get-VhsMp4AspectState -InputObject $InputObject -AspectMode $AspectMode
    $geometry = Get-VhsMp4AspectTargetGeometry -InputObject $InputObject -AspectMode $AspectMode -RotateFlip $RotateFlip -ScaleMode $ScaleMode -CropState $CropState

    return [pscustomobject]@{
        AspectMode = $aspectState.AspectMode
        DetectedAspectMode = $aspectState.DetectedAspectMode
        DetectedAspectConfidence = $aspectState.DetectedAspectConfidence
        DetectedDisplayAspectRatio = $aspectState.DetectedDisplayAspectRatio
        DetectedSampleAspectRatio = $aspectState.DetectedSampleAspectRatio
        OutputAspectMode = $aspectState.OutputAspectMode
        AspectSummary = $aspectState.AspectSummary
        OutputAspectWidth = $geometry.OutputWidth
        OutputAspectHeight = $geometry.OutputHeight
    }
}

function Add-VhsMp4AspectSnapshotToObject {
    param(
        [Parameter(Mandatory = $true)]
        $TargetObject,
        [Parameter(Mandatory = $true)]
        $InputObject,
        [string]$AspectMode = "Auto",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [object]$CropState
    )

    $aspectSnapshot = Get-VhsMp4AspectSnapshot -InputObject $InputObject -AspectMode $AspectMode -RotateFlip $RotateFlip -ScaleMode $ScaleMode -CropState $CropState
    foreach ($property in $aspectSnapshot.PSObject.Properties) {
        $TargetObject | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
    }

    return $TargetObject
}

function Get-VhsMp4DisplayAspectRatio {
    param(
        $VideoStream,
        [int]$Width,
        [int]$Height
    )

    $displayAspectRatio = Get-VhsMp4ObjectPropertyValue -Object $VideoStream -Name "display_aspect_ratio"
    if (-not [string]::IsNullOrWhiteSpace([string]$displayAspectRatio) -and [string]$displayAspectRatio -ne "0:1") {
        return [string]$displayAspectRatio
    }

    if ($Width -gt 0 -and $Height -gt 0) {
        $gcd = Get-VhsMp4GreatestCommonDivisor -Left $Width -Right $Height
        return ("{0}:{1}" -f ($Width / $gcd), ($Height / $gcd))
    }

    return "--"
}

function Get-VhsMp4MediaInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    $json = Invoke-VhsMp4Ffprobe `
        -SourcePath $SourcePath `
        -FfmpegPath $FfmpegPath `
        -FfprobeArguments @("-v", "error", "-show_format", "-show_streams", "-of", "json")

    $data = $json | ConvertFrom-Json
    $format = Get-VhsMp4ObjectPropertyValue -Object $data -Name "format"
    $streams = @(Get-VhsMp4ObjectPropertyValue -Object $data -Name "streams")
    $videoStream = $streams | Where-Object { (Get-VhsMp4ObjectPropertyValue -Object $_ -Name "codec_type") -eq "video" } | Select-Object -First 1
    $audioStream = $streams | Where-Object { (Get-VhsMp4ObjectPropertyValue -Object $_ -Name "codec_type") -eq "audio" } | Select-Object -First 1

    $durationSeconds = Convert-VhsMp4OptionalDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $format -Name "duration")
    $sizeBytes = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $format -Name "size")
    $overallBitrateKbps = Convert-VhsMp4BitsPerSecondToKbps -Value (Get-VhsMp4ObjectPropertyValue -Object $format -Name "bit_rate")

    $width = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "width")
    $height = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "height")
    $resolution = if ($width -and $height) { "$($width)x$($height)" } else { "--" }
    $widthForAspect = 0
    $heightForAspect = 0
    if ($null -ne $width) { $widthForAspect = [int]$width }
    if ($null -ne $height) { $heightForAspect = [int]$height }
    $displayAspectRatio = Get-VhsMp4DisplayAspectRatio -VideoStream $videoStream -Width $widthForAspect -Height $heightForAspect
    $frameRate = Convert-VhsMp4RationalToDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "avg_frame_rate")
    if ($null -eq $frameRate -or $frameRate -le 0) {
        $frameRate = Convert-VhsMp4RationalToDouble -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "r_frame_rate")
    }

    $frameCount = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "nb_frames")
    $videoBitrateKbps = Convert-VhsMp4BitsPerSecondToKbps -Value (Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "bit_rate")
    $audioBitrateKbps = Convert-VhsMp4BitsPerSecondToKbps -Value (Get-VhsMp4ObjectPropertyValue -Object $audioStream -Name "bit_rate")
    $audioChannels = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $audioStream -Name "channels")
    $audioSampleRateHz = Convert-VhsMp4OptionalInt64 -Value (Get-VhsMp4ObjectPropertyValue -Object $audioStream -Name "sample_rate")
    $videoCodec = [string](Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "codec_name")
    $audioCodec = [string](Get-VhsMp4ObjectPropertyValue -Object $audioStream -Name "codec_name")

    $videoSummaryParts = @($videoCodec, $resolution, $displayAspectRatio, (Format-VhsMp4FrameRateText -FrameRate $frameRate)) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) -and [string]$_ -ne "--" }
    $audioSummaryParts = @($audioCodec)
    if ($audioChannels) { $audioSummaryParts += "$audioChannels ch" }
    if ($audioSampleRateHz) { $audioSummaryParts += "$audioSampleRateHz Hz" }
    $audioBitrateText = Format-VhsMp4KbpsText -Kbps $audioBitrateKbps
    if ($audioBitrateText -ne "--") { $audioSummaryParts += $audioBitrateText }

    $mediaInfo = [pscustomobject]@{
        SourceName = [System.IO.Path]::GetFileName($SourcePath)
        SourcePath = [System.IO.Path]::GetFullPath($SourcePath)
        Container = [string](Get-VhsMp4ObjectPropertyValue -Object $format -Name "format_name")
        ContainerLongName = [string](Get-VhsMp4ObjectPropertyValue -Object $format -Name "format_long_name")
        DurationSeconds = $durationSeconds
        DurationText = Format-VhsMp4DurationText -Seconds $durationSeconds
        SizeBytes = $sizeBytes
        SizeText = Format-VhsMp4ByteSize -Bytes $sizeBytes
        OverallBitrateKbps = $overallBitrateKbps
        OverallBitrateText = Format-VhsMp4KbpsText -Kbps $overallBitrateKbps
        VideoCodec = $videoCodec
        VideoCodecLongName = [string](Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "codec_long_name")
        Width = $width
        Height = $height
        Resolution = $resolution
        DisplayAspectRatio = $displayAspectRatio
        SampleAspectRatio = [string](Get-VhsMp4ObjectPropertyValue -Object $videoStream -Name "sample_aspect_ratio")
        FrameRate = $frameRate
        FrameRateText = Format-VhsMp4FrameRateText -FrameRate $frameRate
        FrameCount = $frameCount
        VideoBitrateKbps = $videoBitrateKbps
        VideoBitrateText = Format-VhsMp4KbpsText -Kbps $videoBitrateKbps
        AudioCodec = $audioCodec
        AudioChannels = $audioChannels
        AudioChannelLayout = [string](Get-VhsMp4ObjectPropertyValue -Object $audioStream -Name "channel_layout")
        AudioSampleRateHz = $audioSampleRateHz
        AudioBitrateKbps = $audioBitrateKbps
        AudioBitrateText = $audioBitrateText
        VideoSummary = ($videoSummaryParts -join " | ")
        AudioSummary = ($audioSummaryParts -join " | ")
    }

    return (Add-VhsMp4AspectSnapshotToObject -TargetObject $mediaInfo -InputObject $mediaInfo)
}

function Get-VhsMp4MediaDurationSeconds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    $stdout = Invoke-VhsMp4Ffprobe `
        -SourcePath $SourcePath `
        -FfmpegPath $FfmpegPath `
        -FfprobeArguments @("-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1")

    $duration = 0.0
    $style = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ([double]::TryParse($stdout.Trim(), $style, $culture, [ref]$duration) -and $duration -gt 0) {
        return $duration
    }

    return $null
}

function Resolve-VhsMp4InputDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir
    )

    try {
        return (Resolve-Path -LiteralPath $InputDir).Path
    }
    catch {
        throw "Ulazni folder ne postoji: $InputDir"
    }
}

function Resolve-VhsMp4OutputDir {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir,
        [string]$OutputDir
    )

    if ([string]::IsNullOrWhiteSpace($OutputDir)) {
        return (Join-Path $InputDir "vhs-mp4-output")
    }

    return [System.IO.Path]::GetFullPath($OutputDir)
}

function Assert-VhsMp4FfmpegPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    try {
        return (Resolve-VhsMp4CommandPath -CommandPath $FfmpegPath)
    }
    catch {
        throw "FFmpeg nije pronadjen: $FfmpegPath"
    }
}

function Test-VhsMp4FfmpegPreflight {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    try {
        $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments @("-version")
        $startInfo.WorkingDirectory = [System.IO.Path]::GetTempPath()

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            return [pscustomobject]@{
                Ready = $false
                ExitCode = $process.ExitCode
                Message = "FFmpeg preflight exit code: $($process.ExitCode) | $stderr"
                StdOut = $stdout
                StdErr = $stderr
            }
        }

        return [pscustomobject]@{
            Ready = $true
            ExitCode = 0
            Message = "FFmpeg preflight OK"
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    catch {
        return [pscustomobject]@{
            Ready = $false
            ExitCode = $null
            Message = "FFmpeg preflight nije uspeo: " + (Get-VhsMp4ErrorMessage -ErrorObject $_)
            StdOut = ""
            StdErr = ""
        }
    }
}

function Get-VhsMp4NormalizedEncoderMode {
    param(
        [string]$EncoderMode = "Auto"
    )

    $text = [string]$EncoderMode
    if ([string]::IsNullOrWhiteSpace($text)) {
        return "Auto"
    }

    $normalized = $text.Trim().ToLowerInvariant()
    switch ($normalized) {
        "auto" { return "Auto" }
        "cpu" { return "CPU" }
        "cpu (libx264/libx265)" { return "CPU" }
        "nvidia" { return "NVIDIA NVENC" }
        "nvidia nvenc" { return "NVIDIA NVENC" }
        "intel" { return "Intel QSV" }
        "intel qsv" { return "Intel QSV" }
        "intel quick sync" { return "Intel QSV" }
        "amd" { return "AMD AMF" }
        "amd amf" { return "AMD AMF" }
        default { return "Auto" }
    }
}

function Get-VhsMp4EncoderInventoryFromText {
    param(
        [string]$EncodersText
    )

    $encoderMap = @{}
    foreach ($line in (([string]$EncodersText) -split "\r?\n")) {
        $match = [regex]::Match([string]$line, '^\s*\S{6}\s+([A-Za-z0-9_]+)\s+')
        if ($match.Success) {
            $encoderMap[$match.Groups[1].Value.ToLowerInvariant()] = $true
        }
    }

    $advertisedModeMap = [ordered]@{
        "CPU" = $true
        "NVIDIA NVENC" = ($encoderMap.ContainsKey("h264_nvenc") -or $encoderMap.ContainsKey("hevc_nvenc"))
        "Intel QSV" = ($encoderMap.ContainsKey("h264_qsv") -or $encoderMap.ContainsKey("hevc_qsv"))
        "AMD AMF" = ($encoderMap.ContainsKey("h264_amf") -or $encoderMap.ContainsKey("hevc_amf"))
    }
    $runtimeReadyModeMap = [ordered]@{
        "CPU" = $true
        "NVIDIA NVENC" = [bool]$advertisedModeMap["NVIDIA NVENC"]
        "Intel QSV" = [bool]$advertisedModeMap["Intel QSV"]
        "AMD AMF" = [bool]$advertisedModeMap["AMD AMF"]
    }

    $availableModes = New-Object System.Collections.Generic.List[string]
    $runtimeReadyModes = New-Object System.Collections.Generic.List[string]
    foreach ($modeName in $advertisedModeMap.Keys) {
        if ([bool]$advertisedModeMap[$modeName]) {
            $availableModes.Add($modeName)
        }
        if ([bool]$runtimeReadyModeMap[$modeName]) {
            $runtimeReadyModes.Add($modeName)
        }
    }

    return [pscustomobject]@{
        EncoderNames = @($encoderMap.Keys | Sort-Object)
        HasLibx264 = $encoderMap.ContainsKey("libx264")
        HasLibx265 = $encoderMap.ContainsKey("libx265")
        HasH264Nvenc = $encoderMap.ContainsKey("h264_nvenc")
        HasHevcNvenc = $encoderMap.ContainsKey("hevc_nvenc")
        HasH264Qsv = $encoderMap.ContainsKey("h264_qsv")
        HasHevcQsv = $encoderMap.ContainsKey("hevc_qsv")
        HasH264Amf = $encoderMap.ContainsKey("h264_amf")
        HasHevcAmf = $encoderMap.ContainsKey("hevc_amf")
        AdvertisedModeMap = $advertisedModeMap
        RuntimeReadyModeMap = $runtimeReadyModeMap
        AvailableModes = @($availableModes.ToArray())
        RuntimeReadyModes = @($runtimeReadyModes.ToArray())
        RuntimeNotes = @()
        Summary = (($runtimeReadyModes.ToArray()) -join " | ")
    }
}

function Test-VhsMp4EncoderRuntime {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("NVIDIA NVENC", "Intel QSV", "AMD AMF")]
        [string]$ModeName
    )

    $encoderName = switch ($ModeName) {
        "NVIDIA NVENC" { "h264_nvenc" }
        "Intel QSV" { "h264_qsv" }
        "AMD AMF" { "h264_amf" }
    }

    $probeArgs = @(
        "-hide_banner",
        "-f", "lavfi",
        "-i", "color=c=black:s=640x480:d=0.12",
        "-frames:v", "3",
        "-c:v", $encoderName
    )

    switch ($ModeName) {
        "NVIDIA NVENC" {
            $probeArgs += @("-preset", "p5", "-tune", "hq", "-rc", "vbr", "-cq", "22", "-b:v", "0", "-multipass", "fullres")
        }
        "Intel QSV" {
            $probeArgs += @("-preset", "slow", "-global_quality", "22", "-look_ahead", "0")
        }
        "AMD AMF" {
            $probeArgs += @("-quality", "quality", "-rc", "qvbr", "-qvbr_quality_level", "22")
        }
    }

    $probeArgs += @("-f", "null", "-")

    try {
        $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $probeArgs
        $startInfo.WorkingDirectory = [System.IO.Path]::GetTempPath()
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -eq 0) {
            return [pscustomobject]@{
                Ready = $true
                ExitCode = 0
                Message = "$ModeName ready"
                StdOut = $stdout
                StdErr = $stderr
            }
        }

        $message = if (-not [string]::IsNullOrWhiteSpace($stderr)) { $stderr.Trim() } elseif (-not [string]::IsNullOrWhiteSpace($stdout)) { $stdout.Trim() } else { "$ModeName init failed" }
        return [pscustomobject]@{
            Ready = $false
            ExitCode = $process.ExitCode
            Message = $message
            StdOut = $stdout
            StdErr = $stderr
        }
    }
    catch {
        return [pscustomobject]@{
            Ready = $false
            ExitCode = $null
            Message = Get-VhsMp4ErrorMessage -ErrorObject $_
            StdOut = ""
            StdErr = ""
        }
    }
}

function Get-VhsMp4EncoderInventory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath
    )

    $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments @("-hide_banner", "-encoders")
    $startInfo.WorkingDirectory = [System.IO.Path]::GetTempPath()

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        throw "FFmpeg encoder inventory nije dostupan (exit code: $($process.ExitCode)) | $stderr"
    }

    $inventory = Get-VhsMp4EncoderInventoryFromText -EncodersText ($stdout + [Environment]::NewLine + $stderr)
    $runtimeReadyModeMap = [ordered]@{
        "CPU" = $true
        "NVIDIA NVENC" = $false
        "Intel QSV" = $false
        "AMD AMF" = $false
    }
    $runtimeNotes = New-Object System.Collections.Generic.List[string]

    foreach ($modeName in @("NVIDIA NVENC", "Intel QSV", "AMD AMF")) {
        if (-not [bool]$inventory.AdvertisedModeMap[$modeName]) {
            continue
        }

        $runtimeCheck = Test-VhsMp4EncoderRuntime -FfmpegPath $FfmpegPath -ModeName $modeName
        $runtimeReadyModeMap[$modeName] = [bool]$runtimeCheck.Ready
        if (-not $runtimeCheck.Ready) {
            $runtimeNotes.Add(($modeName + ": init failed"))
        }
    }

    $availableModes = New-Object System.Collections.Generic.List[string]
    $runtimeReadyModes = New-Object System.Collections.Generic.List[string]
    $summaryParts = New-Object System.Collections.Generic.List[string]

    foreach ($modeName in @("CPU", "NVIDIA NVENC", "Intel QSV", "AMD AMF")) {
        if ([bool]$inventory.AdvertisedModeMap[$modeName]) {
            $availableModes.Add($modeName)
        }
        if ([bool]$runtimeReadyModeMap[$modeName]) {
            $runtimeReadyModes.Add($modeName)
            $summaryParts.Add($modeName)
        }
        elseif ([bool]$inventory.AdvertisedModeMap[$modeName]) {
            $summaryParts.Add($modeName + ": init failed")
        }
    }

    return [pscustomobject]@{
        EncoderNames = $inventory.EncoderNames
        HasLibx264 = [bool]$inventory.HasLibx264
        HasLibx265 = [bool]$inventory.HasLibx265
        HasH264Nvenc = [bool]$inventory.HasH264Nvenc
        HasHevcNvenc = [bool]$inventory.HasHevcNvenc
        HasH264Qsv = [bool]$inventory.HasH264Qsv
        HasHevcQsv = [bool]$inventory.HasHevcQsv
        HasH264Amf = [bool]$inventory.HasH264Amf
        HasHevcAmf = [bool]$inventory.HasHevcAmf
        AdvertisedModeMap = $inventory.AdvertisedModeMap
        RuntimeReadyModeMap = $runtimeReadyModeMap
        AvailableModes = @($availableModes.ToArray())
        RuntimeReadyModes = @($runtimeReadyModes.ToArray())
        RuntimeNotes = @($runtimeNotes.ToArray())
        Summary = (($summaryParts.ToArray()) -join " | ")
    }
}

function Get-VhsMp4NvencPreset {
    param(
        [string]$Preset = "slow"
    )

    switch ([string]$Preset) {
        "ultrafast" { return "p1" }
        "superfast" { return "p1" }
        "veryfast" { return "p2" }
        "faster" { return "p3" }
        "fast" { return "p4" }
        "medium" { return "p4" }
        "slow" { return "p5" }
        "slower" { return "p6" }
        "veryslow" { return "p7" }
        default { return "p5" }
    }
}

function Get-VhsMp4QsvPreset {
    param(
        [string]$Preset = "slow"
    )

    switch ([string]$Preset) {
        "ultrafast" { return "veryfast" }
        "superfast" { return "veryfast" }
        default { return $Preset }
    }
}

function Get-VhsMp4AmfPreset {
    param(
        [string]$Preset = "slow"
    )

    switch ([string]$Preset) {
        { $_ -in @("ultrafast", "superfast", "veryfast", "faster", "fast") } { return "speed" }
        "medium" { return "balanced" }
        default { return "quality" }
    }
}

function Resolve-VhsMp4VideoEncoderPlan {
    param(
        [Parameter(Mandatory = $true)]
        [object]$QualityProfile,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory,
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = ""
    )

    $normalizedMode = Get-VhsMp4NormalizedEncoderMode -EncoderMode $EncoderMode
    $codecFamily = [string](Get-VhsMp4ObjectPropertyValue -Object $QualityProfile -Name "CodecFamily")
    if ([string]::IsNullOrWhiteSpace($codecFamily)) {
        $codecFamily = if ([string]$QualityProfile.VideoCodec -like "libx265") { "hevc" } else { "h264" }
    }
    $videoBitrateProvided = -not [string]::IsNullOrWhiteSpace([string]$VideoBitrate)
    $videoBitrateKbps = if ($videoBitrateProvided) { Convert-VhsMp4BitrateToKbps -Bitrate $VideoBitrate } else { 0 }
    $videoBufferSize = if ($videoBitrateProvided) { "$($videoBitrateKbps * 2)k" } else { "" }
    $cpuVideoArguments = if ($videoBitrateProvided) {
        @(
            "-preset", [string]$QualityProfile.Preset,
            "-b:v", [string]$VideoBitrate,
            "-maxrate", [string]$VideoBitrate,
            "-bufsize", $videoBufferSize,
            "-pix_fmt", "yuv420p"
        )
    }
    else {
        @("-preset", [string]$QualityProfile.Preset, "-crf", "$([int]$QualityProfile.Crf)", "-pix_fmt", "yuv420p")
    }

    $cpuPlan = [pscustomobject]@{
        RequestedMode = $normalizedMode
        ResolvedMode = "CPU"
        VideoCodec = [string]$QualityProfile.VideoCodec
        VideoTag = [string]$QualityProfile.VideoTag
        VideoArguments = $cpuVideoArguments
        Summary = if ($videoBitrateProvided) { "Encode engine: CPU | target bitrate $VideoBitrate" } else { "Encode engine: CPU" }
        FallbackUsed = ($normalizedMode -notin @("Auto", "CPU"))
    }

    if ($normalizedMode -in @("Auto", "CPU")) {
        return $cpuPlan
    }

    $canUseRequestedMode = $false
    $runtimeReady = $true
    if ($null -ne $EncoderInventory) {
        switch ($normalizedMode) {
            "NVIDIA NVENC" {
                $canUseRequestedMode = if ($codecFamily -eq "hevc") { [bool]$EncoderInventory.HasHevcNvenc } else { [bool]$EncoderInventory.HasH264Nvenc }
            }
            "Intel QSV" {
                $canUseRequestedMode = if ($codecFamily -eq "hevc") { [bool]$EncoderInventory.HasHevcQsv } else { [bool]$EncoderInventory.HasH264Qsv }
            }
            "AMD AMF" {
                $canUseRequestedMode = if ($codecFamily -eq "hevc") { [bool]$EncoderInventory.HasHevcAmf } else { [bool]$EncoderInventory.HasH264Amf }
            }
        }

        $runtimeReadyMap = Get-VhsMp4ObjectPropertyValue -Object $EncoderInventory -Name "RuntimeReadyModeMap"
        if ($null -ne $runtimeReadyMap -and $runtimeReadyMap.Contains($normalizedMode)) {
            $runtimeReady = [bool]$runtimeReadyMap[$normalizedMode]
        }
    }

    if (-not $canUseRequestedMode -or -not $runtimeReady) {
        $cpuPlan.Summary = if ($runtimeReady) { "Encode engine: CPU | fallback sa $normalizedMode" } else { "Encode engine: CPU | $normalizedMode nije runtime spreman" }
        return $cpuPlan
    }

    switch ($normalizedMode) {
        "NVIDIA NVENC" {
            $videoArguments = if ($videoBitrateProvided) {
                @(
                    "-preset", (Get-VhsMp4NvencPreset -Preset ([string]$QualityProfile.Preset)),
                    "-tune", "hq",
                    "-rc", "vbr",
                    "-b:v", [string]$VideoBitrate,
                    "-maxrate", [string]$VideoBitrate,
                    "-bufsize", $videoBufferSize,
                    "-multipass", "fullres",
                    "-pix_fmt", "yuv420p"
                )
            }
            else {
                @(
                    "-preset", (Get-VhsMp4NvencPreset -Preset ([string]$QualityProfile.Preset)),
                    "-tune", "hq",
                    "-rc", "vbr",
                    "-cq", "$([int]$QualityProfile.Crf)",
                    "-b:v", "0",
                    "-multipass", "fullres",
                    "-pix_fmt", "yuv420p"
                )
            }
            return [pscustomobject]@{
                RequestedMode = $normalizedMode
                ResolvedMode = $normalizedMode
                VideoCodec = if ($codecFamily -eq "hevc") { "hevc_nvenc" } else { "h264_nvenc" }
                VideoTag = [string]$QualityProfile.VideoTag
                VideoArguments = $videoArguments
                Summary = if ($videoBitrateProvided) { "Encode engine: NVIDIA NVENC | target bitrate $VideoBitrate" } else { "Encode engine: NVIDIA NVENC" }
                FallbackUsed = $false
            }
        }
        "Intel QSV" {
            $videoArguments = if ($videoBitrateProvided) {
                @(
                    "-preset", (Get-VhsMp4QsvPreset -Preset ([string]$QualityProfile.Preset)),
                    "-b:v", [string]$VideoBitrate,
                    "-maxrate", [string]$VideoBitrate,
                    "-bufsize", $videoBufferSize,
                    "-look_ahead", "0",
                    "-pix_fmt", "nv12"
                )
            }
            else {
                @(
                    "-preset", (Get-VhsMp4QsvPreset -Preset ([string]$QualityProfile.Preset)),
                    "-global_quality", "$([int]$QualityProfile.Crf)",
                    "-look_ahead", "0",
                    "-pix_fmt", "nv12"
                )
            }
            return [pscustomobject]@{
                RequestedMode = $normalizedMode
                ResolvedMode = $normalizedMode
                VideoCodec = if ($codecFamily -eq "hevc") { "hevc_qsv" } else { "h264_qsv" }
                VideoTag = [string]$QualityProfile.VideoTag
                VideoArguments = $videoArguments
                Summary = if ($videoBitrateProvided) { "Encode engine: Intel QSV | target bitrate $VideoBitrate" } else { "Encode engine: Intel QSV" }
                FallbackUsed = $false
            }
        }
        "AMD AMF" {
            $videoArguments = if ($videoBitrateProvided) {
                @(
                    "-quality", (Get-VhsMp4AmfPreset -Preset ([string]$QualityProfile.Preset)),
                    "-rc", "vbr_peak",
                    "-b:v", [string]$VideoBitrate,
                    "-maxrate", [string]$VideoBitrate,
                    "-bufsize", $videoBufferSize,
                    "-pix_fmt", "yuv420p"
                )
            }
            else {
                @(
                    "-quality", (Get-VhsMp4AmfPreset -Preset ([string]$QualityProfile.Preset)),
                    "-rc", "qvbr",
                    "-qvbr_quality_level", "$([int]$QualityProfile.Crf)",
                    "-pix_fmt", "yuv420p"
                )
            }
            return [pscustomobject]@{
                RequestedMode = $normalizedMode
                ResolvedMode = $normalizedMode
                VideoCodec = if ($codecFamily -eq "hevc") { "hevc_amf" } else { "h264_amf" }
                VideoTag = [string]$QualityProfile.VideoTag
                VideoArguments = $videoArguments
                Summary = if ($videoBitrateProvided) { "Encode engine: AMD AMF | target bitrate $VideoBitrate" } else { "Encode engine: AMD AMF" }
                FallbackUsed = $false
            }
        }
        default {
            return $cpuPlan
        }
    }
}

function Get-VhsMp4QualityProfile {
    param(
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k"
    )

    switch ($QualityMode) {
        { $_ -in @("Small MP4 H.264", "Smaller File") } {
            return [pscustomobject]@{
                QualityMode = $QualityMode
                Crf = 24
                Preset = "slow"
                AudioBitrate = "128k"
                CodecFamily = "h264"
                VideoCodec = "libx264"
                VideoTag = ""
            }
        }
        { $_ -in @("High Quality MP4 H.264", "Better Quality") } {
            return [pscustomobject]@{
                QualityMode = $QualityMode
                Crf = 20
                Preset = "slow"
                AudioBitrate = "192k"
                CodecFamily = "h264"
                VideoCodec = "libx264"
                VideoTag = ""
            }
        }
        "HEVC H.265 Smaller" {
            return [pscustomobject]@{
                QualityMode = $QualityMode
                Crf = 26
                Preset = "medium"
                AudioBitrate = "128k"
                CodecFamily = "hevc"
                VideoCodec = "libx265"
                VideoTag = "hvc1"
            }
        }
        { $_ -in @("Universal MP4 H.264", "Standard VHS") } {
            return [pscustomobject]@{
                QualityMode = $QualityMode
                Crf = 22
                Preset = "slow"
                AudioBitrate = "160k"
                CodecFamily = "h264"
                VideoCodec = "libx264"
                VideoTag = ""
            }
        }
        "Custom" {
            return [pscustomobject]@{
                QualityMode = $QualityMode
                Crf = $Crf
                Preset = $Preset
                AudioBitrate = $AudioBitrate
                CodecFamily = "h264"
                VideoCodec = "libx264"
                VideoTag = ""
            }
        }
        default {
            return [pscustomobject]@{
                QualityMode = "Universal MP4 H.264"
                Crf = 22
                Preset = "slow"
                AudioBitrate = "160k"
                CodecFamily = "h264"
                VideoCodec = "libx264"
                VideoTag = ""
            }
        }
    }
}

function Get-VhsMp4VideoFilterChain {
    param(
        $InputObject,
        [object]$CropState,
        [string]$AspectMode = "Auto",
        [ValidateSet("Off", "YADIF", "YADIF Bob")]
        [string]$Deinterlace = "Off",
        [ValidateSet("Off", "Light", "Medium")]
        [string]$Denoise = "Off",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original"
    )

    $filters = @()
    $cropFilter = Get-VhsMp4CropFilter -CropState $CropState
    if (-not [string]::IsNullOrWhiteSpace($cropFilter)) {
        $filters += $cropFilter
    }

    switch ($Deinterlace) {
        "YADIF" { $filters += "yadif=0:-1:0" }
        "YADIF Bob" { $filters += "yadif=1:-1:0" }
    }

    switch ($Denoise) {
        "Light" { $filters += "hqdn3d=1.5:1.5:6:6" }
        "Medium" { $filters += "hqdn3d=3:3:8:8" }
    }

    switch ($RotateFlip) {
        "90 CW" { $filters += "transpose=1" }
        "90 CCW" { $filters += "transpose=2" }
        "180" { $filters += @("transpose=1", "transpose=1") }
        "Horizontal Flip" { $filters += "hflip" }
        "Vertical Flip" { $filters += "vflip" }
    }

    $scaleFilter = ""
    if ($null -ne $InputObject) {
        $scaleFilter = Get-VhsMp4AspectAwareScaleFilter -InputObject $InputObject -AspectMode $AspectMode -RotateFlip $RotateFlip -ScaleMode $ScaleMode -CropState $CropState
    }
    else {
        switch ($ScaleMode) {
            "PAL 576p" { $scaleFilter = "scale=-2:576:flags=lanczos" }
            "720p" { $scaleFilter = "scale=-2:720:flags=lanczos" }
            "1080p" { $scaleFilter = "scale=-2:1080:flags=lanczos" }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($scaleFilter)) {
        $filters += $scaleFilter
    }

    return ($filters -join ",")
}

function Get-VhsMp4AudioFilterChain {
    param(
        [switch]$AudioNormalize
    )

    if ($AudioNormalize) {
        return "loudnorm=I=-16:TP=-1.5:LRA=11"
    }

    return ""
}

function Get-VhsMp4FilterSummary {
    param(
        $InputObject,
        [object]$CropState,
        [string]$AspectMode = "Auto",
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

    $parts = @()
    if ($null -ne $InputObject) {
        $geometry = Get-VhsMp4AspectTargetGeometry -InputObject $InputObject -AspectMode $AspectMode -RotateFlip $RotateFlip -ScaleMode $ScaleMode -CropState $CropState
        $normalizedAspectMode = Get-VhsMp4NormalizedAspectMode -AspectMode $AspectMode
        $aspectLabel = if ($normalizedAspectMode -eq "Auto") { [string]$geometry.OutputAspectMode } else { $AspectMode }
        if ($geometry.RequiresAspectCorrection -or $normalizedAspectMode -ne "Auto") {
            $parts += "Aspect: $aspectLabel -> $($geometry.OutputWidth)x$($geometry.OutputHeight)"
        }
    }
    $cropFilter = Get-VhsMp4CropFilter -CropState $CropState
    if (-not [string]::IsNullOrWhiteSpace($cropFilter)) {
        $resolvedCropState = Get-VhsMp4CropState -InputObject $CropState
        $parts += "Crop: $($resolvedCropState.Left),$($resolvedCropState.Top),$($resolvedCropState.Right),$($resolvedCropState.Bottom)"
    }
    if ($Deinterlace -ne "Off") {
        $parts += "Deinterlace: $Deinterlace"
    }
    if ($Denoise -ne "Off") {
        $parts += "Denoise: $Denoise"
    }
    if ($RotateFlip -ne "None") {
        $parts += "Rotate/flip: $RotateFlip"
    }
    if ($ScaleMode -ne "Original") {
        $parts += "Scale: $ScaleMode"
    }
    if ($AudioNormalize) {
        $parts += "Audio normalize: On"
    }

    return ($parts -join " | ")
}

function New-VhsMp4RunContext {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir,
        [string]$OutputDir,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [string]$FfmpegPath = "ffmpeg",
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [object[]]$TrimSegments,
        [bool]$SourceHasAudio = $true,
        [ValidateSet("Off", "YADIF", "YADIF Bob")]
        [string]$Deinterlace = "Off",
        [ValidateSet("Off", "Light", "Medium")]
        [string]$Denoise = "Off",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [switch]$AudioNormalize,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory
    )

    $resolvedInputDir = Resolve-VhsMp4InputDir -InputDir $InputDir
    $resolvedOutputDir = Resolve-VhsMp4OutputDir -InputDir $resolvedInputDir -OutputDir $OutputDir
    $resolvedFfmpegPath = Assert-VhsMp4FfmpegPath -FfmpegPath $FfmpegPath
    $preflight = Test-VhsMp4FfmpegPreflight -FfmpegPath $resolvedFfmpegPath
    if (-not $preflight.Ready) {
        throw $preflight.Message
    }

    $profile = Get-VhsMp4QualityProfile -QualityMode $QualityMode -Crf $Crf -Preset $Preset -AudioBitrate $AudioBitrate
    $normalizedEncoderMode = Get-VhsMp4NormalizedEncoderMode -EncoderMode $EncoderMode
    $resolvedEncoderInventory = $EncoderInventory
    if ($null -eq $resolvedEncoderInventory) {
        if ($normalizedEncoderMode -in @("Auto", "CPU")) {
            $resolvedEncoderInventory = Get-VhsMp4EncoderInventoryFromText -EncodersText ""
        }
        else {
            $resolvedEncoderInventory = Get-VhsMp4EncoderInventory -FfmpegPath $resolvedFfmpegPath
        }
    }
    $encoderPlan = Resolve-VhsMp4VideoEncoderPlan -QualityProfile $profile -EncoderMode $normalizedEncoderMode -EncoderInventory $resolvedEncoderInventory -VideoBitrate $VideoBitrate
    $trimWindow = Get-VhsMp4TrimWindow -TrimStart $TrimStart -TrimEnd $TrimEnd
    $filterSummary = Get-VhsMp4FilterSummary -Deinterlace $Deinterlace -Denoise $Denoise -RotateFlip $RotateFlip -ScaleMode $ScaleMode -AudioNormalize:$AudioNormalize

    $null = New-Item -ItemType Directory -Path $resolvedOutputDir -Force
    $logDir = Join-Path $resolvedOutputDir "logs"
    $null = New-Item -ItemType Directory -Path $logDir -Force

    $logPath = Join-Path $logDir ("optimize-vhs-mp4-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    New-Item -ItemType File -Path $logPath -Force | Out-Null

    return [pscustomobject]@{
        InputDir = $resolvedInputDir
        OutputDir = $resolvedOutputDir
        QualityMode = $profile.QualityMode
        Crf = $profile.Crf
        Preset = $profile.Preset
        AudioBitrate = $profile.AudioBitrate
        VideoBitrate = [string]$VideoBitrate
        FfmpegPath = $resolvedFfmpegPath
        SplitOutput = [bool]$SplitOutput
        MaxPartGb = $MaxPartGb
        TrimStart = $trimWindow.StartText
        TrimEnd = $trimWindow.EndText
        TrimSummary = $trimWindow.Summary
        Deinterlace = $Deinterlace
        Denoise = $Denoise
        RotateFlip = $RotateFlip
        ScaleMode = $ScaleMode
        AudioNormalize = [bool]$AudioNormalize
        EncoderMode = $normalizedEncoderMode
        ResolvedEncoderMode = [string]$encoderPlan.ResolvedMode
        EncoderSummary = [string]$encoderPlan.Summary
        EncoderInventory = $resolvedEncoderInventory
        FilterSummary = $filterSummary
        LogDir = $logDir
        LogPath = $logPath
    }
}

function Write-VhsMp4Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [scriptblock]$OnLog
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $Message"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8

    if ($OnLog) {
        & $OnLog $line
    }
}

function Get-VhsMp4SupportedExtensions {
    return @(".mp4", ".avi", ".mpg", ".mpeg", ".mov", ".mkv", ".m4v", ".wmv", ".ts", ".m2ts", ".vob")
}

function Convert-VhsMp4BitrateToKbps {
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern("^\d+k$")]
        [string]$Bitrate
    )

    return [int]($Bitrate.Substring(0, $Bitrate.Length - 1))
}

function Get-VhsMp4SplitVideoMaxKbps {
    param(
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = ""
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$VideoBitrate)) {
        return (Convert-VhsMp4BitrateToKbps -Bitrate $VideoBitrate)
    }

    switch ($QualityMode) {
        { $_ -in @("Small MP4 H.264", "Smaller File", "HEVC H.265 Smaller") } { return 3000 }
        { $_ -in @("High Quality MP4 H.264", "Better Quality") } { return 6500 }
        "Custom" {
            if ($Crf -le 20) {
                return 6500
            }
            if ($Crf -ge 24) {
                return 3000
            }
            return 4500
        }
        default { return 4500 }
    }
}

function Get-VhsMp4SplitSegmentSeconds {
    param(
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [ValidateRange(1, 1000000)]
        [int]$VideoMaxKbps = 4500,
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k"
    )

    $audioKbps = Convert-VhsMp4BitrateToKbps -Bitrate $AudioBitrate
    $totalKbps = [Math]::Max(1, $VideoMaxKbps + $audioKbps)
    $targetBytes = $MaxPartGb * [Math]::Pow(1024, 3)
    $safetyFactor = 0.95
    $segmentSeconds = [int][Math]::Floor(($targetBytes * 8.0 * $safetyFactor) / ($totalKbps * 1000.0))
    return [int]([Math]::Max(1, $segmentSeconds))
}

function Get-VhsMp4EstimatedOutputInfo {
    param(
        [ValidateRange(0.001, 100000000)]
        [double]$DurationSeconds,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8
    )

    $profile = Get-VhsMp4QualityProfile -QualityMode $QualityMode -Crf $Crf -AudioBitrate $AudioBitrate
    $videoKbps = Get-VhsMp4SplitVideoMaxKbps -QualityMode $profile.QualityMode -Crf $profile.Crf -VideoBitrate $VideoBitrate
    $audioKbps = Convert-VhsMp4BitrateToKbps -Bitrate $profile.AudioBitrate
    $totalKbps = [Math]::Max(1, $videoKbps + $audioKbps)
    $estimatedBytes = [Math]::Ceiling(($DurationSeconds * $totalKbps * 1000.0) / 8.0)
    $estimatedGb = $estimatedBytes / [Math]::Pow(1024, 3)
    $maxPartBytes = $MaxPartGb * [Math]::Pow(1024, 3)
    $partCount = if ($SplitOutput) {
        [int][Math]::Max(1, [Math]::Ceiling($estimatedBytes / $maxPartBytes))
    }
    else {
        1
    }

    $fitsFat32 = ($estimatedGb -lt 3.95) -or [bool]$SplitOutput
    $usbNote = if ($SplitOutput) {
        "FAT32 OK, procena: $partCount delova; exFAT OK"
    }
    elseif ($estimatedGb -ge 3.95) {
        "FAT32 rizik: ukljuci Split output ili koristi exFAT"
    }
    else {
        "FAT32 OK; exFAT OK"
    }

    return [pscustomobject]@{
        DurationSeconds = $DurationSeconds
        VideoKbps = $videoKbps
        AudioKbps = $audioKbps
        TotalKbps = $totalKbps
        EstimatedBytes = [int64]$estimatedBytes
        EstimatedGb = [Math]::Round($estimatedGb, 2)
        PartCount = $partCount
        FitsFat32 = [bool]$fitsFat32
        UsbNote = $usbNote
    }
}

function Get-VhsMp4SplitOutputPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    return (Join-Path $OutputDir ($BaseName + "-part%03d.mp4"))
}

function Get-VhsMp4SampleOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$SourceName
    )

    $sampleDir = Join-Path $OutputDir "samples"
    $null = New-Item -ItemType Directory -Path $sampleDir -Force
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($SourceName)
    return (Join-Path $sampleDir ($baseName + "-sample.mp4"))
}

function Get-VhsMp4FirstSplitOutputPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    return (Join-Path $OutputDir ($BaseName + "-part001.mp4"))
}

function Get-VhsMp4ItemOutputTarget {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [bool]$SplitOutput
    )

    $patternProperty = $Item.PSObject.Properties["OutputPattern"]
    if ($SplitOutput -and $patternProperty -and -not [string]::IsNullOrWhiteSpace([string]$patternProperty.Value)) {
        return [string]$patternProperty.Value
    }

    return [string]$Item.OutputPath
}

function Test-VhsMp4PlanItemHasAudio {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $hasAudio = Get-VhsMp4ObjectPropertyValue -Object $Item -Name "HasAudio"
    if ($null -ne $hasAudio) {
        return [bool]$hasAudio
    }

    $mediaInfo = Get-VhsMp4ObjectPropertyValue -Object $Item -Name "MediaInfo"
    if ($null -ne $mediaInfo) {
        $audioCodec = [string](Get-VhsMp4ObjectPropertyValue -Object $mediaInfo -Name "AudioCodec")
        if (-not [string]::IsNullOrWhiteSpace($audioCodec) -and $audioCodec -ne "--") {
            return $true
        }
        return $false
    }

    return $true
}

function Write-VhsMp4CustomerReport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir,
        [Parameter(Mandatory = $true)]
        [object[]]$Items,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [bool]$SplitOutput = $false,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [string]$FilterSummary = "",
        [string]$WorkflowPresetName = ""
    )

    $resolvedOutputDir = [System.IO.Path]::GetFullPath($OutputDir)
    $null = New-Item -ItemType Directory -Path $resolvedOutputDir -Force
    $reportPath = Join-Path $resolvedOutputDir "IZVESTAJ.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $splitText = if ($SplitOutput) { "ukljucen, delovi do oko $MaxPartGb GB" } else { "iskljucen" }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("VHS MP4 Optimizer - IZVESTAJ")
    $lines.Add("Datum: $timestamp")
    $lines.Add("")
    $lines.Add("Podesavanja:")
    if (-not [string]::IsNullOrWhiteSpace($WorkflowPresetName)) {
        $lines.Add("Workflow preset: $WorkflowPresetName")
    }
    $lines.Add("Quality mode: $QualityMode")
    $lines.Add("CRF: $Crf")
    $lines.Add("Preset: $Preset")
    if (-not [string]::IsNullOrWhiteSpace([string]$VideoBitrate)) {
        $lines.Add("Video bitrate: $VideoBitrate")
    }
    $lines.Add("Audio bitrate: $AudioBitrate")
    $lines.Add("Split output: $splitText")
    if (-not [string]::IsNullOrWhiteSpace($FilterSummary)) {
        $lines.Add("Filters: $FilterSummary")
    }
    $lines.Add("")
    $lines.Add("Originalni fajlovi nisu menjani.")
    $lines.Add("")
    $lines.Add("Fajlovi:")

    foreach ($item in $Items) {
        $sourceName = [string]$item.SourceName
        $status = [string]$item.Status
        $outputTarget = Get-VhsMp4ItemOutputTarget -Item $item -SplitOutput $SplitOutput
        $outputName = [System.IO.Path]::GetFileName($outputTarget)
        $lines.Add(("{0} | {1} | {2}" -f $sourceName, $status, $outputName))
        $trimProperty = $item.PSObject.Properties["TrimSummary"]
        if ($trimProperty -and -not [string]::IsNullOrWhiteSpace([string]$trimProperty.Value)) {
            $lines.Add("  Trim: $($trimProperty.Value)")
        }
    }

    $lines.Add("")
    $lines.Add("USB PREDAJA CHECKLIST:")
    $lines.Add("- Ako je neki fajl veci od 4 GB, koristi exFAT USB ili Split output.")
    $lines.Add("- Za FAT32 USB ostavi Split output na oko 3.8 GB po delu.")
    $lines.Add("- Pusti bar prvi minut svakog MP4 fajla pre predaje.")
    $lines.Add("- Kopiraj IZVESTAJ.txt uz gotove video fajlove.")
    $lines.Add("- Originalni fajlovi ostaju kod tebe kao arhiva.")

    Set-Content -LiteralPath $reportPath -Value $lines -Encoding UTF8
    return $reportPath
}

function Get-VhsMp4PathWithTrailingSeparator {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $trimChars = @([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return ([System.IO.Path]::GetFullPath($Path).TrimEnd($trimChars) + [System.IO.Path]::DirectorySeparatorChar)
}

function Test-VhsMp4PathEquals {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Left,
        [Parameter(Mandatory = $true)]
        [string]$Right
    )

    $leftFull = [System.IO.Path]::GetFullPath($Left).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $rightFull = [System.IO.Path]::GetFullPath($Right).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return [string]::Equals($leftFull, $rightFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-VhsMp4PathIsUnderDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Directory
    )

    $pathFull = [System.IO.Path]::GetFullPath($Path)
    $directoryFull = Get-VhsMp4PathWithTrailingSeparator -Path $Directory
    return $pathFull.StartsWith($directoryFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-VhsMp4RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseDir,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $baseUri = New-Object System.Uri (Get-VhsMp4PathWithTrailingSeparator -Path $BaseDir)
    $pathUri = New-Object System.Uri ([System.IO.Path]::GetFullPath($Path))
    $relativeUri = $baseUri.MakeRelativeUri($pathUri).ToString()
    return [System.Uri]::UnescapeDataString($relativeUri).Replace("/", [System.IO.Path]::DirectorySeparatorChar)
}

function New-VhsMp4OutputParentDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $parent = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }
}

function Get-VhsMp4CommonDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $fullPaths = @($Paths |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { [System.IO.Path]::GetFullPath([string]$_) } |
        Sort-Object -Unique)

    if ($fullPaths.Count -eq 0) {
        return ""
    }

    $root = [System.IO.Path]::GetPathRoot($fullPaths[0])
    foreach ($path in $fullPaths) {
        if (-not [string]::Equals([System.IO.Path]::GetPathRoot($path), $root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return ""
        }
    }

    $commonPath = $fullPaths[0]
    while (-not [string]::IsNullOrWhiteSpace($commonPath)) {
        $matchesAll = $true
        foreach ($path in $fullPaths) {
            if (-not (Test-VhsMp4PathEquals -Left $path -Right $commonPath) -and -not (Test-VhsMp4PathIsUnderDirectory -Path $path -Directory $commonPath)) {
                $matchesAll = $false
                break
            }
        }

        if ($matchesAll) {
            return $commonPath
        }

        $parent = Split-Path -Path $commonPath -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or [string]::Equals($parent, $commonPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }

        $commonPath = $parent
    }

    return $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Get-VhsMp4ExplicitSourceFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SourcePaths,
        [string]$ExcludeDirectory = ""
    )

    $supportedExtensions = Get-VhsMp4SupportedExtensions
    $resolvedExcludeDirectory = ""
    if (-not [string]::IsNullOrWhiteSpace($ExcludeDirectory)) {
        $resolvedExcludeDirectory = [System.IO.Path]::GetFullPath($ExcludeDirectory)
    }

    $resolvedFiles = New-Object System.Collections.Generic.List[string]

    foreach ($sourcePath in $SourcePaths) {
        if ([string]::IsNullOrWhiteSpace([string]$sourcePath) -or -not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }

        $item = Get-Item -LiteralPath $sourcePath -Force
        $files = if ($item.PSIsContainer) {
            @(Get-ChildItem -LiteralPath $item.FullName -File -Recurse -Force -ErrorAction SilentlyContinue)
        }
        else {
            @($item)
        }

        foreach ($file in $files) {
            if ($file.PSIsContainer -or $file.Extension.ToLowerInvariant() -notin $supportedExtensions) {
                continue
            }

            $fullName = [System.IO.Path]::GetFullPath($file.FullName)
            if (-not [string]::IsNullOrWhiteSpace($resolvedExcludeDirectory) -and (Test-VhsMp4PathIsUnderDirectory -Path $fullName -Directory $resolvedExcludeDirectory)) {
                continue
            }

            $resolvedFiles.Add($fullName)
        }
    }

    return @($resolvedFiles | Sort-Object -Unique | ForEach-Object { Get-Item -LiteralPath $_ -Force })
}

function Get-VhsMp4ExplicitSourceName {
    param(
        [string]$BaseDir,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    $resolvedSourcePath = [System.IO.Path]::GetFullPath($SourcePath)
    if (-not [string]::IsNullOrWhiteSpace($BaseDir) -and ((Test-VhsMp4PathEquals -Left $resolvedSourcePath -Right $BaseDir) -or (Test-VhsMp4PathIsUnderDirectory -Path $resolvedSourcePath -Directory $BaseDir))) {
        return Get-VhsMp4RelativePath -BaseDir $BaseDir -Path $resolvedSourcePath
    }

    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedSourcePath)
    if (-not [string]::IsNullOrWhiteSpace($pathRoot) -and $resolvedSourcePath.StartsWith($pathRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativeFromRoot = $resolvedSourcePath.Substring($pathRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $rootLabel = $pathRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar).Replace(":", "")
        if ([string]::IsNullOrWhiteSpace($rootLabel)) {
            return $relativeFromRoot
        }
        if ([string]::IsNullOrWhiteSpace($relativeFromRoot)) {
            return $rootLabel
        }
        return (Join-Path $rootLabel $relativeFromRoot)
    }

    return [System.IO.Path]::GetFileName($resolvedSourcePath)
}

function Get-VhsMp4Plan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir,
        [string]$OutputDir,
        [string]$FfmpegPath,
        [switch]$SplitOutput
    )

    $resolvedInputDir = Resolve-VhsMp4InputDir -InputDir $InputDir
    $resolvedOutputDir = Resolve-VhsMp4OutputDir -InputDir $resolvedInputDir -OutputDir $OutputDir
    $skipOutputDir = -not (Test-VhsMp4PathEquals -Left $resolvedInputDir -Right $resolvedOutputDir)

    return @(Get-ChildItem -LiteralPath $resolvedInputDir -File -Recurse -Force |
        Where-Object {
            $_.Extension.ToLowerInvariant() -in (Get-VhsMp4SupportedExtensions) -and
            (-not $skipOutputDir -or -not (Test-VhsMp4PathIsUnderDirectory -Path $_.FullName -Directory $resolvedOutputDir))
        } |
        Sort-Object FullName |
        ForEach-Object {
            $relativeSourcePath = Get-VhsMp4RelativePath -BaseDir $resolvedInputDir -Path $_.FullName
            $relativeDirectory = Split-Path -Path $relativeSourcePath -Parent
            $outputItemDir = $resolvedOutputDir
            if (-not [string]::IsNullOrWhiteSpace($relativeDirectory)) {
                $outputItemDir = Join-Path $resolvedOutputDir $relativeDirectory
            }

            if ($SplitOutput) {
                $outputPath = Get-VhsMp4FirstSplitOutputPath -OutputDir $outputItemDir -BaseName $_.BaseName
                $outputPattern = Get-VhsMp4SplitOutputPattern -OutputDir $outputItemDir -BaseName $_.BaseName
            }
            else {
                $outputPath = Join-Path $outputItemDir ($_.BaseName + ".mp4")
                $outputPattern = $outputPath
            }

            $item = [pscustomobject]@{
                SourceName = $relativeSourcePath
                SourceFileName = $_.Name
                RelativeSourcePath = $relativeSourcePath
                SourcePath = $_.FullName
                OutputPath = $outputPath
                OutputPattern = $outputPattern
                DisplayOutputName = Get-VhsMp4RelativePath -BaseDir $resolvedOutputDir -Path $outputPattern
                Status = if (Test-Path -LiteralPath $outputPath) { "skipped" } else { "queued" }
            }

            if (-not [string]::IsNullOrWhiteSpace($FfmpegPath)) {
                try {
                    $mediaInfo = Get-VhsMp4MediaInfo -SourcePath $_.FullName -FfmpegPath $FfmpegPath
                    $item | Add-Member -NotePropertyName "MediaInfo" -NotePropertyValue $mediaInfo -Force
                    $item = Add-VhsMp4AspectSnapshotToObject -TargetObject $item -InputObject $mediaInfo
                }
                catch {
                }
            }

            $item
        })
}

function Get-VhsMp4PlanFromPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SourcePaths,
        [string]$InputDir,
        [string]$OutputDir,
        [string]$FfmpegPath,
        [switch]$SplitOutput
    )

    $candidatePaths = @($SourcePaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($candidatePaths.Count -eq 0) {
        return @()
    }

    $resolvedInputDir = ""
    if (-not [string]::IsNullOrWhiteSpace($InputDir)) {
        $resolvedInputDir = Resolve-VhsMp4InputDir -InputDir $InputDir
    }
    else {
        $sourceDirectories = New-Object System.Collections.Generic.List[string]
        foreach ($sourcePath in $candidatePaths) {
            if (-not (Test-Path -LiteralPath $sourcePath)) {
                continue
            }

            $item = Get-Item -LiteralPath $sourcePath -Force
            if ($item.PSIsContainer) {
                $sourceDirectories.Add([System.IO.Path]::GetFullPath($item.FullName))
            }
            else {
                $sourceDirectories.Add([System.IO.Path]::GetFullPath((Split-Path -Path $item.FullName -Parent)))
            }
        }

        $resolvedInputDir = Get-VhsMp4CommonDirectory -Paths $sourceDirectories
        if ([string]::IsNullOrWhiteSpace($resolvedInputDir) -and $sourceDirectories.Count -gt 0) {
            $resolvedInputDir = [string]$sourceDirectories[0]
        }
    }

    if ([string]::IsNullOrWhiteSpace($resolvedInputDir)) {
        throw "Ulazni folder nije moguce odrediti iz zadatih fajlova."
    }

    $resolvedOutputDir = Resolve-VhsMp4OutputDir -InputDir $resolvedInputDir -OutputDir $OutputDir
    $files = @(Get-VhsMp4ExplicitSourceFiles -SourcePaths $candidatePaths -ExcludeDirectory $resolvedOutputDir)

    return @($files |
        Sort-Object FullName |
        ForEach-Object {
            $sourceName = Get-VhsMp4ExplicitSourceName -BaseDir $resolvedInputDir -SourcePath $_.FullName
            $relativeDirectory = Split-Path -Path $sourceName -Parent
            $outputItemDir = $resolvedOutputDir
            if (-not [string]::IsNullOrWhiteSpace($relativeDirectory)) {
                $outputItemDir = Join-Path $resolvedOutputDir $relativeDirectory
            }

            if ($SplitOutput) {
                $outputPath = Get-VhsMp4FirstSplitOutputPath -OutputDir $outputItemDir -BaseName $_.BaseName
                $outputPattern = Get-VhsMp4SplitOutputPattern -OutputDir $outputItemDir -BaseName $_.BaseName
            }
            else {
                $outputPath = Join-Path $outputItemDir ($_.BaseName + ".mp4")
                $outputPattern = $outputPath
            }

            $item = [pscustomobject]@{
                SourceName = $sourceName
                SourceFileName = $_.Name
                RelativeSourcePath = $sourceName
                SourcePath = $_.FullName
                OutputPath = $outputPath
                OutputPattern = $outputPattern
                DisplayOutputName = Get-VhsMp4RelativePath -BaseDir $resolvedOutputDir -Path $outputPattern
                Status = if (Test-Path -LiteralPath $outputPath) { "skipped" } else { "queued" }
            }

            if (-not [string]::IsNullOrWhiteSpace($FfmpegPath)) {
                try {
                    $mediaInfo = Get-VhsMp4MediaInfo -SourcePath $_.FullName -FfmpegPath $FfmpegPath
                    $item | Add-Member -NotePropertyName "MediaInfo" -NotePropertyValue $mediaInfo -Force
                    $item = Add-VhsMp4AspectSnapshotToObject -TargetObject $item -InputObject $mediaInfo
                }
                catch {
                }
            }

            $item
        })
}

function Get-VhsMp4FfmpegArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [string]$ProgressPath,
        [ValidateRange(0, 86400)]
        [int]$SampleSeconds = 0,
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [object[]]$TrimSegments,
        [string]$AspectMode = "Auto",
        [object]$VideoInfo,
        [object]$CropState,
        [bool]$SourceHasAudio = $true,
        [ValidateSet("Off", "YADIF", "YADIF Bob")]
        [string]$Deinterlace = "Off",
        [ValidateSet("Off", "Light", "Medium")]
        [string]$Denoise = "Off",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [switch]$AudioNormalize,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory
    )

    $profile = Get-VhsMp4QualityProfile -QualityMode $QualityMode -Crf $Crf -Preset $Preset -AudioBitrate $AudioBitrate
    $encoderPlan = Resolve-VhsMp4VideoEncoderPlan -QualityProfile $profile -EncoderMode $EncoderMode -EncoderInventory $EncoderInventory -VideoBitrate $VideoBitrate
    $videoMaxKbps = Get-VhsMp4SplitVideoMaxKbps -QualityMode $profile.QualityMode -Crf $profile.Crf -VideoBitrate $VideoBitrate
    $hasVideoBitrateOverride = -not [string]::IsNullOrWhiteSpace([string]$VideoBitrate)
    $trimPlan = Get-VhsMp4EffectiveTrimPlan -TrimStart $TrimStart -TrimEnd $TrimEnd -TrimSegments $TrimSegments
    $videoFilterChain = Get-VhsMp4VideoFilterChain -InputObject $VideoInfo -CropState $CropState -AspectMode $AspectMode -Deinterlace $Deinterlace -Denoise $Denoise -RotateFlip $RotateFlip -ScaleMode $ScaleMode
    $audioFilterChain = Get-VhsMp4AudioFilterChain -AudioNormalize:$AudioNormalize

    $ffmpegArgs = @(
        "-hide_banner",
        "-y"
    )

    if ($trimPlan.Mode -ne "multi" -and -not [string]::IsNullOrWhiteSpace($trimPlan.StartText)) {
        $ffmpegArgs += @("-ss", $trimPlan.StartText)
    }

    if ($trimPlan.Mode -ne "multi" -and
        (-not [string]::IsNullOrWhiteSpace($trimPlan.StartText)) -and
        (-not [string]::IsNullOrWhiteSpace($trimPlan.DurationText))) {
        $ffmpegArgs += @("-t", $trimPlan.DurationText)
    }
    elseif ($trimPlan.Mode -ne "multi" -and -not [string]::IsNullOrWhiteSpace($trimPlan.EndText)) {
        $ffmpegArgs += @("-to", $trimPlan.EndText)
    }

    $ffmpegArgs += @("-i", $SourcePath)

    if ($trimPlan.Mode -eq "multi") {
        $filterComplex = New-VhsMp4MultiTrimFilterComplex -TrimSegments $trimPlan.Segments -VideoFilterChain $videoFilterChain -AudioFilterChain $audioFilterChain -SourceHasAudio $SourceHasAudio
        $ffmpegArgs += @(
            "-filter_complex", $filterComplex,
            "-map", "[vout]"
        )
        if ($SourceHasAudio) {
            $ffmpegArgs += @("-map", "[aout]")
        }
    }
    else {
        $ffmpegArgs += @(
            "-map", "0:v:0",
            "-map", "0:a?"
        )

    if (-not [string]::IsNullOrWhiteSpace($videoFilterChain)) {
        $ffmpegArgs += @("-vf", $videoFilterChain)
    }
    }

    $ffmpegArgs += @(
        "-c:v", $encoderPlan.VideoCodec
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$encoderPlan.VideoTag)) {
        $ffmpegArgs += @("-tag:v", $encoderPlan.VideoTag)
    }

    $ffmpegArgs += @($encoderPlan.VideoArguments)

    if ($trimPlan.Mode -ne "multi" -and -not [string]::IsNullOrWhiteSpace($audioFilterChain)) {
        $ffmpegArgs += @("-af", $audioFilterChain)
    }

    $ffmpegArgs += @(
        "-c:a", "aac",
        "-b:a", $profile.AudioBitrate
    )

    if ($SplitOutput -and -not $hasVideoBitrateOverride) {
        $ffmpegArgs += @("-maxrate", "$($videoMaxKbps)k", "-bufsize", "$($videoMaxKbps * 2)k")
    }

    if (-not [string]::IsNullOrWhiteSpace($ProgressPath)) {
        $ffmpegArgs += @("-nostats", "-progress", $ProgressPath)
    }

    if ($SampleSeconds -gt 0) {
        $ffmpegArgs += @("-t", "$SampleSeconds")
    }

    if ($SplitOutput) {
        $segmentSeconds = Get-VhsMp4SplitSegmentSeconds -MaxPartGb $MaxPartGb -VideoMaxKbps $videoMaxKbps -AudioBitrate $profile.AudioBitrate
        $ffmpegArgs += @(
            "-f", "segment",
            "-segment_time", "$segmentSeconds",
            "-segment_start_number", "1",
            "-reset_timestamps", "1",
            "-segment_format", "mp4",
            "-segment_format_options", "movflags=+faststart",
            $OutputPath
        )
    }
    else {
        $ffmpegArgs += @("-movflags", "+faststart", $OutputPath)
    }

    return ,$ffmpegArgs
}

function New-VhsMp4ProcessStartInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FfmpegArguments
    )

    $commandPath = Resolve-VhsMp4CommandPath -CommandPath $FfmpegPath
    $extension = [System.IO.Path]::GetExtension($commandPath)
    $argumentList = if ($extension -ieq ".ps1") {
        $scriptLiteral = "'" + ($commandPath -replace "'", "''") + "'"
        $argumentLiterals = foreach ($argument in $FfmpegArguments) {
            "'" + ($argument -replace "'", "''") + "'"
        }
        $commandText = "& $scriptLiteral -Args @(" + ($argumentLiterals -join ", ") + ")"
        @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $commandText)
    }
    else {
        $FfmpegArguments
    }

    $fileName = if ($extension -ieq ".ps1") {
        (Get-Command -Name powershell -ErrorAction Stop).Source
    }
    else {
        $commandPath
    }

    $quotedArguments = foreach ($argument in $argumentList) {
        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        }
        else {
            $argument
        }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $fileName
    $startInfo.Arguments = ($quotedArguments -join " ")
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true
    return $startInfo
}

function New-VhsMp4PreviewFrame {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [string]$FfmpegPath = "ffmpeg",
        [string]$PreviewTime = "00:00:05"
    )

    $previewSeconds = Convert-VhsMp4TimeTextToSeconds -Value $PreviewTime
    if ($null -eq $previewSeconds) {
        $previewSeconds = 5.0
    }
    $previewTimeText = Format-VhsMp4FfmpegTime -Seconds $previewSeconds

    New-VhsMp4OutputParentDirectory -OutputPath $OutputPath

    $arguments = @(
        "-hide_banner",
        "-y",
        "-ss", $previewTimeText,
        "-i", $SourcePath,
        "-map", "0:v:0",
        "-frames:v", "1",
        "-c:v", "png",
        "-pix_fmt", "rgb24",
        $OutputPath
    )

    $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $arguments
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        Success = ($process.ExitCode -eq 0)
        OutputPath = $OutputPath
        PreviewTime = $previewTimeText
        ExitCode = $process.ExitCode
        StdOut = $stdOut
        ErrorText = $stdErr
    }
}

function Get-VhsMp4CopyContainerOptions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $extension = [System.IO.Path]::GetExtension($OutputPath).ToLowerInvariant()
    switch ($extension) {
        ".mp4" { return [pscustomobject]@{ SegmentFormat = "mp4"; UseFastStart = $true } }
        ".m4v" { return [pscustomobject]@{ SegmentFormat = "mp4"; UseFastStart = $true } }
        ".mov" { return [pscustomobject]@{ SegmentFormat = "mov"; UseFastStart = $false } }
        ".mkv" { return [pscustomobject]@{ SegmentFormat = "matroska"; UseFastStart = $false } }
        ".avi" { return [pscustomobject]@{ SegmentFormat = "avi"; UseFastStart = $false } }
        ".mpg" { return [pscustomobject]@{ SegmentFormat = "mpeg"; UseFastStart = $false } }
        ".mpeg" { return [pscustomobject]@{ SegmentFormat = "mpeg"; UseFastStart = $false } }
        ".ts" { return [pscustomobject]@{ SegmentFormat = "mpegts"; UseFastStart = $false } }
        ".m2ts" { return [pscustomobject]@{ SegmentFormat = "mpegts"; UseFastStart = $false } }
        default { return [pscustomobject]@{ SegmentFormat = ""; UseFastStart = $false } }
    }
}

function ConvertTo-VhsMp4CopySplitFfmpegPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPattern
    )

    if ($OutputPattern -match "%0?3d") {
        return $OutputPattern
    }

    if ($OutputPattern -match "\{0:D3\}") {
        return ($OutputPattern -replace "\{0:D3\}", "%03d")
    }

    $directory = Split-Path -Path $OutputPattern -Parent
    if ([string]::IsNullOrWhiteSpace($directory)) {
        $directory = (Get-Location).Path
    }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPattern)
    $extension = [System.IO.Path]::GetExtension($OutputPattern)
    return (Join-Path $directory ($baseName + "-part%03d" + $extension))
}

function Get-VhsMp4CopySplitOutputPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPattern,
        [Parameter(Mandatory = $true)]
        [int]$PartCount
    )

    $resolvedPattern = if ($OutputPattern -match "\{0:D3\}") {
        $OutputPattern
    }
    elseif ($OutputPattern -match "%0?3d") {
        $OutputPattern -replace "%0?3d", "{0:D3}"
    }
    else {
        $directory = Split-Path -Path $OutputPattern -Parent
        if ([string]::IsNullOrWhiteSpace($directory)) {
            $directory = (Get-Location).Path
        }
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPattern)
        $extension = [System.IO.Path]::GetExtension($OutputPattern)
        Join-Path $directory ($baseName + "-part{0:D3}" + $extension)
    }

    $paths = New-Object System.Collections.Generic.List[string]
    for ($index = 1; $index -le $PartCount; $index++) {
        $paths.Add([System.IO.Path]::GetFullPath(([string]::Format($resolvedPattern, $index))))
    }

    return @($paths)
}

function ConvertTo-VhsMp4ConcatFileLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    $normalizedPath = [System.IO.Path]::GetFullPath($SourcePath).Replace("\", "/")
    $escapedPath = $normalizedPath.Replace("'", "'\''")
    return "file '$escapedPath'"
}

function Invoke-VhsMp4CopySplit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPattern,
        [Parameter(Mandatory = $true)]
        [int]$PartCount,
        [string]$FfmpegPath = "ffmpeg",
        [double]$DurationSeconds = 0
    )

    if ($PartCount -lt 2) {
        throw "Copy split trazi najmanje 2 dela."
    }

    if ($DurationSeconds -le 0) {
        $mediaInfo = Get-VhsMp4MediaInfo -SourcePath $SourcePath -FfmpegPath $FfmpegPath
        if ($null -ne $mediaInfo -and $null -ne $mediaInfo.DurationSeconds) {
            $DurationSeconds = [double]$mediaInfo.DurationSeconds
        }
    }

    if ($DurationSeconds -le 0) {
        throw "Trajanje izvornog fajla nije dostupno; copy split ne moze da izracuna delove."
    }

    $ffmpegPattern = ConvertTo-VhsMp4CopySplitFfmpegPattern -OutputPattern $OutputPattern
    $containerOptions = Get-VhsMp4CopyContainerOptions -OutputPath $ffmpegPattern
    New-VhsMp4OutputParentDirectory -OutputPath $ffmpegPattern

    $segmentTimes = New-Object System.Collections.Generic.List[string]
    for ($index = 1; $index -lt $PartCount; $index++) {
        $cutSeconds = ($DurationSeconds * $index) / $PartCount
        $segmentTimes.Add((Format-VhsMp4FfmpegTime -Seconds $cutSeconds))
    }

    $arguments = @(
        "-hide_banner",
        "-y",
        "-i", $SourcePath,
        "-map", "0",
        "-c", "copy",
        "-f", "segment",
        "-segment_times", ($segmentTimes -join ","),
        "-segment_start_number", "1",
        "-reset_timestamps", "1"
    )

    if (-not [string]::IsNullOrWhiteSpace([string]$containerOptions.SegmentFormat)) {
        $arguments += @("-segment_format", [string]$containerOptions.SegmentFormat)
    }

    if ([bool]$containerOptions.UseFastStart) {
        $arguments += @("-segment_format_options", "movflags=+faststart")
    }

    $arguments += $ffmpegPattern

    $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $arguments
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdOut = $process.StandardOutput.ReadToEnd()
    $stdErr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    $outputPaths = @()
    if ($process.ExitCode -eq 0) {
        $outputPaths = @(Get-VhsMp4CopySplitOutputPaths -OutputPattern $OutputPattern -PartCount $PartCount | Where-Object { Test-Path -LiteralPath $_ })
    }

    return [pscustomobject]@{
        Success = ($process.ExitCode -eq 0 -and $outputPaths.Count -gt 0)
        ExitCode = $process.ExitCode
        StdOut = $stdOut
        ErrorText = $stdErr
        SourcePath = [System.IO.Path]::GetFullPath($SourcePath)
        OutputPattern = $ffmpegPattern
        PartCount = $PartCount
        DurationSeconds = $DurationSeconds
        SegmentTimes = @($segmentTimes)
        OutputPaths = @($outputPaths)
    }
}

function Invoke-VhsMp4CopyJoin {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SourcePaths,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [string]$FfmpegPath = "ffmpeg"
    )

    $resolvedSourcePaths = @($SourcePaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [System.IO.Path]::GetFullPath([string]$_) })
    if ($resolvedSourcePaths.Count -lt 2) {
        throw "Copy join trazi najmanje 2 ulazna fajla."
    }

    New-VhsMp4OutputParentDirectory -OutputPath $OutputPath

    $concatListPath = Join-Path ([System.IO.Path]::GetTempPath()) ("vhs-mp4-concat-" + [System.Guid]::NewGuid().ToString("N") + ".txt")
    try {
        $concatLines = foreach ($sourcePath in $resolvedSourcePaths) {
            ConvertTo-VhsMp4ConcatFileLine -SourcePath $sourcePath
        }
        Set-Content -LiteralPath $concatListPath -Value $concatLines -Encoding UTF8

        $containerOptions = Get-VhsMp4CopyContainerOptions -OutputPath $OutputPath
        $arguments = @(
            "-hide_banner",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", $concatListPath,
            "-c", "copy"
        )

        if ([bool]$containerOptions.UseFastStart) {
            $arguments += @("-movflags", "+faststart")
        }

        $arguments += $OutputPath

        $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $arguments
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        [void]$process.Start()
        $stdOut = $process.StandardOutput.ReadToEnd()
        $stdErr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        return [pscustomobject]@{
            Success = ($process.ExitCode -eq 0 -and (Test-Path -LiteralPath $OutputPath))
            ExitCode = $process.ExitCode
            StdOut = $stdOut
            ErrorText = $stdErr
            OutputPath = [System.IO.Path]::GetFullPath($OutputPath)
            SourcePaths = @($resolvedSourcePaths)
        }
    }
    finally {
        if (Test-Path -LiteralPath $concatListPath) {
            Remove-Item -LiteralPath $concatListPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Start-VhsMp4FileProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [string]$ProgressPath,
        [ValidateRange(0, 86400)]
        [int]$SampleSeconds = 0,
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [object[]]$TrimSegments,
        [bool]$SourceHasAudio = $true,
        [ValidateSet("Off", "YADIF", "YADIF Bob")]
        [string]$Deinterlace = "Off",
        [ValidateSet("Off", "Light", "Medium")]
        [string]$Denoise = "Off",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [switch]$AudioNormalize,
        [string]$AspectMode = "Auto",
        [object]$VideoInfo,
        [object]$CropState,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory,
        [hashtable]$SharedState
    )

    New-VhsMp4OutputParentDirectory -OutputPath $OutputPath

    $ffmpegArguments = Get-VhsMp4FfmpegArguments `
        -SourcePath $SourcePath `
        -OutputPath $OutputPath `
        -QualityMode $QualityMode `
        -Crf $Crf `
        -Preset $Preset `
        -AudioBitrate $AudioBitrate `
        -VideoBitrate $VideoBitrate `
        -ProgressPath $ProgressPath `
        -SampleSeconds $SampleSeconds `
        -SplitOutput:$SplitOutput `
        -MaxPartGb $MaxPartGb `
        -TrimStart $TrimStart `
        -TrimEnd $TrimEnd `
        -TrimSegments $TrimSegments `
        -SourceHasAudio $SourceHasAudio `
        -Deinterlace $Deinterlace `
        -Denoise $Denoise `
        -RotateFlip $RotateFlip `
        -ScaleMode $ScaleMode `
        -AudioNormalize:$AudioNormalize `
        -AspectMode $AspectMode `
        -VideoInfo $VideoInfo `
        -CropState $CropState `
        -EncoderMode $EncoderMode `
        -EncoderInventory $EncoderInventory

    $startInfo = New-VhsMp4ProcessStartInfo -FfmpegPath $FfmpegPath -FfmpegArguments $ffmpegArguments
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()

    $stdOutTask = $process.StandardOutput.ReadToEndAsync()
    $stdErrTask = $process.StandardError.ReadToEndAsync()
    $process | Add-Member -NotePropertyName "VhsMp4StdOutTask" -NotePropertyValue $stdOutTask -Force
    $process | Add-Member -NotePropertyName "VhsMp4StdErrTask" -NotePropertyValue $stdErrTask -Force

    if ($SharedState) {
        $SharedState.CurrentProcessId = $process.Id
    }

    return [pscustomobject]@{
        Process = $process
        OutputPath = $OutputPath
        SourcePath = $SourcePath
    }
}

function Complete-VhsMp4FileProcess {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [hashtable]$SharedState
    )

    $stdOut = ""
    $stdErr = ""
    $exitCode = -1

    try {
        if (-not $Process.HasExited) {
            $Process.WaitForExit()
        }

        $stdOutTaskProperty = $Process.PSObject.Properties["VhsMp4StdOutTask"]
        $stdErrTaskProperty = $Process.PSObject.Properties["VhsMp4StdErrTask"]

        if ($stdOutTaskProperty -and $stdOutTaskProperty.Value) {
            $stdOut = $stdOutTaskProperty.Value.GetAwaiter().GetResult()
        }
        else {
            $stdOut = $Process.StandardOutput.ReadToEnd()
        }

        if ($stdErrTaskProperty -and $stdErrTaskProperty.Value) {
            $stdErr = $stdErrTaskProperty.Value.GetAwaiter().GetResult()
        }
        else {
            $stdErr = $Process.StandardError.ReadToEnd()
        }

        $exitCode = $Process.ExitCode
    }
    finally {
        if ($SharedState) {
            $SharedState.CurrentProcessId = $null
        }
    }

    return [pscustomobject]@{
        Success = ($exitCode -eq 0)
        ExitCode = $exitCode
        StdOut = $stdOut
        StdErr = $stdErr
        OutputPath = $OutputPath
    }
}

function Invoke-VhsMp4File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [string]$FfmpegPath,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [ValidateRange(0, 86400)]
        [int]$SampleSeconds = 0,
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [object[]]$TrimSegments,
        [bool]$SourceHasAudio = $true,
        [ValidateSet("Off", "YADIF", "YADIF Bob")]
        [string]$Deinterlace = "Off",
        [ValidateSet("Off", "Light", "Medium")]
        [string]$Denoise = "Off",
        [ValidateSet("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip")]
        [string]$RotateFlip = "None",
        [ValidateSet("Original", "PAL 576p", "720p", "1080p")]
        [string]$ScaleMode = "Original",
        [switch]$AudioNormalize,
        [string]$AspectMode = "Auto",
        [object]$VideoInfo,
        [object]$CropState,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory,
        [hashtable]$SharedState
    )

    $started = Start-VhsMp4FileProcess `
        -SourcePath $SourcePath `
        -OutputPath $OutputPath `
        -FfmpegPath $FfmpegPath `
        -QualityMode $QualityMode `
        -Crf $Crf `
        -Preset $Preset `
        -AudioBitrate $AudioBitrate `
        -VideoBitrate $VideoBitrate `
        -SampleSeconds $SampleSeconds `
        -SplitOutput:$SplitOutput `
        -MaxPartGb $MaxPartGb `
        -TrimStart $TrimStart `
        -TrimEnd $TrimEnd `
        -TrimSegments $TrimSegments `
        -SourceHasAudio $SourceHasAudio `
        -Deinterlace $Deinterlace `
        -Denoise $Denoise `
        -RotateFlip $RotateFlip `
        -ScaleMode $ScaleMode `
        -AudioNormalize:$AudioNormalize `
        -AspectMode $AspectMode `
        -VideoInfo $VideoInfo `
        -CropState $CropState `
        -EncoderMode $EncoderMode `
        -EncoderInventory $EncoderInventory `
        -SharedState $SharedState

    return (Complete-VhsMp4FileProcess -Process $started.Process -OutputPath $OutputPath -SharedState $SharedState)
}

function Invoke-VhsMp4Batch {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir,
        [string]$OutputDir,
        [ValidateSet("Universal MP4 H.264", "Small MP4 H.264", "High Quality MP4 H.264", "HEVC H.265 Smaller", "Standard VHS", "Smaller File", "Better Quality", "Custom")]
        [string]$QualityMode = "Standard VHS",
        [ValidateRange(0, 51)]
        [int]$Crf = 22,
        [ValidateSet("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")]
        [string]$Preset = "slow",
        [ValidatePattern("^\d+k$")]
        [string]$AudioBitrate = "160k",
        [ValidatePattern('^$|^\d+k$')]
        [string]$VideoBitrate = "",
        [string]$FfmpegPath = "ffmpeg",
        [switch]$SplitOutput,
        [ValidateRange(0.001, 1024)]
        [double]$MaxPartGb = 3.8,
        [object[]]$Plan,
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
        [switch]$AudioNormalize,
        [string]$EncoderMode = "Auto",
        [object]$EncoderInventory,
        [scriptblock]$OnLog,
        [scriptblock]$OnStatusChange,
        [scriptblock]$ShouldStop,
        [hashtable]$SharedState
    )

    $context = New-VhsMp4RunContext `
        -InputDir $InputDir `
        -OutputDir $OutputDir `
        -QualityMode $QualityMode `
        -Crf $Crf `
        -Preset $Preset `
        -AudioBitrate $AudioBitrate `
        -VideoBitrate $VideoBitrate `
        -FfmpegPath $FfmpegPath `
        -SplitOutput:$SplitOutput `
        -MaxPartGb $MaxPartGb `
        -TrimStart $TrimStart `
        -TrimEnd $TrimEnd `
        -Deinterlace $Deinterlace `
        -Denoise $Denoise `
        -RotateFlip $RotateFlip `
        -ScaleMode $ScaleMode `
        -AudioNormalize:$AudioNormalize `
        -EncoderMode $EncoderMode `
        -EncoderInventory $EncoderInventory

    $items = if ($Plan -and $Plan.Count -gt 0) {
        @($Plan)
    }
    else {
        @(Get-VhsMp4Plan -InputDir $context.InputDir -OutputDir $context.OutputDir -FfmpegPath $context.FfmpegPath -SplitOutput:([bool]$context.SplitOutput))
    }
    $processedCount = 0
    $skippedCount = 0
    $failedCount = 0
    $stoppedCount = 0
    $stopNow = $false

    Write-VhsMp4Log -LogPath $context.LogPath -Message "InputDir: $($context.InputDir)" -OnLog $OnLog
    Write-VhsMp4Log -LogPath $context.LogPath -Message "OutputDir: $($context.OutputDir)" -OnLog $OnLog
    $videoBitrateLogText = if (-not [string]::IsNullOrWhiteSpace([string]$context.VideoBitrate)) { [string]$context.VideoBitrate } else { "auto/CRF" }
    Write-VhsMp4Log -LogPath $context.LogPath -Message "QualityMode: $($context.QualityMode) | CRF: $($context.Crf) | Preset: $($context.Preset) | VideoBitrate: $videoBitrateLogText | AudioBitrate: $($context.AudioBitrate)" -OnLog $OnLog
    Write-VhsMp4Log -LogPath $context.LogPath -Message "SplitOutput: $($context.SplitOutput) | MaxPartGb: $($context.MaxPartGb)" -OnLog $OnLog
    if (-not [string]::IsNullOrWhiteSpace([string]$context.FilterSummary)) {
        Write-VhsMp4Log -LogPath $context.LogPath -Message "Filters: $($context.FilterSummary)" -OnLog $OnLog
    }

    foreach ($item in $items) {
        $outputTarget = Get-VhsMp4ItemOutputTarget -Item $item -SplitOutput $context.SplitOutput

        if ($item.Status -eq "skipped") {
            $skippedCount++
            Write-VhsMp4Log -LogPath $context.LogPath -Message "SKIP: $($item.SourcePath) -> $outputTarget" -OnLog $OnLog
            if ($OnStatusChange) {
                & $OnStatusChange $item
            }
            continue
        }

        if ($ShouldStop -and (& $ShouldStop)) {
            $stopNow = $true
        }

        if ($stopNow) {
            $item.Status = "stopped"
            $stoppedCount++
            if ($OnStatusChange) {
                & $OnStatusChange $item
            }
            continue
        }

        $itemTrimStart = [string](Get-VhsMp4ObjectPropertyValue -Object $item -Name "TrimStartText")
        $itemTrimEnd = [string](Get-VhsMp4ObjectPropertyValue -Object $item -Name "TrimEndText")
        $itemTrimSegments = @(Get-VhsMp4ObjectPropertyValue -Object $item -Name "TrimSegments")
        if ([string]::IsNullOrWhiteSpace($itemTrimStart)) {
            $itemTrimStart = $context.TrimStart
        }
        if ([string]::IsNullOrWhiteSpace($itemTrimEnd)) {
            $itemTrimEnd = $context.TrimEnd
        }

        $itemTrimPlan = Get-VhsMp4EffectiveTrimPlan -TrimStart $itemTrimStart -TrimEnd $itemTrimEnd -TrimSegments $itemTrimSegments
        if (-not [string]::IsNullOrWhiteSpace([string]$itemTrimPlan.Summary)) {
            $item | Add-Member -NotePropertyName "TrimStartText" -NotePropertyValue $itemTrimPlan.StartText -Force
            $item | Add-Member -NotePropertyName "TrimEndText" -NotePropertyValue $itemTrimPlan.EndText -Force
            $item | Add-Member -NotePropertyName "TrimStartSeconds" -NotePropertyValue $itemTrimPlan.StartSeconds -Force
            $item | Add-Member -NotePropertyName "TrimEndSeconds" -NotePropertyValue $itemTrimPlan.EndSeconds -Force
            $item | Add-Member -NotePropertyName "TrimDurationSeconds" -NotePropertyValue $itemTrimPlan.DurationSeconds -Force
            $item | Add-Member -NotePropertyName "TrimSummary" -NotePropertyValue $itemTrimPlan.Summary -Force
            if ($itemTrimPlan.Count -gt 0) {
                $item | Add-Member -NotePropertyName "TrimSegments" -NotePropertyValue $itemTrimPlan.Segments -Force
            }
        }

        $item.Status = "running"
        if ($OnStatusChange) {
            & $OnStatusChange $item
        }

        try {
            $itemHasAudio = Test-VhsMp4PlanItemHasAudio -Item $item
            $result = Invoke-VhsMp4File `
                -SourcePath $item.SourcePath `
                -OutputPath $outputTarget `
                -FfmpegPath $context.FfmpegPath `
                -QualityMode $context.QualityMode `
                -Crf $context.Crf `
                -Preset $context.Preset `
                -AudioBitrate $context.AudioBitrate `
                -VideoBitrate $context.VideoBitrate `
                -SplitOutput:([bool]$context.SplitOutput) `
                -MaxPartGb $context.MaxPartGb `
                -TrimStart $itemTrimPlan.StartText `
                -TrimEnd $itemTrimPlan.EndText `
                -TrimSegments $itemTrimPlan.Segments `
                -SourceHasAudio $itemHasAudio `
                -Deinterlace $context.Deinterlace `
                -Denoise $context.Denoise `
                -RotateFlip $context.RotateFlip `
                -ScaleMode $context.ScaleMode `
                -AudioNormalize:([bool]$context.AudioNormalize) `
                -EncoderMode $context.EncoderMode `
                -EncoderInventory $context.EncoderInventory `
                -SharedState $SharedState

            if ($result.StdOut) {
                foreach ($line in ($result.StdOut -split "\r?\n")) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                        Write-VhsMp4Log -LogPath $context.LogPath -Message "FFMPEG: $line" -OnLog $OnLog
                    }
                }
            }

            if ($result.StdErr) {
                foreach ($line in ($result.StdErr -split "\r?\n")) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) {
                        Write-VhsMp4Log -LogPath $context.LogPath -Message "FFMPEG: $line" -OnLog $OnLog
                    }
                }
            }

            if (-not $result.Success) {
                throw "FFmpeg exit code: $($result.ExitCode)"
            }

            $item.Status = "done"
            $processedCount++
            Write-VhsMp4Log -LogPath $context.LogPath -Message "OK: $($item.SourcePath) -> $outputTarget" -OnLog $OnLog
        }
        catch {
            if ($ShouldStop -and (& $ShouldStop)) {
                $item.Status = "stopped"
                $stoppedCount++
                Write-VhsMp4Log -LogPath $context.LogPath -Message "STOP: $($item.SourcePath) -> $outputTarget | $($_.Exception.Message)" -OnLog $OnLog
                $stopNow = $true
            }
            else {
                $item.Status = "failed"
                $failedCount++
                Write-VhsMp4Log -LogPath $context.LogPath -Message "FAIL: $($item.SourcePath) -> $outputTarget | $($_.Exception.Message)" -OnLog $OnLog
            }
        }

        if ($OnStatusChange) {
            & $OnStatusChange $item
        }
    }

    $reportPath = Write-VhsMp4CustomerReport `
        -OutputDir $context.OutputDir `
        -Items $items `
        -QualityMode $context.QualityMode `
        -Crf $context.Crf `
        -Preset $context.Preset `
        -AudioBitrate $context.AudioBitrate `
        -VideoBitrate $context.VideoBitrate `
        -SplitOutput ([bool]$context.SplitOutput) `
        -MaxPartGb $context.MaxPartGb `
        -FilterSummary $context.FilterSummary
    Write-VhsMp4Log -LogPath $context.LogPath -Message "Report: $reportPath" -OnLog $OnLog

    return [pscustomobject]@{
        ProcessedCount = $processedCount
        SkippedCount = $skippedCount
        FailedCount = $failedCount
        StoppedCount = $stoppedCount
        OutputDir = $context.OutputDir
        LogPath = $context.LogPath
        ReportPath = $reportPath
        Items = $items
    }
}

Export-ModuleMember -Function @(
    "Resolve-VhsMp4CommandPath",
    "Find-VhsMp4InstalledFfmpeg",
    "Add-VhsMp4DirectoryToUserPath",
    "Update-VhsMp4ProcessPathFromEnvironment",
    "Get-VhsMp4ErrorMessage",
    "Get-VhsMp4ResolvedFfmpegPath",
    "Test-VhsMp4FfmpegPreflight",
    "Get-VhsMp4NormalizedEncoderMode",
    "Get-VhsMp4EncoderInventoryFromText",
    "Test-VhsMp4EncoderRuntime",
    "Get-VhsMp4EncoderInventory",
    "Resolve-VhsMp4VideoEncoderPlan",
    "Resolve-VhsMp4FfprobePath",
    "Get-VhsMp4MediaDurationSeconds",
    "Get-VhsMp4MediaInfo",
    "Convert-VhsMp4TimeTextToSeconds",
    "Format-VhsMp4FfmpegTime",
    "Get-VhsMp4TrimWindow",
    "Get-VhsMp4TrimSegments",
    "Get-VhsMp4CropState",
    "Get-VhsMp4NormalizedAspectMode",
    "Get-VhsMp4AspectConfidence",
    "Get-VhsMp4DetectedAspect",
    "Get-VhsMp4AspectState",
    "Get-VhsMp4AspectSnapshot",
    "Get-VhsMp4AspectTargetGeometry",
    "Get-VhsMp4AspectAwareScaleFilter",
    "Test-VhsMp4CropState",
    "Get-VhsMp4CropFilter",
    "Get-VhsMp4CropDetectionSampleTimes",
    "Get-VhsMp4DetectedCrop",
    "Get-VhsMp4DetectedCropFromSourcePath",
    "New-VhsMp4RunContext",
    "Write-VhsMp4Log",
    "Get-VhsMp4SupportedExtensions",
    "Get-VhsMp4QualityProfile",
    "Get-VhsMp4VideoFilterChain",
    "Get-VhsMp4AudioFilterChain",
    "Get-VhsMp4FilterSummary",
    "Get-VhsMp4SplitVideoMaxKbps",
    "Get-VhsMp4SplitSegmentSeconds",
    "Get-VhsMp4EstimatedOutputInfo",
    "Get-VhsMp4SampleOutputPath",
    "Write-VhsMp4CustomerReport",
    "Get-VhsMp4Plan",
    "Get-VhsMp4PlanFromPaths",
    "Get-VhsMp4FfmpegArguments",
    "New-VhsMp4PreviewFrame",
    "Invoke-VhsMp4CopySplit",
    "Invoke-VhsMp4CopyJoin",
    "Start-VhsMp4FileProcess",
    "Complete-VhsMp4FileProcess",
    "Invoke-VhsMp4File",
    "Invoke-VhsMp4Batch"
)
