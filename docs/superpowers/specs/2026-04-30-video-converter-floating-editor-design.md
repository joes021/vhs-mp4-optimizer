# Floating Preview / Trim Redesign

**Goal**

Rasteretiti glavni prozor konvertera tako da bude cist batch ekran, a sav ozbiljan rad nad jednim fajlom prebaciti u poseban floating `Preview / Trim` editor prozor.

## Problem

Dosadasnji glavni prozor je pokusavao da istovremeno bude:
- batch ekran
- media properties pregled
- preview panel
- trim editor
- crop/aspect editor

To je dovelo do toga da:
- preview dobije premalo prostora
- `Apply Trim` i segment dugmad budu skriveni ili zgnjeceni
- preset i quick action dugmad ispadaju iz `Quick Setup` grupe
- batch ekran izgubi fokus i preglednost

## Target UX

### 1. Glavni prozor = batch workspace

Glavni prozor ostaje fokusiran na:
- `Source / Output / FFmpeg`
- `Workflow preset`
- batch akcije
- queue tabelu
- mali `Properties` panel za trenutno izabrani fajl
- status / progress / log

Glavni prozor vise nema veliki preview/trimming panel.

### 2. Floating editor = single-file workspace

`Open Player` i dupli klik na fajl otvaraju jedan floating `Preview / Trim` prozor.

Osobine:
- postoji samo jedan editor prozor u isto vreme
- ako je vec otvoren, otvaranje drugog fajla samo promeni njegov sadrzaj
- editor nije modalni “zatvor”; moze da stoji pored batch prozora
- pamti poslednju velicinu i poziciju
- ima minimalnu velicinu ispod koje ne moze da se smanji

## Floating editor layout

### Leva strana

Levo ide dominantna preview zona:
- veliki preview surface
- ispod preview-a timeline pojas preko pune sirine
- timeline prikazuje trenutno vreme i ukupno trajanje
- `Frame <`, `Frame >`, `Set Start`, `Set End` ostaju uz timeline
- `Start`, `End` i `CUT` markeri moraju biti stalno vidljivi

### Desna strana

Desna alatna kolona je stabilne sirine i sadrzi:

1. `Trim`
- `Start`
- `End`
- `Apply Trim`
- `Add Segment`
- `Remove`
- `Clear Seg`
- `Clear Trim`
- lista segmenata

2. `Crop / Overscan`
- `Detect Crop`
- `Auto Crop`
- `Clear Crop`
- `Left / Top / Right / Bottom`
- status `Auto / Manual / --`

3. `Aspect / Pixel shape`
- `Auto`
- `Keep Original`
- `Force 4:3`
- `Force 16:9`
- `Detected`
- `DAR / SAR`
- `Planned output aspect`

4. `Properties`
- container
- codec
- resolution
- fps
- duration
- bitrate
- frames
- audio info

### Donja akcija

Na dnu editora ostaju:
- `Save to Queue`
- `Close`

Ako postoje nesnimljene izmene pri zatvaranju:
- `Save`
- `Discard`
- `Cancel`

## State and data flow

- editor radi nad jednim izabranim `PlanItem`
- izmene u editoru ne curе nazad u batch dok se ne klikne `Save to Queue`
- `Save to Queue` osvezava queue kolone `Range`, `Crop`, `Aspect` i related summaries
- promena selekcije u glavnom prozoru sama po sebi ne menja otvoreni editor

## Main window after redesign

Glavni desni panel postaje `Properties` panel:
- tekstualni pregled osnovnih media info i planiranih izlaznih parametara
- nema timeline-a
- nema velikog preview-a
- nema trim/crop/aspect kontrola

Batch toolbar ostaje iznad queue tabele:
- `Open Player`
- queue reorder / retry / skip / clear komande

## Testing strategy

Potrebne su provere za:
- glavni prozor vise ne sadrzi stari preview/trim workspace
- `Properties` panel ostaje vidljiv i upotrebljiv na glavnom ekranu
- floating editor ima veliki preview + timeline + desnu alatnu kolonu
- `Open Player` i dupli klik re-use-uju isti editor prozor
- `Save to Queue` vraca izmene nazad u batch
- nesnimljene izmene aktiviraju `Save / Discard / Cancel`

## Migration intent

Ovaj redizajn je namerno “cist rez”:
- glavni ekran = batch
- floating prozor = editor

To je stabilnija osnova za dalji rast aplikacije od daljeg krpljenja boznog preview panela.
