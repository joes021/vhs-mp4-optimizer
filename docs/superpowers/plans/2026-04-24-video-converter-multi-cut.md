# Video Converter Multi-Cut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Omoguciti da jedan video fajl zadrzi vise rucno odabranih segmenata u jednom izlaznom MP4 fajlu.

**Architecture:** Jezgro dobija normalizaciju vise trim segmenata i FFmpeg `filter_complex` + `concat` tok za 2+ segmenta, uz zadrzavanje postojeceg single-trim ponasanja. GUI dobija listu segmenata po izabranom fajlu, dodavanje/uklanjanje segmenata i prikaz sazetka koji se koristi i za procenu velicine i za batch obradu.

**Tech Stack:** PowerShell, WinForms, FFmpeg, pytest

---

### Task 1: Trim Segment Model

**Files:**
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Test: `tests/test_optimize_vhs_mp4_core_behavior.py`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Add `Get-VhsMp4TrimSegments` and segment summary helpers**
- [ ] **Step 4: Run test to verify it passes**

### Task 2: FFmpeg Multi-Cut Build Path

**Files:**
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Test: `tests/test_optimize_vhs_mp4_core_behavior.py`

- [ ] **Step 1: Keep failing FFmpeg multi-cut test red**
- [ ] **Step 2: Extend `Get-VhsMp4FfmpegArguments` for `TrimSegments` and `SourceHasAudio`**
- [ ] **Step 3: Reuse existing single-trim path for 0/1 segment and switch to `filter_complex` concat for 2+**
- [ ] **Step 4: Run targeted tests and keep old trim/split behavior green**

### Task 3: Batch + Estimates Integration

**Files:**
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Test: `tests/test_optimize_vhs_mp4_core_behavior.py`

- [ ] **Step 1: Keep failing batch multi-cut test red**
- [ ] **Step 2: Read per-item `TrimSegments`, `HasAudio`, `TrimSummary`, `TrimDurationSeconds` in batch flow**
- [ ] **Step 3: Preserve reports, progress, estimates, and single-trim compatibility**
- [ ] **Step 4: Run batch-focused tests**

### Task 4: GUI Multi-Cut Editing

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Test: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Keep failing GUI tokens/probe red**
- [ ] **Step 2: Add segment list, add/remove/clear controls, and per-file storage**
- [ ] **Step 3: Sync list selection with Start/End fields and refresh preview/properties summary**
- [ ] **Step 4: Run GUI tests**

### Task 5: Release Refresh + Verification

**Files:**
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Refresh: `release/VHS MP4 Optimizer/...`
- Test: `tests/test_vhs_release_package.py`

- [ ] **Step 1: Update release packaging if README/UI tokens need refresh**
- [ ] **Step 2: Rebuild release folder**
- [ ] **Step 3: Run focused tests, then full pytest**
- [ ] **Step 4: Commit and push**
