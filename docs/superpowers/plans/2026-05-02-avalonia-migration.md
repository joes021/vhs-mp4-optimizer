# VHS MP4 Optimizer Avalonia Migration Plan

Date: 2026-05-02

## Assumptions

- .NET SDK se koristi lokalno u worktree-ju preko `.dotnet/`
- postojece PowerShell skripte ostaju referenca za poslovna pravila
- stari release tok se ne dira dok novi sistem ne sazri

## Phase 1 - Migration foundation

1. Ignorisati lokalne worktree foldere u glavnom repou.
2. Napraviti izdvojenu granu `codex/avalonia-migration`.
3. Dodati pisani spec i plan migracije.
4. Postaviti lokalni .NET SDK alatni tok za worktree.

Exit criteria:

- worktree postoji
- branch postoji
- spec i plan su u repou
- lokalni SDK radi

## Phase 2 - Avalonia skeleton

1. Kreirati novu solution strukturu pod `next/`.
2. Dodati `App`, `Core`, `Infrastructure`, `Core.Tests`.
3. Podici Avalonia app da se build-uje i startuje.
4. Napraviti osnovni glavni prozor sa placeholder batch rasporedom.

Exit criteria:

- `dotnet build` prolazi
- `dotnet test` prolazi
- postoji cist shell prozor novog sistema

## Phase 3 - Batch workspace parity foundation

1. Dodati queue item model i planned output model.
2. Preneti scan tok i tabelarni prikaz fajlova.
3. Dodati input/output compare panel.
4. Dodati preset / advanced settings osnovu.

Exit criteria:

- novi UI ume da skenira i prikaze fajlove
- planned output se racuna za izabrani fajl

## Phase 4 - Player / Trim foundation

1. Dodati floating editor prozor.
2. Dodati single-file timeline segment model.
3. Dodati osnovni manual trim radni tok.
4. Vratiti izmene nazad u batch queue.

Exit criteria:

- editor se otvara iz batch ekrana
- segment model radi bar za jedan fajl

## Phase 5 - Hardening and continuation

1. Preneti crop/aspect/test sample logiku.
2. Dodati release packaging osnovu za novi sistem.
3. Dokumentovati sta je spremno, a sta ostaje u starom sistemu dok traje migracija.

## Verification per phase

- `dotnet build`
- `dotnet test`
- po potrebi ciljani PowerShell testovi stare baze ako se dodiruje zajednicka logika
- commit i push na kraju svake faze
