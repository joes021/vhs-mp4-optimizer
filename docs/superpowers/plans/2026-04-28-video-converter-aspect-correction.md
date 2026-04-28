# Video Converter Aspect Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodati per-file `Aspect mode` sistem sa auto-detect logikom, rucnim override-om, queue statusom, `Player / Trim` kontrolama i square-pixel FFmpeg izlazom za PAL/DV i NTSC/DV materijal.

**Architecture:** Aspect odluka se cuva u istom per-file modelu kao trim i crop, tako da scan, queue, preview i batch obrada rade nad istim stanjem. Core logika za metadata parsing, detekciju i izlaznu geometriju zivi u `scripts/optimize-vhs-mp4-core.psm1`, dok `scripts/optimize-vhs-mp4-gui.ps1` dobija queue polja, glavne kontrole i `Player / Trim` UI koji prikazuje i menja isto stanje bez paralelnog sistema.

**Tech Stack:** PowerShell, WinForms, WPF MediaElement host, FFmpeg, ffprobe, pytest

---

## File Map

- Modify: `scripts/optimize-vhs-mp4-core.psm1`
  - Dodati aspect state helper-e, metadata parsing, PAL/DV i NTSC/DV heuristiku, output geometry racunanje i FFmpeg integraciju.
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
  - Dodati per-file aspect state u queue item model, novu `Aspect` kolonu, batch kontrole, `Copy Aspect to All`, `Player / Trim` sekciju i log/report osvezavanje.
- Modify: `scripts/optimize-vhs-mp4.ps1`
  - Proslediti nova aspect podesavanja u batch/context tok ako CLI wrapper trenutno eksplicitno navodi filter parametre.
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
  - Dodati TDD pokrivanje za aspect detection, confidence mapiranje, output mapping i FFmpeg argumente.
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
  - Dodati tokene i probe za queue `Aspect` kolonu, `Aspect mode`, `Copy Aspect to All`, `Player / Trim` aspect UI i status tekstove.
- Modify: `tests/test_vhs_release_package.py`
  - Dodati release tokene za aspect workflow.
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
  - Dodati korisnicko objasnjenje aspect korekcije, `Auto`, `Keep Original`, `Force 4:3` i `Force 16:9`.
- Modify: `scripts/build-vhs-mp4-release.ps1`
  - Osveziti release README/uputstvo tekst za aspect correction tok.
- Refresh: `release/VHS MP4 Optimizer/...`
  - Osveziti release kopiju posle builder-a.

### Task 1: Aspect Core Detection State

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing core tests for aspect parsing and detection**

Dodati testove koji pokrivaju:

- normalizaciju `AspectMode` vrednosti (`Auto`, `KeepOriginal`, `Force4x3`, `Force16x9`)
- citanje `display_aspect_ratio` i `sample_aspect_ratio`
- `High`, `Medium`, `Low`, `Unknown` confidence mapiranje
- konflikt `DAR` / `SAR` -> `Keep Original`

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "aspect and (detect or confidence or sar or dar)" -v
```

Expected: FAIL jer aspect helperi jos ne postoje.

- [ ] **Step 3: Implement minimal aspect detection helpers**

Dodati u `scripts/optimize-vhs-mp4-core.psm1`:

- `Get-VhsMp4AspectState`
- `Get-VhsMp4NormalizedAspectMode`
- `Get-VhsMp4DetectedAspect`
- `Get-VhsMp4AspectConfidence`

Minimalno ponasanje:

- metadata se citaju konzervativno
- podrzani su samo `4:3` i `16:9`
- konfliktan ili nesiguran signal vraca fallback na `Keep Original`

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "aspect and (detect or confidence or sar or dar)" -v
```

Expected: PASS.

### Task 2: Aspect Output Mapping and FFmpeg Geometry

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing tests for square-pixel output mapping**

Dodati testove za:

- PAL `4:3` -> `768x576`
- PAL `16:9` -> `1024x576`
- NTSC `4:3` -> `640x480`
- NTSC `16:9` -> `854x480`
- `Scale = Original` zadrzava geometriju samo za vec square-pixel ulaz

- [ ] **Step 2: Write failing tests for crop / rotate / scale ordering**

Pokriti:

- crop se racuna pre aspect izlaza
- `90` / `270` rotacija menja radnu geometriju
- `Scale` ne radi drugu aspect korekciju preko vec odlucene geometrije

- [ ] **Step 3: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "aspect and (mapping or geometry or rotate or scale or ffmpeg)" -v
```

Expected: FAIL.

- [ ] **Step 4: Implement minimal geometry helpers**

Dodati:

- `Get-VhsMp4AspectTargetGeometry`
- `Get-VhsMp4AspectAwareScaleFilter`
- helper za PAL/DV i NTSC/DV bazne rezolucije

Implementacija mora da:

- koristi post-crop dimenzije
- koristi post-rotate radnu orijentaciju
- pravi square-pixel raster kad je ulaz anamorphic

- [ ] **Step 5: Integrate aspect logic into filter/argument builder**

Azurirati:

- `Get-VhsMp4VideoFilterChain`
- `Get-VhsMp4FilterSummary`
- `Get-VhsMp4FfmpegArguments`

Tako da `AspectMode`, crop, rotate i scale daju jedan dosledan izlazni filter tok.

- [ ] **Step 6: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "aspect and (mapping or geometry or rotate or scale or ffmpeg)" -v
```

Expected: PASS.

### Task 3: Queue Item Aspect State on Scan

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing tests for per-file aspect state on scan**

Pokriti:

- `Scan Files` odmah upisuje detected aspect podatke po fajlu
- `MediaInfo` zadrzava `DisplayAspectRatio` i `SampleAspectRatio`
- queue item dobija `AspectSummary`, `DetectedAspectMode`, `OutputAspectWidth`, `OutputAspectHeight`

- [ ] **Step 2: Write failing GUI token checks for queue aspect surface**

Dodati tokene za:

- `Aspect`
- `Aspect mode`
- `Copy Aspect to All`
- `Detected:`
- `Keep Original`
- `Force 4:3`
- `Force 16:9`

- [ ] **Step 3: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (scan or queue or summary or mode)" -v
```

Expected: FAIL.

- [ ] **Step 4: Implement aspect fields in scan/estimate pipeline**

Azurirati:

- `Get-VhsMp4MediaInfo`
- `Get-VhsMp4Plan`
- `Get-VhsMp4PlanFromPaths`
- `Add-PlanEstimates`

Tako da svaki item dobije aspect state vec pri scan-u.

- [ ] **Step 5: Add queue `Aspect` column and refresh wiring**

Azurirati:

- grid kolone
- `Set-GridRows`
- `Format-VhsMp4MediaDetails`
- `Update-MediaInfoPanel`

Da queue i properties prikazuju automatsku ili rucnu aspect odluku.

- [ ] **Step 6: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (scan or queue or summary or mode)" -v
```

Expected: PASS.

### Task 4: Main Window Aspect Controls

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing GUI tests for batch aspect controls**

Pokriti:

- `Aspect mode` dropdown postoji u glavnom prozoru
- `Copy Aspect to All` postoji
- batch promena menja samo `AspectMode`
- rucni override ne dira crop i trim stanje

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (dropdown or copy_to_all or batch)" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement main window aspect controls**

Dodati:

- `aspectModeComboBox`
- `copyAspectToAllButton`
- helper-e za izbor reda i primenu aspect moda

- [ ] **Step 4: Implement aspect mode propagation helpers**

Dodati ili azurirati helper-e koji:

- menjaju jedan item
- vracaju item na `Auto`
- kopiraju samo `AspectMode` na sve plan item-e
- odmah osvezavaju queue, preview panel i procene

- [ ] **Step 5: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (dropdown or copy_to_all or batch)" -v
```

Expected: PASS.

### Task 5: Player / Trim Aspect Panel

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing GUI tests for `Player / Trim` aspect section**

Dodati tokene i probe za:

- `Aspect / Pixel shape`
- `Auto`
- `Keep Original`
- `Force 4:3`
- `Force 16:9`
- status tipa `Detected: PAL DV 16:9 -> 1024x576`
- prikaz `DAR`, `SAR` i planiranog izlaza

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (player or trim or pixel_shape)" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement aspect state inside `Open-PlayerTrimWindow`**

Dodati lokalna polja i rezultat:

- `AspectMode`
- `DetectedAspectLabel`
- `DetectedDisplayAspectRatio`
- `DetectedSampleAspectRatio`
- `OutputAspectWidth`
- `OutputAspectHeight`

- [ ] **Step 4: Add `Aspect / Pixel shape` UI and save-back flow**

Dodati:

- dropdown u `Player / Trim`
- status labelu za detekciju
- labelu za ulazni `DAR/SAR`
- `Save to Queue` integraciju koja vraca aspect izmene na plan item

- [ ] **Step 5: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "aspect and (player or trim or pixel_shape)" -v
```

Expected: PASS.

### Task 6: Documentation, Release, and Full Verification

**Files:**
- Modify: `tests/test_vhs_release_package.py`
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `scripts/optimize-vhs-mp4.ps1` if wrapper needs new parameter forwarding

- [ ] **Step 1: Write failing release/doc tests**

Pokriti:

- release README pominje aspect workflow
- uputstvo objasnjava `Auto`, `Keep Original`, `Force 4:3`, `Force 16:9`
- release paket i dalje sadrzi prave GUI/core skripte

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_vhs_release_package.py -k "aspect or release" -v
```

Expected: FAIL.

- [ ] **Step 3: Update docs and release builder**

Azurirati:

- `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- `scripts/build-vhs-mp4-release.ps1`
- po potrebi `scripts/optimize-vhs-mp4.ps1`

Tako da release tok, wrapper i korisnicko uputstvo odgovaraju novoj aspect funkciji.

- [ ] **Step 4: Run full relevant verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v
```

Expected: PASS.

- [ ] **Step 5: Refresh release package**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

Expected: release kopija osvezena bez parser gresaka.

- [ ] **Step 6: Run PowerShell parser sanity check**

Run:

```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts/optimize-vhs-mp4-core.psm1', [ref]$null, [ref]$null)
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts/optimize-vhs-mp4-gui.ps1', [ref]$null, [ref]$null)
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts/build-vhs-mp4-release.ps1', [ref]$null, [ref]$null)
```

Expected: bez parser gresaka.
