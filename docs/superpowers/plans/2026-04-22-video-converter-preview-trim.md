# Video Converter Preview Trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add per-file preview frame and manual trim start/end support to the Windows Video Converter workflow.

**Architecture:** Keep `scripts/optimize-vhs-mp4-core.psm1` as the behavior layer and make the GUI pass per-file trim data into existing conversion paths. The right WinForms panel becomes `Preview / Properties`, while batch planning, FFmpeg argument generation, split output, progress, reports, and release packaging continue through existing patterns.

**Tech Stack:** PowerShell 5+ / WinForms, FFmpeg/ffprobe, Python pytest, Windows release folder scripts.

---

## File Map

- Modify: `scripts/optimize-vhs-mp4-core.psm1`
  - Add time parsing, trim validation, preview-frame generation, trim-aware FFmpeg args, trim-aware report lines, and exports.
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
  - Replace the right `infoBox`-only panel with preview controls plus existing properties text. Store trim fields on each plan item.
- Modify: `scripts/optimize-vhs-mp4.ps1`
  - Add optional CLI `TrimStart` / `TrimEnd` parameters for whole-folder command-line use.
- Modify: `scripts/build-vhs-mp4-release.ps1`
  - Update README text for preview/trim and rebuild release package.
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
  - Add user-facing preview/trim instructions.
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
  - Add TDD coverage for time parsing, trim windows, FFmpeg args, preview frame, and reports.
- Modify: `tests/test_optimize_vhs_mp4_behavior.py`
  - Add CLI coverage for trim parameters.
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
  - Add GUI token coverage for controls, trim storage, preview calls, and table column.
- Modify: `tests/test_vhs_release_package.py`
  - Add release README/package tokens for preview/trim.

## Task 1: Core Time Parsing And Trim Window

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing tests for time parsing and trim validation**

Add a pytest that imports the module and runs PowerShell assertions similar to:

```powershell
$a = Convert-VhsMp4TimeTextToSeconds -Value '01:02:03'
$b = Convert-VhsMp4TimeTextToSeconds -Value '12:34'
$c = Convert-VhsMp4TimeTextToSeconds -Value '90.5'
$window = Get-VhsMp4TrimWindow -TrimStart '00:01:00' -TrimEnd '00:03:30'
$bad = $false
try { Get-VhsMp4TrimWindow -TrimStart '00:03:30' -TrimEnd '00:01:00' | Out-Null } catch { $bad = $true }
[pscustomobject]@{
  A = $a
  B = $b
  C = $c
  Duration = $window.DurationSeconds
  BadRejected = $bad
} | ConvertTo-Json -Compress
```

Assert:

- `A == 3723`
- `B == 754`
- `C == 90.5`
- `Duration == 150`
- `BadRejected is True`

- [ ] **Step 2: Run the focused failing test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "trim_window" -v
```

Expected: FAIL because the trim helper functions do not exist.

- [ ] **Step 3: Implement minimal core helpers**

Add functions near the existing formatting helpers in `scripts/optimize-vhs-mp4-core.psm1`:

- `Convert-VhsMp4TimeTextToSeconds`
- `Format-VhsMp4FfmpegTime`
- `Get-VhsMp4TrimWindow`

Behavior:

- blank/null returns `$null`
- `HH:MM:SS`, `MM:SS`, and numeric seconds are accepted
- commas are accepted as decimal separators
- negative values are rejected
- `End <= Start` is rejected when both are present
- returned object includes `StartSeconds`, `EndSeconds`, `DurationSeconds`, `StartText`, `EndText`, `DurationText`, and `Summary`

- [ ] **Step 4: Export helper functions**

Add new helper names to `Export-ModuleMember` in `scripts/optimize-vhs-mp4-core.psm1`.

- [ ] **Step 5: Run the focused test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "trim_window" -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 tests/test_optimize_vhs_mp4_core_behavior.py
git commit -m "feat: add trim time parsing"
```

## Task 2: Trim-Aware FFmpeg Arguments

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing tests for FFmpeg trim args**

Add assertions for:

- `Get-VhsMp4FfmpegArguments -TrimStart '00:01:00'`
- `Get-VhsMp4FfmpegArguments -TrimEnd '00:02:30'`
- `Get-VhsMp4FfmpegArguments -TrimStart '00:01:00' -TrimEnd '00:02:30'`
- `Get-VhsMp4FfmpegArguments -TrimStart '00:01:00' -TrimEnd '00:02:30' -SplitOutput -MaxPartGb 3.8`

Expected command shapes:

- start-only includes `-ss 00:01:00`
- end-only includes `-to 00:02:30`
- start+end includes `-ss 00:01:00` and `-t 00:01:30`
- split output still includes `-f segment`, `-segment_format mp4`, and `part%03d`

- [ ] **Step 2: Run the focused failing test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "ffmpeg_trim_args" -v
```

Expected: FAIL because `Get-VhsMp4FfmpegArguments` does not accept trim parameters.

- [ ] **Step 3: Extend `Get-VhsMp4FfmpegArguments`**

Modify `scripts/optimize-vhs-mp4-core.psm1` around `Get-VhsMp4FfmpegArguments`:

- add `[string]$TrimStart`
- add `[string]$TrimEnd`
- compute `$trimWindow = Get-VhsMp4TrimWindow -TrimStart $TrimStart -TrimEnd $TrimEnd`
- insert input trim args after `-y` and before `-i`
- use `-ss` for start
- use `-to` for end-only
- use `-t` for start+end duration

Keep `SampleSeconds` as an output-duration cap for sample conversion. If both trim and sample are present, `SampleSeconds` should still add a later `-t 120` only for sample workflows; if this creates duplicate `-t`, document in the test whether sample wins or skip sample+trim until Task 6.

- [ ] **Step 4: Pass trim through process entry points**

Add optional `TrimStart` / `TrimEnd` parameters to:

- `Start-VhsMp4FileProcess`
- `Invoke-VhsMp4File`
- `Invoke-VhsMp4Batch`
- `New-VhsMp4RunContext` if context-level trim is needed for CLI/defaults

For batch plan items, prefer per-item properties when present:

```powershell
$trimStart = if ($item.PSObject.Properties.Name -contains "TrimStartText") { $item.TrimStartText } else { $TrimStart }
$trimEnd = if ($item.PSObject.Properties.Name -contains "TrimEndText") { $item.TrimEndText } else { $TrimEnd }
```

- [ ] **Step 5: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "ffmpeg_trim_args or sample_conversion" -v
```

Expected: PASS, and existing sample conversion tests remain green.

- [ ] **Step 6: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 tests/test_optimize_vhs_mp4_core_behavior.py
git commit -m "feat: add trim ffmpeg arguments"
```

## Task 3: Preview Frame Generation

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing preview-frame test**

Use the existing fake FFmpeg pattern. The fake process should log arguments and create the requested output image path.

PowerShell shape:

```powershell
$previewPath = Join-Path '{output_dir}' 'preview.jpg'
$result = New-VhsMp4PreviewFrame -SourcePath '{source}' -OutputPath $previewPath -FfmpegPath '{fake_ffmpeg}' -PreviewTime '00:00:10'
[pscustomobject]@{
  OutputPath = $result.OutputPath
  Exists = Test-Path -LiteralPath $previewPath
} | ConvertTo-Json -Compress
```

Assert:

- output path exists
- fake FFmpeg log includes `-ss`, `00:00:10`, `-frames:v`, `1`, `-q:v`

- [ ] **Step 2: Run the focused failing test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "preview_frame" -v
```

Expected: FAIL because `New-VhsMp4PreviewFrame` does not exist.

- [ ] **Step 3: Implement `New-VhsMp4PreviewFrame`**

Add core function:

```powershell
function New-VhsMp4PreviewFrame {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [string]$FfmpegPath = "ffmpeg",
        [string]$PreviewTime = "00:00:05"
    )
    ...
}
```

Use arguments:

```powershell
@("-hide_banner", "-y", "-ss", $previewTimeText, "-i", $SourcePath, "-map", "0:v:0", "-frames:v", "1", "-q:v", "3", $OutputPath)
```

Create the output parent directory before running. Return an object with `OutputPath`, `PreviewTime`, `ExitCode`, and `ErrorText`.

- [ ] **Step 4: Export function and run tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "preview_frame or trim_window or ffmpeg_trim_args" -v
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 tests/test_optimize_vhs_mp4_core_behavior.py
git commit -m "feat: add preview frame generation"
```

## Task 4: Report And CLI Trim Support

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `tests/test_optimize_vhs_mp4_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Modify: `scripts/optimize-vhs-mp4.ps1`

- [ ] **Step 1: Write failing report and CLI tests**

Core report test:

- create a fake summary item with `TrimSummary = "00:01:00 - 00:02:30"`
- call `Write-VhsMp4CustomerReport`
- assert report includes trim information

CLI test:

- run `scripts/optimize-vhs-mp4.ps1` with `-TrimStart 00:01:00 -TrimEnd 00:02:30`
- assert fake FFmpeg log includes expected `-ss` and `-t`

- [ ] **Step 2: Run failing tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_behavior.py tests/test_optimize_vhs_mp4_core_behavior.py -k "trim_cli or trim_report" -v
```

Expected: FAIL.

- [ ] **Step 3: Update report writer**

In `Write-VhsMp4CustomerReport`, add a trim line per file when item/result has a trim summary:

```powershell
if ($item.TrimSummary) {
    $lines.Add("  Trim: $($item.TrimSummary)")
}
```

Use defensive property checks because older result objects will not have these fields.

- [ ] **Step 4: Update CLI script**

Add parameters to `scripts/optimize-vhs-mp4.ps1`:

```powershell
[string]$TrimStart = "",
[string]$TrimEnd = ""
```

Pass them into `Invoke-VhsMp4Batch`.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_behavior.py tests/test_optimize_vhs_mp4_core_behavior.py -k "trim_cli or trim_report" -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 scripts/optimize-vhs-mp4.ps1 tests/test_optimize_vhs_mp4_behavior.py tests/test_optimize_vhs_mp4_core_behavior.py
git commit -m "feat: add trim reporting and cli options"
```

## Task 5: GUI Preview / Properties Panel

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing GUI token tests**

Add tokens:

- `Preview / Properties`
- `previewPictureBox`
- `previewTimeTextBox`
- `previewFrameButton`
- `openVideoButton`
- `trimStartTextBox`
- `trimEndTextBox`
- `applyTrimButton`
- `clearTrimButton`
- `New-VhsMp4PreviewFrame`
- `Get-VhsMp4TrimWindow`
- `TrimSummary`
- `Range`
- `Open-SelectedVideo`
- `Invoke-PreviewFrame`
- `Apply-SelectedTrim`
- `Clear-SelectedTrim`

- [ ] **Step 2: Run failing GUI token test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -v
```

Expected: FAIL.

- [ ] **Step 3: Add right-panel controls**

In `scripts/optimize-vhs-mp4-gui.ps1`, replace the direct `Panel2.Controls.Add($infoBox)` block around the existing `mainSplit` section with:

- right `TableLayoutPanel`
- `PictureBox` for preview
- preview controls row
- trim controls row
- existing `RichTextBox` as the bottom/fill properties area

Keep `infoBox` variable name so existing `Update-MediaInfoPanel` continues to work.

- [ ] **Step 4: Add helper functions**

Add GUI functions near media-info helpers:

- `Get-SelectedPlanItem`
- `Get-PreviewFramePath`
- `Invoke-PreviewFrame`
- `Open-SelectedVideo`
- `Load-SelectedTrimFields`
- `Apply-SelectedTrim`
- `Clear-SelectedTrim`
- `Update-PreviewTrimPanel`

Important implementation details:

- dispose previous `PictureBox.Image` before loading a new file
- store preview frames under output folder, for example `vhs-mp4-output\preview-cache`
- use `Start-Process -FilePath $item.SourcePath` for `Open Video`
- call `Get-VhsMp4TrimWindow` inside `Apply-SelectedTrim`
- update row cells after applying/clearing trim

- [ ] **Step 5: Add table trim/range column**

Add a `Range` or `Trim` column to the grid creation. In row population, default it to `--`. When trim is applied, set it to the trim summary.

- [ ] **Step 6: Wire event handlers**

Add click handlers:

- `$previewFrameButton.Add_Click({ Invoke-PreviewFrame })`
- `$openVideoButton.Add_Click({ Open-SelectedVideo })`
- `$applyTrimButton.Add_Click({ Apply-SelectedTrim })`
- `$clearTrimButton.Add_Click({ Clear-SelectedTrim })`

Update `$grid.Add_SelectionChanged` to call both `Update-MediaInfoPanel` and `Update-PreviewTrimPanel`.

- [ ] **Step 7: Update action button enablement**

In `Update-ActionButtons`, enable preview/trim buttons based on:

- not running
- selected plan item exists
- resolved FFmpeg path exists for preview

Keep trim text boxes editable only when a row is selected and batch is not running.

- [ ] **Step 8: Run GUI parser and token tests**

Run:

```powershell
$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path 'scripts/optimize-vhs-mp4-gui.ps1'), [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count -gt 0) { $errors | ForEach-Object { $_.ToString() }; exit 1 } else { 'GUI parser OK' }
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -v
```

Expected: parser OK and tests PASS.

- [ ] **Step 9: Commit**

```powershell
git add scripts/optimize-vhs-mp4-gui.ps1 tests/test_optimize_vhs_mp4_gui_tokens.py
git commit -m "feat: add preview trim panel"
```

## Task 6: Batch Uses Per-File GUI Trim

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Write failing per-file batch trim test**

In core tests, create a plan where one item has `TrimStartText` / `TrimEndText`, invoke batch with fake FFmpeg, and assert only that item gets trim args.

- [ ] **Step 2: Run failing test**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "per_file_trim" -v
```

Expected: FAIL if batch does not yet read per-item trim fields.

- [ ] **Step 3: Implement per-file trim in batch loop**

In `Invoke-VhsMp4Batch` and `Start-NextQueuedItem`, pass each plan item's trim fields to conversion. Do not use global GUI settings for trim unless intentionally added as a CLI/default behavior.

- [ ] **Step 4: Update estimates for trimmed duration**

When a plan item has media duration and trim duration, use trim duration in `Get-VhsMp4EstimatedOutputInfo`. Refresh `EstimatedSize` and `UsbNote` after `Apply Trim` / `Clear Trim`.

- [ ] **Step 5: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "trim or gui" -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 scripts/optimize-vhs-mp4-gui.ps1 tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py
git commit -m "feat: apply per-file trim in batch"
```

## Task 7: Docs, Release, And Shortcut Package

**Files:**
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `tests/test_vhs_release_package.py`
- Generated/modify: `release/VHS MP4 Optimizer/*`

- [ ] **Step 1: Write failing release/doc token tests**

Add expected tokens:

- `Preview Frame`
- `Open Video`
- `Start`
- `End`
- `Apply Trim`
- `Clear Trim`
- `trim`

- [ ] **Step 2: Run failing release tests**

Run:

```powershell
python -m pytest tests/test_vhs_release_package.py -v
```

Expected: FAIL until README/build docs are updated.

- [ ] **Step 3: Update user docs and release builder**

Update:

- `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- README text embedded in `scripts/build-vhs-mp4-release.ps1`

Explain the workflow:

1. scan files
2. select file
3. preview/open video
4. set start/end
5. apply trim
6. start conversion

- [ ] **Step 4: Rebuild release**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

If the release folder is locked by a running program, close the app and rerun. If only a single script needs refresh during development, copy that script manually, but final verification should use the builder.

- [ ] **Step 5: Run release tests**

Run:

```powershell
python -m pytest tests/test_vhs_release_package.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md scripts/build-vhs-mp4-release.ps1 tests/test_vhs_release_package.py "release/VHS MP4 Optimizer"
git commit -m "docs: add preview trim workflow"
```

## Task 8: Final Verification

**Files:**
- All touched files

- [ ] **Step 1: Run focused video converter tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_optimize_vhs_mp4_gui_launcher_tokens.py tests/test_vhs_release_package.py -v
```

Expected: all tests PASS.

- [ ] **Step 2: Run PowerShell parser checks**

Run:

```powershell
$files = @(
  'scripts/optimize-vhs-mp4-core.psm1',
  'scripts/optimize-vhs-mp4.ps1',
  'scripts/optimize-vhs-mp4-gui.ps1',
  'scripts/build-vhs-mp4-release.ps1',
  'release/VHS MP4 Optimizer/scripts/optimize-vhs-mp4-core.psm1',
  'release/VHS MP4 Optimizer/scripts/optimize-vhs-mp4.ps1',
  'release/VHS MP4 Optimizer/scripts/optimize-vhs-mp4-gui.ps1'
)
foreach ($file in $files) {
  $tokens=$null; $errors=$null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file), [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) { Write-Error "$file parser failed"; $errors | ForEach-Object { $_.ToString() }; exit 1 }
}
'PowerShell parser OK'
```

Expected: `PowerShell parser OK`.

- [ ] **Step 3: Run diff checks**

Run:

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; only intended changes before final commit, or clean after commits.

- [ ] **Step 4: Smoke test real scan path if available**

If `F:\Veliki avi` exists, run the existing headless/scan smoke approach or launch the app manually and verify:

- files are detected
- selecting a row updates preview/properties controls
- `Preview Frame` creates a visible image
- `Apply Trim` updates the row range
- `Start Conversion` still enables only when ready

- [ ] **Step 5: Final commit and push**

If there are remaining verification-only or release changes:

```powershell
git add <remaining-files>
git commit -m "feat: complete preview trim workflow"
git push
```

Expected: branch pushed to `origin/codex/video-converter-phase1`.
