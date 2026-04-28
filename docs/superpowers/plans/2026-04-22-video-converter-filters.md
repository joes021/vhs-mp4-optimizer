# Video Converter Filters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add global video/audio filter controls to the Windows Video Converter for common VHS/DVD/customer-delivery cleanup.

**Architecture:** Keep the shared PowerShell core as the only FFmpeg argument builder. GUI and CLI collect user choices and pass them into the same core functions. Tests are written first for each behavior, then implementation is added in small commits.

**Tech Stack:** PowerShell module + WinForms GUI, FFmpeg filters, pytest static/behavior tests, release packaging script.

---

### Task 1: Core Filter Arguments

**Files:**
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Test: `tests/test_optimize_vhs_mp4_core_behavior.py`

- [ ] **Step 1: Write failing tests**

Add tests showing:

- `Get-VhsMp4FfmpegArguments` emits `-vf yadif=0:-1:0,hqdn3d=1.5:1.5:6:6,transpose=1,scale=-2:720:flags=lanczos`
- `AudioNormalize` emits `-af loudnorm=I=-16:TP=-1.5:LRA=11`
- split output still uses segment muxer after filters

- [ ] **Step 2: Run focused test and verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "filter" -v
```

Expected: fail because filter parameters/functions do not exist yet.

- [ ] **Step 3: Implement minimal core support**

Add core helpers:

- `Get-VhsMp4VideoFilterChain`
- `Get-VhsMp4AudioFilterChain`
- `Get-VhsMp4FilterSummary`

Add parameters through `Get-VhsMp4FfmpegArguments`, `New-VhsMp4RunContext`, `Start-VhsMp4FileProcess`, `Invoke-VhsMp4File`, and `Invoke-VhsMp4Batch`.

- [ ] **Step 4: Run focused test and verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "filter" -v
```

- [ ] **Step 5: Commit**

```powershell
git add scripts/optimize-vhs-mp4-core.psm1 tests/test_optimize_vhs_mp4_core_behavior.py
git commit -m "feat: add video filter arguments"
```

### Task 2: CLI Parameters

**Files:**
- Modify: `scripts/optimize-vhs-mp4.ps1`
- Test: `tests/test_optimize_vhs_mp4_behavior.py`

- [ ] **Step 1: Write failing CLI test**

Add a test proving CLI passes `Deinterlace`, `Denoise`, `RotateFlip`, `ScaleMode`, and `AudioNormalize` into FFmpeg arguments.

- [ ] **Step 2: Verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_behavior.py -k "filter" -v
```

- [ ] **Step 3: Add CLI params and pass-through**

Expose the same options as core, with `ValidateSet` where appropriate.

- [ ] **Step 4: Verify GREEN**

Run the same focused command.

- [ ] **Step 5: Commit**

```powershell
git add scripts/optimize-vhs-mp4.ps1 tests/test_optimize_vhs_mp4_behavior.py
git commit -m "feat: add cli filter options"
```

### Task 3: GUI Filter Row

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Test: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Write failing GUI token test**

Require tokens for:

- `Video filters`
- `deinterlaceComboBox`
- `denoiseComboBox`
- `rotateFlipComboBox`
- `scaleModeComboBox`
- `audioNormalizeCheckBox`
- core filter parameter pass-through

- [ ] **Step 2: Verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -v
```

- [ ] **Step 3: Add compact GUI controls**

Add a second settings flow row under quality settings, keep fixed input widths, and disable controls while conversion runs.

- [ ] **Step 4: Pass settings into sample and batch**

Include filter settings in `Get-Settings`, `Invoke-TestSample`, `Start-BatchSession`, and `Start-NextQueuedItem`.

- [ ] **Step 5: Verify GREEN**

Run GUI token tests and PowerShell parser on GUI script.

- [ ] **Step 6: Commit**

```powershell
git add scripts/optimize-vhs-mp4-gui.ps1 tests/test_optimize_vhs_mp4_gui_tokens.py
git commit -m "feat: add gui filter controls"
```

### Task 4: Docs and Release

**Files:**
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `tests/test_vhs_release_package.py`
- Generated: `release/VHS MP4 Optimizer`

- [ ] **Step 1: Write failing release/doc test**

Require release README tokens for `Video filters`, `Deinterlace`, `Denoise`, `Rotate/flip`, `Scale`, and `Audio normalize`.

- [ ] **Step 2: Verify RED**

Run:

```powershell
python -m pytest tests/test_vhs_release_package.py -v
```

- [ ] **Step 3: Update docs and builder**

Explain when to use each filter and that originals are never changed.

- [ ] **Step 4: Rebuild release**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

- [ ] **Step 5: Verify GREEN and commit**

Run release tests, then commit docs/release updates.

### Task 5: Final Verification

- [ ] Run focused video converter tests:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_optimize_vhs_mp4_gui_launcher_tokens.py tests/test_vhs_release_package.py -v
```

- [ ] Run PowerShell parser checks for source and release scripts.
- [ ] Run `git diff --check`.
- [ ] Push branch.
