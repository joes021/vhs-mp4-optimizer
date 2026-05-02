# VHS MP4 Optimizer Avalonia Migration Design

Date: 2026-05-02

## Goal

Prebaciti aplikaciju sa PowerShell/WinForms prototipa na novi cross-platform desktop sistem zasnovan na:

- C# / .NET 8
- Avalonia UI
- FFmpeg kao engine za obradu i export

Prva migraciona verzija treba da dostigne funkcionalni minimum dovoljan da zameni postojeći batch tok i da postavi cistu osnovu za dalji razvoj timeline editora.

## Why migrate now

Postojeci sistem je prerastao skriptni alat. Sledece funkcije traze ozbiljniji UI i state model:

- batch queue sa planned output prikazom
- preview / trim / crop / aspect radni tok
- single-file timeline editor
- kasnije realniji non-linear edit tok

PowerShell ostaje referentna implementacija za logiku i poslovna pravila, ali vise nije dobra osnova za nastavak razvoja interaktivnog editora.

## Architecture

## Solution shape

Nova solution struktura:

- `next/VhsMp4Optimizer.sln`
- `next/src/VhsMp4Optimizer.App`
- `next/src/VhsMp4Optimizer.Core`
- `next/src/VhsMp4Optimizer.Infrastructure`
- `next/tests/VhsMp4Optimizer.Core.Tests`

## Layer responsibilities

### App

- Avalonia UI
- view modeli i komandni tok
- layout za batch radnu povrsinu
- floating player / trim editor prozor

### Core

- domen queue stavki
- trim / cut / segment model
- crop / aspect / scale planiranje
- planned output proracun
- split/join business rules

### Infrastructure

- FFmpeg / FFprobe procesi
- filesystem i app-state persistance
- manifest / updater helpers

## Phase targets

## Phase 1

- solution i projekti
- glavni prozor
- status i queue layout
- compile/run bazni desktop app

## Phase 2

- batch scan i lista fajlova
- planned output model
- input/output poredenje
- osnovna preset i advanced settings mapa

## Phase 3

- floating player / trim prozor
- manual trim navigacija
- single-file timeline segment model
- save back to queue

## Phase 4

- crop / aspect / test sample / batch export parity
- release packaging osnova za novi sistem

## UI direction

Glavni prozor ostaje batch-centric:

- gornji red: input/output izbor
- ispod: quick setup
- ispod: advanced settings
- sredina: queue + planned output / source-output compare
- dole: status / progress / log

Player / Trim ostaje poseban floating prozor i postaje jedino mesto za detaljan rad nad jednim fajlom.

## Migration strategy

- ne raditi "big bang" prepisivanje
- posle svake faze:
  - build
  - test
  - commit
  - push
  - fazni izvestaj
- PowerShell verzija ostaje stabilna fallback varijanta dok Avalonia verzija ne dobije dovoljnu funkcionalnu pokrivenost

## Initial parity target

Prvi ozbiljan cilj novog sistema nije 100% feature parity u jednom skoku, nego:

- batch scan
- queue prikaz
- planned output
- preset / advanced settings skeleton
- player / trim osnova
- single-file cut timeline osnova

Kad taj minimum radi stabilno, na novu bazu se prenose ostale funkcije.
