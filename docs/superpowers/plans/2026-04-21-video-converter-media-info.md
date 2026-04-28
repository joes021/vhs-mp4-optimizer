# Video Converter Media Info Implementation Plan

**Goal:** Add ffprobe-based media properties to the converter scan flow and GUI.

**Architecture:** Core PowerShell module parses ffprobe JSON into a stable object; GUI stores that object on each plan item and renders compact columns plus a detailed properties panel.

## Task 1: Core Media Info

- [ ] Add failing test for `Get-VhsMp4MediaInfo` with fake `ffprobe.ps1`.
- [ ] Extend ffprobe resolution to sibling `.ps1` as well as `.exe`.
- [ ] Parse format and streams into normalized fields.
- [ ] Keep `Get-VhsMp4MediaDurationSeconds` compatible.

## Task 2: GUI Media Info

- [ ] Add failing GUI token checks for media-info columns and panel.
- [ ] Use `Get-VhsMp4MediaInfo` inside `Add-PlanEstimates`.
- [ ] Add table columns and details panel update on row selection.

## Task 3: Docs And Release

- [ ] Update user docs and release README.
- [ ] Rebuild `release/VHS MP4 Optimizer`.

## Task 4: Verification

- [ ] Run focused tests.
- [ ] Run full video-converter test group.
- [ ] Run PowerShell parser checks.
- [ ] Run `git diff --check`.
- [ ] Commit and push.
