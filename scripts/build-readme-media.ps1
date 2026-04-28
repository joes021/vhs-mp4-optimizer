param(
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $repoRoot "docs\media"
}

$outputRoot = [System.IO.Path]::GetFullPath($OutputDir)
$null = New-Item -ItemType Directory -Path $outputRoot -Force

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("vhs-readme-media-" + [guid]::NewGuid().ToString("N"))
$null = New-Item -ItemType Directory -Path $tempRoot -Force

function ConvertTo-PsSingleQuotedLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return "'" + ($Value -replace "'", "''") + "'"
}

function New-DemoPreviewImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        [string]$Subtitle,
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$Accent
    )

    $width = 1280
    $height = 720
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.Clear([System.Drawing.Color]::FromArgb(10, 14, 22))

    $backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0, 0, $width, $height)),
        [System.Drawing.Color]::FromArgb(18, 24, 38),
        [System.Drawing.Color]::FromArgb(5, 8, 14),
        35.0
    )
    $overlayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, $Accent))
    $panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 9, 12, 20))
    $mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(170, 220, 226, 235))
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(245, 248, 250))
    $accentBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210, $Accent))
    $thinPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(95, 255, 255, 255), 1)
    $accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, $Accent), 4)
    $titleFont = New-Object System.Drawing.Font("Segoe UI", 28, [System.Drawing.FontStyle]::Bold)
    $subtitleFont = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Regular)
    $labelFont = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Regular)

    try {
        $graphics.FillRectangle($backgroundBrush, 0, 0, $width, $height)
        $graphics.FillEllipse($overlayBrush, -140, -120, 520, 520)
        $graphics.FillEllipse($overlayBrush, 860, 80, 420, 420)

        $safeRect = New-Object System.Drawing.Rectangle(108, 84, 1064, 552)
        $graphics.FillRectangle($panelBrush, $safeRect)
        $graphics.DrawRectangle($thinPen, $safeRect)

        $innerRect = New-Object System.Drawing.Rectangle(156, 142, 968, 360)
        $graphics.DrawRectangle($accentPen, $innerRect)

        for ($index = 0; $index -lt 18; $index++) {
            $x = 190 + ($index * 52)
            $barHeight = 30 + (($index % 6) * 24)
            $graphics.FillRectangle($accentBrush, $x, 420 - $barHeight, 18, $barHeight)
        }

        $graphics.FillRectangle($mutedBrush, 190, 444, 900, 4)
        $graphics.FillRectangle($accentBrush, 190, 444, 340, 4)

        $graphics.DrawString($Title, $titleFont, $textBrush, 156, 535)
        $graphics.DrawString($Subtitle, $subtitleFont, $mutedBrush, 160, 586)
        $graphics.DrawString("Preview frame", $labelFont, $accentBrush, 170, 154)
        $graphics.DrawString("16:9 | capture sample", $labelFont, $mutedBrush, 926, 154)
    }
    finally {
        $labelFont.Dispose()
        $subtitleFont.Dispose()
        $titleFont.Dispose()
        $accentPen.Dispose()
        $thinPen.Dispose()
        $accentBrush.Dispose()
        $textBrush.Dispose()
        $mutedBrush.Dispose()
        $panelBrush.Dispose()
        $overlayBrush.Dispose()
        $backgroundBrush.Dispose()
        $graphics.Dispose()
        $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bitmap.Dispose()
    }
}

function Get-GuiTemplateText {
    $guiPath = Join-Path $PSScriptRoot "optimize-vhs-mp4-gui.ps1"
    $corePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"
    $guiText = Get-Content -LiteralPath $guiPath -Raw
    $moduleLine = '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"'
    $replacement = '$modulePath = ' + (ConvertTo-PsSingleQuotedLiteral -Value $corePath)
    return $guiText.Replace($moduleLine, $replacement)
}

function Invoke-GuiProbeScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptText,
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $probePath = Join-Path $tempRoot $Name
    Set-Content -LiteralPath $probePath -Value $ScriptText -Encoding UTF8

    $stdoutPath = [System.IO.Path]::ChangeExtension($probePath, ".stdout.txt")
    $stderrPath = [System.IO.Path]::ChangeExtension($probePath, ".stderr.txt")
    $process = Start-Process -FilePath powershell.exe -ArgumentList @(
        "-NoProfile",
        "-STA",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        $probePath
    ) -WorkingDirectory $repoRoot -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

    $stdout = if (Test-Path -LiteralPath $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    if ($process.ExitCode -ne 0) {
        throw ("GUI probe failed: {0}`nSTDOUT:`n{1}`nSTDERR:`n{2}" -f $Name, $stdout, $stderr)
    }
}

function New-GifFromFrames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [Parameter(Mandatory = $true)]
        [string[]]$FramePaths
    )

    $frameLiterals = @($FramePaths | ForEach-Object { ConvertTo-PsSingleQuotedLiteral -Value $_ })
    $pythonScript = @"
from PIL import Image
import sys

output_path = sys.argv[1]
frame_paths = sys.argv[2:]
target_size = (1280, 820)
frames = []

for path in frame_paths:
    image = Image.open(path).convert("RGB")
    image.thumbnail(target_size, Image.LANCZOS)
    canvas = Image.new("RGB", target_size, (13, 18, 28))
    left = (target_size[0] - image.width) // 2
    top = (target_size[1] - image.height) // 2
    canvas.paste(image, (left, top))
    frames.append(canvas)

frames[0].save(
    output_path,
    save_all=True,
    append_images=frames[1:],
    duration=[1200, 1200, 1200],
    loop=0,
    optimize=True,
)
"@

    $pythonScript | python - $OutputPath @FramePaths | Out-Null
}

$mainPreviewImage = Join-Path $tempRoot "preview-main.png"
$playerPreviewImage = Join-Path $tempRoot "preview-player.png"
New-DemoPreviewImage -Path $mainPreviewImage -Title "VHS porodicna arhiva" -Subtitle "Deinterlace, split output i crop pregled u jednom batch toku" -Accent ([System.Drawing.Color]::FromArgb(34, 197, 94))
New-DemoPreviewImage -Path $playerPreviewImage -Title "Player / Trim editor" -Subtitle "Preview mode sa crop, aspect i multi-cut kontrolama" -Accent ([System.Drawing.Color]::FromArgb(59, 130, 246))

$mainOverviewPath = Join-Path $outputRoot "readme-main-overview.png"
$playerTrimPath = Join-Path $outputRoot "readme-player-trim.png"
$batchControlsPath = Join-Path $outputRoot "readme-batch-controls.png"
$workflowGifPath = Join-Path $outputRoot "readme-workflow.gif"

$mainOverviewLiteral = ConvertTo-PsSingleQuotedLiteral -Value $mainOverviewPath
$playerTrimLiteral = ConvertTo-PsSingleQuotedLiteral -Value $playerTrimPath
$batchControlsLiteral = ConvertTo-PsSingleQuotedLiteral -Value $batchControlsPath
$mainPreviewLiteral = ConvertTo-PsSingleQuotedLiteral -Value $mainPreviewImage
$playerPreviewLiteral = ConvertTo-PsSingleQuotedLiteral -Value $playerPreviewImage

$mainProbeShared = @'
function New-DemoMediaInfo {
    param(
        [string]\$Container,
        [string]\$ContainerLongName,
        [double]\$DurationSeconds,
        [string]\$DurationText,
        [string]\$Resolution,
        [string]\$DisplayAspectRatio,
        [string]\$SampleAspectRatio,
        [double]\$FrameRate,
        [string]\$FrameRateText,
        [int]\$FrameCount,
        [string]\$VideoCodec,
        [string]\$VideoBitrateText,
        [string]\$AudioCodec,
        [int]\$AudioChannels,
        [int]\$AudioSampleRateHz,
        [string]\$AudioBitrateText,
        [string]\$OverallBitrateText
    )

    return [pscustomobject]@{
        Container = \$Container
        ContainerLongName = \$ContainerLongName
        DurationSeconds = \$DurationSeconds
        DurationText = \$DurationText
        SizeText = '3.4 GB'
        OverallBitrateText = \$OverallBitrateText
        VideoCodec = \$VideoCodec
        Resolution = \$Resolution
        DisplayAspectRatio = \$DisplayAspectRatio
        SampleAspectRatio = \$SampleAspectRatio
        FrameRate = \$FrameRate
        FrameRateText = \$FrameRateText
        FrameCount = \$FrameCount
        VideoBitrateText = \$VideoBitrateText
        AudioCodec = \$AudioCodec
        AudioChannels = \$AudioChannels
        AudioSampleRateHz = \$AudioSampleRateHz
        AudioBitrateText = \$AudioBitrateText
        VideoSummary = "\$VideoCodec | \$Resolution | \$DisplayAspectRatio | \$FrameRateText"
        AudioSummary = "\$AudioCodec | \$AudioChannels ch | \$AudioSampleRateHz Hz"
    }
}

function Add-DemoGridRow {
    param(
        \$Item
    )

    \$script:PlanItems += \$Item
    \$rowIndex = \$grid.Rows.Add()
    \$row = \$grid.Rows[\$rowIndex]
    \$row.Cells['SourceName'].Value = [string]\$Item.SourceName
    \$row.Cells['OutputName'].Value = [string]\$Item.DisplayOutputName
    \$row.Cells['Container'].Value = [string]\$Item.MediaInfo.Container
    \$row.Cells['Resolution'].Value = [string]\$Item.MediaInfo.Resolution
    \$row.Cells['Duration'].Value = [string]\$Item.MediaInfo.DurationText
    \$row.Cells['Video'].Value = [string]\$Item.MediaInfo.VideoSummary
    \$row.Cells['Audio'].Value = [string]\$Item.MediaInfo.AudioSummary
    \$row.Cells['Bitrate'].Value = [string]\$Item.MediaInfo.OverallBitrateText
    \$row.Cells['Frames'].Value = [string]\$Item.MediaInfo.FrameCount
    \$row.Cells['Range'].Value = Get-PlanItemPropertyText -Item \$Item -Name "TrimSummary" -Default "--"
    \$row.Cells['Aspect'].Value = Get-PlanItemAspectStatusText -Item \$Item
    \$row.Cells['Crop'].Value = Get-PlanItemCropStatusText -Item \$Item
    \$row.Cells['EstimatedSize'].Value = [string]\$Item.EstimatedSize
    \$row.Cells['UsbNote'].Value = [string]\$Item.UsbNote
    \$row.Cells['Status'].Value = [string]\$Item.Status
}

function New-DemoItem {
    param(
        [string]\$SourceName,
        [string]\$SourcePath,
        [string]\$DisplayOutputName,
        \$MediaInfo,
        [string]\$EstimatedSize,
        [string]\$UsbNote,
        [string]\$Status
    )

    \$item = [pscustomobject]@{
        SourceName = \$SourceName
        SourcePath = \$SourcePath
        OutputPath = (Join-Path ([System.IO.Path]::GetDirectoryName(\$SourcePath)) \$DisplayOutputName)
        DisplayOutputName = \$DisplayOutputName
        Status = \$Status
        MediaInfo = \$MediaInfo
        EstimatedSize = \$EstimatedSize
        UsbNote = \$UsbNote
        PreviewPositionSeconds = 12.0
    }

    \$item | Add-Member -NotePropertyName "MediaDetails" -NotePropertyValue (Format-VhsMp4MediaDetails -Item \$item) -Force
    return \$item
}
'@
$mainProbeShared = $mainProbeShared.Replace('\$', '$')

$mainOverviewProbe = $mainProbeShared + @'
\$form.Size = New-Object System.Drawing.Size(1640, 980)
\$form.StartPosition = 'CenterScreen'
\$demoRoot = Join-Path '__TEMP_ROOT__' 'overview'
\$null = New-Item -ItemType Directory -Path \$demoRoot -Force
\$inputPath = Join-Path \$demoRoot 'input'
\$outputPath = Join-Path \$inputPath 'vhs-mp4-output'
\$null = New-Item -ItemType Directory -Path \$inputPath -Force
\$null = New-Item -ItemType Directory -Path \$outputPath -Force

\$inputTextBox.Text = \$inputPath
\$outputTextBox.Text = \$outputPath
\$ffmpegPathTextBox.Text = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'
\$script:ResolvedFfmpegPath = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'
\$ffmpegStatusValue.Text = 'FFmpeg spreman'
\$ffmpegHintLabel.Text = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'

\$firstSource = Join-Path \$inputPath 'Porodica-2001.avi'
\$secondSource = Join-Path \$inputPath 'Svadba-03.mpg'
\$thirdSource = Join-Path \$inputPath 'Proslava-telefon.mp4'
\$null = New-Item -ItemType File -Path \$firstSource -Force
\$null = New-Item -ItemType File -Path \$secondSource -Force
\$null = New-Item -ItemType File -Path \$thirdSource -Force

\$workflowPresetComboBox.SelectedItem = 'VHS cleanup'
\$qualityModeComboBox.SelectedItem = 'Universal MP4 H.264'
\$crfTextBox.Text = '22'
\$presetComboBox.SelectedItem = 'slow'
\$audioTextBox.Text = '160k'
\$deinterlaceComboBox.SelectedItem = 'YADIF'
\$denoiseComboBox.SelectedItem = 'Light'
\$scaleModeComboBox.SelectedItem = 'PAL 576p'
\$splitOutputCheckBox.Checked = \$true
\$maxPartGbTextBox.Enabled = \$true
\$maxPartGbTextBox.Text = '3.8'
\$audioNormalizeCheckBox.Checked = \$true
\$autoApplyCropCheckBox.Checked = \$true

\$item1 = New-DemoItem -SourceName 'Porodica-2001.avi' -SourcePath \$firstSource -DisplayOutputName 'Porodica-2001-part%03d.mp4' -MediaInfo (New-DemoMediaInfo -Container 'avi' -ContainerLongName 'DV AVI' -DurationSeconds 3672.0 -DurationText '01:01:12' -Resolution '720x576' -DisplayAspectRatio '4:3' -SampleAspectRatio '16:15' -FrameRate 25.0 -FrameRateText '25 fps' -FrameCount 91800 -VideoCodec 'dvvideo' -VideoBitrateText '25000 kbps' -AudioCodec 'pcm_s16le' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '1536 kbps' -OverallBitrateText '26536 kbps') -EstimatedSize 'Estimate: 7.4 GB / 3 delova' -UsbNote 'FAT32 rizik -> Split ili exFAT' -Status 'queued'
\$item1 | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'Auto' -Force
\$item1 | Add-Member -NotePropertyName 'PreviewFramePath' -NotePropertyValue '__MAIN_PREVIEW__' -Force
[void](Apply-PlayerTrimStateToItem -Item \$item1 -TrimState ([pscustomobject]@{
    TrimStartText = '00:00:18'
    TrimEndText = '00:57:40'
    PreviewPositionSeconds = 12.0
}))
[void](Apply-PlayerCropStateToItem -Item \$item1 -CropState ([pscustomobject]@{
    CropMode = 'Auto'
    CropLeft = 14
    CropTop = 6
    CropRight = 12
    CropBottom = 28
}))
Update-PlanItemAspectPresentation -Item \$item1

\$item2 = New-DemoItem -SourceName 'Svadba-03.mpg' -SourcePath \$secondSource -DisplayOutputName 'Svadba-03.mp4' -MediaInfo (New-DemoMediaInfo -Container 'mpeg' -ContainerLongName 'MPEG Program Stream' -DurationSeconds 1875.0 -DurationText '00:31:15' -Resolution '720x576' -DisplayAspectRatio '4:3' -SampleAspectRatio '16:15' -FrameRate 25.0 -FrameRateText '25 fps' -FrameCount 46875 -VideoCodec 'mpeg2video' -VideoBitrateText '8000 kbps' -AudioCodec 'ac3' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '256 kbps' -OverallBitrateText '8256 kbps') -EstimatedSize 'Estimate: 1.8 GB' -UsbNote 'OK za FAT32' -Status 'queued'
\$item2 | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'KeepOriginal' -Force
[void](Apply-PlayerTrimStateToItem -Item \$item2 -TrimState ([pscustomobject]@{
    TrimSegments = @(
        [pscustomobject]@{ StartText = '00:00:42'; EndText = '00:05:30' },
        [pscustomobject]@{ StartText = '00:09:10'; EndText = '00:15:18' }
    )
    PreviewPositionSeconds = 42.0
}))
Update-PlanItemAspectPresentation -Item \$item2

\$item3 = New-DemoItem -SourceName 'Proslava-telefon.mp4' -SourcePath \$thirdSource -DisplayOutputName 'Proslava-telefon.mp4' -MediaInfo (New-DemoMediaInfo -Container 'mp4' -ContainerLongName 'MP4' -DurationSeconds 152.0 -DurationText '00:02:32' -Resolution '1920x1080' -DisplayAspectRatio '16:9' -SampleAspectRatio '1:1' -FrameRate 29.97 -FrameRateText '29.97 fps' -FrameCount 4555 -VideoCodec 'h264' -VideoBitrateText '11000 kbps' -AudioCodec 'aac' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '320 kbps' -OverallBitrateText '11320 kbps') -EstimatedSize 'Estimate: 280 MB' -UsbNote 'OK' -Status 'done'
\$item3 | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'KeepOriginal' -Force
Update-PlanItemAspectPresentation -Item \$item3

Add-DemoGridRow -Item \$item1
Add-DemoGridRow -Item \$item2
Add-DemoGridRow -Item \$item3

\$grid.ClearSelection()
\$firstRow = \$grid.Rows[0]
\$firstRow.Selected = \$true
\$grid.CurrentCell = \$firstRow.Cells['SourceName']
\$rightTabControl.SelectedTab = \$previewTabPage
\$previewTimeTextBox.Text = '00:00:12'
Set-PreviewImage -ImagePath '__MAIN_PREVIEW__'
Update-PreviewTrimPanel
Update-MediaInfoPanel
Update-ActionButtons
Set-StatusText 'Scan Files: pronadjeno 3 | queued: 2 | split: ukljucen | USB: 1 FAT32 upozorenje'
\$logTextBox.Text = "Scan Files: 3 fajla u queue-u`r`nPreview spreman za izabrani AVI fajl.`r`nWorkflow preset: VHS cleanup"

\$inputTextBox.Text = 'D:\Klijenti\Porodica VHS'
\$outputTextBox.Text = 'D:\Klijenti\Porodica VHS\vhs-mp4-output'

\$form.Show()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 350
\$bitmap = New-Object System.Drawing.Bitmap(\$form.ClientSize.Width, \$form.ClientSize.Height)
\$form.DrawToBitmap(\$bitmap, (New-Object System.Drawing.Rectangle(0, 0, \$form.ClientSize.Width, \$form.ClientSize.Height)))
\$bitmap.Save('__MAIN_OVERVIEW__', [System.Drawing.Imaging.ImageFormat]::Png)
\$bitmap.Dispose()
\$form.Close()
try { \$script:NotifyIcon.Visible = \$false; \$script:NotifyIcon.Dispose() } catch {}
'@
$mainOverviewProbe = $mainOverviewProbe.Replace('\$', '$')
$mainOverviewProbe = $mainOverviewProbe.Replace('__TEMP_ROOT__', $tempRoot).Replace('__MAIN_PREVIEW__', $mainPreviewImage).Replace('__MAIN_OVERVIEW__', $mainOverviewPath)

$batchControlsProbe = $mainProbeShared + @'
\$form.Size = New-Object System.Drawing.Size(1640, 980)
\$form.StartPosition = 'CenterScreen'
\$demoRoot = Join-Path '__TEMP_ROOT__' 'batch'
\$null = New-Item -ItemType Directory -Path \$demoRoot -Force
\$inputPath = Join-Path \$demoRoot 'input'
\$outputPath = Join-Path \$inputPath 'vhs-mp4-output'
\$null = New-Item -ItemType Directory -Path \$inputPath -Force
\$null = New-Item -ItemType Directory -Path \$outputPath -Force

\$inputTextBox.Text = \$inputPath
\$outputTextBox.Text = \$outputPath
\$ffmpegPathTextBox.Text = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'
\$script:ResolvedFfmpegPath = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'
\$ffmpegStatusValue.Text = 'FFmpeg spreman'
\$ffmpegHintLabel.Text = 'C:\Tools\ffmpeg\bin\ffmpeg.exe'

\$sourceA = Join-Path \$inputPath 'Kaseta-A.avi'
\$sourceB = Join-Path \$inputPath 'Kaseta-B.mpg'
\$sourceC = Join-Path \$inputPath 'Kaseta-C.mov'
\$null = New-Item -ItemType File -Path \$sourceA -Force
\$null = New-Item -ItemType File -Path \$sourceB -Force
\$null = New-Item -ItemType File -Path \$sourceC -Force

\$workflowPresetComboBox.SelectedItem = 'USB standard'
\$qualityModeComboBox.SelectedItem = 'Universal MP4 H.264'
\$crfTextBox.Text = '22'
\$presetComboBox.SelectedItem = 'slow'
\$audioTextBox.Text = '160k'
\$splitOutputCheckBox.Checked = \$true
\$maxPartGbTextBox.Enabled = \$true
\$maxPartGbTextBox.Text = '3.8'
\$aspectModeComboBox.SelectedItem = 'Auto'

\$itemA = New-DemoItem -SourceName 'Kaseta-A.avi' -SourcePath \$sourceA -DisplayOutputName 'Kaseta-A-part%03d.mp4' -MediaInfo (New-DemoMediaInfo -Container 'avi' -ContainerLongName 'DV AVI' -DurationSeconds 4284.0 -DurationText '01:11:24' -Resolution '720x576' -DisplayAspectRatio '4:3' -SampleAspectRatio '16:15' -FrameRate 25.0 -FrameRateText '25 fps' -FrameCount 107100 -VideoCodec 'dvvideo' -VideoBitrateText '25000 kbps' -AudioCodec 'pcm_s16le' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '1536 kbps' -OverallBitrateText '26536 kbps') -EstimatedSize 'Estimate: 8.5 GB / 3 delova' -UsbNote 'FAT32 rizik -> Split ili exFAT' -Status 'done'
\$itemA | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'Auto' -Force
Update-PlanItemAspectPresentation -Item \$itemA

\$itemB = New-DemoItem -SourceName 'Kaseta-B.mpg' -SourcePath \$sourceB -DisplayOutputName 'Kaseta-B.mp4' -MediaInfo (New-DemoMediaInfo -Container 'mpeg' -ContainerLongName 'MPEG Program Stream' -DurationSeconds 2360.0 -DurationText '00:39:20' -Resolution '720x576' -DisplayAspectRatio '4:3' -SampleAspectRatio '16:15' -FrameRate 25.0 -FrameRateText '25 fps' -FrameCount 59000 -VideoCodec 'mpeg2video' -VideoBitrateText '8000 kbps' -AudioCodec 'mp2' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '256 kbps' -OverallBitrateText '8256 kbps') -EstimatedSize 'Estimate: 2.2 GB' -UsbNote 'OK za FAT32' -Status 'queued'
\$itemB | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'Force4x3' -Force
\$itemB | Add-Member -NotePropertyName 'PreviewFramePath' -NotePropertyValue '__MAIN_PREVIEW__' -Force
[void](Apply-PlayerTrimStateToItem -Item \$itemB -TrimState ([pscustomobject]@{
    TrimSegments = @(
        [pscustomobject]@{ StartText = '00:00:35'; EndText = '00:04:12' },
        [pscustomobject]@{ StartText = '00:06:10'; EndText = '00:14:42' },
        [pscustomobject]@{ StartText = '00:20:00'; EndText = '00:28:28' }
    )
    PreviewPositionSeconds = 95.0
}))
[void](Apply-PlayerCropStateToItem -Item \$itemB -CropState ([pscustomobject]@{
    CropMode = 'Manual'
    CropLeft = 8
    CropTop = 6
    CropRight = 8
    CropBottom = 22
}))
Update-PlanItemAspectPresentation -Item \$itemB

\$itemC = New-DemoItem -SourceName 'Kaseta-C.mov' -SourcePath \$sourceC -DisplayOutputName 'Kaseta-C.mp4' -MediaInfo (New-DemoMediaInfo -Container 'mov' -ContainerLongName 'QuickTime / MOV' -DurationSeconds 602.0 -DurationText '00:10:02' -Resolution '1440x1080' -DisplayAspectRatio '16:9' -SampleAspectRatio '4:3' -FrameRate 25.0 -FrameRateText '25 fps' -FrameCount 15050 -VideoCodec 'h264' -VideoBitrateText '12000 kbps' -AudioCodec 'aac' -AudioChannels 2 -AudioSampleRateHz 48000 -AudioBitrateText '256 kbps' -OverallBitrateText '12256 kbps') -EstimatedSize 'Estimate: 910 MB' -UsbNote 'OK' -Status 'queued'
\$itemC | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'Auto' -Force
Update-PlanItemAspectPresentation -Item \$itemC

Add-DemoGridRow -Item \$itemA
Add-DemoGridRow -Item \$itemB
Add-DemoGridRow -Item \$itemC

\$grid.ClearSelection()
\$secondRow = \$grid.Rows[1]
\$secondRow.Selected = \$true
\$grid.CurrentCell = \$secondRow.Cells['SourceName']
\$rightTabControl.SelectedTab = \$trimTabPage
Set-PreviewImage -ImagePath '__MAIN_PREVIEW__'
Update-PreviewTrimPanel
Update-MediaInfoPanel
\$startButton.Enabled = \$false
\$pauseButton.Enabled = \$false
\$resumeButton.Enabled = \$true
\$moveUpButton.Enabled = \$true
\$moveDownButton.Enabled = \$true
\$openPlayerButton.Enabled = \$true
\$sampleButton.Enabled = \$true
Set-StatusText 'Paused'
\$logTextBox.Text = "Pause requested -> current file zavrsen.`r`nBatch je sada u stanju Paused.`r`nQueued fajlovi mogu da se presloze ili dotrim-uju."

\$inputTextBox.Text = 'D:\Isporuka\VHS-serija'
\$outputTextBox.Text = 'D:\Isporuka\VHS-serija\vhs-mp4-output'

\$form.Show()
[System.Windows.Forms.Application]::DoEvents()
Start-Sleep -Milliseconds 350
\$bitmap = New-Object System.Drawing.Bitmap(\$form.ClientSize.Width, \$form.ClientSize.Height)
\$form.DrawToBitmap(\$bitmap, (New-Object System.Drawing.Rectangle(0, 0, \$form.ClientSize.Width, \$form.ClientSize.Height)))
\$bitmap.Save('__BATCH_CONTROLS__', [System.Drawing.Imaging.ImageFormat]::Png)
\$bitmap.Dispose()
\$form.Close()
try { \$script:NotifyIcon.Visible = \$false; \$script:NotifyIcon.Dispose() } catch {}
'@
$batchControlsProbe = $batchControlsProbe.Replace('\$', '$')
$batchControlsProbe = $batchControlsProbe.Replace('__TEMP_ROOT__', $tempRoot).Replace('__MAIN_PREVIEW__', $mainPreviewImage).Replace('__BATCH_CONTROLS__', $batchControlsPath)

$playerDialogPatch = @'
    \$dialog.Add_Shown({
        Start-Sleep -Milliseconds 300
        try {
            if (-not [string]::IsNullOrWhiteSpace([string]\$script:ReadmePlayerPreviewImage) -and (Test-Path -LiteralPath ([string]\$script:ReadmePlayerPreviewImage))) {
                \$img = [System.Drawing.Image]::FromFile([string]\$script:ReadmePlayerPreviewImage)
                if (\$playerPreviewPictureBox.Image) {
                    \$oldImage = \$playerPreviewPictureBox.Image
                    \$playerPreviewPictureBox.Image = \$null
                    \$oldImage.Dispose()
                }
                \$playerPreviewPictureBox.Image = New-Object System.Drawing.Bitmap(\$img)
                \$img.Dispose()
            }
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 150
            \$bitmap = New-Object System.Drawing.Bitmap(\$dialog.ClientSize.Width, \$dialog.ClientSize.Height)
            \$dialog.DrawToBitmap(\$bitmap, (New-Object System.Drawing.Rectangle(0, 0, \$dialog.ClientSize.Width, \$dialog.ClientSize.Height)))
            \$bitmap.Save([string]\$script:ReadmePlayerCaptureImage, [System.Drawing.Imaging.ImageFormat]::Png)
            \$bitmap.Dispose()
        }
        catch {
            Write-Output ('PLAYER_CAPTURE_ERROR: ' + \$_.Exception.Message)
        }
        \$dialog.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        \$dialog.Close()
    })
    if (\$null -ne \$form) {
        [void]\$dialog.ShowDialog(\$form)
    }
    else {
        [void]\$dialog.ShowDialog()
    }
'@
$playerDialogPatch = $playerDialogPatch.Replace('\$', '$')

$playerMainProbe = @'
\$script:ReadmePlayerCaptureImage = '__PLAYER_CAPTURE__'
\$script:ReadmePlayerPreviewImage = '__PLAYER_PREVIEW__'
\$form.Size = New-Object System.Drawing.Size(1400, 900)
\$form.StartPosition = 'CenterScreen'
\$demoRoot = Join-Path '__TEMP_ROOT__' 'player'
\$null = New-Item -ItemType Directory -Path \$demoRoot -Force
\$sourcePath = Join-Path \$demoRoot 'Trim-editor.avi'
\$null = New-Item -ItemType File -Path \$sourcePath -Force

\$mediaInfo = [pscustomobject]@{
    Container = 'avi'
    ContainerLongName = 'DV AVI'
    DurationSeconds = 762.0
    DurationText = '00:12:42'
    SizeText = '2.7 GB'
    OverallBitrateText = '26536 kbps'
    VideoCodec = 'dvvideo'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '16:15'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 19050
    VideoBitrateText = '25000 kbps'
    AudioCodec = 'pcm_s16le'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '1536 kbps'
    VideoSummary = 'dvvideo | 720x576 | 4:3 | 25 fps'
    AudioSummary = 'pcm_s16le | 2 ch | 48000 Hz'
}

\$item = [pscustomobject]@{
    SourceName = 'Trim-editor.avi'
    SourcePath = \$sourcePath
    OutputPath = (Join-Path \$demoRoot 'Trim-editor.mp4')
    DisplayOutputName = 'Trim-editor.mp4'
    Status = 'queued'
    MediaInfo = \$mediaInfo
    EstimatedSize = 'Estimate: 1.4 GB'
    UsbNote = 'OK za FAT32'
    PreviewPositionSeconds = 95.0
}
\$item | Add-Member -NotePropertyName 'AspectMode' -NotePropertyValue 'Force4x3' -Force
\$item | Add-Member -NotePropertyName 'PreviewFramePath' -NotePropertyValue '__PLAYER_PREVIEW__' -Force
[void](Apply-PlayerTrimStateToItem -Item \$item -TrimState ([pscustomobject]@{
    TrimSegments = @(
        [pscustomobject]@{ StartText = '00:00:18'; EndText = '00:01:42' },
        [pscustomobject]@{ StartText = '00:03:05'; EndText = '00:05:20' }
    )
    PreviewPositionSeconds = 95.0
}))
[void](Apply-PlayerCropStateToItem -Item \$item -CropState ([pscustomobject]@{
    CropMode = 'Manual'
    CropLeft = 12
    CropTop = 8
    CropRight = 14
    CropBottom = 24
}))
Update-PlanItemAspectPresentation -Item \$item

\$script:ResolvedFfmpegPath = ''
[void](Open-PlayerTrimWindow -Item \$item)
try { \$script:NotifyIcon.Visible = \$false; \$script:NotifyIcon.Dispose() } catch {}
'@
$playerMainProbe = $playerMainProbe.Replace('\$', '$')
$playerMainProbe = $playerMainProbe.Replace('__TEMP_ROOT__', $tempRoot).Replace('__PLAYER_PREVIEW__', $playerPreviewImage).Replace('__PLAYER_CAPTURE__', $playerTrimPath)

$guiBase = Get-GuiTemplateText
Invoke-GuiProbeScript -ScriptText ($guiBase.Replace("[void]`$form.ShowDialog()", $mainOverviewProbe)) -Name "readme-main-overview-probe.ps1"
Invoke-GuiProbeScript -ScriptText ($guiBase.Replace("[void]`$form.ShowDialog()", $batchControlsProbe)) -Name "readme-batch-controls-probe.ps1"

$dialogPattern = 'if \(\$null -ne \$form\) \{\s+\[void\]\$dialog\.ShowDialog\(\$form\)\s+\}\s+else \{\s+\[void\]\$dialog\.ShowDialog\(\)\s+\}'
$guiWithPlayerHook = [regex]::Replace($guiBase, $dialogPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $playerDialogPatch }, [System.Text.RegularExpressions.RegexOptions]::Singleline)
Invoke-GuiProbeScript -ScriptText ($guiWithPlayerHook.Replace("[void]`$form.ShowDialog()", $playerMainProbe)) -Name "readme-player-trim-probe.ps1"

New-GifFromFrames -OutputPath $workflowGifPath -FramePaths @($mainOverviewPath, $playerTrimPath, $batchControlsPath)

Write-Output ("README media generated in: " + $outputRoot)
