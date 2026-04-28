# Video Converter Player / Trim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodati poseban `Player / Trim` prozor koji otvara izabrani fajl iz batch tabele, nudi pravi playback za moderne formate, precizan preview fallback za stare formate i cuva trim/segment izmene nazad u queue.

**Architecture:** Glavni `Video Converter` prozor ostaje batch centar. Novi modalni `Player / Trim` prozor zivi u istom GUI skriptu i radi nad kopijom stanja jednog plan item-a, pa tek na `Save to Queue` upisuje izmene u shared trim state koji batch vec koristi. Playback koristi WPF `MediaElement` za `MP4/MOV/MKV`, a `AVI/MSDV/MPG` i playback greske automatski prelaze na postojeci FFmpeg frame-preview rezim.

**Tech Stack:** PowerShell, WinForms, WPF `MediaElement`, FFmpeg/ffprobe, pytest

---

## File Map

- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
  - Dodati `Open Player` dugme, dupli klik u grid-u, `Player / Trim` prozor, playback/fallback logiku i `Save to Queue` tok.
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
  - Dodati TDD pokrivanje za novi prozor, otvaranje, fallback mode i `Save to Queue`.
- Modify: `tests/test_vhs_release_package.py`
  - Dodati release token pokrivanje za `Open Player`, `Player / Trim`, `Save to Queue`, `Playback mode`, `Preview mode`.
- Modify: `scripts/build-vhs-mp4-release.ps1`
  - Osveziti release README tekst i rebuild release folder.
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
  - Dodati kratko korisnicko uputstvo za novi player workflow.
- Modify: `release/VHS MP4 Optimizer/...`
  - Osveziti release kopiju posle builder-a.

### Task 1: Player / Trim Test Scaffold

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Write failing GUI token tests**

Dodati tokene za:

- `Open Player`
- `Player / Trim`
- `Open-PlayerTrimWindow`
- `Show-SelectedPlayerTrimWindow`
- `Save to Queue`
- `Playback mode`
- `Preview mode`
- `MediaElement`
- `ElementHost`
- `Save-PlayerTrimChanges`
- `Copy-PlanItemTrimState`
- `Apply-PlayerTrimStateToItem`

- [ ] **Step 2: Write failing probe test for modal editor workflow**

Dodati probe koji:

1. kreira jedan `mp4` plan item sa `MediaInfo`
2. otvara player prozor preko funkcije
3. promeni `Start` i `End`
4. klikne `Save to Queue`
5. proveri da je izvorni item dobio `TrimStartText`, `TrimEndText`, `TrimSummary`

- [ ] **Step 3: Write failing probe test for fallback mode**

Probe sa `avi` item-om treba da potvrdi:

- status pokazuje `Preview mode`
- playback host nije aktivan
- fallback preview kontrole ostaju dostupne

- [ ] **Step 4: Run tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "player_trim" -v
```

Expected: FAIL because new player-window tokens/functions do not exist.

### Task 2: Shared Player State Helpers

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add minimal state-copy helpers**

Dodati minimalne helper funkcije:

- `Copy-PlanItemTrimState`
- `Apply-PlayerTrimStateToItem`
- `Test-PlaybackPreferredFormat`
- `Get-PlayerTrimWindowTitle`

Helperi treba da kopiraju samo potrebna polja:

- `TrimStartText`
- `TrimEndText`
- `TrimSummary`
- `TrimDurationSeconds`
- `TrimSegments`
- `PreviewPositionSeconds`

- [ ] **Step 2: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "player_trim and (tokens or save)" -v
```

Expected: i dalje FAIL ili delom FAIL, ali sada zbog nepostojeceg prozora, ne zbog helper tokena.

### Task 3: Player / Trim Window With Preview Fallback

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Implement `Open-PlayerTrimWindow`**

Napraviti poseban modalni prozor koji vraca strukturisani rezultat:

- `Saved`
- `TrimState`
- `Mode`

UI minimum:

- naslov `Player / Trim`
- metadata red
- veliko preview/player polje
- `Start`, `End`
- segment lista i dugmad
- `Save to Queue`
- `Cancel`

- [ ] **Step 2: Reuse existing trim/segment logic inside modal**

Zadrzati postojece obrasce za:

- `Get-VhsMp4TrimWindow`
- `Get-VhsMp4TrimSegments`
- `Set Start`
- `Set End`
- `Add Segment`
- `Remove`
- `Clear Seg`

ali nad lokalnom kopijom trim state-a umesto direktno nad grid selekcijom.

- [ ] **Step 3: Implement fallback `Preview mode`**

Za `AVI/MSDV/MPG` ili playback init failure:

- prikazi `Preview mode`
- koristi `PictureBox` + `Preview Frame`
- koristi timeline i frame-step fallback tok
- ne ruši prozor

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "player_trim and (fallback or save or modal)" -v
```

Expected: Save/fallback probe tests PASS, playback tests jos mogu biti red.

### Task 4: Playback Mode For Modern Formats

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add failing playback-mode token/probe expectations**

Pokriti:

- `Add-Type -AssemblyName PresentationCore`
- `Add-Type -AssemblyName PresentationFramework`
- `Add-Type -AssemblyName WindowsFormsIntegration`
- `MediaElement`
- `Play/Pause`
- `Stop`
- `current / total`

- [ ] **Step 2: Embed WPF `MediaElement` in WinForms host**

U `Open-PlayerTrimWindow`:

- napraviti `ElementHost`
- kreirati WPF `Grid`
- ubaciti `MediaElement`
- pratiti `MediaOpened`, `MediaEnded`, `MediaFailed`

- [ ] **Step 3: Wire transport and timeline**

Dodati:

- `Play / Pause`
- `Stop`
- timer za osvezavanje `current / total`
- timeline sync
- `frame-by-frame` pomeranje preko FPS-a iz `MediaInfo`
- `Set Start` / `Set End` iz trenutne player pozicije

- [ ] **Step 4: On `MediaFailed`, switch to fallback**

Kad playback ne moze da se otvori:

- status prelazi na `Preview mode`
- player host se sakrije ili zameni fallback preview panelom
- postojece trim radnje ostaju aktivne

- [ ] **Step 5: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "player_trim" -v
```

Expected: PASS.

### Task 5: Main Window Integration

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add `Open Player` button and double-click open**

Glavni ekran treba da dobije:

- novo dugme `Open Player`
- `$grid.Add_CellDoubleClick({ ... })`

- [ ] **Step 2: Save modal changes back to queue**

Implementirati `Show-SelectedPlayerTrimWindow` tako da:

- cita selektovani plan item
- otvara modal
- na `Save to Queue` primeni izmene nazad
- osvezi grid, media info i desni preview panel

- [ ] **Step 3: Add unsaved-changes prompt in modal**

Na zatvaranje ili `Cancel` sa izmenama:

- `Save`
- `Discard`
- `Cancel`

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "player_trim or manual_timeline or multi_cut" -v
```

Expected: PASS uz zadržano staro ponašanje.

### Task 6: Docs, Release, Verification

**Files:**
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `tests/test_vhs_release_package.py`
- Refresh: `release/VHS MP4 Optimizer/...`

- [ ] **Step 1: Add failing release token checks**

Ocekivani tokeni:

- `Open Player`
- `Player / Trim`
- `Save to Queue`
- `Playback mode`
- `Preview mode`

- [ ] **Step 2: Update docs and release builder text**

Objasniti tok:

1. `Scan Files`
2. izaberi fajl
3. `Open Player`
4. podesi `Start/End` ili segmente
5. `Save to Queue`
6. `Start Conversion`

- [ ] **Step 3: Rebuild release**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

- [ ] **Step 4: Run focused verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v
```

- [ ] **Step 5: Run broader verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_optimize_vhs_mp4_gui_launcher_tokens.py tests/test_vhs_release_package.py -v
```

- [ ] **Step 6: Run PowerShell parser checks**

Run:

```powershell
$files = @(
  'scripts/optimize-vhs-mp4-gui.ps1',
  'scripts/build-vhs-mp4-release.ps1',
  'release/VHS MP4 Optimizer/scripts/optimize-vhs-mp4-gui.ps1'
)
foreach ($file in $files) {
  $tokens=$null; $errors=$null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file), [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) { Write-Error "$file parser failed"; $errors | ForEach-Object { $_.ToString() }; exit 1 }
}
'PowerShell parser OK'
```

- [ ] **Step 7: Commit and push**

```powershell
git add docs/superpowers/specs/2026-04-26-video-converter-player-trim-design.md docs/superpowers/plans/2026-04-26-video-converter-player-trim.md docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md scripts/optimize-vhs-mp4-gui.ps1 scripts/build-vhs-mp4-release.ps1 tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py "release/VHS MP4 Optimizer"
git commit -m "feat: add player trim window"
git push
```
