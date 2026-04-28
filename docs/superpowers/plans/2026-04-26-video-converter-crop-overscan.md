# Video Converter Crop / Overscan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodati per-file `Crop / Overscan` alat sa auto-detect i ručnom pixel korekcijom u `Player / Trim` prozoru, plus batch opciju `Auto apply crop if detected` koja radi tek pri `Start Conversion`.

**Architecture:** Crop stanje se čuva uz isti per-file plan item model kao trim i preview stanje. GUI deo živi pre svega u `scripts/optimize-vhs-mp4-gui.ps1`, dok FFmpeg i crop argument logika ostaju u `scripts/optimize-vhs-mp4-core.psm1`. Auto-detect koristi više preview/probe uzoraka po fajlu i konzervativno vraća `No crop` kad rezultat nije dovoljno siguran.

**Tech Stack:** PowerShell, WinForms, FFmpeg, ffprobe, pytest

---

## File Map

- Modify: `scripts/optimize-vhs-mp4-core.psm1`
  - Dodati crop model helper-e, validaciju, auto-detect pomoćne funkcije i FFmpeg crop filter integraciju.
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
  - Dodati crop state u queue item model, crop UI u `Player / Trim`, batch checkbox i status prikaz.
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
  - Dodati TDD pokrivanje za crop argumente, prioritet ručnog crop-a i auto-detect fallback logiku.
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
  - Dodati tokene i probe za crop UI, `Auto Crop`, `Detect Crop`, `Clear Crop`, queue status i batch opciju.
- Modify: `tests/test_vhs_release_package.py`
  - Dodati release tokene za crop workflow.
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
  - Dodati korisničko objašnjenje crop toka.
- Modify: `scripts/build-vhs-mp4-release.ps1`
  - Osvežiti release README sa crop/overscan tokom.
- Refresh: `release/VHS MP4 Optimizer/...`
  - Osvežiti release kopiju posle builder-a.

### Task 1: Crop State and Core Tests

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing core tests for crop state and FFmpeg args**

Dodati testove koji pokrivaju:

- `Manual crop` ima prednost nad `Auto crop`
- `No crop` ne dodaje crop filter
- validan ručni crop pravi očekivani FFmpeg crop izraz
- nevalidne crop vrednosti budu odbijene

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "crop" -v
```

Expected: FAIL jer crop model i FFmpeg crop podrška još ne postoje.

- [ ] **Step 3: Implement minimal core crop helpers**

Dodati u `scripts/optimize-vhs-mp4-core.psm1`:

- `Get-VhsMp4CropState`
- `Test-VhsMp4CropState`
- `Get-VhsMp4CropFilter`

Minimalno ponašanje:

- `None` vraća bez filtera
- `Auto` i `Manual` daju crop filter kada su vrednosti validne
- granice i negativne vrednosti se proveravaju

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "crop" -v
```

Expected: PASS.

### Task 2: Auto-Detect Crop Core Behavior

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing tests for crop detection strategy**

Dodati testove za:

- analiza više uzoraka
- detekcija vraća konzervativni rezultat
- neuspešna ili nesigurna detekcija vraća `No crop`

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "detect_crop or overscan" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement minimal detection helpers**

Dodati:

- `Get-VhsMp4CropDetectionSampleTimes`
- `Get-VhsMp4DetectedCrop`

Prva verzija treba da:

- koristi više frame-ova
- vrati `Mode`, `Left`, `Top`, `Right`, `Bottom`
- vrati siguran `None` rezultat kad nema dovoljno stabilnog nalaza

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py -k "detect_crop or overscan" -v
```

Expected: PASS.

### Task 3: Player / Trim Crop UI

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing GUI token tests**

Dodati tokene za:

- `Crop / Overscan`
- `Detect Crop`
- `Auto Crop`
- `Clear Crop`
- `Left`
- `Top`
- `Right`
- `Bottom`
- `Crop: Auto`
- `Crop: Manual`
- `Auto apply crop if detected`

- [ ] **Step 2: Add failing GUI probe for per-file crop state**

Probe treba da potvrdi:

- crop vrednosti se čuvaju po fajlu
- ručna izmena pixel polja postavlja `Manual crop`
- `Clear Crop` briše crop stanje

- [ ] **Step 3: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "crop" -v
```

Expected: FAIL.

- [ ] **Step 4: Implement crop UI in `Player / Trim`**

Dodati:

- crop sekciju u `Open-PlayerTrimWindow`
- pixel polja `Left / Top / Right / Bottom`
- `Detect Crop`, `Auto Crop`, `Clear Crop`
- crop state label

- [ ] **Step 5: Implement per-file crop state save/apply**

Dodati helper-e kao što su:

- `Copy-PlanItemCropState`
- `Apply-PlayerCropStateToItem`
- `Clear-PlanItemCropState`

- [ ] **Step 6: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "crop" -v
```

Expected: PASS.

### Task 4: Crop Overlay and Queue Status

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Write failing tests for crop overlay and queue indicators**

Pokriti:

- overlay token prisustvo
- queue prikaz `Crop: Auto`, `Crop: Manual`, `Crop: --`
- selekcija reda osvežava crop info

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "crop and (overlay or queue)" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement crop overlay + queue status wiring**

Dodati:

- preview overlay crtanje ili indikator tokene u postojećem preview host-u
- queue kolonu ili status ćeliju za crop stanje

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "crop and (overlay or queue)" -v
```

Expected: PASS.

### Task 5: Batch Auto-Apply Crop

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Modify: `tests/test_optimize_vhs_mp4_core_behavior.py`
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `scripts/optimize-vhs-mp4-core.psm1`

- [ ] **Step 1: Write failing tests for batch checkbox behavior**

Pokriti:

- `Scan Files` ne pokreće crop detekciju
- `Start Conversion` pokreće auto-detect samo kad je checkbox uključen
- ručni crop ne biva pregažen

- [ ] **Step 2: Run focused tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "auto_apply_crop or batch_crop" -v
```

Expected: FAIL.

- [ ] **Step 3: Implement batch checkbox and conversion-time auto-crop**

Dodati:

- checkbox `Auto apply crop if detected` u glavnom GUI-u
- logiku da se auto-detect poziva pri `Start Conversion`
- pravilo `Manual crop` > `Auto crop` > `None`

- [ ] **Step 4: Run focused tests to verify GREEN**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "auto_apply_crop or batch_crop" -v
```

Expected: PASS.

### Task 6: Docs, Release, Final Verification

**Files:**
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `tests/test_vhs_release_package.py`
- Refresh: `release/VHS MP4 Optimizer/...`

- [ ] **Step 1: Write failing release token tests**

Dodati tokene za:

- `Crop / Overscan`
- `Detect Crop`
- `Auto Crop`
- `Clear Crop`
- `Auto apply crop if detected`
- `Left / Top / Right / Bottom`

- [ ] **Step 2: Update docs and release builder**

Opisati korisnički tok:

1. otvori fajl
2. `Detect Crop` ili `Auto Crop`
3. po potrebi ručno doteraј piksele
4. `Save to Queue`
5. opciono koristi batch auto-apply pri startu

- [ ] **Step 3: Rebuild release**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

- [ ] **Step 4: Run focused verification**

Run:

```powershell
python -m pytest tests/test_vhs_release_package.py tests/test_optimize_vhs_mp4_gui_tokens.py -k "crop" -v
```

Expected: PASS.

- [ ] **Step 5: Run broader verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v
```

Expected: PASS.

- [ ] **Step 6: Run PowerShell parser checks**

Run:

```powershell
$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('scripts/optimize-vhs-mp4-gui.ps1',[ref]$tokens,[ref]$errors); if ($errors.Count -gt 0) { $errors | ForEach-Object { $_.Message }; exit 1 }
$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('scripts/optimize-vhs-mp4-core.psm1',[ref]$tokens,[ref]$errors); if ($errors.Count -gt 0) { $errors | ForEach-Object { $_.Message }; exit 1 }
$tokens=$null; $errors=$null; [void][System.Management.Automation.Language.Parser]::ParseFile('scripts/build-vhs-mp4-release.ps1',[ref]$tokens,[ref]$errors); if ($errors.Count -gt 0) { $errors | ForEach-Object { $_.Message }; exit 1 }
```

- [ ] **Step 7: Commit**

```powershell
git add docs/superpowers/specs/2026-04-26-video-converter-crop-overscan-design.md docs/superpowers/plans/2026-04-26-video-converter-crop-overscan.md docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md scripts/optimize-vhs-mp4-gui.ps1 scripts/optimize-vhs-mp4-core.psm1 scripts/build-vhs-mp4-release.ps1 tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py release
git commit -m "feat: add crop overscan workflow"
```
