from pathlib import Path
import json
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def ps_quote(path: Path) -> str:
    return str(path).replace("'", "''")


def test_vhs_gui_script_contains_expected_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Add-Type -AssemblyName System.Windows.Forms",
        "Add-Type -AssemblyName System.Drawing",
        "Video Converter",
        "VHS MP4 Optimizer",
        "MP4 / AVI / MPG / MOV / MKV",
        "System.Windows.Forms.Timer",
        "Scan Files",
        "Test Sample",
        "Start Conversion",
        "Pause",
        "Resume",
        "StartButtonActiveBackColor",
        "StartButtonDisabledBackColor",
        "$startButton.UseVisualStyleBackColor = $false",
        "$startButton.ForeColor = [System.Drawing.Color]::White",
        "Stop",
        "Open Output",
        "Open Log",
        "FFmpeg path",
        "Browse FFmpeg",
        "Install FFmpeg",
        "Test-VhsMp4FfmpegPreflight",
        "FFmpeg preflight",
        "Quality mode",
        "Video filters",
        "Deinterlace",
        "Denoise",
        "Rotate/flip",
        "Scale",
        "PAL 576p",
        "Audio normalize",
        "deinterlaceComboBox",
        "denoiseComboBox",
        "rotateFlipComboBox",
        "scaleModeComboBox",
        "audioNormalizeCheckBox",
        "Get-VhsMp4FilterSummary",
        "FilterSummary",
        "-Deinterlace",
        "-Denoise",
        "-RotateFlip",
        "-ScaleMode",
        "-AudioNormalize",
        "Split output",
        "Max part GB",
        "Estimate",
        "USB note",
        "Add-PlanEstimates",
        "Get-VhsMp4EstimatedOutputInfo",
        "Get-VhsMp4SampleOutputPath",
        "Invoke-TestSample",
        "SampleSeconds 120",
        "samples",
        "Write-VhsMp4CustomerReport",
        "IZVESTAJ.txt",
        "System.Media.SystemSounds",
        "System.Windows.Forms.NotifyIcon",
        "BalloonTipTitle",
        "Format-VhsMp4Gigabytes",
        "FAT32",
        "exFAT",
        "Standard VHS",
        "Smaller File",
        "Better Quality",
        "Universal MP4 H.264",
        "Small MP4 H.264",
        "High Quality MP4 H.264",
        "HEVC H.265 Smaller",
        ".mov",
        ".mkv",
        ".wmv",
        ".m2ts",
        ".vob",
        "ProgressBar",
        "File progress",
        "ETA",
        "currentFileProgressBar",
        "currentFilePercentLabel",
        "currentFileEtaLabel",
        "Update-CurrentFileProgress",
        "Get-VhsMp4MediaDurationSeconds",
        "ProgressPath",
        "SplitOutput",
        "MaxPartGb",
        "splitOutputCheckBox",
        "maxPartGbTextBox",
        "part%03d",
        "out_time_ms",
        "DataGridView",
        "EstimatedSize",
        "UsbNote",
        "Container",
        "Resolution",
        "Duration",
        "FPS",
        "Frames",
        "Properties",
        "Media info",
        "Preview / Properties",
        "previewPictureBox",
        "previewTimeTextBox",
        "previewFrameButton",
        "openVideoButton",
        "trimStartTextBox",
        "trimEndTextBox",
        "trimSegmentsListBox",
        "addSegmentButton",
        "removeSegmentButton",
        "clearSegmentsButton",
        "applyTrimButton",
        "clearTrimButton",
        "New-VhsMp4PreviewFrame",
        "Get-VhsMp4TrimWindow",
        "Get-VhsMp4TrimSegments",
        "TrimSummary",
        "Range",
        "Open-SelectedVideo",
        "Invoke-PreviewFrame",
        "Apply-SelectedTrim",
        "Clear-SelectedTrim",
        "Add-TrimSegmentFromFields",
        "Remove-SelectedTrimSegment",
        "Clear-SelectedTrimSegments",
        "Sync-SelectedTrimSegmentsList",
        "AllowDrop = $true",
        "[System.Windows.Forms.DataFormats]::FileDrop",
        "Get-VhsMp4PlanFromPaths",
        "Import-DroppedPaths",
        "Set-DragDropVisualState",
        "Add_DragOver",
        "Add_DragLeave",
        "MediaSummary",
        "MediaDetails",
        "Update-MediaInfoPanel",
        "Get-VhsMp4MediaInfo",
        "DisplayAspectRatio",
        "OverallBitrate",
        "VideoBitrate",
        "AudioBitrate",
        "CurrentProcessId",
        "Start-VhsMp4FileProcess",
        "Complete-VhsMp4FileProcess",
        "CurrentBatchIndex",
        "winget install --id Gyan.FFmpeg.Essentials",
        "Add-VhsMp4DirectoryToUserPath",
        "vhs-mp4-output",
    ]:
        assert token in script, f"missing GUI token: {token}"

    assert "BackgroundWorker" not in script


def test_vhs_gui_reserves_space_for_status_text_above_file_grid() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    top_row = re.search(
        r"\$rootLayout\.RowStyles\.Add\(\(New-Object System\.Windows\.Forms\.RowStyle\(\[System\.Windows\.Forms\.SizeType\]::Absolute, (\d+)\)\)\)",
        script,
    )
    assert top_row, "missing fixed top configuration row"
    assert int(top_row.group(1)) >= 300

    assert script.count("$configLayout.RowStyles.Add") >= 6
    assert script.count("$statusPanel.RowStyles.Add") >= 3
    assert "$configLayout.AutoScroll = $true" in script


def test_vhs_gui_uses_tabbed_right_workspace_for_preview_trim_and_properties() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "$rightPanel.RowCount = 2",
        "$rightTabControl = New-Object System.Windows.Forms.TabControl",
        '$previewTabPage.Text = "Preview"',
        '$trimTabPage.Text = "Trim"',
        '$propertiesTabPage.Text = "Properties"',
        "$rightTabControl.TabPages.Add($previewTabPage)",
        "$rightTabControl.TabPages.Add($trimTabPage)",
        "$rightTabControl.TabPages.Add($propertiesTabPage)",
        "$rightPanel.Controls.Add($rightTabControl, 0, 1)",
        "$previewTabPage.Controls.Add($previewTabLayout)",
        "$trimTabPage.Controls.Add($trimGroupBox)",
        "$propertiesTabPage.Controls.Add($infoBox)",
        "$previewTabLayout.Controls.Add($previewPictureBox, 0, 0)",
        "$previewTabLayout.Controls.Add($previewControlsPanel, 0, 1)",
    ]:
        assert token in script, f"missing tabbed right-workspace token: {token}"

    assert "$rightPanel.Controls.Add($trimGroupBox, 0, 1)" not in script
    assert "$rightPanel.Controls.Add($previewPictureBox, 0, 3)" not in script


def test_vhs_gui_reserves_readable_right_panel_width_and_stable_trim_layout() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "$script:RightPanelTargetWidth = 500",
        "$mainSplit.Panel2MinSize = $script:RightPanelTargetWidth",
        "$mainSplit.FixedPanel = [System.Windows.Forms.FixedPanel]::Panel2",
        "function Set-MainSplitLayout",
        "$form.Add_Shown({",
        "Set-MainSplitLayout",
        "$trimLayout = New-Object System.Windows.Forms.TableLayoutPanel",
        "$trimLayout.ColumnCount = 4",
        "$trimLayout.RowCount = 4",
        "$trimGroupBox.Controls.Add($trimLayout)",
        "$trimLayout.Controls.Add($trimStartLabel, 0, 0)",
        "$trimLayout.Controls.Add($trimStartTextBox, 1, 0)",
        "$trimLayout.Controls.Add($trimEndLabel, 2, 0)",
        "$trimLayout.Controls.Add($trimEndTextBox, 3, 0)",
        "$trimButtonsFlow = New-Object System.Windows.Forms.FlowLayoutPanel",
        "$trimLayout.Controls.Add($trimButtonsFlow, 0, 1)",
        "$trimButtonsFlow.Controls.Add($applyTrimButton)",
        "$trimButtonsFlow.Controls.Add($addSegmentButton)",
        "$trimButtonsFlow.Controls.Add($removeSegmentButton)",
        "$trimButtonsFlow.Controls.Add($clearSegmentsButton)",
        "$trimButtonsFlow.Controls.Add($clearTrimButton)",
        "$trimLayout.Controls.Add($trimSegmentsListBox, 0, 2)",
        "$trimLayout.Controls.Add($cutRangeLabel, 0, 3)",
    ]:
        assert token in script, f"missing stable right-panel UI token: {token}"


def test_vhs_gui_reserves_vertical_space_for_preview_panel() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    root_fixed_rows = [
        int(value)
        for value in re.findall(
            r"\$rootLayout\.RowStyles\.Add\(\(New-Object System\.Windows\.Forms\.RowStyle\(\[System\.Windows\.Forms\.SizeType\]::Absolute, (\d+)\)\)\)",
            script,
        )
    ]
    assert root_fixed_rows == [300, 60, 90]
    assert sum(root_fixed_rows) <= 480

    right_rows = re.findall(
        r"\$rightPanel\.RowStyles\.Add\(\(New-Object System\.Windows\.Forms\.RowStyle\(\[System\.Windows\.Forms\.SizeType\]::(Absolute|Percent), (\d+)\)\)\)",
        script,
    )
    assert right_rows[:2] == [
        ("Absolute", "24"),
        ("Percent", "100"),
    ]

    preview_rows = re.findall(
        r"\$previewTabLayout\.RowStyles\.Add\(\(New-Object System\.Windows\.Forms\.RowStyle\(\[System\.Windows\.Forms\.SizeType\]::(Absolute|Percent), (\d+)\)\)\)",
        script,
    )
    assert preview_rows[:2] == [
        ("Percent", "100"),
        ("Absolute", "96"),
    ]


def test_vhs_gui_has_manual_timeline_frame_and_cut_controls() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "$script:PreviewTimelineScale = 100",
        "$script:PreviewAutoPending = $false",
        "function Update-PreviewTimeline",
        "function Set-PreviewPositionSeconds",
        "function Move-PreviewFrame",
        "function Test-AutoPreviewEnabled",
        "function Request-AutoPreview",
        "function Invoke-PendingAutoPreview",
        "function Set-TrimPointFromPreview",
        "Get-SelectedPreviewDurationSeconds",
        "Get-SelectedPreviewFrameRate",
        "previewControlsPanel",
        "previewAutoTimer",
        "autoPreviewCheckBox",
        "previewTimelineTrackBar",
        "previewPositionLabel",
        "previousFrameButton",
        "nextFrameButton",
        "setTrimStartButton",
        "setTrimEndButton",
        "$previewAutoTimer.Add_Tick({",
        "$autoPreviewCheckBox.Add_CheckedChanged({",
        "$previewTimelineTrackBar.Add_Scroll({",
        "$previewTimelineTrackBar.Add_MouseUp({",
        "$previousFrameButton.Add_Click({",
        "$nextFrameButton.Add_Click({",
        "$setTrimStartButton.Add_Click({",
        "$setTrimEndButton.Add_Click({",
        "Request-AutoPreview",
        "Invoke-PendingAutoPreview",
        "Auto preview",
        "Move-PreviewFrame -Direction -1",
        "Move-PreviewFrame -Direction 1",
        "Set-TrimPointFromPreview -Point Start",
        "Set-TrimPointFromPreview -Point End",
    ]:
        assert token in script, f"missing manual preview timeline token: {token}"


def test_vhs_gui_has_preview_keyboard_shortcuts_cut_display_and_crf_help() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "$form.KeyPreview = $true",
        "function Move-PreviewSeconds",
        "function Invoke-PreviewKeyboardShortcut",
        "$form.Add_KeyDown({",
        "[System.Windows.Forms.Keys]::Left",
        "[System.Windows.Forms.Keys]::Right",
        "[System.Windows.Forms.Keys]::I",
        "[System.Windows.Forms.Keys]::O",
        "[System.Windows.Forms.Keys]::Space",
        "$eventArgs.SuppressKeyPress = $true",
        "$eventArgs.Handled = $true",
        "Move-PreviewFrame -Direction $direction",
        "Move-PreviewSeconds -SecondsDelta ($direction * 1.0)",
        "Move-PreviewSeconds -SecondsDelta ($direction * 10.0)",
        "cutRangeLabel",
        "function Format-CutTimelineMarkerText",
        "function Update-CutRangeDisplay",
        "CUT: [",
        "CRF: 18-20 bolji | 22 normal | 24-26 manji",
        "CRF vodic",
        "manji CRF = bolji kvalitet i veci fajl",
        "18-20 odlican kvalitet",
        "22 preporuceno",
        "24-26 manji fajl",
        "28+ nizi kvalitet",
        "$toolTip = New-Object System.Windows.Forms.ToolTip",
        "$toolTip.SetToolTip($crfTextBox",
    ]:
        assert token in script, f"missing keyboard/cut/CRF token: {token}"


def test_vhs_gui_contains_player_trim_window_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Open Player",
        "Player / Trim",
        "function Copy-PlanItemTrimState",
        "function Apply-PlayerTrimStateToItem",
        "function Test-PlaybackPreferredFormat",
        "function Open-PlayerTrimWindow",
        "function Show-SelectedPlayerTrimWindow",
        "Save to Queue",
        "Playback mode",
        "Preview mode",
        "ElementHost",
        "MediaElement",
        "Play / Pause",
        "Save-PlayerTrimChanges",
    ]:
        assert token in script, f"missing player/trim token: {token}"


def test_vhs_gui_contains_player_trim_crop_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Crop / Overscan",
        "Detect Crop",
        "Auto Crop",
        "Clear Crop",
        "Left",
        "Top",
        "Right",
        "Bottom",
        "Crop: Auto",
        "Crop: Manual",
        "Aspect",
        "Aspect mode",
        "Copy Aspect to All",
        "Detected:",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "function Copy-PlanItemCropState",
        "function Apply-PlayerCropStateToItem",
        "function Clear-PlanItemCropState",
        "Copy-PlanItemCropState",
        "Apply-PlayerCropStateToItem",
        "Clear-PlanItemCropState",
    ]:
        assert token in script, f"missing crop UI token: {token}"


def test_vhs_gui_contains_player_trim_aspect_panel_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Aspect / Pixel shape",
        "playerAspectModeComboBox",
        "Auto",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "Detected:",
        "DisplayAspectRatio",
        "SampleAspectRatio",
        "OutputAspectWidth",
        "OutputAspectHeight",
    ]:
        assert token in script, f"missing player/trim aspect panel token: {token}"


def test_vhs_gui_contains_crop_overlay_and_queue_status_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        '[void]$grid.Columns.Add("Crop", "Crop")',
        '[void]$grid.Columns.Add("Aspect", "Aspect")',
        "Crop overlay",
        "function Get-PlanItemCropStatusText",
        "function Get-PlanItemAspectStatusText",
        "function Get-PreviewCropOverlayText",
        "function Update-PreviewCropOverlay",
        '$row.Cells["Crop"].Value',
        '$row.Cells["Aspect"].Value',
    ]:
        assert token in script, f"missing crop overlay/queue token: {token}"


def test_vhs_gui_contains_queue_aspect_surface_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        '[void]$grid.Columns.Add("Aspect", "Aspect")',
        "Aspect mode",
        "Copy Aspect to All",
        "Detected:",
        "Keep Original",
        "Force 4:3",
        "Force 16:9",
        "function Get-PlanItemAspectStatusText",
        '$row.Cells["Aspect"].Value',
    ]:
        assert token in script, f"missing queue aspect token: {token}"


def test_vhs_gui_contains_main_window_aspect_dropdown_and_copy_to_all_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "aspectModeComboBox",
        "copyAspectToAllButton",
        "function Sync-AspectModeControls",
        "function Set-SelectedPlanItemAspectMode",
        "function Copy-SelectedAspectModeToAll",
        "$aspectModeComboBox.DropDownStyle = \"DropDownList\"",
        "$copyAspectToAllButton.Text = $script:AspectModeBatchActionLabel",
    ]:
        assert token in script, f"missing main-window aspect control token: {token}"


def test_vhs_gui_contains_auto_apply_crop_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Auto apply crop if detected",
        "function Invoke-BatchAutoApplyCrop",
        "AutoApplyCrop",
        "Auto crop primenjen",
        'Invoke-BatchAutoApplyCrop -Items $plan -Enabled:([bool]$Settings.AutoApplyCrop)',
    ]:
        assert token in script, f"missing batch auto-crop token: {token}"


def test_vhs_gui_contains_workflow_preset_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Workflow preset",
        "workflowPresetComboBox",
        "Save Preset",
        "Delete Preset",
        "Import Preset",
        "Export Preset",
        "presetDescriptionLabel",
        "USB standard",
        "Mali fajl",
        "High quality arhiva",
        "HEVC manji fajl",
        "VHS cleanup",
        "Custom",
        "function Get-WorkflowPresetDefinitions",
        "function Get-WorkflowPresetStoragePath",
        "function Import-WorkflowPresetState",
        "function Export-WorkflowPresetState",
        "function Get-CurrentWorkflowPresetSettings",
        "function Apply-WorkflowPresetSettings",
        "function Set-WorkflowPresetCustomState",
        "function Save-WorkflowPreset",
        "function Remove-WorkflowPreset",
        "function Import-WorkflowPresetFromFile",
        "function Export-WorkflowPresetToFile",
        "function Restore-WorkflowPresetStartupState",
        "function Save-WorkflowPresetStartupState",
    ]:
        assert token in script, f"missing workflow preset token: {token}"


def test_vhs_gui_contains_pause_resume_batch_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "Pause",
        "Resume",
        "Paused after current file",
        "Paused",
        "Move Up",
        "Move Down",
        "function Test-BatchPaused",
        "function Test-BatchEditLocked",
        "function Sync-PausedBatchPlanFromCurrentSettings",
        "function Resume-BatchSession",
        "function Move-SelectedQueuedItem",
        "$pauseButton = New-Object System.Windows.Forms.Button",
        "$resumeButton = New-Object System.Windows.Forms.Button",
        "$moveUpButton = New-Object System.Windows.Forms.Button",
        "$moveDownButton = New-Object System.Windows.Forms.Button",
        "$pauseButton.Add_Click({",
        "$resumeButton.Add_Click({",
        "$moveUpButton.Add_Click({",
        "$moveDownButton.Add_Click({",
    ]:
        assert token in script, f"missing pause/resume batch token: {token}"


def test_vhs_gui_workflow_presets_persist_to_appdata_and_recover_from_corrupt_state(tmp_path: Path) -> None:
    storage_root = tmp_path / "appdata"
    export_path = tmp_path / "preset-export.json"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )
    gui_script = gui_script.replace(
        '$preflight = Test-VhsMp4FfmpegPreflight -FfmpegPath $Settings.FfmpegPath',
        "$preflight = [pscustomobject]@{ Ready = $true; Message = 'ok'; ExitCode = 0; StdOut = ''; StdErr = '' }",
    )
    gui_script = gui_script.replace(
        '$preflight = Test-VhsMp4FfmpegPreflight -FfmpegPath $Settings.FfmpegPath',
        "$preflight = [pscustomobject]@{ Ready = $true; Message = 'ok'; ExitCode = 0; StdOut = ''; StdErr = '' }",
    )

    probe = f"""
function Get-WorkflowPresetStorageRoot {{
    return '{ps_quote(storage_root)}'
}}
$defs = @(Get-WorkflowPresetDefinitions)
$settings = [pscustomobject]@{{
    QualityMode = 'HEVC H.265 Smaller'
    Crf = 26
    Preset = 'medium'
    AudioBitrate = '128k'
    Deinterlace = 'YADIF'
    Denoise = 'Light'
    RotateFlip = 'None'
    ScaleMode = 'PAL 576p'
    AudioNormalize = $true
    SplitOutput = $true
    AutoApplyCrop = $true
    MaxPartGb = 3.8
}}
$saved = Save-WorkflowPreset -Name 'Moj USB' -Settings $settings -Description 'Licni preset za USB predaju'
$stateAfterSave = Import-WorkflowPresetState
Export-WorkflowPresetToFile -Preset $saved -Path '{ps_quote(export_path)}'
$exported = Get-Content -LiteralPath '{ps_quote(export_path)}' -Raw | ConvertFrom-Json
Set-Content -LiteralPath (Get-WorkflowPresetStoragePath) -Value '{{bad json' -Encoding UTF8
$fallbackState = Import-WorkflowPresetState
Write-Output 'JSON_START'
[pscustomobject]@{{
    BuiltInCount = @($defs | Where-Object {{ $_.Kind -eq 'BuiltIn' }}).Count
    UserCountAfterSave = @($stateAfterSave.UserPresets).Count
    SavedName = [string]$stateAfterSave.UserPresets[0].Name
    SavedScale = [string]$stateAfterSave.UserPresets[0].Settings.ScaleMode
    SavedAutoApplyCrop = [bool]$stateAfterSave.UserPresets[0].Settings.AutoApplyCrop
    StoragePath = Get-WorkflowPresetStoragePath
    ExportExists = Test-Path -LiteralPath '{ps_quote(export_path)}'
    ExportName = [string]$exported.Name
    ExportAutoApplyCrop = [bool]$exported.Settings.AutoApplyCrop
    FallbackBuiltInCount = @($fallbackState.BuiltInPresets).Count
    FallbackUserCount = @($fallbackState.UserPresets).Count
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-workflow-preset-storage-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["BuiltInCount"] >= 5
    assert payload["UserCountAfterSave"] == 1
    assert payload["SavedName"] == "Moj USB"
    assert payload["SavedScale"] == "PAL 576p"
    assert payload["SavedAutoApplyCrop"] is True
    assert str(storage_root) in payload["StoragePath"]
    assert payload["ExportExists"] is True
    assert payload["ExportName"] == "Moj USB"
    assert payload["ExportAutoApplyCrop"] is True
    assert payload["FallbackBuiltInCount"] >= 5
    assert payload["FallbackUserCount"] == 0


def test_vhs_gui_workflow_preset_apply_custom_state_and_startup_restore(tmp_path: Path) -> None:
    storage_root = tmp_path / "appdata"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )
    gui_script = gui_script.replace(
        '$preflight = Test-VhsMp4FfmpegPreflight -FfmpegPath $Settings.FfmpegPath',
        "$preflight = [pscustomobject]@{ Ready = $true; Message = 'ok'; ExitCode = 0; StdOut = ''; StdErr = '' }",
    )

    probe = f"""
function Get-WorkflowPresetStorageRoot {{
    return '{ps_quote(storage_root)}'
}}
$inputTextBox.Text = 'X:\\ulaz'
$outputTextBox.Text = 'X:\\izlaz'
$ffmpegPathTextBox.Text = 'X:\\ffmpeg.exe'
$script:ResolvedFfmpegPath = 'X:\\ffmpeg.exe'
$usbPreset = @(Get-WorkflowPresetDefinitions | Where-Object {{ $_.Name -eq 'USB standard' }})[0]
Apply-WorkflowPresetSettings -Preset $usbPreset
$afterApply = Get-CurrentWorkflowPresetSettings
$selectedAfterApply = [string]$workflowPresetComboBox.SelectedItem
$descriptionAfterApply = $presetDescriptionLabel.Text
$audioTextBox.Text = '192k'
$autoApplyCropCheckBox.Checked = $true
Set-WorkflowPresetCustomState
$selectedAfterCustom = [string]$workflowPresetComboBox.SelectedItem
$descriptionAfterCustom = $presetDescriptionLabel.Text
Save-WorkflowPresetStartupState
$qualityModeComboBox.SelectedItem = 'Small MP4 H.264'
$crfTextBox.Text = '30'
$audioTextBox.Text = '96k'
$workflowPresetComboBox.SelectedItem = 'Custom'
Restore-WorkflowPresetStartupState
$afterRestore = Get-CurrentWorkflowPresetSettings
Write-Output 'JSON_START'
[pscustomobject]@{{
    SelectedAfterApply = $selectedAfterApply
    DescriptionAfterApply = $descriptionAfterApply
    QualityAfterApply = [string]$afterApply.QualityMode
    SplitAfterApply = [bool]$afterApply.SplitOutput
    AutoApplyCropAfterApply = [bool]$afterApply.AutoApplyCrop
    SelectedAfterCustom = $selectedAfterCustom
    DescriptionAfterCustom = $descriptionAfterCustom
    InputAfterApply = $inputTextBox.Text
    OutputAfterApply = $outputTextBox.Text
    FfmpegAfterApply = $ffmpegPathTextBox.Text
    RestoredPreset = [string]$workflowPresetComboBox.SelectedItem
    RestoredQuality = [string]$afterRestore.QualityMode
    RestoredAudio = [string]$afterRestore.AudioBitrate
    RestoredAutoApplyCrop = [bool]$afterRestore.AutoApplyCrop
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-workflow-preset-custom-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["SelectedAfterApply"] == "USB standard"
    assert "USB" in payload["DescriptionAfterApply"]
    assert payload["QualityAfterApply"] == "Universal MP4 H.264"
    assert payload["SplitAfterApply"] is True
    assert payload["AutoApplyCropAfterApply"] is False
    assert payload["SelectedAfterCustom"] == "Custom"
    assert "Custom" in payload["DescriptionAfterCustom"]
    assert payload["InputAfterApply"] == r"X:\ulaz"
    assert payload["OutputAfterApply"] == r"X:\izlaz"
    assert payload["FfmpegAfterApply"] == r"X:\ffmpeg.exe"
    assert payload["RestoredPreset"] == "Custom"
    assert payload["RestoredQuality"] == "Universal MP4 H.264"
    assert payload["RestoredAudio"] == "192k"
    assert payload["RestoredAutoApplyCrop"] is True


def test_vhs_gui_pause_resume_reorder_and_refresh_remaining_queue(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = tmp_path / "output"
    input_dir.mkdir()
    output_dir.mkdir()
    ffmpeg_stub = tmp_path / "ffmpeg-stub.ps1"
    ffmpeg_stub.write_text(
        "param([string[]]$Args)\nWrite-Output 'ffmpeg version stub'\nexit 0\n",
        encoding="utf-8",
    )

    source_a = input_dir / "a.avi"
    source_b = input_dir / "b.avi"
    source_c = input_dir / "c.avi"
    for source in (source_a, source_b, source_c):
        source.write_text("video", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
function Test-VhsMp4FfmpegPreflight {{
    param([string]$FfmpegPath)
    return [pscustomobject]@{{ Ready = $true; Message = 'ok'; ExitCode = 0; StdOut = ''; StdErr = '' }}
}}

$script:StartCalls = New-Object System.Collections.ArrayList
function Start-VhsMp4FileProcess {{
    param(
        [string]$SourcePath,
        [string]$OutputPath,
        [string]$FfmpegPath,
        [string]$QualityMode,
        [int]$Crf,
        [string]$Preset,
        [string]$AudioBitrate,
        [string]$ProgressPath,
        [bool]$SplitOutput,
        [double]$MaxPartGb,
        [string]$TrimStart,
        [string]$TrimEnd,
        [object[]]$TrimSegments,
        [string]$AspectMode,
        $VideoInfo,
        $CropState,
        [bool]$SourceHasAudio,
        [string]$Deinterlace,
        [string]$Denoise,
        [string]$RotateFlip,
        [string]$ScaleMode,
        [bool]$AudioNormalize,
        $SharedState
    )

    $process = [pscustomobject]@{{
        HasExited = $false
        Id = 1000 + $script:StartCalls.Count
    }}
    $null = $script:StartCalls.Add([pscustomobject]@{{
        SourcePath = $SourcePath
        OutputPath = $OutputPath
        QualityMode = $QualityMode
        Crf = $Crf
        SplitOutput = [bool]$SplitOutput
        MaxPartGb = $MaxPartGb
        ScaleMode = $ScaleMode
    }})
    $SharedState.CurrentProcessId = $process.Id
    return [pscustomobject]@{{ Process = $process }}
}}

function Complete-VhsMp4FileProcess {{
    param($Process, [string]$OutputPath, $SharedState)
    $SharedState.CurrentProcessId = $null
    return [pscustomobject]@{{ Success = $true; ExitCode = 0; StdOut = ''; StdErr = '' }}
}}

$inputTextBox.Text = '{ps_quote(input_dir)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$ffmpegPathTextBox.Text = '{ps_quote(ffmpeg_stub)}'
$script:ResolvedFfmpegPath = '{ps_quote(ffmpeg_stub)}'
$qualityModeComboBox.SelectedItem = 'Universal MP4 H.264'
$crfTextBox.Text = '22'
$presetComboBox.SelectedItem = 'slow'
$audioTextBox.Text = '160k'
$splitOutputCheckBox.Checked = $false
$maxPartGbTextBox.Text = '3.8'
$deinterlaceComboBox.SelectedItem = 'Off'
$denoiseComboBox.SelectedItem = 'Off'
$rotateFlipComboBox.SelectedItem = 'None'
$scaleModeComboBox.SelectedItem = 'Original'
$audioNormalizeCheckBox.Checked = $false
$autoApplyCropCheckBox.Checked = $false

$mediaInfo = [pscustomobject]@{{
    Container = 'avi'
    ContainerLongName = 'AVI'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'dvvideo'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    VideoSummary = 'dvvideo | 720x576 | 4:3 | 25 fps'
    AudioCodec = 'pcm_s16le'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '1536 kbps'
    AudioSummary = 'pcm_s16le | 2 ch | 48000 Hz | 1536 kbps'
}}

$itemA = [pscustomobject]@{{
    SourceName = 'a.avi'
    SourceFileName = 'a.avi'
    RelativeSourcePath = 'a.avi'
    SourcePath = '{ps_quote(source_a)}'
    OutputPath = '{ps_quote(output_dir / "a.mp4")}'
    OutputPattern = '{ps_quote(output_dir / "a.mp4")}'
    DisplayOutputName = 'a.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$itemB = [pscustomobject]@{{
    SourceName = 'b.avi'
    SourceFileName = 'b.avi'
    RelativeSourcePath = 'b.avi'
    SourcePath = '{ps_quote(source_b)}'
    OutputPath = '{ps_quote(output_dir / "b.mp4")}'
    OutputPattern = '{ps_quote(output_dir / "b.mp4")}'
    DisplayOutputName = 'b.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$itemC = [pscustomobject]@{{
    SourceName = 'c.avi'
    SourceFileName = 'c.avi'
    RelativeSourcePath = 'c.avi'
    SourcePath = '{ps_quote(source_c)}'
    OutputPath = '{ps_quote(output_dir / "c.mp4")}'
    OutputPattern = '{ps_quote(output_dir / "c.mp4")}'
    DisplayOutputName = 'c.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}

$plan = Add-PlanEstimates -Plan @($itemA, $itemB, $itemC)
Set-GridRows -Plan $plan
[void](Select-PlanGridRowBySourceName -SourceName 'a.avi')

$settings = Get-Settings
Start-BatchSession -Settings $settings

    [void](Request-BatchPause)
$statusAfterPauseRequest = $statusValueLabel.Text
$pauseRequested = [bool]$script:BatchContext.PauseRequested

$script:CurrentProcess.HasExited = $true
Process-BatchTick

    $statusAfterPaused = $statusValueLabel.Text
    $isPaused = Test-BatchPaused
    $startEnabledWhilePaused = [bool]$startButton.Enabled
    $pauseEnabledWhilePaused = [bool]$pauseButton.Enabled
    $resumeEnabledWhilePaused = [bool]$resumeButton.Enabled
    $firstStatusAfterPaused = [string]$script:PlanItems[0].Status
    $secondStatusAfterPaused = [string]$script:PlanItems[1].Status
    $thirdStatusAfterPaused = [string]$script:PlanItems[2].Status
    
    [void](Select-PlanGridRowBySourceName -SourceName 'b.avi')
    [void](Move-SelectedQueuedItem -Direction 1)
$queuedOrderAfterMove = @(
    [string]$grid.Rows[0].Cells['SourceName'].Value,
    [string]$grid.Rows[1].Cells['SourceName'].Value,
    [string]$grid.Rows[2].Cells['SourceName'].Value
)

$qualityModeComboBox.SelectedItem = 'High Quality MP4 H.264'
$openPlayerWhilePaused = [bool]$openPlayerButton.Enabled
$sampleWhilePaused = [bool]$sampleButton.Enabled
$aspectWhilePaused = [bool]$aspectModeComboBox.Enabled
$splitOutputCheckBox.Checked = $true
$outputNameWhilePaused = [string]$grid.Rows[1].Cells['OutputName'].Value

    [void](Resume-BatchSession)

Write-Output 'JSON_START'
[pscustomobject]@{{
    StatusAfterPauseRequest = $statusAfterPauseRequest
    PauseRequested = $pauseRequested
    StatusAfterPaused = $statusAfterPaused
        IsPaused = $isPaused
        StartEnabledWhilePaused = $startEnabledWhilePaused
        PauseEnabledWhilePaused = $pauseEnabledWhilePaused
        ResumeEnabledWhilePaused = $resumeEnabledWhilePaused
        FirstStatusAfterPaused = $firstStatusAfterPaused
        SecondStatusAfterPaused = $secondStatusAfterPaused
        ThirdStatusAfterPaused = $thirdStatusAfterPaused
    QueuedOrderAfterMove = $queuedOrderAfterMove
    OpenPlayerWhilePaused = $openPlayerWhilePaused
    SampleWhilePaused = $sampleWhilePaused
    AspectWhilePaused = $aspectWhilePaused
    OutputNameWhilePaused = $outputNameWhilePaused
    RunningAfterResume = if ($null -eq $script:CurrentPlanItem) {{ '' }} else {{ [string]$script:CurrentPlanItem.SourceName }}
    StartCallCount = @($script:StartCalls).Count
    SecondCallQuality = [string]$script:StartCalls[1].QualityMode
    SecondCallSplit = [bool]$script:StartCalls[1].SplitOutput
    SecondCallOutputPath = [string]$script:StartCalls[1].OutputPath
    PauseEnabledAfterResume = [bool]$pauseButton.Enabled
    ResumeEnabledAfterResume = [bool]$resumeButton.Enabled
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-pause-resume-runtime-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["StatusAfterPauseRequest"] == "Paused after current file"
    assert payload["PauseRequested"] is True
    assert payload["StatusAfterPaused"] == "Paused"
    assert payload["IsPaused"] is True
    assert payload["StartEnabledWhilePaused"] is False
    assert payload["PauseEnabledWhilePaused"] is False
    assert payload["ResumeEnabledWhilePaused"] is True
    assert payload["FirstStatusAfterPaused"] == "done"
    assert payload["SecondStatusAfterPaused"] == "queued"
    assert payload["ThirdStatusAfterPaused"] == "queued"
    assert payload["QueuedOrderAfterMove"] == ["a.avi", "c.avi", "b.avi"]
    assert payload["OpenPlayerWhilePaused"] is True
    assert payload["SampleWhilePaused"] is True
    assert payload["AspectWhilePaused"] is True
    assert "c-part%03d.mp4" in payload["OutputNameWhilePaused"]
    assert payload["RunningAfterResume"] == "c.avi"
    assert payload["StartCallCount"] == 2
    assert payload["SecondCallQuality"] == "High Quality MP4 H.264"
    assert payload["SecondCallSplit"] is True
    assert "c-part%03d.mp4" in payload["SecondCallOutputPath"]
    assert payload["PauseEnabledAfterResume"] is True
    assert payload["ResumeEnabledAfterResume"] is False


def test_vhs_gui_player_trim_crop_state_roundtrip_is_per_file(tmp_path: Path) -> None:
    source_a = tmp_path / "clip-a.mp4"
    source_a.write_text("source-a", encoding="utf-8")
    source_b = tmp_path / "clip-b.mp4"
    source_b.write_text("source-b", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(tmp_path / "out")}'
 $mediaInfo = [pscustomobject]@{{
     Container = 'mp4'
     ContainerLongName = 'MP4'
     DurationSeconds = 180.0
     DurationText = '00:03:00'
     SizeText = '1 MB'
     OverallBitrateText = '1000 kbps'
     VideoCodec = 'h264'
     Width = 720
     Height = 576
     Resolution = '720x576'
     DisplayAspectRatio = '4:3'
     SampleAspectRatio = '1:1'
     FrameRate = 25.0
     FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$itemA = [pscustomobject]@{{
    SourceName = 'clip-a.mp4'
    SourcePath = '{ps_quote(source_a)}'
    DisplayOutputName = 'clip-a.mp4'
    MediaInfo = $mediaInfo
    CropMode = 'Auto'
    CropLeft = 12
    CropTop = 8
    CropRight = 14
    CropBottom = 10
}}
$itemB = [pscustomobject]@{{
    SourceName = 'clip-b.mp4'
    SourcePath = '{ps_quote(source_b)}'
    DisplayOutputName = 'clip-b.mp4'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($itemA, $itemB)
for ($index = 0; $index -lt $script:PlanItems.Count; $index++) {{
    $rowIndex = $grid.Rows.Add()
    $row = $grid.Rows[$rowIndex]
    $row.Cells['SourceName'].Value = $script:PlanItems[$index].SourceName
    $row.Cells['OutputName'].Value = $script:PlanItems[$index].DisplayOutputName
    $row.Cells['Status'].Value = 'queued'
    if ($index -eq 0) {{
        $row.Selected = $true
        $grid.CurrentCell = $row.Cells['SourceName']
    }}
}}
$savedA = Copy-PlanItemCropState -Item $itemA
$manualState = [pscustomobject]@{{
    CropMode = 'Manual'
    CropLeft = 16
    CropTop = 8
    CropRight = 14
    CropBottom = 10
}}
Apply-PlayerCropStateToItem -Item $itemA -CropState $manualState
$appliedMode = if ($itemA.PSObject.Properties['CropMode']) {{ [string]$itemA.CropMode }} else {{ '' }}
$appliedLeft = if ($itemA.PSObject.Properties['CropLeft']) {{ [int]$itemA.CropLeft }} else {{ -1 }}
$appliedTop = if ($itemA.PSObject.Properties['CropTop']) {{ [int]$itemA.CropTop }} else {{ -1 }}
$appliedRight = if ($itemA.PSObject.Properties['CropRight']) {{ [int]$itemA.CropRight }} else {{ -1 }}
$appliedBottom = if ($itemA.PSObject.Properties['CropBottom']) {{ [int]$itemA.CropBottom }} else {{ -1 }}
Clear-PlanItemCropState -Item $itemA
Write-Output 'JSON_START'
[pscustomobject]@{{
    SavedMode = [string]$savedA.CropMode
    SavedLeft = [int]$savedA.CropLeft
    SavedTop = [int]$savedA.CropTop
    SavedRight = [int]$savedA.CropRight
    SavedBottom = [int]$savedA.CropBottom
    AppliedMode = $appliedMode
    AppliedLeft = $appliedLeft
    AppliedTop = $appliedTop
    AppliedRight = $appliedRight
    AppliedBottom = $appliedBottom
    ClearedHasMode = [bool]$itemA.PSObject.Properties['CropMode']
    ClearedHasLeft = [bool]$itemA.PSObject.Properties['CropLeft']
    OtherItemHasMode = [bool]$itemB.PSObject.Properties['CropMode']
    OtherItemHasLeft = [bool]$itemB.PSObject.Properties['CropLeft']
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-player-trim-crop-state-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["SavedMode"] == "Auto"
    assert payload["SavedLeft"] == 12
    assert payload["SavedTop"] == 8
    assert payload["SavedRight"] == 14
    assert payload["SavedBottom"] == 10
    assert payload["AppliedMode"] == "Manual"
    assert payload["AppliedLeft"] == 16
    assert payload["AppliedTop"] == 8
    assert payload["AppliedRight"] == 14
    assert payload["AppliedBottom"] == 10
    assert payload["ClearedHasMode"] is False
    assert payload["ClearedHasLeft"] is False
    assert payload["OtherItemHasMode"] is False
    assert payload["OtherItemHasLeft"] is False


def test_vhs_gui_player_detect_auto_and_clear_crop_modes_are_consistent() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "function Apply-DetectedCropToPlayerState",
        'if ($AcceptAuto) {',
        '$localState.CropMode = "Auto"',
        'else {',
        '$localState.CropMode = "Manual"',
        "Update-PlayerCropSummaryFromFields",
        "Update-PlayerCropStateLabel",
        "function Clear-PlayerCropFields",
        '$localState.CropMode = ""',
        '$playerCropStateLabel.Text = "Crop: Auto"',
        '$playerCropStateLabel.Text = "Crop: Manual"',
        '$playerCropStateLabel.Text = "Crop: --"',
    ]:
        assert token in script, f"missing crop mode transition token: {token}"


def test_vhs_gui_player_detect_auto_and_clear_crop_runtime_flow(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    show_pattern = re.compile(
        r"(?ms)^    if \(\$null -ne \$form\)\s*\{\s*\[void\]\$dialog\.ShowDialog\(\$form\)\s*\}\s*else\s*\{\s*\[void\]\$dialog\.ShowDialog\(\)\s*\}"
    )
    show_replacement = """    Apply-DetectedCropToPlayerState
    $script:DetectLabel = $playerCropStateLabel.Text
    $script:DetectMode = [string]$localState.CropMode
    $script:DetectPersistedMode = [string](Get-PlayerCropStateFromFields).CropMode
    Apply-DetectedCropToPlayerState -AcceptAuto:$true
    $script:AutoLabel = $playerCropStateLabel.Text
    $script:AutoMode = [string]$localState.CropMode
    $script:AutoPersistedMode = [string](Get-PlayerCropStateFromFields).CropMode
    Clear-PlayerCropFields
    $script:ClearLabel = $playerCropStateLabel.Text
    $script:ClearMode = [string]$localState.CropMode
    Save-PlayerTrimChanges"""
    gui_script, show_replacements = show_pattern.subn(lambda _: show_replacement, gui_script, count=1)
    assert show_replacements == 1

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'clip.mp4'
    MediaInfo = $mediaInfo
    DetectedCrop = [pscustomobject]@{{
        Mode = 'Auto'
        Left = 12
        Top = 8
        Right = 14
        Bottom = 10
        SourceWidth = 720
        SourceHeight = 576
        Summary = 'Auto crop: 694x558 @ 12,8'
    }}
}}
$result = Open-PlayerTrimWindow -Item $item
$savedResult = @($result | Where-Object {{ $null -ne $_ -and $_.PSObject.Properties['Saved'] }})[-1]
Write-Output 'JSON_START'
[pscustomobject]@{{
    DetectLabel = $script:DetectLabel
    DetectMode = $script:DetectMode
    DetectPersistedMode = $script:DetectPersistedMode
    AutoLabel = $script:AutoLabel
    AutoMode = $script:AutoMode
    AutoPersistedMode = $script:AutoPersistedMode
    ClearLabel = $script:ClearLabel
    ClearMode = $script:ClearMode
    SavedCropMode = if ($null -eq $savedResult -or -not $savedResult.PSObject.Properties['CropState']) {{ '<missing>' }} else {{ [string]$savedResult.CropState.CropMode }}
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    main_show_pattern = re.compile(r"(?m)^\s*\[void\]\$form\.ShowDialog\(\)\s*$")
    gui_script, main_show_replacements = main_show_pattern.subn(lambda _: probe, gui_script, count=1)
    assert main_show_replacements == 1
    probe_script = tmp_path / "gui-player-detect-crop-runtime-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["DetectLabel"] == "Crop: Manual"
    assert payload["DetectMode"] == "Manual"
    assert payload["DetectPersistedMode"] == "Manual"
    assert payload["AutoLabel"] == "Crop: Auto"
    assert payload["AutoMode"] == "Auto"
    assert payload["AutoPersistedMode"] == "Auto"
    assert payload["ClearLabel"] == "Crop: --"
    assert payload["ClearMode"] == ""
    assert payload["SavedCropMode"] == ""


def test_vhs_gui_player_trim_preview_only_normalizes_legacy_aspect_mode(tmp_path: Path) -> None:
    source = tmp_path / "legacy.mpg"
    source.write_text("legacy", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mpeg'
    ContainerLongName = 'MPEG Program Stream'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'mpeg2video'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '16:9'
    SampleAspectRatio = '64:45'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'mp2'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '192 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'legacy.mpg'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'legacy.mp4'
    MediaInfo = $mediaInfo
    AspectMode = 'Keep Original'
}}
$result = Open-PlayerTrimWindow -Item $item -PreviewOnly
Write-Output 'JSON_START'
[pscustomobject]@{{
    AspectMode = if ($null -eq $result.AspectState) {{ '' }} else {{ [string]$result.AspectState.AspectMode }}
    DisplayAspectRatio = if ($null -eq $result.AspectState) {{ '' }} else {{ [string]$result.AspectState.DetectedDisplayAspectRatio }}
    SampleAspectRatio = if ($null -eq $result.AspectState) {{ '' }} else {{ [string]$result.AspectState.DetectedSampleAspectRatio }}
    OutputAspectWidth = if ($null -eq $result.AspectState -or $null -eq $result.AspectState.OutputAspectWidth) {{ -1 }} else {{ [int]$result.AspectState.OutputAspectWidth }}
    OutputAspectHeight = if ($null -eq $result.AspectState -or $null -eq $result.AspectState.OutputAspectHeight) {{ -1 }} else {{ [int]$result.AspectState.OutputAspectHeight }}
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-player-trim-aspect-preview-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["AspectMode"] == "KeepOriginal"
    assert payload["DisplayAspectRatio"] == "16:9"
    assert payload["SampleAspectRatio"] == "64:45"
    assert payload["OutputAspectWidth"] > 0
    assert payload["OutputAspectHeight"] > 0


def test_vhs_gui_show_selected_player_trim_window_saves_aspect_state_back_to_queue(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
    VideoSummary = 'h264 | 720x576 | 25 fps'
    AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    OutputPath = '{ps_quote(output_dir / "clip.mp4")}'
    DisplayOutputName = 'clip.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($item)
$rowIndex = $grid.Rows.Add()
$row = $grid.Rows[$rowIndex]
$row.Cells['SourceName'].Value = 'clip.mp4'
$row.Cells['OutputName'].Value = 'clip.mp4'
$row.Cells['Range'].Value = '--'
$row.Cells['Status'].Value = 'queued'
$row.Selected = $true
$grid.CurrentCell = $row.Cells['SourceName']
 function Open-PlayerTrimWindow {{
     param([object]$Item)
     return [pscustomobject]@{{
         Saved = $true
         Mode = 'Playback mode'
         AspectState = [pscustomobject]@{{
             AspectMode = 'Force16x9'
         }}
         TrimState = [pscustomobject]@{{
             TrimStartText = '00:00:10'
             TrimEndText = '00:00:20'
             TrimSummary = '00:00:10 - 00:00:20'
             TrimDurationSeconds = 10.0
            TrimSegments = @()
            PreviewPositionSeconds = 10.0
        }}
        CropState = [pscustomobject]@{{
            CropMode = 'Manual'
            CropLeft = 12
            CropTop = 8
            CropRight = 14
            CropBottom = 10
        }}
     }}
 }}
 Show-SelectedPlayerTrimWindow
 Write-Output 'JSON_START'
 [pscustomobject]@{{
     AspectMode = if ($item.PSObject.Properties['AspectMode']) {{ [string]$item.AspectMode }} else {{ '' }}
     OutputAspectWidth = if ($item.PSObject.Properties['OutputAspectWidth']) {{ [int]$item.OutputAspectWidth }} else {{ -1 }}
     OutputAspectHeight = if ($item.PSObject.Properties['OutputAspectHeight']) {{ [int]$item.OutputAspectHeight }} else {{ -1 }}
     TrimStart = $item.TrimStartText
     TrimEnd = $item.TrimEndText
     TrimSummary = $item.TrimSummary
     TrimDurationSeconds = [double]$item.TrimDurationSeconds
     CropMode = if ($item.PSObject.Properties['CropMode']) {{ [string]$item.CropMode }} else {{ '' }}
    CropLeft = if ($item.PSObject.Properties['CropLeft']) {{ [int]$item.CropLeft }} else {{ -1 }}
    CropTop = if ($item.PSObject.Properties['CropTop']) {{ [int]$item.CropTop }} else {{ -1 }}
    CropRight = if ($item.PSObject.Properties['CropRight']) {{ [int]$item.CropRight }} else {{ -1 }}
    CropBottom = if ($item.PSObject.Properties['CropBottom']) {{ [int]$item.CropBottom }} else {{ -1 }}
    RangeCell = [string]$row.Cells['Range'].Value
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-player-trim-save-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["TrimStart"] == "00:00:10"
    assert payload["TrimEnd"] == "00:00:20"
    assert payload["TrimSummary"] == "00:00:10 - 00:00:20"
    assert payload["TrimDurationSeconds"] == 10
    assert payload["AspectMode"] == "Force16x9"
    assert payload["OutputAspectWidth"] > 0
    assert payload["OutputAspectHeight"] > 0
    assert payload["CropMode"] == "Manual"
    assert payload["CropLeft"] == 12
    assert payload["CropTop"] == 8
    assert payload["CropRight"] == 14
    assert payload["CropBottom"] == 10
    assert payload["RangeCell"] == "00:00:10 - 00:00:20"


def test_vhs_gui_player_trim_crop_change_refreshes_output_aspect_before_save(tmp_path: Path) -> None:
    source = tmp_path / "crop-shift.mpg"
    source.write_text("source", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    show_pattern = re.compile(
        r"(?ms)^    if \(\$null -ne \$form\)\s*\{\s*\[void\]\$dialog\.ShowDialog\(\$form\)\s*\}\s*else\s*\{\s*\[void\]\$dialog\.ShowDialog\(\)\s*\}"
    )
    show_replacement = """    $script:BeforeAspectGeometry = $playerAspectGeometryLabel.Text
    $playerCropTopTextBox.Text = '24'
    $playerCropBottomTextBox.Text = '24'
    $script:AfterAspectGeometry = $playerAspectGeometryLabel.Text
    $dialogResult = [pscustomobject]@{
        Saved = $false
        Mode = [string]$localState.Mode
    }"""
    gui_script, show_replacements = show_pattern.subn(lambda _: show_replacement, gui_script, count=1)
    assert show_replacements == 1

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mpeg'
    ContainerLongName = 'MPEG Program Stream'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'mpeg2video'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '16:9'
    SampleAspectRatio = '64:45'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'mp2'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '192 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'crop-shift.mpg'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'crop-shift.mp4'
    MediaInfo = $mediaInfo
    AspectMode = 'Auto'
}}
[void](Open-PlayerTrimWindow -Item $item)
Write-Output 'JSON_START'
[pscustomobject]@{{
    BeforeAspectGeometry = $script:BeforeAspectGeometry
    AfterAspectGeometry = $script:AfterAspectGeometry
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    main_show_pattern = re.compile(r"(?m)^\s*\[void\]\$form\.ShowDialog\(\)\s*$")
    gui_script, main_show_replacements = main_show_pattern.subn(lambda _: probe, gui_script, count=1)
    assert main_show_replacements == 1
    probe_script = tmp_path / "gui-player-trim-aspect-crop-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["BeforeAspectGeometry"] != payload["AfterAspectGeometry"]
    assert "Output: 1024 x 576" in payload["BeforeAspectGeometry"]
    assert "Output: 940 x 528" in payload["AfterAspectGeometry"]


def test_vhs_gui_player_trim_unsaved_aspect_change_does_not_persist_to_queue(tmp_path: Path) -> None:
    source = tmp_path / "unsaved.mp4"
    source.write_text("source", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    show_pattern = re.compile(
        r"(?ms)^    if \(\$null -ne \$form\)\s*\{\s*\[void\]\$dialog\.ShowDialog\(\$form\)\s*\}\s*else\s*\{\s*\[void\]\$dialog\.ShowDialog\(\)\s*\}"
    )
    show_replacement = """    $playerAspectModeComboBox.SelectedItem = 'Force 16:9'
    $script:UnsavedAspectMode = [string]$localState.AspectMode
    $dialogResult = [pscustomobject]@{
        Saved = $false
        Mode = [string]$localState.Mode
        AspectState = [pscustomobject]@{
            AspectMode = [string]$localState.AspectMode
        }
    }"""
    gui_script, show_replacements = show_pattern.subn(lambda _: show_replacement, gui_script, count=1)
    assert show_replacements == 1

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '16:15'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'unsaved.mp4'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'unsaved.mp4'
    MediaInfo = $mediaInfo
    AspectMode = 'KeepOriginal'
}}
$result = Open-PlayerTrimWindow -Item $item
$savedResult = @($result | Where-Object {{ $null -ne $_ -and $_.PSObject.Properties['Saved'] }})[-1]
Write-Output 'JSON_START'
[pscustomobject]@{{
    ResultSaved = if ($null -eq $savedResult) {{ '<missing>' }} else {{ [string]$savedResult.Saved }}
    UnsavedAspectMode = $script:UnsavedAspectMode
    ItemAspectMode = [string]$item.AspectMode
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    main_show_pattern = re.compile(r"(?m)^\s*\[void\]\$form\.ShowDialog\(\)\s*$")
    gui_script, main_show_replacements = main_show_pattern.subn(lambda _: probe, gui_script, count=1)
    assert main_show_replacements == 1
    probe_script = tmp_path / "gui-player-trim-aspect-unsaved-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["ResultSaved"] == "False"
    assert payload["UnsavedAspectMode"] == "Force16x9"
    assert payload["ItemAspectMode"] == "KeepOriginal"


def test_vhs_gui_crop_overlay_and_queue_status_refresh_with_selection(tmp_path: Path) -> None:
    source_one = tmp_path / "clip-one.mp4"
    source_two = tmp_path / "clip-two.mp4"
    source_one.write_text("source-one", encoding="utf-8")
    source_two.write_text("source-two", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
    VideoSummary = 'h264 | 720x576 | 25 fps'
    AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
}}
$itemOne = [pscustomobject]@{{
    SourceName = 'clip-one.mp4'
    SourcePath = '{ps_quote(source_one)}'
    OutputPath = '{ps_quote(output_dir / "clip-one.mp4")}'
    DisplayOutputName = 'clip-one.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
    CropMode = 'Manual'
    CropLeft = 12
    CropTop = 8
    CropRight = 14
    CropBottom = 10
    CropSummary = 'crop=694:558:12:8'
}}
$itemTwo = [pscustomobject]@{{
    SourceName = 'clip-two.mp4'
    SourcePath = '{ps_quote(source_two)}'
    OutputPath = '{ps_quote(output_dir / "clip-two.mp4")}'
    DisplayOutputName = 'clip-two.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($itemOne, $itemTwo)
$grid.MultiSelect = $false

$rowIndexOne = $grid.Rows.Add()
$rowOne = $grid.Rows[$rowIndexOne]
$rowOne.Cells['SourceName'].Value = 'clip-one.mp4'
$rowOne.Cells['OutputName'].Value = 'clip-one.mp4'
$rowOne.Cells['Range'].Value = '--'
$rowOne.Cells['Status'].Value = 'queued'

$rowIndexTwo = $grid.Rows.Add()
$rowTwo = $grid.Rows[$rowIndexTwo]
$rowTwo.Cells['SourceName'].Value = 'clip-two.mp4'
$rowTwo.Cells['OutputName'].Value = 'clip-two.mp4'
$rowTwo.Cells['Range'].Value = '--'
$rowTwo.Cells['Status'].Value = 'queued'

Update-SelectedTrimGridRow -Item $itemOne
Update-SelectedTrimGridRow -Item $itemTwo

$rowOne.Selected = $true
$grid.CurrentCell = $rowOne.Cells['SourceName']
Update-PreviewTrimPanel
$manualStatus = $previewStatusLabel.Text
$manualOverlay = $previewCropOverlayLabel.Text

$rowTwo.Selected = $true
$grid.CurrentCell = $rowTwo.Cells['SourceName']
Update-PreviewTrimPanel
$noneStatus = $previewStatusLabel.Text
$noneOverlay = $previewCropOverlayLabel.Text

Write-Output 'JSON_START'
[pscustomobject]@{{
    CropCellOne = [string]$rowOne.Cells['Crop'].Value
    CropCellTwo = [string]$rowTwo.Cells['Crop'].Value
    ManualStatus = $manualStatus
    ManualOverlay = $manualOverlay
    NoneStatus = $noneStatus
    NoneOverlay = $noneOverlay
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-crop-overlay-queue-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["CropCellOne"] == "Crop: Manual"
    assert payload["CropCellTwo"] == "Crop: --"
    assert "Crop: Manual" in payload["ManualStatus"]
    assert payload["ManualOverlay"].startswith("Crop overlay: Manual")
    assert "L12 T8 R14 B10" in payload["ManualOverlay"]
    assert "Crop: --" in payload["NoneStatus"]
    assert payload["NoneOverlay"] == "Crop overlay: --"


def test_vhs_gui_auto_apply_crop_runs_only_on_start_and_preserves_manual_crop(tmp_path: Path) -> None:
    source_manual = tmp_path / "manual.mp4"
    source_auto = tmp_path / "auto.mp4"
    source_manual.write_text("manual", encoding="utf-8")
    source_auto.write_text("auto", encoding="utf-8")
    output_dir = tmp_path / "out"
    ffmpeg_stub = Path(r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )
    probe = f"""
function New-ProbeBatchPlan {{
    $mediaInfo = [pscustomobject]@{{
        Container = 'mp4'
        ContainerLongName = 'MP4'
        DurationSeconds = 180.0
        DurationText = '00:03:00'
        SizeText = '1 MB'
        OverallBitrateText = '1000 kbps'
        VideoCodec = 'h264'
        Resolution = '720x576'
        DisplayAspectRatio = '4:3'
        SampleAspectRatio = '1:1'
        FrameRate = 25.0
        FrameRateText = '25 fps'
        FrameCount = 4500
        VideoBitrateText = '900 kbps'
        AudioCodec = 'aac'
        AudioChannels = 2
        AudioSampleRateHz = 48000
        AudioBitrateText = '128 kbps'
        VideoSummary = 'h264 | 720x576 | 25 fps'
        AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
    }}
    $samples = @(
        [pscustomobject]@{{ Left = 12; Top = 8; Right = 14; Bottom = 10 }},
        [pscustomobject]@{{ Left = 12; Top = 8; Right = 14; Bottom = 10 }},
        [pscustomobject]@{{ Left = 12; Top = 8; Right = 14; Bottom = 10 }}
    )

    return @(
        [pscustomobject]@{{
            SourceName = 'manual.mp4'
            SourcePath = '{ps_quote(source_manual)}'
            OutputPath = '{ps_quote(output_dir / "manual.mp4")}'
            DisplayOutputName = 'manual.mp4'
            Status = 'queued'
            MediaInfo = $mediaInfo
            CropMode = 'Manual'
            CropLeft = 4
            CropTop = 2
            CropRight = 6
            CropBottom = 4
            CropSummary = 'Manual crop: 710x570 @ 4,2'
            DetectionSamples = $samples
        }},
        [pscustomobject]@{{
            SourceName = 'auto.mp4'
            SourcePath = '{ps_quote(source_auto)}'
            OutputPath = '{ps_quote(output_dir / "auto.mp4")}'
            DisplayOutputName = 'auto.mp4'
            Status = 'queued'
            MediaInfo = $mediaInfo
            DetectionSamples = $samples
        }}
    )
}}

function Add-PlanEstimates {{
    param([object[]]$Plan)
    foreach ($item in $Plan) {{
        $item | Add-Member -NotePropertyName 'UsbNote' -NotePropertyValue '' -Force
        $item | Add-Member -NotePropertyName 'EstimatedSize' -NotePropertyValue 'Estimate: --' -Force
        $item | Add-Member -NotePropertyName 'MediaDetails' -NotePropertyValue 'Media details' -Force
    }}
    return $Plan
}}

function Get-VhsMp4Plan {{
    param([string]$InputDir, [string]$OutputDir, [switch]$SplitOutput)
    return @(New-ProbeBatchPlan)
}}

function Set-GridRows {{
    param([object[]]$Plan)
    $script:PlanItems = @($Plan)
}}

$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$script:ResolvedFfmpegPath = '{ps_quote(ffmpeg_stub)}'
$ffmpegPathTextBox.Text = $script:ResolvedFfmpegPath
$autoApplyCropCheckBox.Checked = $true

Scan-InputFolder
$scanPlan = @($script:PlanItems)
$scanManualMode = [string]$scanPlan[0].CropMode
$scanAutoMode = if ($scanPlan[1].PSObject.Properties['CropMode']) {{ [string]$scanPlan[1].CropMode }} else {{ '' }}

$startOffPlan = @(New-ProbeBatchPlan)
$null = Invoke-BatchAutoApplyCrop -Items $startOffPlan -Enabled:$false
$startOffManualMode = [string]$startOffPlan[0].CropMode
$startOffManualLeft = [int]$startOffPlan[0].CropLeft
$startOffAutoMode = if ($startOffPlan[1].PSObject.Properties['CropMode']) {{ [string]$startOffPlan[1].CropMode }} else {{ '' }}

$startOnPlan = @(New-ProbeBatchPlan)
$null = Invoke-BatchAutoApplyCrop -Items $startOnPlan -Enabled:$true
$startOnManualMode = [string]$startOnPlan[0].CropMode
$startOnManualLeft = [int]$startOnPlan[0].CropLeft
$startOnAutoMode = if ($startOnPlan[1].PSObject.Properties['CropMode']) {{ [string]$startOnPlan[1].CropMode }} else {{ '' }}
$startOnAutoLeft = if ($startOnPlan[1].PSObject.Properties['CropLeft']) {{ [int]$startOnPlan[1].CropLeft }} else {{ -1 }}

Write-Output 'JSON_START'
[pscustomobject]@{{
    ScanManualMode = $scanManualMode
    ScanAutoMode = $scanAutoMode
    StartOffManualMode = $startOffManualMode
    StartOffManualLeft = $startOffManualLeft
    StartOffAutoMode = $startOffAutoMode
    StartOnManualMode = $startOnManualMode
    StartOnManualLeft = $startOnManualLeft
    StartOnAutoMode = $startOnAutoMode
    StartOnAutoLeft = $startOnAutoLeft
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-batch-auto-crop-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["ScanManualMode"] == "Manual"
    assert payload["ScanAutoMode"] == ""
    assert payload["StartOffManualMode"] == "Manual"
    assert payload["StartOffManualLeft"] == 4
    assert payload["StartOffAutoMode"] == ""
    assert payload["StartOnManualMode"] == "Manual"
    assert payload["StartOnManualLeft"] == 4
    assert payload["StartOnAutoMode"] == "Auto"
    assert payload["StartOnAutoLeft"] == 12


def test_vhs_gui_refreshes_queue_aspect_summary_after_crop_and_shows_unknown_mode_honestly(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'mpeg2video'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '16:9'
    SampleAspectRatio = '64:45'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
    VideoSummary = 'mpeg2video | 720x576 | 16:9 | 25 fps'
    AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
}}
$croppedItem = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    OutputPath = '{ps_quote(output_dir / "clip.mp4")}'
    DisplayOutputName = 'clip.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$unknownItem = [pscustomobject]@{{
    SourceName = 'unknown.mp4'
    SourcePath = '{ps_quote(tmp_path / "unknown.mp4")}'
    OutputPath = '{ps_quote(output_dir / "unknown.mp4")}'
    DisplayOutputName = 'unknown.mp4'
    Status = 'queued'
}}

Apply-PlayerCropStateToItem -Item $croppedItem -CropState ([pscustomobject]@{{
    CropMode = 'Manual'
    CropLeft = 0
    CropTop = 8
    CropRight = 0
    CropBottom = 8
}})

$croppedDetails = Format-VhsMp4MediaDetails -Item $croppedItem
$croppedAspect = Get-PlanItemAspectStatusText -Item $croppedItem
$unknownDetails = Format-VhsMp4MediaDetails -Item $unknownItem
$unknownAspect = Get-PlanItemAspectStatusText -Item $unknownItem

Write-Output 'JSON_START'
[pscustomobject]@{{
    CroppedAspect = $croppedAspect
    CroppedDetails = $croppedDetails
    CroppedOutputAspectHeight = if ($croppedItem.PSObject.Properties['OutputAspectHeight']) {{ [string]$croppedItem.OutputAspectHeight }} else {{ '' }}
    UnknownAspect = $unknownAspect
    UnknownDetails = $unknownDetails
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-aspect-refresh-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["CroppedAspect"] == "Auto 16:9"
    assert payload["CroppedOutputAspectHeight"] == "560"
    assert "Planned output aspect: 996 x 560" in payload["CroppedDetails"]
    assert payload["UnknownAspect"] == "--"
    assert "Detected: Not available" in payload["UnknownDetails"]


def test_vhs_gui_aspect_dropdown_manual_override_preserves_crop_and_trim_state(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'mpeg2video'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '16:9'
    SampleAspectRatio = '64:45'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
    VideoSummary = 'mpeg2video | 720x576 | 16:9 | 25 fps'
    AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    OutputPath = '{ps_quote(output_dir / "clip.mp4")}'
    DisplayOutputName = 'clip.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
    AspectMode = 'Auto'
    EstimatedSize = 'Estimate: stale'
    UsbNote = 'USB note: stale'
}}
Apply-PlayerCropStateToItem -Item $item -CropState ([pscustomobject]@{{
    CropMode = 'Manual'
    CropLeft = 6
    CropTop = 8
    CropRight = 10
    CropBottom = 12
}})
Apply-PlayerTrimStateToItem -Item $item -TrimState ([pscustomobject]@{{
    TrimStartText = '00:00:05'
    TrimEndText = '00:00:20'
}})
Set-GridRows -Plan @($item)
$grid.Rows[0].Selected = $true
$grid.CurrentCell = $grid.Rows[0].Cells['SourceName']
Update-MediaInfoPanel
Update-PreviewTrimPanel
$beforeCropSummary = [string]$item.CropSummary
$beforeTrimSummary = [string]$item.TrimSummary
$aspectModeComboBox.SelectedItem = 'Force 4:3'
Write-Output 'JSON_START'
[pscustomobject]@{{
    AspectMode = [string]$item.AspectMode
    AspectCell = [string]$grid.Rows[0].Cells['Aspect'].Value
    CropMode = [string]$item.CropMode
    CropLeft = [int]$item.CropLeft
    CropSummaryUnchanged = ([string]$item.CropSummary -eq $beforeCropSummary)
    TrimStartText = [string]$item.TrimStartText
    TrimEndText = [string]$item.TrimEndText
    TrimSummaryUnchanged = ([string]$item.TrimSummary -eq $beforeTrimSummary)
    ComboSelection = [string]$aspectModeComboBox.SelectedItem
    EstimatedSize = [string]$item.EstimatedSize
    UsbNote = [string]$item.UsbNote
    EstimateCell = [string]$grid.Rows[0].Cells['EstimatedSize'].Value
    UsbNoteCell = [string]$grid.Rows[0].Cells['UsbNote'].Value
    MediaDetails = [string]$item.MediaDetails
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-aspect-dropdown-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["AspectMode"] == "Force4x3"
    assert payload["AspectCell"] == "Manual 4:3"
    assert payload["CropMode"] == "Manual"
    assert payload["CropLeft"] == 6
    assert payload["CropSummaryUnchanged"] is True
    assert payload["TrimStartText"] == "00:00:05"
    assert payload["TrimEndText"] == "00:00:20"
    assert payload["TrimSummaryUnchanged"] is True
    assert payload["ComboSelection"] == "Force 4:3"
    assert payload["EstimatedSize"] != "Estimate: stale"
    assert payload["UsbNote"] != "USB note: stale"
    assert payload["EstimateCell"] == payload["EstimatedSize"]
    assert payload["UsbNoteCell"] == payload["UsbNote"]
    assert payload["EstimatedSize"] in payload["MediaDetails"]
    assert payload["UsbNote"] in payload["MediaDetails"]


def test_vhs_gui_copy_to_all_batch_updates_only_aspect_mode(tmp_path: Path) -> None:
    source_a = tmp_path / "clip-a.mp4"
    source_b = tmp_path / "clip-b.mp4"
    source_a.write_text("source", encoding="utf-8")
    source_b.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'mpeg2video'
    Width = 720
    Height = 576
    Resolution = '720x576'
    DisplayAspectRatio = '16:9'
    SampleAspectRatio = '64:45'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
    VideoSummary = 'mpeg2video | 720x576 | 16:9 | 25 fps'
    AudioSummary = 'aac | 2 ch | 48000 Hz | 128 kbps'
}}
$first = [pscustomobject]@{{
    SourceName = 'clip-a.mp4'
    SourcePath = '{ps_quote(source_a)}'
    OutputPath = '{ps_quote(output_dir / "clip-a.mp4")}'
    DisplayOutputName = 'clip-a.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
    AspectMode = 'Auto'
    EstimatedSize = 'Estimate: stale-a'
    UsbNote = 'USB note: stale-a'
}}
$second = [pscustomobject]@{{
    SourceName = 'clip-b.mp4'
    SourcePath = '{ps_quote(source_b)}'
    OutputPath = '{ps_quote(output_dir / "clip-b.mp4")}'
    DisplayOutputName = 'clip-b.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
    AspectMode = 'KeepOriginal'
    EstimatedSize = 'Estimate: stale-b'
    UsbNote = 'USB note: stale-b'
}}
Apply-PlayerCropStateToItem -Item $second -CropState ([pscustomobject]@{{
    CropMode = 'Manual'
    CropLeft = 4
    CropTop = 2
    CropRight = 6
    CropBottom = 2
}})
Apply-PlayerTrimStateToItem -Item $second -TrimState ([pscustomobject]@{{
    TrimStartText = '00:00:10'
    TrimEndText = '00:00:30'
}})
Set-GridRows -Plan @($first, $second)
$grid.Rows[0].Selected = $true
$grid.CurrentCell = $grid.Rows[0].Cells['SourceName']
Update-MediaInfoPanel
Update-PreviewTrimPanel
$beforeCropSummary = [string]$second.CropSummary
$beforeTrimSummary = [string]$second.TrimSummary
$aspectModeComboBox.SelectedItem = 'Force 16:9'
[void](Copy-SelectedAspectModeToAll)
Write-Output 'JSON_START'
[pscustomobject]@{{
    FirstAspectMode = [string]$first.AspectMode
    SecondAspectMode = [string]$second.AspectMode
    FirstAspectCell = [string]$grid.Rows[0].Cells['Aspect'].Value
    SecondAspectCell = [string]$grid.Rows[1].Cells['Aspect'].Value
    FirstEstimatedSize = [string]$first.EstimatedSize
    SecondEstimatedSize = [string]$second.EstimatedSize
    FirstUsbNote = [string]$first.UsbNote
    SecondUsbNote = [string]$second.UsbNote
    FirstEstimateCell = [string]$grid.Rows[0].Cells['EstimatedSize'].Value
    SecondEstimateCell = [string]$grid.Rows[1].Cells['EstimatedSize'].Value
    FirstUsbNoteCell = [string]$grid.Rows[0].Cells['UsbNote'].Value
    SecondUsbNoteCell = [string]$grid.Rows[1].Cells['UsbNote'].Value
    SecondCropMode = [string]$second.CropMode
    SecondCropLeft = [int]$second.CropLeft
    SecondCropSummaryUnchanged = ([string]$second.CropSummary -eq $beforeCropSummary)
    SecondTrimStartText = [string]$second.TrimStartText
    SecondTrimEndText = [string]$second.TrimEndText
    SecondTrimSummaryUnchanged = ([string]$second.TrimSummary -eq $beforeTrimSummary)
    FirstMediaDetails = [string]$first.MediaDetails
    SecondMediaDetails = [string]$second.MediaDetails
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-aspect-copy-to-all-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["FirstAspectMode"] == "Force16x9"
    assert payload["SecondAspectMode"] == "Force16x9"
    assert payload["FirstAspectCell"] == "Manual 16:9"
    assert payload["SecondAspectCell"] == "Manual 16:9"
    assert payload["FirstEstimatedSize"] != "Estimate: stale-a"
    assert payload["SecondEstimatedSize"] != "Estimate: stale-b"
    assert payload["FirstUsbNote"] != "USB note: stale-a"
    assert payload["SecondUsbNote"] != "USB note: stale-b"
    assert payload["FirstEstimateCell"] == payload["FirstEstimatedSize"]
    assert payload["SecondEstimateCell"] == payload["SecondEstimatedSize"]
    assert payload["FirstUsbNoteCell"] == payload["FirstUsbNote"]
    assert payload["SecondUsbNoteCell"] == payload["SecondUsbNote"]
    assert payload["SecondCropMode"] == "Manual"
    assert payload["SecondCropLeft"] == 4
    assert payload["SecondCropSummaryUnchanged"] is True
    assert payload["SecondTrimStartText"] == "00:00:10"
    assert payload["SecondTrimEndText"] == "00:00:30"
    assert payload["SecondTrimSummaryUnchanged"] is True
    assert payload["FirstEstimatedSize"] in payload["FirstMediaDetails"]
    assert payload["SecondEstimatedSize"] in payload["SecondMediaDetails"]


def test_vhs_gui_prefers_preview_mode_for_avi_player_window(tmp_path: Path) -> None:
    source = tmp_path / "clip.avi"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$mediaInfo = [pscustomobject]@{{
    Container = 'avi'
    ContainerLongName = 'AVI'
    DurationSeconds = 180.0
    DurationText = '00:03:00'
    SizeText = '1 MB'
    OverallBitrateText = '25000 kbps'
    VideoCodec = 'dvvideo'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 4500
    VideoBitrateText = '24000 kbps'
    AudioCodec = 'pcm_s16le'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '1536 kbps'
    VideoSummary = 'dvvideo | 720x576 | 25 fps'
    AudioSummary = 'pcm_s16le | 2 ch | 48000 Hz'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.avi'
    SourcePath = '{ps_quote(source)}'
    OutputPath = '{ps_quote(output_dir / "clip.mp4")}'
    DisplayOutputName = 'clip.mp4'
    Status = 'queued'
    MediaInfo = $mediaInfo
}}
$result = Open-PlayerTrimWindow -Item $item -PreviewOnly
Write-Output 'JSON_START'
[pscustomobject]@{{
    Mode = [string]$result.Mode
    PlaybackPreferred = [bool](Test-PlaybackPreferredFormat -Item $item)
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-player-trim-fallback-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["Mode"] == "Preview mode"
    assert payload["PlaybackPreferred"] is False


def test_vhs_gui_supports_multi_cut_segment_list(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 240.0
    DurationText = '00:04:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 6000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'clip.mp4'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($item)
$rowIndex = $grid.Rows.Add()
$row = $grid.Rows[$rowIndex]
$row.Cells['SourceName'].Value = 'clip.mp4'
$row.Cells['OutputName'].Value = 'clip.mp4'
$row.Cells['Status'].Value = 'queued'
$row.Selected = $true
$grid.CurrentCell = $row.Cells['SourceName']
Update-PreviewTrimPanel
$trimStartTextBox.Text = '00:00:10'
$trimEndTextBox.Text = '00:00:20'
Add-TrimSegmentFromFields
$trimStartTextBox.Text = '00:01:00'
$trimEndTextBox.Text = '00:01:30'
Add-TrimSegmentFromFields
Write-Output 'JSON_START'
[pscustomobject]@{{
    SegmentCount = @($item.TrimSegments).Count
    SegmentSummary = $item.TrimSummary
    SegmentDurationSeconds = [double]$item.TrimDurationSeconds
    ListCount = $trimSegmentsListBox.Items.Count
    FirstListItem = [string]$trimSegmentsListBox.Items[0]
    SecondListItem = [string]$trimSegmentsListBox.Items[1]
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-multi-cut-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["SegmentCount"] == 2
    assert payload["SegmentSummary"] == "2 seg | 00:00:10 - 00:00:20 ; 00:01:00 - 00:01:30"
    assert payload["SegmentDurationSeconds"] == 40
    assert payload["ListCount"] == 2
    assert payload["FirstListItem"] == "1. 00:00:10 - 00:00:20"
    assert payload["SecondListItem"] == "2. 00:01:00 - 00:01:30"


def test_vhs_gui_preview_timeline_sets_trim_points_without_rendering(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'clip.mp4'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($item)
$rowIndex = $grid.Rows.Add()
$row = $grid.Rows[$rowIndex]
$row.Cells['SourceName'].Value = 'clip.mp4'
$row.Cells['OutputName'].Value = 'clip.mp4'
$row.Cells['Status'].Value = 'queued'
$row.Selected = $true
$grid.CurrentCell = $row.Cells['SourceName']
Update-PreviewTrimPanel
Set-PreviewPositionSeconds -Seconds 10 -RefreshImage:$false
Set-TrimPointFromPreview -Point Start
Move-PreviewFrame -Direction 1 -RefreshImage:$false
Set-TrimPointFromPreview -Point End
$shortcutFrame = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::Right)
$shortcutSecond = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::Right) -Shift:$true
$shortcutTenSeconds = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::Left) -Control:$true
$shortcutStart = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::I)
$shortcutFrameAfterStart = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::Right)
$shortcutEnd = Invoke-PreviewKeyboardShortcut -KeyCode ([System.Windows.Forms.Keys]::O)
Write-Output 'JSON_START'
[pscustomobject]@{{
    PreviewTime = $previewTimeTextBox.Text
    TimelineValue = $previewTimelineTrackBar.Value
    PositionLabel = $previewPositionLabel.Text
    TrimStart = $trimStartTextBox.Text
    TrimEnd = $trimEndTextBox.Text
    CutRange = $cutRangeLabel.Text
    ItemPreviewSeconds = [double]$item.PreviewPositionSeconds
    ShortcutFrame = $shortcutFrame
    ShortcutSecond = $shortcutSecond
    ShortcutTenSeconds = $shortcutTenSeconds
    ShortcutStart = $shortcutStart
    ShortcutFrameAfterStart = $shortcutFrameAfterStart
    ShortcutEnd = $shortcutEnd
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-preview-timeline-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["TrimStart"] == "00:00:01.08"
    assert payload["TrimEnd"] == "00:00:01.12"
    assert payload["PreviewTime"] == "00:00:01.12"
    assert payload["TimelineValue"] == 112
    assert payload["PositionLabel"] == "00:00:01.12 / 00:02:00"
    assert "CUT: [" in payload["CutRange"]
    assert "S" in payload["CutRange"]
    assert payload["ShortcutFrame"] is True
    assert payload["ShortcutSecond"] is True
    assert payload["ShortcutTenSeconds"] is True
    assert payload["ShortcutStart"] is True
    assert payload["ShortcutFrameAfterStart"] is True
    assert payload["ShortcutEnd"] is True
    assert abs(payload["ItemPreviewSeconds"] - 1.12) < 0.001


def test_vhs_gui_auto_preview_toggle_controls_debounced_refresh(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$script:ResolvedFfmpegPath = 'fake-ffmpeg'
$mediaInfo = [pscustomobject]@{{
    Container = 'mp4'
    ContainerLongName = 'MP4'
    DurationSeconds = 120.0
    DurationText = '00:02:00'
    SizeText = '1 MB'
    OverallBitrateText = '1000 kbps'
    VideoCodec = 'h264'
    Resolution = '720x576'
    DisplayAspectRatio = '4:3'
    SampleAspectRatio = '1:1'
    FrameRate = 25.0
    FrameRateText = '25 fps'
    FrameCount = 3000
    VideoBitrateText = '900 kbps'
    AudioCodec = 'aac'
    AudioChannels = 2
    AudioSampleRateHz = 48000
    AudioBitrateText = '128 kbps'
}}
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    DisplayOutputName = 'clip.mp4'
    MediaInfo = $mediaInfo
}}
$script:PlanItems = @($item)
$rowIndex = $grid.Rows.Add()
$row = $grid.Rows[$rowIndex]
$row.Cells['SourceName'].Value = 'clip.mp4'
$row.Cells['OutputName'].Value = 'clip.mp4'
$row.Cells['Status'].Value = 'queued'
$row.Selected = $true
$grid.CurrentCell = $row.Cells['SourceName']
Update-PreviewTrimPanel
$script:AutoPreviewCalls = 0
$script:LastPreviewTime = ''
$script:LastPreviewStatus = ''
function Invoke-PreviewFrame {{
    param(
        [bool]$SilentErrors = $false,
        [bool]$LogAction = $true,
        [string]$StatusPrefix = 'Preview Frame'
    )
    $script:AutoPreviewCalls += 1
    $script:LastPreviewTime = $previewTimeTextBox.Text
    $script:LastPreviewStatus = $StatusPrefix
}}
$autoPreviewCheckBox.Checked = $true
Set-PreviewPositionSeconds -Seconds 12 -RefreshImage:$true
$pendingAfterOn = [bool]$script:PreviewAutoPending
Invoke-PendingAutoPreview
$callsAfterOn = $script:AutoPreviewCalls
$timeAfterOn = $script:LastPreviewTime
$statusAfterOn = $script:LastPreviewStatus
$autoPreviewCheckBox.Checked = $false
Set-PreviewPositionSeconds -Seconds 14 -RefreshImage:$true
$pendingAfterOff = [bool]$script:PreviewAutoPending
Invoke-PendingAutoPreview
Write-Output 'JSON_START'
[pscustomobject]@{{
    CallsAfterOn = $callsAfterOn
    FinalCalls = $script:AutoPreviewCalls
    TimeAfterOn = $timeAfterOn
    StatusAfterOn = $statusAfterOn
    PendingAfterOn = $pendingAfterOn
    PendingAfterOff = $pendingAfterOff
    AutoPreviewChecked = [bool]$autoPreviewCheckBox.Checked
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-auto-preview-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["CallsAfterOn"] == 1
    assert payload["FinalCalls"] == 1
    assert payload["TimeAfterOn"] == "00:00:12"
    assert payload["StatusAfterOn"] == "Auto preview"
    assert payload["PendingAfterOn"] is True
    assert payload["PendingAfterOff"] is False
    assert payload["AutoPreviewChecked"] is False


def test_vhs_gui_preview_cache_uses_png_frames(tmp_path: Path) -> None:
    source = tmp_path / "clip.mp4"
    source.write_text("source", encoding="utf-8")
    output_dir = tmp_path / "out"

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(tmp_path)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
$item = [pscustomobject]@{{
    SourceName = 'clip.mp4'
    SourcePath = '{ps_quote(source)}'
    OutputPath = '{ps_quote(output_dir / "clip.mp4")}'
    DisplayOutputName = 'clip.mp4'
    Status = 'queued'
}}
$previewPath = Get-PreviewFramePath -Item $item
Write-Output 'JSON_START'
[pscustomobject]@{{
    PreviewPath = $previewPath
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-preview-cache-path-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    assert payload["PreviewPath"].endswith(".png")


def test_vhs_gui_scan_keeps_plan_items_flat_for_direct_video_files(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    output_dir = input_dir / "vhs-mp4-output"
    input_dir.mkdir()
    (input_dir / "alpha.mp4").write_text("source", encoding="utf-8")
    (input_dir / "beta.avi").write_text("source", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
$inputTextBox.Text = '{ps_quote(input_dir)}'
$outputTextBox.Text = '{ps_quote(output_dir)}'
Scan-InputFolder
$items = @($script:PlanItems | ForEach-Object {{
    $sourceProperty = $_.PSObject.Properties['SourceName']
    [pscustomobject]@{{
        HasSourceName = [bool]$sourceProperty
        SourceName = if ($sourceProperty) {{ [string]$sourceProperty.Value }} else {{ '' }}
    }}
}})
Write-Output 'JSON_START'
[pscustomobject]@{{
    Rows = $grid.Rows.Count
    PlanItems = $script:PlanItems.Count
    Status = $statusValueLabel.Text
    Items = $items
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-scan-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    assert "JSON_START" in run.stdout
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    names = {item["SourceName"] for item in payload["Items"]}

    assert payload["Rows"] == 2
    assert payload["PlanItems"] == 2
    assert names == {"alpha.mp4", "beta.avi"}
    assert all(item["HasSourceName"] for item in payload["Items"])


def test_vhs_gui_imports_direct_dropped_files_into_plan(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    input_dir.mkdir()
    output_dir = input_dir / "vhs-mp4-output"
    (input_dir / "alpha.mp4").write_text("source", encoding="utf-8")
    (input_dir / "beta.avi").write_text("source", encoding="utf-8")
    (input_dir / "notes.txt").write_text("ignore", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
Import-DroppedPaths -Paths @('{ps_quote(input_dir / "alpha.mp4")}', '{ps_quote(input_dir / "beta.avi")}', '{ps_quote(input_dir / "notes.txt")}')
$items = @($script:PlanItems | Select-Object SourceName, DisplayOutputName, Status)
Write-Output 'JSON_START'
[pscustomobject]@{{
    Rows = $grid.Rows.Count
    PlanItems = $script:PlanItems.Count
    InputDir = $inputTextBox.Text
    OutputDir = $outputTextBox.Text
    Status = $statusValueLabel.Text
    Items = $items
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-drop-files-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    names = {item["SourceName"] for item in payload["Items"]}

    assert payload["Rows"] == 2
    assert payload["PlanItems"] == 2
    assert payload["InputDir"] == str(input_dir)
    assert payload["OutputDir"] == str(output_dir)
    assert names == {"alpha.mp4", "beta.avi"}
    assert "Drop import" in payload["Status"]


def test_vhs_gui_imports_dropped_folder_and_scans_supported_videos(tmp_path: Path) -> None:
    input_dir = tmp_path / "input"
    nested_dir = input_dir / "Kaseta 01"
    nested_dir.mkdir(parents=True)
    output_dir = input_dir / "vhs-mp4-output"
    output_dir.mkdir()
    (input_dir / "root_video.mp4").write_text("source", encoding="utf-8")
    (nested_dir / "rodjendan.avi").write_text("source", encoding="utf-8")
    (nested_dir / "notes.txt").write_text("ignore", encoding="utf-8")
    (output_dir / "existing.mp4").write_text("ignore", encoding="utf-8")

    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = f"""
Import-DroppedPaths -Paths @('{ps_quote(input_dir)}')
$items = @($script:PlanItems | Select-Object SourceName, DisplayOutputName, Status)
Write-Output 'JSON_START'
[pscustomobject]@{{
    Rows = $grid.Rows.Count
    PlanItems = $script:PlanItems.Count
    InputDir = $inputTextBox.Text
    OutputDir = $outputTextBox.Text
    Items = $items
}} | ConvertTo-Json -Depth 6
try {{ $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() }} catch {{}}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-drop-folder-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])
    names = {item["SourceName"] for item in payload["Items"]}

    assert payload["Rows"] == 2
    assert payload["PlanItems"] == 2
    assert payload["InputDir"] == str(input_dir)
    assert payload["OutputDir"] == str(output_dir)
    assert names == {"root_video.mp4", "Kaseta 01\\rodjendan.avi"}


def test_vhs_gui_drag_visual_state_highlights_drop_target(tmp_path: Path) -> None:
    gui_script = (ROOT / "scripts" / "optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")
    module_path = ps_quote(ROOT / "scripts" / "optimize-vhs-mp4-core.psm1")
    gui_script = gui_script.replace(
        '$modulePath = Join-Path $PSScriptRoot "optimize-vhs-mp4-core.psm1"',
        f"$modulePath = '{module_path}'",
    )

    probe = """
$beforeStatus = 'Mirno stanje'
Set-StatusText $beforeStatus
$defaultGridBackColor = $grid.BackgroundColor.ToArgb()
$defaultHelpForeColor = $inputHelpLabel.ForeColor.ToArgb()
Set-DragDropVisualState -Active
$activeStatus = $statusValueLabel.Text
$activeGridBackColor = $grid.BackgroundColor.ToArgb()
$activeHelpForeColor = $inputHelpLabel.ForeColor.ToArgb()
$activeDragState = [bool]$script:DragDropActive
Set-DragDropVisualState -Active:$false
Write-Output 'JSON_START'
[pscustomobject]@{
    BeforeStatus = $beforeStatus
    FinalStatus = $statusValueLabel.Text
    DefaultGridBackColor = $defaultGridBackColor
    ActiveGridBackColor = $activeGridBackColor
    DefaultHelpForeColor = $defaultHelpForeColor
    ActiveHelpForeColor = $activeHelpForeColor
    ActiveStatus = $activeStatus
    ActiveDragState = $activeDragState
    FinalDragState = [bool]$script:DragDropActive
} | ConvertTo-Json -Depth 6
try { $script:NotifyIcon.Visible = $false; $script:NotifyIcon.Dispose() } catch {}
""".strip()

    gui_script = gui_script.replace("[void]$form.ShowDialog()", probe)
    probe_script = tmp_path / "gui-drag-visual-probe.ps1"
    probe_script.write_text(gui_script, encoding="utf-8")

    run = subprocess.run(
        [
            "powershell",
            "-NoProfile",
            "-STA",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(probe_script),
        ],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
        timeout=120,
    )

    assert run.returncode == 0, run.stderr
    payload = json.loads(run.stdout.split("JSON_START", 1)[1])

    assert payload["ActiveDragState"] is True
    assert payload["FinalDragState"] is False
    assert "Pusti" in payload["ActiveStatus"]
    assert payload["ActiveGridBackColor"] != payload["DefaultGridBackColor"]
    assert payload["ActiveHelpForeColor"] != payload["DefaultHelpForeColor"]
    assert payload["FinalStatus"] == payload["BeforeStatus"]


def test_vhs_gui_contains_help_about_and_update_tokens() -> None:
    script = Path("scripts/optimize-vhs-mp4-gui.ps1").read_text(encoding="utf-8")

    for token in [
        "MenuStrip",
        "Help",
        "About VHS MP4 Optimizer",
        "Check for Updates",
        "Open User Guide",
        "Current version",
        "Install type",
        "Install path",
        "GitHub repo",
        "Release tag",
        "function Get-AppMetadataPath",
        "function Get-UpdateStatePath",
        "function Get-VhsMp4ApplicationMetadata",
        "function Get-VhsMp4InstallType",
        "function Get-VhsMp4LatestReleaseInfo",
        "function Compare-VhsMp4ReleaseTag",
        "function Test-ShouldAutoCheckForUpdates",
        "function Save-UpdateCheckState",
        "function Show-AboutDialog",
        "function Invoke-UpdateCheck",
        "function Start-ConfirmedAppUpdate",
        "function Open-UserGuide",
        "api.github.com/repos/joes021/vhs-mp4-optimizer/releases/latest",
        "browser_download_url",
        "setup.exe",
        "portable zip",
    ]:
        assert token in script, f"missing help/update token: {token}"
