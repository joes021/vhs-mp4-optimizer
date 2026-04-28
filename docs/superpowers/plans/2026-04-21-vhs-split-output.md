# VHS Split Output Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional split mode that creates customer-delivery MP4 parts around a chosen maximum size, defaulting to 3.8 GB.

**Architecture:** Keep split logic in `scripts/optimize-vhs-mp4-core.psm1` so CLI and GUI share the same behavior. Use FFmpeg's segment muxer to create valid MP4 files named `base-part001.mp4`, `base-part002.mp4`, and so on; never byte-split an MP4.

**Tech Stack:** PowerShell, WinForms, FFmpeg, Python pytest regression tests.

---

### Task 1: Core Split Planning And FFmpeg Arguments

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [x] Write a failing test that verifies split plans use `part001` for skip detection and `part%03d` for FFmpeg output.
- [x] Write a failing test that verifies FFmpeg arguments include the segment muxer, `segment_time`, `segment_start_number 1`, and MP4 segment options.
- [x] Add shared helpers for split output naming, video max bitrate, and segment duration calculation.
- [x] Thread `SplitOutput` and `MaxPartGb` through plan, context, file invocation, and batch invocation.
- [x] Run the focused core tests.

### Task 2: CLI And GUI Wiring

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_behavior.py`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4.ps1`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [x] Write failing tests for CLI split flags and GUI split controls.
- [x] Add `-SplitOutput` and `-MaxPartGb` to the CLI script.
- [x] Add `Split output` checkbox and `Max part GB` textbox to the GUI settings row.
- [x] Validate GUI max part size only when split mode is enabled.
- [x] Pass split settings into scan, context creation, and per-file FFmpeg process start.

### Task 3: Docs And Verification

**Files:**
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `docs/superpowers/specs/2026-04-21-vhs-mp4-optimizer-design.md`

- [x] Document the split option and explain that parts are valid MP4 files.
- [x] Run all focused pytest tests.
- [x] Run PowerShell parser validation for the scripts.
- [x] Run `git diff --check`.
- [x] Commit the completed feature.
