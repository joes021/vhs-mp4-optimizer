Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName WindowsFormsIntegration

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"
Import-Module $modulePath -Force

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:WingetPackageId = "Gyan.FFmpeg.Essentials"
$script:PlanItems = @()
$script:LastLogPath = $null
$script:LastReportPath = $null
$script:ResolvedFfmpegPath = $null
$script:BatchContext = $null
$script:CurrentBatchIndex = -1
$script:CurrentProcess = $null
$script:CurrentPlanItem = $null
$script:CurrentProgressPath = $null
$script:CurrentDurationSeconds = $null
$script:CurrentFileStartedAt = $null
$script:PollTimer = New-Object System.Windows.Forms.Timer
$script:PollTimer.Interval = 250
$script:WorkspaceTopSectionRatio = 0.5
$script:WorkspaceMiddleSectionRatio = 0.6
$script:WorkspaceVerticalSectionRatio = 0.5
$script:LayoutStateApplying = $false
$script:AdvancedVisibilityUserOverride = $false
$script:PreviewTimelineScale = 100
$script:PreviewAutoPending = $false
$script:PreviewAutoDelayMs = 250
$script:PendingTrimSegmentIndex = -1
$script:PlayerTrimEditorWindow = $null
$script:PlayerTrimEditorSourcePath = ""
$script:PlayerTrimEditorBounds = $null
$script:DragDropActive = $false
$script:LastNormalStatusText = ""
$script:DragDropAccentColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
$script:DragDropPanelBackColor = [System.Drawing.Color]::FromArgb(236, 253, 245)
$script:DragDropGridBackColor = [System.Drawing.Color]::FromArgb(220, 252, 231)
$script:DragDropGridRowBackColor = [System.Drawing.Color]::FromArgb(240, 253, 244)
$script:DragDropGridAltRowBackColor = [System.Drawing.Color]::FromArgb(229, 246, 236)
$script:DragDropVisualDefaults = $null
$script:SharedState = [hashtable]::Synchronized(@{
    StopRequested = $false
    CurrentProcessId = $null
})
$script:AppIconPath = Join-Path (Split-Path $PSScriptRoot -Parent) "assets\vhs-mp4-optimizer.ico"
$script:NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
$script:NotifyIcon.Text = "Video Converter"
$script:NotifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$script:WorkflowPresetCustomName = "Custom"
$script:WorkflowPresetDefaultName = "USB standard"
$script:WorkflowPresetState = $null
$script:WorkflowPresetApplying = $false
$script:WorkflowPresetSuppressSelection = $false
$script:WorkflowPresetStorageWarning = ""
$script:QualityModeSeparatorLabel = "---------------- Device presets ----------------"
$script:QualityModeLastSelection = "Universal MP4 H.264"
$script:EncoderInventory = $null
$script:EncoderModeDefaultName = "Auto"
$script:EncoderModeCpuLabel = "CPU (libx264/libx265)"
$script:EncoderModeLabels = @(
    $script:EncoderModeDefaultName,
    $script:EncoderModeCpuLabel,
    "NVIDIA NVENC",
    "Intel QSV",
    "AMD AMF"
)
$script:AspectModeControlSync = $false
$script:AspectModeBatchActionLabel = "Copy Aspect to All"
$script:AspectModeOptionLabels = @("Keep Original", "Force 4:3", "Force 16:9")
$script:AdvancedSettingsVisible = $false
$script:GitHubLatestReleaseApi = "https://api.github.com/repos/joes021/vhs-mp4-optimizer/releases/latest"
$script:ApplicationMetadata = $null
$script:UpdateCheckState = $null
$script:UpdateCheckInProgress = $false
$script:AutoFfmpegBootstrapAttempted = $false
$script:AutoFfmpegBootstrapInProgress = $false
if (Test-Path -LiteralPath $script:AppIconPath) {
    $script:NotifyIcon.Icon = New-Object System.Drawing.Icon $script:AppIconPath
}
$script:NotifyIcon.Visible = $true

function Add-LogLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    if ($null -eq $logTextBox) {
        return
    }

    $logTextBox.AppendText($Text + [Environment]::NewLine)
    $logTextBox.SelectionStart = $logTextBox.TextLength
    $logTextBox.ScrollToCaret()
}

function Set-StatusText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    if (-not $script:DragDropActive) {
        $script:LastNormalStatusText = $Text
    }

    $statusValueLabel.Text = $Text
}

function Set-MainSplitLayout {
    $splitVariable = Get-Variable -Name mainSplit -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $splitVariable) {
        return
    }

    $split = $splitVariable.Value
    if ($null -eq $split -or $split.Width -le 0) {
        return
    }

    $split.Panel1MinSize = 280
    $split.Panel2MinSize = 280
    $availableWidth = $split.Width - $split.SplitterWidth
    if ($availableWidth -le 0) {
        return
    }

    $desiredDistance = [int][Math]::Round($availableWidth * [double]$script:WorkspaceVerticalSectionRatio, 0, [System.MidpointRounding]::AwayFromZero)
    $maxDistance = $split.Width - $split.Panel2MinSize - $split.SplitterWidth
    $distance = [Math]::Max($split.Panel1MinSize, $desiredDistance)
    $distance = [Math]::Min($distance, $maxDistance)
    if ($distance -gt 0 -and $distance -ne $split.SplitterDistance) {
        $split.SplitterDistance = $distance
    }
}

function Set-WorkspaceSplitLayout {
    $splitVariable = Get-Variable -Name workspaceSplit -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $splitVariable) {
        return
    }

    $split = $splitVariable.Value
    if ($null -eq $split -or $split.Height -le 0) {
        return
    }

    $split.Panel1MinSize = 250
    $split.Panel2MinSize = 240
    $availableHeight = $split.Height - $split.SplitterWidth
    if ($availableHeight -le 0) {
        return
    }

    $desiredDistance = [int][Math]::Round($availableHeight * [double]$script:WorkspaceTopSectionRatio, 0, [System.MidpointRounding]::AwayFromZero)
    $maxDistance = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
    $distance = [Math]::Max($split.Panel1MinSize, $desiredDistance)
    $distance = [Math]::Min($distance, $maxDistance)
    if ($distance -gt 0 -and $distance -ne $split.SplitterDistance) {
        $split.SplitterDistance = $distance
    }
}

function Set-LowerWorkspaceSplitLayout {
    $splitVariable = Get-Variable -Name lowerWorkspaceSplit -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $splitVariable) {
        return
    }

    $split = $splitVariable.Value
    if ($null -eq $split -or $split.Height -le 0) {
        return
    }

    $split.Panel1MinSize = 220
    $split.Panel2MinSize = 180
    $availableHeight = $split.Height - $split.SplitterWidth
    if ($availableHeight -le 0) {
        return
    }

    $desiredDistance = [int][Math]::Round($availableHeight * [double]$script:WorkspaceMiddleSectionRatio, 0, [System.MidpointRounding]::AwayFromZero)
    $maxDistance = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
    $distance = [Math]::Max($split.Panel1MinSize, $desiredDistance)
    $distance = [Math]::Min($distance, $maxDistance)
    if ($distance -gt 0 -and $distance -ne $split.SplitterDistance) {
        $split.SplitterDistance = $distance
    }
}

function Set-DetailsSplitLayout {
    $splitVariable = Get-Variable -Name detailsSplit -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $splitVariable) {
        return
    }

    $split = $splitVariable.Value
    if ($null -eq $split -or $split.Height -le 0) {
        return
    }

    $split.Panel1MinSize = 180
    $split.Panel2MinSize = 180
    $desiredTopHeight = [Math]::Max($split.Panel1MinSize, $split.Height - 300 - $split.SplitterWidth)
    $maxDistance = $split.Height - $split.Panel2MinSize - $split.SplitterWidth
    $distance = [Math]::Max($split.Panel1MinSize, $desiredTopHeight)
    $distance = [Math]::Min($distance, $maxDistance)
    if ($distance -gt 0 -and $distance -ne $split.SplitterDistance) {
        $split.SplitterDistance = $distance
    }
}

function Set-AdvancedSettingsVisibility {
    param(
        [bool]$Visible,
        [switch]$UserInitiated
    )

    $script:AdvancedSettingsVisible = $Visible
    if ($UserInitiated) {
        $script:AdvancedVisibilityUserOverride = $true
    }

    if (Get-Variable -Name "advancedSettingsGroupBox" -ErrorAction SilentlyContinue) {
        $advancedSettingsGroupBox.Visible = $Visible
    }

    if (Get-Variable -Name "advancedToggleButton" -ErrorAction SilentlyContinue) {
        $advancedToggleButton.Text = if ($Visible) { "Hide Advanced" } else { "Show Advanced" }
    }

    if (Get-Variable -Name "topWorkspaceLayout" -ErrorAction SilentlyContinue) {
        if ($topWorkspaceLayout.RowStyles.Count -ge 3) {
            $topWorkspaceLayout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::AutoSize
            $topWorkspaceLayout.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::AutoSize
            if ($Visible) {
                $topWorkspaceLayout.RowStyles[2].SizeType = [System.Windows.Forms.SizeType]::Percent
                $topWorkspaceLayout.RowStyles[2].Height = 100
            }
            else {
                $topWorkspaceLayout.RowStyles[2].SizeType = [System.Windows.Forms.SizeType]::Absolute
                $topWorkspaceLayout.RowStyles[2].Height = 0
            }
        }
        $topWorkspaceLayout.PerformLayout()
    }
}

function Get-DefaultWorkspaceLayoutState {
    return [pscustomobject]@{
        TopSectionRatio = 0.5
        MiddleSectionRatio = 0.6
        VerticalSectionRatio = 0.5
        AdvancedVisible = $true
        AdvancedVisibilityUserOverride = $false
    }
}

function Get-CurrentWorkspaceLayoutState {
    return [pscustomobject]@{
        TopSectionRatio = [double]$script:WorkspaceTopSectionRatio
        MiddleSectionRatio = [double]$script:WorkspaceMiddleSectionRatio
        VerticalSectionRatio = [double]$script:WorkspaceVerticalSectionRatio
        AdvancedVisible = [bool]$script:AdvancedSettingsVisible
        AdvancedVisibilityUserOverride = [bool]$script:AdvancedVisibilityUserOverride
    }
}

function Convert-GuiOptionalDouble {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }

    $result = 0.0
    if ([double]::TryParse($text.Trim().Replace(",", "."), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$result)) {
        return [double]$result
    }

    return $null
}

function Apply-WorkspaceLayoutState {
    param(
        [AllowNull()]
        [object]$LayoutState
    )

    $defaultLayout = Get-DefaultWorkspaceLayoutState
    $topRatio = Convert-GuiOptionalDouble -Value (Get-WorkflowPresetObjectValue -Object $LayoutState -Name "TopSectionRatio")
    $middleRatio = Convert-GuiOptionalDouble -Value (Get-WorkflowPresetObjectValue -Object $LayoutState -Name "MiddleSectionRatio")
    $verticalRatio = Convert-GuiOptionalDouble -Value (Get-WorkflowPresetObjectValue -Object $LayoutState -Name "VerticalSectionRatio")
    $advancedVisible = Get-WorkflowPresetObjectValue -Object $LayoutState -Name "AdvancedVisible"
    $advancedUserOverride = Get-WorkflowPresetObjectValue -Object $LayoutState -Name "AdvancedVisibilityUserOverride"

    $script:WorkspaceTopSectionRatio = if ($null -ne $topRatio -and $topRatio -ge 0.25 -and $topRatio -le 0.75) { [double]$topRatio } else { [double]$defaultLayout.TopSectionRatio }
    $script:WorkspaceMiddleSectionRatio = if ($null -ne $middleRatio -and $middleRatio -ge 0.30 -and $middleRatio -le 0.80) { [double]$middleRatio } else { [double]$defaultLayout.MiddleSectionRatio }
    $script:WorkspaceVerticalSectionRatio = if ($null -ne $verticalRatio -and $verticalRatio -ge 0.25 -and $verticalRatio -le 0.75) { [double]$verticalRatio } else { [double]$defaultLayout.VerticalSectionRatio }
    $useSavedAdvancedPreference = $false
    if ($null -ne $advancedUserOverride) {
        $useSavedAdvancedPreference = [bool]$advancedUserOverride
    }

    $script:AdvancedVisibilityUserOverride = $useSavedAdvancedPreference
    $resolvedAdvancedVisible = if (-not $useSavedAdvancedPreference) {
        [bool]$defaultLayout.AdvancedVisible
    }
    elseif ($null -eq $advancedVisible) {
        [bool]$defaultLayout.AdvancedVisible
    }
    else {
        [bool]$advancedVisible
    }

    $script:LayoutStateApplying = $true
    try {
        Set-AdvancedSettingsVisibility -Visible:$resolvedAdvancedVisible
        if (Get-Variable -Name form -ErrorAction SilentlyContinue) {
            $form.PerformLayout()
            [System.Windows.Forms.Application]::DoEvents()
        }
        Set-WorkspaceSplitLayout
        Set-LowerWorkspaceSplitLayout
        if (Get-Variable -Name form -ErrorAction SilentlyContinue) {
            $form.PerformLayout()
            [System.Windows.Forms.Application]::DoEvents()
        }
        Set-MainSplitLayout
        Set-DetailsSplitLayout
        if (Get-Variable -Name form -ErrorAction SilentlyContinue) {
            $form.PerformLayout()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    finally {
        $script:LayoutStateApplying = $false
    }
}

function Restore-DefaultLayout {
    $script:AdvancedVisibilityUserOverride = $false
    Apply-WorkspaceLayoutState -LayoutState (Get-DefaultWorkspaceLayoutState)
    Save-WorkflowPresetStartupState
}

function Format-VhsMp4KbpsText {
    param($Kbps)

    if ($null -eq $Kbps -or $Kbps -le 0) {
        return "--"
    }

    return "$Kbps kbps"
}

function Test-GuiPathEquals {
    param(
        [string]$Left,
        [string]$Right
    )

    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) {
        return $false
    }

    $leftFull = [System.IO.Path]::GetFullPath($Left).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $rightFull = [System.IO.Path]::GetFullPath($Right).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return [string]::Equals($leftFull, $rightFull, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CommonDroppedDirectory {
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
            if (-not (Test-GuiPathEquals -Left $path -Right $commonPath) -and -not $path.StartsWith(([System.IO.Path]::GetFullPath($commonPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
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

function Get-DroppedSelectionInputDir {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    $candidateDirectories = New-Object System.Collections.Generic.List[string]
    foreach ($path in $Paths) {
        if ([string]::IsNullOrWhiteSpace([string]$path) -or -not (Test-Path -LiteralPath $path)) {
            continue
        }

        $item = Get-Item -LiteralPath $path -Force
        if ($item.PSIsContainer) {
            $candidateDirectories.Add([System.IO.Path]::GetFullPath($item.FullName))
        }
        else {
            $candidateDirectories.Add([System.IO.Path]::GetFullPath((Split-Path -Path $item.FullName -Parent)))
        }
    }

    if ($candidateDirectories.Count -eq 0) {
        return ""
    }

    if ($candidateDirectories.Count -eq 1) {
        return [string]$candidateDirectories[0]
    }

    $commonDirectory = Get-CommonDroppedDirectory -Paths $candidateDirectories
    if (-not [string]::IsNullOrWhiteSpace($commonDirectory)) {
        return $commonDirectory
    }

    return [string]$candidateDirectories[0]
}

function Set-SuggestedOutputDirForInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputDir,
        [string]$PreviousInputDir = ""
    )

    $suggestedOutputDir = Join-Path $InputDir "vhs-mp4-output"
    $shouldSetOutput = [string]::IsNullOrWhiteSpace($outputTextBox.Text)

    if (-not $shouldSetOutput -and -not [string]::IsNullOrWhiteSpace($PreviousInputDir)) {
        $previousDefaultOutput = Join-Path $PreviousInputDir "vhs-mp4-output"
        $shouldSetOutput = Test-GuiPathEquals -Left $outputTextBox.Text -Right $previousDefaultOutput
    }

    if ($shouldSetOutput) {
        $outputTextBox.Text = $suggestedOutputDir
    }
}

function Get-WorkflowPresetObjectValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object -or [string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) {
        return $Object[$Name]
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function New-WorkflowPresetSettingsObject {
    param(
        [object]$Settings
    )

    $crfValue = 22
    $rawCrf = Get-WorkflowPresetObjectValue -Object $Settings -Name "Crf"
    if ($rawCrf -is [int]) {
        $crfValue = [int]$rawCrf
    }
    else {
        [void][int]::TryParse([string]$rawCrf, [ref]$crfValue)
    }

    $maxPartGb = 3.8
    $rawMaxPartGb = Get-WorkflowPresetObjectValue -Object $Settings -Name "MaxPartGb"
    $style = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    if ($rawMaxPartGb -is [double]) {
        $maxPartGb = [double]$rawMaxPartGb
    }
    elseif ($null -ne $rawMaxPartGb) {
        $maxPartText = ([string]$rawMaxPartGb).Trim().Replace(",", ".")
        [void][double]::TryParse($maxPartText, $style, $culture, [ref]$maxPartGb)
    }

    $qualityMode = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "QualityMode")
    $videoBitrate = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "VideoBitrate")
    if ([string]::IsNullOrWhiteSpace($videoBitrate) -and -not [string]::IsNullOrWhiteSpace($qualityMode) -and $qualityMode -ne "Custom") {
        $videoBitrate = Get-QualityModeSuggestedVideoBitrate -QualityMode $qualityMode
    }

    return [pscustomobject]@{
        QualityMode = $qualityMode
        Crf = [Math]::Min(51, [Math]::Max(0, $crfValue))
        Preset = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "Preset")
        AudioBitrate = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "AudioBitrate")
        VideoBitrate = $videoBitrate
        Deinterlace = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "Deinterlace")
        Denoise = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "Denoise")
        RotateFlip = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "RotateFlip")
        ScaleMode = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "ScaleMode")
        AudioNormalize = [bool](Get-WorkflowPresetObjectValue -Object $Settings -Name "AudioNormalize")
        EncoderMode = [string](Get-WorkflowPresetObjectValue -Object $Settings -Name "EncoderMode")
        SplitOutput = [bool](Get-WorkflowPresetObjectValue -Object $Settings -Name "SplitOutput")
        AutoApplyCrop = [bool](Get-WorkflowPresetObjectValue -Object $Settings -Name "AutoApplyCrop")
        MaxPartGb = [Math]::Min(1024.0, [Math]::Max(0.001, $maxPartGb))
    }
}

function New-WorkflowPresetObject {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Kind = "BuiltIn",
        [string]$Description = "",
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    return [pscustomobject]@{
        Name = $Name.Trim()
        Kind = $Kind
        Description = $Description.Trim()
        Settings = New-WorkflowPresetSettingsObject -Settings $Settings
    }
}

function Get-QualityModeSelectionDefinitions {
    return @(
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Universal MP4 H.264"
            InternalQualityMode = "Universal MP4 H.264"
            SuggestedCrf = 22
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "6000k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Small MP4 H.264"
            InternalQualityMode = "Small MP4 H.264"
            SuggestedCrf = 24
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "3500k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "High Quality MP4 H.264"
            InternalQualityMode = "High Quality MP4 H.264"
            SuggestedCrf = 20
            SuggestedAudioBitrate = "192k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "9000k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "HEVC H.265 Smaller"
            InternalQualityMode = "HEVC H.265 Smaller"
            SuggestedCrf = 26
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "medium"
            SuggestedVideoBitrate = "2800k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Standard VHS"
            InternalQualityMode = "Standard VHS"
            SuggestedCrf = 22
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "5000k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Smaller File"
            InternalQualityMode = "Smaller File"
            SuggestedCrf = 24
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "3500k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Better Quality"
            InternalQualityMode = "Better Quality"
            SuggestedCrf = 20
            SuggestedAudioBitrate = "192k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "9000k"
        }
        [pscustomobject]@{
            Group = "Base"
            DisplayName = "Custom"
            InternalQualityMode = "Custom"
            SuggestedCrf = 22
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = ""
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "TV / univerzalni Smart TV"
            InternalQualityMode = "Universal MP4 H.264"
            SuggestedCrf = 22
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "6500k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "Stari TV / media player"
            InternalQualityMode = "Universal MP4 H.264"
            SuggestedCrf = 23
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "medium"
            SuggestedVideoBitrate = "4500k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "Laptop / PC"
            InternalQualityMode = "Universal MP4 H.264"
            SuggestedCrf = 22
            SuggestedAudioBitrate = "160k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "5500k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "Telefon"
            InternalQualityMode = "Small MP4 H.264"
            SuggestedCrf = 24
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "2200k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "Tablet"
            InternalQualityMode = "Small MP4 H.264"
            SuggestedCrf = 23
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "3200k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "YouTube upload"
            InternalQualityMode = "High Quality MP4 H.264"
            SuggestedCrf = 19
            SuggestedAudioBitrate = "192k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "12000k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "USB mali fajl"
            InternalQualityMode = "Small MP4 H.264"
            SuggestedCrf = 25
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "medium"
            SuggestedVideoBitrate = "3000k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "Arhiva / bolji kvalitet"
            InternalQualityMode = "High Quality MP4 H.264"
            SuggestedCrf = 19
            SuggestedAudioBitrate = "192k"
            SuggestedPreset = "slow"
            SuggestedVideoBitrate = "10000k"
        }
        [pscustomobject]@{
            Group = "Device"
            DisplayName = "HEVC za novije uredjaje"
            InternalQualityMode = "HEVC H.265 Smaller"
            SuggestedCrf = 25
            SuggestedAudioBitrate = "128k"
            SuggestedPreset = "medium"
            SuggestedVideoBitrate = "3200k"
        }
    )
}

function Resolve-QualityModeSelection {
    param(
        [string]$QualityMode
    )

    $normalizedQualityMode = [string]$QualityMode
    if ([string]::IsNullOrWhiteSpace($normalizedQualityMode)) {
        $normalizedQualityMode = "Universal MP4 H.264"
    }
    elseif ($normalizedQualityMode -eq $script:QualityModeSeparatorLabel) {
        $normalizedQualityMode = if ([string]::IsNullOrWhiteSpace($script:QualityModeLastSelection)) { "Universal MP4 H.264" } else { [string]$script:QualityModeLastSelection }
    }

    foreach ($definition in @(Get-QualityModeSelectionDefinitions)) {
        if ($normalizedQualityMode -eq [string]$definition.DisplayName -or $normalizedQualityMode -eq [string]$definition.InternalQualityMode) {
            return $definition
        }
    }

    return [pscustomobject]@{
        Group = "Base"
        DisplayName = $normalizedQualityMode
        InternalQualityMode = $normalizedQualityMode
        SuggestedCrf = 22
        SuggestedAudioBitrate = "160k"
        SuggestedPreset = "slow"
        SuggestedVideoBitrate = "6000k"
    }
}

function Get-QualityModeComboItems {
    $items = New-Object System.Collections.Generic.List[string]
    foreach ($definition in @(Get-QualityModeSelectionDefinitions | Where-Object { [string]$_.Group -eq "Base" })) {
        $items.Add([string]$definition.DisplayName)
    }
    $items.Add($script:QualityModeSeparatorLabel)
    foreach ($definition in @(Get-QualityModeSelectionDefinitions | Where-Object { [string]$_.Group -eq "Device" })) {
        $items.Add([string]$definition.DisplayName)
    }
    return @($items.ToArray())
}

function Get-QualityModeSelectionDisplayName {
    param(
        [string]$QualityMode
    )

    return [string](Resolve-QualityModeSelection -QualityMode $QualityMode).DisplayName
}

function Get-CurrentQualityModeSelectionLabel {
    $selection = if (Get-Variable -Name qualityModeComboBox -ErrorAction SilentlyContinue) { [string]$qualityModeComboBox.SelectedItem } else { "" }
    if ([string]::IsNullOrWhiteSpace($selection) -or $selection -eq $script:QualityModeSeparatorLabel) {
        if (-not [string]::IsNullOrWhiteSpace($script:QualityModeLastSelection)) {
            return [string]$script:QualityModeLastSelection
        }
        return "Universal MP4 H.264"
    }

    return $selection
}

function Get-CurrentInternalQualityModeName {
    return [string](Resolve-QualityModeSelection -QualityMode (Get-CurrentQualityModeSelectionLabel)).InternalQualityMode
}

function Get-QualityModeSuggestedVideoBitrate {
    param(
        [string]$QualityMode
    )

    return [string](Resolve-QualityModeSelection -QualityMode $QualityMode).SuggestedVideoBitrate
}

function Get-WorkflowPresetDefinitions {
    $presets = New-Object System.Collections.Generic.List[object]
    $presets.Add((New-WorkflowPresetObject -Name "USB standard" -Kind "BuiltIn" -Description "USB standard za predaju: univerzalni MP4 H.264, split ukljucen i procena prilagodjena USB radu." -Settings @{
                QualityMode = "Universal MP4 H.264"
                Crf = 22
                Preset = "slow"
                AudioBitrate = "160k"
                VideoBitrate = (Get-QualityModeSuggestedVideoBitrate -QualityMode "Universal MP4 H.264")
                Deinterlace = "Off"
                Denoise = "Off"
                RotateFlip = "None"
                ScaleMode = "Original"
                AudioNormalize = $false
                EncoderMode = "Auto"
                SplitOutput = $true
                AutoApplyCrop = $false
                MaxPartGb = 3.8
            }))
    $presets.Add((New-WorkflowPresetObject -Name "Mali fajl" -Kind "BuiltIn" -Description "Mali fajl za laksu predaju: smanjen bitrate/profil i split po potrebi." -Settings @{
                QualityMode = "Small MP4 H.264"
                Crf = 24
                Preset = "slow"
                AudioBitrate = "128k"
                VideoBitrate = (Get-QualityModeSuggestedVideoBitrate -QualityMode "Small MP4 H.264")
                Deinterlace = "Off"
                Denoise = "Off"
                RotateFlip = "None"
                ScaleMode = "Original"
                AudioNormalize = $false
                EncoderMode = "Auto"
                SplitOutput = $true
                AutoApplyCrop = $false
                MaxPartGb = 3.8
            }))
    $presets.Add((New-WorkflowPresetObject -Name "High quality arhiva" -Kind "BuiltIn" -Description "High quality arhiva: veci kvalitet i bez obaveznog splitovanja, za dugorocno cuvanje." -Settings @{
                QualityMode = "High Quality MP4 H.264"
                Crf = 20
                Preset = "slow"
                AudioBitrate = "192k"
                VideoBitrate = (Get-QualityModeSuggestedVideoBitrate -QualityMode "High Quality MP4 H.264")
                Deinterlace = "Off"
                Denoise = "Off"
                RotateFlip = "None"
                ScaleMode = "Original"
                AudioNormalize = $false
                EncoderMode = "Auto"
                SplitOutput = $false
                AutoApplyCrop = $false
                MaxPartGb = 3.8
            }))
    $presets.Add((New-WorkflowPresetObject -Name "HEVC manji fajl" -Kind "BuiltIn" -Description "HEVC manji fajl: H.265 za manju velicinu kada je bitniji prostor nego kompatibilnost." -Settings @{
                QualityMode = "HEVC H.265 Smaller"
                Crf = 26
                Preset = "medium"
                AudioBitrate = "128k"
                VideoBitrate = (Get-QualityModeSuggestedVideoBitrate -QualityMode "HEVC H.265 Smaller")
                Deinterlace = "Off"
                Denoise = "Off"
                RotateFlip = "None"
                ScaleMode = "Original"
                AudioNormalize = $false
                EncoderMode = "Auto"
                SplitOutput = $true
                AutoApplyCrop = $false
                MaxPartGb = 3.8
            }))
    $presets.Add((New-WorkflowPresetObject -Name "VHS cleanup" -Kind "BuiltIn" -Description "VHS cleanup: podrazumevani VHS kvalitet uz deinterlace, lagani denoise i normalizaciju zvuka." -Settings @{
                QualityMode = "Standard VHS"
                Crf = 22
                Preset = "slow"
                AudioBitrate = "160k"
                VideoBitrate = (Get-QualityModeSuggestedVideoBitrate -QualityMode "Standard VHS")
                Deinterlace = "YADIF"
                Denoise = "Light"
                RotateFlip = "None"
                ScaleMode = "PAL 576p"
                AudioNormalize = $true
                EncoderMode = "Auto"
                SplitOutput = $true
                AutoApplyCrop = $true
                MaxPartGb = 3.8
            }))
    return @($presets.ToArray())
}

function Get-WorkflowPresetStorageRoot {
    return (Join-Path ([Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)) "VhsMp4Optimizer")
}

function Get-WorkflowPresetStoragePath {
    return (Join-Path (Get-WorkflowPresetStorageRoot) "workflow-presets.json")
}

function Get-WorkflowAppStatePath {
    return (Join-Path (Get-WorkflowPresetStorageRoot) "workflow-state.json")
}

function Ensure-WorkflowPresetStorageDirectory {
    $root = Get-WorkflowPresetStorageRoot
    $null = New-Item -ItemType Directory -Path $root -Force
    return $root
}

function Get-AllWorkflowPresets {
    if ($null -eq $script:WorkflowPresetState) {
        $script:WorkflowPresetState = Import-WorkflowPresetState
    }

    $all = New-Object System.Collections.Generic.List[object]
    foreach ($preset in @($script:WorkflowPresetState.BuiltInPresets)) {
        $all.Add($preset)
    }
    foreach ($preset in @($script:WorkflowPresetState.UserPresets | Sort-Object Name)) {
        $all.Add($preset)
    }
    return @($all.ToArray())
}

function Find-WorkflowPresetByName {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -eq $script:WorkflowPresetCustomName) {
        return $null
    }

    foreach ($preset in @(Get-AllWorkflowPresets)) {
        if ([string]::Equals([string]$preset.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $preset
        }
    }

    return $null
}

function Import-WorkflowPresetState {
    $builtInPresets = @(Get-WorkflowPresetDefinitions)
    $userPresets = @()
    $loadError = ""
    $storagePath = Get-WorkflowPresetStoragePath

    if (Test-Path -LiteralPath $storagePath) {
        try {
            $rawContent = Get-Content -LiteralPath $storagePath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($rawContent)) {
                $parsed = ConvertFrom-Json -InputObject $rawContent -ErrorAction Stop
                $rawUserPresets = if ($parsed -is [System.Array]) {
                    @($parsed)
                }
                elseif ($parsed.PSObject.Properties["UserPresets"]) {
                    @($parsed.UserPresets)
                }
                else {
                    @()
                }

                foreach ($entry in $rawUserPresets) {
                    $name = [string](Get-WorkflowPresetObjectValue -Object $entry -Name "Name")
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        continue
                    }

                    $userPresets += (New-WorkflowPresetObject -Name $name -Kind "User" -Description ([string](Get-WorkflowPresetObjectValue -Object $entry -Name "Description")) -Settings (Get-WorkflowPresetObjectValue -Object $entry -Name "Settings"))
                }
            }
        }
        catch {
            $loadError = "Workflow preset storage nije ispravan; vracam built-in preset-e."
            $userPresets = @()
        }
    }

    return [pscustomobject]@{
        BuiltInPresets = $builtInPresets
        UserPresets = @($userPresets | Sort-Object Name)
        LoadError = $loadError
    }
}

function Export-WorkflowPresetState {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$UserPresets
    )

    Ensure-WorkflowPresetStorageDirectory | Out-Null
    $payload = [pscustomobject]@{
        SchemaVersion = 1
        UserPresets = @($UserPresets | ForEach-Object {
                [pscustomobject]@{
                    Name = [string]$_.Name
                    Description = [string]$_.Description
                    Settings = New-WorkflowPresetSettingsObject -Settings $_.Settings
                }
            })
    }

    $json = $payload | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath (Get-WorkflowPresetStoragePath) -Value $json -Encoding UTF8
}

function Import-WorkflowAppState {
    $appStatePath = Get-WorkflowAppStatePath
    if (-not (Test-Path -LiteralPath $appStatePath)) {
        return [pscustomobject]@{
            LastPresetName = ""
            LastGeneralSettings = $null
            LayoutState = $null
        }
    }

    try {
        $rawContent = Get-Content -LiteralPath $appStatePath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($rawContent)) {
            throw "Prazan workflow app state."
        }

        $parsed = ConvertFrom-Json -InputObject $rawContent -ErrorAction Stop
        return [pscustomobject]@{
            LastPresetName = [string](Get-WorkflowPresetObjectValue -Object $parsed -Name "LastPresetName")
            LastGeneralSettings = (Get-WorkflowPresetObjectValue -Object $parsed -Name "LastGeneralSettings")
            LayoutState = (Get-WorkflowPresetObjectValue -Object $parsed -Name "LayoutState")
        }
    }
    catch {
        return [pscustomobject]@{
            LastPresetName = ""
            LastGeneralSettings = $null
            LayoutState = $null
        }
    }
}

function Export-WorkflowAppState {
    param(
        [string]$LastPresetName,
        [object]$LastGeneralSettings,
        [object]$LayoutState = $null
    )

    Ensure-WorkflowPresetStorageDirectory | Out-Null
    $payload = [pscustomobject]@{
        SchemaVersion = 1
        LastPresetName = $LastPresetName
        LastGeneralSettings = if ($null -ne $LastGeneralSettings) { New-WorkflowPresetSettingsObject -Settings $LastGeneralSettings } else { $null }
        LayoutState = if ($null -ne $LayoutState) { $LayoutState } else { Get-CurrentWorkspaceLayoutState }
    }

    $json = $payload | ConvertTo-Json -Depth 8
    Set-Content -LiteralPath (Get-WorkflowAppStatePath) -Value $json -Encoding UTF8
}

function Get-AppMetadataPath {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) "app-manifest.json")
}

function Get-UpdateStatePath {
    return (Join-Path (Get-WorkflowPresetStorageRoot) "update-state.json")
}

function Get-VhsMp4InstallRoot {
    return [System.IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
}

function Get-VhsMp4ApplicationMetadata {
    param(
        [switch]$Refresh
    )

    if (-not $Refresh -and $null -ne $script:ApplicationMetadata) {
        return $script:ApplicationMetadata
    }

    $defaultRepository = "joes021/vhs-mp4-optimizer"
    $metadata = [ordered]@{
        AppName = "VHS MP4 Optimizer"
        Version = "dev"
        GitRef = "local"
        ReleaseTag = ""
        Repository = $defaultRepository
        LatestReleaseApi = $script:GitHubLatestReleaseApi
        ReleasesPage = "https://github.com/$defaultRepository/releases"
        BuiltAtUtc = ""
    }

    $appMetadataPath = Get-AppMetadataPath
    if (Test-Path -LiteralPath $appMetadataPath) {
        try {
            $parsed = Get-Content -LiteralPath $appMetadataPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            foreach ($propertyName in @("AppName", "Version", "GitRef", "ReleaseTag", "Repository", "LatestReleaseApi", "ReleasesPage", "BuiltAtUtc")) {
                $value = Get-WorkflowPresetObjectValue -Object $parsed -Name $propertyName
                if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                    $metadata[$propertyName] = [string]$value
                }
            }
        }
        catch {
            Add-LogLine -Text ("App metadata warning: " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$metadata.LatestReleaseApi)) {
        $metadata.LatestReleaseApi = "https://api.github.com/repos/$($metadata.Repository)/releases/latest"
    }
    if ([string]::IsNullOrWhiteSpace([string]$metadata.ReleasesPage)) {
        $metadata.ReleasesPage = "https://github.com/$($metadata.Repository)/releases"
    }

    $script:ApplicationMetadata = [pscustomobject]$metadata
    return $script:ApplicationMetadata
}

function Get-VhsMp4InstallType {
    $installRoot = Get-VhsMp4InstallRoot
    $installerRoot = [System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA "Programs\VHS MP4 Optimizer"))
    if (Test-GuiPathEquals -Left $installRoot -Right $installerRoot) {
        return "Installer"
    }

    if (Test-Path -LiteralPath (Get-AppMetadataPath)) {
        return "Portable"
    }

    return "Repo/dev"
}

function Get-VhsMp4UpdateCheckState {
    if ($null -ne $script:UpdateCheckState) {
        return $script:UpdateCheckState
    }

    $statePath = Get-UpdateStatePath
    if (-not (Test-Path -LiteralPath $statePath)) {
        $script:UpdateCheckState = [pscustomobject]@{
            LastCheckedUtc = ""
            LastPromptedTag = ""
            LastAcceptedTag = ""
        }
        return $script:UpdateCheckState
    }

    try {
        $parsed = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
        $script:UpdateCheckState = [pscustomobject]@{
            LastCheckedUtc = [string](Get-WorkflowPresetObjectValue -Object $parsed -Name "LastCheckedUtc")
            LastPromptedTag = [string](Get-WorkflowPresetObjectValue -Object $parsed -Name "LastPromptedTag")
            LastAcceptedTag = [string](Get-WorkflowPresetObjectValue -Object $parsed -Name "LastAcceptedTag")
        }
    }
    catch {
        $script:UpdateCheckState = [pscustomobject]@{
            LastCheckedUtc = ""
            LastPromptedTag = ""
            LastAcceptedTag = ""
        }
    }

    return $script:UpdateCheckState
}

function Save-UpdateCheckState {
    param(
        [string]$LastCheckedUtc = ((Get-Date).ToUniversalTime().ToString("o")),
        [string]$LastPromptedTag = "",
        [string]$LastAcceptedTag = ""
    )

    Ensure-WorkflowPresetStorageDirectory | Out-Null
    $payload = [pscustomobject]@{
        SchemaVersion = 1
        LastCheckedUtc = $LastCheckedUtc
        LastPromptedTag = $LastPromptedTag
        LastAcceptedTag = $LastAcceptedTag
    }

    $json = $payload | ConvertTo-Json -Depth 4
    Set-Content -LiteralPath (Get-UpdateStatePath) -Value $json -Encoding UTF8
    $script:UpdateCheckState = $payload
}

function Compare-VhsMp4ReleaseTag {
    param(
        [string]$CurrentTag,
        [string]$LatestTag
    )

    if ([string]::IsNullOrWhiteSpace($LatestTag)) {
        return $false
    }
    if ([string]::IsNullOrWhiteSpace($CurrentTag)) {
        return $true
    }

    return (-not [string]::Equals($CurrentTag.Trim(), $LatestTag.Trim(), [System.StringComparison]::OrdinalIgnoreCase))
}

function Test-ShouldAutoCheckForUpdates {
    if ((Get-VhsMp4InstallType) -eq "Repo/dev") {
        return $false
    }

    $state = Get-VhsMp4UpdateCheckState
    if ([string]::IsNullOrWhiteSpace([string]$state.LastCheckedUtc)) {
        return $true
    }

    try {
        $lastChecked = [datetime]::Parse([string]$state.LastCheckedUtc, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        return (((Get-Date).ToUniversalTime() - $lastChecked.ToUniversalTime()).TotalHours -ge 12.0)
    }
    catch {
        return $true
    }
}

function Get-VhsMp4LatestReleaseInfo {
    $metadata = Get-VhsMp4ApplicationMetadata
    $uri = [string]$metadata.LatestReleaseApi
    if ([string]::IsNullOrWhiteSpace($uri)) {
        $uri = "https://api.github.com/repos/$([string]$metadata.Repository)/releases/latest"
    }

    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = ("VhsMp4Optimizer/" + [string]$metadata.Version)
    }

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    }
    catch {
    }

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 15 -ErrorAction Stop
    $assets = @()
    if ($null -ne $response -and $response.PSObject.Properties["assets"]) {
        $assets = @($response.assets)
    }

    $setupAsset = $assets | Where-Object { [string](Get-WorkflowPresetObjectValue -Object $_ -Name "name") -match '(?i)setup.*\.exe$' } | Select-Object -First 1
    $portableZipAsset = $assets | Where-Object { [string](Get-WorkflowPresetObjectValue -Object $_ -Name "name") -match '(?i)portable.*\.zip$' } | Select-Object -First 1

    return [pscustomobject]@{
        TagName = [string](Get-WorkflowPresetObjectValue -Object $response -Name "tag_name")
        Name = [string](Get-WorkflowPresetObjectValue -Object $response -Name "name")
        HtmlUrl = [string](Get-WorkflowPresetObjectValue -Object $response -Name "html_url")
        PublishedAt = [string](Get-WorkflowPresetObjectValue -Object $response -Name "published_at")
        SetupAssetName = if ($null -ne $setupAsset) { [string](Get-WorkflowPresetObjectValue -Object $setupAsset -Name "name") } else { "" }
        SetupAssetUrl = if ($null -ne $setupAsset) { [string](Get-WorkflowPresetObjectValue -Object $setupAsset -Name "browser_download_url") } else { "" }
        PortableZipName = if ($null -ne $portableZipAsset) { [string](Get-WorkflowPresetObjectValue -Object $portableZipAsset -Name "name") } else { "" }
        PortableZipUrl = if ($null -ne $portableZipAsset) { [string](Get-WorkflowPresetObjectValue -Object $portableZipAsset -Name "browser_download_url") } else { "" }
    }
}

function Get-UserGuidePath {
    $installRoot = Get-VhsMp4InstallRoot
    foreach ($candidate in @(
            (Join-Path $installRoot "README - kako se koristi.txt"),
            (Join-Path $installRoot "docs\VHS_MP4_OPTIMIZER_UPUTSTVO.md")
        )) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Open-UserGuide {
    $guidePath = Get-UserGuidePath
    if ([string]::IsNullOrWhiteSpace([string]$guidePath)) {
        [System.Windows.Forms.MessageBox]::Show("User guide nije pronadjen uz aplikaciju.", "Open User Guide", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    try {
        Start-Process -FilePath $guidePath
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Open User Guide", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}

function Close-MainFormForUpdate {
    $formVariable = Get-Variable -Name form -ErrorAction SilentlyContinue
    if ($null -eq $formVariable -or $null -eq $formVariable.Value) {
        return
    }

    try {
        $formVariable.Value.Close()
    }
    catch {
    }
}

function Test-IsApplicationControlBlockedError {
    param(
        [Parameter(Mandatory = $true)]
        $ErrorObject
    )

    $message = Get-VhsMp4ErrorMessage -ErrorObject $ErrorObject
    if ([string]::IsNullOrWhiteSpace($message)) {
        return $false
    }

    foreach ($token in @(
            "Application Control policy has blocked this file",
            "AppLocker",
            "blocked this file",
            "blocked by group policy",
            "software restriction policy"
        )) {
        if ($message -like ("*" + $token + "*")) {
            return $true
        }
    }

    return $false
}

function Invoke-UpdatePolicyBlockedFallback {
    param(
        [string]$DownloadPath,
        [string]$ReleaseUrl,
        [string]$ArtifactLabel = "update"
    )

    $downloadRoot = if ([string]::IsNullOrWhiteSpace($DownloadPath)) { "" } else { Split-Path -Parent $DownloadPath }
    $message = @"
Application Control policy je blokirao automatsko pokretanje update-a.

Preuzet artefakt: $ArtifactLabel
Lokacija: $DownloadPath

Otvoricu release stranicu i download folder da mozes rucno da probas update ili da uzmes portable ZIP ako setup.exe ostane blokiran.
"@

    Add-LogLine -Text ("Update launch blocked by policy: " + $ArtifactLabel + " | " + $DownloadPath)
    Set-StatusText "Check for Updates: automatsko pokretanje blokirano politikom"

    if (-not [string]::IsNullOrWhiteSpace($ReleaseUrl)) {
        try {
            Start-Process -FilePath $ReleaseUrl
        }
        catch {
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($downloadRoot) -and (Test-Path -LiteralPath $downloadRoot)) {
        try {
            Start-Process -FilePath $downloadRoot
        }
        catch {
        }
    }

    [System.Windows.Forms.MessageBox]::Show($message.Trim(), "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
}

function Start-ConfirmedAppUpdate {
    param(
        [Parameter(Mandatory = $true)]
        [object]$LatestRelease,
        [Parameter(Mandatory = $true)]
        [object]$CurrentMetadata
    )

    $installType = Get-VhsMp4InstallType
    $downloadUrl = ""
    $downloadName = ""
    $downloadKind = ""

    if ($installType -eq "Installer" -and -not [string]::IsNullOrWhiteSpace([string]$LatestRelease.SetupAssetUrl)) {
        $downloadUrl = [string]$LatestRelease.SetupAssetUrl
        $downloadName = if ([string]::IsNullOrWhiteSpace([string]$LatestRelease.SetupAssetName)) { "VHS-MP4-Optimizer-Setup-latest.exe" } else { [string]$LatestRelease.SetupAssetName }
        $downloadKind = "setup.exe"
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$LatestRelease.PortableZipUrl)) {
        $downloadUrl = [string]$LatestRelease.PortableZipUrl
        $downloadName = if ([string]::IsNullOrWhiteSpace([string]$LatestRelease.PortableZipName)) { "VHS-MP4-Optimizer-portable-latest.zip" } else { [string]$LatestRelease.PortableZipName }
        $downloadKind = "portable zip"
    }
    elseif (-not [string]::IsNullOrWhiteSpace([string]$LatestRelease.SetupAssetUrl)) {
        $downloadUrl = [string]$LatestRelease.SetupAssetUrl
        $downloadName = if ([string]::IsNullOrWhiteSpace([string]$LatestRelease.SetupAssetName)) { "VHS-MP4-Optimizer-Setup-latest.exe" } else { [string]$LatestRelease.SetupAssetName }
        $downloadKind = "setup.exe"
    }

    if ([string]::IsNullOrWhiteSpace($downloadUrl)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$LatestRelease.HtmlUrl)) {
            Start-Process -FilePath ([string]$LatestRelease.HtmlUrl)
            return
        }

        throw "GitHub release nema setup.exe ni portable zip asset za update."
    }

    $downloadRoot = Join-Path $env:TEMP "VhsMp4OptimizerUpdates"
    $null = New-Item -ItemType Directory -Path $downloadRoot -Force
    $downloadPath = Join-Path $downloadRoot $downloadName
    $headers = @{
        "Accept" = "application/octet-stream"
        "User-Agent" = ("VhsMp4Optimizer/" + [string]$CurrentMetadata.Version)
    }

    Set-StatusText ("Check for Updates: preuzimam " + $downloadKind + " ...")
    Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $downloadPath -TimeoutSec 300 -ErrorAction Stop
    Add-LogLine -Text ("Update downloaded: " + $downloadPath)

    if ($downloadKind -eq "setup.exe") {
        try {
            Add-LogLine -Text ("Launching updater: " + $downloadPath)
            Start-Process -FilePath $downloadPath -ErrorAction Stop
            [System.Windows.Forms.MessageBox]::Show("Update je preuzet. Pokrecem setup.exe; posle toga zavrsi upgrade preko postojece instalacije.", "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            Close-MainFormForUpdate
        }
        catch {
            if (Test-IsApplicationControlBlockedError -ErrorObject $_) {
                Invoke-UpdatePolicyBlockedFallback -DownloadPath $downloadPath -ReleaseUrl ([string]$LatestRelease.HtmlUrl) -ArtifactLabel "setup.exe"
                return
            }

            throw
        }

        return
    }

    $targetRoot = Get-VhsMp4InstallRoot
    $restartLauncher = Join-Path $targetRoot "VHS MP4 Optimizer.bat"
    $helperPath = Join-Path $downloadRoot ("apply-vhs-mp4-update-" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
    $helperScript = @"
param(
    [int]`$ParentProcessId,
    [string]`$ZipPath,
    [string]`$TargetRoot,
    [string]`$RestartLauncher
)

`$ErrorActionPreference = 'Stop'

for (`$attempt = 0; `$attempt -lt 240; `$attempt++) {
    `$process = Get-Process -Id `$ParentProcessId -ErrorAction SilentlyContinue
    if (`$null -eq `$process) {
        break
    }
    Start-Sleep -Milliseconds 500
}

Start-Sleep -Milliseconds 700

`$extractRoot = Join-Path ([System.IO.Path]::GetDirectoryName(`$ZipPath)) ('vhs-mp4-opt-update-' + [System.Guid]::NewGuid().ToString('N'))
Expand-Archive -LiteralPath `$ZipPath -DestinationPath `$extractRoot -Force
`$sourceRoot = Join-Path `$extractRoot 'VHS MP4 Optimizer'
Copy-Item -Path (Join-Path `$sourceRoot '*') -Destination `$TargetRoot -Recurse -Force
if (Test-Path -LiteralPath `$RestartLauncher) {
    Start-Process -FilePath `$RestartLauncher
}
Remove-Item -LiteralPath `$extractRoot -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$PSCommandPath -Force -ErrorAction SilentlyContinue
"@

    Set-Content -LiteralPath $helperPath -Value $helperScript -Encoding UTF8

    try {
        Add-LogLine -Text ("Launching portable update helper: " + $helperPath)
        Start-Process -FilePath "powershell" -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "RemoteSigned",
            "-WindowStyle", "Hidden",
            "-File", $helperPath,
            "-ParentProcessId", $PID,
            "-ZipPath", $downloadPath,
            "-TargetRoot", $targetRoot,
            "-RestartLauncher", $restartLauncher
        ) -ErrorAction Stop

        [System.Windows.Forms.MessageBox]::Show("Portable update je preuzet. Program ce se zatvoriti, zameniti fajlove i ponovo pokrenuti novu verziju.", "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        Close-MainFormForUpdate
    }
    catch {
        if (Test-IsApplicationControlBlockedError -ErrorObject $_) {
            Invoke-UpdatePolicyBlockedFallback -DownloadPath $downloadPath -ReleaseUrl ([string]$LatestRelease.HtmlUrl) -ArtifactLabel "portable update helper"
            return
        }

        throw
    }
}

function Invoke-UpdateCheck {
    param(
        [switch]$Silent,
        [switch]$Startup
    )

    if ($script:UpdateCheckInProgress) {
        return $false
    }

    $script:UpdateCheckInProgress = $true
    try {
        $metadata = Get-VhsMp4ApplicationMetadata
        $latestRelease = Get-VhsMp4LatestReleaseInfo
        Save-UpdateCheckState -LastCheckedUtc ((Get-Date).ToUniversalTime().ToString("o")) -LastPromptedTag ([string]$latestRelease.TagName) -LastAcceptedTag ([string](Get-VhsMp4UpdateCheckState).LastAcceptedTag)

        if (-not (Compare-VhsMp4ReleaseTag -CurrentTag ([string]$metadata.ReleaseTag) -LatestTag ([string]$latestRelease.TagName))) {
            if (-not $Silent) {
                [System.Windows.Forms.MessageBox]::Show("Vec koristis najnoviju verziju.", "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            }
            return $false
        }

        $installType = Get-VhsMp4InstallType
        $updateArtifact = if ($installType -eq "Installer" -and -not [string]::IsNullOrWhiteSpace([string]$latestRelease.SetupAssetUrl)) {
            "setup.exe"
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$latestRelease.PortableZipUrl)) {
            "portable zip"
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$latestRelease.SetupAssetUrl)) {
            "setup.exe"
        }
        else {
            "release page"
        }

        $message = @"
Pronadjena je novija verzija.

Current version: $([string]$metadata.Version)
Release tag: $([string]$metadata.ReleaseTag)
Latest release: $([string]$latestRelease.TagName)
Install type: $installType

Da li zelis da preuzmem i pokrenem update preko ${updateArtifact}?
"@

        $result = [System.Windows.Forms.MessageBox]::Show($message.Trim(), "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return $false
        }

        Save-UpdateCheckState -LastCheckedUtc ((Get-Date).ToUniversalTime().ToString("o")) -LastPromptedTag ([string]$latestRelease.TagName) -LastAcceptedTag ([string]$latestRelease.TagName)
        Start-ConfirmedAppUpdate -LatestRelease $latestRelease -CurrentMetadata $metadata
        return $true
    }
    catch {
        $message = "Check for Updates nije uspeo: " + (Get-VhsMp4ErrorMessage -ErrorObject $_)
        Add-LogLine -Text $message
        if (-not $Silent) {
            [System.Windows.Forms.MessageBox]::Show($message, "Check for Updates", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        return $false
    }
    finally {
        $script:UpdateCheckInProgress = $false
    }
}

function Show-AboutDialog {
    $metadata = Get-VhsMp4ApplicationMetadata
    $installType = Get-VhsMp4InstallType
    $installPath = Get-VhsMp4InstallRoot

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "About VHS MP4 Optimizer"
    $dialog.StartPosition = "CenterParent"
    $dialog.ClientSize = New-Object System.Drawing.Size(640, 320)
    $dialog.MinimumSize = New-Object System.Drawing.Size(640, 320)
    if (Test-Path -LiteralPath $script:AppIconPath) {
        $dialog.Icon = New-Object System.Drawing.Icon $script:AppIconPath
    }

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = "Fill"
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 1
    $layout.RowCount = 2
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $dialog.Controls.Add($layout)

    $detailsBox = New-Object System.Windows.Forms.TextBox
    $detailsBox.Multiline = $true
    $detailsBox.ReadOnly = $true
    $detailsBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
    $detailsBox.Dock = "Fill"
    $detailsBox.Text = @"
VHS MP4 Optimizer

Current version: $([string]$metadata.Version)
Release tag: $([string]$metadata.ReleaseTag)
Git ref: $([string]$metadata.GitRef)
Install type: $installType
Install path: $installPath
GitHub repo: $([string]$metadata.Repository)
Releases page: $([string]$metadata.ReleasesPage)
"@.Trim()
    $layout.Controls.Add($detailsBox, 0, 0)

    $buttonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonsFlow.Dock = "Fill"
    $buttonsFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::RightToLeft
    $buttonsFlow.WrapContents = $false
    $layout.Controls.Add($buttonsFlow, 0, 1)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.AutoSize = $true
    $okButton.Add_Click({ $dialog.Close() })
    $buttonsFlow.Controls.Add($okButton)

    $checkButton = New-Object System.Windows.Forms.Button
    $checkButton.Text = "Check for Updates"
    $checkButton.AutoSize = $true
    $checkButton.Add_Click({ [void](Invoke-UpdateCheck) })
    $buttonsFlow.Controls.Add($checkButton)

    $guideButton = New-Object System.Windows.Forms.Button
    $guideButton.Text = "Open User Guide"
    $guideButton.AutoSize = $true
    $guideButton.Add_Click({ Open-UserGuide })
    $buttonsFlow.Controls.Add($guideButton)

    [void]$dialog.ShowDialog($form)
}

function Update-WorkflowPresetActionButtons {
    $savePresetButtonVariable = Get-Variable -Name savePresetButton -ErrorAction SilentlyContinue
    if ($null -eq $savePresetButtonVariable) {
        return
    }

    $isEditLocked = Test-BatchEditLocked
    $selectedName = ""
    if (Get-Variable -Name workflowPresetComboBox -ErrorAction SilentlyContinue) {
        $selectedName = [string]$workflowPresetComboBox.SelectedItem
    }
    $selectedPreset = Find-WorkflowPresetByName -Name $selectedName
    $isUserPreset = ($null -ne $selectedPreset) -and ([string]$selectedPreset.Kind -eq "User")

    $savePresetButton.Enabled = -not $isEditLocked
    $deletePresetButton.Enabled = (-not $isEditLocked) -and $isUserPreset
    $importPresetButton.Enabled = -not $isEditLocked
    $exportPresetButton.Enabled = -not $isEditLocked
}

function Refresh-WorkflowPresetComboBox {
    param(
        [string]$SelectedName = ""
    )

    if (-not (Get-Variable -Name workflowPresetComboBox -ErrorAction SilentlyContinue)) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($SelectedName)) {
        $SelectedName = [string]$workflowPresetComboBox.SelectedItem
    }

    $script:WorkflowPresetSuppressSelection = $true
    try {
        $workflowPresetComboBox.Items.Clear()
        foreach ($preset in @(Get-AllWorkflowPresets)) {
            [void]$workflowPresetComboBox.Items.Add([string]$preset.Name)
        }
        [void]$workflowPresetComboBox.Items.Add($script:WorkflowPresetCustomName)

        if ([string]::IsNullOrWhiteSpace($SelectedName) -or -not $workflowPresetComboBox.Items.Contains($SelectedName)) {
            $SelectedName = $script:WorkflowPresetDefaultName
        }

        $workflowPresetComboBox.SelectedItem = $SelectedName
    }
    finally {
        $script:WorkflowPresetSuppressSelection = $false
    }

    Update-WorkflowPresetActionButtons
}

function Set-WorkflowPresetDescription {
    param(
        [string]$Text
    )

    if (Get-Variable -Name presetDescriptionLabel -ErrorAction SilentlyContinue) {
        $presetDescriptionLabel.Text = $Text
    }
}

function Set-WorkflowPresetSelectionState {
    param(
        [string]$PresetName,
        [string]$PresetKind,
        [string]$Description
    )

    if (Get-Variable -Name workflowPresetComboBox -ErrorAction SilentlyContinue) {
        if (-not $workflowPresetComboBox.Items.Contains($PresetName)) {
            Refresh-WorkflowPresetComboBox -SelectedName $PresetName
        }
        else {
            $script:WorkflowPresetSuppressSelection = $true
            try {
                $workflowPresetComboBox.SelectedItem = $PresetName
            }
            finally {
                $script:WorkflowPresetSuppressSelection = $false
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Description)) {
        if ($PresetName -eq $script:WorkflowPresetCustomName) {
            $Description = "Custom - rucno izmenjena opsta batch podesavanja."
        }
        elseif ($PresetKind -eq "User") {
            $Description = "Korisnicki workflow preset."
        }
    }

    Set-WorkflowPresetDescription -Text $Description
    Update-WorkflowPresetActionButtons
}

function Get-CurrentWorkflowPresetSettings {
    $crfValue = 22
    if (Get-Variable -Name crfTextBox -ErrorAction SilentlyContinue) {
        [void][int]::TryParse([string]$crfTextBox.Text, [ref]$crfValue)
    }

    $maxPartGb = 3.8
    if (Get-Variable -Name maxPartGbTextBox -ErrorAction SilentlyContinue) {
        $numberStyles = [System.Globalization.NumberStyles]::Float
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $maxPartText = [string]$maxPartGbTextBox.Text
        if (-not [string]::IsNullOrWhiteSpace($maxPartText)) {
            [void][double]::TryParse($maxPartText.Trim().Replace(",", "."), $numberStyles, $culture, [ref]$maxPartGb)
        }
    }

        return (New-WorkflowPresetSettingsObject -Settings @{
            QualityMode = Get-CurrentQualityModeSelectionLabel
            Crf = $crfValue
            Preset = [string]$presetComboBox.SelectedItem
            AudioBitrate = [string]$audioTextBox.Text
            VideoBitrate = Get-CurrentVideoBitrateText
            Deinterlace = [string]$deinterlaceComboBox.SelectedItem
            Denoise = [string]$denoiseComboBox.SelectedItem
            RotateFlip = [string]$rotateFlipComboBox.SelectedItem
            ScaleMode = [string]$scaleModeComboBox.SelectedItem
            AudioNormalize = [bool]$audioNormalizeCheckBox.Checked
            EncoderMode = if (Get-Variable -Name encoderModeComboBox -ErrorAction SilentlyContinue) { [string]$encoderModeComboBox.SelectedItem } else { $script:EncoderModeDefaultName }
            SplitOutput = [bool]$splitOutputCheckBox.Checked
            AutoApplyCrop = if (Get-Variable -Name autoApplyCropCheckBox -ErrorAction SilentlyContinue) { [bool]$autoApplyCropCheckBox.Checked } else { $false }
            MaxPartGb = $maxPartGb
        })
}

function Test-WorkflowPresetMatchesCurrentSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Preset,
        [object]$CurrentSettings = $null
    )

    if ($null -eq $CurrentSettings) {
        $CurrentSettings = Get-CurrentWorkflowPresetSettings
    }

    $presetSettings = New-WorkflowPresetSettingsObject -Settings $Preset.Settings
    foreach ($propertyName in @("QualityMode", "Crf", "Preset", "AudioBitrate", "VideoBitrate", "Deinterlace", "Denoise", "RotateFlip", "ScaleMode", "AudioNormalize", "EncoderMode", "SplitOutput", "AutoApplyCrop", "MaxPartGb")) {
        $leftValue = $presetSettings.$propertyName
        $rightValue = $CurrentSettings.$propertyName
        if ($propertyName -eq "MaxPartGb") {
            if ([Math]::Abs(([double]$leftValue) - ([double]$rightValue)) -gt 0.0001) {
                return $false
            }
        }
        elseif ([string]$leftValue -ne [string]$rightValue) {
            return $false
        }
    }

    return $true
}

function Refresh-PlanEstimatesForCurrentSettings {
    param(
        [string]$StatusPrefix = "Workflow preset"
    )

    Update-ActionButtons
    if (Test-BatchEditLocked) {
        return
    }

    if (Test-BatchPaused) {
        [void](Sync-PausedBatchPlanFromCurrentSettings -StatusPrefix $StatusPrefix)
        return
    }

    if ($script:PlanItems.Count -gt 0) {
        $selectedItem = Get-SelectedPlanItem
        $selectedName = if ($null -ne $selectedItem) { [string]$selectedItem.SourceName } else { "" }
        $script:PlanItems = @(Add-PlanEstimates -Plan $script:PlanItems)
        Set-GridRows -Plan $script:PlanItems

        if (-not [string]::IsNullOrWhiteSpace($selectedName)) {
            foreach ($row in $grid.Rows) {
                if ([string]$row.Cells["SourceName"].Value -eq $selectedName) {
                    $row.Selected = $true
                    $grid.CurrentCell = $row.Cells["SourceName"]
                    break
                }
            }
        }

        Set-StatusText ($StatusPrefix + " aktivan | procene i USB napomene su osvezene.")
        return
    }

    Set-StatusText ($StatusPrefix + " aktivan | opsta batch podesavanja su azurirana.")
}

function Set-WorkflowPresetControlsFromSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    $normalizedSettings = New-WorkflowPresetSettingsObject -Settings $Settings
    $script:WorkflowPresetApplying = $true
    try {
        $preferredQualityMode = Get-QualityModeSelectionDisplayName -QualityMode $normalizedSettings.QualityMode
        if ($qualityModeComboBox.Items.Contains($preferredQualityMode)) {
            $qualityModeComboBox.SelectedItem = $preferredQualityMode
        }
        else {
            $qualityModeComboBox.SelectedItem = "Universal MP4 H.264"
        }
        $script:QualityModeLastSelection = Get-CurrentQualityModeSelectionLabel
        $crfTextBox.Text = [string]$normalizedSettings.Crf
        $presetComboBox.SelectedItem = $normalizedSettings.Preset
        $audioTextBox.Text = $normalizedSettings.AudioBitrate
        if (Get-Variable -Name videoBitrateTextBox -ErrorAction SilentlyContinue) {
            $videoBitrateTextBox.Text = [string]$normalizedSettings.VideoBitrate
        }
        $deinterlaceComboBox.SelectedItem = $normalizedSettings.Deinterlace
        $denoiseComboBox.SelectedItem = $normalizedSettings.Denoise
        $rotateFlipComboBox.SelectedItem = $normalizedSettings.RotateFlip
        $scaleModeComboBox.SelectedItem = $normalizedSettings.ScaleMode
        $audioNormalizeCheckBox.Checked = [bool]$normalizedSettings.AudioNormalize
        if (Get-Variable -Name encoderModeComboBox -ErrorAction SilentlyContinue) {
            $preferredEncoderMode = if ([string]::IsNullOrWhiteSpace([string]$normalizedSettings.EncoderMode)) { $script:EncoderModeDefaultName } else { [string]$normalizedSettings.EncoderMode }
            if ($encoderModeComboBox.Items.Contains($preferredEncoderMode)) {
                $encoderModeComboBox.SelectedItem = $preferredEncoderMode
            }
            else {
                $encoderModeComboBox.SelectedItem = $script:EncoderModeDefaultName
            }
        }
        $splitOutputCheckBox.Checked = [bool]$normalizedSettings.SplitOutput
        if (Get-Variable -Name autoApplyCropCheckBox -ErrorAction SilentlyContinue) {
            $autoApplyCropCheckBox.Checked = [bool]$normalizedSettings.AutoApplyCrop
        }
        $maxPartGbTextBox.Text = ([double]$normalizedSettings.MaxPartGb).ToString("0.###", [System.Globalization.CultureInfo]::InvariantCulture)
        $maxPartGbTextBox.Enabled = $splitOutputCheckBox.Checked
    }
    finally {
        $script:WorkflowPresetApplying = $false
    }
}

function Apply-WorkflowPresetSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Preset,
        [switch]$SkipPersist
    )

    Set-WorkflowPresetControlsFromSettings -Settings $Preset.Settings
    Set-WorkflowPresetSelectionState -PresetName ([string]$Preset.Name) -PresetKind ([string]$Preset.Kind) -Description ([string]$Preset.Description)
    Refresh-PlanEstimatesForCurrentSettings -StatusPrefix ("Workflow preset: " + [string]$Preset.Name)
    if (-not $SkipPersist) {
        Save-WorkflowPresetStartupState
    }
}

function Set-WorkflowPresetCustomState {
    Set-WorkflowPresetSelectionState -PresetName $script:WorkflowPresetCustomName -PresetKind "Custom" -Description "Custom - rucno izmenjena opsta batch podesavanja."
}

function Update-WorkflowPresetDirtyState {
    if ($script:WorkflowPresetApplying -or $script:WorkflowPresetSuppressSelection) {
        return
    }

    $currentSettings = Get-CurrentWorkflowPresetSettings
    foreach ($preset in @(Get-AllWorkflowPresets)) {
        if (Test-WorkflowPresetMatchesCurrentSettings -Preset $preset -CurrentSettings $currentSettings) {
            Set-WorkflowPresetSelectionState -PresetName ([string]$preset.Name) -PresetKind ([string]$preset.Kind) -Description ([string]$preset.Description)
            return
        }
    }

    Set-WorkflowPresetCustomState
}

function Save-WorkflowPreset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [object]$Settings,
        [string]$Description = ""
    )

    $trimmedName = $Name.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedName)) {
        throw "Ime preseta je obavezno."
    }

    if ($trimmedName -eq $script:WorkflowPresetCustomName) {
        throw "Ime Custom je rezervisano."
    }

    if ($null -ne (Find-WorkflowPresetByName -Name $trimmedName) -and ((Find-WorkflowPresetByName -Name $trimmedName).Kind -eq "BuiltIn")) {
        throw "Ime preseta je rezervisano za built-in workflow preset."
    }

    $state = Import-WorkflowPresetState
    $remainingUserPresets = @($state.UserPresets | Where-Object { -not [string]::Equals([string]$_.Name, $trimmedName, [System.StringComparison]::OrdinalIgnoreCase) })
    $savedPreset = New-WorkflowPresetObject -Name $trimmedName -Kind "User" -Description $Description -Settings $Settings
    $remainingUserPresets += $savedPreset
    Export-WorkflowPresetState -UserPresets $remainingUserPresets
    $script:WorkflowPresetState = [pscustomobject]@{
        BuiltInPresets = $state.BuiltInPresets
        UserPresets = @($remainingUserPresets | Sort-Object Name)
        LoadError = ""
    }

    Refresh-WorkflowPresetComboBox -SelectedName $trimmedName
    Set-WorkflowPresetSelectionState -PresetName $trimmedName -PresetKind "User" -Description ([string]$savedPreset.Description)
    Save-WorkflowPresetStartupState
    return $savedPreset
}

function Remove-WorkflowPreset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $preset = Find-WorkflowPresetByName -Name $Name
    if ($null -eq $preset) {
        return $false
    }

    if ([string]$preset.Kind -ne "User") {
        throw "Samo korisnicki preset moze da se obrise."
    }

    $state = Import-WorkflowPresetState
    $remainingUserPresets = @($state.UserPresets | Where-Object { -not [string]::Equals([string]$_.Name, $Name, [System.StringComparison]::OrdinalIgnoreCase) })
    Export-WorkflowPresetState -UserPresets $remainingUserPresets
    $script:WorkflowPresetState = [pscustomobject]@{
        BuiltInPresets = $state.BuiltInPresets
        UserPresets = @($remainingUserPresets | Sort-Object Name)
        LoadError = ""
    }

    Refresh-WorkflowPresetComboBox -SelectedName $script:WorkflowPresetDefaultName
    $defaultPreset = Find-WorkflowPresetByName -Name $script:WorkflowPresetDefaultName
    if ($null -ne $defaultPreset) {
        Apply-WorkflowPresetSettings -Preset $defaultPreset -SkipPersist
    }
    else {
        Save-WorkflowPresetStartupState
    }

    return $true
}

function Export-WorkflowPresetToFile {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Preset,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = if ($null -ne $Preset.PSObject.Properties["Settings"] -and $null -ne $Preset.Settings) {
        New-WorkflowPresetSettingsObject -Settings $Preset.Settings
    }
    else {
        Get-CurrentWorkflowPresetSettings
    }

    $payload = [pscustomobject]@{
        SchemaVersion = 1
        Name = [string]$Preset.Name
        Description = [string]$Preset.Description
        Settings = $settings
    }

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    Set-Content -LiteralPath $Path -Value ($payload | ConvertTo-Json -Depth 8) -Encoding UTF8
    return $Path
}

function Import-WorkflowPresetFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parsed = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $Path -Raw -Encoding UTF8) -ErrorAction Stop
    $name = [string](Get-WorkflowPresetObjectValue -Object $parsed -Name "Name")
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Import preset fajl nema Name."
    }

    $settings = Get-WorkflowPresetObjectValue -Object $parsed -Name "Settings"
    if ($null -eq $settings) {
        throw "Import preset fajl nema Settings."
    }

    return (Save-WorkflowPreset -Name $name -Settings $settings -Description ([string](Get-WorkflowPresetObjectValue -Object $parsed -Name "Description")))
}

function Save-WorkflowPresetStartupState {
    $selectedName = if (Get-Variable -Name workflowPresetComboBox -ErrorAction SilentlyContinue) { [string]$workflowPresetComboBox.SelectedItem } else { $script:WorkflowPresetCustomName }
    Export-WorkflowAppState -LastPresetName $selectedName -LastGeneralSettings (Get-CurrentWorkflowPresetSettings) -LayoutState (Get-CurrentWorkspaceLayoutState)
}

function Restore-WorkflowPresetStartupState {
    $appState = Import-WorkflowAppState
    $restoredName = [string]$appState.LastPresetName
    $settings = $appState.LastGeneralSettings
    $layoutState = $appState.LayoutState

    Apply-WorkspaceLayoutState -LayoutState $layoutState

    if (-not [string]::IsNullOrWhiteSpace($restoredName) -and $restoredName -ne $script:WorkflowPresetCustomName) {
        $preset = Find-WorkflowPresetByName -Name $restoredName
        if ($null -ne $preset) {
            Apply-WorkflowPresetSettings -Preset $preset -SkipPersist
            return
        }
    }

    if ($null -ne $settings) {
        Set-WorkflowPresetControlsFromSettings -Settings $settings
        if ($restoredName -eq $script:WorkflowPresetCustomName) {
            Set-WorkflowPresetCustomState
        }
        else {
            Update-WorkflowPresetDirtyState
        }
        return
    }

    $defaultPreset = Find-WorkflowPresetByName -Name $script:WorkflowPresetDefaultName
    if ($null -ne $defaultPreset) {
        Apply-WorkflowPresetSettings -Preset $defaultPreset -SkipPersist
    }
}

function Initialize-WorkflowPresetState {
    $script:WorkflowPresetState = Import-WorkflowPresetState
    $script:WorkflowPresetStorageWarning = [string]$script:WorkflowPresetState.LoadError
    Refresh-WorkflowPresetComboBox -SelectedName $script:WorkflowPresetDefaultName
    Restore-WorkflowPresetStartupState
}

function Set-DragDropVisualState {
    param(
        [switch]$Active,
        [switch]$KeepCurrentStatus
    )

    if ($null -eq $script:DragDropVisualDefaults) {
        $script:DragDropActive = [bool]$Active
        if (-not $KeepCurrentStatus -and -not [string]::IsNullOrWhiteSpace($script:LastNormalStatusText)) {
            $statusValueLabel.Text = $script:LastNormalStatusText
        }
        return
    }

    if ($Active) {
        $script:DragDropActive = $true
        if ([string]::IsNullOrWhiteSpace($script:LastNormalStatusText) -and $null -ne $statusValueLabel) {
            $script:LastNormalStatusText = [string]$statusValueLabel.Text
        }

        $statusPanel.BackColor = $script:DragDropPanelBackColor
        $mainSplit.Panel1.BackColor = $script:DragDropPanelBackColor
        $mainSplit.Panel2.BackColor = $script:DragDropPanelBackColor
        $rightPanel.BackColor = $script:DragDropPanelBackColor
        $grid.BackgroundColor = $script:DragDropGridBackColor
        $grid.RowsDefaultCellStyle.BackColor = $script:DragDropGridRowBackColor
        $grid.AlternatingRowsDefaultCellStyle.BackColor = $script:DragDropGridAltRowBackColor
        $statusTitleLabel.ForeColor = $script:DragDropAccentColor
        $inputHelpLabel.ForeColor = $script:DragDropAccentColor
        $outputHelpLabel.ForeColor = $script:DragDropAccentColor
        $statusTitleLabel.Text = "Video Converter | Drop ready"
        $inputHelpLabel.Text = "Pusti folder ili video fajlove bilo gde u prozoru"
        $outputHelpLabel.Text = "Drop odmah puni listu za obradu"
        $statusValueLabel.Text = "Pusti folder ili video fajlove da ih odmah ucitam i pripremim za konverziju."
        return
    }

    $script:DragDropActive = $false
    $statusPanel.BackColor = $script:DragDropVisualDefaults.StatusPanelBackColor
    $mainSplit.Panel1.BackColor = $script:DragDropVisualDefaults.Panel1BackColor
    $mainSplit.Panel2.BackColor = $script:DragDropVisualDefaults.Panel2BackColor
    $rightPanel.BackColor = $script:DragDropVisualDefaults.RightPanelBackColor
    $grid.BackgroundColor = $script:DragDropVisualDefaults.GridBackColor
    $grid.RowsDefaultCellStyle.BackColor = $script:DragDropVisualDefaults.GridRowsBackColor
    $grid.AlternatingRowsDefaultCellStyle.BackColor = $script:DragDropVisualDefaults.GridAltRowsBackColor
    $statusTitleLabel.ForeColor = $script:DragDropVisualDefaults.StatusTitleForeColor
    $inputHelpLabel.ForeColor = $script:DragDropVisualDefaults.InputHelpForeColor
    $outputHelpLabel.ForeColor = $script:DragDropVisualDefaults.OutputHelpForeColor
    $statusTitleLabel.Text = $script:DragDropVisualDefaults.StatusTitleText
    $inputHelpLabel.Text = $script:DragDropVisualDefaults.InputHelpText
    $outputHelpLabel.Text = $script:DragDropVisualDefaults.OutputHelpText

    if (-not $KeepCurrentStatus) {
        $statusValueLabel.Text = $script:LastNormalStatusText
    }
}

function Test-BatchRunning {
    return ($null -ne $script:BatchContext)
}

function Test-BatchPaused {
    if ($null -eq $script:BatchContext) {
        return $false
    }

    $pausedProperty = $script:BatchContext.PSObject.Properties["Paused"]
    if (-not $pausedProperty) {
        return $false
    }

    return [bool]$pausedProperty.Value
}

function Test-BatchEditLocked {
    return (Test-BatchRunning) -and (-not (Test-BatchPaused))
}

function Test-PlanItemQueued {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return $false
    }

    $statusProperty = $Item.PSObject.Properties["Status"]
    if (-not $statusProperty) {
        return $false
    }

    return ([string]$statusProperty.Value -eq "queued")
}

function Test-CanEditPlanItem {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return $false
    }

    if (-not (Test-BatchRunning)) {
        return $true
    }

    if (-not (Test-BatchPaused)) {
        return $false
    }

    return (Test-PlanItemQueued -Item $Item)
}

function Test-HasQueuedPlanItems {
    foreach ($item in @($script:PlanItems)) {
        if (Test-PlanItemQueued -Item $item) {
            return $true
        }
    }

    return $false
}

function Get-PlanItemStatusText {
    param(
        [AllowNull()]
        $Item,
        [string]$Default = ""
    )

    if ($null -eq $Item) {
        return $Default
    }

    $statusProperty = $Item.PSObject.Properties["Status"]
    if (-not $statusProperty -or [string]::IsNullOrWhiteSpace([string]$statusProperty.Value)) {
        return $Default
    }

    return [string]$statusProperty.Value
}

function Show-CompletionNotice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    try {
        [System.Media.SystemSounds]::Asterisk.Play()
    }
    catch {
    }

    try {
        $script:NotifyIcon.BalloonTipTitle = "VHS MP4 Optimizer"
        $script:NotifyIcon.BalloonTipText = $Text
        $script:NotifyIcon.ShowBalloonTip(5000)
    }
    catch {
    }
}

function Get-PlanStatusCounts {
    $doneCount = 0
    $skippedCount = 0
    $failedCount = 0
    $stoppedCount = 0

    foreach ($item in $script:PlanItems) {
        switch ([string]$item.Status) {
            "done" { $doneCount++ }
            "skipped" { $skippedCount++ }
            "failed" { $failedCount++ }
            "stopped" { $stoppedCount++ }
        }
    }

    return [pscustomobject]@{
        Done = $doneCount
        Skipped = $skippedCount
        Failed = $failedCount
        Stopped = $stoppedCount
    }
}

function Write-SessionLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($null -eq $script:BatchContext) {
        return
    }

    Write-VhsMp4Log -LogPath $script:BatchContext.Context.LogPath -Message $Message -OnLog {
        param($line)
        Add-LogLine -Text $line
    }
}

function Get-FfmpegSearchRoots {
    return @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"),
        (Join-Path $env:LOCALAPPDATA "Programs\FFmpeg"),
        (Join-Path $env:LOCALAPPDATA "Programs\ffmpeg")
    )
}

function Sync-FfmpegState {
    $candidate = $ffmpegPathTextBox.Text.Trim()
    $resolved = Get-VhsMp4ResolvedFfmpegPath -CandidatePath $candidate -SearchRoots (Get-FfmpegSearchRoots)

    if ($resolved) {
        $directory = Split-Path -Path $resolved -Parent
        Add-VhsMp4DirectoryToUserPath -Directory $directory | Out-Null
        Update-VhsMp4ProcessPathFromEnvironment | Out-Null

        if ($ffmpegPathTextBox.Text -ne $resolved) {
            $ffmpegPathTextBox.Text = $resolved
        }

        $script:ResolvedFfmpegPath = $resolved
        $ffmpegStatusValue.Text = "FFmpeg spreman"
        $ffmpegHintLabel.Text = $resolved
    }
    else {
        $script:ResolvedFfmpegPath = $null
        $ffmpegStatusValue.Text = "FFmpeg nije pronadjen"
        $ffmpegHintLabel.Text = "Auto-install pri startu | Help > Install FFmpeg / Browse FFmpeg za rucni fallback."
    }

    Sync-EncoderModeState
    Update-ActionButtons
}

function Sync-EncoderModeState {
    $inventory = $null
    if (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
        try {
            $inventory = Get-VhsMp4EncoderInventory -FfmpegPath $script:ResolvedFfmpegPath
        }
        catch {
            $message = "Encode engine provera nije uspela; hardverski modovi ce pasti nazad na CPU. " + (Get-VhsMp4ErrorMessage -ErrorObject $_)
            Add-LogLine -Text $message
            $inventory = Get-VhsMp4EncoderInventoryFromText -EncodersText ""
        }
    }
    else {
        $inventory = Get-VhsMp4EncoderInventoryFromText -EncodersText ""
    }

    $script:EncoderInventory = $inventory

    if (Get-Variable -Name encoderModeComboBox -ErrorAction SilentlyContinue) {
        $selectedMode = [string]$encoderModeComboBox.SelectedItem
        if ([string]::IsNullOrWhiteSpace($selectedMode)) {
            $selectedMode = $script:EncoderModeDefaultName
        }

        $previousApplying = $script:WorkflowPresetApplying
        $script:WorkflowPresetApplying = $true
        try {
            $encoderModeComboBox.Items.Clear()
            foreach ($modeName in $script:EncoderModeLabels) {
                [void]$encoderModeComboBox.Items.Add($modeName)
            }
            if (-not $encoderModeComboBox.Items.Contains($selectedMode)) {
                $selectedMode = $script:EncoderModeDefaultName
            }
            $encoderModeComboBox.SelectedItem = $selectedMode
        }
        finally {
            $script:WorkflowPresetApplying = $previousApplying
        }
    }

    if (Get-Variable -Name encoderStatusLabel -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
            $encoderStatusLabel.Text = "RuntimeReadyModes: CPU | Auto koristi CPU dok FFmpeg ne bude spreman."
        }
        else {
            $runtimeReadyModes = @($inventory.RuntimeReadyModes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            $runtimeNotes = @($inventory.RuntimeNotes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            $readyText = if ($runtimeReadyModes.Count -gt 0) { $runtimeReadyModes -join ", " } else { "CPU" }
            $noteText = if ($runtimeNotes.Count -gt 0) { " | " + ($runtimeNotes -join "; ") } else { "" }
            $encoderStatusLabel.Text = "RuntimeReadyModes: " + $readyText + $noteText
        }
    }
}

function Update-ProgressBar {
    $total = $grid.Rows.Count
    if ($total -le 0) {
        $progressBar.Maximum = 1
        $progressBar.Value = 0
        $progressLabel.Text = "0 / 0"
        return
    }

    $finished = 0
    foreach ($row in $grid.Rows) {
        $status = [string]$row.Cells["Status"].Value
        if ($status -in @("skipped", "done", "failed", "stopped")) {
            $finished++
        }
    }

    $progressBar.Maximum = $total
    $progressBar.Value = [Math]::Min($finished, $total)
    $progressLabel.Text = "$finished / $total"
}

function Format-VhsMp4Duration {
    param(
        [double]$Seconds
    )

    if ($Seconds -lt 0) {
        $Seconds = 0
    }

    $span = [System.TimeSpan]::FromSeconds([Math]::Round($Seconds))
    return $span.ToString("hh\:mm\:ss")
}

function Format-VhsMp4Gigabytes {
    param(
        [double]$Gigabytes
    )

    if ($Gigabytes -lt 0) {
        $Gigabytes = 0
    }

    return ("{0:N2} GB" -f $Gigabytes)
}

function Get-CurrentFileProgressSeconds {
    if ([string]::IsNullOrWhiteSpace($script:CurrentProgressPath) -or -not (Test-Path -LiteralPath $script:CurrentProgressPath)) {
        return $null
    }

    $lines = @(Get-Content -LiteralPath $script:CurrentProgressPath -Tail 60 -ErrorAction SilentlyContinue)
    for ($index = $lines.Count - 1; $index -ge 0; $index--) {
        $line = [string]$lines[$index]
        if ($line -match "^out_time_ms=(\d+)") {
            return ([double]$Matches[1] / 1000000.0)
        }
    }

    return $null
}

function Update-CurrentFileProgress {
    if ($null -eq $script:CurrentPlanItem) {
        $currentFileNameLabel.Text = "File progress: nema aktivnog fajla"
        $currentFileProgressBar.Value = 0
        $currentFilePercentLabel.Text = "0%"
        $currentFileEtaLabel.Text = "ETA: --:--:--"
        return
    }

    $currentFileNameLabel.Text = "File progress: " + $script:CurrentPlanItem.SourceName
    $duration = $script:CurrentDurationSeconds
    $progressSeconds = Get-CurrentFileProgressSeconds

    if ($null -eq $duration -or $duration -le 0 -or $null -eq $progressSeconds) {
        $currentFileProgressBar.Value = 0
        $currentFilePercentLabel.Text = "0%"
        $currentFileEtaLabel.Text = "ETA: racunam..."
        return
    }

    $percent = [Math]::Min(100.0, [Math]::Max(0.0, ($progressSeconds / $duration) * 100.0))
    $currentFileProgressBar.Value = [Math]::Min(100, [Math]::Max(0, [int][Math]::Round($percent)))
    $currentFilePercentLabel.Text = ("{0}%" -f ([int][Math]::Round($percent)))

    if ($percent -gt 0 -and $null -ne $script:CurrentFileStartedAt) {
        $elapsedSeconds = ((Get-Date) - $script:CurrentFileStartedAt).TotalSeconds
        $etaSeconds = ($elapsedSeconds * (100.0 - $percent)) / $percent
        $currentFileEtaLabel.Text = "ETA: " + (Format-VhsMp4Duration -Seconds $etaSeconds)
    }
    else {
        $currentFileEtaLabel.Text = "ETA: racunam..."
    }
}

function Update-ActionButtons {
    $hasQueued = Test-HasQueuedPlanItems
    $isRunning = Test-BatchRunning
    $isPaused = Test-BatchPaused
    $isEditLocked = Test-BatchEditLocked
    $hasInput = -not [string]::IsNullOrWhiteSpace($inputTextBox.Text)
    $hasOutput = -not [string]::IsNullOrWhiteSpace($outputTextBox.Text)
    $selectedPlanItem = $null
    try {
        $selectedPlanItem = Get-SelectedPlanItem
    }
    catch {
        $selectedPlanItem = $null
    }
    $hasSelectedPlanItem = ($null -ne $selectedPlanItem)
    $canEditSelectedItem = Test-CanEditPlanItem -Item $selectedPlanItem
    $selectedQueued = Test-PlanItemQueued -Item $selectedPlanItem
    $hasFailed = @($script:PlanItems | Where-Object { (Get-PlanItemStatusText -Item $_) -eq "failed" }).Count -gt 0
    $hasCompleted = @($script:PlanItems | Where-Object { (Get-PlanItemStatusText -Item $_) -in @("done", "skipped", "stopped") }).Count -gt 0

    $inputTextBox.Enabled = -not $isRunning
    $outputTextBox.Enabled = -not $isEditLocked
    $ffmpegPathTextBox.Enabled = -not $isEditLocked
    $qualityModeComboBox.Enabled = -not $isEditLocked
    $crfTextBox.Enabled = -not $isEditLocked
    $presetComboBox.Enabled = -not $isEditLocked
    $audioTextBox.Enabled = -not $isEditLocked
    $browseInputButton.Enabled = -not $isRunning
    $browseOutputButton.Enabled = (-not $isEditLocked) -and $hasInput
    $browseFfmpegButton.Enabled = -not $isEditLocked
    $installFfmpegButton.Enabled = -not $isEditLocked
    if (Get-Variable -Name "workflowPresetComboBox" -ErrorAction SilentlyContinue) {
        $workflowPresetComboBox.Enabled = -not $isEditLocked
        Update-WorkflowPresetActionButtons
    }
    if (Get-Variable -Name "deinterlaceComboBox" -ErrorAction SilentlyContinue) {
        $deinterlaceComboBox.Enabled = -not $isEditLocked
        $denoiseComboBox.Enabled = -not $isEditLocked
        $rotateFlipComboBox.Enabled = -not $isEditLocked
        $scaleModeComboBox.Enabled = -not $isEditLocked
        $audioNormalizeCheckBox.Enabled = -not $isEditLocked
        if (Get-Variable -Name "aspectModeComboBox" -ErrorAction SilentlyContinue) {
            $aspectModeComboBox.Enabled = $canEditSelectedItem
        }
        if (Get-Variable -Name "copyAspectToAllButton" -ErrorAction SilentlyContinue) {
            $copyAspectToAllButton.Enabled = $canEditSelectedItem -and ($script:PlanItems.Count -gt 0)
        }
    }
    $splitOutputCheckBox.Enabled = -not $isEditLocked
    $maxPartGbTextBox.Enabled = (-not $isEditLocked) -and $splitOutputCheckBox.Checked
    if (Get-Variable -Name "encoderModeComboBox" -ErrorAction SilentlyContinue) {
        $encoderModeComboBox.Enabled = -not $isEditLocked
    }
    $scanButton.Enabled = (-not $isRunning) -and $hasInput
    $sampleButton.Enabled = ((-not $isEditLocked) -or $isPaused) -and $hasInput -and $hasQueued -and (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath))
    if (Get-Variable -Name "openPlayerButton" -ErrorAction SilentlyContinue) {
        $openPlayerButton.Enabled = $canEditSelectedItem
    }
    if (Get-Variable -Name "moveUpButton" -ErrorAction SilentlyContinue) {
        $moveUpButton.Enabled = $selectedQueued -and (-not $isEditLocked)
        $moveDownButton.Enabled = $selectedQueued -and (-not $isEditLocked)
    }
    if (Get-Variable -Name "skipSelectedButton" -ErrorAction SilentlyContinue) {
        $skipSelectedButton.Enabled = $selectedQueued -and (-not $isEditLocked)
    }
    if (Get-Variable -Name "retryFailedButton" -ErrorAction SilentlyContinue) {
        $retryFailedButton.Enabled = (-not $isRunning) -and $hasFailed
    }
    if (Get-Variable -Name "clearCompletedButton" -ErrorAction SilentlyContinue) {
        $clearCompletedButton.Enabled = (-not $isRunning) -and $hasCompleted
    }
    if (Get-Variable -Name "advancedToggleButton" -ErrorAction SilentlyContinue) {
        $advancedToggleButton.Enabled = -not $isEditLocked
    }
    if (Get-Variable -Name "queueMenuItem" -ErrorAction SilentlyContinue) {
        $queueMenuItem.Enabled = ($script:PlanItems.Count -gt 0) -or (-not $isRunning)
        $saveQueueMenuItem.Enabled = ($script:PlanItems.Count -gt 0) -and (-not $isEditLocked)
        $loadQueueMenuItem.Enabled = -not $isRunning
        $skipSelectedMenuItem.Enabled = $selectedQueued -and (-not $isEditLocked)
        $retryFailedMenuItem.Enabled = (-not $isRunning) -and $hasFailed
        $clearCompletedMenuItem.Enabled = (-not $isRunning) -and $hasCompleted
    }
    $startEnabled = (-not $isRunning) -and $hasInput -and $hasOutput -and $hasQueued -and (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath))
    $startButton.Enabled = $startEnabled
    if ($startEnabled) {
        $startButton.BackColor = $script:StartButtonActiveBackColor
        $startButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(16, 122, 58)
    }
    else {
        $startButton.BackColor = $script:StartButtonDisabledBackColor
        $startButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 166, 173)
    }
    if (Get-Variable -Name "pauseButton" -ErrorAction SilentlyContinue) {
        $pauseButton.Enabled = $isRunning -and (-not $isPaused) -and (-not $script:SharedState.StopRequested) -and ($null -ne $script:CurrentProcess) -and $hasQueued
    }
    if (Get-Variable -Name "resumeButton" -ErrorAction SilentlyContinue) {
        $resumeButton.Enabled = $isPaused -and $hasQueued -and (-not $script:SharedState.StopRequested)
    }
    $stopButton.Enabled = $isRunning
    $openOutputButton.Enabled = $hasOutput -and (Test-Path -LiteralPath $outputTextBox.Text)
    $openLogButton.Enabled = -not [string]::IsNullOrWhiteSpace($script:LastLogPath) -and (Test-Path -LiteralPath $script:LastLogPath)
    $openReportButton.Enabled = -not [string]::IsNullOrWhiteSpace($script:LastReportPath) -and (Test-Path -LiteralPath $script:LastReportPath)

    if (Get-Variable -Name "previewFrameButton" -ErrorAction SilentlyContinue) {
        $hasTimelineDuration = $false
        try {
            $hasTimelineDuration = (Get-SelectedPreviewDurationSeconds) -gt 0
        }
        catch {
            $hasTimelineDuration = $false
        }
        $previewFrameButton.Enabled = $canEditSelectedItem -and (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath))
        $openVideoButton.Enabled = $canEditSelectedItem
        $trimStartTextBox.Enabled = $canEditSelectedItem
        $trimEndTextBox.Enabled = $canEditSelectedItem
        $previewTimeTextBox.Enabled = $canEditSelectedItem
        $previewTimelineTrackBar.Enabled = $canEditSelectedItem -and $hasTimelineDuration
        $previousFrameButton.Enabled = $canEditSelectedItem
        $nextFrameButton.Enabled = $canEditSelectedItem
        $setTrimStartButton.Enabled = $canEditSelectedItem
        $setTrimEndButton.Enabled = $canEditSelectedItem
        if (Get-Variable -Name "autoPreviewCheckBox" -ErrorAction SilentlyContinue) {
            $autoPreviewCheckBox.Enabled = $canEditSelectedItem
        }
        $applyTrimButton.Enabled = $canEditSelectedItem
        $clearTrimButton.Enabled = $canEditSelectedItem
        if (Get-Variable -Name "trimSegmentsListBox" -ErrorAction SilentlyContinue) {
            $segmentCount = @(Get-SelectedTrimSegments).Count
            $trimSegmentsListBox.Enabled = $canEditSelectedItem -and $segmentCount -gt 0
            $addSegmentButton.Enabled = $canEditSelectedItem
            $removeSegmentButton.Enabled = $canEditSelectedItem -and $segmentCount -gt 0 -and $trimSegmentsListBox.SelectedIndex -ge 0
            $clearSegmentsButton.Enabled = $canEditSelectedItem -and $segmentCount -gt 0
        }
    }
}

function Get-MediaInfoIntroText {
    return @"
Selected file / Properties

Izaberi fajl u tabeli da ovde vidis ulazni format, kontejner, rezoluciju, odnos stranica, FPS, broj frejmova, protok, audio i trajanje.
Desni gornji panel sada pokazuje planirani izlaz: codec, resolution, bitrate, split, crop, trim i procenu velicine pre konverzije.
Open Player ili dupli klik otvaraju poseban floating Player / Trim prozor. Tamo radis preview, timeline, trim, segmente, crop i aspect.
Glavni ekran je sada batch radna povrsina: folderi, preset-i, queue, Start/Pause/Resume i status ostaju ovde.
Player / Trim koristi Save to Queue da vrati izmene nazad u glavni batch bez zatrpavanja ovog ekrana.
Video filters dodaje Deinterlace, Denoise, Rotate/flip, Scale i Audio normalize za ceo batch.
Video bitrate u Advanced Settings je opcion override; ostavi prazno za CRF/Quality mode.

Quality mode:

Universal MP4 H.264 = preporuceno za predaju musteriji.
Small MP4 H.264 = kada fajl mora biti sto manji.
High Quality MP4 H.264 = za vazne snimke gde je velicina manje bitna.
HEVC H.265 Smaller = manji fajl uz noviji H.265 kodek.

Stari VHS profili ostaju dostupni: Standard VHS, Smaller File, Better Quality i Custom.
Originalni MP4 / AVI / MPG / MPEG / MOV / MKV / M4V / WMV / TS / M2TS / VOB fajlovi ostaju netaknuti.
Podrzane ekstenzije: .mp4, .avi, .mpg, .mpeg, .mov, .mkv, .m4v, .wmv, .ts, .m2ts, .vob.
Test Sample pravi probni MP4 u samples folderu.
Split output pravi delove kao ime-part001.mp4, ime-part002.mp4.
VHS MP4 Optimizer tok rada je i dalje tu za stare kasete.
"@
}

function Get-PlanItemPropertyText {
    param(
        $Item,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$Default = ""
    )

    if ($null -eq $Item) {
        return $Default
    }

    $property = $Item.PSObject.Properties[$Name]
    if ($property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
        return [string]$property.Value
    }

    return $Default
}

function Copy-PlanItemTrimState {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return [pscustomobject]@{
            TrimStartText = ""
            TrimEndText = ""
            TrimSummary = ""
            TrimDurationSeconds = $null
            TrimSegments = @()
            PreviewPositionSeconds = 0.0
        }
    }

    $trimSegments = @()
    $segmentsProperty = $Item.PSObject.Properties["TrimSegments"]
    if ($segmentsProperty -and $null -ne $segmentsProperty.Value) {
        foreach ($segment in @($segmentsProperty.Value)) {
            $startText = ""
            $endText = ""
            if ($segment.PSObject.Properties["StartText"]) {
                $startText = [string]$segment.StartText
            }
            elseif ($segment.PSObject.Properties["TrimStart"]) {
                $startText = [string]$segment.TrimStart
            }

            if ($segment.PSObject.Properties["EndText"]) {
                $endText = [string]$segment.EndText
            }
            elseif ($segment.PSObject.Properties["TrimEnd"]) {
                $endText = [string]$segment.TrimEnd
            }

            if (-not [string]::IsNullOrWhiteSpace($startText) -and -not [string]::IsNullOrWhiteSpace($endText)) {
                $trimSegments += [pscustomobject]@{
                    StartText = $startText
                    EndText = $endText
                }
            }
        }
    }

    $trimStartText = Get-PlanItemPropertyText -Item $Item -Name "TrimStartText" -Default ""
    $trimEndText = Get-PlanItemPropertyText -Item $Item -Name "TrimEndText" -Default ""
    $trimSummary = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default ""
    $trimDurationSeconds = $null
    if ($Item.PSObject.Properties["TrimDurationSeconds"] -and $null -ne $Item.TrimDurationSeconds) {
        $trimDurationSeconds = [double]$Item.TrimDurationSeconds
    }

    if ($trimSegments.Count -gt 0) {
        $normalized = Get-VhsMp4TrimSegments -TrimSegments $trimSegments
        $trimSummary = [string]$normalized.Summary
        $trimDurationSeconds = [double]$normalized.TotalDurationSeconds
        if ([string]::IsNullOrWhiteSpace($trimStartText)) {
            $trimStartText = [string]$normalized.Segments[0].StartText
        }
        if ([string]::IsNullOrWhiteSpace($trimEndText)) {
            $trimEndText = [string]$normalized.Segments[0].EndText
        }
        $trimSegments = @()
        foreach ($segment in @($normalized.Segments)) {
            $trimSegments += [pscustomobject]@{
                StartText = [string]$segment.StartText
                EndText = [string]$segment.EndText
                Summary = [string]$segment.Summary
            }
        }
    }

    $previewPositionSeconds = 0.0
    if ($Item.PSObject.Properties["PreviewPositionSeconds"] -and $null -ne $Item.PreviewPositionSeconds) {
        $previewPositionSeconds = [double]$Item.PreviewPositionSeconds
    }

    return [pscustomobject]@{
        TrimStartText = $trimStartText
        TrimEndText = $trimEndText
        TrimSummary = $trimSummary
        TrimDurationSeconds = $trimDurationSeconds
        TrimSegments = @($trimSegments)
        PreviewPositionSeconds = $previewPositionSeconds
    }
}

function Get-PlanItemCropSourceDimensions {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return [pscustomobject]@{
            SourceWidth = $null
            SourceHeight = $null
        }
    }

    $sourceWidth = $null
    $sourceHeight = $null
    $candidates = @($Item)
    if ($Item.PSObject.Properties["MediaInfo"] -and $null -ne $Item.MediaInfo) {
        $candidates += $Item.MediaInfo
    }

    foreach ($candidate in $candidates) {
        if ($null -eq $candidate) {
            continue
        }

        if ($null -eq $sourceWidth) {
            foreach ($name in @("SourceWidth", "Width")) {
                if ($candidate.PSObject.Properties[$name] -and $null -ne $candidate.$name) {
                    try {
                        $sourceWidth = [int]$candidate.$name
                        break
                    }
                    catch {
                    }
                }
            }
        }

        if ($null -eq $sourceHeight) {
            foreach ($name in @("SourceHeight", "Height")) {
                if ($candidate.PSObject.Properties[$name] -and $null -ne $candidate.$name) {
                    try {
                        $sourceHeight = [int]$candidate.$name
                        break
                    }
                    catch {
                    }
                }
            }
        }
    }

    if (($null -eq $sourceWidth -or $null -eq $sourceHeight) -and $Item.PSObject.Properties["MediaInfo"] -and $null -ne $Item.MediaInfo) {
        $resolutionText = if ($Item.MediaInfo.PSObject.Properties["Resolution"]) { [string]$Item.MediaInfo.Resolution } else { "" }
        $resolutionMatch = [regex]::Match($resolutionText, '^\s*(\d+)\s*x\s*(\d+)\s*$')
        if ($resolutionMatch.Success) {
            if ($null -eq $sourceWidth) {
                $sourceWidth = [int]$resolutionMatch.Groups[1].Value
            }
            if ($null -eq $sourceHeight) {
                $sourceHeight = [int]$resolutionMatch.Groups[2].Value
            }
        }
    }

    return [pscustomobject]@{
        SourceWidth = $sourceWidth
        SourceHeight = $sourceHeight
    }
}

function Copy-PlanItemCropState {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return [pscustomobject]@{
            CropMode = ""
            CropLeft = 0
            CropTop = 0
            CropRight = 0
            CropBottom = 0
            CropSummary = ""
            SourceWidth = $null
            SourceHeight = $null
        }
    }

    $source = Get-PlanItemCropSourceDimensions -Item $Item
    $cropInput = [pscustomobject]@{
        CropMode = Get-PlanItemPropertyText -Item $Item -Name "CropMode" -Default ""
        CropLeft = if ($Item.PSObject.Properties["CropLeft"]) { $Item.CropLeft } else { $null }
        CropTop = if ($Item.PSObject.Properties["CropTop"]) { $Item.CropTop } else { $null }
        CropRight = if ($Item.PSObject.Properties["CropRight"]) { $Item.CropRight } else { $null }
        CropBottom = if ($Item.PSObject.Properties["CropBottom"]) { $Item.CropBottom } else { $null }
        SourceWidth = $source.SourceWidth
        SourceHeight = $source.SourceHeight
    }

    try {
        $normalized = Get-VhsMp4CropState -InputObject $cropInput
    }
    catch {
        $normalized = [pscustomobject]@{
            Mode = "None"
            Left = 0
            Top = 0
            Right = 0
            Bottom = 0
            Summary = ""
            SourceWidth = $source.SourceWidth
            SourceHeight = $source.SourceHeight
        }
    }

    $cropMode = if ([string]$normalized.Mode -eq "None") { "" } else { [string]$normalized.Mode }
    $cropSummary = Get-PlanItemPropertyText -Item $Item -Name "CropSummary" -Default ""
    if ([string]::IsNullOrWhiteSpace($cropSummary)) {
        $cropSummary = [string]$normalized.Summary
    }

    return [pscustomobject]@{
        CropMode = $cropMode
        CropLeft = [int]$normalized.Left
        CropTop = [int]$normalized.Top
        CropRight = [int]$normalized.Right
        CropBottom = [int]$normalized.Bottom
        CropSummary = $cropSummary
        SourceWidth = $normalized.SourceWidth
        SourceHeight = $normalized.SourceHeight
    }
}

function Get-PlanItemCropOverlayState {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return $null
    }

    $cropState = Copy-PlanItemCropState -Item $Item
    if ([string]::IsNullOrWhiteSpace([string]$cropState.CropMode)) {
        return $null
    }

    try {
        return (Get-VhsMp4CropState -InputObject ([pscustomobject]@{
                Mode = [string]$cropState.CropMode
                Left = [int]$cropState.CropLeft
                Top = [int]$cropState.CropTop
                Right = [int]$cropState.CropRight
                Bottom = [int]$cropState.CropBottom
                SourceWidth = $cropState.SourceWidth
                SourceHeight = $cropState.SourceHeight
            }))
    }
    catch {
        return $null
    }
}

function Get-PlanItemCropStatusText {
    param(
        $Item
    )

    $overlayState = Get-PlanItemCropOverlayState -Item $Item
    if ($null -eq $overlayState) {
        return "Crop: --"
    }

    return ("Crop: " + [string]$overlayState.Mode)
}

function Get-PreviewCropOverlayText {
    param(
        $Item
    )

    $overlayState = Get-PlanItemCropOverlayState -Item $Item
    if ($null -eq $overlayState) {
        return "Crop overlay: --"
    }

    return ("Crop overlay: {0} | L{1} T{2} R{3} B{4} | {5}x{6}" -f `
            [string]$overlayState.Mode, `
            [int]$overlayState.Left, `
            [int]$overlayState.Top, `
            [int]$overlayState.Right, `
            [int]$overlayState.Bottom, `
            [int]$overlayState.Width, `
            [int]$overlayState.Height)
}

function Get-PictureBoxImageDisplayRectangle {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.PictureBox]$PictureBox
    )

    if ($null -eq $PictureBox.Image) {
        return [System.Drawing.Rectangle]::Empty
    }

    $clientWidth = [Math]::Max(1, $PictureBox.ClientSize.Width)
    $clientHeight = [Math]::Max(1, $PictureBox.ClientSize.Height)
    $imageWidth = [Math]::Max(1, $PictureBox.Image.Width)
    $imageHeight = [Math]::Max(1, $PictureBox.Image.Height)

    $scale = [Math]::Min(([double]$clientWidth / [double]$imageWidth), ([double]$clientHeight / [double]$imageHeight))
    $displayWidth = [Math]::Max(1, [int][Math]::Round($imageWidth * $scale, 0, [System.MidpointRounding]::AwayFromZero))
    $displayHeight = [Math]::Max(1, [int][Math]::Round($imageHeight * $scale, 0, [System.MidpointRounding]::AwayFromZero))
    $offsetX = [int][Math]::Floor(($clientWidth - $displayWidth) / 2.0)
    $offsetY = [int][Math]::Floor(($clientHeight - $displayHeight) / 2.0)

    return (New-Object System.Drawing.Rectangle($offsetX, $offsetY, $displayWidth, $displayHeight))
}

function Get-PreviewCropOverlayRectangle {
    param(
        [AllowNull()]
        $Item,
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.PictureBox]$PictureBox
    )

    if ($null -eq $Item) {
        return [System.Drawing.Rectangle]::Empty
    }

    $overlayState = Get-PlanItemCropOverlayState -Item $Item
    if ($null -eq $overlayState) {
        return [System.Drawing.Rectangle]::Empty
    }

    $displayRectangle = Get-PictureBoxImageDisplayRectangle -PictureBox $PictureBox
    if ($displayRectangle.IsEmpty -or $overlayState.SourceWidth -le 0 -or $overlayState.SourceHeight -le 0) {
        return [System.Drawing.Rectangle]::Empty
    }

    $scaleX = [double]$displayRectangle.Width / [double]$overlayState.SourceWidth
    $scaleY = [double]$displayRectangle.Height / [double]$overlayState.SourceHeight
    $x = $displayRectangle.X + [int][Math]::Round([double]$overlayState.Left * $scaleX, 0, [System.MidpointRounding]::AwayFromZero)
    $y = $displayRectangle.Y + [int][Math]::Round([double]$overlayState.Top * $scaleY, 0, [System.MidpointRounding]::AwayFromZero)
    $width = [int][Math]::Round([double]$overlayState.Width * $scaleX, 0, [System.MidpointRounding]::AwayFromZero)
    $height = [int][Math]::Round([double]$overlayState.Height * $scaleY, 0, [System.MidpointRounding]::AwayFromZero)

    if ($width -le 0 -or $height -le 0) {
        return [System.Drawing.Rectangle]::Empty
    }

    return (New-Object System.Drawing.Rectangle($x, $y, $width, $height))
}

function Update-PreviewCropOverlay {
    $item = Get-SelectedPlanItem

    if (Get-Variable -Name "previewCropOverlayLabel" -ErrorAction SilentlyContinue) {
        $previewCropOverlayLabel.Text = Get-PreviewCropOverlayText -Item $item
        if ($previewCropOverlayLabel.Text -eq "Crop overlay: --") {
            $previewCropOverlayLabel.ForeColor = [System.Drawing.SystemColors]::GrayText
        }
        else {
            $previewCropOverlayLabel.ForeColor = [System.Drawing.Color]::FromArgb(22, 101, 52)
        }
    }

    if (Get-Variable -Name "previewPictureBox" -ErrorAction SilentlyContinue) {
        $previewPictureBox.Invalidate()
    }
}

function Draw-PreviewCropOverlay {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.PictureBox]$PictureBox,
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.PaintEventArgs]$EventArgs,
        $Item
    )

    if ($null -eq $Item -or $null -eq $PictureBox.Image) {
        return
    }

    $displayRectangle = Get-PictureBoxImageDisplayRectangle -PictureBox $PictureBox
    $cropRectangle = Get-PreviewCropOverlayRectangle -Item $Item -PictureBox $PictureBox
    if ($displayRectangle.IsEmpty -or $cropRectangle.IsEmpty) {
        return
    }

    $graphics = $EventArgs.Graphics
    $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110, 0, 0, 0))
    $outlinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(34, 197, 94), 2)
    try {
        $topHeight = [Math]::Max(0, $cropRectangle.Y - $displayRectangle.Y)
        $leftWidth = [Math]::Max(0, $cropRectangle.X - $displayRectangle.X)
        $rightX = $cropRectangle.Right
        $rightWidth = [Math]::Max(0, $displayRectangle.Right - $rightX)
        $bottomY = $cropRectangle.Bottom
        $bottomHeight = [Math]::Max(0, $displayRectangle.Bottom - $bottomY)

        if ($topHeight -gt 0) {
            $graphics.FillRectangle($overlayBrush, $displayRectangle.X, $displayRectangle.Y, $displayRectangle.Width, $topHeight)
        }
        if ($bottomHeight -gt 0) {
            $graphics.FillRectangle($overlayBrush, $displayRectangle.X, $bottomY, $displayRectangle.Width, $bottomHeight)
        }
        if ($leftWidth -gt 0) {
            $graphics.FillRectangle($overlayBrush, $displayRectangle.X, $cropRectangle.Y, $leftWidth, $cropRectangle.Height)
        }
        if ($rightWidth -gt 0) {
            $graphics.FillRectangle($overlayBrush, $rightX, $cropRectangle.Y, $rightWidth, $cropRectangle.Height)
        }

        $graphics.DrawRectangle($outlinePen, $cropRectangle)
    }
    finally {
        $outlinePen.Dispose()
        $overlayBrush.Dispose()
    }
}

function Get-PlanItemDetectedCropState {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    if ($null -eq $Item) {
        return $null
    }

    $cropSource = Get-PlanItemCropSourceDimensions -Item $Item
    if ($null -eq $cropSource.SourceWidth -or $null -eq $cropSource.SourceHeight) {
        return $null
    }

    $candidateInputs = New-Object System.Collections.Generic.List[object]
    $candidateInputs.Add((Copy-PlanItemCropState -Item $Item))

    $candidates = New-Object System.Collections.Generic.List[object]
    $candidates.Add($Item)
    if ($Item.PSObject.Properties["MediaInfo"] -and $null -ne $Item.MediaInfo) {
        $candidates.Add($Item.MediaInfo)
    }

    foreach ($candidate in $candidates) {
        if ($null -eq $candidate) {
            continue
        }

        foreach ($detectedProperty in @("DetectedCrop", "CropDetected", "CropDetection", "AutoCrop")) {
            if ($candidate.PSObject.Properties[$detectedProperty] -and $null -ne $candidate.$detectedProperty) {
                $candidateInputs.Add([pscustomobject]@{
                        Mode = if ($candidate.$detectedProperty.PSObject.Properties["Mode"]) { [string]$candidate.$detectedProperty.Mode } else { "Auto" }
                        Left = if ($candidate.$detectedProperty.PSObject.Properties["Left"]) { $candidate.$detectedProperty.Left } elseif ($candidate.$detectedProperty.PSObject.Properties["CropLeft"]) { $candidate.$detectedProperty.CropLeft } else { $null }
                        Top = if ($candidate.$detectedProperty.PSObject.Properties["Top"]) { $candidate.$detectedProperty.Top } elseif ($candidate.$detectedProperty.PSObject.Properties["CropTop"]) { $candidate.$detectedProperty.CropTop } else { $null }
                        Right = if ($candidate.$detectedProperty.PSObject.Properties["Right"]) { $candidate.$detectedProperty.Right } elseif ($candidate.$detectedProperty.PSObject.Properties["CropRight"]) { $candidate.$detectedProperty.CropRight } else { $null }
                        Bottom = if ($candidate.$detectedProperty.PSObject.Properties["Bottom"]) { $candidate.$detectedProperty.Bottom } elseif ($candidate.$detectedProperty.PSObject.Properties["CropBottom"]) { $candidate.$detectedProperty.CropBottom } else { $null }
                        SourceWidth = $cropSource.SourceWidth
                        SourceHeight = $cropSource.SourceHeight
                    })
                break
            }
        }

        $sampleSet = $null
        foreach ($sampleProperty in @("Samples", "CropSamples", "DetectionSamples")) {
            if ($candidate.PSObject.Properties[$sampleProperty] -and $null -ne $candidate.$sampleProperty) {
                $sampleSet = $candidate.$sampleProperty
                break
            }
        }

        if ($null -ne $sampleSet) {
            $candidateInputs.Add([pscustomobject]@{
                    SourceWidth = $cropSource.SourceWidth
                    SourceHeight = $cropSource.SourceHeight
                    Samples = $sampleSet
                })
        }
    }

    foreach ($candidateInput in $candidateInputs) {
        try {
            $detected = Get-VhsMp4DetectedCrop -InputObject $candidateInput
            if ([string]$detected.Mode -eq "Auto") {
                return [pscustomobject]@{
                    CropMode = "Auto"
                    CropLeft = [int]$detected.Left
                    CropTop = [int]$detected.Top
                    CropRight = [int]$detected.Right
                    CropBottom = [int]$detected.Bottom
                    CropSummary = [string]$detected.Summary
                }
            }
        }
        catch {
        }

        try {
            $normalized = Get-VhsMp4CropState -InputObject $candidateInput
            if ([string]$normalized.Mode -ne "None") {
                return [pscustomobject]@{
                    CropMode = if ([string]$normalized.Mode -eq "Auto") { "Auto" } else { "Manual" }
                    CropLeft = [int]$normalized.Left
                    CropTop = [int]$normalized.Top
                    CropRight = [int]$normalized.Right
                    CropBottom = [int]$normalized.Bottom
                    CropSummary = [string]$normalized.Summary
                }
            }
        }
        catch {
        }
    }

    return $null
}

function Apply-PlayerTrimStateToItem {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        $TrimState
    )

    foreach ($name in @("TrimSegments", "TrimStartText", "TrimEndText", "TrimStartSeconds", "TrimEndSeconds", "TrimDurationSeconds", "TrimSummary")) {
        if ($Item.PSObject.Properties[$name]) {
            $Item.PSObject.Properties.Remove($name)
        }
    }

    $segments = @()
    if ($TrimState.PSObject.Properties["TrimSegments"] -and $null -ne $TrimState.TrimSegments) {
        $segments = @($TrimState.TrimSegments)
    }

    if ($segments.Count -gt 0) {
        $normalized = Get-VhsMp4TrimSegments -TrimSegments $segments
        $Item | Add-Member -NotePropertyName "TrimSegments" -NotePropertyValue $normalized.Segments -Force
        $Item | Add-Member -NotePropertyName "TrimStartText" -NotePropertyValue "" -Force
        $Item | Add-Member -NotePropertyName "TrimEndText" -NotePropertyValue "" -Force
        $Item | Add-Member -NotePropertyName "TrimStartSeconds" -NotePropertyValue $null -Force
        $Item | Add-Member -NotePropertyName "TrimEndSeconds" -NotePropertyValue $null -Force
        $Item | Add-Member -NotePropertyName "TrimDurationSeconds" -NotePropertyValue $normalized.TotalDurationSeconds -Force
        $Item | Add-Member -NotePropertyName "TrimSummary" -NotePropertyValue $normalized.Summary -Force
    }
    else {
        $window = Get-VhsMp4TrimWindow -TrimStart ([string]$TrimState.TrimStartText) -TrimEnd ([string]$TrimState.TrimEndText)
        if (-not [string]::IsNullOrWhiteSpace([string]$window.Summary)) {
            $Item | Add-Member -NotePropertyName "TrimStartText" -NotePropertyValue $window.StartText -Force
            $Item | Add-Member -NotePropertyName "TrimEndText" -NotePropertyValue $window.EndText -Force
            $Item | Add-Member -NotePropertyName "TrimStartSeconds" -NotePropertyValue $window.StartSeconds -Force
            $Item | Add-Member -NotePropertyName "TrimEndSeconds" -NotePropertyValue $window.EndSeconds -Force
            $Item | Add-Member -NotePropertyName "TrimDurationSeconds" -NotePropertyValue $window.DurationSeconds -Force
            $Item | Add-Member -NotePropertyName "TrimSummary" -NotePropertyValue $window.Summary -Force
        }
    }

    if ($TrimState.PSObject.Properties["PreviewPositionSeconds"] -and $null -ne $TrimState.PreviewPositionSeconds) {
        $Item | Add-Member -NotePropertyName "PreviewPositionSeconds" -NotePropertyValue ([double]$TrimState.PreviewPositionSeconds) -Force
    }

    Update-PlanItemTrimEstimate -Item $Item
    Update-SelectedTrimGridRow -Item $Item
    $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
}

function Clear-PlanItemCropState {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    foreach ($name in @("CropMode", "CropLeft", "CropTop", "CropRight", "CropBottom", "CropSummary", "CropDetectedAt", "CropDetectionConfidence", "CropDetectionSampleCount")) {
        if ($Item.PSObject.Properties[$name]) {
            $Item.PSObject.Properties.Remove($name)
        }
    }

    Sync-PlanItemAspectSnapshot -Item $Item | Out-Null
    $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
    Update-SelectedTrimGridRow -Item $Item
}

function Apply-PlayerCropStateToItem {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        $CropState
    )

    Clear-PlanItemCropState -Item $Item

    if ($null -eq $CropState) {
        return
    }

    $mode = ""
    if ($CropState.PSObject.Properties["CropMode"]) {
        $mode = [string]$CropState.CropMode
    }
    elseif ($CropState.PSObject.Properties["Mode"]) {
        $mode = [string]$CropState.Mode
    }

    $left = if ($CropState.PSObject.Properties["CropLeft"]) { $CropState.CropLeft } elseif ($CropState.PSObject.Properties["Left"]) { $CropState.Left } else { $null }
    $top = if ($CropState.PSObject.Properties["CropTop"]) { $CropState.CropTop } elseif ($CropState.PSObject.Properties["Top"]) { $CropState.Top } else { $null }
    $right = if ($CropState.PSObject.Properties["CropRight"]) { $CropState.CropRight } elseif ($CropState.PSObject.Properties["Right"]) { $CropState.Right } else { $null }
    $bottom = if ($CropState.PSObject.Properties["CropBottom"]) { $CropState.CropBottom } elseif ($CropState.PSObject.Properties["Bottom"]) { $CropState.Bottom } else { $null }
    $hasValues = ($null -ne $left) -or ($null -ne $top) -or ($null -ne $right) -or ($null -ne $bottom)

    if ([string]::IsNullOrWhiteSpace($mode) -and $hasValues) {
        $mode = "Manual"
    }

    if ([string]::IsNullOrWhiteSpace($mode) -or $mode -eq "None") {
        return
    }

    $source = Get-PlanItemCropSourceDimensions -Item $Item
    $normalized = Get-VhsMp4CropState -InputObject ([pscustomobject]@{
            Mode = $mode
            Left = $left
            Top = $top
            Right = $right
            Bottom = $bottom
            SourceWidth = $source.SourceWidth
            SourceHeight = $source.SourceHeight
        })

    if ([string]$normalized.Mode -eq "None") {
        return
    }

    $Item | Add-Member -NotePropertyName "CropMode" -NotePropertyValue ([string]$normalized.Mode) -Force
    $Item | Add-Member -NotePropertyName "CropLeft" -NotePropertyValue ([int]$normalized.Left) -Force
    $Item | Add-Member -NotePropertyName "CropTop" -NotePropertyValue ([int]$normalized.Top) -Force
    $Item | Add-Member -NotePropertyName "CropRight" -NotePropertyValue ([int]$normalized.Right) -Force
    $Item | Add-Member -NotePropertyName "CropBottom" -NotePropertyValue ([int]$normalized.Bottom) -Force
    $Item | Add-Member -NotePropertyName "CropSummary" -NotePropertyValue ([string]$normalized.Summary) -Force
    Sync-PlanItemAspectSnapshot -Item $Item | Out-Null
    $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
    Update-SelectedTrimGridRow -Item $Item
}

function Test-PlaybackPreferredFormat {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    if ($null -eq $Item -or [string]::IsNullOrWhiteSpace([string]$Item.SourcePath)) {
        return $false
    }

    $extension = [System.IO.Path]::GetExtension([string]$Item.SourcePath)
    return $extension -in @(".mp4", ".mov", ".mkv")
}

function Get-PlayerTrimWindowTitle {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    return "Player / Trim - " + [string]$Item.SourceName
}

function Get-PlanItemAspectSnapshotPropertyNames {
    return @(
        "AspectMode",
        "DetectedAspectMode",
        "DetectedAspectConfidence",
        "DetectedDisplayAspectRatio",
        "DetectedSampleAspectRatio",
        "OutputAspectMode",
        "AspectSummary",
        "OutputAspectWidth",
        "OutputAspectHeight"
    )
}

function Get-PlanItemCurrentAspectSnapshot {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item -or -not $Item.PSObject.Properties["MediaInfo"] -or $null -eq $Item.MediaInfo) {
        return $null
    }

    $aspectMode = Get-PlanItemPropertyText -Item $Item -Name "AspectMode" -Default "Auto"
    $cropState = Copy-PlanItemCropState -Item $Item
    if ([string]::IsNullOrWhiteSpace([string]$cropState.CropMode)) {
        $cropState = $null
    }

    try {
        return (Get-VhsMp4AspectSnapshot -InputObject $Item.MediaInfo -AspectMode $aspectMode -CropState $cropState)
    }
    catch {
        return $null
    }
}

function Sync-PlanItemAspectSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $snapshot = Get-PlanItemCurrentAspectSnapshot -Item $Item
    foreach ($propertyName in @(Get-PlanItemAspectSnapshotPropertyNames)) {
        if ($Item.PSObject.Properties[$propertyName]) {
            $Item.PSObject.Properties.Remove($propertyName)
        }
    }

    if ($null -eq $snapshot) {
        return $null
    }

    foreach ($property in $snapshot.PSObject.Properties) {
        $Item | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value -Force
    }

    return $snapshot
}

function Get-AspectModeDisplayName {
    param(
        [string]$AspectMode,
        [string]$Default = "Auto"
    )

    switch ([string]$AspectMode) {
        "Auto" { return "Auto" }
        "KeepOriginal" { return "Keep Original" }
        "Force4x3" { return "Force 4:3" }
        "Force16x9" { return "Force 16:9" }
        default { return $Default }
    }
}

function Get-AspectModeShortLabel {
    param(
        [string]$AspectMode
    )

    switch ([string]$AspectMode) {
        "KeepOriginal" { return "Keep" }
        "Force4x3" { return "4:3" }
        "Force16x9" { return "16:9" }
        default { return "--" }
    }
}

function Update-PlanItemAspectPresentation {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    Sync-PlanItemAspectSnapshot -Item $Item | Out-Null
    $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
    Update-SelectedTrimGridRow -Item $Item
}

function Select-PlanGridRowBySourceName {
    param(
        [string]$SourceName
    )

    if ([string]::IsNullOrWhiteSpace($SourceName)) {
        $grid.ClearSelection()
        return $false
    }

    foreach ($row in $grid.Rows) {
        $isMatch = ([string]$row.Cells["SourceName"].Value -eq $SourceName)
        $row.Selected = $isMatch
        if ($isMatch) {
            $grid.CurrentCell = $row.Cells["SourceName"]
            return $true
        }
    }

    return $false
}

function Sync-AspectModeControls {
    if (-not (Get-Variable -Name "aspectModeComboBox" -ErrorAction SilentlyContinue)) {
        return
    }

    $script:AspectModeControlSync = $true
    try {
        $selectedItem = Get-SelectedPlanItem
        if ($null -eq $selectedItem) {
            $aspectModeComboBox.SelectedItem = "Auto"
        }
        else {
            $aspectModeComboBox.SelectedItem = Get-AspectModeDisplayName -AspectMode (Get-PlanItemPropertyText -Item $selectedItem -Name "AspectMode" -Default "Auto")
        }

        if (Get-Variable -Name "copyAspectToAllButton" -ErrorAction SilentlyContinue) {
            $copyAspectToAllButton.Enabled = (Test-CanEditPlanItem -Item $selectedItem) -and ($script:PlanItems.Count -gt 0)
        }
    }
    finally {
        $script:AspectModeControlSync = $false
    }
}

function Set-SelectedPlanItemAspectMode {
    param(
        [string]$AspectMode = "Auto"
    )

    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return $false
    }

    $normalizedAspectMode = Get-VhsMp4NormalizedAspectMode -AspectMode $AspectMode
    $item | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue $normalizedAspectMode -Force
    Update-PlanItemAspectPresentation -Item $item
    Update-PlanItemTrimEstimate -Item $item
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    return $true
}

function Copy-SelectedAspectModeToAll {
    $selectedItem = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $selectedItem)) {
        return $false
    }

    $sourceName = [string]$selectedItem.SourceName
    $aspectMode = Get-PlanItemPropertyText -Item $selectedItem -Name "AspectMode" -Default "Auto"
    foreach ($item in @($script:PlanItems)) {
        if ($null -eq $item) {
            continue
        }

        if ((Test-BatchPaused) -and -not (Test-PlanItemQueued -Item $item)) {
            continue
        }

        $item | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue $aspectMode -Force
        Update-PlanItemAspectPresentation -Item $item
        Update-PlanItemTrimEstimate -Item $item
    }

    [void](Select-PlanGridRowBySourceName -SourceName $sourceName)
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    return $true
}

function Get-PlanItemAspectStatusText {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return "--"
    }

    $snapshot = Get-PlanItemCurrentAspectSnapshot -Item $Item
    if ($null -eq $snapshot) {
        return "--"
    }

    $aspectMode = [string]$snapshot.AspectMode
    $outputAspectMode = [string]$snapshot.OutputAspectMode
    if ([string]::IsNullOrWhiteSpace($outputAspectMode)) {
        if ($aspectMode -eq "Auto") {
            return "--"
        }
        return (Get-AspectModeShortLabel -AspectMode $aspectMode)
    }

    if ($aspectMode -eq "Auto") {
        $shortLabel = Get-AspectModeShortLabel -AspectMode $outputAspectMode
        if ($shortLabel -eq "--") {
            return "Auto"
        }
        return "Auto " + $shortLabel
    }

    if ($aspectMode -eq "KeepOriginal") {
        return "Keep"
    }

    return "Manual " + (Get-AspectModeShortLabel -AspectMode $aspectMode)
}

function Get-CurrentVideoBitrateText {
    if (-not (Get-Variable -Name "videoBitrateTextBox" -ErrorAction SilentlyContinue)) {
        return ""
    }

    return [string]$videoBitrateTextBox.Text.Trim()
}

function Get-VhsMp4VideoCodecDisplayName {
    param(
        [string]$Codec
    )

    switch -Regex ([string]$Codec) {
        '(^|_)h264|libx264' { return "H.264" }
        '(^|_)hevc|libx265' { return "H.265 / HEVC" }
        default { return [string]$Codec }
    }
}

function Get-PlanItemPlannedDurationText {
    param(
        [AllowNull()]
        $Item,
        $MediaInfo
    )

    $trimDurationProperty = if ($null -ne $Item) { $Item.PSObject.Properties["TrimDurationSeconds"] } else { $null }
    if ($trimDurationProperty -and $null -ne $trimDurationProperty.Value -and [double]$trimDurationProperty.Value -gt 0) {
        return (Format-VhsMp4Duration -Seconds ([double]$trimDurationProperty.Value))
    }

    if ($null -ne $MediaInfo -and -not [string]::IsNullOrWhiteSpace([string]$MediaInfo.DurationText)) {
        return [string]$MediaInfo.DurationText
    }

    return "--"
}

function Get-PlanItemOutputPlanState {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return [pscustomobject]@{
            Container = "MP4"
            Resolution = "--"
            DurationText = "--"
            VideoSummary = "--"
            AudioSummary = "--"
            BitrateText = "--"
            Details = "Planirani izlaz nije dostupan."
        }
    }

    $mediaInfoProperty = $Item.PSObject.Properties["MediaInfo"]
    $mediaInfo = if ($mediaInfoProperty) { $mediaInfoProperty.Value } else { $null }
    $qualityMode = Get-CurrentInternalQualityModeName
    if ([string]::IsNullOrWhiteSpace($qualityMode)) {
        $qualityMode = "Universal MP4 H.264"
    }
    $crfValue = 22
    [void][int]::TryParse([string]$crfTextBox.Text, [ref]$crfValue)
    $presetName = [string]$presetComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($presetName)) {
        $presetName = "slow"
    }
    $audioBitrate = [string]$audioTextBox.Text
    if ([string]::IsNullOrWhiteSpace($audioBitrate) -or $audioBitrate -notmatch '^\d+k$') {
        $audioBitrate = "160k"
    }
    $videoBitrate = Get-CurrentVideoBitrateText
    if (-not [string]::IsNullOrWhiteSpace($videoBitrate) -and $videoBitrate -notmatch '^\d+k$') {
        $videoBitrate = ""
    }
    $encoderMode = if (Get-Variable -Name encoderModeComboBox -ErrorAction SilentlyContinue) { [string]$encoderModeComboBox.SelectedItem } else { $script:EncoderModeDefaultName }
    $profile = Get-VhsMp4QualityProfile -QualityMode $qualityMode -Crf $crfValue -Preset $presetName -AudioBitrate $audioBitrate
    $encoderPlan = Resolve-VhsMp4VideoEncoderPlan -QualityProfile $profile -EncoderMode $encoderMode -EncoderInventory $script:EncoderInventory -VideoBitrate $videoBitrate
    $durationSeconds = 0.0
    if ($null -ne $mediaInfo -and $null -ne $mediaInfo.DurationSeconds) {
        $durationSeconds = [double]$mediaInfo.DurationSeconds
    }
    $trimDurationProperty = $Item.PSObject.Properties["TrimDurationSeconds"]
    if ($trimDurationProperty -and $null -ne $trimDurationProperty.Value -and [double]$trimDurationProperty.Value -gt 0) {
        $durationSeconds = [double]$trimDurationProperty.Value
    }

    $maxPartGbForEstimate = 3.8
    if (Get-Variable -Name maxPartGbTextBox -ErrorAction SilentlyContinue) {
        $rawMaxPartText = [string]$maxPartGbTextBox.Text
        if (-not [string]::IsNullOrWhiteSpace($rawMaxPartText)) {
            [void][double]::TryParse($rawMaxPartText.Trim().Replace(",", "."), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$maxPartGbForEstimate)
        }
    }

    $estimate = if ($durationSeconds -gt 0) {
        Get-VhsMp4EstimatedOutputInfo `
            -DurationSeconds $durationSeconds `
            -QualityMode $qualityMode `
            -Crf $crfValue `
            -AudioBitrate $audioBitrate `
            -VideoBitrate $videoBitrate `
            -SplitOutput:$splitOutputCheckBox.Checked `
            -MaxPartGb $maxPartGbForEstimate
    }
    else {
        $null
    }

    $snapshot = Get-PlanItemCurrentAspectSnapshot -Item $Item
    $plannedResolution = if ($null -ne $snapshot -and $null -ne $snapshot.OutputAspectWidth -and $null -ne $snapshot.OutputAspectHeight) {
        "$([string]$snapshot.OutputAspectWidth)x$([string]$snapshot.OutputAspectHeight)"
    }
    elseif ($null -ne $mediaInfo -and -not [string]::IsNullOrWhiteSpace([string]$mediaInfo.Resolution)) {
        [string]$mediaInfo.Resolution
    }
    else {
        "--"
    }

    $videoCodecLabel = Get-VhsMp4VideoCodecDisplayName -Codec ([string]$encoderPlan.VideoCodec)
    $rateControlText = if (-not [string]::IsNullOrWhiteSpace([string]$videoBitrate)) {
        "Target $videoBitrate"
    }
    else {
        "CRF $crfValue | preset $presetName"
    }
    $videoSummary = "$videoCodecLabel | $rateControlText | $([string]$encoderPlan.ResolvedMode)"
    $audioSummary = "AAC | $([string]$profile.AudioBitrate)"
    $videoKbpsText = if ($null -ne $estimate) { Format-VhsMp4KbpsText -Kbps ([int]$estimate.VideoKbps) } else { "--" }
    $audioKbpsText = if ($null -ne $estimate) { Format-VhsMp4KbpsText -Kbps ([int]$estimate.AudioKbps) } else { "--" }
    $totalKbpsText = if ($null -ne $estimate) { Format-VhsMp4KbpsText -Kbps ([int]$estimate.TotalKbps) + " est." } else { "--" }
    $estimatedSize = Get-PlanItemPropertyText -Item $Item -Name "EstimatedSize" -Default "Estimate: --"
    $usbNote = Get-PlanItemPropertyText -Item $Item -Name "UsbNote" -Default "USB note: --"
    $trimSummary = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default "--"
    $cropSummary = Get-PlanItemPropertyText -Item $Item -Name "CropSummary" -Default "--"
    $aspectStatus = Get-PlanItemAspectStatusText -Item $Item
    $displayOutputName = if ($Item.PSObject.Properties["DisplayOutputName"] -and -not [string]::IsNullOrWhiteSpace([string]$Item.DisplayOutputName)) { [string]$Item.DisplayOutputName } else { [System.IO.Path]::GetFileName([string]$Item.OutputPath) }
    $splitSummary = if ($splitOutputCheckBox.Checked -and $null -ne $estimate) {
        "On | oko $maxPartGbForEstimate GB | $([string]$estimate.PartCount) delova"
    }
    else {
        "Off"
    }

    $details = @"
Planned output

File: $displayOutputName
Container: MP4
Resolution: $plannedResolution
Duration: $(Get-PlanItemPlannedDurationText -Item $Item -MediaInfo $mediaInfo)
Video codec: $videoCodecLabel
Rate control: $rateControlText
Video bitrate: $videoKbpsText
Audio codec: AAC
Audio bitrate: $audioKbpsText
Total bitrate: $totalKbpsText
Encode engine: $([string]$encoderPlan.Summary)
Aspect: $aspectStatus
Trim: $trimSummary
Crop: $cropSummary
Split output: $splitSummary
$estimatedSize
$usbNote
"@

    return [pscustomobject]@{
        DisplayOutputName = $displayOutputName
        Container = "MP4"
        Resolution = $plannedResolution
        DurationText = (Get-PlanItemPlannedDurationText -Item $Item -MediaInfo $mediaInfo)
        VideoCodecLabel = $videoCodecLabel
        VideoSummary = $videoSummary
        VideoBitrateComparisonText = if (-not [string]::IsNullOrWhiteSpace([string]$videoBitrate)) { "$videoBitrate target | $videoKbpsText" } else { $videoKbpsText }
        AudioCodecText = "AAC"
        AudioBitrateText = $audioKbpsText
        AudioSummary = $audioSummary
        BitrateText = $totalKbpsText
        EncodeEngineText = [string]$encoderPlan.Summary
        EstimatedSizeText = $estimatedSize
        UsbNoteText = $usbNote
        Details = $details
    }
}

function Format-VhsMp4MediaDetails {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return (Get-MediaInfoIntroText)
    }

    $mediaInfoProperty = $Item.PSObject.Properties["MediaInfo"]
    $mediaInfo = if ($mediaInfoProperty) { $mediaInfoProperty.Value } else { $null }
    $estimatedSize = Get-PlanItemPropertyText -Item $Item -Name "EstimatedSize" -Default "Estimate: --"
    $usbNote = Get-PlanItemPropertyText -Item $Item -Name "UsbNote" -Default "USB note: --"
    $trimSummary = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default "--"
    $cropSummary = Get-PlanItemPropertyText -Item $Item -Name "CropSummary" -Default "--"
    $snapshot = Get-PlanItemCurrentAspectSnapshot -Item $Item
    $aspectModeRaw = if ($null -ne $snapshot) { [string]$snapshot.AspectMode } else { [string](Get-PlanItemPropertyText -Item $Item -Name "AspectMode" -Default "Auto") }
    $detectedAspectModeRaw = if ($null -ne $snapshot) { [string]$snapshot.DetectedAspectMode } else { "" }
    $aspectMode = Get-AspectModeDisplayName -AspectMode $aspectModeRaw
    $detectedAspectMode = Get-AspectModeDisplayName -AspectMode $detectedAspectModeRaw -Default "Not available"
    $aspectSummary = if ($null -ne $snapshot -and -not [string]::IsNullOrWhiteSpace([string]$snapshot.AspectSummary)) { [string]$snapshot.AspectSummary } else { "--" }
    $outputAspectWidth = if ($null -ne $snapshot -and $null -ne $snapshot.OutputAspectWidth) { [string]$snapshot.OutputAspectWidth } else { "--" }
    $outputAspectHeight = if ($null -ne $snapshot -and $null -ne $snapshot.OutputAspectHeight) { [string]$snapshot.OutputAspectHeight } else { "--" }

    if ($null -eq $mediaInfo) {
    return @"
Selected file / Properties

Input / source properties

File: $($Item.SourceName)
Path: $($Item.SourcePath)
Media info: nije dostupno

Aspect mode: $aspectMode
Detected: $detectedAspectMode
Aspect summary: $aspectSummary
Planned output aspect: $outputAspectWidth x $outputAspectHeight
Trim: $trimSummary
Crop: $cropSummary
$estimatedSize
$usbNote
"@
    }

    return @"
Selected file / Properties

Input / source properties

File: $($Item.SourceName)
Path: $($Item.SourcePath)

Container: $($mediaInfo.Container)
Container long name: $($mediaInfo.ContainerLongName)
Duration: $($mediaInfo.DurationText)
Size: $($mediaInfo.SizeText)
OverallBitrate: $($mediaInfo.OverallBitrateText)

Video:
Codec: $($mediaInfo.VideoCodec)
Resolution: $($mediaInfo.Resolution)
DisplayAspectRatio: $($mediaInfo.DisplayAspectRatio)
SampleAspectRatio: $($mediaInfo.SampleAspectRatio)
FPS: $($mediaInfo.FrameRateText)
Frames: $($mediaInfo.FrameCount)
VideoBitrate: $($mediaInfo.VideoBitrateText)

Audio:
Codec: $($mediaInfo.AudioCodec)
Channels: $($mediaInfo.AudioChannels)
Sample rate: $($mediaInfo.AudioSampleRateHz) Hz
AudioBitrate: $($mediaInfo.AudioBitrateText)

Output: $($Item.DisplayOutputName)
Aspect mode: $aspectMode
Detected: $detectedAspectMode
Aspect summary: $aspectSummary
Planned output aspect: $outputAspectWidth x $outputAspectHeight
Trim: $trimSummary
Crop: $cropSummary
$estimatedSize
$usbNote
"@
}

function Get-PlanItemComparisonRows {
    param(
        [AllowNull()]
        $Item
    )

    if ($null -eq $Item) {
        return @(
            [pscustomobject]@{
                PropertyName = "Info"
                InputValue = "Izaberi fajl iz tabele"
                PlannedValue = "Ovde poredimo ulaz i planirani izlaz"
            }
        )
    }

    $mediaInfo = if ($Item.PSObject.Properties["MediaInfo"]) { $Item.MediaInfo } else { $null }
    $outputState = Get-PlanItemOutputPlanState -Item $Item
    $trimSummary = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default "--"
    $cropSummary = Get-PlanItemPropertyText -Item $Item -Name "CropSummary" -Default "--"
    $aspectStatus = Get-PlanItemAspectStatusText -Item $Item
    $displayOutputName = if ($Item.PSObject.Properties["DisplayOutputName"] -and -not [string]::IsNullOrWhiteSpace([string]$Item.DisplayOutputName)) { [string]$Item.DisplayOutputName } else { [System.IO.Path]::GetFileName([string]$Item.OutputPath) }

    $inputContainer = if ($null -ne $mediaInfo) { [string]$mediaInfo.Container } else { "--" }
    $inputSize = if ($null -ne $mediaInfo -and -not [string]::IsNullOrWhiteSpace([string]$mediaInfo.SizeText)) { [string]$mediaInfo.SizeText } else { "--" }
    $inputResolution = if ($null -ne $mediaInfo) { [string]$mediaInfo.Resolution } else { "--" }
    $inputDuration = if ($null -ne $mediaInfo) { [string]$mediaInfo.DurationText } else { "--" }
    $inputVideoCodec = if ($null -ne $mediaInfo) { [string]$mediaInfo.VideoCodec } else { "--" }
    $inputVideoBitrate = if ($null -ne $mediaInfo) { [string]$mediaInfo.VideoBitrateText } else { "--" }
    $inputAudioCodec = if ($null -ne $mediaInfo) { [string]$mediaInfo.AudioCodec } else { "--" }
    $inputAudioBitrate = if ($null -ne $mediaInfo) { [string]$mediaInfo.AudioBitrateText } else { "--" }
    $inputFps = if ($null -ne $mediaInfo) { [string]$mediaInfo.FrameRateText } else { "--" }
    $inputAspect = if ($null -ne $mediaInfo) { [string]$mediaInfo.DisplayAspectRatio } else { "--" }

    return @(
        [pscustomobject]@{ PropertyName = "File"; InputValue = [string]$Item.SourceName; PlannedValue = $displayOutputName }
        [pscustomobject]@{ PropertyName = "Container"; InputValue = $inputContainer; PlannedValue = [string]$outputState.Container }
        [pscustomobject]@{ PropertyName = "Resolution"; InputValue = $inputResolution; PlannedValue = [string]$outputState.Resolution }
        [pscustomobject]@{ PropertyName = "Duration"; InputValue = $inputDuration; PlannedValue = [string]$outputState.DurationText }
        [pscustomobject]@{ PropertyName = "FPS"; InputValue = $inputFps; PlannedValue = "--" }
        [pscustomobject]@{ PropertyName = "Aspect"; InputValue = $inputAspect; PlannedValue = $aspectStatus }
        [pscustomobject]@{ PropertyName = "Video codec"; InputValue = $inputVideoCodec; PlannedValue = [string]$outputState.VideoCodecLabel }
        [pscustomobject]@{ PropertyName = "Video bitrate"; InputValue = $inputVideoBitrate; PlannedValue = [string]$outputState.VideoBitrateComparisonText }
        [pscustomobject]@{ PropertyName = "Audio codec"; InputValue = $inputAudioCodec; PlannedValue = [string]$outputState.AudioCodecText }
        [pscustomobject]@{ PropertyName = "Audio bitrate"; InputValue = $inputAudioBitrate; PlannedValue = [string]$outputState.AudioBitrateText }
        [pscustomobject]@{ PropertyName = "Total bitrate"; InputValue = if ($null -ne $mediaInfo) { [string]$mediaInfo.OverallBitrateText } else { "--" }; PlannedValue = [string]$outputState.BitrateText }
        [pscustomobject]@{ PropertyName = "Encode engine"; InputValue = "--"; PlannedValue = [string]$outputState.EncodeEngineText }
        [pscustomobject]@{ PropertyName = "Trim"; InputValue = "--"; PlannedValue = $trimSummary }
        [pscustomobject]@{ PropertyName = "Crop"; InputValue = "--"; PlannedValue = $cropSummary }
        [pscustomobject]@{ PropertyName = "Input size / estimate"; InputValue = $inputSize; PlannedValue = [string]$outputState.EstimatedSizeText }
        [pscustomobject]@{ PropertyName = "USB note"; InputValue = "--"; PlannedValue = [string]$outputState.UsbNoteText }
    )
}

function Update-ComparisonPanel {
    if (-not (Get-Variable -Name "comparisonGrid" -ErrorAction SilentlyContinue)) {
        return
    }

    $comparisonGrid.Rows.Clear()
    foreach ($row in @(Get-PlanItemComparisonRows -Item (Get-SelectedPlanItem))) {
        [void]$comparisonGrid.Rows.Add(
            [string]$row.PropertyName,
            [string]$row.InputValue,
            [string]$row.PlannedValue
        )
    }
    $comparisonGrid.ClearSelection()
}

function Update-MediaInfoPanel {
    if ($null -eq $infoBox) {
        return
    }

    if ($grid.SelectedRows.Count -gt 0) {
        $sourceName = [string]$grid.SelectedRows[0].Cells["SourceName"].Value
        foreach ($item in $script:PlanItems) {
            if ([string]$item.SourceName -eq $sourceName) {
                $details = Get-PlanItemPropertyText -Item $item -Name "MediaDetails" -Default ""
                if (-not [string]::IsNullOrWhiteSpace($details)) {
                    $infoBox.Text = $details
                    Update-OutputPlanPanel
                    return
                }

                $infoBox.Text = Format-VhsMp4MediaDetails -Item $item
                Update-OutputPlanPanel
                return
            }
        }
    }

    $infoBox.Text = Get-MediaInfoIntroText
    Update-OutputPlanPanel
}

function Update-OutputPlanPanel {
    if (-not (Get-Variable -Name "outputPlanInfoBox" -ErrorAction SilentlyContinue)) {
        return
    }

    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        $outputPlanInfoBox.Text = @"
Planned output

Izaberi fajl u queue listi da ovde odmah vidis planirani izlaz:
- codec i encode engine
- resolution i aspect
- video/audio bitrate
- trim/crop/split i procenu velicine
"@
        Update-ComparisonPanel
        return
    }

    $details = Get-PlanItemPropertyText -Item $item -Name "PlannedOutputDetails" -Default ""
    if (-not [string]::IsNullOrWhiteSpace($details)) {
        $outputPlanInfoBox.Text = $details
        Update-ComparisonPanel
        return
    }

    $outputPlanInfoBox.Text = (Get-PlanItemOutputPlanState -Item $item).Details
    Update-ComparisonPanel
}

function Get-SelectedPlanItem {
    if ($grid.SelectedRows.Count -le 0) {
        return $null
    }

    $sourceName = [string]$grid.SelectedRows[0].Cells["SourceName"].Value
    foreach ($item in $script:PlanItems) {
        if ([string]$item.SourceName -eq $sourceName) {
            return $item
        }
    }

    return $null
}

function Get-SelectedPreviewMediaInfo {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        return $null
    }

    $mediaInfoProperty = $item.PSObject.Properties["MediaInfo"]
    if (-not $mediaInfoProperty) {
        return $null
    }

    return $mediaInfoProperty.Value
}

function Get-SelectedPreviewDurationSeconds {
    $mediaInfo = Get-SelectedPreviewMediaInfo
    if ($null -eq $mediaInfo -or $null -eq $mediaInfo.DurationSeconds) {
        return 0.0
    }

    return [double]$mediaInfo.DurationSeconds
}

function Get-SelectedPreviewFrameRate {
    $mediaInfo = Get-SelectedPreviewMediaInfo
    if ($null -eq $mediaInfo -or $null -eq $mediaInfo.FrameRate -or [double]$mediaInfo.FrameRate -le 0) {
        return 25.0
    }

    return [double]$mediaInfo.FrameRate
}

function Get-PreviewFramePath {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $baseDir = $outputTextBox.Text
    if ([string]::IsNullOrWhiteSpace($baseDir) -and -not [string]::IsNullOrWhiteSpace($inputTextBox.Text)) {
        $baseDir = Join-Path $inputTextBox.Text "vhs-mp4-output"
    }
    if ([string]::IsNullOrWhiteSpace($baseDir)) {
        $baseDir = [System.IO.Path]::GetTempPath()
    }

    $previewDir = Join-Path $baseDir "preview-cache"
    $null = New-Item -ItemType Directory -Path $previewDir -Force
    $safeName = ([string]$Item.SourceName) -replace "[^A-Za-z0-9_.-]", "_"
    return (Join-Path $previewDir ($safeName + ".png"))
}

function Set-PreviewImage {
    param(
        [string]$ImagePath
    )

    if ($previewPictureBox.Image) {
        $oldImage = $previewPictureBox.Image
        $previewPictureBox.Image = $null
        $oldImage.Dispose()
    }

    if ([string]::IsNullOrWhiteSpace($ImagePath) -or -not (Test-Path -LiteralPath $ImagePath)) {
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($ImagePath)
    $stream = New-Object System.IO.MemoryStream(,$bytes)
    try {
        $image = [System.Drawing.Image]::FromStream($stream)
        try {
            $previewPictureBox.Image = New-Object System.Drawing.Bitmap($image)
        }
        finally {
            $image.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }

    $previewPictureBox.Invalidate()
}

function Get-PreviewPositionSeconds {
    try {
        $seconds = Convert-VhsMp4TimeTextToSeconds -Value $previewTimeTextBox.Text
        if ($null -eq $seconds) {
            return 0.0
        }

        return [double]$seconds
    }
    catch {
        return 0.0
    }
}

function Test-AutoPreviewEnabled {
    if (Test-BatchEditLocked) {
        return $false
    }

    $selectedItem = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $selectedItem)) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
        return $false
    }

    if (-not (Get-Variable -Name "autoPreviewCheckBox" -ErrorAction SilentlyContinue)) {
        return $false
    }

    return [bool]$autoPreviewCheckBox.Checked
}

function Request-AutoPreview {
    if (-not (Test-AutoPreviewEnabled)) {
        $script:PreviewAutoPending = $false
        if (Get-Variable -Name "previewAutoTimer" -ErrorAction SilentlyContinue) {
            $previewAutoTimer.Stop()
        }
        return
    }

    $script:PreviewAutoPending = $true
    if (Get-Variable -Name "previewAutoTimer" -ErrorAction SilentlyContinue) {
        $previewAutoTimer.Stop()
        $previewAutoTimer.Start()
        return
    }

    Invoke-PendingAutoPreview
}

function Invoke-PendingAutoPreview {
    if (Get-Variable -Name "previewAutoTimer" -ErrorAction SilentlyContinue) {
        $previewAutoTimer.Stop()
    }

    if (-not $script:PreviewAutoPending) {
        return
    }

    if (-not (Test-AutoPreviewEnabled)) {
        $script:PreviewAutoPending = $false
        return
    }

    $script:PreviewAutoPending = $false
    [void](Invoke-PreviewFrame -SilentErrors:$true -LogAction:$false -StatusPrefix "Auto preview")
}

function Set-PreviewPositionSeconds {
    param(
        [double]$Seconds,
        [bool]$RefreshImage = $false
    )

    $item = Get-SelectedPlanItem
    $duration = Get-SelectedPreviewDurationSeconds
    $position = [Math]::Max(0.0, $Seconds)
    if ($duration -gt 0) {
        $position = [Math]::Min($duration, $position)
    }

    $positionText = Format-VhsMp4FfmpegTime -Seconds $position
    if ([string]::IsNullOrWhiteSpace($positionText)) {
        $positionText = "00:00:00"
    }

    $previewTimeTextBox.Text = $positionText
    if ($null -ne $item) {
        $item | Add-Member -NotePropertyName "PreviewPositionSeconds" -NotePropertyValue $position -Force
    }

    if (Get-Variable -Name "previewTimelineTrackBar" -ErrorAction SilentlyContinue) {
        $maximum = [Math]::Max(1, [int][Math]::Round($duration * $script:PreviewTimelineScale, 0, [System.MidpointRounding]::AwayFromZero))
        if ($previewTimelineTrackBar.Maximum -ne $maximum) {
            $previewTimelineTrackBar.Maximum = $maximum
        }
        $previewTimelineTrackBar.TickFrequency = [Math]::Max(1, [int][Math]::Round($maximum / 10.0, 0, [System.MidpointRounding]::AwayFromZero))
        $previewTimelineTrackBar.LargeChange = [Math]::Max(1, $script:PreviewTimelineScale)
        $timelineValue = [Math]::Min($previewTimelineTrackBar.Maximum, [Math]::Max($previewTimelineTrackBar.Minimum, [int][Math]::Round($position * $script:PreviewTimelineScale, 0, [System.MidpointRounding]::AwayFromZero)))
        if ($previewTimelineTrackBar.Value -ne $timelineValue) {
            $previewTimelineTrackBar.Value = $timelineValue
        }
    }

    if (Get-Variable -Name "previewPositionLabel" -ErrorAction SilentlyContinue) {
        $durationText = if ($duration -gt 0) { Format-VhsMp4FfmpegTime -Seconds $duration } else { "--:--:--" }
        $previewPositionLabel.Text = $positionText + " / " + $durationText
    }

    if ($RefreshImage) {
        Request-AutoPreview
    }
}

function Update-PreviewTimeline {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        $previewTimeTextBox.Text = "00:00:00"
        $previewPositionLabel.Text = "00:00:00 / --:--:--"
        $previewTimelineTrackBar.Maximum = 1
        $previewTimelineTrackBar.Value = 0
        return
    }

    $duration = Get-SelectedPreviewDurationSeconds
    $position = $null
    $positionProperty = $item.PSObject.Properties["PreviewPositionSeconds"]
    if ($positionProperty -and $null -ne $positionProperty.Value) {
        $position = [double]$positionProperty.Value
    }

    if ($null -eq $position) {
        $parsedPosition = Get-PreviewPositionSeconds
        if ($parsedPosition -gt 0) {
            $position = $parsedPosition
        }
    }

    if ($null -eq $position) {
        $position = if ($duration -gt 0) { [Math]::Min(5.0, $duration) } else { 0.0 }
    }

    Set-PreviewPositionSeconds -Seconds $position -RefreshImage:$false
}

function Move-PreviewFrame {
    param(
        [int]$Direction,
        [bool]$RefreshImage = $true
    )

    $frameRate = Get-SelectedPreviewFrameRate
    $frameStep = if ($frameRate -gt 0) { 1.0 / $frameRate } else { 1.0 / 25.0 }
    $currentSeconds = Get-PreviewPositionSeconds
    Set-PreviewPositionSeconds -Seconds ($currentSeconds + ($Direction * $frameStep)) -RefreshImage:$RefreshImage
}

function Move-PreviewSeconds {
    param(
        [double]$SecondsDelta,
        [bool]$RefreshImage = $true
    )

    $currentSeconds = Get-PreviewPositionSeconds
    Set-PreviewPositionSeconds -Seconds ($currentSeconds + $SecondsDelta) -RefreshImage:$RefreshImage
}

function Format-CutTimelineMarkerText {
    param(
        [string]$TrimStart = "",
        [string]$TrimEnd = "",
        [double]$DurationSeconds = [double]::NaN
    )

    try {
        $window = Get-VhsMp4TrimWindow -TrimStart $TrimStart -TrimEnd $TrimEnd
    }
    catch {
        return "CUT: neispravno - End mora biti posle Start"
    }

    if ([string]::IsNullOrWhiteSpace($window.Summary)) {
        return "CUT: --"
    }

    $duration = $DurationSeconds
    if ([double]::IsNaN($duration)) {
        $duration = Get-SelectedPreviewDurationSeconds
    }
    if ($duration -le 0) {
        return "CUT: " + $window.Summary
    }

    $markerWidth = 28
    $markers = New-Object char[] $markerWidth
    for ($index = 0; $index -lt $markerWidth; $index++) {
        $markers[$index] = '-'
    }

    $startIndex = $null
    $endIndex = $null
    if ($null -ne $window.StartSeconds) {
        $startIndex = [Math]::Min($markerWidth - 1, [Math]::Max(0, [int][Math]::Round(([double]$window.StartSeconds / $duration) * ($markerWidth - 1))))
    }
    if ($null -ne $window.EndSeconds) {
        $endIndex = [Math]::Min($markerWidth - 1, [Math]::Max(0, [int][Math]::Round(([double]$window.EndSeconds / $duration) * ($markerWidth - 1))))
    }
    if ($null -ne $startIndex -and $null -ne $endIndex -and $endIndex -le $startIndex -and [double]$window.EndSeconds -gt [double]$window.StartSeconds) {
        $endIndex = [Math]::Min($markerWidth - 1, $startIndex + 1)
    }

    if ($null -ne $startIndex -and $null -ne $endIndex) {
        for ($index = $startIndex; $index -le $endIndex; $index++) {
            $markers[$index] = '='
        }
    }

    if ($null -ne $startIndex) {
        $markers[$startIndex] = 'S'
    }
    if ($null -ne $endIndex) {
        $markers[$endIndex] = 'E'
    }

    return ("CUT: [" + (-join $markers) + "] " + $window.Summary)
}

function Update-CutRangeDisplay {
    $cutText = Format-CutTimelineMarkerText -TrimStart $trimStartTextBox.Text -TrimEnd $trimEndTextBox.Text
    $isInvalid = $cutText -like "CUT: neispravno*"
    $cutColor = if ($isInvalid) { [System.Drawing.Color]::FromArgb(176, 32, 32) } else { [System.Drawing.SystemColors]::ControlText }

    if (Get-Variable -Name "cutRangeLabel" -ErrorAction SilentlyContinue) {
        $cutRangeLabel.Text = $cutText
        $cutRangeLabel.ForeColor = $cutColor
    }

    if (Get-Variable -Name "previewTrimSummaryLabel" -ErrorAction SilentlyContinue) {
        $previewTrimSummaryLabel.Text = $cutText
        $previewTrimSummaryLabel.ForeColor = $cutColor
    }

    if (Get-Variable -Name "previewStartMarkerLabel" -ErrorAction SilentlyContinue) {
        $previewStartMarkerLabel.Text = if ([string]::IsNullOrWhiteSpace($trimStartTextBox.Text)) { "Start: --" } else { "Start: " + $trimStartTextBox.Text }
    }

    if (Get-Variable -Name "previewEndMarkerLabel" -ErrorAction SilentlyContinue) {
        $previewEndMarkerLabel.Text = if ([string]::IsNullOrWhiteSpace($trimEndTextBox.Text)) { "End: --" } else { "End: " + $trimEndTextBox.Text }
    }
}

function Get-SelectedTrimSegments {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        return @()
    }

    $segmentsProperty = $item.PSObject.Properties["TrimSegments"]
    if (-not $segmentsProperty -or $null -eq $segmentsProperty.Value) {
        return @()
    }

    return @($segmentsProperty.Value)
}

function Get-SelectedTrimSegmentIndex {
    if (-not (Get-Variable -Name "trimSegmentsListBox" -ErrorAction SilentlyContinue)) {
        return -1
    }

    $segments = @(Get-SelectedTrimSegments)
    if ($trimSegmentsListBox.SelectedIndex -lt 0 -or $trimSegmentsListBox.SelectedIndex -ge $segments.Count) {
        return -1
    }

    return [int]$trimSegmentsListBox.SelectedIndex
}

function Get-SelectedTrimSegment {
    $segments = @(Get-SelectedTrimSegments)
    $index = Get-SelectedTrimSegmentIndex
    if ($index -lt 0 -or $index -ge $segments.Count) {
        return $null
    }

    return $segments[$index]
}

function Sync-SelectedTrimSegmentsList {
    if (-not (Get-Variable -Name "trimSegmentsListBox" -ErrorAction SilentlyContinue)) {
        return
    }

    $segments = @(Get-SelectedTrimSegments)
    $selectedIndex = $script:PendingTrimSegmentIndex
    if ($selectedIndex -lt 0) {
        $selectedIndex = $trimSegmentsListBox.SelectedIndex
    }
    $script:PendingTrimSegmentIndex = -1

    $trimSegmentsListBox.Items.Clear()
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $segment = $segments[$index]
        [void]$trimSegmentsListBox.Items.Add(("{0}. {1}" -f ($index + 1), [string]$segment.Summary))
    }

    if ($segments.Count -gt 0) {
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $segments.Count) {
            $selectedIndex = 0
        }
        $trimSegmentsListBox.SelectedIndex = $selectedIndex
    }

    if (Get-Variable -Name "removeSegmentButton" -ErrorAction SilentlyContinue) {
        $removeSegmentButton.Enabled = $segments.Count -gt 0 -and $trimSegmentsListBox.SelectedIndex -ge 0 -and (Test-CanEditPlanItem -Item (Get-SelectedPlanItem))
    }
    if (Get-Variable -Name "clearSegmentsButton" -ErrorAction SilentlyContinue) {
        $clearSegmentsButton.Enabled = $segments.Count -gt 0 -and (Test-CanEditPlanItem -Item (Get-SelectedPlanItem))
    }
}

function Save-SelectedTrimSegments {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Segments,
        [int]$PreferredIndex = -1,
        [string]$LogAction = "Trim segments"
    )

    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        return
    }

    $normalized = Get-VhsMp4TrimSegments -TrimSegments $Segments
    $item | Add-Member -NotePropertyName "TrimSegments" -NotePropertyValue $normalized.Segments -Force
    $item | Add-Member -NotePropertyName "TrimStartText" -NotePropertyValue "" -Force
    $item | Add-Member -NotePropertyName "TrimEndText" -NotePropertyValue "" -Force
    $item | Add-Member -NotePropertyName "TrimStartSeconds" -NotePropertyValue $null -Force
    $item | Add-Member -NotePropertyName "TrimEndSeconds" -NotePropertyValue $null -Force
    $item | Add-Member -NotePropertyName "TrimDurationSeconds" -NotePropertyValue $normalized.TotalDurationSeconds -Force
    $item | Add-Member -NotePropertyName "TrimSummary" -NotePropertyValue $normalized.Summary -Force

    $script:PendingTrimSegmentIndex = if ($PreferredIndex -ge 0) { [Math]::Min($PreferredIndex, $normalized.Count - 1) } else { 0 }
    Update-PlanItemTrimEstimate -Item $item
    Update-SelectedTrimGridRow -Item $item
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    Add-LogLine ($LogAction + ": " + $item.SourceName + " | " + $normalized.Summary)
}

function Add-TrimSegmentFromFields {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    try {
        $window = Get-VhsMp4TrimWindow -TrimStart $trimStartTextBox.Text -TrimEnd $trimEndTextBox.Text
        if ([string]::IsNullOrWhiteSpace($window.Summary) -or [string]::IsNullOrWhiteSpace($window.StartText) -or [string]::IsNullOrWhiteSpace($window.EndText)) {
            throw "Za Add Segment unesi i Start i End."
        }

        $segments = New-Object System.Collections.Generic.List[object]
        foreach ($segment in (Get-SelectedTrimSegments)) {
            $segments.Add($segment)
        }
        $segments.Add([pscustomobject]@{
            StartText = $window.StartText
            EndText = $window.EndText
        })

        $normalized = Get-VhsMp4TrimSegments -TrimSegments $segments
        $preferredIndex = 0
        for ($index = 0; $index -lt $normalized.Count; $index++) {
            $segment = $normalized.Segments[$index]
            if ([string]$segment.StartText -eq [string]$window.StartText -and [string]$segment.EndText -eq [string]$window.EndText) {
                $preferredIndex = $index
                break
            }
        }

        Save-SelectedTrimSegments -Segments $normalized.Segments -PreferredIndex $preferredIndex -LogAction "Add Segment"
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Add Segment", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}

function Remove-SelectedTrimSegment {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    $segments = @(Get-SelectedTrimSegments)
    $selectedIndex = Get-SelectedTrimSegmentIndex
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $segments.Count) {
        return
    }

    $remaining = New-Object System.Collections.Generic.List[object]
    for ($index = 0; $index -lt $segments.Count; $index++) {
        if ($index -ne $selectedIndex) {
            $remaining.Add($segments[$index])
        }
    }

    if ($remaining.Count -gt 0) {
        Save-SelectedTrimSegments -Segments $remaining -PreferredIndex ([Math]::Min($selectedIndex, $remaining.Count - 1)) -LogAction "Remove Segment"
        return
    }

    Clear-SelectedTrimSegments
}

function Clear-SelectedTrimSegments {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    foreach ($name in @("TrimSegments", "TrimStartText", "TrimEndText", "TrimStartSeconds", "TrimEndSeconds", "TrimDurationSeconds", "TrimSummary")) {
        if ($item.PSObject.Properties[$name]) {
            $item.PSObject.Properties.Remove($name)
        }
    }

    $script:PendingTrimSegmentIndex = -1
    Update-PlanItemTrimEstimate -Item $item
    Update-SelectedTrimGridRow -Item $item
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    Add-LogLine ("Clear Segments: " + $item.SourceName)
}

function Set-TrimPointFromPreview {
    param(
        [ValidateSet("Start", "End")]
        [string]$Point
    )

    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    $previewTime = $previewTimeTextBox.Text
    if ([string]::IsNullOrWhiteSpace($previewTime)) {
        $previewTime = "00:00:00"
    }

    if ($Point -eq "Start") {
        $trimStartTextBox.Text = $previewTime
    }
    else {
        $trimEndTextBox.Text = $previewTime
    }

    Update-CutRangeDisplay
    $previewStatusLabel.Text = "Cut point: " + $Point + " = " + $previewTime + " | Apply Trim za potvrdu."
}

function Invoke-PreviewKeyboardShortcut {
    param(
        [System.Windows.Forms.Keys]$KeyCode,
        [bool]$Shift = $false,
        [bool]$Control = $false
    )

    if (Test-BatchEditLocked) {
        return $false
    }

    if (-not (Test-CanEditPlanItem -Item (Get-SelectedPlanItem))) {
        return $false
    }

    if ($KeyCode -eq [System.Windows.Forms.Keys]::Left -or $KeyCode -eq [System.Windows.Forms.Keys]::Right) {
        $direction = if ($KeyCode -eq [System.Windows.Forms.Keys]::Left) { -1 } else { 1 }
        if ($Control) {
            Move-PreviewSeconds -SecondsDelta ($direction * 10.0)
        }
        elseif ($Shift) {
            Move-PreviewSeconds -SecondsDelta ($direction * 1.0)
        }
        else {
            Move-PreviewFrame -Direction $direction
        }
        return $true
    }

    if ($KeyCode -eq [System.Windows.Forms.Keys]::I) {
        Set-TrimPointFromPreview -Point Start
        return $true
    }

    if ($KeyCode -eq [System.Windows.Forms.Keys]::O) {
        Set-TrimPointFromPreview -Point End
        return $true
    }

    if ($KeyCode -eq [System.Windows.Forms.Keys]::Space) {
        if (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
            Invoke-PreviewFrame
        }
        return $true
    }

    return $false
}

function Load-SelectedTrimFields {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        $trimStartTextBox.Text = ""
        $trimEndTextBox.Text = ""
        Update-CutRangeDisplay
        return
    }

    $selectedSegment = Get-SelectedTrimSegment
    if ($null -ne $selectedSegment) {
        $trimStartTextBox.Text = [string]$selectedSegment.StartText
        $trimEndTextBox.Text = [string]$selectedSegment.EndText
    }
    else {
        $trimStartTextBox.Text = Get-PlanItemPropertyText -Item $item -Name "TrimStartText" -Default ""
        $trimEndTextBox.Text = Get-PlanItemPropertyText -Item $item -Name "TrimEndText" -Default ""
    }

    Update-CutRangeDisplay
}

function Update-PreviewTrimPanel {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        $previewStatusLabel.Text = "Selected file"
        if (Get-Variable -Name "selectedFileSummaryLabel" -ErrorAction SilentlyContinue) {
            $selectedFileSummaryLabel.Text = "Izaberi fajl u queue listi pa otvori Open Player kada hoces preview, trim, crop ili aspect korekciju."
        }
        Sync-SelectedTrimSegmentsList
        Load-SelectedTrimFields
        Update-PreviewTimeline
        Update-PreviewCropOverlay
        Sync-AspectModeControls
        Update-ActionButtons
        return
    }

    $trimSummary = Get-PlanItemPropertyText -Item $item -Name "TrimSummary" -Default "--"
    $cropStatus = Get-PlanItemCropStatusText -Item $item
    $aspectStatus = Get-PlanItemAspectStatusText -Item $item
    $previewStatusLabel.Text = "Selected file: " + $item.SourceName
    if (Get-Variable -Name "selectedFileSummaryLabel" -ErrorAction SilentlyContinue) {
        $selectedFileSummaryLabel.Text = "Range: " + $trimSummary + " | " + $cropStatus + " | Aspect: " + $aspectStatus + " | Open Player za detaljnu obradu."
    }
    Sync-SelectedTrimSegmentsList
    Load-SelectedTrimFields
    Update-PreviewTimeline
    Update-PreviewCropOverlay
    Sync-AspectModeControls

    $previewProperty = $item.PSObject.Properties["PreviewFramePath"]
    if ($previewProperty -and -not [string]::IsNullOrWhiteSpace([string]$previewProperty.Value) -and (Test-Path -LiteralPath ([string]$previewProperty.Value))) {
        try {
            Set-PreviewImage -ImagePath ([string]$previewProperty.Value)
        }
        catch {
            Add-LogLine ("Preview image load warning: " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        }
    }

    Update-ActionButtons
}

function Invoke-PreviewFrame {
    param(
        [bool]$SilentErrors = $false,
        [bool]$LogAction = $true,
        [string]$StatusPrefix = "Preview Frame"
    )

    if (Test-BatchEditLocked) {
        return $false
    }

    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
        if (-not $SilentErrors) {
            [System.Windows.Forms.MessageBox]::Show("FFmpeg nije spreman za Preview Frame.", "Preview Frame", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        return $false
    }

    try {
        $previewPath = Get-PreviewFramePath -Item $item
        $previewTime = $previewTimeTextBox.Text
        if ([string]::IsNullOrWhiteSpace($previewTime)) {
            $previewTime = "00:00:05"
        }

        $result = New-VhsMp4PreviewFrame -SourcePath $item.SourcePath -OutputPath $previewPath -FfmpegPath $script:ResolvedFfmpegPath -PreviewTime $previewTime
        if (-not $result.Success) {
            throw "FFmpeg preview exit code: $($result.ExitCode) | $($result.ErrorText)"
        }

        $item | Add-Member -NotePropertyName "PreviewFramePath" -NotePropertyValue $previewPath -Force
        Set-PreviewImage -ImagePath $previewPath
        if (-not [string]::IsNullOrWhiteSpace($StatusPrefix)) {
            $previewStatusLabel.Text = $StatusPrefix + ": " + $item.SourceName + " @ " + $result.PreviewTime
        }
        if ($LogAction) {
            Add-LogLine ("Preview Frame: " + $item.SourcePath + " -> " + $previewPath)
        }
        return $true
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        if ($LogAction) {
            Add-LogLine ("Preview Frame failed: " + $message)
        }
        if (-not $SilentErrors) {
            [System.Windows.Forms.MessageBox]::Show($message, "Preview Frame", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        return $false
    }
}

function Open-SelectedVideo {
    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        return
    }

    try {
        Start-Process -FilePath $item.SourcePath
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Open Video", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}

function Open-PlayerTrimWindow {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [switch]$PreviewOnly,
        [switch]$Modeless,
        [System.Windows.Forms.Form]$OwnerForm,
        [scriptblock]$OnSave
    )

    $trimState = Copy-PlanItemTrimState -Item $Item
    $cropState = Copy-PlanItemCropState -Item $Item
    $initialAspectMode = Get-VhsMp4NormalizedAspectMode -AspectMode (Get-PlanItemPropertyText -Item $Item -Name "AspectMode" -Default "Auto")
    $mediaInfo = $null
    if ($Item.PSObject.Properties["MediaInfo"]) {
        $mediaInfo = $Item.MediaInfo
    }

    $durationSeconds = 0.0
    if ($null -ne $mediaInfo -and $null -ne $mediaInfo.DurationSeconds) {
        $durationSeconds = [double]$mediaInfo.DurationSeconds
    }

    $frameRate = 25.0
    if ($null -ne $mediaInfo -and $null -ne $mediaInfo.FrameRate -and [double]$mediaInfo.FrameRate -gt 0) {
        $frameRate = [double]$mediaInfo.FrameRate
    }

    $initialMode = if (Test-PlaybackPreferredFormat -Item $Item) { "Playback mode" } else { "Preview mode" }
    if ($PreviewOnly) {
        $previewAspectState = $null
        try {
            if ($null -ne $mediaInfo) {
                $previewAspectState = Get-VhsMp4AspectSnapshot -InputObject $mediaInfo -AspectMode $initialAspectMode -CropState $cropState
            }
        }
        catch {
            $previewAspectState = $null
        }

        return [pscustomobject]@{
            Saved = $false
            Mode = $initialMode
            TrimState = $trimState
            CropState = $cropState
            AspectState = $previewAspectState
        }
    }

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = Get-PlayerTrimWindowTitle -Item $Item
    $dialog.StartPosition = if ($Modeless -and $null -ne $script:PlayerTrimEditorBounds) { "Manual" } elseif ($null -ne $OwnerForm) { "CenterParent" } else { "CenterScreen" }
    $dialog.Width = 1320
    $dialog.Height = 860
    $dialog.MinimumSize = New-Object System.Drawing.Size(1120, 760)
    $dialog.KeyPreview = $true
    $dialog.BackColor = [System.Drawing.SystemColors]::Control
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    if (Test-Path -LiteralPath $script:AppIconPath) {
        $dialog.Icon = New-Object System.Drawing.Icon $script:AppIconPath
    }
    if ($Modeless -and $null -ne $script:PlayerTrimEditorBounds) {
        $dialog.Bounds = $script:PlayerTrimEditorBounds
    }

    $localState = [ordered]@{
        Mode = $initialMode
        TrimStartText = [string]$trimState.TrimStartText
        TrimEndText = [string]$trimState.TrimEndText
        TrimSummary = [string]$trimState.TrimSummary
        TrimDurationSeconds = $trimState.TrimDurationSeconds
        TrimSegments = @($trimState.TrimSegments)
        PreviewPositionSeconds = [double]$trimState.PreviewPositionSeconds
        CropMode = [string]$cropState.CropMode
        CropLeft = [int]$cropState.CropLeft
        CropTop = [int]$cropState.CropTop
        CropRight = [int]$cropState.CropRight
        CropBottom = [int]$cropState.CropBottom
        CropSummary = [string]$cropState.CropSummary
        CropFieldSync = $false
        AspectMode = [string]$initialAspectMode
        DetectedAspectLabel = ""
        DetectedDisplayAspectRatio = ""
        DetectedSampleAspectRatio = ""
        OutputAspectWidth = $null
        OutputAspectHeight = $null
        AspectModeControlSync = $false
        Dirty = $false
    }

    if ($localState.PreviewPositionSeconds -le 0) {
        $localState.PreviewPositionSeconds = if ($durationSeconds -gt 0) { [Math]::Min(5.0, $durationSeconds) } else { 0.0 }
    }

    $dialogResult = [pscustomobject]@{
        Saved = $false
        Mode = $localState.Mode
        TrimState = $trimState
        CropState = $cropState
    }
    $closingAfterSave = $false
    $playbackReady = $false

    $playerRootLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $playerRootLayout.Dock = "Fill"
    $playerRootLayout.ColumnCount = 2
    $playerRootLayout.RowCount = 2
    $playerRootLayout.Padding = New-Object System.Windows.Forms.Padding(10)
    $playerRootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $playerRootLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 360)))
    $playerRootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))
    $playerRootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($playerRootLayout)

    $playerHeaderLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $playerHeaderLayout.Dock = "Fill"
    $playerHeaderLayout.ColumnCount = 1
    $playerHeaderLayout.RowCount = 2
    $playerHeaderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
    $playerHeaderLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $playerRootLayout.Controls.Add($playerHeaderLayout, 0, 0)
    $playerRootLayout.SetColumnSpan($playerHeaderLayout, 2)

    $playerModeLabel = New-Object System.Windows.Forms.Label
    $playerModeLabel.Dock = "Fill"
    $playerModeLabel.TextAlign = "MiddleLeft"
    $playerModeLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $playerHeaderLayout.Controls.Add($playerModeLabel, 0, 0)

    $metaParts = New-Object System.Collections.Generic.List[string]
    $metaParts.Add([string]$Item.SourceName)
    if ($null -ne $mediaInfo) {
        if (-not [string]::IsNullOrWhiteSpace([string]$mediaInfo.ContainerLongName)) { $metaParts.Add([string]$mediaInfo.ContainerLongName) }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$mediaInfo.Container)) { $metaParts.Add([string]$mediaInfo.Container) }
        if (-not [string]::IsNullOrWhiteSpace([string]$mediaInfo.DurationText)) { $metaParts.Add([string]$mediaInfo.DurationText) }
        if (-not [string]::IsNullOrWhiteSpace([string]$mediaInfo.Resolution)) { $metaParts.Add([string]$mediaInfo.Resolution) }
        if (-not [string]::IsNullOrWhiteSpace([string]$mediaInfo.FrameRateText)) { $metaParts.Add([string]$mediaInfo.FrameRateText) }
    }

    $playerMetaLabel = New-Object System.Windows.Forms.Label
    $playerMetaLabel.Dock = "Fill"
    $playerMetaLabel.TextAlign = "MiddleLeft"
    $playerMetaLabel.Text = ($metaParts -join " | ")
    $playerMetaLabel.MaximumSize = New-Object System.Drawing.Size(1220, 0)
    $playerHeaderLayout.Controls.Add($playerMetaLabel, 0, 1)

    $playerWorkspaceLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $playerWorkspaceLayout.Dock = "Fill"
    $playerWorkspaceLayout.ColumnCount = 1
    $playerWorkspaceLayout.RowCount = 5
    $playerWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $playerWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $playerWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $playerWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))
    $playerWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $playerRootLayout.Controls.Add($playerWorkspaceLayout, 0, 1)

    $surfacePanel = New-Object System.Windows.Forms.Panel
    $surfacePanel.Dock = "Fill"
    $playerWorkspaceLayout.Controls.Add($surfacePanel, 0, 0)

    $playbackHost = New-Object System.Windows.Forms.Integration.ElementHost
    $playbackHost.Dock = "Fill"
    $playbackHost.BackColor = [System.Drawing.Color]::Black
    $surfacePanel.Controls.Add($playbackHost)

    $playerPreviewPictureBox = New-Object System.Windows.Forms.PictureBox
    $playerPreviewPictureBox.Dock = "Fill"
    $playerPreviewPictureBox.BorderStyle = "FixedSingle"
    $playerPreviewPictureBox.SizeMode = "Zoom"
    $playerPreviewPictureBox.BackColor = [System.Drawing.Color]::Black
    $surfacePanel.Controls.Add($playerPreviewPictureBox)

    $wpfGrid = New-Object System.Windows.Controls.Grid
    $wpfGrid.Background = [System.Windows.Media.Brushes]::Black
    $mediaElement = New-Object System.Windows.Controls.MediaElement
    $mediaElement.LoadedBehavior = [System.Windows.Controls.MediaState]::Manual
    $mediaElement.UnloadedBehavior = [System.Windows.Controls.MediaState]::Manual
    $mediaElement.Stretch = [System.Windows.Media.Stretch]::Uniform
    $mediaElement.ScrubbingEnabled = $true
    $mediaElement.Volume = 0.0
    [void]$wpfGrid.Children.Add($mediaElement)
    $playbackHost.Child = $wpfGrid

    $timelineInfoLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $timelineInfoLayout.Dock = "Fill"
    $timelineInfoLayout.ColumnCount = 4
    $timelineInfoLayout.RowCount = 1
    $timelineInfoLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 96)))
    $timelineInfoLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 114)))
    $timelineInfoLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $timelineInfoLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 208)))
    $playerWorkspaceLayout.Controls.Add($timelineInfoLayout, 0, 1)

    $playerPreviewTimeLabel = New-Object System.Windows.Forms.Label
    $playerPreviewTimeLabel.Text = "Preview time"
    $playerPreviewTimeLabel.Dock = "Fill"
    $playerPreviewTimeLabel.TextAlign = "MiddleLeft"
    $timelineInfoLayout.Controls.Add($playerPreviewTimeLabel, 0, 0)

    $playerPreviewTimeTextBox = New-Object System.Windows.Forms.TextBox
    $playerPreviewTimeTextBox.Dock = "Fill"
    $playerPreviewTimeTextBox.Text = Format-VhsMp4FfmpegTime -Seconds $localState.PreviewPositionSeconds
    $timelineInfoLayout.Controls.Add($playerPreviewTimeTextBox, 1, 0)

    $playerPositionLabel = New-Object System.Windows.Forms.Label
    $playerPositionLabel.Dock = "Fill"
    $playerPositionLabel.TextAlign = "MiddleLeft"
    $timelineInfoLayout.Controls.Add($playerPositionLabel, 2, 0)

    $timelineActionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $timelineActionsFlow.Dock = "Fill"
    $timelineActionsFlow.WrapContents = $false
    $timelineActionsFlow.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
    $timelineInfoLayout.Controls.Add($timelineActionsFlow, 3, 0)

    $playerPreviewFrameButton = New-Object System.Windows.Forms.Button
    $playerPreviewFrameButton.Text = "Preview Frame"
    $playerPreviewFrameButton.AutoSize = $true
    $timelineActionsFlow.Controls.Add($playerPreviewFrameButton)

    $playerOpenVideoButton = New-Object System.Windows.Forms.Button
    $playerOpenVideoButton.Text = "Open Video"
    $playerOpenVideoButton.AutoSize = $true
    $timelineActionsFlow.Controls.Add($playerOpenVideoButton)

    $playerTimelineTrackBar = New-Object System.Windows.Forms.TrackBar
    $playerTimelineTrackBar.Dock = "Fill"
    $playerTimelineTrackBar.Minimum = 0
    $playerTimelineTrackBar.Maximum = [Math]::Max(1, [int][Math]::Round($durationSeconds * $script:PreviewTimelineScale, 0, [System.MidpointRounding]::AwayFromZero))
    $playerTimelineTrackBar.TickStyle = [System.Windows.Forms.TickStyle]::None
    $playerTimelineTrackBar.LargeChange = $script:PreviewTimelineScale
    $playerWorkspaceLayout.Controls.Add($playerTimelineTrackBar, 0, 2)

    $transportFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $transportFlow.Dock = "Fill"
    $transportFlow.WrapContents = $true
    $playerWorkspaceLayout.Controls.Add($transportFlow, 0, 3)

    $playPauseButton = New-Object System.Windows.Forms.Button
    $playPauseButton.Text = "Play / Pause"
    $playPauseButton.AutoSize = $true
    $transportFlow.Controls.Add($playPauseButton)

    $stopPlaybackButton = New-Object System.Windows.Forms.Button
    $stopPlaybackButton.Text = "Stop"
    $stopPlaybackButton.AutoSize = $true
    $transportFlow.Controls.Add($stopPlaybackButton)

    $previousPlayerFrameButton = New-Object System.Windows.Forms.Button
    $previousPlayerFrameButton.Text = "< Frame"
    $previousPlayerFrameButton.AutoSize = $true
    $transportFlow.Controls.Add($previousPlayerFrameButton)

    $nextPlayerFrameButton = New-Object System.Windows.Forms.Button
    $nextPlayerFrameButton.Text = "Frame >"
    $nextPlayerFrameButton.AutoSize = $true
    $transportFlow.Controls.Add($nextPlayerFrameButton)

    $setPlayerTrimStartButton = New-Object System.Windows.Forms.Button
    $setPlayerTrimStartButton.Text = "Set Start"
    $setPlayerTrimStartButton.AutoSize = $true
    $transportFlow.Controls.Add($setPlayerTrimStartButton)

    $setPlayerTrimEndButton = New-Object System.Windows.Forms.Button
    $setPlayerTrimEndButton.Text = "Set End"
    $setPlayerTrimEndButton.AutoSize = $true
    $transportFlow.Controls.Add($setPlayerTrimEndButton)

    $playerMarkersLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $playerMarkersLayout.Dock = "Fill"
    $playerMarkersLayout.ColumnCount = 3
    $playerMarkersLayout.RowCount = 1
    $playerMarkersLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 160)))
    $playerMarkersLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 160)))
    $playerMarkersLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $playerWorkspaceLayout.Controls.Add($playerMarkersLayout, 0, 4)

    $playerStartMarkerLabel = New-Object System.Windows.Forms.Label
    $playerStartMarkerLabel.Text = "Start: --"
    $playerStartMarkerLabel.Dock = "Fill"
    $playerStartMarkerLabel.TextAlign = "MiddleLeft"
    $playerMarkersLayout.Controls.Add($playerStartMarkerLabel, 0, 0)

    $playerEndMarkerLabel = New-Object System.Windows.Forms.Label
    $playerEndMarkerLabel.Text = "End: --"
    $playerEndMarkerLabel.Dock = "Fill"
    $playerEndMarkerLabel.TextAlign = "MiddleLeft"
    $playerMarkersLayout.Controls.Add($playerEndMarkerLabel, 1, 0)

    $playerTimelineSummaryLabel = New-Object System.Windows.Forms.Label
    $playerTimelineSummaryLabel.Text = "CUT: --"
    $playerTimelineSummaryLabel.Dock = "Fill"
    $playerTimelineSummaryLabel.TextAlign = "MiddleLeft"
    $playerTimelineSummaryLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
    $playerMarkersLayout.Controls.Add($playerTimelineSummaryLabel, 2, 0)

    $toolColumnLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $toolColumnLayout.Dock = "Fill"
    $toolColumnLayout.ColumnCount = 1
    $toolColumnLayout.RowCount = 5
    $toolColumnLayout.Padding = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
    $toolColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 222)))
    $toolColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
    $toolColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 126)))
    $toolColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $toolColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 40)))
    $playerRootLayout.Controls.Add($toolColumnLayout, 1, 1)

    $playerTrimGroupBox = New-Object System.Windows.Forms.GroupBox
    $playerTrimGroupBox.Text = "Trim"
    $playerTrimGroupBox.Dock = "Fill"
    $toolColumnLayout.Controls.Add($playerTrimGroupBox, 0, 0)

    $trimLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $trimLayout.Dock = "Fill"
    $trimLayout.ColumnCount = 2
    $trimLayout.RowCount = 5
    $trimLayout.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)
    $trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 118)))
    $trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 56)))
    $trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $playerTrimGroupBox.Controls.Add($trimLayout)

    $playerTrimStartLabel = New-Object System.Windows.Forms.Label
    $playerTrimStartLabel.Text = "Start (HH:MM:SS)"
    $playerTrimStartLabel.Dock = "Fill"
    $playerTrimStartLabel.TextAlign = "MiddleLeft"
    $trimLayout.Controls.Add($playerTrimStartLabel, 0, 0)

    $playerTrimStartTextBox = New-Object System.Windows.Forms.TextBox
    $playerTrimStartTextBox.Dock = "Fill"
    $trimLayout.Controls.Add($playerTrimStartTextBox, 1, 0)

    $playerTrimEndLabel = New-Object System.Windows.Forms.Label
    $playerTrimEndLabel.Text = "End (HH:MM:SS)"
    $playerTrimEndLabel.Dock = "Fill"
    $playerTrimEndLabel.TextAlign = "MiddleLeft"
    $trimLayout.Controls.Add($playerTrimEndLabel, 0, 1)

    $playerTrimEndTextBox = New-Object System.Windows.Forms.TextBox
    $playerTrimEndTextBox.Dock = "Fill"
    $trimLayout.Controls.Add($playerTrimEndTextBox, 1, 1)

    $trimActionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $trimActionsFlow.Dock = "Fill"
    $trimActionsFlow.WrapContents = $true
    $trimLayout.Controls.Add($trimActionsFlow, 0, 2)
    $trimLayout.SetColumnSpan($trimActionsFlow, 2)

    $applyPlayerTrimButton = New-Object System.Windows.Forms.Button
    $applyPlayerTrimButton.Text = "Apply Trim"
    $applyPlayerTrimButton.AutoSize = $true
    $trimActionsFlow.Controls.Add($applyPlayerTrimButton)

    $addPlayerSegmentButton = New-Object System.Windows.Forms.Button
    $addPlayerSegmentButton.Text = "Add Segment"
    $addPlayerSegmentButton.AutoSize = $true
    $trimActionsFlow.Controls.Add($addPlayerSegmentButton)

    $removePlayerSegmentButton = New-Object System.Windows.Forms.Button
    $removePlayerSegmentButton.Text = "Remove"
    $removePlayerSegmentButton.AutoSize = $true
    $trimActionsFlow.Controls.Add($removePlayerSegmentButton)

    $clearPlayerSegmentsButton = New-Object System.Windows.Forms.Button
    $clearPlayerSegmentsButton.Text = "Clear Seg"
    $clearPlayerSegmentsButton.AutoSize = $true
    $trimActionsFlow.Controls.Add($clearPlayerSegmentsButton)

    $clearPlayerTrimButton = New-Object System.Windows.Forms.Button
    $clearPlayerTrimButton.Text = "Clear Trim"
    $clearPlayerTrimButton.AutoSize = $true
    $trimActionsFlow.Controls.Add($clearPlayerTrimButton)

    $playerCutRangeLabel = New-Object System.Windows.Forms.Label
    $playerCutRangeLabel.Text = "CUT: --"
    $playerCutRangeLabel.Dock = "Fill"
    $playerCutRangeLabel.TextAlign = "MiddleLeft"
    $playerCutRangeLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
    $trimLayout.Controls.Add($playerCutRangeLabel, 0, 3)
    $trimLayout.SetColumnSpan($playerCutRangeLabel, 2)

    $playerSegmentsListBox = New-Object System.Windows.Forms.ComboBox
    $playerSegmentsListBox.Dock = "Fill"
    $playerSegmentsListBox.DropDownStyle = "DropDownList"
    $trimLayout.Controls.Add($playerSegmentsListBox, 0, 4)
    $trimLayout.SetColumnSpan($playerSegmentsListBox, 2)

    $cropGroupBox = New-Object System.Windows.Forms.GroupBox
    $cropGroupBox.Text = "Crop / Overscan"
    $cropGroupBox.Dock = "Fill"
    $toolColumnLayout.Controls.Add($cropGroupBox, 0, 1)

    $cropLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $cropLayout.Dock = "Fill"
    $cropLayout.ColumnCount = 4
    $cropLayout.RowCount = 4
    $cropLayout.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
    $cropLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 70)))
    $cropLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
    $cropLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 70)))
    $cropLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $cropLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
    $cropLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
    $cropLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $cropLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $cropGroupBox.Controls.Add($cropLayout)

    $playerCropLeftLabel = New-Object System.Windows.Forms.Label
    $playerCropLeftLabel.Text = "Left"
    $playerCropLeftLabel.Dock = "Fill"
    $playerCropLeftLabel.TextAlign = "MiddleLeft"
    $cropLayout.Controls.Add($playerCropLeftLabel, 0, 0)

    $playerCropLeftTextBox = New-Object System.Windows.Forms.TextBox
    $playerCropLeftTextBox.Dock = "Fill"
    $cropLayout.Controls.Add($playerCropLeftTextBox, 1, 0)

    $playerCropTopLabel = New-Object System.Windows.Forms.Label
    $playerCropTopLabel.Text = "Top"
    $playerCropTopLabel.Dock = "Fill"
    $playerCropTopLabel.TextAlign = "MiddleLeft"
    $cropLayout.Controls.Add($playerCropTopLabel, 2, 0)

    $playerCropTopTextBox = New-Object System.Windows.Forms.TextBox
    $playerCropTopTextBox.Dock = "Fill"
    $cropLayout.Controls.Add($playerCropTopTextBox, 3, 0)

    $playerCropRightLabel = New-Object System.Windows.Forms.Label
    $playerCropRightLabel.Text = "Right"
    $playerCropRightLabel.Dock = "Fill"
    $playerCropRightLabel.TextAlign = "MiddleLeft"
    $cropLayout.Controls.Add($playerCropRightLabel, 0, 1)

    $playerCropRightTextBox = New-Object System.Windows.Forms.TextBox
    $playerCropRightTextBox.Dock = "Fill"
    $cropLayout.Controls.Add($playerCropRightTextBox, 1, 1)

    $playerCropBottomLabel = New-Object System.Windows.Forms.Label
    $playerCropBottomLabel.Text = "Bottom"
    $playerCropBottomLabel.Dock = "Fill"
    $playerCropBottomLabel.TextAlign = "MiddleLeft"
    $cropLayout.Controls.Add($playerCropBottomLabel, 2, 1)

    $playerCropBottomTextBox = New-Object System.Windows.Forms.TextBox
    $playerCropBottomTextBox.Dock = "Fill"
    $cropLayout.Controls.Add($playerCropBottomTextBox, 3, 1)

    $cropButtonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $cropButtonsFlow.Dock = "Fill"
    $cropButtonsFlow.WrapContents = $false
    $cropLayout.Controls.Add($cropButtonsFlow, 0, 2)
    $cropLayout.SetColumnSpan($cropButtonsFlow, 4)

    $detectCropButton = New-Object System.Windows.Forms.Button
    $detectCropButton.Text = "Detect Crop"
    $detectCropButton.AutoSize = $true
    $cropButtonsFlow.Controls.Add($detectCropButton)

    $autoCropButton = New-Object System.Windows.Forms.Button
    $autoCropButton.Text = "Auto Crop"
    $autoCropButton.AutoSize = $true
    $cropButtonsFlow.Controls.Add($autoCropButton)

    $clearCropButton = New-Object System.Windows.Forms.Button
    $clearCropButton.Text = "Clear Crop"
    $clearCropButton.AutoSize = $true
    $cropButtonsFlow.Controls.Add($clearCropButton)

    $playerCropStateLabel = New-Object System.Windows.Forms.Label
    $playerCropStateLabel.Text = "Crop: --"
    $playerCropStateLabel.Dock = "Fill"
    $playerCropStateLabel.TextAlign = "MiddleLeft"
    $cropLayout.Controls.Add($playerCropStateLabel, 0, 3)
    $cropLayout.SetColumnSpan($playerCropStateLabel, 4)

    $aspectGroupBox = New-Object System.Windows.Forms.GroupBox
    $aspectGroupBox.Text = "Aspect / Pixel shape"
    $aspectGroupBox.Dock = "Fill"
    $toolColumnLayout.Controls.Add($aspectGroupBox, 0, 2)

    $aspectLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $aspectLayout.Dock = "Fill"
    $aspectLayout.ColumnCount = 4
    $aspectLayout.RowCount = 3
    $aspectLayout.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
    $aspectLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 140)))
    $aspectLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 220)))
    $aspectLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
    $aspectLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $aspectLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
    $aspectLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
    $aspectLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $aspectGroupBox.Controls.Add($aspectLayout)

    $playerAspectModeLabel = New-Object System.Windows.Forms.Label
    $playerAspectModeLabel.Text = "Aspect mode"
    $playerAspectModeLabel.Dock = "Fill"
    $playerAspectModeLabel.TextAlign = "MiddleLeft"
    $aspectLayout.Controls.Add($playerAspectModeLabel, 0, 0)

    $playerAspectModeComboBox = New-Object System.Windows.Forms.ComboBox
    $playerAspectModeComboBox.Name = "playerAspectModeComboBox"
    $playerAspectModeComboBox.Dock = "Fill"
    $playerAspectModeComboBox.DropDownStyle = "DropDownList"
    [void]$playerAspectModeComboBox.Items.Add("Auto")
    [void]$playerAspectModeComboBox.Items.Add("Keep Original")
    [void]$playerAspectModeComboBox.Items.Add("Force 4:3")
    [void]$playerAspectModeComboBox.Items.Add("Force 16:9")
    $aspectLayout.Controls.Add($playerAspectModeComboBox, 1, 0)

    $playerAspectDetailsLabel = New-Object System.Windows.Forms.Label
    $playerAspectDetailsLabel.Text = "Detected: --"
    $playerAspectDetailsLabel.Dock = "Fill"
    $playerAspectDetailsLabel.TextAlign = "MiddleLeft"
    $playerAspectDetailsLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
    $aspectLayout.Controls.Add($playerAspectDetailsLabel, 0, 1)
    $aspectLayout.SetColumnSpan($playerAspectDetailsLabel, 4)

    $playerAspectGeometryLabel = New-Object System.Windows.Forms.Label
    $playerAspectGeometryLabel.Text = "DAR: -- | SAR: -- | Output: -- x --"
    $playerAspectGeometryLabel.Dock = "Fill"
    $playerAspectGeometryLabel.TextAlign = "MiddleLeft"
    $playerAspectGeometryLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
    $aspectLayout.Controls.Add($playerAspectGeometryLabel, 0, 2)
    $aspectLayout.SetColumnSpan($playerAspectGeometryLabel, 4)

    $playerPropertiesGroupBox = New-Object System.Windows.Forms.GroupBox
    $playerPropertiesGroupBox.Text = "Properties"
    $playerPropertiesGroupBox.Dock = "Fill"
    $toolColumnLayout.Controls.Add($playerPropertiesGroupBox, 0, 3)

    $playerInfoBox = New-Object System.Windows.Forms.RichTextBox
    $playerInfoBox.Dock = "Fill"
    $playerInfoBox.ReadOnly = $true
    $playerInfoBox.BorderStyle = "None"
    $playerInfoBox.BackColor = [System.Drawing.SystemColors]::Window
    $playerInfoBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $playerInfoBox.Text = Format-VhsMp4MediaDetails -Item $Item
    $playerPropertiesGroupBox.Controls.Add($playerInfoBox)

    $dialogButtonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $dialogButtonsFlow.Dock = "Fill"
    $dialogButtonsFlow.WrapContents = $false
    $toolColumnLayout.Controls.Add($dialogButtonsFlow, 0, 4)

    $saveToQueueButton = New-Object System.Windows.Forms.Button
    $saveToQueueButton.Text = "Save to Queue"
    $saveToQueueButton.AutoSize = $true
    $saveToQueueButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $saveToQueueButton.ForeColor = [System.Drawing.Color]::White
    $saveToQueueButton.BackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
    $saveToQueueButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $dialogButtonsFlow.Controls.Add($saveToQueueButton)

    $cancelPlayerButton = New-Object System.Windows.Forms.Button
    $cancelPlayerButton.Text = if ($Modeless) { "Close" } else { "Cancel" }
    $cancelPlayerButton.AutoSize = $true
    $dialogButtonsFlow.Controls.Add($cancelPlayerButton)

    $playbackTimer = New-Object System.Windows.Forms.Timer
    $playbackTimer.Interval = 200
    $runtimeState = [pscustomobject]@{
        DurationSeconds = $durationSeconds
        FrameRate = $frameRate
        DialogResult = $dialogResult
        ClosingAfterSave = $closingAfterSave
        PlaybackReady = $playbackReady
    }

    $playerRuntimeContext = [pscustomobject]@{
        Dialog = $dialog
        Item = $Item
        MediaInfo = $mediaInfo
        LocalState = $localState
        RuntimeState = $runtimeState
        Modeless = [bool]$Modeless
        OnSave = $OnSave
        MediaElement = $mediaElement
        PlaybackHost = $playbackHost
        PlayerModeLabel = $playerModeLabel
        PlayerPreviewPictureBox = $playerPreviewPictureBox
        PlayPauseButton = $playPauseButton
        StopPlaybackButton = $stopPlaybackButton
        PlayerPreviewFrameButton = $playerPreviewFrameButton
        PlayerSegmentsListBox = $playerSegmentsListBox
        RemovePlayerSegmentButton = $removePlayerSegmentButton
        ClearPlayerSegmentsButton = $clearPlayerSegmentsButton
        PlayerTrimStartTextBox = $playerTrimStartTextBox
        PlayerTrimEndTextBox = $playerTrimEndTextBox
        PlayerCutRangeLabel = $playerCutRangeLabel
        PlayerTimelineSummaryLabel = $playerTimelineSummaryLabel
        PlayerStartMarkerLabel = $playerStartMarkerLabel
        PlayerEndMarkerLabel = $playerEndMarkerLabel
        PlayerCropLeftTextBox = $playerCropLeftTextBox
        PlayerCropTopTextBox = $playerCropTopTextBox
        PlayerCropRightTextBox = $playerCropRightTextBox
        PlayerCropBottomTextBox = $playerCropBottomTextBox
        PlayerCropStateLabel = $playerCropStateLabel
        PlayerAspectModeComboBox = $playerAspectModeComboBox
        PlayerAspectDetailsLabel = $playerAspectDetailsLabel
        PlayerAspectGeometryLabel = $playerAspectGeometryLabel
        PlayerPositionLabel = $playerPositionLabel
        PlayerPreviewTimeTextBox = $playerPreviewTimeTextBox
        PlayerTimelineTrackBar = $playerTimelineTrackBar
        PlaybackTimer = $playbackTimer
        ResolvedFfmpegPath = $script:ResolvedFfmpegPath
        PreviewTimelineScale = $script:PreviewTimelineScale
    }

    $playerRuntime = New-Module -AsCustomObject -ArgumentList $playerRuntimeContext -ScriptBlock {
        param($ctx)

        $dialog = $ctx.Dialog
        $Item = $ctx.Item
        $mediaInfo = $ctx.MediaInfo
        $localState = $ctx.LocalState
        $runtimeState = $ctx.RuntimeState
        $Modeless = [bool]$ctx.Modeless
        $OnSave = $ctx.OnSave
        $mediaElement = $ctx.MediaElement
        $playbackHost = $ctx.PlaybackHost
        $playerModeLabel = $ctx.PlayerModeLabel
        $playerPreviewPictureBox = $ctx.PlayerPreviewPictureBox
        $playPauseButton = $ctx.PlayPauseButton
        $stopPlaybackButton = $ctx.StopPlaybackButton
        $playerPreviewFrameButton = $ctx.PlayerPreviewFrameButton
        $playerSegmentsListBox = $ctx.PlayerSegmentsListBox
        $removePlayerSegmentButton = $ctx.RemovePlayerSegmentButton
        $clearPlayerSegmentsButton = $ctx.ClearPlayerSegmentsButton
        $playerTrimStartTextBox = $ctx.PlayerTrimStartTextBox
        $playerTrimEndTextBox = $ctx.PlayerTrimEndTextBox
        $playerCutRangeLabel = $ctx.PlayerCutRangeLabel
        $playerTimelineSummaryLabel = $ctx.PlayerTimelineSummaryLabel
        $playerStartMarkerLabel = $ctx.PlayerStartMarkerLabel
        $playerEndMarkerLabel = $ctx.PlayerEndMarkerLabel
        $playerCropLeftTextBox = $ctx.PlayerCropLeftTextBox
        $playerCropTopTextBox = $ctx.PlayerCropTopTextBox
        $playerCropRightTextBox = $ctx.PlayerCropRightTextBox
        $playerCropBottomTextBox = $ctx.PlayerCropBottomTextBox
        $playerCropStateLabel = $ctx.PlayerCropStateLabel
        $playerAspectModeComboBox = $ctx.PlayerAspectModeComboBox
        $playerAspectDetailsLabel = $ctx.PlayerAspectDetailsLabel
        $playerAspectGeometryLabel = $ctx.PlayerAspectGeometryLabel
        $playerPositionLabel = $ctx.PlayerPositionLabel
        $playerPreviewTimeTextBox = $ctx.PlayerPreviewTimeTextBox
        $playerTimelineTrackBar = $ctx.PlayerTimelineTrackBar
        $playbackTimer = $ctx.PlaybackTimer
        $resolvedFfmpegPath = [string]$ctx.ResolvedFfmpegPath
        $previewTimelineScale = [int]$ctx.PreviewTimelineScale

    function Set-PlayerTrimDialogDirty {
        param([bool]$Value = $true)
        $localState.Dirty = $Value
        $dirtyPrefix = ""
        if ($localState.Dirty) {
            $dirtyPrefix = "* "
        }
        $dialog.Text = $dirtyPrefix + (Get-PlayerTrimWindowTitle -Item $Item)
    }

    function Set-PlayerTrimDialogMode {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Mode,
            [string]$Reason = ""
        )

        $localState.Mode = $Mode
        if ($Mode -eq "Playback mode") {
            $playerModeLabel.Text = "Playback mode"
            $playerModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(22, 78, 99)
            $playbackHost.Visible = $true
            $playerPreviewPictureBox.Visible = $false
            $playPauseButton.Enabled = $true
            $stopPlaybackButton.Enabled = $true
            $playerPreviewFrameButton.Enabled = $false
        }
        else {
            $playerModeLabel.Text = "Preview mode"
            if (-not [string]::IsNullOrWhiteSpace($Reason)) {
                $playerModeLabel.Text += " | " + $Reason
            }
            $playerModeLabel.ForeColor = [System.Drawing.Color]::FromArgb(146, 64, 14)
            $playbackHost.Visible = $false
            $playerPreviewPictureBox.Visible = $true
            $playPauseButton.Enabled = $false
            $stopPlaybackButton.Enabled = $false
            $playerPreviewFrameButton.Enabled = -not [string]::IsNullOrWhiteSpace($resolvedFfmpegPath)
            try {
                $playbackTimer.Stop()
            }
            catch {
            }
            try {
                $mediaElement.Stop()
            }
            catch {
            }
        }
    }

    function Start-PlayerPlayback {
        if ($localState.Mode -ne "Playback mode") {
            return
        }

        try {
            $mediaElement.Play()
            $playbackTimer.Start()
        }
        catch {
            try {
                $playbackTimer.Stop()
            }
            catch {
            }
            Set-PlayerTrimDialogMode "Preview mode" "fallback"
        }
    }

    function Stop-PlayerPlayback {
        try {
            $playbackTimer.Stop()
        }
        catch {
        }

        try {
            $mediaElement.Stop()
        }
        catch {
        }
    }

    function Sync-PlayerSegmentsList {
        $playerSegmentsListBox.Items.Clear()
        $segments = @($localState.TrimSegments)
        for ($index = 0; $index -lt $segments.Count; $index++) {
            $summary = if ($segments[$index].PSObject.Properties["Summary"]) { [string]$segments[$index].Summary } else { ([string]$segments[$index].StartText + " - " + [string]$segments[$index].EndText) }
            [void]$playerSegmentsListBox.Items.Add(("{0}. {1}" -f ($index + 1), $summary))
        }

        if ($segments.Count -gt 0) {
            if ($playerSegmentsListBox.SelectedIndex -lt 0 -or $playerSegmentsListBox.SelectedIndex -ge $segments.Count) {
                $playerSegmentsListBox.SelectedIndex = 0
            }
        }

        $removePlayerSegmentButton.Enabled = $segments.Count -gt 0 -and $playerSegmentsListBox.SelectedIndex -ge 0
        $clearPlayerSegmentsButton.Enabled = $segments.Count -gt 0
    }

    function Update-PlayerCutDisplay {
        $cutText = Format-CutTimelineMarkerText -TrimStart $playerTrimStartTextBox.Text -TrimEnd $playerTrimEndTextBox.Text -DurationSeconds $runtimeState.DurationSeconds
        $playerCutRangeLabel.Text = $cutText
        $playerTimelineSummaryLabel.Text = $cutText
        $playerStartMarkerLabel.Text = if ([string]::IsNullOrWhiteSpace($playerTrimStartTextBox.Text)) { "Start: --" } else { "Start: " + $playerTrimStartTextBox.Text }
        $playerEndMarkerLabel.Text = if ([string]::IsNullOrWhiteSpace($playerTrimEndTextBox.Text)) { "End: --" } else { "End: " + $playerTrimEndTextBox.Text }
    }

    function Load-PlayerTrimFields {
        $segments = @($localState.TrimSegments)
        if ($segments.Count -gt 0 -and $playerSegmentsListBox.SelectedIndex -ge 0 -and $playerSegmentsListBox.SelectedIndex -lt $segments.Count) {
            $playerTrimStartTextBox.Text = [string]$segments[$playerSegmentsListBox.SelectedIndex].StartText
            $playerTrimEndTextBox.Text = [string]$segments[$playerSegmentsListBox.SelectedIndex].EndText
        }
        else {
            $playerTrimStartTextBox.Text = [string]$localState.TrimStartText
            $playerTrimEndTextBox.Text = [string]$localState.TrimEndText
        }

        Update-PlayerCutDisplay
    }

    function Convert-PlayerCropFieldValue {
        param(
            [string]$Text,
            [string]$FieldName
        )

        $trimmedText = [string]$Text
        if ([string]::IsNullOrWhiteSpace($trimmedText)) {
            return 0
        }

        $value = 0
        if (-not [int]::TryParse($trimmedText.Trim(), [ref]$value)) {
            throw ($FieldName + " crop mora biti ceo broj.")
        }
        if ($value -lt 0) {
            throw ($FieldName + " crop ne moze biti negativan.")
        }

        return $value
    }

    function Set-PlayerCropFieldTexts {
        param(
            [int]$Left,
            [int]$Top,
            [int]$Right,
            [int]$Bottom,
            [bool]$ClearFields = $false
        )

        $localState.CropFieldSync = $true
        try {
            $playerCropLeftTextBox.Text = if ($ClearFields) { "" } else { [string]$Left }
            $playerCropTopTextBox.Text = if ($ClearFields) { "" } else { [string]$Top }
            $playerCropRightTextBox.Text = if ($ClearFields) { "" } else { [string]$Right }
            $playerCropBottomTextBox.Text = if ($ClearFields) { "" } else { [string]$Bottom }
        }
        finally {
            $localState.CropFieldSync = $false
        }
    }

    function Update-PlayerCropStateLabel {
        switch ([string]$localState.CropMode) {
            "Auto" {
                $playerCropStateLabel.Text = "Crop: Auto"
            }
            "Manual" {
                $playerCropStateLabel.Text = "Crop: Manual"
            }
            default {
                $playerCropStateLabel.Text = "Crop: --"
            }
        }
    }

    function Update-PlayerCropSummaryFromFields {
        $cropMode = [string]$localState.CropMode
        $hasAnyText = -not (
            [string]::IsNullOrWhiteSpace($playerCropLeftTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropTopTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropRightTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropBottomTextBox.Text)
        )

        if (-not $hasAnyText) {
            $localState.CropSummary = ""
            return
        }

        if ([string]::IsNullOrWhiteSpace($cropMode) -or $cropMode -eq "None") {
            $cropMode = "Manual"
        }

        try {
            $cropSource = Get-PlanItemCropSourceDimensions -Item $Item
            $normalized = Get-VhsMp4CropState -InputObject ([pscustomobject]@{
                    Mode = $cropMode
                    Left = (Convert-PlayerCropFieldValue -Text $playerCropLeftTextBox.Text -FieldName "Left")
                    Top = (Convert-PlayerCropFieldValue -Text $playerCropTopTextBox.Text -FieldName "Top")
                    Right = (Convert-PlayerCropFieldValue -Text $playerCropRightTextBox.Text -FieldName "Right")
                    Bottom = (Convert-PlayerCropFieldValue -Text $playerCropBottomTextBox.Text -FieldName "Bottom")
                    SourceWidth = $cropSource.SourceWidth
                    SourceHeight = $cropSource.SourceHeight
                })
            $localState.CropSummary = [string]$normalized.Summary
        }
        catch {
            $localState.CropSummary = ""
        }
    }

    function Get-PlayerCropStateFromFields {
        $hasAnyText = -not (
            [string]::IsNullOrWhiteSpace($playerCropLeftTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropTopTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropRightTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropBottomTextBox.Text)
        )

        if (-not $hasAnyText) {
            return [pscustomobject]@{
                CropMode = ""
                CropLeft = 0
                CropTop = 0
                CropRight = 0
                CropBottom = 0
                CropSummary = ""
            }
        }

        $cropMode = [string]$localState.CropMode
        if ([string]::IsNullOrWhiteSpace($cropMode) -or $cropMode -eq "None") {
            $cropMode = "Manual"
        }

        $cropState = [pscustomobject]@{
            CropMode = $cropMode
            CropLeft = (Convert-PlayerCropFieldValue -Text $playerCropLeftTextBox.Text -FieldName "Left")
            CropTop = (Convert-PlayerCropFieldValue -Text $playerCropTopTextBox.Text -FieldName "Top")
            CropRight = (Convert-PlayerCropFieldValue -Text $playerCropRightTextBox.Text -FieldName "Right")
            CropBottom = (Convert-PlayerCropFieldValue -Text $playerCropBottomTextBox.Text -FieldName "Bottom")
            CropSummary = ""
        }

        $localState.CropMode = $cropState.CropMode
        $localState.CropLeft = $cropState.CropLeft
        $localState.CropTop = $cropState.CropTop
        $localState.CropRight = $cropState.CropRight
        $localState.CropBottom = $cropState.CropBottom
        Update-PlayerCropSummaryFromFields
        $cropState.CropSummary = [string]$localState.CropSummary
        return $cropState
    }

    function Load-PlayerCropFields {
        $hasCrop = -not [string]::IsNullOrWhiteSpace([string]$localState.CropMode)
        if ($hasCrop) {
            Set-PlayerCropFieldTexts -Left $localState.CropLeft -Top $localState.CropTop -Right $localState.CropRight -Bottom $localState.CropBottom
        }
        else {
            Set-PlayerCropFieldTexts -Left 0 -Top 0 -Right 0 -Bottom 0 -ClearFields:$true
        }
        Update-PlayerCropSummaryFromFields
        Update-PlayerCropStateLabel
    }

    function Set-PlayerCropTextChanged {
        if ($localState.CropFieldSync) {
            return
        }

        $hasAnyText = -not (
            [string]::IsNullOrWhiteSpace($playerCropLeftTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropTopTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropRightTextBox.Text) -and
            [string]::IsNullOrWhiteSpace($playerCropBottomTextBox.Text)
        )

        if ($hasAnyText) {
            $localState.CropMode = "Manual"
            try {
                $localState.CropLeft = Convert-PlayerCropFieldValue -Text $playerCropLeftTextBox.Text -FieldName "Left"
                $localState.CropTop = Convert-PlayerCropFieldValue -Text $playerCropTopTextBox.Text -FieldName "Top"
                $localState.CropRight = Convert-PlayerCropFieldValue -Text $playerCropRightTextBox.Text -FieldName "Right"
                $localState.CropBottom = Convert-PlayerCropFieldValue -Text $playerCropBottomTextBox.Text -FieldName "Bottom"
            }
            catch {
            }
        }
        else {
            $localState.CropMode = ""
            $localState.CropLeft = 0
            $localState.CropTop = 0
            $localState.CropRight = 0
            $localState.CropBottom = 0
        }

        Update-PlayerCropSummaryFromFields
        Update-PlayerCropStateLabel
        Sync-PlayerAspectPanel
        Set-PlayerTrimDialogDirty
    }

    function Get-PlayerDetectedCropState {
        return (Get-PlanItemDetectedCropState -Item $Item)
    }

    function Apply-DetectedCropToPlayerState {
        param(
            [bool]$AcceptAuto = $false
        )

        $detectedCrop = Get-PlayerDetectedCropState
        if ($null -eq $detectedCrop) {
            [System.Windows.Forms.MessageBox]::Show("Crop detekcija jos nije dostupna za ovaj fajl.", "Detect Crop", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $localState.CropLeft = [int]$detectedCrop.CropLeft
        $localState.CropTop = [int]$detectedCrop.CropTop
        $localState.CropRight = [int]$detectedCrop.CropRight
        $localState.CropBottom = [int]$detectedCrop.CropBottom
        $localState.CropSummary = [string]$detectedCrop.CropSummary
        if ($AcceptAuto) {
            $localState.CropMode = "Auto"
        }
        else {
            $localState.CropMode = "Manual"
        }
        Set-PlayerCropFieldTexts -Left $localState.CropLeft -Top $localState.CropTop -Right $localState.CropRight -Bottom $localState.CropBottom
        Update-PlayerCropSummaryFromFields
        Update-PlayerCropStateLabel
        Sync-PlayerAspectPanel
        Set-PlayerTrimDialogDirty
    }

    function Clear-PlayerCropFields {
        $localState.CropMode = ""
        $localState.CropLeft = 0
        $localState.CropTop = 0
        $localState.CropRight = 0
        $localState.CropBottom = 0
        $localState.CropSummary = ""
        Set-PlayerCropFieldTexts -Left 0 -Top 0 -Right 0 -Bottom 0 -ClearFields:$true
        Update-PlayerCropStateLabel
        Sync-PlayerAspectPanel
        Set-PlayerTrimDialogDirty
    }

    function Get-PlayerAspectModeFromLabel {
        param(
            [AllowNull()]
            [string]$Label
        )

        switch ([string]$Label) {
            "Auto" { return "Auto" }
            "Keep Original" { return "KeepOriginal" }
            "Force 4:3" { return "Force4x3" }
            "Force 16:9" { return "Force16x9" }
            default { return "Auto" }
        }
    }

    function Format-PlayerAspectDetectedLabel {
        param(
            [AllowNull()]
            $Snapshot,
            [AllowNull()]
            $SourceDimensions
        )

        if ($null -eq $Snapshot) {
            return ""
        }

        $baseGeometry = $null
        try {
            if ($null -ne $SourceDimensions -and $null -ne $SourceDimensions.SourceWidth -and $null -ne $SourceDimensions.SourceHeight) {
                $baseGeometry = Get-VhsMp4AspectBaseGeometry -Width ([int]$SourceDimensions.SourceWidth) -Height ([int]$SourceDimensions.SourceHeight)
            }
        }
        catch {
            $baseGeometry = $null
        }

        $modeLabel = Get-AspectModeShortLabel -AspectMode ([string]$Snapshot.OutputAspectMode)
        if ($modeLabel -eq "--") {
            $modeLabel = Get-AspectModeShortLabel -AspectMode ([string]$Snapshot.DetectedAspectMode)
        }

        if (-not [string]::IsNullOrWhiteSpace($baseGeometry) -and $modeLabel -in @("4:3", "16:9")) {
            return ($baseGeometry + " DV " + $modeLabel)
        }

        return (Get-AspectModeDisplayName -AspectMode ([string]$Snapshot.DetectedAspectMode) -Default "--")
    }

    function Sync-PlayerAspectPanel {
        if ($null -eq $playerAspectModeComboBox -or $null -eq $playerAspectDetailsLabel -or $null -eq $playerAspectGeometryLabel) {
            return
        }

        $snapshot = $null
        $sourceDimensions = $null
        try {
            $sourceDimensions = Get-PlanItemCropSourceDimensions -Item $Item
        }
        catch {
            $sourceDimensions = $null
        }

        try {
            $cropState = Get-PlayerCropStateFromFields
            if ($null -ne $sourceDimensions) {
                $cropState | Add-Member -NotePropertyName "SourceWidth" -NotePropertyValue $sourceDimensions.SourceWidth -Force
                $cropState | Add-Member -NotePropertyName "SourceHeight" -NotePropertyValue $sourceDimensions.SourceHeight -Force
            }
            $snapshot = if ($null -ne $mediaInfo) { Get-VhsMp4AspectSnapshot -InputObject $mediaInfo -AspectMode $localState.AspectMode -CropState $cropState } else { $null }
        }
        catch {
            $snapshot = $null
        }

        if ($null -eq $snapshot) {
            $localState.DetectedAspectLabel = ""
            $localState.DetectedDisplayAspectRatio = ""
            $localState.DetectedSampleAspectRatio = ""
            $localState.OutputAspectWidth = $null
            $localState.OutputAspectHeight = $null
            $playerAspectDetailsLabel.Text = "Detected: --"
            $playerAspectGeometryLabel.Text = "DAR: -- | SAR: -- | Output: -- x --"
            return
        }

        $localState.DetectedAspectLabel = Format-PlayerAspectDetectedLabel -Snapshot $snapshot -SourceDimensions $sourceDimensions
        $localState.DetectedDisplayAspectRatio = if ([string]::IsNullOrWhiteSpace([string]$snapshot.DetectedDisplayAspectRatio)) { "--" } else { [string]$snapshot.DetectedDisplayAspectRatio }
        $localState.DetectedSampleAspectRatio = if ([string]::IsNullOrWhiteSpace([string]$snapshot.DetectedSampleAspectRatio)) { "--" } else { [string]$snapshot.DetectedSampleAspectRatio }
        $localState.OutputAspectWidth = $snapshot.OutputAspectWidth
        $localState.OutputAspectHeight = $snapshot.OutputAspectHeight

        $outputText = "-- x --"
        if ($null -ne $snapshot.OutputAspectWidth -and $null -ne $snapshot.OutputAspectHeight) {
            $outputText = ([string]$snapshot.OutputAspectWidth + "x" + [string]$snapshot.OutputAspectHeight)
        }

        $detectedLabel = if ([string]::IsNullOrWhiteSpace([string]$localState.DetectedAspectLabel)) { "--" } else { [string]$localState.DetectedAspectLabel }
        $playerAspectDetailsLabel.Text = ("Detected: " + $detectedLabel + " -> " + $outputText)
        $playerAspectGeometryLabel.Text = ("DAR: " + $localState.DetectedDisplayAspectRatio + " | SAR: " + $localState.DetectedSampleAspectRatio + " | Output: " + $outputText.Replace("x", " x "))
    }

    function Set-PlayerPositionSeconds {
        param(
            [double]$Seconds,
            [bool]$SyncPlayer = $false,
            [bool]$RequestPreview = $false
        )

        $position = [Math]::Max(0.0, $Seconds)
        if ($runtimeState.DurationSeconds -gt 0) {
            $position = [Math]::Min($runtimeState.DurationSeconds, $position)
        }

        $localState.PreviewPositionSeconds = $position
        $positionText = Format-VhsMp4FfmpegTime -Seconds $position
        if ([string]::IsNullOrWhiteSpace($positionText)) {
            $positionText = "00:00:00"
        }

        $totalText = if ($runtimeState.DurationSeconds -gt 0) { Format-VhsMp4FfmpegTime -Seconds $runtimeState.DurationSeconds } else { "--:--:--" }
        $playerPositionLabel.Text = $positionText + " / " + $totalText
        $playerPreviewTimeTextBox.Text = $positionText

        $timelineValue = [Math]::Min($playerTimelineTrackBar.Maximum, [Math]::Max($playerTimelineTrackBar.Minimum, [int][Math]::Round($position * $previewTimelineScale, 0, [System.MidpointRounding]::AwayFromZero)))
        if ($playerTimelineTrackBar.Value -ne $timelineValue) {
            $playerTimelineTrackBar.Value = $timelineValue
        }

        if ($SyncPlayer -and $localState.Mode -eq "Playback mode" -and $runtimeState.PlaybackReady) {
            try {
                $mediaElement.Position = [TimeSpan]::FromSeconds($position)
            }
            catch {
            }
        }

        if ($RequestPreview -and $localState.Mode -eq "Preview mode" -and -not [string]::IsNullOrWhiteSpace($resolvedFfmpegPath)) {
            $previewPath = Get-PreviewFramePath -Item $Item
            try {
                $result = New-VhsMp4PreviewFrame -SourcePath $Item.SourcePath -OutputPath $previewPath -FfmpegPath $resolvedFfmpegPath -PreviewTime $positionText
                if ($result.Success) {
                    $bytes = [System.IO.File]::ReadAllBytes($previewPath)
                    $stream = New-Object System.IO.MemoryStream(,$bytes)
                    try {
                        $image = [System.Drawing.Image]::FromStream($stream)
                        try {
                            if ($null -ne $playerPreviewPictureBox.Image) {
                                $playerPreviewPictureBox.Image.Dispose()
                            }
                            $playerPreviewPictureBox.Image = New-Object System.Drawing.Bitmap($image)
                        }
                        finally {
                            $image.Dispose()
                        }
                    }
                    finally {
                        $stream.Dispose()
                    }
                }
            }
            catch {
            }
        }
    }

    function Move-PlayerFrame {
        param([int]$Direction)
        Set-PlayerPositionSeconds -Seconds ($localState.PreviewPositionSeconds + ($Direction * (1.0 / $runtimeState.FrameRate))) -SyncPlayer:($localState.Mode -eq "Playback mode") -RequestPreview:($localState.Mode -eq "Preview mode")
    }

    function Set-PlayerTrimPoint {
        param([ValidateSet("Start", "End")][string]$Point)

        $positionText = Format-VhsMp4FfmpegTime -Seconds $localState.PreviewPositionSeconds
        if ([string]::IsNullOrWhiteSpace($positionText)) {
            $positionText = "00:00:00"
        }

        if ($Point -eq "Start") {
            $playerTrimStartTextBox.Text = $positionText
        }
        else {
            $playerTrimEndTextBox.Text = $positionText
        }

        Set-PlayerTrimDialogDirty
        Update-PlayerCutDisplay
    }

    function Apply-PlayerTrimFields {
        try {
            $segments = @($localState.TrimSegments)
            if ($segments.Count -gt 0 -and $playerSegmentsListBox.SelectedIndex -ge 0 -and $playerSegmentsListBox.SelectedIndex -lt $segments.Count) {
                $segmentWindow = Get-VhsMp4TrimWindow -TrimStart $playerTrimStartTextBox.Text -TrimEnd $playerTrimEndTextBox.Text
                if ([string]::IsNullOrWhiteSpace([string]$segmentWindow.Summary)) {
                    throw "Za update segmenta unesi i Start i End."
                }

                $segments[$playerSegmentsListBox.SelectedIndex] = [pscustomobject]@{
                    StartText = [string]$segmentWindow.StartText
                    EndText = [string]$segmentWindow.EndText
                }
                $normalized = Get-VhsMp4TrimSegments -TrimSegments $segments
                $localState.TrimSegments = @($normalized.Segments)
                $localState.TrimStartText = ""
                $localState.TrimEndText = ""
                $localState.TrimSummary = [string]$normalized.Summary
                $localState.TrimDurationSeconds = [double]$normalized.TotalDurationSeconds
                Sync-PlayerSegmentsList
                Load-PlayerTrimFields
                Set-PlayerTrimDialogDirty
                return
            }

            $window = Get-VhsMp4TrimWindow -TrimStart $playerTrimStartTextBox.Text -TrimEnd $playerTrimEndTextBox.Text
            if ([string]::IsNullOrWhiteSpace([string]$window.Summary)) {
                $localState.TrimStartText = ""
                $localState.TrimEndText = ""
                $localState.TrimSummary = ""
                $localState.TrimDurationSeconds = $null
            }
            else {
                $localState.TrimStartText = [string]$window.StartText
                $localState.TrimEndText = [string]$window.EndText
                $localState.TrimSummary = [string]$window.Summary
                $localState.TrimDurationSeconds = [double]$window.DurationSeconds
            }
            $localState.TrimSegments = @()
            Sync-PlayerSegmentsList
            Update-PlayerCutDisplay
            Set-PlayerTrimDialogDirty
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Apply Trim", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }

    function Add-PlayerTrimSegmentFromFields {
        try {
            $window = Get-VhsMp4TrimWindow -TrimStart $playerTrimStartTextBox.Text -TrimEnd $playerTrimEndTextBox.Text
            if ([string]::IsNullOrWhiteSpace([string]$window.Summary) -or [string]::IsNullOrWhiteSpace([string]$window.StartText) -or [string]::IsNullOrWhiteSpace([string]$window.EndText)) {
                throw "Za Add Segment unesi i Start i End."
            }

            $segments = New-Object System.Collections.Generic.List[object]
            foreach ($segment in @($localState.TrimSegments)) {
                $segments.Add([pscustomobject]@{
                    StartText = [string]$segment.StartText
                    EndText = [string]$segment.EndText
                })
            }
            $segments.Add([pscustomobject]@{
                StartText = [string]$window.StartText
                EndText = [string]$window.EndText
            })

            $normalized = Get-VhsMp4TrimSegments -TrimSegments $segments
            $localState.TrimSegments = @($normalized.Segments)
            $localState.TrimStartText = ""
            $localState.TrimEndText = ""
            $localState.TrimSummary = [string]$normalized.Summary
            $localState.TrimDurationSeconds = [double]$normalized.TotalDurationSeconds
            Sync-PlayerSegmentsList
            $playerSegmentsListBox.SelectedIndex = [Math]::Max(0, $normalized.Count - 1)
            Load-PlayerTrimFields
            Set-PlayerTrimDialogDirty
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Add Segment", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }

    function Remove-PlayerTrimSegment {
        $segments = @($localState.TrimSegments)
        $selectedIndex = $playerSegmentsListBox.SelectedIndex
        if ($selectedIndex -lt 0 -or $selectedIndex -ge $segments.Count) {
            return
        }

        $remaining = New-Object System.Collections.Generic.List[object]
        for ($index = 0; $index -lt $segments.Count; $index++) {
            if ($index -ne $selectedIndex) {
                $remaining.Add($segments[$index])
            }
        }

        if ($remaining.Count -gt 0) {
            $normalized = Get-VhsMp4TrimSegments -TrimSegments $remaining
            $localState.TrimSegments = @($normalized.Segments)
            $localState.TrimSummary = [string]$normalized.Summary
            $localState.TrimDurationSeconds = [double]$normalized.TotalDurationSeconds
        }
        else {
            $localState.TrimSegments = @()
            $localState.TrimSummary = ""
            $localState.TrimDurationSeconds = $null
        }

        Sync-PlayerSegmentsList
        Load-PlayerTrimFields
        Set-PlayerTrimDialogDirty
    }

    function Clear-PlayerTrimSegments {
        $localState.TrimSegments = @()
        $localState.TrimSummary = ""
        $localState.TrimDurationSeconds = $null
        Sync-PlayerSegmentsList
        Update-PlayerCutDisplay
        Set-PlayerTrimDialogDirty
    }

    function Clear-PlayerTrimFields {
        $localState.TrimSegments = @()
        $localState.TrimStartText = ""
        $localState.TrimEndText = ""
        $localState.TrimSummary = ""
        $localState.TrimDurationSeconds = $null
        $playerTrimStartTextBox.Text = ""
        $playerTrimEndTextBox.Text = ""
        Sync-PlayerSegmentsList
        Update-PlayerCutDisplay
        Set-PlayerTrimDialogDirty
    }

    function Save-PlayerTrimChanges {
        param(
            [switch]$CloseAfterSave
        )

        try {
            if (@($localState.TrimSegments).Count -eq 0) {
                $window = Get-VhsMp4TrimWindow -TrimStart $playerTrimStartTextBox.Text -TrimEnd $playerTrimEndTextBox.Text
                $localState.TrimStartText = [string]$window.StartText
                $localState.TrimEndText = [string]$window.EndText
                $localState.TrimSummary = [string]$window.Summary
                $localState.TrimDurationSeconds = $window.DurationSeconds
            }

            $runtimeState.DialogResult = [pscustomobject]@{
                Saved = $true
                Mode = [string]$localState.Mode
                AspectState = [pscustomobject]@{
                    AspectMode = [string](Get-VhsMp4NormalizedAspectMode -AspectMode $localState.AspectMode)
                    DetectedAspectLabel = [string]$localState.DetectedAspectLabel
                    DetectedDisplayAspectRatio = [string]$localState.DetectedDisplayAspectRatio
                    DetectedSampleAspectRatio = [string]$localState.DetectedSampleAspectRatio
                    OutputAspectWidth = $localState.OutputAspectWidth
                    OutputAspectHeight = $localState.OutputAspectHeight
                }
                TrimState = [pscustomobject]@{
                    TrimStartText = [string]$localState.TrimStartText
                    TrimEndText = [string]$localState.TrimEndText
                    TrimSummary = [string]$localState.TrimSummary
                    TrimDurationSeconds = $localState.TrimDurationSeconds
                    TrimSegments = @($localState.TrimSegments)
                    PreviewPositionSeconds = [double]$localState.PreviewPositionSeconds
                }
                CropState = (Get-PlayerCropStateFromFields)
            }
            Set-PlayerTrimDialogDirty -Value $false
            if ($Modeless) {
                if ($null -ne $OnSave) {
                    & $OnSave $Item $runtimeState.DialogResult
                }
                if ($CloseAfterSave) {
                    $runtimeState.ClosingAfterSave = $true
                    $dialog.Close()
                }
                return
            }

            $runtimeState.ClosingAfterSave = $true
            $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $dialog.Close()
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Save to Queue", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }
        Export-ModuleMember -Function *
    }

    function Set-PlayerTrimDialogDirty {
        param([bool]$Value = $true)
        $playerRuntime.'Set-PlayerTrimDialogDirty'($Value)
    }

    function Set-PlayerTrimDialogMode {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Mode,
            [string]$Reason = ""
        )
        $playerRuntime.'Set-PlayerTrimDialogMode'($Mode, $Reason)
    }

    function Sync-PlayerSegmentsList {
        $playerRuntime.'Sync-PlayerSegmentsList'()
    }

    function Update-PlayerCutDisplay {
        $playerRuntime.'Update-PlayerCutDisplay'()
    }

    function Load-PlayerTrimFields {
        $playerRuntime.'Load-PlayerTrimFields'()
    }

    function Get-PlayerCropStateFromFields {
        $playerRuntime.'Get-PlayerCropStateFromFields'()
    }

    function Load-PlayerCropFields {
        $playerRuntime.'Load-PlayerCropFields'()
    }

    function Set-PlayerCropTextChanged {
        $playerRuntime.'Set-PlayerCropTextChanged'()
    }

    function Apply-DetectedCropToPlayerState {
        param(
            [bool]$AcceptAuto = $false
        )
        $playerRuntime.'Apply-DetectedCropToPlayerState'($AcceptAuto)
    }

    function Clear-PlayerCropFields {
        $playerRuntime.'Clear-PlayerCropFields'()
    }

    function Get-PlayerAspectModeFromLabel {
        param(
            [AllowNull()]
            [string]$Label
        )
        $playerRuntime.'Get-PlayerAspectModeFromLabel'($Label)
    }

    function Sync-PlayerAspectPanel {
        $playerRuntime.'Sync-PlayerAspectPanel'()
    }

    function Set-PlayerPositionSeconds {
        param(
            [double]$Seconds,
            [bool]$SyncPlayer = $false,
            [bool]$RequestPreview = $false
        )
        $playerRuntime.'Set-PlayerPositionSeconds'($Seconds, $SyncPlayer, $RequestPreview)
    }

    function Move-PlayerFrame {
        param([int]$Direction)
        $playerRuntime.'Move-PlayerFrame'($Direction)
    }

    function Set-PlayerTrimPoint {
        param([ValidateSet("Start", "End")][string]$Point)
        $playerRuntime.'Set-PlayerTrimPoint'($Point)
    }

    function Apply-PlayerTrimFields {
        $playerRuntime.'Apply-PlayerTrimFields'()
    }

    function Add-PlayerTrimSegmentFromFields {
        $playerRuntime.'Add-PlayerTrimSegmentFromFields'()
    }

    function Remove-PlayerTrimSegment {
        $playerRuntime.'Remove-PlayerTrimSegment'()
    }

    function Clear-PlayerTrimSegments {
        $playerRuntime.'Clear-PlayerTrimSegments'()
    }

    function Clear-PlayerTrimFields {
        $playerRuntime.'Clear-PlayerTrimFields'()
    }

    function Save-PlayerTrimChanges {
        param(
            [switch]$CloseAfterSave
        )
        $playerRuntime.'Save-PlayerTrimChanges'([bool]$CloseAfterSave)
    }

    $mediaElement.Add_MediaOpened(({
        $runtimeState.PlaybackReady = $true
        if ($mediaElement.NaturalDuration.HasTimeSpan) {
            $seconds = $mediaElement.NaturalDuration.TimeSpan.TotalSeconds
            if ($seconds -gt 0) {
                $runtimeState.DurationSeconds = $seconds
                $playerTimelineTrackBar.Maximum = [Math]::Max(1, [int][Math]::Round($runtimeState.DurationSeconds * $script:PreviewTimelineScale, 0, [System.MidpointRounding]::AwayFromZero))
            }
        }
        $playerRuntime.'Set-PlayerPositionSeconds'($localState.PreviewPositionSeconds, $false, $false)
    }).GetNewClosure())

    $mediaElement.Add_MediaEnded(({
        try {
            $mediaElement.Pause()
        }
        catch {
        }
        $playerRuntime.'Set-PlayerPositionSeconds'(0, $false, $false)
    }).GetNewClosure())

    $mediaElement.Add_MediaFailed(({
        param($sender, $eventArgs)
        $playerRuntime.'Set-PlayerTrimDialogMode'("Preview mode", "fallback")
        $playerRuntime.'Set-PlayerPositionSeconds'($localState.PreviewPositionSeconds, $false, $true)
    }).GetNewClosure())

    $playbackTimer.Add_Tick(({
        if ($localState.Mode -ne "Playback mode" -or -not $runtimeState.PlaybackReady) {
            return
        }

        try {
            $playerRuntime.'Set-PlayerPositionSeconds'($mediaElement.Position.TotalSeconds, $false, $false)
        }
        catch {
        }
    }).GetNewClosure())

    $applyPlayerTrimButton.Add_Click(({
        $playerRuntime.'Apply-PlayerTrimFields'()
    }).GetNewClosure())

    $setPlayerTrimStartButton.Add_Click(({
        $playerRuntime.'Set-PlayerTrimPoint'("Start")
    }).GetNewClosure())

    $setPlayerTrimEndButton.Add_Click(({
        $playerRuntime.'Set-PlayerTrimPoint'("End")
    }).GetNewClosure())

    $addPlayerSegmentButton.Add_Click(({
        $playerRuntime.'Add-PlayerTrimSegmentFromFields'()
    }).GetNewClosure())

    $removePlayerSegmentButton.Add_Click(({
        $playerRuntime.'Remove-PlayerTrimSegment'()
    }).GetNewClosure())

    $clearPlayerSegmentsButton.Add_Click(({
        $playerRuntime.'Clear-PlayerTrimSegments'()
    }).GetNewClosure())

    $clearPlayerTrimButton.Add_Click(({
        $playerRuntime.'Clear-PlayerTrimFields'()
    }).GetNewClosure())

    $playerSegmentsListBox.Add_SelectedIndexChanged(({
        $playerRuntime.'Load-PlayerTrimFields'()
    }).GetNewClosure())

    $playerTrimStartTextBox.Add_TextChanged(({
        $playerRuntime.'Update-PlayerCutDisplay'()
    }).GetNewClosure())

    $playerTrimEndTextBox.Add_TextChanged(({
        $playerRuntime.'Update-PlayerCutDisplay'()
    }).GetNewClosure())

    $playerCropLeftTextBox.Add_TextChanged(({
        $playerRuntime.'Set-PlayerCropTextChanged'()
    }).GetNewClosure())

    $playerCropTopTextBox.Add_TextChanged(({
        $playerRuntime.'Set-PlayerCropTextChanged'()
    }).GetNewClosure())

    $playerCropRightTextBox.Add_TextChanged(({
        $playerRuntime.'Set-PlayerCropTextChanged'()
    }).GetNewClosure())

    $playerCropBottomTextBox.Add_TextChanged(({
        $playerRuntime.'Set-PlayerCropTextChanged'()
    }).GetNewClosure())

    $playerAspectModeComboBox.Add_SelectedIndexChanged(({
        if ($localState.AspectModeControlSync) {
            return
        }

        $localState.AspectMode = $playerRuntime.'Get-PlayerAspectModeFromLabel'([string]$playerAspectModeComboBox.SelectedItem)
        $playerRuntime.'Sync-PlayerAspectPanel'()
        $playerRuntime.'Set-PlayerTrimDialogDirty'()
    }).GetNewClosure())

    $playerTimelineTrackBar.Add_Scroll(({
        $requestPreview = $localState.Mode -eq "Preview mode"
        $playerRuntime.'Set-PlayerPositionSeconds'(([double]$playerTimelineTrackBar.Value / $script:PreviewTimelineScale), ($localState.Mode -eq "Playback mode"), $requestPreview)
    }).GetNewClosure())

    $playerPreviewTimeTextBox.Add_Leave(({
        $seconds = $localState.PreviewPositionSeconds
        try {
            $parsed = Convert-VhsMp4TimeTextToSeconds -Value $playerPreviewTimeTextBox.Text
            if ($null -ne $parsed) {
                $seconds = [double]$parsed
            }
        }
        catch {
            $seconds = $localState.PreviewPositionSeconds
        }

        $playerRuntime.'Set-PlayerPositionSeconds'($seconds, ($localState.Mode -eq "Playback mode"), ($localState.Mode -eq "Preview mode"))
    }).GetNewClosure())

    $playPauseButton.Add_Click(({
        $playerRuntime.'Start-PlayerPlayback'()
    }).GetNewClosure())

    $stopPlaybackButton.Add_Click(({
        if ($localState.Mode -eq "Playback mode") {
            $playerRuntime.'Stop-PlayerPlayback'()
        }
        $playerRuntime.'Set-PlayerPositionSeconds'(0, $false, ($localState.Mode -eq "Preview mode"))
    }).GetNewClosure())

    $previousPlayerFrameButton.Add_Click(({
        $playerRuntime.'Move-PlayerFrame'(-1)
    }).GetNewClosure())

    $nextPlayerFrameButton.Add_Click(({
        $playerRuntime.'Move-PlayerFrame'(1)
    }).GetNewClosure())

    $playerPreviewFrameButton.Add_Click(({
        $playerRuntime.'Set-PlayerPositionSeconds'($localState.PreviewPositionSeconds, $false, $true)
    }).GetNewClosure())

    $playerOpenVideoButton.Add_Click(({
        try {
            Start-Process -FilePath $Item.SourcePath
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Open Video", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    }).GetNewClosure())

    $detectCropButton.Add_Click(({
        $playerRuntime.'Apply-DetectedCropToPlayerState'($false)
    }).GetNewClosure())

    $autoCropButton.Add_Click(({
        $playerRuntime.'Apply-DetectedCropToPlayerState'($true)
    }).GetNewClosure())

    $clearCropButton.Add_Click(({
        $playerRuntime.'Clear-PlayerCropFields'()
    }).GetNewClosure())

    $saveToQueueButton.Add_Click(({
        $playerRuntime.'Save-PlayerTrimChanges'($false)
    }).GetNewClosure())

    $cancelPlayerButton.Add_Click(({
        $dialog.Close()
    }).GetNewClosure())

    $dialog.Add_KeyDown(({
        param($sender, $eventArgs)

        if ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Left) {
            $playerRuntime.'Move-PlayerFrame'(-1)
            $eventArgs.SuppressKeyPress = $true
            $eventArgs.Handled = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::Right) {
            $playerRuntime.'Move-PlayerFrame'(1)
            $eventArgs.SuppressKeyPress = $true
            $eventArgs.Handled = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::I) {
            $playerRuntime.'Set-PlayerTrimPoint'("Start")
            $eventArgs.SuppressKeyPress = $true
            $eventArgs.Handled = $true
        }
        elseif ($eventArgs.KeyCode -eq [System.Windows.Forms.Keys]::O) {
            $playerRuntime.'Set-PlayerTrimPoint'("End")
            $eventArgs.SuppressKeyPress = $true
            $eventArgs.Handled = $true
        }
    }).GetNewClosure())

    $dialog.Add_FormClosing(({
        param($sender, $eventArgs)

        $playerRuntime.'Stop-PlayerPlayback'()

        if ($runtimeState.ClosingAfterSave -or -not $localState.Dirty) {
            return
        }

        $response = [System.Windows.Forms.MessageBox]::Show(
            "Imas nesacuvane izmene. Yes = Save, No = Discard, Cancel = ostani u Player / Trim prozoru.",
            "Player / Trim",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            $eventArgs.Cancel = $true
            $playerRuntime.'Save-PlayerTrimChanges'($true)
            return
        }

        if ($response -eq [System.Windows.Forms.DialogResult]::Cancel) {
            $eventArgs.Cancel = $true
        }
    }).GetNewClosure())

    $playerRuntime.'Set-PlayerTrimDialogMode'($localState.Mode)
    $playerRuntime.'Sync-PlayerSegmentsList'()
    $playerRuntime.'Load-PlayerTrimFields'()
    $playerRuntime.'Load-PlayerCropFields'()
    $localState.AspectModeControlSync = $true
    try {
        $playerAspectModeComboBox.SelectedItem = Get-AspectModeDisplayName -AspectMode $localState.AspectMode
    }
    finally {
        $localState.AspectModeControlSync = $false
    }
    $playerRuntime.'Sync-PlayerAspectPanel'()
    $playerRuntime.'Set-PlayerPositionSeconds'($localState.PreviewPositionSeconds, $false, $false)

    if ($localState.Mode -eq "Playback mode") {
        try {
            $mediaElement.Source = New-Object System.Uri ([System.IO.Path]::GetFullPath([string]$Item.SourcePath))
        }
        catch {
            $playerRuntime.'Set-PlayerTrimDialogMode'("Preview mode", "fallback")
        }
    }

    $dialog.Add_Shown(({
        if ($localState.Mode -eq "Preview mode" -and -not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
            $playerRuntime.'Set-PlayerPositionSeconds'($localState.PreviewPositionSeconds, $false, $true)
        }
    }).GetNewClosure())

    $dialog.Add_Move(({
        if ($dialog.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
            $script:PlayerTrimEditorBounds = $dialog.Bounds
        }
    }).GetNewClosure())

    $dialog.Add_ResizeEnd(({
        if ($dialog.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
            $script:PlayerTrimEditorBounds = $dialog.Bounds
        }
    }).GetNewClosure())

    $dialog.Add_FormClosed(({
        if ($dialog.WindowState -eq [System.Windows.Forms.FormWindowState]::Normal) {
            $script:PlayerTrimEditorBounds = $dialog.Bounds
        }
        if ($script:PlayerTrimEditorWindow -eq $dialog) {
            $script:PlayerTrimEditorWindow = $null
            $script:PlayerTrimEditorSourcePath = ""
        }
    }).GetNewClosure())

    if ($Modeless) {
        return $dialog
    }

    if ($null -ne $form) {
        [void]$dialog.ShowDialog($form)
    }
    else {
        [void]$dialog.ShowDialog()
    }

    return $runtimeState.DialogResult
}

function Show-SelectedPlayerTrimWindow {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    $result = Open-PlayerTrimWindow -Item $item
    if ($null -eq $result -or -not $result.Saved) {
        return
    }

    Apply-PlayerTrimWindowResult -Item $item -Result $result
}

function Apply-PlayerTrimWindowResult {
    param(
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        $Result
    )

    if ($Result.PSObject.Properties["AspectState"] -and $null -ne $Result.AspectState -and $Result.AspectState.PSObject.Properties["AspectMode"]) {
        $normalizedAspectMode = Get-VhsMp4NormalizedAspectMode -AspectMode ([string]$Result.AspectState.AspectMode)
        $Item | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue $normalizedAspectMode -Force
        Update-PlanItemAspectPresentation -Item $Item
    }
    Apply-PlayerTrimStateToItem -Item $Item -TrimState $Result.TrimState
    if ($Result.PSObject.Properties["CropState"]) {
        Apply-PlayerCropStateToItem -Item $Item -CropState $Result.CropState
    }
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    $trimSummary = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default "--"
    $cropSummary = Get-PlanItemPropertyText -Item $Item -Name "CropSummary" -Default "--"
    Add-LogLine ("Player / Trim saved: " + $Item.SourceName + " | Trim " + $trimSummary + " | Crop " + $cropSummary)
    Set-StatusText ("Player / Trim sacuvan za: " + $Item.SourceName)
}

function Open-SelectedPlayerTrimEditor {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    $itemSourcePath = [System.IO.Path]::GetFullPath([string]$item.SourcePath)
    $existingWindow = $script:PlayerTrimEditorWindow
    if ($null -ne $existingWindow -and -not $existingWindow.IsDisposed) {
        if ([string]$script:PlayerTrimEditorSourcePath -eq $itemSourcePath) {
            try {
                if ($existingWindow.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
                    $existingWindow.WindowState = [System.Windows.Forms.FormWindowState]::Normal
                }
                $existingWindow.Activate()
                $existingWindow.Focus()
            }
            catch {
            }
            return
        }

        try {
            $existingWindow.Close()
        }
        catch {
        }

        if ($null -ne $script:PlayerTrimEditorWindow -and -not $script:PlayerTrimEditorWindow.IsDisposed) {
            return
        }
    }

    $editorWindow = @(Open-PlayerTrimWindow -Item $item -Modeless -OwnerForm $form -OnSave {
        param($savedItem, $saveResult)
        Apply-PlayerTrimWindowResult -Item $savedItem -Result $saveResult
    }) | Where-Object { $null -ne $_ -and $_ -is [System.Windows.Forms.Form] } | Select-Object -Last 1

    if ($null -eq $editorWindow) {
        return
    }

    $script:PlayerTrimEditorWindow = $editorWindow
    $script:PlayerTrimEditorSourcePath = $itemSourcePath
    if ($null -ne $form) {
        $editorWindow.Show($form)
    }
    else {
        $editorWindow.Show()
    }
    $editorWindow.Activate()
}

function Update-SelectedTrimGridRow {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $rangeText = Get-PlanItemPropertyText -Item $Item -Name "TrimSummary" -Default "--"
    $aspectText = Get-PlanItemAspectStatusText -Item $Item
    $cropText = Get-PlanItemCropStatusText -Item $Item
    foreach ($row in $grid.Rows) {
        if ([string]$row.Cells["SourceName"].Value -eq [string]$Item.SourceName) {
            $row.Cells["Range"].Value = $rangeText
            $row.Cells["Aspect"].Value = $aspectText
            $row.Cells["Crop"].Value = $cropText
            $plannedContainer = Get-PlanItemPropertyText -Item $Item -Name "PlannedContainer" -Default ""
            $plannedResolution = Get-PlanItemPropertyText -Item $Item -Name "PlannedResolution" -Default ""
            $plannedDuration = Get-PlanItemPropertyText -Item $Item -Name "PlannedDurationText" -Default ""
            $plannedVideo = Get-PlanItemPropertyText -Item $Item -Name "PlannedVideoSummary" -Default ""
            $plannedAudio = Get-PlanItemPropertyText -Item $Item -Name "PlannedAudioSummary" -Default ""
            $plannedBitrate = Get-PlanItemPropertyText -Item $Item -Name "PlannedBitrateText" -Default ""
            if (-not [string]::IsNullOrWhiteSpace($plannedContainer)) { $row.Cells["Container"].Value = $plannedContainer }
            if (-not [string]::IsNullOrWhiteSpace($plannedResolution)) { $row.Cells["Resolution"].Value = $plannedResolution }
            if (-not [string]::IsNullOrWhiteSpace($plannedDuration)) { $row.Cells["Duration"].Value = $plannedDuration }
            if (-not [string]::IsNullOrWhiteSpace($plannedVideo)) { $row.Cells["Video"].Value = $plannedVideo }
            if (-not [string]::IsNullOrWhiteSpace($plannedAudio)) { $row.Cells["Audio"].Value = $plannedAudio }
            if (-not [string]::IsNullOrWhiteSpace($plannedBitrate)) { $row.Cells["Bitrate"].Value = $plannedBitrate }
            break
        }
    }
}

function Update-PlanItemOutputPresentation {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $outputPlan = Get-PlanItemOutputPlanState -Item $Item
    $Item | Add-Member -NotePropertyName "PlannedContainer" -NotePropertyValue ([string]$outputPlan.Container) -Force
    $Item | Add-Member -NotePropertyName "PlannedResolution" -NotePropertyValue ([string]$outputPlan.Resolution) -Force
    $Item | Add-Member -NotePropertyName "PlannedDurationText" -NotePropertyValue ([string]$outputPlan.DurationText) -Force
    $Item | Add-Member -NotePropertyName "PlannedVideoSummary" -NotePropertyValue ([string]$outputPlan.VideoSummary) -Force
    $Item | Add-Member -NotePropertyName "PlannedAudioSummary" -NotePropertyValue ([string]$outputPlan.AudioSummary) -Force
    $Item | Add-Member -NotePropertyName "PlannedBitrateText" -NotePropertyValue ([string]$outputPlan.BitrateText) -Force
    $Item | Add-Member -NotePropertyName "PlannedOutputDetails" -NotePropertyValue ([string]$outputPlan.Details) -Force
}

function Update-PlanItemTrimEstimate {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    try {
        $mediaInfoProperty = $Item.PSObject.Properties["MediaInfo"]
        if (-not $mediaInfoProperty -or $null -eq $mediaInfoProperty.Value) {
            $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
            return
        }

        $duration = $mediaInfoProperty.Value.DurationSeconds
        $trimDurationProperty = $Item.PSObject.Properties["TrimDurationSeconds"]
        if ($trimDurationProperty -and $null -ne $trimDurationProperty.Value -and [double]$trimDurationProperty.Value -gt 0) {
            $duration = [double]$trimDurationProperty.Value
        }

        if ($null -eq $duration -or $duration -le 0) {
            $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
            return
        }

        $maxPartGbForEstimate = 3.8
        if (-not [string]::IsNullOrWhiteSpace($maxPartGbTextBox.Text)) {
            $maxPartGbForEstimate = [double]::Parse($maxPartGbTextBox.Text.Trim().Replace(",", "."), [System.Globalization.CultureInfo]::InvariantCulture)
        }

        $estimate = Get-VhsMp4EstimatedOutputInfo `
            -DurationSeconds $duration `
            -QualityMode (Get-CurrentInternalQualityModeName) `
            -Crf ([int]$crfTextBox.Text) `
            -AudioBitrate $audioTextBox.Text `
            -VideoBitrate (Get-CurrentVideoBitrateText) `
            -SplitOutput:$splitOutputCheckBox.Checked `
            -MaxPartGb $maxPartGbForEstimate

        $estimatedSize = "Estimate: " + (Format-VhsMp4Gigabytes -Gigabytes $estimate.EstimatedGb)
        if ($splitOutputCheckBox.Checked) {
            $estimatedSize += " / " + $estimate.PartCount + " delova"
        }

        $Item | Add-Member -NotePropertyName "EstimatedSize" -NotePropertyValue $estimatedSize -Force
        $Item | Add-Member -NotePropertyName "UsbNote" -NotePropertyValue $estimate.UsbNote -Force
        Update-PlanItemOutputPresentation -Item $Item
        $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force

        foreach ($row in $grid.Rows) {
            if ([string]$row.Cells["SourceName"].Value -eq [string]$Item.SourceName) {
                $row.Cells["EstimatedSize"].Value = $estimatedSize
                $row.Cells["UsbNote"].Value = $estimate.UsbNote
                $row.Cells["Container"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedContainer" -Default $row.Cells["Container"].Value
                $row.Cells["Resolution"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedResolution" -Default $row.Cells["Resolution"].Value
                $row.Cells["Duration"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedDurationText" -Default $row.Cells["Duration"].Value
                $row.Cells["Video"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedVideoSummary" -Default $row.Cells["Video"].Value
                $row.Cells["Audio"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedAudioSummary" -Default $row.Cells["Audio"].Value
                $row.Cells["Bitrate"].Value = Get-PlanItemPropertyText -Item $Item -Name "PlannedBitrateText" -Default $row.Cells["Bitrate"].Value
                break
            }
        }
        Update-OutputPlanPanel
    }
    catch {
        Add-LogLine ("Estimate warning: " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        Update-PlanItemOutputPresentation -Item $Item
        $Item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $Item) -Force
    }
}

function Apply-SelectedTrim {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    try {
        $segments = @(Get-SelectedTrimSegments)
        $selectedSegmentIndex = Get-SelectedTrimSegmentIndex
        if ($segments.Count -gt 0 -and $selectedSegmentIndex -ge 0 -and $selectedSegmentIndex -lt $segments.Count) {
            $segmentWindow = Get-VhsMp4TrimWindow -TrimStart $trimStartTextBox.Text -TrimEnd $trimEndTextBox.Text
            if ([string]::IsNullOrWhiteSpace($segmentWindow.Summary) -or [string]::IsNullOrWhiteSpace($segmentWindow.StartText) -or [string]::IsNullOrWhiteSpace($segmentWindow.EndText)) {
                throw "Za update segmenta unesi i Start i End."
            }

            $segments[$selectedSegmentIndex] = [pscustomobject]@{
                StartText = $segmentWindow.StartText
                EndText = $segmentWindow.EndText
            }
            Save-SelectedTrimSegments -Segments $segments -PreferredIndex $selectedSegmentIndex -LogAction "Update Segment"
            return
        }

        $window = Get-VhsMp4TrimWindow -TrimStart $trimStartTextBox.Text -TrimEnd $trimEndTextBox.Text
        if ([string]::IsNullOrWhiteSpace($window.Summary)) {
            Clear-SelectedTrim
            return
        }

        if ($item.PSObject.Properties["TrimSegments"]) {
            $item.PSObject.Properties.Remove("TrimSegments")
        }
        $item | Add-Member -NotePropertyName "TrimStartText" -NotePropertyValue $window.StartText -Force
        $item | Add-Member -NotePropertyName "TrimEndText" -NotePropertyValue $window.EndText -Force
        $item | Add-Member -NotePropertyName "TrimStartSeconds" -NotePropertyValue $window.StartSeconds -Force
        $item | Add-Member -NotePropertyName "TrimEndSeconds" -NotePropertyValue $window.EndSeconds -Force
        $item | Add-Member -NotePropertyName "TrimDurationSeconds" -NotePropertyValue $window.DurationSeconds -Force
        $item | Add-Member -NotePropertyName "TrimSummary" -NotePropertyValue $window.Summary -Force
        Update-PlanItemTrimEstimate -Item $item
        Update-SelectedTrimGridRow -Item $item
        Update-MediaInfoPanel
        Update-PreviewTrimPanel
        Add-LogLine ("Apply Trim: " + $item.SourceName + " | " + $window.Summary)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Apply Trim", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
}

function Clear-SelectedTrim {
    $item = Get-SelectedPlanItem
    if (-not (Test-CanEditPlanItem -Item $item)) {
        return
    }

    foreach ($name in @("TrimSegments", "TrimStartText", "TrimEndText", "TrimStartSeconds", "TrimEndSeconds", "TrimDurationSeconds", "TrimSummary")) {
        if ($item.PSObject.Properties[$name]) {
            $item.PSObject.Properties.Remove($name)
        }
    }

    $script:PendingTrimSegmentIndex = -1
    $trimStartTextBox.Text = ""
    $trimEndTextBox.Text = ""
    Sync-SelectedTrimSegmentsList
    Update-CutRangeDisplay
    Update-PlanItemTrimEstimate -Item $item
    Update-SelectedTrimGridRow -Item $item
    Update-MediaInfoPanel
    $previewStatusLabel.Text = "Selected file: " + $item.SourceName
    if (Get-Variable -Name "selectedFileSummaryLabel" -ErrorAction SilentlyContinue) {
        $selectedFileSummaryLabel.Text = "Range: -- | Crop: " + (Get-PlanItemCropStatusText -Item $item) + " | Aspect: " + (Get-PlanItemAspectStatusText -Item $item) + " | Open Player za detaljnu obradu."
    }
    Add-LogLine ("Clear Trim: " + $item.SourceName)
}

function Set-GridRows {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Plan
    )

    $grid.Rows.Clear()
    $script:PlanItems = @($Plan | Where-Object { $null -ne $_ })

    foreach ($item in $script:PlanItems) {
        $outputName = [System.IO.Path]::GetFileName($item.OutputPath)
        $displayProperty = $item.PSObject.Properties["DisplayOutputName"]
        if ($displayProperty -and -not [string]::IsNullOrWhiteSpace([string]$displayProperty.Value)) {
            $outputName = [string]$displayProperty.Value
        }

        $estimatedSize = ""
        $estimatedSizeProperty = $item.PSObject.Properties["EstimatedSize"]
        if ($estimatedSizeProperty) {
            $estimatedSize = [string]$estimatedSizeProperty.Value
        }

        $usbNote = ""
        $usbNoteProperty = $item.PSObject.Properties["UsbNote"]
        if ($usbNoteProperty) {
            $usbNote = [string]$usbNoteProperty.Value
        }

        $mediaInfoProperty = $item.PSObject.Properties["MediaInfo"]
        $mediaInfo = if ($mediaInfoProperty) { $mediaInfoProperty.Value } else { $null }
        $sourceResolution = if ($mediaInfo) { [string]$mediaInfo.Resolution } else { "" }
        $sourceDuration = if ($mediaInfo) { [string]$mediaInfo.DurationText } else { "" }
        $sourceVideoSummary = if ($mediaInfo) { [string]$mediaInfo.VideoSummary } else { "" }
        $sourceAudioSummary = if ($mediaInfo) { [string]$mediaInfo.AudioSummary } else { "" }
        $sourceBitrate = if ($mediaInfo) { [string]$mediaInfo.OverallBitrateText } else { "" }
        $container = Get-PlanItemPropertyText -Item $item -Name "PlannedContainer" -Default "MP4"
        $resolution = Get-PlanItemPropertyText -Item $item -Name "PlannedResolution" -Default $sourceResolution
        $duration = Get-PlanItemPropertyText -Item $item -Name "PlannedDurationText" -Default $sourceDuration
        $video = Get-PlanItemPropertyText -Item $item -Name "PlannedVideoSummary" -Default $sourceVideoSummary
        $audio = Get-PlanItemPropertyText -Item $item -Name "PlannedAudioSummary" -Default $sourceAudioSummary
        $bitrate = Get-PlanItemPropertyText -Item $item -Name "PlannedBitrateText" -Default $sourceBitrate
        $frames = if ($mediaInfo -and $mediaInfo.FrameCount) { [string]$mediaInfo.FrameCount } else { "" }
        $range = Get-PlanItemPropertyText -Item $item -Name "TrimSummary" -Default "--"
        $aspect = Get-PlanItemAspectStatusText -Item $item
        $crop = Get-PlanItemCropStatusText -Item $item

        $rowIndex = $grid.Rows.Add($item.SourceName, $outputName, $container, $resolution, $duration, $video, $audio, $bitrate, $frames, $range, $aspect, $crop, $estimatedSize, $usbNote, $item.Status)
        $row = $grid.Rows[$rowIndex]
        $row.Cells["Aspect"].Value = $aspect
    }

    Update-MediaInfoPanel
    Update-PreviewTrimPanel
    Update-OutputPlanPanel
    Update-ProgressBar
    Update-ActionButtons
}

function Get-PlanOutputTarget {
    param(
        [Parameter(Mandatory = $true)]
        $Item
    )

    $patternProperty = $Item.PSObject.Properties["OutputPattern"]
    if ($script:BatchContext -and $script:BatchContext.Context.SplitOutput -and $patternProperty -and -not [string]::IsNullOrWhiteSpace([string]$patternProperty.Value)) {
        return [string]$patternProperty.Value
    }

    return [string]$Item.OutputPath
}

function Add-PlanEstimates {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object[]]$Plan
    )

    $filteredPlan = @($Plan | Where-Object { $null -ne $_ })

    foreach ($item in $filteredPlan) {
        $estimatedSize = "Estimate: --"
        $usbNote = "USB note: FFmpeg/ffprobe potreban"
        $mediaInfo = $null
        $existingMediaInfoProperty = $item.PSObject.Properties["MediaInfo"]
        if ($existingMediaInfoProperty -and $null -ne $existingMediaInfoProperty.Value) {
            $mediaInfo = $existingMediaInfoProperty.Value
        }

        if (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
            try {
                if ($null -eq $mediaInfo) {
                    $mediaInfo = Get-VhsMp4MediaInfo -SourcePath $item.SourcePath -FfmpegPath $script:ResolvedFfmpegPath
                }
                $duration = $mediaInfo.DurationSeconds
                $trimDurationProperty = $item.PSObject.Properties["TrimDurationSeconds"]
                if ($trimDurationProperty -and $null -ne $trimDurationProperty.Value -and [double]$trimDurationProperty.Value -gt 0) {
                    $duration = [double]$trimDurationProperty.Value
                }
                if ($null -ne $duration -and $duration -gt 0) {
                    $maxPartGbForEstimate = 3.8
                    if (-not [string]::IsNullOrWhiteSpace($maxPartGbTextBox.Text)) {
                        $maxPartGbForEstimate = [double]::Parse($maxPartGbTextBox.Text.Trim().Replace(",", "."), [System.Globalization.CultureInfo]::InvariantCulture)
                    }

                    $estimate = Get-VhsMp4EstimatedOutputInfo `
                        -DurationSeconds $duration `
                        -QualityMode (Get-CurrentInternalQualityModeName) `
                        -Crf ([int]$crfTextBox.Text) `
                        -AudioBitrate $audioTextBox.Text `
                        -VideoBitrate (Get-CurrentVideoBitrateText) `
                        -SplitOutput:$splitOutputCheckBox.Checked `
                        -MaxPartGb $maxPartGbForEstimate

                    $estimatedSize = "Estimate: " + (Format-VhsMp4Gigabytes -Gigabytes $estimate.EstimatedGb)
                    if ($splitOutputCheckBox.Checked) {
                        $estimatedSize += " / " + $estimate.PartCount + " delova"
                    }
                    $usbNote = $estimate.UsbNote
                }
            }
            catch {
                $usbNote = "USB note: procena nije dostupna | Media info nije dostupno"
            }
        }

        $item | Add-Member -NotePropertyName "MediaInfo" -NotePropertyValue $mediaInfo -Force
        Sync-PlanItemAspectSnapshot -Item $item | Out-Null
        $mediaSummary = if ($mediaInfo) { "$($mediaInfo.Container) | $($mediaInfo.Resolution) | $($mediaInfo.VideoSummary)" } else { "Media info: --" }
        $item | Add-Member -NotePropertyName "MediaSummary" -NotePropertyValue $mediaSummary -Force
        $item | Add-Member -NotePropertyName "EstimatedSize" -NotePropertyValue $estimatedSize -Force
        $item | Add-Member -NotePropertyName "UsbNote" -NotePropertyValue $usbNote -Force
        Update-PlanItemOutputPresentation -Item $item
        $item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item $item) -Force
    }

    return $filteredPlan
}

function Invoke-BatchAutoApplyCrop {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Items,
        [bool]$Enabled = $false
    )

    if (-not $Enabled) {
        return $Items
    }

    foreach ($item in $Items) {
        if ($null -eq $item -or [string]$item.Status -ne "queued") {
            continue
        }

        $existingCrop = Copy-PlanItemCropState -Item $item
        if ([string]$existingCrop.CropMode -eq "Manual") {
            continue
        }

        $detectedCrop = Get-PlanItemDetectedCropState -Item $item
        if ($null -eq $detectedCrop -or [string]$detectedCrop.CropMode -ne "Auto") {
            continue
        }

        Apply-PlayerCropStateToItem -Item $item -CropState $detectedCrop
        Add-LogLine ("Auto crop primenjen: " + $item.SourceName + " | " + [string]$item.CropSummary)
    }

    return $Items
}

function Update-BatchContextSettingsFromSettings {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Settings
    )

    if ($null -eq $script:BatchContext -or $null -eq $script:BatchContext.Context) {
        return
    }

    $context = $script:BatchContext.Context
    $context.OutputDir = $Settings.OutputDir
    $context.QualityMode = $Settings.QualityMode
    $context.Crf = $Settings.Crf
    $context.Preset = $Settings.Preset
    $context.AudioBitrate = $Settings.AudioBitrate
    $context.VideoBitrate = $Settings.VideoBitrate
    $context.FfmpegPath = $Settings.FfmpegPath
    $context.WorkflowPresetName = $Settings.WorkflowPresetName
    $context.SplitOutput = [bool]$Settings.SplitOutput
    $context.MaxPartGb = $Settings.MaxPartGb
    $context.Deinterlace = $Settings.Deinterlace
    $context.Denoise = $Settings.Denoise
    $context.RotateFlip = $Settings.RotateFlip
    $context.ScaleMode = $Settings.ScaleMode
    $context.AudioNormalize = [bool]$Settings.AudioNormalize
    $context.EncoderMode = [string]$Settings.EncoderMode
    $context.EncoderInventory = $script:EncoderInventory
    $context.FilterSummary = $Settings.FilterSummary
}

function Sync-PausedBatchPlanFromCurrentSettings {
    param(
        [string]$StatusPrefix = "Paused"
    )

    if (-not (Test-BatchPaused)) {
        return $false
    }

    $settings = Get-Settings
    $selectedItem = Get-SelectedPlanItem
    $selectedSourceName = if ($null -ne $selectedItem) { [string]$selectedItem.SourceName } else { "" }
    $queuedItems = @($script:PlanItems | Where-Object { [string]$_.Status -eq "queued" })
    $queuedPaths = @($queuedItems | ForEach-Object { [string]$_.SourcePath } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    $refreshedByPath = @{}
    if ($queuedPaths.Count -gt 0) {
        $refreshedQueuedItems = @(Get-VhsMp4PlanFromPaths -SourcePaths $queuedPaths -InputDir $script:BatchContext.Context.InputDir -OutputDir $settings.OutputDir -FfmpegPath $settings.FfmpegPath -SplitOutput:$settings.SplitOutput)
        foreach ($refreshedItem in $refreshedQueuedItems) {
            $originalItem = @($queuedItems | Where-Object { [string]$_.SourcePath -eq [string]$refreshedItem.SourcePath })[0]
            if ($null -eq $originalItem) {
                continue
            }

            $trimState = Copy-PlanItemTrimState -Item $originalItem
            $cropState = Copy-PlanItemCropState -Item $originalItem
            $aspectMode = Get-PlanItemPropertyText -Item $originalItem -Name "AspectMode" -Default "Auto"

            if ($originalItem.PSObject.Properties["MediaInfo"] -and $null -ne $originalItem.MediaInfo) {
                $refreshedItem | Add-Member -NotePropertyName "MediaInfo" -NotePropertyValue $originalItem.MediaInfo -Force
            }
            if ($originalItem.PSObject.Properties["DetectedCrop"] -and $null -ne $originalItem.DetectedCrop) {
                $refreshedItem | Add-Member -NotePropertyName "DetectedCrop" -NotePropertyValue $originalItem.DetectedCrop -Force
            }
            if ($originalItem.PSObject.Properties["PreviewFramePath"] -and -not [string]::IsNullOrWhiteSpace([string]$originalItem.PreviewFramePath)) {
                $refreshedItem | Add-Member -NotePropertyName "PreviewFramePath" -NotePropertyValue ([string]$originalItem.PreviewFramePath) -Force
            }
            if ($originalItem.PSObject.Properties["PreviewPositionSeconds"] -and $null -ne $originalItem.PreviewPositionSeconds) {
                $refreshedItem | Add-Member -NotePropertyName "PreviewPositionSeconds" -NotePropertyValue ([double]$originalItem.PreviewPositionSeconds) -Force
            }

            Apply-PlayerTrimStateToItem -Item $refreshedItem -TrimState $trimState
            Apply-PlayerCropStateToItem -Item $refreshedItem -CropState $cropState
            $refreshedItem | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue $aspectMode -Force
            Sync-PlanItemAspectSnapshot -Item $refreshedItem | Out-Null
            $refreshedByPath[[string]$refreshedItem.SourcePath] = $refreshedItem
        }
    }

    $mergedPlan = New-Object System.Collections.Generic.List[object]
    foreach ($item in @($script:PlanItems)) {
        if ([string]$item.Status -eq "queued" -and $refreshedByPath.ContainsKey([string]$item.SourcePath)) {
            $mergedPlan.Add($refreshedByPath[[string]$item.SourcePath])
        }
        else {
            $mergedPlan.Add($item)
        }
    }

    $mergedPlanArray = @(Add-PlanEstimates -Plan $mergedPlan)
    $mergedPlanArray = @(Invoke-BatchAutoApplyCrop -Items $mergedPlanArray -Enabled:([bool]$settings.AutoApplyCrop))
    Set-GridRows -Plan $mergedPlanArray
    if (-not [string]::IsNullOrWhiteSpace($selectedSourceName)) {
        [void](Select-PlanGridRowBySourceName -SourceName $selectedSourceName)
    }

    Update-BatchContextSettingsFromSettings -Settings $settings

    if ([string]::IsNullOrWhiteSpace($StatusPrefix)) {
        $StatusPrefix = "Paused"
    }
    Set-StatusText ($StatusPrefix + " | queued fajlovi su osvezeni.")
    return $true
}

function Enter-BatchPausedState {
    if ($null -eq $script:BatchContext) {
        return $false
    }

    $script:BatchContext.PauseRequested = $false
    $script:BatchContext.Paused = $true
    $script:PollTimer.Stop()
    Update-CurrentFileProgress
    Write-SessionLog -Message "PAUSE: batch je pauziran pre sledeceg queued fajla."
    Set-StatusText "Paused"
    Update-ActionButtons
    return $true
}

function Request-BatchPause {
    if ($null -eq $script:BatchContext -or (Test-BatchPaused)) {
        return $false
    }

    $script:BatchContext.PauseRequested = $true
    Write-SessionLog -Message "PAUSE requested after current file."
    if ($null -eq $script:CurrentProcess) {
        return (Enter-BatchPausedState)
    }

    Set-StatusText "Paused after current file"
    Update-ActionButtons
    return $true
}

function Resume-BatchSession {
    if (-not (Test-BatchPaused) -or $null -eq $script:BatchContext) {
        return $false
    }

    try {
        [void](Sync-PausedBatchPlanFromCurrentSettings -StatusPrefix "Resume")
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        [System.Windows.Forms.MessageBox]::Show($message, "Resume", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }

    if (-not (Test-HasQueuedPlanItems)) {
        Finish-BatchSession
        return $false
    }

    $script:BatchContext.Paused = $false
    $script:BatchContext.PauseRequested = $false
    $script:PollTimer.Start()
    Set-StatusText "Resume: nastavljam queued fajlove..."
    [void](Start-NextQueuedItem)
    Update-ActionButtons
    return $true
}

function Move-SelectedQueuedItem {
    param(
        [int]$Direction
    )

    if ($Direction -notin @(-1, 1)) {
        return $false
    }

    if (Test-BatchEditLocked) {
        return $false
    }

    $selectedItem = Get-SelectedPlanItem
    if (-not (Test-PlanItemQueued -Item $selectedItem)) {
        return $false
    }

    $selectedIndex = -1
    for ($index = 0; $index -lt $script:PlanItems.Count; $index++) {
        if ([string]$script:PlanItems[$index].SourcePath -eq [string]$selectedItem.SourcePath) {
            $selectedIndex = $index
            break
        }
    }

    if ($selectedIndex -lt 0) {
        return $false
    }

    $targetIndex = $selectedIndex + $Direction
    while ($targetIndex -ge 0 -and $targetIndex -lt $script:PlanItems.Count) {
        if ([string]$script:PlanItems[$targetIndex].Status -eq "queued") {
            break
        }

        $targetIndex += $Direction
    }

    if ($targetIndex -lt 0 -or $targetIndex -ge $script:PlanItems.Count -or $targetIndex -eq $selectedIndex) {
        return $false
    }

    $buffer = $script:PlanItems[$selectedIndex]
    $script:PlanItems[$selectedIndex] = $script:PlanItems[$targetIndex]
    $script:PlanItems[$targetIndex] = $buffer
    Set-GridRows -Plan $script:PlanItems
    [void](Select-PlanGridRowBySourceName -SourceName ([string]$selectedItem.SourceName))
    if (Test-BatchPaused) {
        Set-StatusText "Paused | queued redosled je azuriran."
    }
    else {
        Set-StatusText "Queue redosled je azuriran."
    }
    return $true
}

function Skip-SelectedQueuedItem {
    if (Test-BatchEditLocked) {
        return $false
    }

    $selectedItem = Get-SelectedPlanItem
    if (-not (Test-PlanItemQueued -Item $selectedItem)) {
        return $false
    }

    Update-RowStatus -SourceName ([string]$selectedItem.SourceName) -Status "skipped"
    Set-StatusText ("Skip Selected: " + [string]$selectedItem.SourceName)
    return $true
}

function Retry-FailedPlanItems {
    if (Test-BatchRunning) {
        return $false
    }

    $failedItems = @($script:PlanItems | Where-Object { (Get-PlanItemStatusText -Item $_) -eq "failed" })
    if ($failedItems.Count -eq 0) {
        return $false
    }

    foreach ($item in $failedItems) {
        $item.Status = "queued"
    }

    Set-GridRows -Plan $script:PlanItems
    if ($script:PlanItems.Count -gt 0) {
        [void](Select-PlanGridRowBySourceName -SourceName ([string]$failedItems[0].SourceName))
    }
    Set-StatusText ("Retry Failed: " + $failedItems.Count + " fajl(ova) vraceno u queue.")
    return $true
}

function Clear-CompletedPlanItems {
    if (Test-BatchRunning) {
        return $false
    }

    $remainingItems = @($script:PlanItems | Where-Object { (Get-PlanItemStatusText -Item $_) -notin @("done", "skipped", "stopped") })
    if ($remainingItems.Count -eq $script:PlanItems.Count) {
        return $false
    }

    Set-GridRows -Plan $remainingItems
    if ($script:PlanItems.Count -gt 0) {
        [void](Select-PlanGridRowBySourceName -SourceName ([string]$script:PlanItems[0].SourceName))
    }
    Set-StatusText "Clear Completed: zavrseni/skipped/stopped fajlovi su uklonjeni iz queue."
    return $true
}

function Export-QueuePlanToFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($script:PlanItems.Count -eq 0) {
        throw "Queue je prazan; nema sta da se sacuva."
    }

    $crfValue = 22
    [void][int]::TryParse([string]$crfTextBox.Text, [ref]$crfValue)
    $maxPartGb = 3.8
    $numberStyles = [System.Globalization.NumberStyles]::Float
    $culture = [System.Globalization.CultureInfo]::InvariantCulture
    $maxPartText = [string]$maxPartGbTextBox.Text
    if (-not [string]::IsNullOrWhiteSpace($maxPartText)) {
        [void][double]::TryParse($maxPartText.Trim().Replace(",", "."), $numberStyles, $culture, [ref]$maxPartGb)
    }

    $payload = [pscustomobject]@{
        SchemaVersion = 1
        SavedAtUtc = ((Get-Date).ToUniversalTime().ToString("o"))
        AppName = "VHS MP4 Optimizer"
        Settings = [pscustomobject]@{
            InputDir = [string]$inputTextBox.Text
            OutputDir = [string]$outputTextBox.Text
            FfmpegPath = if (-not [string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) { [string]$script:ResolvedFfmpegPath } else { [string]$ffmpegPathTextBox.Text }
            WorkflowPresetName = if ([string]::IsNullOrWhiteSpace([string]$workflowPresetComboBox.SelectedItem)) { $script:WorkflowPresetCustomName } else { [string]$workflowPresetComboBox.SelectedItem }
            QualityMode = Get-CurrentQualityModeSelectionLabel
            Crf = $crfValue
            Preset = [string]$presetComboBox.SelectedItem
            AudioBitrate = [string]$audioTextBox.Text
            VideoBitrate = Get-CurrentVideoBitrateText
            Deinterlace = [string]$deinterlaceComboBox.SelectedItem
            Denoise = [string]$denoiseComboBox.SelectedItem
            RotateFlip = [string]$rotateFlipComboBox.SelectedItem
            ScaleMode = [string]$scaleModeComboBox.SelectedItem
            AudioNormalize = [bool]$audioNormalizeCheckBox.Checked
            EncoderMode = if ([string]::IsNullOrWhiteSpace([string]$encoderModeComboBox.SelectedItem)) { $script:EncoderModeDefaultName } else { [string]$encoderModeComboBox.SelectedItem }
            SplitOutput = [bool]$splitOutputCheckBox.Checked
            AutoApplyCrop = [bool]$autoApplyCropCheckBox.Checked
            MaxPartGb = $maxPartGb
        }
        PlanItems = @($script:PlanItems)
    }

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    Set-Content -LiteralPath $Path -Value ($payload | ConvertTo-Json -Depth 16) -Encoding UTF8
    Set-StatusText ("Queue sacuvan: " + $Path)
    return $true
}

function Import-QueuePlanFromFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-BatchRunning) {
        return $false
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Queue fajl ne postoji."
    }

    $rawContent = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($rawContent)) {
        throw "Queue fajl je prazan."
    }

    $parsed = ConvertFrom-Json -InputObject $rawContent -ErrorAction Stop
    $settingsObject = Get-WorkflowPresetObjectValue -Object $parsed -Name "Settings"
    if ($null -eq $settingsObject) {
        throw "Queue fajl nema Settings sekciju."
    }

    $normalizedSettings = New-WorkflowPresetSettingsObject -Settings $settingsObject
    $inputTextBox.Text = [string](Get-WorkflowPresetObjectValue -Object $settingsObject -Name "InputDir")
    $outputTextBox.Text = [string](Get-WorkflowPresetObjectValue -Object $settingsObject -Name "OutputDir")
    $ffmpegPathTextBox.Text = [string](Get-WorkflowPresetObjectValue -Object $settingsObject -Name "FfmpegPath")
    Sync-FfmpegState
    Set-WorkflowPresetControlsFromSettings -Settings $normalizedSettings
    Update-WorkflowPresetDirtyState

    $rawPlanItems = @((Get-WorkflowPresetObjectValue -Object $parsed -Name "PlanItems"))
    $planItems = New-Object System.Collections.Generic.List[object]
    $aspectModeBySource = @{}
    foreach ($item in $rawPlanItems) {
        if ($null -eq $item) {
            continue
        }

        $status = [string](Get-PlanItemPropertyText -Item $item -Name "Status" -Default "queued")
        $aspectModeRaw = [string](Get-PlanItemPropertyText -Item $item -Name "AspectMode" -Default "")
        $aspectMode = if ([string]::IsNullOrWhiteSpace($aspectModeRaw)) { "" } else { Get-AspectModeDisplayName -AspectMode $aspectModeRaw -Default $aspectModeRaw }
        if ($status -in @("running", "processing", "paused")) {
            $status = "queued"
        }
        $item | Add-Member -NotePropertyName "Status" -NotePropertyValue $status -Force
        Sync-PlanItemAspectSnapshot -Item $item | Out-Null
        if (-not [string]::IsNullOrWhiteSpace($aspectMode)) {
            $aspectModeBySource[[string]$item.SourcePath] = $aspectMode
            $item | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue $aspectMode -Force
        }
        $planItems.Add($item)
    }

    $restoredPlan = @($planItems.ToArray())
    $restoredPlan = @(Add-PlanEstimates -Plan $restoredPlan)
    foreach ($item in $restoredPlan) {
        $sourcePath = [string]$item.SourcePath
        if (-not [string]::IsNullOrWhiteSpace($sourcePath) -and $aspectModeBySource.ContainsKey($sourcePath)) {
            $item | Add-Member -NotePropertyName "AspectMode" -NotePropertyValue ([string]$aspectModeBySource[$sourcePath]) -Force
        }
    }
    Set-GridRows -Plan $restoredPlan
    if ($script:PlanItems.Count -gt 0) {
        [void](Select-PlanGridRowBySourceName -SourceName ([string]$script:PlanItems[0].SourceName))
    }
    Set-StatusText ("Queue ucitan: " + $Path)
    return $true
}

function Show-SaveQueueDialog {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "Queue (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "Save Queue"
    $dialog.FileName = "vhs-mp4-queue.json"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $false
    }

    return (Export-QueuePlanToFile -Path $dialog.FileName)
}

function Show-LoadQueueDialog {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Queue (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "Load Queue"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $false
    }

    return (Import-QueuePlanFromFile -Path $dialog.FileName)
}

function Update-RowStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceName,
        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    foreach ($item in $script:PlanItems) {
        if ([string]$item.SourceName -eq $SourceName) {
            $item.Status = $Status
            break
        }
    }

    foreach ($row in $grid.Rows) {
        if ([string]$row.Cells["SourceName"].Value -eq $SourceName) {
            $row.Cells["Status"].Value = $Status
            break
        }
    }

    Update-ProgressBar
    Update-ActionButtons
}

function Get-Settings {
    if ([string]::IsNullOrWhiteSpace($inputTextBox.Text)) {
        throw "Izaberi input folder."
    }

    if (-not (Test-Path -LiteralPath $inputTextBox.Text)) {
        throw "Input folder ne postoji."
    }

    $crfValue = 22
    if (-not [int]::TryParse($crfTextBox.Text, [ref]$crfValue)) {
        throw "CRF mora biti ceo broj."
    }

    if ($crfValue -lt 0 -or $crfValue -gt 51) {
        throw "CRF mora biti izmedju 0 i 51."
    }

    if ([string]::IsNullOrWhiteSpace($audioTextBox.Text) -or $audioTextBox.Text -notmatch "^\d+k$") {
        throw "Audio bitrate mora biti oblika 160k."
    }

    $videoBitrateText = Get-CurrentVideoBitrateText
    if (-not [string]::IsNullOrWhiteSpace($videoBitrateText) -and $videoBitrateText -notmatch "^\d+k$") {
        throw "Video bitrate mora biti oblika 4500k ili prazno za CRF/Quality mode."
    }

    $maxPartGb = 3.8
    if ($splitOutputCheckBox.Checked) {
        $maxPartText = $maxPartGbTextBox.Text.Trim().Replace(",", ".")
        $numberStyles = [System.Globalization.NumberStyles]::Float
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        if (-not [double]::TryParse($maxPartText, $numberStyles, $culture, [ref]$maxPartGb)) {
            throw "Max part GB mora biti broj, na primer 3.8."
        }

        if ($maxPartGb -lt 0.001 -or $maxPartGb -gt 1024) {
            throw "Max part GB mora biti izmedju 0.001 i 1024."
        }
    }

    if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
        $outputTextBox.Text = Join-Path $inputTextBox.Text "vhs-mp4-output"
    }

    if ([string]::IsNullOrWhiteSpace($script:ResolvedFfmpegPath)) {
        throw "FFmpeg nije spreman. Program ga pokusava automatski instalirati; rucni fallback je u Help > Install FFmpeg / Browse FFmpeg."
    }

    return [pscustomobject]@{
        InputDir = $inputTextBox.Text
        OutputDir = $outputTextBox.Text
        QualityMode = Get-CurrentInternalQualityModeName
        Crf = $crfValue
        Preset = [string]$presetComboBox.SelectedItem
        AudioBitrate = $audioTextBox.Text
        VideoBitrate = $videoBitrateText
        FfmpegPath = $script:ResolvedFfmpegPath
        WorkflowPresetName = if ([string]::IsNullOrWhiteSpace([string]$workflowPresetComboBox.SelectedItem)) { $script:WorkflowPresetCustomName } else { [string]$workflowPresetComboBox.SelectedItem }
        SplitOutput = [bool]$splitOutputCheckBox.Checked
        MaxPartGb = $maxPartGb
        Deinterlace = [string]$deinterlaceComboBox.SelectedItem
        Denoise = [string]$denoiseComboBox.SelectedItem
        RotateFlip = [string]$rotateFlipComboBox.SelectedItem
        ScaleMode = [string]$scaleModeComboBox.SelectedItem
        AudioNormalize = [bool]$audioNormalizeCheckBox.Checked
        EncoderMode = if ([string]::IsNullOrWhiteSpace([string]$encoderModeComboBox.SelectedItem)) { $script:EncoderModeDefaultName } else { [string]$encoderModeComboBox.SelectedItem }
        AutoApplyCrop = [bool]$autoApplyCropCheckBox.Checked
        FilterSummary = Get-VhsMp4FilterSummary `
            -Deinterlace ([string]$deinterlaceComboBox.SelectedItem) `
            -Denoise ([string]$denoiseComboBox.SelectedItem) `
            -RotateFlip ([string]$rotateFlipComboBox.SelectedItem) `
            -ScaleMode ([string]$scaleModeComboBox.SelectedItem) `
            -AudioNormalize:$audioNormalizeCheckBox.Checked
    }
}

function Invoke-WorkflowPresetFieldChanged {
    if ($script:WorkflowPresetApplying) {
        Update-ActionButtons
        return
    }

    Update-WorkflowPresetDirtyState
    try {
        Refresh-PlanEstimatesForCurrentSettings -StatusPrefix "Podesavanja"
    }
    catch {
        if (Test-BatchPaused) {
            Set-StatusText ("Paused | " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        }
        else {
            Set-StatusText ("Podesavanja | " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        }
    }
    Update-ActionButtons
}

function Show-WorkflowPresetSaveDialog {
    param(
        [string]$InitialName = "",
        [string]$InitialDescription = ""
    )

    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = "Save Preset"
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = New-Object System.Drawing.Size(430, 150)
    $dialog.ShowInTaskbar = $false

    $layout = New-Object System.Windows.Forms.TableLayoutPanel
    $layout.Dock = "Fill"
    $layout.Padding = New-Object System.Windows.Forms.Padding(12)
    $layout.ColumnCount = 2
    $layout.RowCount = 4
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
    $layout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
    $layout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
    $dialog.Controls.Add($layout)

    $nameLabel = New-Object System.Windows.Forms.Label
    $nameLabel.Text = "Name"
    $nameLabel.Anchor = "Left"
    $nameLabel.AutoSize = $true
    $layout.Controls.Add($nameLabel, 0, 0)

    $nameTextBox = New-Object System.Windows.Forms.TextBox
    $nameTextBox.Dock = "Fill"
    $nameTextBox.Text = $InitialName
    $layout.Controls.Add($nameTextBox, 1, 0)

    $descriptionLabel = New-Object System.Windows.Forms.Label
    $descriptionLabel.Text = "Description"
    $descriptionLabel.Anchor = "Left"
    $descriptionLabel.AutoSize = $true
    $layout.Controls.Add($descriptionLabel, 0, 1)

    $descriptionTextBox = New-Object System.Windows.Forms.TextBox
    $descriptionTextBox.Dock = "Fill"
    $descriptionTextBox.Text = $InitialDescription
    $layout.Controls.Add($descriptionTextBox, 1, 1)

    $hintLabel = New-Object System.Windows.Forms.Label
    $hintLabel.Text = "Workflow preset cuva samo opsta batch podesavanja, bez trim/segment podataka."
    $hintLabel.Dock = "Fill"
    $hintLabel.AutoEllipsis = $true
    $layout.Controls.Add($hintLabel, 0, 2)
    $layout.SetColumnSpan($hintLabel, 2)

    $buttonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
    $buttonsFlow.Dock = "Right"
    $buttonsFlow.WrapContents = $false
    $layout.Controls.Add($buttonsFlow, 0, 3)
    $layout.SetColumnSpan($buttonsFlow, 2)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "Save"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonsFlow.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonsFlow.Controls.Add($cancelButton)

    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    return [pscustomobject]@{
        Name = $nameTextBox.Text.Trim()
        Description = $descriptionTextBox.Text.Trim()
    }
}

function Get-WorkflowPresetForExport {
    $selectedName = [string]$workflowPresetComboBox.SelectedItem
    $selectedPreset = Find-WorkflowPresetByName -Name $selectedName
    if ($null -ne $selectedPreset) {
        return $selectedPreset
    }

    return (New-WorkflowPresetObject -Name $script:WorkflowPresetCustomName -Kind "User" -Description "Custom - rucno izmenjena opsta batch podesavanja." -Settings (Get-CurrentWorkflowPresetSettings))
}

function Scan-InputFolder {
    if ([string]::IsNullOrWhiteSpace($inputTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Izaberi input folder pa klikni Scan Files.", "VHS MP4 Optimizer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    if (-not (Test-Path -LiteralPath $inputTextBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Input folder ne postoji.", "VHS MP4 Optimizer", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return
    }

    if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
        $outputTextBox.Text = Join-Path $inputTextBox.Text "vhs-mp4-output"
    }

    Sync-FfmpegState
    $plan = @(Get-VhsMp4Plan -InputDir $inputTextBox.Text -OutputDir $outputTextBox.Text -FfmpegPath $script:ResolvedFfmpegPath -SplitOutput:$splitOutputCheckBox.Checked)
    $plan = @(Add-PlanEstimates -Plan $plan)
    Set-GridRows -Plan $plan

    if ($plan.Count -eq 0) {
        $allFiles = @(Get-ChildItem -LiteralPath $inputTextBox.Text -File -Recurse -Force -ErrorAction SilentlyContinue)
        $extensions = @($allFiles | Group-Object { if ([string]::IsNullOrWhiteSpace($_.Extension)) { "(bez ekstenzije)" } else { $_.Extension.ToLowerInvariant() } } | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" })
        $extensionText = if ($extensions.Count -gt 0) { " Ekstenzije koje vidim: " + ($extensions -join ", ") } else { "" }
        Set-StatusText "Scan Files je zavrsen, ali nema podrzanih video fajlova u folderu ili podfolderima: .mp4, .avi, .mpg, .mpeg, .mov, .mkv, .m4v, .wmv, .ts, .m2ts ili .vob. Ukupno fajlova koje vidim: $($allFiles.Count).$extensionText"
        return
    }

    $queued = @($plan | Where-Object { $_.Status -eq "queued" }).Count
    $skipped = @($plan | Where-Object { $_.Status -eq "skipped" }).Count
    $fat32Warnings = @($plan | Where-Object { ([string]$_.UsbNote) -match "FAT32 rizik" }).Count
    $splitNote = if ($splitOutputCheckBox.Checked) { " | split: part%03d do oko $($maxPartGbTextBox.Text) GB" } else { "" }
    $usbNote = if ($fat32Warnings -gt 0) { " | FAT32 upozorenja: $fat32Warnings, exFAT ili Split output" } else { " | USB: FAT32/exFAT OK po proceni" }
    Set-StatusText "Scan Files: pronadjeno $($plan.Count) | queued: $queued | skipped: $skipped$splitNote$usbNote | Start Conversion pokrece obradu."
}

function Import-DroppedPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths
    )

    if (Test-BatchRunning) {
        Set-StatusText "Drag & drop je privremeno iskljucen dok traje konverzija."
        return
    }

    $candidatePaths = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($candidatePaths.Count -eq 0) {
        return
    }

    $previousInputDir = [string]$inputTextBox.Text
    $inputDir = Get-DroppedSelectionInputDir -Paths $candidatePaths
    if ([string]::IsNullOrWhiteSpace($inputDir)) {
        Set-StatusText "Drop import: ne mogu da odredim input folder."
        return
    }

    $inputTextBox.Text = $inputDir
    Set-SuggestedOutputDirForInput -InputDir $inputDir -PreviousInputDir $previousInputDir
    Sync-FfmpegState

    $plan = @(Get-VhsMp4PlanFromPaths -SourcePaths $candidatePaths -InputDir $inputDir -OutputDir $outputTextBox.Text -FfmpegPath $script:ResolvedFfmpegPath -SplitOutput:$splitOutputCheckBox.Checked)
    $plan = @(Add-PlanEstimates -Plan $plan)
    Set-GridRows -Plan $plan

    if ($plan.Count -eq 0) {
        Set-StatusText "Drop import: nema podrzanih video fajlova u izboru. Podrzano: .mp4, .avi, .mpg, .mpeg, .mov, .mkv, .m4v, .wmv, .ts, .m2ts, .vob."
        return
    }

    $queued = @($plan | Where-Object { $_.Status -eq "queued" }).Count
    $skipped = @($plan | Where-Object { $_.Status -eq "skipped" }).Count
    $fat32Warnings = @($plan | Where-Object { ([string]$_.UsbNote) -match "FAT32 rizik" }).Count
    $splitNote = if ($splitOutputCheckBox.Checked) { " | split: part%03d do oko $($maxPartGbTextBox.Text) GB" } else { "" }
    $usbNote = if ($fat32Warnings -gt 0) { " | FAT32 upozorenja: $fat32Warnings, exFAT ili Split output" } else { " | USB: FAT32/exFAT OK po proceni" }
    Set-StatusText "Drop import: pronadjeno $($plan.Count) | queued: $queued | skipped: $skipped$splitNote$usbNote | Start Conversion pokrece obradu."
}

function Get-SelectedOrFirstPlanItem {
    $selectedItem = Get-SelectedPlanItem
    if ($null -ne $selectedItem -and ((-not (Test-BatchPaused)) -or (Test-PlanItemQueued -Item $selectedItem))) {
        return $selectedItem
    }

    foreach ($item in $script:PlanItems) {
        if ([string]$item.Status -eq "queued") {
            return $item
        }
    }

    foreach ($item in $script:PlanItems) {
        return $item
    }

    return $null
}

function Invoke-TestSample {
    if (Test-BatchEditLocked) {
        return
    }

    try {
        $settings = Get-Settings
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        $response = [System.Windows.Forms.MessageBox]::Show($message + "`r`n`r`nDa pokusam Install FFmpeg sada?", "Test Sample", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            Install-FFmpegInteractive
        }
        return
    }

    if ($script:PlanItems.Count -eq 0) {
        Scan-InputFolder
    }

    $item = Get-SelectedOrFirstPlanItem
    if ($null -eq $item) {
        [System.Windows.Forms.MessageBox]::Show("Nema fajlova za Test Sample.", "Test Sample", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        return
    }

    $form.UseWaitCursor = $true
    Update-ActionButtons

    try {
        $context = New-VhsMp4RunContext `
            -InputDir $settings.InputDir `
            -OutputDir $settings.OutputDir `
            -QualityMode $settings.QualityMode `
            -Crf $settings.Crf `
            -Preset $settings.Preset `
            -AudioBitrate $settings.AudioBitrate `
            -VideoBitrate $settings.VideoBitrate `
            -FfmpegPath $settings.FfmpegPath `
            -SplitOutput:$false `
            -MaxPartGb $settings.MaxPartGb `
            -Deinterlace $settings.Deinterlace `
            -Denoise $settings.Denoise `
            -RotateFlip $settings.RotateFlip `
            -ScaleMode $settings.ScaleMode `
            -AudioNormalize:([bool]$settings.AudioNormalize)

        $script:LastLogPath = $context.LogPath
        $samplePath = Get-VhsMp4SampleOutputPath -OutputDir $context.OutputDir -SourceName $item.SourceName
        Add-LogLine ("Test Sample: " + $item.SourcePath + " -> " + $samplePath)
        Set-StatusText ("Pravim Test Sample od 120 sekundi: " + $item.SourceName)

        $result = Invoke-VhsMp4File `
            -SourcePath $item.SourcePath `
            -OutputPath $samplePath `
            -FfmpegPath $context.FfmpegPath `
            -QualityMode $context.QualityMode `
            -Crf $context.Crf `
            -Preset $context.Preset `
            -AudioBitrate $context.AudioBitrate `
            -VideoBitrate $context.VideoBitrate `
            -SampleSeconds 120 `
            -Deinterlace $context.Deinterlace `
            -Denoise $context.Denoise `
            -RotateFlip $context.RotateFlip `
            -ScaleMode $context.ScaleMode `
            -AudioNormalize:([bool]$context.AudioNormalize)

        foreach ($line in (($result.StdOut + [Environment]::NewLine + $result.StdErr) -split "\r?\n")) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Add-LogLine ("FFMPEG: " + $line)
            }
        }

        if (-not $result.Success) {
            throw "FFmpeg exit code: $($result.ExitCode)"
        }

        Add-LogLine ("OK Test Sample: " + $samplePath)
        Set-StatusText ("Test Sample gotov: " + [System.IO.Path]::GetFileName($samplePath))
        Show-CompletionNotice -Text "Test Sample je gotov."
        Invoke-Item -LiteralPath (Split-Path -Path $samplePath -Parent)
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        Add-LogLine ("Test Sample error: " + $message)
        Set-StatusText ("Test Sample greska: " + $message)
        [System.Windows.Forms.MessageBox]::Show($message, "Test Sample", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
    finally {
        $form.UseWaitCursor = $false
        Update-ActionButtons
    }
}

function Invoke-CommandWithOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $quotedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"' + ($argument -replace '"', '\"') + '"'
        }
        else {
            $argument
        }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $FilePath
    $startInfo.Arguments = ($quotedArguments -join " ")
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode = $process.ExitCode
        StdOut = $stdout
        StdErr = $stderr
    }
}

function Prompt-BrowseFfmpeg {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "FFmpeg executable|ffmpeg.exe|Executable files|*.exe|All files|*.*"
    $openFileDialog.Title = "Izaberi ffmpeg.exe"
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $ffmpegPathTextBox.Text = $openFileDialog.FileName
        Sync-FfmpegState
        return $true
    }

    return $false
}

function Install-FFmpegAutomatic {
    param(
        [switch]$AllowBrowseFallback,
        [switch]$ShowFailureDialog,
        [switch]$StartupBootstrap
    )

    try {
        $wingetPath = Resolve-VhsMp4CommandPath -CommandPath "winget"
    }
    catch {
        $message = "winget nije pronadjen. FFmpeg auto-install nije moguc bez winget-a."
        Add-LogLine $message
        Set-StatusText $message
        if ($AllowBrowseFallback) {
            [void](Prompt-BrowseFfmpeg)
        }
        elseif ($ShowFailureDialog) {
            [System.Windows.Forms.MessageBox]::Show($message, "Install FFmpeg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        return $false
    }

    $installArgs = @(
        "install",
        "--id", $script:WingetPackageId,
        "-e",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    )

    $form.UseWaitCursor = $true
    if ($StartupBootstrap) {
        Set-StatusText "FFmpeg nije pronadjen. Pokusavam automatsku instalaciju..."
    }
    else {
        Set-StatusText "Instaliram FFmpeg..."
    }
    Add-LogLine "winget install --id Gyan.FFmpeg.Essentials -e --accept-package-agreements --accept-source-agreements --disable-interactivity"

    try {
        $result = Invoke-CommandWithOutput -FilePath $wingetPath -Arguments $installArgs
        foreach ($line in (($result.StdOut + [Environment]::NewLine + $result.StdErr) -split "\r?\n")) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Add-LogLine $line
            }
        }

        if ($result.ExitCode -ne 0) {
            throw "winget install nije uspeo (exit code: $($result.ExitCode))."
        }

        Update-VhsMp4ProcessPathFromEnvironment | Out-Null
        $installedFfmpeg = Find-VhsMp4InstalledFfmpeg -SearchRoots (Get-FfmpegSearchRoots)
        if ($installedFfmpeg) {
            Add-VhsMp4DirectoryToUserPath -Directory (Split-Path -Path $installedFfmpeg -Parent) | Out-Null
            Update-VhsMp4ProcessPathFromEnvironment | Out-Null
            $ffmpegPathTextBox.Text = $installedFfmpeg
            Sync-FfmpegState
            Set-StatusText "FFmpeg je instaliran i spreman."
            return $true
        }
        else {
            Sync-FfmpegState
            throw "FFmpeg je mozda instaliran, ali putanja nije automatski pronadjena."
        }
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        Add-LogLine ("Install FFmpeg error: " + $message)
        Set-StatusText $message
        if ($AllowBrowseFallback) {
            $fallback = [System.Windows.Forms.MessageBox]::Show("Automatska instalacija nije uspela ili FFmpeg nije pronadjen posle instalacije.`r`n`r`nDa otvorim rucni izbor ffmpeg.exe?", "Install FFmpeg", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($fallback -eq [System.Windows.Forms.DialogResult]::Yes) {
                [void](Prompt-BrowseFfmpeg)
            }
        }
        elseif ($ShowFailureDialog) {
            [System.Windows.Forms.MessageBox]::Show($message, "Install FFmpeg", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        return $false
    }
    finally {
        $form.UseWaitCursor = $false
        Update-ActionButtons
    }
}

function Install-FFmpegInteractive {
    $message = "GUI moze da instalira FFmpeg preko winget i da ga automatski doda u user PATH.`r`n`r`nNastavi?"
    $choice = [System.Windows.Forms.MessageBox]::Show($message, "Install FFmpeg", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    [void](Install-FFmpegAutomatic -AllowBrowseFallback -ShowFailureDialog)
}

function Ensure-FfmpegReadyOnStartup {
    if ($script:AutoFfmpegBootstrapAttempted -or $script:AutoFfmpegBootstrapInProgress) {
        return
    }

    if ((Get-VhsMp4InstallType) -eq "Repo/dev") {
        return
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$script:ResolvedFfmpegPath)) {
        return
    }

    $script:AutoFfmpegBootstrapAttempted = $true
    $script:AutoFfmpegBootstrapInProgress = $true
    try {
        [void](Install-FFmpegAutomatic -StartupBootstrap)
    }
    finally {
        $script:AutoFfmpegBootstrapInProgress = $false
        Sync-FfmpegState
    }
}

function Mark-RemainingQueuedItemsStopped {
    foreach ($item in $script:PlanItems) {
        if ([string]$item.Status -eq "queued") {
            Update-RowStatus -SourceName $item.SourceName -Status "stopped"
            $outputTarget = Get-PlanOutputTarget -Item $item
            Write-SessionLog -Message ("STOP: " + $item.SourcePath + " -> " + $outputTarget + " | batch stop before start")
        }
    }
}

function Finish-BatchSession {
    param(
        [string]$ErrorMessage
    )

    $script:PollTimer.Stop()
    $script:CurrentProcess = $null
    $script:CurrentPlanItem = $null
    $script:CurrentProgressPath = $null
    $script:CurrentDurationSeconds = $null
    $script:CurrentFileStartedAt = $null
    $script:SharedState.CurrentProcessId = $null

    if ($ErrorMessage) {
        Write-SessionLog -Message ("ERROR: " + $ErrorMessage)
        Set-StatusText ("Greska: " + $ErrorMessage)
    }
    else {
        $reportPath = $null
        try {
            $reportPath = Write-VhsMp4CustomerReport `
                -OutputDir $script:BatchContext.Context.OutputDir `
                -Items $script:PlanItems `
                -QualityMode $script:BatchContext.Context.QualityMode `
                -Crf $script:BatchContext.Context.Crf `
                -Preset $script:BatchContext.Context.Preset `
                -AudioBitrate $script:BatchContext.Context.AudioBitrate `
                -VideoBitrate $script:BatchContext.Context.VideoBitrate `
                -SplitOutput ([bool]$script:BatchContext.Context.SplitOutput) `
                -MaxPartGb $script:BatchContext.Context.MaxPartGb `
                -FilterSummary $script:BatchContext.Context.FilterSummary `
                -WorkflowPresetName ([string]$script:BatchContext.Context.WorkflowPresetName)
            $script:LastReportPath = $reportPath
            Write-SessionLog -Message ("Report: " + $reportPath)
        }
        catch {
            Write-SessionLog -Message ("WARN: IZVESTAJ.txt nije napravljen | " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
        }

        $counts = Get-PlanStatusCounts
        $reportNote = if ($reportPath) { " | IZVESTAJ.txt spreman" } else { "" }
        Set-StatusText ("Zavrseno | done: {0} | skipped: {1} | failed: {2} | stopped: {3}{4}" -f $counts.Done, $counts.Skipped, $counts.Failed, $counts.Stopped, $reportNote)
        Show-CompletionNotice -Text "Konverzija je zavrsena. IZVESTAJ.txt je spreman."
    }

    $script:BatchContext = $null
    Update-ProgressBar
    Update-ActionButtons
}

function Start-NextQueuedItem {
    if ($null -eq $script:BatchContext) {
        return $false
    }

    if (Test-BatchPaused) {
        return $false
    }

    if ($script:SharedState.StopRequested) {
        Mark-RemainingQueuedItemsStopped
        Finish-BatchSession
        return $false
    }

    if ($script:BatchContext.PauseRequested) {
        if (Test-HasQueuedPlanItems) {
            [void](Enter-BatchPausedState)
            return $false
        }

        Finish-BatchSession
        return $false
    }

    for ($index = $script:CurrentBatchIndex + 1; $index -lt $script:PlanItems.Count; $index++) {
        $script:CurrentBatchIndex = $index
        $item = $script:PlanItems[$index]

        if ([string]$item.Status -ne "queued") {
            continue
        }

        $outputTarget = Get-PlanOutputTarget -Item $item
        Update-RowStatus -SourceName $item.SourceName -Status "running"
        Write-SessionLog -Message ("RUN: " + $item.SourcePath + " -> " + $outputTarget)

        try {
            $progressName = ([string]$item.SourceName) -replace "[^A-Za-z0-9_.-]", "_"
            $script:CurrentProgressPath = Join-Path $script:BatchContext.Context.LogDir ("progress-" + $progressName + ".txt")
            if (Test-Path -LiteralPath $script:CurrentProgressPath) {
                Remove-Item -LiteralPath $script:CurrentProgressPath -Force
            }

            $script:CurrentDurationSeconds = $null
            $trimDurationProperty = $item.PSObject.Properties["TrimDurationSeconds"]
            if ($trimDurationProperty -and $null -ne $trimDurationProperty.Value -and [double]$trimDurationProperty.Value -gt 0) {
                $script:CurrentDurationSeconds = [double]$trimDurationProperty.Value
            }
            else {
                try {
                    $script:CurrentDurationSeconds = Get-VhsMp4MediaDurationSeconds -SourcePath $item.SourcePath -FfmpegPath $script:BatchContext.Context.FfmpegPath
                }
                catch {
                    Write-SessionLog -Message ("WARN: ffprobe duration unavailable for " + $item.SourceName + " | " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
                }
            }
            $script:CurrentFileStartedAt = Get-Date
            Update-CurrentFileProgress

            $trimStartForItem = Get-PlanItemPropertyText -Item $item -Name "TrimStartText" -Default ""
            $trimEndForItem = Get-PlanItemPropertyText -Item $item -Name "TrimEndText" -Default ""
            $trimSegmentsProperty = $item.PSObject.Properties["TrimSegments"]
            $trimSegmentsForItem = if ($trimSegmentsProperty -and $null -ne $trimSegmentsProperty.Value) { @($trimSegmentsProperty.Value) } else { @() }
            $itemHasAudio = $true
            $mediaInfoProperty = $item.PSObject.Properties["MediaInfo"]
            if ($mediaInfoProperty -and $null -ne $mediaInfoProperty.Value) {
                $itemHasAudio = -not [string]::IsNullOrWhiteSpace([string]$mediaInfoProperty.Value.AudioCodec)
            }

            $started = Start-VhsMp4FileProcess `
                -SourcePath $item.SourcePath `
                -OutputPath $outputTarget `
                -FfmpegPath $script:BatchContext.Context.FfmpegPath `
                -QualityMode $script:BatchContext.Context.QualityMode `
                -Crf $script:BatchContext.Context.Crf `
                -Preset $script:BatchContext.Context.Preset `
                -AudioBitrate $script:BatchContext.Context.AudioBitrate `
                -VideoBitrate $script:BatchContext.Context.VideoBitrate `
                -ProgressPath $script:CurrentProgressPath `
                -SplitOutput:([bool]$script:BatchContext.Context.SplitOutput) `
                -MaxPartGb $script:BatchContext.Context.MaxPartGb `
                -TrimStart $trimStartForItem `
                -TrimEnd $trimEndForItem `
                -TrimSegments $trimSegmentsForItem `
                -SourceHasAudio $itemHasAudio `
                -Deinterlace $script:BatchContext.Context.Deinterlace `
                -Denoise $script:BatchContext.Context.Denoise `
                -RotateFlip $script:BatchContext.Context.RotateFlip `
                -ScaleMode $script:BatchContext.Context.ScaleMode `
                -AudioNormalize:([bool]$script:BatchContext.Context.AudioNormalize) `
                -EncoderMode ([string]$script:BatchContext.Context.EncoderMode) `
                -EncoderInventory $script:BatchContext.Context.EncoderInventory `
                -SharedState $script:SharedState

            $script:CurrentProcess = $started.Process
            $script:CurrentPlanItem = $item
            Set-StatusText ("Obradjujem: " + $item.SourceName)
            Update-ActionButtons
            return $true
        }
        catch {
            $message = Get-VhsMp4ErrorMessage -ErrorObject $_
            Update-RowStatus -SourceName $item.SourceName -Status "failed"
            Write-SessionLog -Message ("FAIL: " + $item.SourcePath + " -> " + $outputTarget + " | " + $message)
        }
    }

    Finish-BatchSession
    return $false
}

function Complete-CurrentProcess {
    if ($null -eq $script:CurrentProcess -or $null -eq $script:CurrentPlanItem) {
        return
    }

    $item = $script:CurrentPlanItem
    $outputTarget = Get-PlanOutputTarget -Item $item

    try {
        $result = Complete-VhsMp4FileProcess -Process $script:CurrentProcess -OutputPath $outputTarget -SharedState $script:SharedState

        foreach ($line in (($result.StdOut + [Environment]::NewLine + $result.StdErr) -split "\r?\n")) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-SessionLog -Message ("FFMPEG: " + $line)
            }
        }

        if ($result.Success) {
            $currentFileProgressBar.Value = 100
            $currentFilePercentLabel.Text = "100%"
            $currentFileEtaLabel.Text = "ETA: 00:00:00"
            Update-RowStatus -SourceName $item.SourceName -Status "done"
            Write-SessionLog -Message ("OK: " + $item.SourcePath + " -> " + $outputTarget)
        }
        elseif ($script:SharedState.StopRequested) {
            Update-RowStatus -SourceName $item.SourceName -Status "stopped"
            Write-SessionLog -Message ("STOP: " + $item.SourcePath + " -> " + $outputTarget + " | FFmpeg exit code: " + $result.ExitCode)
        }
        else {
            Update-RowStatus -SourceName $item.SourceName -Status "failed"
            Write-SessionLog -Message ("FAIL: " + $item.SourcePath + " -> " + $outputTarget + " | FFmpeg exit code: " + $result.ExitCode)
        }
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        if ($script:SharedState.StopRequested) {
            Update-RowStatus -SourceName $item.SourceName -Status "stopped"
            Write-SessionLog -Message ("STOP: " + $item.SourcePath + " -> " + $outputTarget + " | " + $message)
        }
        else {
            Update-RowStatus -SourceName $item.SourceName -Status "failed"
            Write-SessionLog -Message ("FAIL: " + $item.SourcePath + " -> " + $outputTarget + " | " + $message)
        }
    }
    finally {
        $script:CurrentProcess = $null
        $script:CurrentPlanItem = $null
    }

    if ($script:SharedState.StopRequested) {
        Mark-RemainingQueuedItemsStopped
        Finish-BatchSession
        return
    }

    if ($null -ne $script:BatchContext -and $script:BatchContext.PauseRequested -and (Test-HasQueuedPlanItems)) {
        [void](Enter-BatchPausedState)
        return
    }

    [void](Start-NextQueuedItem)
}

function Start-BatchSession {
    param(
        [Parameter(Mandatory = $true)]
        $Settings
    )

    Set-StatusText "FFmpeg preflight provera..."
    $preflight = Test-VhsMp4FfmpegPreflight -FfmpegPath $Settings.FfmpegPath
    if (-not $preflight.Ready) {
        throw $preflight.Message
    }
    Add-LogLine "FFmpeg preflight OK."

    $context = New-VhsMp4RunContext `
        -InputDir $Settings.InputDir `
        -OutputDir $Settings.OutputDir `
        -QualityMode $Settings.QualityMode `
        -Crf $Settings.Crf `
        -Preset $Settings.Preset `
        -AudioBitrate $Settings.AudioBitrate `
        -VideoBitrate $Settings.VideoBitrate `
        -FfmpegPath $Settings.FfmpegPath `
        -SplitOutput:([bool]$Settings.SplitOutput) `
        -MaxPartGb $Settings.MaxPartGb `
        -Deinterlace $Settings.Deinterlace `
        -Denoise $Settings.Denoise `
        -RotateFlip $Settings.RotateFlip `
        -ScaleMode $Settings.ScaleMode `
        -AudioNormalize:([bool]$Settings.AudioNormalize) `
        -EncoderMode ([string]$Settings.EncoderMode) `
        -EncoderInventory $script:EncoderInventory
    $context | Add-Member -NotePropertyName "WorkflowPresetName" -NotePropertyValue ([string]$Settings.WorkflowPresetName) -Force

    $plan = if ($script:PlanItems.Count -gt 0) {
        @($script:PlanItems)
    }
    else {
        @(Get-VhsMp4Plan -InputDir $context.InputDir -OutputDir $context.OutputDir -FfmpegPath $context.FfmpegPath -SplitOutput:([bool]$context.SplitOutput))
    }
    $plan = @(Add-PlanEstimates -Plan $plan)
    $plan = @(Invoke-BatchAutoApplyCrop -Items $plan -Enabled:([bool]$Settings.AutoApplyCrop))
    Set-GridRows -Plan $plan
    $script:LastReportPath = $null
    if (@($plan | Where-Object { $_.Status -eq "queued" }).Count -eq 0) {
        $script:LastLogPath = $context.LogPath
        $script:LastReportPath = Write-VhsMp4CustomerReport `
            -OutputDir $context.OutputDir `
            -Items $script:PlanItems `
            -QualityMode $context.QualityMode `
            -Crf $context.Crf `
            -Preset $context.Preset `
            -AudioBitrate $context.AudioBitrate `
            -VideoBitrate $context.VideoBitrate `
            -SplitOutput ([bool]$context.SplitOutput) `
            -MaxPartGb $context.MaxPartGb `
            -FilterSummary $context.FilterSummary `
            -WorkflowPresetName ([string]$context.WorkflowPresetName)
        Set-StatusText "Nema queued fajlova za obradu. IZVESTAJ.txt je spreman."
        Update-ActionButtons
        return
    }

    $script:SharedState.StopRequested = $false
    $script:SharedState.CurrentProcessId = $null
    $script:CurrentProcess = $null
    $script:CurrentPlanItem = $null
    $script:CurrentBatchIndex = -1
    $script:LastLogPath = $context.LogPath
    $logTextBox.Clear()

    $script:BatchContext = [pscustomobject]@{
        Context = $context
        PauseRequested = $false
        Paused = $false
    }

    Write-SessionLog -Message ("InputDir: " + $context.InputDir)
    Write-SessionLog -Message ("OutputDir: " + $context.OutputDir)
    if (-not [string]::IsNullOrWhiteSpace([string]$context.WorkflowPresetName)) {
        Write-SessionLog -Message ("WorkflowPreset: " + [string]$context.WorkflowPresetName)
    }
    $videoBitrateLogText = if (-not [string]::IsNullOrWhiteSpace([string]$context.VideoBitrate)) { [string]$context.VideoBitrate } else { "auto/CRF" }
    Write-SessionLog -Message ("QualityMode: " + $context.QualityMode + " | CRF: " + $context.Crf + " | Preset: " + $context.Preset + " | VideoBitrate: " + $videoBitrateLogText + " | AudioBitrate: " + $context.AudioBitrate)
    Write-SessionLog -Message ("SplitOutput: " + $context.SplitOutput + " | MaxPartGb: " + $context.MaxPartGb)
    Write-SessionLog -Message ("Encode engine: requested " + [string]$context.EncoderMode + " | using " + [string]$context.ResolvedEncoderMode)
    if (-not [string]::IsNullOrWhiteSpace([string]$context.FilterSummary)) {
        Write-SessionLog -Message ("Filters: " + $context.FilterSummary)
    }
    Write-SessionLog -Message ("FFmpeg: " + $context.FfmpegPath)

    foreach ($item in $script:PlanItems) {
        if ([string]$item.Status -eq "skipped") {
            $outputTarget = Get-PlanOutputTarget -Item $item
            Write-SessionLog -Message ("SKIP: " + $item.SourcePath + " -> " + $outputTarget)
        }
    }

    Set-StatusText "Pokrecem Start Conversion..."
    $script:PollTimer.Start()
    [void](Start-NextQueuedItem)
    Update-ActionButtons
}

function Process-BatchTick {
    if ($null -eq $script:BatchContext) {
        $script:PollTimer.Stop()
        return
    }

    if ($null -eq $script:CurrentProcess) {
        return
    }

    Update-CurrentFileProgress

    if (-not $script:CurrentProcess.HasExited) {
        return
    }

    Complete-CurrentProcess
}

function Register-DragDropTarget {
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.Control]$Control,
        [Parameter(Mandatory = $true)]
        [scriptblock]$DragEnterAction,
        [scriptblock]$DragOverAction,
        [Parameter(Mandatory = $true)]
        [scriptblock]$DragDropAction
    )

    $Control.AllowDrop = $true
    $Control.Add_DragEnter($DragEnterAction)
    if ($DragOverAction) {
        $Control.Add_DragOver($DragOverAction)
    }
    $Control.Add_DragDrop($DragDropAction)

    foreach ($child in $Control.Controls) {
        Register-DragDropTarget -Control $child -DragEnterAction $DragEnterAction -DragOverAction $DragOverAction -DragDropAction $DragDropAction
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Video Converter"
$form.Size = New-Object System.Drawing.Size(1360, 900)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(1260, 820)
$form.KeyPreview = $true

$toolTip = New-Object System.Windows.Forms.ToolTip
$previewAutoTimer = New-Object System.Windows.Forms.Timer
$previewAutoTimer.Interval = $script:PreviewAutoDelayMs
$startupUpdateTimer = New-Object System.Windows.Forms.Timer
$startupUpdateTimer.Interval = 900

$shellLayout = New-Object System.Windows.Forms.TableLayoutPanel
$shellLayout.Dock = "Fill"
$shellLayout.ColumnCount = 1
$shellLayout.RowCount = 2
$shellLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
$shellLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($shellLayout)

$menuStrip = New-Object System.Windows.Forms.MenuStrip
$menuStrip.Dock = "Fill"
$form.MainMenuStrip = $menuStrip
$shellLayout.Controls.Add($menuStrip, 0, 0)

$queueMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$queueMenuItem.Text = "Queue"
$menuStrip.Items.Add($queueMenuItem) | Out-Null

$saveQueueMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$saveQueueMenuItem.Text = "Save Queue"
$queueMenuItem.DropDownItems.Add($saveQueueMenuItem) | Out-Null

$loadQueueMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$loadQueueMenuItem.Text = "Load Queue"
$queueMenuItem.DropDownItems.Add($loadQueueMenuItem) | Out-Null

$queueMenuItem.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$skipSelectedMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$skipSelectedMenuItem.Text = "Skip Selected"
$queueMenuItem.DropDownItems.Add($skipSelectedMenuItem) | Out-Null

$retryFailedMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$retryFailedMenuItem.Text = "Retry Failed"
$queueMenuItem.DropDownItems.Add($retryFailedMenuItem) | Out-Null

$clearCompletedMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$clearCompletedMenuItem.Text = "Clear Completed"
$queueMenuItem.DropDownItems.Add($clearCompletedMenuItem) | Out-Null

$viewMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$viewMenuItem.Text = "View"
$menuStrip.Items.Add($viewMenuItem) | Out-Null

$restoreDefaultLayoutMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreDefaultLayoutMenuItem.Text = "Restore Default Layout"
$viewMenuItem.DropDownItems.Add($restoreDefaultLayoutMenuItem) | Out-Null

$helpMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$helpMenuItem.Text = "Help"
$menuStrip.Items.Add($helpMenuItem) | Out-Null

$installFfmpegMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$installFfmpegMenuItem.Text = "Install FFmpeg"
$helpMenuItem.DropDownItems.Add($installFfmpegMenuItem) | Out-Null

$browseFfmpegMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$browseFfmpegMenuItem.Text = "Browse FFmpeg"
$helpMenuItem.DropDownItems.Add($browseFfmpegMenuItem) | Out-Null

$helpMenuItem.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$aboutMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$aboutMenuItem.Text = "About VHS MP4 Optimizer"
$helpMenuItem.DropDownItems.Add($aboutMenuItem) | Out-Null

$checkForUpdatesMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$checkForUpdatesMenuItem.Text = "Check for Updates"
$helpMenuItem.DropDownItems.Add($checkForUpdatesMenuItem) | Out-Null

$openUserGuideMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$openUserGuideMenuItem.Text = "Open User Guide"
$helpMenuItem.DropDownItems.Add($openUserGuideMenuItem) | Out-Null

$rootLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rootLayout.Dock = "Fill"
$rootLayout.ColumnCount = 1
$rootLayout.RowCount = 1
$rootLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$shellLayout.Controls.Add($rootLayout, 0, 1)

$workspaceSplit = New-Object System.Windows.Forms.SplitContainer
$workspaceSplit.Dock = "Fill"
$workspaceSplit.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$workspaceSplit.IsSplitterFixed = $false
$workspaceSplit.SplitterWidth = 10
$workspaceSplit.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$workspaceSplit.BackColor = [System.Drawing.Color]::Gainsboro
$rootLayout.Controls.Add($workspaceSplit, 0, 0)

$lowerWorkspaceSplit = New-Object System.Windows.Forms.SplitContainer
$lowerWorkspaceSplit.Dock = "Fill"
$lowerWorkspaceSplit.Orientation = [System.Windows.Forms.Orientation]::Horizontal
$lowerWorkspaceSplit.IsSplitterFixed = $false
$lowerWorkspaceSplit.SplitterWidth = 10
$lowerWorkspaceSplit.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$lowerWorkspaceSplit.BackColor = [System.Drawing.Color]::Gainsboro
$workspaceSplit.Panel2.Controls.Add($lowerWorkspaceSplit)

$topWorkspaceLayout = New-Object System.Windows.Forms.TableLayoutPanel
$topWorkspaceLayout.Dock = "Fill"
$topWorkspaceLayout.ColumnCount = 1
$topWorkspaceLayout.RowCount = 3
$topWorkspaceLayout.Padding = New-Object System.Windows.Forms.Padding(12, 10, 12, 8)
$topWorkspaceLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$topWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$topWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$topWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$workspaceSplit.Panel1.Controls.Add($topWorkspaceLayout)

$sourceGroupBox = New-Object System.Windows.Forms.GroupBox
$sourceGroupBox.Text = "Input / Output"
$sourceGroupBox.Dock = "Fill"
$topWorkspaceLayout.Controls.Add($sourceGroupBox, 0, 0)

$sourceLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sourceLayout.Dock = "Fill"
$sourceLayout.ColumnCount = 2
$sourceLayout.RowCount = 1
$sourceLayout.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
$sourceLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$sourceLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$sourceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$sourceGroupBox.Controls.Add($sourceLayout)

$inputFolderPanel = New-Object System.Windows.Forms.TableLayoutPanel
$inputFolderPanel.Dock = "Fill"
$inputFolderPanel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
$inputFolderPanel.ColumnCount = 3
$inputFolderPanel.RowCount = 1
$inputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 82)))
$inputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$inputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 112)))
$inputFolderPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$sourceLayout.Controls.Add($inputFolderPanel, 0, 0)

$inputLabel = New-Object System.Windows.Forms.Label
$inputLabel.Text = "Input folder"
$inputLabel.Anchor = "Left"
$inputLabel.AutoSize = $true
$inputFolderPanel.Controls.Add($inputLabel, 0, 0)

$inputTextBox = New-Object System.Windows.Forms.TextBox
$inputTextBox.Dock = "Fill"
$inputTextBox.Margin = New-Object System.Windows.Forms.Padding(0)
$inputFolderPanel.Controls.Add($inputTextBox, 1, 0)

$browseInputButton = New-Object System.Windows.Forms.Button
$browseInputButton.Text = "Browse..."
$browseInputButton.Anchor = "Left,Top"
$browseInputButton.Margin = New-Object System.Windows.Forms.Padding(0)
$browseInputButton.Size = New-Object System.Drawing.Size(104, 20)
$inputFolderPanel.Controls.Add($browseInputButton, 2, 0)

$inputHelpLabel = New-Object System.Windows.Forms.Label
$inputHelpLabel.Text = "MP4 / AVI / MPG / MOV / MKV ulazi | prevuci folder ili fajlove"
$inputHelpLabel.Visible = $false

$outputFolderPanel = New-Object System.Windows.Forms.TableLayoutPanel
$outputFolderPanel.Dock = "Fill"
$outputFolderPanel.Margin = New-Object System.Windows.Forms.Padding(6, 0, 0, 0)
$outputFolderPanel.ColumnCount = 3
$outputFolderPanel.RowCount = 1
$outputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 82)))
$outputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$outputFolderPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 112)))
$outputFolderPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$sourceLayout.Controls.Add($outputFolderPanel, 1, 0)

$outputLabel = New-Object System.Windows.Forms.Label
$outputLabel.Text = "Output folder"
$outputLabel.Anchor = "Left"
$outputLabel.AutoSize = $true
$outputFolderPanel.Controls.Add($outputLabel, 0, 0)

$outputTextBox = New-Object System.Windows.Forms.TextBox
$outputTextBox.Dock = "Fill"
$outputTextBox.Margin = New-Object System.Windows.Forms.Padding(0)
$outputFolderPanel.Controls.Add($outputTextBox, 1, 0)

$browseOutputButton = New-Object System.Windows.Forms.Button
$browseOutputButton.Text = "Browse..."
$browseOutputButton.Anchor = "Left,Top"
$browseOutputButton.Margin = New-Object System.Windows.Forms.Padding(0)
$browseOutputButton.Size = New-Object System.Drawing.Size(104, 20)
$outputFolderPanel.Controls.Add($browseOutputButton, 2, 0)

$outputHelpLabel = New-Object System.Windows.Forms.Label
$outputHelpLabel.Text = "Podrazumevano: vhs-mp4-output"
$outputHelpLabel.Visible = $false

$ffmpegLabel = New-Object System.Windows.Forms.Label
$ffmpegLabel.Text = "FFmpeg path"
$ffmpegLabel.Anchor = "Left"
$ffmpegLabel.AutoSize = $true

$ffmpegPathTextBox = New-Object System.Windows.Forms.TextBox
$ffmpegPathTextBox.Visible = $false

$browseFfmpegButton = New-Object System.Windows.Forms.Button
$browseFfmpegButton.Text = "Browse FFmpeg"

$installFfmpegButton = New-Object System.Windows.Forms.Button
$installFfmpegButton.Text = "Install FFmpeg"

$ffmpegHelpNoteLabel = New-Object System.Windows.Forms.Label
$ffmpegHelpNoteLabel.Text = "Auto-install pri startu | Help > Install FFmpeg / Browse FFmpeg za rucni fallback"
$ffmpegHelpNoteLabel.Dock = "Fill"
$ffmpegHelpNoteLabel.TextAlign = "MiddleLeft"
$ffmpegHelpNoteLabel.AutoEllipsis = $true

$quickRunGroupBox = New-Object System.Windows.Forms.GroupBox
$quickRunGroupBox.Text = "Quick Setup"
$quickRunGroupBox.Dock = "Fill"
$topWorkspaceLayout.Controls.Add($quickRunGroupBox, 0, 1)

$quickRunLayout = New-Object System.Windows.Forms.TableLayoutPanel
$quickRunLayout.Dock = "Fill"
$quickRunLayout.ColumnCount = 2
$quickRunLayout.RowCount = 1
$quickRunLayout.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 8)
$quickRunLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$quickRunLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
$quickRunGroupBox.Controls.Add($quickRunLayout)

$presetColumnLayout = New-Object System.Windows.Forms.TableLayoutPanel
$presetColumnLayout.Dock = "Fill"
$presetColumnLayout.Margin = New-Object System.Windows.Forms.Padding(0)
$presetColumnLayout.ColumnCount = 1
$presetColumnLayout.RowCount = 4
$presetColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 16)))
$presetColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
$presetColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60)))
$presetColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 0)))
$quickRunLayout.Controls.Add($presetColumnLayout, 0, 0)

$workflowPresetLabel = New-Object System.Windows.Forms.Label
$workflowPresetLabel.Text = "Workflow preset"
$workflowPresetLabel.Anchor = "Left"
$workflowPresetLabel.AutoSize = $true
$workflowPresetLabel.Margin = New-Object System.Windows.Forms.Padding(0)
$presetColumnLayout.Controls.Add($workflowPresetLabel, 0, 0)

$workflowPresetToolbar = New-Object System.Windows.Forms.TableLayoutPanel
$workflowPresetToolbar.Dock = "Fill"
$workflowPresetToolbar.Margin = New-Object System.Windows.Forms.Padding(0)
$workflowPresetToolbar.ColumnCount = 1
$workflowPresetToolbar.RowCount = 1
$workflowPresetToolbar.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$presetColumnLayout.Controls.Add($workflowPresetToolbar, 0, 1)

$workflowPresetFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$workflowPresetFlow.Dock = "Fill"
$workflowPresetFlow.WrapContents = $true
$workflowPresetFlow.AutoSize = $true
$workflowPresetFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$workflowPresetFlow.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
$presetColumnLayout.Controls.Add($workflowPresetFlow, 0, 2)

$workflowPresetComboBox = New-Object System.Windows.Forms.ComboBox
$workflowPresetComboBox.Name = "workflowPresetComboBox"
$workflowPresetComboBox.Dock = "Fill"
$workflowPresetComboBox.DropDownStyle = "DropDownList"
$workflowPresetToolbar.Controls.Add($workflowPresetComboBox, 0, 0)

$savePresetButton = New-Object System.Windows.Forms.Button
$savePresetButton.Text = "Save Preset"
$savePresetButton.AutoSize = $true
$workflowPresetFlow.Controls.Add($savePresetButton)

$deletePresetButton = New-Object System.Windows.Forms.Button
$deletePresetButton.Text = "Delete Preset"
$deletePresetButton.AutoSize = $true
$workflowPresetFlow.Controls.Add($deletePresetButton)

$importPresetButton = New-Object System.Windows.Forms.Button
$importPresetButton.Text = "Import Preset"
$importPresetButton.AutoSize = $true
$workflowPresetFlow.Controls.Add($importPresetButton)

$exportPresetButton = New-Object System.Windows.Forms.Button
$exportPresetButton.Text = "Export Preset"
$exportPresetButton.AutoSize = $true
$workflowPresetFlow.Controls.Add($exportPresetButton)

$presetDescriptionLabel = New-Object System.Windows.Forms.Label
$presetDescriptionLabel.Name = "presetDescriptionLabel"
$presetDescriptionLabel.Dock = "Fill"
$presetDescriptionLabel.AutoEllipsis = $true
$presetDescriptionLabel.Text = "Workflow preset odmah primenjuje opsta batch podesavanja. Rucne izmene prelaze u Custom."
$presetDescriptionLabel.Visible = $false
$presetColumnLayout.Controls.Add($presetDescriptionLabel, 0, 3)

$actionsColumnLayout = New-Object System.Windows.Forms.TableLayoutPanel
$actionsColumnLayout.Dock = "Fill"
$actionsColumnLayout.Margin = New-Object System.Windows.Forms.Padding(0)
$actionsColumnLayout.ColumnCount = 1
$actionsColumnLayout.RowCount = 4
$actionsColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 16)))
$actionsColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$actionsColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$actionsColumnLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$quickRunLayout.Controls.Add($actionsColumnLayout, 1, 0)

$quickActionsLabel = New-Object System.Windows.Forms.Label
$quickActionsLabel.Text = "Quick actions"
$quickActionsLabel.Anchor = "Left"
$quickActionsLabel.AutoSize = $true
$quickActionsLabel.Margin = New-Object System.Windows.Forms.Padding(0)
$actionsColumnLayout.Controls.Add($quickActionsLabel, 0, 0)

$primaryActionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$primaryActionsFlow.Dock = "Fill"
$primaryActionsFlow.WrapContents = $true
$primaryActionsFlow.AutoSize = $true
$primaryActionsFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$primaryActionsFlow.Margin = New-Object System.Windows.Forms.Padding(0)
$actionsColumnLayout.Controls.Add($primaryActionsFlow, 0, 1)

$secondaryActionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$secondaryActionsFlow.Dock = "Fill"
$secondaryActionsFlow.WrapContents = $true
$secondaryActionsFlow.AutoSize = $true
$secondaryActionsFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$secondaryActionsFlow.Margin = New-Object System.Windows.Forms.Padding(0)
$actionsColumnLayout.Controls.Add($secondaryActionsFlow, 0, 2)

$tertiaryActionsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$tertiaryActionsFlow.Dock = "Fill"
$tertiaryActionsFlow.WrapContents = $true
$tertiaryActionsFlow.AutoSize = $true
$tertiaryActionsFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$tertiaryActionsFlow.Margin = New-Object System.Windows.Forms.Padding(0)
$actionsColumnLayout.Controls.Add($tertiaryActionsFlow, 0, 3)

$queueToolbar = New-Object System.Windows.Forms.FlowLayoutPanel
$queueToolbar.Dock = "Fill"
$queueToolbar.WrapContents = $true
$queueToolbar.AutoSize = $false
$queueToolbar.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)

$advancedSettingsGroupBox = New-Object System.Windows.Forms.GroupBox
$advancedSettingsGroupBox.Text = "Advanced Settings"
$advancedSettingsGroupBox.Dock = "Fill"
$advancedSettingsGroupBox.Visible = $true
$topWorkspaceLayout.Controls.Add($advancedSettingsGroupBox, 0, 2)

$advancedSettingsLayout = New-Object System.Windows.Forms.TableLayoutPanel
$advancedSettingsLayout.Dock = "Fill"
$advancedSettingsLayout.AutoScroll = $true
$advancedSettingsLayout.ColumnCount = 1
$advancedSettingsLayout.RowCount = 3
$advancedSettingsLayout.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
$advancedSettingsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$advancedSettingsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$advancedSettingsLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::AutoSize)))
$advancedSettingsGroupBox.Controls.Add($advancedSettingsLayout)

$settingsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$settingsFlow.Dock = "Fill"
$settingsFlow.WrapContents = $true
$settingsFlow.AutoSize = $true
$settingsFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$advancedSettingsLayout.Controls.Add($settingsFlow, 0, 0)

$qualityModeLabel = New-Object System.Windows.Forms.Label
$qualityModeLabel.Text = "Quality mode"
$qualityModeLabel.Width = 80
$qualityModeLabel.TextAlign = "MiddleLeft"
$settingsFlow.Controls.Add($qualityModeLabel)

$qualityModeComboBox = New-Object System.Windows.Forms.ComboBox
$qualityModeComboBox.Width = 235
$qualityModeComboBox.DropDownStyle = "DropDownList"
$qualityModeComboBox.DrawMode = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$qualityModeComboBox.ItemHeight = 20
$qualityModeComboBox.DropDownWidth = 280
[void]$qualityModeComboBox.Items.AddRange((Get-QualityModeComboItems))
$qualityModeComboBox.SelectedItem = "Universal MP4 H.264"
$script:QualityModeLastSelection = "Universal MP4 H.264"
$settingsFlow.Controls.Add($qualityModeComboBox)
$qualityModeComboBox.Add_DrawItem({
    param($sender, $e)

    if ($e.Index -lt 0) {
        return
    }

    $itemText = [string]$sender.Items[$e.Index]
    $e.DrawBackground()

    if ($itemText -eq $script:QualityModeSeparatorLabel) {
        $lineY = $e.Bounds.Top + [int]($e.Bounds.Height / 2)
        $separatorPen = New-Object System.Drawing.Pen([System.Drawing.Color]::Silver)
        try {
            $e.Graphics.DrawLine($separatorPen, $e.Bounds.Left + 6, $lineY, $e.Bounds.Right - 6, $lineY)
        }
        finally {
            $separatorPen.Dispose()
        }
    }
    else {
        $textColor = if (($e.State -band [System.Windows.Forms.DrawItemState]::Selected) -eq [System.Windows.Forms.DrawItemState]::Selected) {
            [System.Drawing.SystemColors]::HighlightText
        }
        else {
            [System.Drawing.SystemColors]::ControlText
        }
        $textBrush = New-Object System.Drawing.SolidBrush($textColor)
        try {
            $e.Graphics.DrawString($itemText, $e.Font, $textBrush, [float]($e.Bounds.Left + 4), [float]($e.Bounds.Top + 2))
        }
        finally {
            $textBrush.Dispose()
        }
    }

    $e.DrawFocusRectangle()
})

$crfLabel = New-Object System.Windows.Forms.Label
$crfLabel.Text = "CRF"
$crfLabel.Width = 30
$crfLabel.Margin = New-Object System.Windows.Forms.Padding(16, 6, 3, 3)
$settingsFlow.Controls.Add($crfLabel)

$crfTextBox = New-Object System.Windows.Forms.TextBox
$crfTextBox.Width = 50
$crfTextBox.Text = "22"
$settingsFlow.Controls.Add($crfTextBox)

$crfHelpLabel = New-Object System.Windows.Forms.Label
$crfHelpLabel.Text = "CRF vodic"
$crfHelpLabel.Width = 62
$crfHelpLabel.TextAlign = "MiddleLeft"
$crfHelpLabel.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 3)
$settingsFlow.Controls.Add($crfHelpLabel)

$crfHelpText = "CRF: 18-20 bolji | 22 normal | 24-26 manji. CRF vodic: manji CRF = bolji kvalitet i veci fajl. 18-20 odlican kvalitet; 22 preporuceno; 24-26 manji fajl; 28+ nizi kvalitet."
$toolTip.SetToolTip($crfLabel, $crfHelpText)
$toolTip.SetToolTip($crfTextBox, $crfHelpText)
$toolTip.SetToolTip($crfHelpLabel, $crfHelpText)

$presetLabel = New-Object System.Windows.Forms.Label
$presetLabel.Text = "Preset"
$presetLabel.Width = 45
$presetLabel.Margin = New-Object System.Windows.Forms.Padding(16, 6, 3, 3)
$settingsFlow.Controls.Add($presetLabel)

$presetComboBox = New-Object System.Windows.Forms.ComboBox
$presetComboBox.Width = 105
$presetComboBox.DropDownStyle = "DropDownList"
[void]$presetComboBox.Items.AddRange(@("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"))
$presetComboBox.SelectedItem = "slow"
$settingsFlow.Controls.Add($presetComboBox)

$audioLabel = New-Object System.Windows.Forms.Label
$audioLabel.Text = "Audio bitrate"
$audioLabel.Width = 75
$audioLabel.Margin = New-Object System.Windows.Forms.Padding(16, 6, 3, 3)
$settingsFlow.Controls.Add($audioLabel)

$audioTextBox = New-Object System.Windows.Forms.TextBox
$audioTextBox.Width = 70
$audioTextBox.Text = "160k"
$settingsFlow.Controls.Add($audioTextBox)

$videoBitrateLabel = New-Object System.Windows.Forms.Label
$videoBitrateLabel.Text = "Video bitrate"
$videoBitrateLabel.Width = 82
$videoBitrateLabel.Margin = New-Object System.Windows.Forms.Padding(16, 6, 3, 3)
$settingsFlow.Controls.Add($videoBitrateLabel)

$videoBitrateTextBox = New-Object System.Windows.Forms.TextBox
$videoBitrateTextBox.Name = "videoBitrateTextBox"
$videoBitrateTextBox.Width = 74
$videoBitrateTextBox.Text = ""
$settingsFlow.Controls.Add($videoBitrateTextBox)

$videoBitrateHelpText = "Video bitrate je opcion override. Ostavi prazno za CRF/Quality mode. Primer: 4500k."
$toolTip.SetToolTip($videoBitrateLabel, $videoBitrateHelpText)
$toolTip.SetToolTip($videoBitrateTextBox, $videoBitrateHelpText)

$splitOutputCheckBox = New-Object System.Windows.Forms.CheckBox
$splitOutputCheckBox.Text = "Split output"
$splitOutputCheckBox.Width = 92
$splitOutputCheckBox.Margin = New-Object System.Windows.Forms.Padding(16, 3, 3, 3)
$settingsFlow.Controls.Add($splitOutputCheckBox)

$maxPartGbLabel = New-Object System.Windows.Forms.Label
$maxPartGbLabel.Text = "Max part GB"
$maxPartGbLabel.Width = 78
$maxPartGbLabel.Margin = New-Object System.Windows.Forms.Padding(16, 6, 3, 3)
$settingsFlow.Controls.Add($maxPartGbLabel)

$maxPartGbTextBox = New-Object System.Windows.Forms.TextBox
$maxPartGbTextBox.Width = 55
$maxPartGbTextBox.Text = "3.8"
$maxPartGbTextBox.Enabled = $false
$settingsFlow.Controls.Add($maxPartGbTextBox)

$encoderFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$encoderFlow.Dock = "Fill"
$encoderFlow.WrapContents = $true
$encoderFlow.AutoSize = $true
$encoderFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$advancedSettingsLayout.Controls.Add($encoderFlow, 0, 1)

$encoderModeLabel = New-Object System.Windows.Forms.Label
$encoderModeLabel.Text = "Encode engine"
$encoderModeLabel.Width = 88
$encoderModeLabel.TextAlign = "MiddleLeft"
$encoderFlow.Controls.Add($encoderModeLabel)

$encoderModeComboBox = New-Object System.Windows.Forms.ComboBox
$encoderModeComboBox.Name = "encoderModeComboBox"
$encoderModeComboBox.Width = 172
$encoderModeComboBox.DropDownStyle = "DropDownList"
[void]$encoderModeComboBox.Items.AddRange($script:EncoderModeLabels)
$encoderModeComboBox.SelectedItem = $script:EncoderModeDefaultName
$encoderFlow.Controls.Add($encoderModeComboBox)

$encoderStatusLabel = New-Object System.Windows.Forms.Label
$encoderStatusLabel.Name = "encoderStatusLabel"
$encoderStatusLabel.AutoSize = $true
$encoderStatusLabel.Margin = New-Object System.Windows.Forms.Padding(12, 6, 3, 3)
$encoderStatusLabel.Text = "RuntimeReadyModes: CPU"
$encoderFlow.Controls.Add($encoderStatusLabel)

$filterFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$filterFlow.Dock = "Fill"
$filterFlow.WrapContents = $true
$filterFlow.AutoSize = $true
$filterFlow.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
$advancedSettingsLayout.Controls.Add($filterFlow, 0, 2)

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = "Video filters"
$filterLabel.Width = 80
$filterLabel.TextAlign = "MiddleLeft"
$filterFlow.Controls.Add($filterLabel)

$deinterlaceLabel = New-Object System.Windows.Forms.Label
$deinterlaceLabel.Text = "Deinterlace"
$deinterlaceLabel.Width = 72
$deinterlaceLabel.Margin = New-Object System.Windows.Forms.Padding(0, 6, 3, 3)
$filterFlow.Controls.Add($deinterlaceLabel)

$deinterlaceComboBox = New-Object System.Windows.Forms.ComboBox
$deinterlaceComboBox.Width = 92
$deinterlaceComboBox.DropDownStyle = "DropDownList"
[void]$deinterlaceComboBox.Items.AddRange(@("Off", "YADIF", "YADIF Bob"))
$deinterlaceComboBox.SelectedItem = "Off"
$filterFlow.Controls.Add($deinterlaceComboBox)

$denoiseLabel = New-Object System.Windows.Forms.Label
$denoiseLabel.Text = "Denoise"
$denoiseLabel.Width = 50
$denoiseLabel.Margin = New-Object System.Windows.Forms.Padding(12, 6, 3, 3)
$filterFlow.Controls.Add($denoiseLabel)

$denoiseComboBox = New-Object System.Windows.Forms.ComboBox
$denoiseComboBox.Width = 78
$denoiseComboBox.DropDownStyle = "DropDownList"
[void]$denoiseComboBox.Items.AddRange(@("Off", "Light", "Medium"))
$denoiseComboBox.SelectedItem = "Off"
$filterFlow.Controls.Add($denoiseComboBox)

$rotateFlipLabel = New-Object System.Windows.Forms.Label
$rotateFlipLabel.Text = "Rotate/flip"
$rotateFlipLabel.Width = 66
$rotateFlipLabel.Margin = New-Object System.Windows.Forms.Padding(12, 6, 3, 3)
$filterFlow.Controls.Add($rotateFlipLabel)

$rotateFlipComboBox = New-Object System.Windows.Forms.ComboBox
$rotateFlipComboBox.Width = 118
$rotateFlipComboBox.DropDownStyle = "DropDownList"
[void]$rotateFlipComboBox.Items.AddRange(@("None", "90 CW", "90 CCW", "180", "Horizontal Flip", "Vertical Flip"))
$rotateFlipComboBox.SelectedItem = "None"
$filterFlow.Controls.Add($rotateFlipComboBox)

$scaleModeLabel = New-Object System.Windows.Forms.Label
$scaleModeLabel.Text = "Scale"
$scaleModeLabel.Width = 38
$scaleModeLabel.Margin = New-Object System.Windows.Forms.Padding(12, 6, 3, 3)
$filterFlow.Controls.Add($scaleModeLabel)

$scaleModeComboBox = New-Object System.Windows.Forms.ComboBox
$scaleModeComboBox.Width = 86
$scaleModeComboBox.DropDownStyle = "DropDownList"
[void]$scaleModeComboBox.Items.AddRange(@("Original", "PAL 576p", "720p", "1080p"))
$scaleModeComboBox.SelectedItem = "Original"
$filterFlow.Controls.Add($scaleModeComboBox)

$audioNormalizeCheckBox = New-Object System.Windows.Forms.CheckBox
$audioNormalizeCheckBox.Text = "Audio normalize"
$audioNormalizeCheckBox.Width = 118
$audioNormalizeCheckBox.Margin = New-Object System.Windows.Forms.Padding(12, 3, 3, 3)
$filterFlow.Controls.Add($audioNormalizeCheckBox)

$aspectModeLabel = New-Object System.Windows.Forms.Label
$aspectModeLabel.Text = "Aspect mode"
$aspectModeLabel.Width = 74
$aspectModeLabel.Margin = New-Object System.Windows.Forms.Padding(12, 6, 3, 3)
$filterFlow.Controls.Add($aspectModeLabel)

$aspectModeComboBox = New-Object System.Windows.Forms.ComboBox
$aspectModeComboBox.Name = "aspectModeComboBox"
$aspectModeComboBox.Width = 104
$aspectModeComboBox.DropDownStyle = "DropDownList"
[void]$aspectModeComboBox.Items.AddRange(@("Auto", "Keep Original", "Force 4:3", "Force 16:9"))
$aspectModeComboBox.SelectedItem = "Auto"
$filterFlow.Controls.Add($aspectModeComboBox)

$copyAspectToAllButton = New-Object System.Windows.Forms.Button
$copyAspectToAllButton.Name = "copyAspectToAllButton"
$copyAspectToAllButton.Text = $script:AspectModeBatchActionLabel
$copyAspectToAllButton.AutoSize = $true
$copyAspectToAllButton.Margin = New-Object System.Windows.Forms.Padding(12, 1, 3, 1)
$filterFlow.Controls.Add($copyAspectToAllButton)

$autoApplyCropCheckBox = New-Object System.Windows.Forms.CheckBox
$autoApplyCropCheckBox.Text = "Auto apply crop if detected"
$autoApplyCropCheckBox.Width = 190
$autoApplyCropCheckBox.Margin = New-Object System.Windows.Forms.Padding(12, 3, 3, 3)
$filterFlow.Controls.Add($autoApplyCropCheckBox)

$scanButton = New-Object System.Windows.Forms.Button
$scanButton.Text = "Scan Files"
$scanButton.AutoSize = $true
$primaryActionsFlow.Controls.Add($scanButton)

$sampleButton = New-Object System.Windows.Forms.Button
$sampleButton.Text = "Test Sample"
$sampleButton.AutoSize = $true
$primaryActionsFlow.Controls.Add($sampleButton)

$openPlayerButton = New-Object System.Windows.Forms.Button
$openPlayerButton.Text = "Open Player"
$openPlayerButton.AutoSize = $true
$queueToolbar.Controls.Add($openPlayerButton)

$moveUpButton = New-Object System.Windows.Forms.Button
$moveUpButton.Text = "Move Up"
$moveUpButton.AutoSize = $true
$queueToolbar.Controls.Add($moveUpButton)

$moveDownButton = New-Object System.Windows.Forms.Button
$moveDownButton.Text = "Move Down"
$moveDownButton.AutoSize = $true
$queueToolbar.Controls.Add($moveDownButton)

$skipSelectedButton = New-Object System.Windows.Forms.Button
$skipSelectedButton.Text = "Skip Selected"
$skipSelectedButton.AutoSize = $true
$queueToolbar.Controls.Add($skipSelectedButton)

$retryFailedButton = New-Object System.Windows.Forms.Button
$retryFailedButton.Text = "Retry Failed"
$retryFailedButton.AutoSize = $true
$queueToolbar.Controls.Add($retryFailedButton)

$clearCompletedButton = New-Object System.Windows.Forms.Button
$clearCompletedButton.Text = "Clear Completed"
$clearCompletedButton.AutoSize = $true
$queueToolbar.Controls.Add($clearCompletedButton)

$startButton = New-Object System.Windows.Forms.Button
$startButton.Text = "Start Conversion"
$startButton.AutoSize = $true
$startButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$startButton.ForeColor = [System.Drawing.Color]::White
$startButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$startButton.FlatAppearance.BorderSize = 1
$startButton.UseVisualStyleBackColor = $false
$script:StartButtonActiveBackColor = [System.Drawing.Color]::FromArgb(22, 163, 74)
$script:StartButtonDisabledBackColor = [System.Drawing.Color]::FromArgb(142, 155, 168)
$startButton.BackColor = $script:StartButtonDisabledBackColor
$primaryActionsFlow.Controls.Add($startButton)

$pauseButton = New-Object System.Windows.Forms.Button
$pauseButton.Text = "Pause"
$pauseButton.AutoSize = $true
$pauseButton.Enabled = $false
$secondaryActionsFlow.Controls.Add($pauseButton)

$resumeButton = New-Object System.Windows.Forms.Button
$resumeButton.Text = "Resume"
$resumeButton.AutoSize = $true
$resumeButton.Enabled = $false
$secondaryActionsFlow.Controls.Add($resumeButton)

$stopButton = New-Object System.Windows.Forms.Button
$stopButton.Text = "Stop"
$stopButton.AutoSize = $true
$stopButton.Enabled = $false
$secondaryActionsFlow.Controls.Add($stopButton)

$openOutputButton = New-Object System.Windows.Forms.Button
$openOutputButton.Text = "Open Output"
$openOutputButton.AutoSize = $true
$secondaryActionsFlow.Controls.Add($openOutputButton)

$openLogButton = New-Object System.Windows.Forms.Button
$openLogButton.Text = "Open Log"
$openLogButton.AutoSize = $true
$tertiaryActionsFlow.Controls.Add($openLogButton)

$openReportButton = New-Object System.Windows.Forms.Button
$openReportButton.Text = "Open Report"
$openReportButton.AutoSize = $true
$tertiaryActionsFlow.Controls.Add($openReportButton)

$advancedToggleButton = New-Object System.Windows.Forms.Button
$advancedToggleButton.Text = "Hide Advanced"
$advancedToggleButton.AutoSize = $true
$tertiaryActionsFlow.Controls.Add($advancedToggleButton)

$statusPanel = New-Object System.Windows.Forms.TableLayoutPanel
$statusPanel.Dock = "Fill"
$statusPanel.ColumnCount = 1
$statusPanel.RowCount = 3
$statusPanel.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 8)
$statusPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$statusPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$statusPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))

$statusTitleLabel = New-Object System.Windows.Forms.Label
$statusTitleLabel.Text = "Batch status"
$statusTitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$statusTitleLabel.AutoSize = $true
$statusPanel.Controls.Add($statusTitleLabel, 0, 0)

$statusValueLabel = New-Object System.Windows.Forms.Label
$statusValueLabel.Text = "Scan Files pregleda video fajlove u folderu i podfolderima. Split output pravi validne part001 MP4 delove i ne dira originale."
$statusValueLabel.AutoSize = $false
$statusValueLabel.Dock = "Fill"
$statusValueLabel.TextAlign = "TopLeft"
$statusValueLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$statusValueLabel.MaximumSize = New-Object System.Drawing.Size(0, 0)
$statusPanel.Controls.Add($statusValueLabel, 0, 1)
$script:LastNormalStatusText = $statusValueLabel.Text

$ffmpegStatusPanel = New-Object System.Windows.Forms.FlowLayoutPanel
$ffmpegStatusPanel.Dock = "Fill"
$ffmpegStatusPanel.WrapContents = $false
$statusPanel.Controls.Add($ffmpegStatusPanel, 0, 2)

$ffmpegStatusLabel = New-Object System.Windows.Forms.Label
$ffmpegStatusLabel.Text = "FFmpeg status:"
$ffmpegStatusLabel.AutoSize = $true
$ffmpegStatusPanel.Controls.Add($ffmpegStatusLabel)

$ffmpegStatusValue = New-Object System.Windows.Forms.Label
$ffmpegStatusValue.Text = "Provera u toku..."
$ffmpegStatusValue.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$ffmpegStatusValue.AutoSize = $true
$ffmpegStatusValue.Margin = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$ffmpegStatusPanel.Controls.Add($ffmpegStatusValue)

$ffmpegHintLabel = New-Object System.Windows.Forms.Label
$ffmpegHintLabel.Text = ""
$ffmpegHintLabel.AutoSize = $true
$ffmpegHintLabel.Margin = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
$ffmpegStatusPanel.Controls.Add($ffmpegHintLabel)

$mainSplit = New-Object System.Windows.Forms.SplitContainer
$mainSplit.Dock = "Fill"
$mainSplit.IsSplitterFixed = $false
$mainSplit.SplitterWidth = 10
$mainSplit.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
$mainSplit.BackColor = [System.Drawing.Color]::Gainsboro
$lowerWorkspaceSplit.Panel1.Controls.Add($mainSplit)

$leftWorkspaceLayout = New-Object System.Windows.Forms.TableLayoutPanel
$leftWorkspaceLayout.Dock = "Fill"
$leftWorkspaceLayout.ColumnCount = 1
$leftWorkspaceLayout.RowCount = 2
$leftWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))
$leftWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$mainSplit.Panel1.Controls.Add($leftWorkspaceLayout)
$leftWorkspaceLayout.Controls.Add($queueToolbar, 0, 0)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = "Fill"
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.ReadOnly = $true
$grid.SelectionMode = "FullRowSelect"
$grid.AutoSizeColumnsMode = "DisplayedCells"
$grid.ScrollBars = "Both"
$grid.RowHeadersVisible = $false
[void]$grid.Columns.Add("SourceName", "Source file")
[void]$grid.Columns.Add("OutputName", "Output file")
[void]$grid.Columns.Add("Container", "Container")
[void]$grid.Columns.Add("Resolution", "Resolution")
[void]$grid.Columns.Add("Duration", "Duration")
[void]$grid.Columns.Add("Video", "Video")
[void]$grid.Columns.Add("Audio", "Audio")
[void]$grid.Columns.Add("Bitrate", "Bitrate")
[void]$grid.Columns.Add("Frames", "Frames")
[void]$grid.Columns.Add("Range", "Range")
[void]$grid.Columns.Add("Aspect", "Aspect")
[void]$grid.Columns.Add("Crop", "Crop")
[void]$grid.Columns.Add("EstimatedSize", "Estimate")
[void]$grid.Columns.Add("UsbNote", "USB note")
[void]$grid.Columns.Add("Status", "Status")
$leftWorkspaceLayout.Controls.Add($grid, 0, 1)

$rightPanel = New-Object System.Windows.Forms.TableLayoutPanel
$rightPanel.Dock = "Fill"
$rightPanel.ColumnCount = 1
$rightPanel.RowCount = 3
$rightPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$rightPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
$rightPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$mainSplit.Panel2.Controls.Add($rightPanel)

$previewStatusLabel = New-Object System.Windows.Forms.Label
$previewStatusLabel.Text = "Selected file"
$previewStatusLabel.Dock = "Fill"
$previewStatusLabel.TextAlign = "MiddleLeft"
$previewStatusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$rightPanel.Controls.Add($previewStatusLabel, 0, 0)

$selectedFileSummaryLabel = New-Object System.Windows.Forms.Label
$selectedFileSummaryLabel.Name = "selectedFileSummaryLabel"
$selectedFileSummaryLabel.Dock = "Fill"
$selectedFileSummaryLabel.TextAlign = "MiddleLeft"
$selectedFileSummaryLabel.AutoEllipsis = $true
$selectedFileSummaryLabel.Text = "Izaberi fajl u queue listi pa koristi Open Player za preview, trim, crop i aspect korekciju."
$rightPanel.Controls.Add($selectedFileSummaryLabel, 0, 1)

$outputPlanGroupBox = New-Object System.Windows.Forms.GroupBox
$outputPlanGroupBox.Text = "Input / Planned output"
$outputPlanGroupBox.Dock = "Fill"
$rightPanel.Controls.Add($outputPlanGroupBox, 0, 2)

$outputPlanInfoBox = New-Object System.Windows.Forms.RichTextBox
$outputPlanInfoBox.Dock = "Fill"
$outputPlanInfoBox.ReadOnly = $true
$outputPlanInfoBox.BorderStyle = "None"
$outputPlanInfoBox.BackColor = [System.Drawing.SystemColors]::Window
$outputPlanInfoBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$outputPlanInfoBox.Text = "Planned output`r`n`r`nIzaberi fajl u queue listi da vidis planirani izlaz."
$outputPlanInfoBox.Visible = $false
$outputPlanGroupBox.Controls.Add($outputPlanInfoBox)

$comparisonGrid = New-Object System.Windows.Forms.DataGridView
$comparisonGrid.Dock = "Fill"
$comparisonGrid.AllowUserToAddRows = $false
$comparisonGrid.AllowUserToDeleteRows = $false
$comparisonGrid.AllowUserToResizeRows = $false
$comparisonGrid.ReadOnly = $true
$comparisonGrid.SelectionMode = "FullRowSelect"
$comparisonGrid.MultiSelect = $false
$comparisonGrid.RowHeadersVisible = $false
$comparisonGrid.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::Fill
$comparisonGrid.BackgroundColor = [System.Drawing.SystemColors]::Window
$comparisonGrid.BorderStyle = [System.Windows.Forms.BorderStyle]::None
[void]$comparisonGrid.Columns.Add("PropertyName", "Property")
[void]$comparisonGrid.Columns.Add("InputValue", "Input")
[void]$comparisonGrid.Columns.Add("PlannedValue", "Planned output")
$comparisonGrid.Columns["PropertyName"].AutoSizeMode = [System.Windows.Forms.DataGridViewAutoSizeColumnMode]::None
$comparisonGrid.Columns["PropertyName"].Width = 152
$comparisonGrid.Columns['InputValue'].FillWeight = 50
$comparisonGrid.Columns['PlannedValue'].FillWeight = 50
$outputPlanGroupBox.Controls.Add($comparisonGrid)

$propertiesGroupBox = New-Object System.Windows.Forms.GroupBox
$propertiesGroupBox.Text = "Input / source properties"
$propertiesGroupBox.Visible = $false

$infoBox = New-Object System.Windows.Forms.RichTextBox
$infoBox.Dock = "Fill"
$infoBox.ReadOnly = $true
$infoBox.BorderStyle = "None"
$infoBox.BackColor = [System.Drawing.SystemColors]::Window
$infoBox.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$infoBox.Text = Get-MediaInfoIntroText
$propertiesGroupBox.Controls.Add($infoBox)

$trimTabPage = New-Object System.Windows.Forms.TabPage
$trimTabPage.Text = "Trim"
$trimTabPage.Padding = New-Object System.Windows.Forms.Padding(6)

$propertiesTabPage = New-Object System.Windows.Forms.TabPage
$propertiesTabPage.Text = "Properties"
$propertiesTabPage.Padding = New-Object System.Windows.Forms.Padding(6)

$rightEditorTabControl = New-Object System.Windows.Forms.TabControl
$rightEditorTabControl.Dock = "Fill"
$rightEditorTabControl.TabPages.Add($trimTabPage)
$rightEditorTabControl.TabPages.Add($propertiesTabPage)

$trimGroupBox = New-Object System.Windows.Forms.GroupBox
$trimGroupBox.Text = "Trim selected file"
$trimGroupBox.Dock = "Fill"
$trimTabPage.Controls.Add($trimGroupBox)

$trimLayout = New-Object System.Windows.Forms.TableLayoutPanel
$trimLayout.Dock = "Fill"
$trimLayout.ColumnCount = 4
$trimLayout.RowCount = 4
$trimLayout.Padding = New-Object System.Windows.Forms.Padding(8, 4, 8, 4)
$trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 108)))
$trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 88)))
$trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 104)))
$trimLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))
$trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 26)))
$trimLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$trimGroupBox.Controls.Add($trimLayout)

$trimStartLabel = New-Object System.Windows.Forms.Label
$trimStartLabel.Text = "Start (HH:MM:SS)"
$trimStartLabel.Dock = "Fill"
$trimStartLabel.TextAlign = "MiddleLeft"
$trimStartLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$trimLayout.Controls.Add($trimStartLabel, 0, 0)

$trimStartTextBox = New-Object System.Windows.Forms.TextBox
$trimStartTextBox.Dock = "Fill"
$trimStartTextBox.Margin = New-Object System.Windows.Forms.Padding(0, 4, 8, 0)
$trimLayout.Controls.Add($trimStartTextBox, 1, 0)

$trimEndLabel = New-Object System.Windows.Forms.Label
$trimEndLabel.Text = "End (HH:MM:SS)"
$trimEndLabel.Dock = "Fill"
$trimEndLabel.TextAlign = "MiddleLeft"
$trimEndLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$trimLayout.Controls.Add($trimEndLabel, 2, 0)

$trimEndTextBox = New-Object System.Windows.Forms.TextBox
$trimEndTextBox.Dock = "Fill"
$trimEndTextBox.Margin = New-Object System.Windows.Forms.Padding(0, 4, 0, 0)
$trimLayout.Controls.Add($trimEndTextBox, 3, 0)

$trimButtonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$trimButtonsFlow.Dock = "Fill"
$trimButtonsFlow.WrapContents = $true
$trimButtonsFlow.AutoSize = $false
$trimButtonsFlow.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
$trimLayout.Controls.Add($trimButtonsFlow, 0, 1)
$trimLayout.SetColumnSpan($trimButtonsFlow, 4)

$applyTrimButton = New-Object System.Windows.Forms.Button
$applyTrimButton.Text = "Apply Trim"
$applyTrimButton.AutoSize = $true
$trimButtonsFlow.Controls.Add($applyTrimButton)

$addSegmentButton = New-Object System.Windows.Forms.Button
$addSegmentButton.Text = "Add Segment"
$addSegmentButton.AutoSize = $true
$trimButtonsFlow.Controls.Add($addSegmentButton)

$removeSegmentButton = New-Object System.Windows.Forms.Button
$removeSegmentButton.Text = "Remove"
$removeSegmentButton.AutoSize = $true
$trimButtonsFlow.Controls.Add($removeSegmentButton)

$clearSegmentsButton = New-Object System.Windows.Forms.Button
$clearSegmentsButton.Text = "Clear Seg"
$clearSegmentsButton.AutoSize = $true
$trimButtonsFlow.Controls.Add($clearSegmentsButton)

$clearTrimButton = New-Object System.Windows.Forms.Button
$clearTrimButton.Text = "Clear Trim"
$clearTrimButton.AutoSize = $true
$trimButtonsFlow.Controls.Add($clearTrimButton)

$trimSegmentsListBox = New-Object System.Windows.Forms.ComboBox
$trimSegmentsListBox.Dock = "Fill"
$trimSegmentsListBox.DropDownStyle = "DropDownList"
$trimSegmentsListBox.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
$trimLayout.Controls.Add($trimSegmentsListBox, 0, 2)
$trimLayout.SetColumnSpan($trimSegmentsListBox, 4)

$cutRangeLabel = New-Object System.Windows.Forms.Label
$cutRangeLabel.Text = "CUT: --"
$cutRangeLabel.Dock = "Fill"
$cutRangeLabel.TextAlign = "MiddleLeft"
$cutRangeLabel.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
$cutRangeLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
$trimLayout.Controls.Add($cutRangeLabel, 0, 3)
$trimLayout.SetColumnSpan($cutRangeLabel, 4)

$previewControlsPanel = New-Object System.Windows.Forms.TableLayoutPanel
$previewControlsPanel.Dock = "Fill"
$previewControlsPanel.ColumnCount = 5
$previewControlsPanel.RowCount = 4
$previewControlsPanel.Padding = New-Object System.Windows.Forms.Padding(0, 2, 0, 0)
$previewControlsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 96)))
$previewControlsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 104)))
$previewControlsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$previewControlsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 104)))
$previewControlsPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 92)))
$previewControlsPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$previewControlsPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$previewControlsPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
$previewControlsPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))

$previewWorkspaceLayout = New-Object System.Windows.Forms.TableLayoutPanel
$previewWorkspaceLayout.Dock = "Fill"
$previewWorkspaceLayout.ColumnCount = 1
$previewWorkspaceLayout.RowCount = 3
$previewWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$previewWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 124)))
$previewWorkspaceLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))

$previewTimeLabel = New-Object System.Windows.Forms.Label
$previewTimeLabel.Text = "Preview time"
$previewTimeLabel.Dock = "Fill"
$previewTimeLabel.TextAlign = "MiddleLeft"
$previewTimeLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 4, 0)
$previewControlsPanel.Controls.Add($previewTimeLabel, 0, 0)

$previewTimeTextBox = New-Object System.Windows.Forms.TextBox
$previewTimeTextBox.Dock = "Fill"
$previewTimeTextBox.Text = "00:00:05"
$previewTimeTextBox.Margin = New-Object System.Windows.Forms.Padding(0, 3, 6, 0)
$previewControlsPanel.Controls.Add($previewTimeTextBox, 1, 0)

$previewPositionLabel = New-Object System.Windows.Forms.Label
$previewPositionLabel.Text = "00:00:05 / --:--:--"
$previewPositionLabel.Dock = "Fill"
$previewPositionLabel.TextAlign = "MiddleLeft"
$previewPositionLabel.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 0)
$previewControlsPanel.Controls.Add($previewPositionLabel, 2, 0)

$previewFrameButton = New-Object System.Windows.Forms.Button
$previewFrameButton.Text = "Preview Frame"
$previewFrameButton.Dock = "Fill"
$previewFrameButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 6, 2)
$previewControlsPanel.Controls.Add($previewFrameButton, 3, 0)

$openVideoButton = New-Object System.Windows.Forms.Button
$openVideoButton.Text = "Open Video"
$openVideoButton.Dock = "Fill"
$openVideoButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
$previewControlsPanel.Controls.Add($openVideoButton, 4, 0)

$previewTimelineTrackBar = New-Object System.Windows.Forms.TrackBar
$previewTimelineTrackBar.Dock = "Fill"
$previewTimelineTrackBar.Minimum = 0
$previewTimelineTrackBar.Maximum = 1
$previewTimelineTrackBar.Value = 0
$previewTimelineTrackBar.TickStyle = [System.Windows.Forms.TickStyle]::None
$previewTimelineTrackBar.SmallChange = 1
$previewTimelineTrackBar.LargeChange = $script:PreviewTimelineScale
$previewTimelineTrackBar.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0)
$previewControlsPanel.Controls.Add($previewTimelineTrackBar, 0, 1)
$previewControlsPanel.SetColumnSpan($previewTimelineTrackBar, 5)

$previousFrameButton = New-Object System.Windows.Forms.Button
$previousFrameButton.Text = "< Frame"
$previousFrameButton.Dock = "Fill"
$previousFrameButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 6, 2)
$previewControlsPanel.Controls.Add($previousFrameButton, 0, 2)

$nextFrameButton = New-Object System.Windows.Forms.Button
$nextFrameButton.Text = "Frame >"
$nextFrameButton.Dock = "Fill"
$nextFrameButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 6, 2)
$previewControlsPanel.Controls.Add($nextFrameButton, 1, 2)

$autoPreviewCheckBox = New-Object System.Windows.Forms.CheckBox
$autoPreviewCheckBox.Text = "Auto preview"
$autoPreviewCheckBox.Checked = $true
$autoPreviewCheckBox.Dock = "Fill"
$autoPreviewCheckBox.Margin = New-Object System.Windows.Forms.Padding(0, 3, 6, 0)
$previewControlsPanel.Controls.Add($autoPreviewCheckBox, 2, 2)

$setTrimStartButton = New-Object System.Windows.Forms.Button
$setTrimStartButton.Text = "Set Start"
$setTrimStartButton.Dock = "Fill"
$setTrimStartButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 6, 2)
$previewControlsPanel.Controls.Add($setTrimStartButton, 3, 2)

$setTrimEndButton = New-Object System.Windows.Forms.Button
$setTrimEndButton.Text = "Set End"
$setTrimEndButton.Dock = "Fill"
$setTrimEndButton.Margin = New-Object System.Windows.Forms.Padding(0, 2, 0, 2)
$previewControlsPanel.Controls.Add($setTrimEndButton, 4, 2)

$previewCropOverlayLabel = New-Object System.Windows.Forms.Label
$previewCropOverlayLabel.Text = "Crop overlay: --"
$previewCropOverlayLabel.Dock = "Fill"
$previewCropOverlayLabel.TextAlign = "MiddleLeft"
$previewCropOverlayLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
$previewCropOverlayLabel.ForeColor = [System.Drawing.SystemColors]::GrayText
$previewControlsPanel.Controls.Add($previewCropOverlayLabel, 0, 3)
$previewControlsPanel.SetColumnSpan($previewCropOverlayLabel, 5)

$previewMarkersPanel = New-Object System.Windows.Forms.TableLayoutPanel
$previewMarkersPanel.Dock = "Fill"
$previewMarkersPanel.ColumnCount = 3
$previewMarkersPanel.RowCount = 1
$previewMarkersPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 140)))
$previewMarkersPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 140)))
$previewMarkersPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$previewMarkersPanel.Margin = New-Object System.Windows.Forms.Padding(0)

$previewStartMarkerLabel = New-Object System.Windows.Forms.Label
$previewStartMarkerLabel.Text = "Start: --"
$previewStartMarkerLabel.Dock = "Fill"
$previewStartMarkerLabel.TextAlign = "MiddleLeft"
$previewMarkersPanel.Controls.Add($previewStartMarkerLabel, 0, 0)

$previewEndMarkerLabel = New-Object System.Windows.Forms.Label
$previewEndMarkerLabel.Text = "End: --"
$previewEndMarkerLabel.Dock = "Fill"
$previewEndMarkerLabel.TextAlign = "MiddleLeft"
$previewMarkersPanel.Controls.Add($previewEndMarkerLabel, 1, 0)

$previewTrimSummaryLabel = New-Object System.Windows.Forms.Label
$previewTrimSummaryLabel.Text = "CUT: --"
$previewTrimSummaryLabel.Dock = "Fill"
$previewTrimSummaryLabel.TextAlign = "MiddleLeft"
$previewTrimSummaryLabel.Font = New-Object System.Drawing.Font("Consolas", 8)
$previewMarkersPanel.Controls.Add($previewTrimSummaryLabel, 2, 0)

$previewPictureBox = New-Object System.Windows.Forms.PictureBox
$previewPictureBox.Dock = "Fill"
$previewPictureBox.BorderStyle = "FixedSingle"
$previewPictureBox.SizeMode = "Zoom"
$previewPictureBox.BackColor = [System.Drawing.Color]::Black
$previewPictureBox.Add_Paint({
    param($sender, $eventArgs)

    $item = Get-SelectedPlanItem
    if ($null -eq $item) {
        return
    }

    Draw-PreviewCropOverlay -PictureBox $previewPictureBox -EventArgs $eventArgs -Item $item
})
$previewWorkspaceLayout.Controls.Add($previewPictureBox, 0, 0)
$previewWorkspaceLayout.Controls.Add($previewControlsPanel, 0, 1)
$previewWorkspaceLayout.Controls.Add($previewMarkersPanel, 0, 2)

$script:DragDropVisualDefaults = [pscustomobject]@{
    StatusPanelBackColor = $statusPanel.BackColor
    Panel1BackColor = $mainSplit.Panel1.BackColor
    Panel2BackColor = $mainSplit.Panel2.BackColor
    RightPanelBackColor = $rightPanel.BackColor
    GridBackColor = $grid.BackgroundColor
    GridRowsBackColor = $grid.RowsDefaultCellStyle.BackColor
    GridAltRowsBackColor = $grid.AlternatingRowsDefaultCellStyle.BackColor
    StatusTitleForeColor = $statusTitleLabel.ForeColor
    InputHelpForeColor = $inputHelpLabel.ForeColor
    OutputHelpForeColor = $outputHelpLabel.ForeColor
    StatusTitleText = $statusTitleLabel.Text
    InputHelpText = $inputHelpLabel.Text
    OutputHelpText = $outputHelpLabel.Text
}

$grid.Add_SelectionChanged({
    Update-MediaInfoPanel
    Update-PreviewTrimPanel
})

$grid.Add_CellDoubleClick({
    param($sender, $eventArgs)

    if ($eventArgs.RowIndex -lt 0) {
        return
    }

    Open-SelectedPlayerTrimEditor
})

$activityTabControl = New-Object System.Windows.Forms.TabControl
$activityTabControl.Dock = "Fill"
$lowerWorkspaceSplit.Panel2.Controls.Add($activityTabControl)

$statusTabPage = New-Object System.Windows.Forms.TabPage
$statusTabPage.Text = "Status"
$statusTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$activityTabControl.TabPages.Add($statusTabPage)

$progressTabPage = New-Object System.Windows.Forms.TabPage
$progressTabPage.Text = "Progress"
$progressTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$activityTabControl.TabPages.Add($progressTabPage)

$logTabPage = New-Object System.Windows.Forms.TabPage
$logTabPage.Text = "Log"
$logTabPage.Padding = New-Object System.Windows.Forms.Padding(6)
$activityTabControl.TabPages.Add($logTabPage)

$statusTabPage.Controls.Add($statusPanel)

$progressPanel = New-Object System.Windows.Forms.TableLayoutPanel
$progressPanel.Dock = "Fill"
$progressPanel.ColumnCount = 4
$progressPanel.RowCount = 2
$progressPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 170)))
$progressPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$progressPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
$progressPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
$progressPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$progressPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$progressTabPage.Controls.Add($progressPanel)

$totalProgressLabel = New-Object System.Windows.Forms.Label
$totalProgressLabel.Text = "Total progress"
$totalProgressLabel.TextAlign = "MiddleLeft"
$totalProgressLabel.Dock = "Fill"
$progressPanel.Controls.Add($totalProgressLabel, 0, 0)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Dock = "Fill"
$progressBar.Minimum = 0
$progressBar.Maximum = 1
$progressPanel.Controls.Add($progressBar, 1, 0)

$progressLabel = New-Object System.Windows.Forms.Label
$progressLabel.Text = "0 / 0"
$progressLabel.TextAlign = "MiddleRight"
$progressLabel.Dock = "Fill"
$progressPanel.Controls.Add($progressLabel, 2, 0)

$currentFileNameLabel = New-Object System.Windows.Forms.Label
$currentFileNameLabel.Text = "File progress: nema aktivnog fajla"
$currentFileNameLabel.TextAlign = "MiddleLeft"
$currentFileNameLabel.Dock = "Fill"
$progressPanel.Controls.Add($currentFileNameLabel, 0, 1)

$currentFileProgressBar = New-Object System.Windows.Forms.ProgressBar
$currentFileProgressBar.Dock = "Fill"
$currentFileProgressBar.Minimum = 0
$currentFileProgressBar.Maximum = 100
$currentFileProgressBar.Value = 0
$progressPanel.Controls.Add($currentFileProgressBar, 1, 1)

$currentFilePercentLabel = New-Object System.Windows.Forms.Label
$currentFilePercentLabel.Text = "0%"
$currentFilePercentLabel.TextAlign = "MiddleRight"
$currentFilePercentLabel.Dock = "Fill"
$progressPanel.Controls.Add($currentFilePercentLabel, 2, 1)

$currentFileEtaLabel = New-Object System.Windows.Forms.Label
$currentFileEtaLabel.Text = "ETA: --:--:--"
$currentFileEtaLabel.TextAlign = "MiddleRight"
$currentFileEtaLabel.Dock = "Fill"
$progressPanel.Controls.Add($currentFileEtaLabel, 3, 1)

$logTextBox = New-Object System.Windows.Forms.RichTextBox
$logTextBox.Dock = "Fill"
$logTextBox.ReadOnly = $true
$logTextBox.WordWrap = $false
$logTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logTabPage.Controls.Add($logTextBox)

$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog

$browseInputButton.Add_Click({
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $inputTextBox.Text = $folderDialog.SelectedPath
        if ([string]::IsNullOrWhiteSpace($outputTextBox.Text)) {
            $outputTextBox.Text = Join-Path $folderDialog.SelectedPath "vhs-mp4-output"
        }
        Scan-InputFolder
    }
})

$browseOutputButton.Add_Click({
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $outputTextBox.Text = $folderDialog.SelectedPath
        Update-ActionButtons
    }
})

$browseFfmpegButton.Add_Click({
    [void](Prompt-BrowseFfmpeg)
})

$installFfmpegButton.Add_Click({
    Install-FFmpegInteractive
})

$scanButton.Add_Click({
    Scan-InputFolder
})

$sampleButton.Add_Click({
    Invoke-TestSample
})

$advancedToggleButton.Add_Click({
    Set-AdvancedSettingsVisibility -Visible:(-not $script:AdvancedSettingsVisible) -UserInitiated
    Save-WorkflowPresetStartupState
})

$restoreDefaultLayoutMenuItem.Add_Click({
    Restore-DefaultLayout
})

$aboutMenuItem.Add_Click({
    Show-AboutDialog
})

$installFfmpegMenuItem.Add_Click({
    Install-FFmpegInteractive
})

$browseFfmpegMenuItem.Add_Click({
    [void](Prompt-BrowseFfmpeg)
})

$checkForUpdatesMenuItem.Add_Click({
    [void](Invoke-UpdateCheck)
})

$saveQueueMenuItem.Add_Click({
    try {
        [void](Show-SaveQueueDialog)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Save Queue", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$loadQueueMenuItem.Add_Click({
    try {
        [void](Show-LoadQueueDialog)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show((Get-VhsMp4ErrorMessage -ErrorObject $_), "Load Queue", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$skipSelectedMenuItem.Add_Click({
    [void](Skip-SelectedQueuedItem)
})

$retryFailedMenuItem.Add_Click({
    [void](Retry-FailedPlanItems)
})

$clearCompletedMenuItem.Add_Click({
    [void](Clear-CompletedPlanItems)
})

$openUserGuideMenuItem.Add_Click({
    Open-UserGuide
})

$openPlayerButton.Add_Click({
    Open-SelectedPlayerTrimEditor
})

$moveUpButton.Add_Click({
    [void](Move-SelectedQueuedItem -Direction -1)
})

$moveDownButton.Add_Click({
    [void](Move-SelectedQueuedItem -Direction 1)
})

$skipSelectedButton.Add_Click({
    [void](Skip-SelectedQueuedItem)
})

$retryFailedButton.Add_Click({
    [void](Retry-FailedPlanItems)
})

$clearCompletedButton.Add_Click({
    [void](Clear-CompletedPlanItems)
})

$previewFrameButton.Add_Click({
    Invoke-PreviewFrame
})

$openVideoButton.Add_Click({
    Open-SelectedVideo
})

$trimStartTextBox.Add_TextChanged({
    Update-CutRangeDisplay
})

$trimEndTextBox.Add_TextChanged({
    Update-CutRangeDisplay
})

$previewTimeTextBox.Add_Leave({
    Set-PreviewPositionSeconds -Seconds (Get-PreviewPositionSeconds) -RefreshImage:$true
})

$previewTimelineTrackBar.Add_Scroll({
    Set-PreviewPositionSeconds -Seconds ([double]$previewTimelineTrackBar.Value / $script:PreviewTimelineScale) -RefreshImage:$true
})

$previewTimelineTrackBar.Add_MouseUp({
    if (Test-AutoPreviewEnabled) {
        Invoke-PendingAutoPreview
    }
})

$previewAutoTimer.Add_Tick({
    Invoke-PendingAutoPreview
})

$startupUpdateTimer.Add_Tick({
    $startupUpdateTimer.Stop()
    if (Test-ShouldAutoCheckForUpdates) {
        [void](Invoke-UpdateCheck -Silent -Startup)
    }
})

$previousFrameButton.Add_Click({
    Move-PreviewFrame -Direction -1
})

$nextFrameButton.Add_Click({
    Move-PreviewFrame -Direction 1
})

$setTrimStartButton.Add_Click({
    Set-TrimPointFromPreview -Point Start
})

$setTrimEndButton.Add_Click({
    Set-TrimPointFromPreview -Point End
})

$applyTrimButton.Add_Click({
    Apply-SelectedTrim
})

$addSegmentButton.Add_Click({
    Add-TrimSegmentFromFields
})

$removeSegmentButton.Add_Click({
    Remove-SelectedTrimSegment
})

$clearSegmentsButton.Add_Click({
    Clear-SelectedTrimSegments
})

$clearTrimButton.Add_Click({
    Clear-SelectedTrim
})

$trimSegmentsListBox.Add_SelectedIndexChanged({
    Load-SelectedTrimFields
    Update-ActionButtons
})

$autoPreviewCheckBox.Add_CheckedChanged({
    if ($autoPreviewCheckBox.Checked) {
        Request-AutoPreview
    }
    else {
        $script:PreviewAutoPending = $false
        $previewAutoTimer.Stop()
    }
})

$form.Add_KeyDown({
    param($sender, $eventArgs)

    if ($form.ActiveControl -is [System.Windows.Forms.TextBox] -or $form.ActiveControl -is [System.Windows.Forms.ComboBox]) {
        return
    }

    if (Invoke-PreviewKeyboardShortcut -KeyCode $eventArgs.KeyCode -Shift:$eventArgs.Shift -Control:$eventArgs.Control) {
        $eventArgs.SuppressKeyPress = $true
        $eventArgs.Handled = $true
    }
})

$openOutputButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($outputTextBox.Text) -and (Test-Path -LiteralPath $outputTextBox.Text)) {
        Invoke-Item -LiteralPath $outputTextBox.Text
    }
})

$openLogButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($script:LastLogPath) -and (Test-Path -LiteralPath $script:LastLogPath)) {
        Invoke-Item -LiteralPath $script:LastLogPath
    }
})

$openReportButton.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($script:LastReportPath) -and (Test-Path -LiteralPath $script:LastReportPath)) {
        Invoke-Item -LiteralPath $script:LastReportPath
    }
})

$ffmpegPathTextBox.Add_Leave({
    Sync-FfmpegState
})

$workflowPresetComboBox.Add_SelectedIndexChanged({
    if ($script:WorkflowPresetSuppressSelection -or $script:WorkflowPresetApplying) {
        return
    }

    $selectedName = [string]$workflowPresetComboBox.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedName)) {
        return
    }

    if ($selectedName -eq $script:WorkflowPresetCustomName) {
        Set-WorkflowPresetCustomState
        return
    }

    $preset = Find-WorkflowPresetByName -Name $selectedName
    if ($null -eq $preset) {
        Set-WorkflowPresetCustomState
        return
    }

    Apply-WorkflowPresetSettings -Preset $preset
})

$savePresetButton.Add_Click({
    try {
        $selectedName = [string]$workflowPresetComboBox.SelectedItem
        $selectedPreset = Find-WorkflowPresetByName -Name $selectedName
        $defaultName = if ($null -ne $selectedPreset -and [string]$selectedPreset.Kind -eq "User") { [string]$selectedPreset.Name } else { "" }
        $defaultDescription = if ($null -ne $selectedPreset) { [string]$selectedPreset.Description } else { "" }
        $prompt = Show-WorkflowPresetSaveDialog -InitialName $defaultName -InitialDescription $defaultDescription
        if ($null -eq $prompt) {
            return
        }

        if ([string]::IsNullOrWhiteSpace([string]$prompt.Name)) {
            [System.Windows.Forms.MessageBox]::Show("Unesi ime za preset.", "Save Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $existingPreset = Find-WorkflowPresetByName -Name $prompt.Name
        if ($null -ne $existingPreset -and [string]$existingPreset.Kind -eq "BuiltIn") {
            [System.Windows.Forms.MessageBox]::Show("To ime je rezervisano za built-in workflow preset.", "Save Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return
        }

        if ($null -ne $existingPreset -and [string]$existingPreset.Kind -eq "User") {
            $overwriteResponse = [System.Windows.Forms.MessageBox]::Show("Preset sa tim imenom vec postoji. Da ga prepisem?", "Save Preset", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($overwriteResponse -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }

        $savedPreset = Save-WorkflowPreset -Name $prompt.Name -Settings (Get-CurrentWorkflowPresetSettings) -Description $prompt.Description
        Set-StatusText ("Workflow preset sacuvan: " + [string]$savedPreset.Name)
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        [System.Windows.Forms.MessageBox]::Show($message, "Save Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$deletePresetButton.Add_Click({
    try {
        $selectedName = [string]$workflowPresetComboBox.SelectedItem
        if ([string]::IsNullOrWhiteSpace($selectedName) -or $selectedName -eq $script:WorkflowPresetCustomName) {
            return
        }

        $preset = Find-WorkflowPresetByName -Name $selectedName
        if ($null -eq $preset -or [string]$preset.Kind -ne "User") {
            [System.Windows.Forms.MessageBox]::Show("Moze da se obrise samo korisnicki preset.", "Delete Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            return
        }

        $response = [System.Windows.Forms.MessageBox]::Show("Da obrisem preset '" + $selectedName + "'?", "Delete Preset", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($response -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }

        [void](Remove-WorkflowPreset -Name $selectedName)
        Set-StatusText ("Workflow preset obrisan: " + $selectedName)
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        [System.Windows.Forms.MessageBox]::Show($message, "Delete Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$importPresetButton.Add_Click({
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "Workflow preset (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "Import Preset"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    try {
        $importedPreset = Import-WorkflowPresetFromFile -Path $dialog.FileName
        Refresh-WorkflowPresetComboBox -SelectedName ([string]$importedPreset.Name)
        Apply-WorkflowPresetSettings -Preset $importedPreset
        Set-StatusText ("Workflow preset importovan: " + [string]$importedPreset.Name)
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        [System.Windows.Forms.MessageBox]::Show($message, "Import Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$exportPresetButton.Add_Click({
    $presetForExport = Get-WorkflowPresetForExport
    $safeName = ([string]$presetForExport.Name)
    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeName = $safeName.Replace([string]$invalidChar, "-")
    }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = "Workflow preset (*.json)|*.json|All files (*.*)|*.*"
    $dialog.Title = "Export Preset"
    $dialog.FileName = $safeName + ".json"
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    try {
        [void](Export-WorkflowPresetToFile -Preset $presetForExport -Path $dialog.FileName)
        Set-StatusText ("Workflow preset eksportovan: " + $dialog.FileName)
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        [System.Windows.Forms.MessageBox]::Show($message, "Export Preset", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
    }
})

$qualityModeComboBox.Add_SelectedIndexChanged({
    if ($script:WorkflowPresetApplying) {
        return
    }

    $selectedQualityMode = [string]$qualityModeComboBox.SelectedItem
    if ($selectedQualityMode -eq $script:QualityModeSeparatorLabel) {
        $script:WorkflowPresetApplying = $true
        try {
            $qualityModeComboBox.SelectedItem = Get-CurrentQualityModeSelectionLabel
        }
        finally {
            $script:WorkflowPresetApplying = $false
        }
        return
    }

    $resolvedQualityMode = Resolve-QualityModeSelection -QualityMode $selectedQualityMode
    $script:QualityModeLastSelection = [string]$resolvedQualityMode.DisplayName
    $crfTextBox.Text = [string]$resolvedQualityMode.SuggestedCrf
    $audioTextBox.Text = [string]$resolvedQualityMode.SuggestedAudioBitrate
    $presetComboBox.SelectedItem = [string]$resolvedQualityMode.SuggestedPreset
    $videoBitrateTextBox.Text = [string]$resolvedQualityMode.SuggestedVideoBitrate

    Invoke-WorkflowPresetFieldChanged
})

$splitOutputCheckBox.Add_CheckedChanged({
    Update-ActionButtons

    if ($script:WorkflowPresetApplying) {
        return
    }

    if ((-not (Test-BatchRunning)) -and $script:PlanItems.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($inputTextBox.Text) -and (Test-Path -LiteralPath $inputTextBox.Text)) {
        Scan-InputFolder
    }

    Invoke-WorkflowPresetFieldChanged
})

$presetComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$crfTextBox.Add_TextChanged({
    Invoke-WorkflowPresetFieldChanged
})

$audioTextBox.Add_TextChanged({
    Invoke-WorkflowPresetFieldChanged
})

$videoBitrateTextBox.Add_TextChanged({
    Invoke-WorkflowPresetFieldChanged
})

$encoderModeComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$maxPartGbTextBox.Add_TextChanged({
    Invoke-WorkflowPresetFieldChanged
})

$deinterlaceComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$denoiseComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$rotateFlipComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$scaleModeComboBox.Add_SelectedIndexChanged({
    Invoke-WorkflowPresetFieldChanged
})

$aspectModeComboBox.Add_SelectedIndexChanged({
    if ($script:AspectModeControlSync) {
        return
    }

    [void](Set-SelectedPlanItemAspectMode -AspectMode ([string]$aspectModeComboBox.SelectedItem))
})

$copyAspectToAllButton.Add_Click({
    [void](Copy-SelectedAspectModeToAll)
})

$audioNormalizeCheckBox.Add_CheckedChanged({
    Invoke-WorkflowPresetFieldChanged
})

$autoApplyCropCheckBox.Add_CheckedChanged({
    Invoke-WorkflowPresetFieldChanged
})

$startButton.Add_Click({
    try {
        $settings = Get-Settings
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        $response = [System.Windows.Forms.MessageBox]::Show($message + "`r`n`r`nDa pokusam Install FFmpeg sada?", "Start Conversion", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($response -eq [System.Windows.Forms.DialogResult]::Yes) {
            Install-FFmpegInteractive
        }
        return
    }

    try {
        Start-BatchSession -Settings $settings
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        Add-LogLine -Text ("ERROR: " + $message)
        Set-StatusText ("Greska: " + $message)
        Update-ActionButtons
    }
})

$pauseButton.Add_Click({
    [void](Request-BatchPause)
})

$resumeButton.Add_Click({
    [void](Resume-BatchSession)
})

$stopButton.Add_Click({
    $script:SharedState.StopRequested = $true
    if (Test-BatchPaused) {
        Mark-RemainingQueuedItemsStopped
        Finish-BatchSession
        return
    }

    if ($script:SharedState.CurrentProcessId) {
        try {
            Stop-Process -Id $script:SharedState.CurrentProcessId -Force -ErrorAction Stop
            Add-LogLine -Text ("STOP requested for PID " + $script:SharedState.CurrentProcessId)
        }
        catch {
            $message = Get-VhsMp4ErrorMessage -ErrorObject $_
            Add-LogLine -Text ("STOP warning: " + $message)
        }
    }
    Set-StatusText "Zaustavljanje u toku..."
    Update-ActionButtons
})

$script:PollTimer.Add_Tick({
    try {
        Process-BatchTick
    }
    catch {
        $message = Get-VhsMp4ErrorMessage -ErrorObject $_
        Finish-BatchSession -ErrorMessage $message
    }
})

$form.Add_Shown({
    $script:LayoutStateApplying = $true
    try {
        Set-WorkspaceSplitLayout
        Set-LowerWorkspaceSplitLayout
        Set-MainSplitLayout
        Set-DetailsSplitLayout
        Set-AdvancedSettingsVisibility -Visible:$true
        Update-VhsMp4ProcessPathFromEnvironment | Out-Null
        Sync-FfmpegState
        Initialize-WorkflowPresetState
    }
    finally {
        $script:LayoutStateApplying = $false
    }
    Set-WorkspaceSplitLayout
    Set-LowerWorkspaceSplitLayout
    Set-MainSplitLayout
    Set-DetailsSplitLayout
    if (-not [string]::IsNullOrWhiteSpace($script:WorkflowPresetStorageWarning)) {
        Add-LogLine -Text $script:WorkflowPresetStorageWarning
        Set-StatusText $script:WorkflowPresetStorageWarning
    }
    Update-ActionButtons
    Ensure-FfmpegReadyOnStartup
    $startupUpdateTimer.Start()
})

$form.Add_Resize({
    Set-WorkspaceSplitLayout
    Set-LowerWorkspaceSplitLayout
    Set-MainSplitLayout
    Set-DetailsSplitLayout
})

$mainSplit.Add_SplitterMoved({
    if ($script:LayoutStateApplying) {
        return
    }

    $availableWidth = $mainSplit.Width - $mainSplit.SplitterWidth
    if ($availableWidth -gt 0) {
        $script:WorkspaceVerticalSectionRatio = [Math]::Round(($mainSplit.SplitterDistance / $availableWidth), 4)
    }
    Save-WorkflowPresetStartupState
})

$workspaceSplit.Add_SplitterMoved({
    if ($script:LayoutStateApplying) {
        return
    }

    $availableHeight = $workspaceSplit.Height - $workspaceSplit.SplitterWidth
    if ($availableHeight -gt 0) {
        $script:WorkspaceTopSectionRatio = [Math]::Round(($workspaceSplit.SplitterDistance / $availableHeight), 4)
    }
    Save-WorkflowPresetStartupState
})

$lowerWorkspaceSplit.Add_SplitterMoved({
    if ($script:LayoutStateApplying) {
        return
    }

    $availableHeight = $lowerWorkspaceSplit.Height - $lowerWorkspaceSplit.SplitterWidth
    if ($availableHeight -gt 0) {
        $script:WorkspaceMiddleSectionRatio = [Math]::Round(($lowerWorkspaceSplit.SplitterDistance / $availableHeight), 4)
    }
    Save-WorkflowPresetStartupState
})

$dragEnterHandler = {
    param($sender, $eventArgs)

    if ($eventArgs.Data -and $eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        Set-DragDropVisualState -Active
    }
    else {
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        Set-DragDropVisualState -Active:$false
    }
}

$dragOverHandler = {
    param($sender, $eventArgs)

    if ($eventArgs.Data -and $eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy
        Set-DragDropVisualState -Active
    }
    else {
        $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None
        Set-DragDropVisualState -Active:$false
    }
}

$dragDropHandler = {
    param($sender, $eventArgs)

    try {
        Set-DragDropVisualState -Active:$false -KeepCurrentStatus
        if (-not $eventArgs.Data -or -not $eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
            return
        }

        $paths = @($eventArgs.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
        Import-DroppedPaths -Paths $paths
    }
    catch {
        Set-StatusText ("Drop import greska: " + (Get-VhsMp4ErrorMessage -ErrorObject $_))
    }
}

$form.Add_DragLeave({
    Set-DragDropVisualState -Active:$false
})

Register-DragDropTarget -Control $form -DragEnterAction $dragEnterHandler -DragOverAction $dragOverHandler -DragDropAction $dragDropHandler

$form.Add_FormClosing({
    $script:PollTimer.Stop()
    $startupUpdateTimer.Stop()
    $script:SharedState.StopRequested = $true
    try {
        Save-WorkflowPresetStartupState
    }
    catch {
    }
    if ($script:SharedState.CurrentProcessId) {
        try {
            Stop-Process -Id $script:SharedState.CurrentProcessId -Force -ErrorAction Stop
        }
        catch {
        }
    }

    try {
        $script:NotifyIcon.Visible = $false
        $script:NotifyIcon.Dispose()
    }
    catch {
    }
})

[void]$form.ShowDialog()
