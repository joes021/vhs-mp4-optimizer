# Video Converter Workflow Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodati `Workflow preset` sistem sa ugrađenim profilima po nameni, korisnickim presetima u `AppData`, `Custom` stanjem, import/export tokom i povezanim status/report/documentation poboljsanjima.

**Architecture:** Svi preset helperi i UI integracija zive u `scripts/optimize-vhs-mp4-gui.ps1`, jer upravljaju stanjem forme i batch procenama. Preset model je cist snapshot opštih batch podesavanja, odvojen od trim/segment logike. Storage koristi JSON fajlove u korisnickom `AppData` prostoru, uz built-in definicije u samoj aplikaciji.

**Tech Stack:** PowerShell, WinForms, JSON, pytest

---

## File Map

- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
  - Dodati preset model, built-in preset-e, AppData storage, UI, `Custom` stanje i report/log integraciju.
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
  - Dodati TDD pokrivanje za preset UI, helper funkcije, import/export i `Custom` ponasanje.
- Modify: `tests/test_vhs_release_package.py`
  - Dodati release tokene za preset workflow.
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
  - Dodati kratko uputstvo za workflow preset tok.
- Modify: `scripts/build-vhs-mp4-release.ps1`
  - Osveziti release README sa preset sekcijom.
- Refresh: `release/VHS MP4 Optimizer/...`
  - Osveziti release kopiju posle builder-a.

### Task 1: Preset Spec Scaffolding In Tests

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Write failing GUI token checks for preset UI**

Dodati tokene za:

- `Workflow preset`
- `workflowPresetComboBox`
- `Save Preset`
- `Delete Preset`
- `Import Preset`
- `Export Preset`
- `presetDescriptionLabel`
- `Custom`

- [ ] **Step 2: Write failing helper token checks**

Dodati tokene za:

- `Get-WorkflowPresetDefinitions`
- `Get-WorkflowPresetStoragePath`
- `Import-WorkflowPresetState`
- `Export-WorkflowPresetState`
- `Get-CurrentWorkflowPresetSettings`
- `Apply-WorkflowPresetSettings`
- `Set-WorkflowPresetCustomState`
- `Save-WorkflowPreset`
- `Remove-WorkflowPreset`

- [ ] **Step 3: Run tests to verify RED**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "workflow_preset or preset" -v
```

Expected: FAIL because preset system does not exist yet.

### Task 2: AppData Preset Model And Persistence

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add failing persistence probe**

Probe treba da potvrdi:

- built-in preset-i postoje
- storage putanja je u `LocalApplicationData`
- user preset moze da se sacuva
- preset moze da se ucita nazad
- korumpiran JSON vraca fallback stanje umesto pada

- [ ] **Step 2: Implement minimal preset definition helpers**

Dodati:

- `Get-WorkflowPresetDefinitions`
- `New-WorkflowPresetObject`
- `Get-WorkflowPresetStorageRoot`
- `Get-WorkflowPresetStoragePath`
- `Get-WorkflowAppStatePath`

- [ ] **Step 3: Implement import/export state helpers**

Dodati:

- `Import-WorkflowPresetState`
- `Export-WorkflowPresetState`
- `Import-WorkflowAppState`
- `Export-WorkflowAppState`

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "preset and (storage or appdata or import or export)" -v
```

Expected: storage probe PASS ili ostane red samo na UI tokenima.

### Task 3: Form Snapshot And Custom State

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add failing form-state probe**

Probe treba da potvrdi:

- snapshot hvata sva opsta batch polja
- `Apply-WorkflowPresetSettings` puni kontrole
- rucna promena vraca aktivno stanje na `Custom`
- `Custom` ne menja input/output/FFmpeg polja

- [ ] **Step 2: Implement form snapshot helpers**

Dodati:

- `Get-CurrentWorkflowPresetSettings`
- `Apply-WorkflowPresetSettings`
- `Test-WorkflowPresetMatchesCurrentSettings`
- `Set-WorkflowPresetSelectionState`
- `Set-WorkflowPresetCustomState`

- [ ] **Step 3: Wire change tracking**

Promene u:

- `qualityModeComboBox`
- `crfTextBox`
- `presetComboBox`
- `audioTextBox`
- `splitOutputCheckBox`
- `maxPartGbTextBox`
- `deinterlaceComboBox`
- `denoiseComboBox`
- `rotateFlipComboBox`
- `scaleModeComboBox`
- `audioNormalizeCheckBox`

treba da aktiviraju `Custom` stanje kad izmene vise nisu iste kao aktivni preset.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "preset and (custom or apply or snapshot)" -v
```

Expected: PASS.

### Task 4: Preset UI And Immediate Apply

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add preset controls to main window**

Dodati:

- `Workflow preset` label
- dropdown
- `Save Preset`
- `Delete Preset`
- `Import Preset`
- `Export Preset`
- opisnu labelu ispod

- [ ] **Step 2: Implement immediate apply**

Kad korisnik izabere preset:

- kontrole se odmah popune
- status i opis se osveze
- ako vec postoji plan, osveze se procene i USB note gde ima smisla

- [ ] **Step 3: Protect built-in delete path**

`Delete Preset` treba da:

- radi samo za korisnicke preset-e
- odbije `BuiltIn` i `Custom`

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "preset and (ui or immediate or delete)" -v
```

Expected: PASS.

### Task 5: Save / Import / Export / Last-Used State

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Add failing persistence workflow probe**

Probe treba da potvrdi:

- `Save Preset` cuva user preset
- `Import Preset` vraca isti preset
- `Export Preset` pravi JSON fajl
- poslednji preset i zadnje opste vrednosti se obnavljaju pri startu

- [ ] **Step 2: Implement action handlers**

Dodati:

- `Save-WorkflowPreset`
- `Remove-WorkflowPreset`
- `Import-WorkflowPresetFromFile`
- `Export-WorkflowPresetToFile`
- `Restore-WorkflowPresetStartupState`
- `Save-WorkflowPresetStartupState`

- [ ] **Step 3: Write minimal overwrite behavior**

Kod duplog imena:

- ako je user preset, pitati za overwrite
- ako je built-in ime, traziti drugo ime

- [ ] **Step 4: Run focused tests**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "preset and (save or import or export or startup)" -v
```

Expected: PASS.

### Task 6: Report / Docs / Release

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-vhs-mp4-release.ps1`
- Modify: `tests/test_vhs_release_package.py`

- [ ] **Step 1: Add failing release token checks**

Dodati tokene za:

- `Workflow preset`
- `Save Preset`
- `Delete Preset`
- `Import Preset`
- `Export Preset`
- `USB standard`
- `VHS cleanup`
- `Custom`

- [ ] **Step 2: Add preset name to report/log flow**

Status, session log i `IZVESTAJ.txt` treba da zabeleze preset ime ili `Custom`.

- [ ] **Step 3: Update user docs**

Opisati tok:

1. izaberi `Workflow preset`
2. po potrebi izmeni vrednosti
3. vidi `Custom` ako si skrenuo sa preseta
4. `Save Preset` ako zelis da sacuvas svoj profil
5. `Start Conversion`

- [ ] **Step 4: Rebuild release**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1
```

- [ ] **Step 5: Run focused verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v
```

- [ ] **Step 6: Run broader verification**

Run:

```powershell
python -m pytest tests/test_optimize_vhs_mp4_core_behavior.py tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py -v
```

- [ ] **Step 7: Run PowerShell parser checks**

Run:

```powershell
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/optimize-vhs-mp4-gui.ps1',[ref]$null,[ref]$null)"
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('scripts/build-vhs-mp4-release.ps1',[ref]$null,[ref]$null)"
```

- [ ] **Step 8: Commit**

```powershell
git add docs/superpowers/specs/2026-04-26-video-converter-workflow-presets-design.md docs/superpowers/plans/2026-04-26-video-converter-workflow-presets.md docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md scripts/optimize-vhs-mp4-gui.ps1 scripts/build-vhs-mp4-release.ps1 tests/test_optimize_vhs_mp4_gui_tokens.py tests/test_vhs_release_package.py release
git commit -m "feat: add workflow presets"
```
