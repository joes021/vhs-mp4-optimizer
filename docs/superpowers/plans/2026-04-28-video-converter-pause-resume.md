# Video Converter Pause Resume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodati batch `Pause / Resume` tok koji zavrsava trenutni fajl, zatim pauzira batch pre sledeceg fajla, dozvoljava izmene nad preostalim queue stavkama i nastavlja od prvog sledeceg `queued` fajla u aktuelnom redosledu.

**Architecture:** Implementacija ostaje u GUI batch orkestraciji. `Pause` i `Resume` uvode mali state-machine sloj iznad postojeceg `Start-NextQueuedItem` / `Complete-CurrentProcess` toka, bez promene FFmpeg procesa usred fajla. Runtime probe testovi pokrivaju UI state, status poruke i nastavak obrade iz pausiranog queue-a.

**Tech Stack:** PowerShell, WinForms GUI, pytest probe testovi

---

### Task 1: Cover Pause Resume Surface and Runtime

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Write failing GUI token test**

Pokriti tokene za:
- `Pause`
- `Resume`
- stanje tipa `Paused after current file`
- stanje tipa `Paused`

- [ ] **Step 2: Write failing runtime probe test**

Pokriti:
- `Pause` ostavlja trenutni fajl da zavrsi
- batch staje pre sledeceg fajla
- `Resume` nastavlja od prvog sledeceg `queued` fajla
- while paused, `Open Player`, `Test Sample` i glavna batch podesavanja mogu ostati aktivni

- [ ] **Step 3: Run focused tests to verify RED**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "pause or resume" -v`
Expected: FAIL

### Task 2: Add Pause Resume State Machine

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Add pause/resume script state**

Uvesti:
- stanje za `PauseRequested`
- stanje za `Paused`
- helper za detekciju da li je batch aktivno pausiran

- [ ] **Step 2: Wire buttons and button-state logic**

Dodati:
- `Pause` dugme
- `Resume` dugme
- `Update-ActionButtons` logiku za running vs paused

- [ ] **Step 3: Implement batch transition rules**

Obezbediti:
- `Pause` samo oznaci batch da stane posle trenutnog fajla
- posle zavrsetka tog fajla batch prelazi u `Paused`
- `Resume` krece od prvog sledeceg `queued` fajla u tadasnjem redosledu
- `Stop` i dalje ostaje hard stop

- [ ] **Step 4: Keep paused editing behavior**

Dozvoliti tokom `Paused`:
- opsta batch podesavanja
- `Open Player`
- trim/crop/aspect izmene
- `Test Sample`

- [ ] **Step 5: Run focused tests to verify GREEN**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "pause or resume" -v`
Expected: PASS

### Task 3: Full Verification and Release Copy Refresh

**Files:**
- Modify: `tests/test_vhs_release_package.py` if release docs need new pause/resume mentions
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md` if user-facing flow changes need explanation
- Modify: `scripts/build-vhs-mp4-release.ps1` if release README should mention pause/resume

- [ ] **Step 1: Run relevant verification**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v`
Expected: PASS

- [ ] **Step 2: Refresh release package**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1`
Expected: release osvezen

- [ ] **Step 3: Run parser sanity**

Run: parser check for `scripts/optimize-vhs-mp4-gui.ps1` and `scripts/build-vhs-mp4-release.ps1`
Expected: no parser errors
