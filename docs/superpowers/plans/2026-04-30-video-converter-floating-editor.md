# Floating Preview / Trim Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pretvoriti glavni GUI u cist batch + properties ekran i prebaciti preview/trim/crop/aspect rad u jedan floating editor prozor.

**Architecture:** Glavni prozor zadrzava batch workflow i mali properties pregled, dok postojeci `Open-PlayerTrimWindow` postaje glavni single-file editor sa velikim preview-em, timeline pojasom i desnom alatnom kolonom. Postojece trim/crop/aspect stanje ostaje u istom `PlanItem` modelu; menja se samo raspored i nacin interakcije.

**Tech Stack:** PowerShell, WinForms, WPF `MediaElement`, pytest token/runtime probe testovi

---

### Task 1: Zapisati i ucvrstiti novi UI smer testovima

**Files:**
- Modify: `tests/test_optimize_vhs_mp4_gui_tokens.py`
- Reference: `scripts/optimize-vhs-mp4-gui.ps1`

- [ ] **Step 1: Dodati failing token test za batch-only glavni prozor**

Potvrditi da glavni GUI vise ne kreira stari desni preview/trim workspace, vec `Properties` panel.

- [ ] **Step 2: Dodati failing runtime probe za batch ekran**

Proveriti da:
- `Open Player` ostaje dostupan
- `Properties` panel postoji
- glavni prozor nema spljeskan preview region

- [ ] **Step 3: Dodati failing token/runtime test za floating editor raspored**

Proveriti da editor ima:
- split levo/desno
- veliki preview
- timeline ispod preview-a
- desnu alatnu kolonu

- [ ] **Step 4: Pokrenuti ciljane testove i potvrditi da padaju**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "floating_editor or batch_only_properties" -q`

### Task 2: Očistiti glavni batch prozor

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Test: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Ukloniti stari desni preview/trim panel iz glavnog prozora**

- [ ] **Step 2: Dodati kompaktan `Properties` panel na glavni ekran**

- [ ] **Step 3: Ostaviti queue toolbar i batch komande na glavnom prozoru**

- [ ] **Step 4: Pokrenuti ciljane batch layout testove**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "batch_only_properties" -q`

### Task 3: Presložiti floating `Preview / Trim` editor

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Test: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Redizajnirati `Open-PlayerTrimWindow` root layout**

Napraviti:
- levi preview region
- timeline ispod preview-a
- desnu alatnu kolonu
- donju `Save to Queue` / `Close` akciju

- [ ] **Step 2: Premestiti Trim sekciju u vrh desne kolone**

- [ ] **Step 3: Premestiti Crop / Aspect / Properties u nastavak desne kolone**

- [ ] **Step 4: Osigurati da preview zauzima dominantan deo prozora**

- [ ] **Step 5: Pokrenuti ciljane editor testove**

Run: `python -m pytest tests/test_optimize_vhs_mp4_gui_tokens.py -k "floating_editor" -q`

### Task 4: Napraviti editor single-instance workflow

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Test: `tests/test_optimize_vhs_mp4_gui_tokens.py`

- [ ] **Step 1: Dodati script-level reference na aktivni editor prozor**

- [ ] **Step 2: Prepraviti `Open Player` i dupli klik da re-use-uju isti prozor**

- [ ] **Step 3: Osigurati da promena selekcije u grid-u ne menja automatski editor**

- [ ] **Step 4: Dodati ili prilagoditi testove za single-window behavior**

### Task 5: Zatvoriti glavne UX rupе i release trag

**Files:**
- Modify: `scripts/optimize-vhs-mp4-gui.ps1`
- Modify: `docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md`
- Modify: `scripts/build-readme-media.ps1` (ako screenshot probing zahteva novi raspored)
- Optional modify: `docs/media/*` ako se regenerisu screenshotovi

- [ ] **Step 1: Ažurirati uputstvo da glavni ekran vise nije editor**

- [ ] **Step 2: Po potrebi prilagoditi README media probe skript**

- [ ] **Step 3: Regenerisati README slike ako se oslanjaju na glavni ekran**

### Task 6: Puna verifikacija i release osvežavanje

**Files:**
- Modify: `release/VHS MP4 Optimizer/...` kroz build skripte

- [ ] **Step 1: Pokrenuti kompletan test paket**

Run: `python -m pytest -q`

- [ ] **Step 2: Pokrenuti release/installer testove**

Run: `python -m pytest tests/test_vhs_release_package.py tests/test_vhs_installer_packaging.py tests/test_readme_media.py -q`

- [ ] **Step 3: Osvežiti release paket**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-release.ps1`

- [ ] **Step 4: Osvežiti installer paket**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-installer.ps1`

- [ ] **Step 5: Commit**

```bash
git add scripts/optimize-vhs-mp4-gui.ps1 tests/test_optimize_vhs_mp4_gui_tokens.py docs/VHS_MP4_OPTIMIZER_UPUTSTVO.md scripts/build-readme-media.ps1 docs/media release/VHS\ MP4\ Optimizer
git commit -m "feat: split batch workspace from floating editor"
```
