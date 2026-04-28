# VHS MP4 Optimizer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Windows GUI tool that recompresses already-created large VHS `.mp4` files and DV/MSDV `.avi` files into smaller customer-delivery MP4 files.

**Architecture:** Add a focused PowerShell module for VHS MP4 optimization, with CLI and WinForms GUI wrappers calling the shared module. Scanning, FFmpeg arguments, FFmpeg progress output, ffprobe duration lookup, logging, skip behavior, and process handling stay testable.

**Tech Stack:** PowerShell, WinForms, FFmpeg, Python `pytest`

---

### Task 1: Core VHS MP4 Batch Module

**Files:**
- Create: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Create: `scripts/optimize-vhs-mp4-core.psm1`

- [x] Write failing tests for scan, skip, quality modes, and batch execution.
- [x] Run the test and verify RED.
- [x] Implement minimal module.
- [x] Run the test and verify GREEN.

### Task 2: CLI Wrapper

**Files:**
- Create: `tests/test_optimize_vhs_mp4_behavior.py`
- Create: `scripts/optimize-vhs-mp4.ps1`

- [x] Write failing CLI behavior test.
- [x] Run the test and verify RED.
- [x] Implement wrapper.
- [x] Run the test and verify GREEN.

### Task 3: WinForms GUI And Launcher

**Files:**
- Create: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Create: `tests/test_optimize_vhs_mp4_gui_launcher_tokens.py`
- Create: `scripts/optimize-vhs-mp4-gui.ps1`
- Create: `scripts/optimize-vhs-mp4-gui.bat`

- [x] Write failing GUI token tests.
- [x] Run the tests and verify RED.
- [x] Implement GUI and launcher.
- [x] Run the tests and verify GREEN.

### Task 4: Final Verification

- [x] Run focused VHS optimizer tests.
- [x] Run a real tiny FFmpeg smoke test.

### Task 5: AVI Input And Per-File Progress

- [x] Add failing tests for `.avi` discovery and `.avi` to `.mp4` output naming.
- [x] Add failing tests for FFmpeg `-progress` arguments and ffprobe path resolution.
- [x] Extend the core module to accept `.mp4` and `.avi` inputs.
- [x] Add GUI controls for current-file progress percentage and ETA.
- [x] Run focused tests and real AVI smoke verification.
