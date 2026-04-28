# Video Converter Workflow Presets Design

## Goal

Dodati ozbiljan `Workflow preset` sistem u `Video Converter`, tako da korisnik moze jednim izborom da ucita smislen skup opštih batch podesavanja, sacuva sopstvene profile i nastavi da radi bez stalnog rucnog setovanja istih kontrola.

Ova faza ne menja per-file trim, segmente ni queue sadrzaj. Fokus je na tome da alat postane brzi, pouzdaniji i prijatniji za svakodnevni rad sa mnogo video fajlova.

## Chosen Direction

Izabran je hibridni preset tok:

- ugrađeni `Workflow preset` profili po nameni
- korisnicki preset-i sacuvani u `AppData`, nezavisno od release foldera
- preset se primenjuje odmah cim se izabere
- svaka rucna izmena opštih kontrola prebacuje aktivno stanje na `Custom`
- preset sistem je odvojen od postojećeg encoder `Preset` polja (`slow`, `medium`, `fast` i slicno)
- preset se moze `Save`, `Delete`, `Import` i `Export`
- poslednji korisceni preset i zadnja opsta podesavanja se cuvaju za sledece pokretanje

Ovim dobijamo brzinu gotovih profila, slobodu da korisnik sacuva svoj radni stil i stabilnost pri update-u aplikacije.

## Scope

Ova faza radi:

- novi `Workflow preset` izbor u glavnom GUI-u
- ugrađene profile po nameni
- korisnicke preset-e u `AppData`
- odmah-apply ponasanje pri izboru preseta
- `Custom` stanje kad korisnik rucno promeni opsta podesavanja
- `Save Preset`
- `Delete Preset`
- `Import Preset`
- `Export Preset`
- cuvanje poslednjeg aktivnog preseta
- cuvanje poslednjih opštih batch podesavanja
- zastitu ugrađenih preseta od brisanja
- bezbedan fallback kad je preset fajl ostecen ili neispravan
- kratku preset napomenu/opis u UI-ju
- osvezavanje statusa, procena i USB napomena kad preset promeni bitne opcije
- log/report trag o aktivnom preset-u
- release README/uputstvo za novi workflow

Ova faza ne radi:

- per-file trim preset-e
- preset-e za queue sadrzaj
- preset-e za input/output folder ili FFmpeg putanju
- cloud sinhronizaciju
- biblioteku preview thumbnail-a po preset-u

## Preset Types

Sistem uvodi tri vrste stanja:

1. `Built-in`
   - isporucuju se sa aplikacijom
   - ne mogu da se brisu
   - sluze kao siguran pocetak

2. `User`
   - korisnik ih cuva sam
   - zive u `AppData`
   - mogu da se prepisu, brisu, izvoze i uvoze

3. `Custom`
   - nije trajni preset nego trenutno stanje forme
   - nastaje kad korisnik promeni bilo koju opstu kontrolu posle izbora nekog preseta
   - ne cuva se automatski kao novi preset

## Built-In Presets

Pocetni skup ugrađenih profila treba da bude po nameni, ne po internim tehnickim oznakama:

- `USB standard`
- `Mali fajl`
- `High quality arhiva`
- `HEVC manji fajl`
- `VHS cleanup`

Svaki od njih treba da mapira kompletan set opštih batch kontrola:

- `Quality mode`
- `CRF`
- encoder `Preset`
- `Audio bitrate`
- `Deinterlace`
- `Denoise`
- `Rotate/flip`
- `Scale`
- `Audio normalize`
- `Split output`
- `Max part GB`

## Data Model

Preset ne sme da bude samo parcijalni patch. Mora da predstavlja pun i citljiv snapshot opštih batch podesavanja.

Predlozena struktura:

- `SchemaVersion`
- `Name`
- `Kind` (`BuiltIn` / `User`)
- `Description`
- `Settings`
  - `QualityMode`
  - `Crf`
  - `Preset`
  - `AudioBitrate`
  - `Deinterlace`
  - `Denoise`
  - `RotateFlip`
  - `ScaleMode`
  - `AudioNormalize`
  - `SplitOutput`
  - `MaxPartGb`

Odvojeno od same preset kolekcije cuva se i korisnicko `AppState` stanje:

- `LastPresetName`
- `LastGeneralSettings`

Ovo omogucava da se aplikacija vrati u poslednje radno stanje cak i kad je aktivno bilo `Custom`.

## Storage Strategy

Korisnicki preset-i i app state se cuvaju u korisnickom `AppData` prostoru, ne pored release skripti.

Razlozi:

- update release foldera ne brise korisnicke preset-e
- desktop precica i portable kopija ostaju jednostavni
- ne mesamo radne podatke sa distributivnim fajlovima
- vise korisnika na istoj masini moze da ima sopstvena podesavanja

Ako storage fajl ne postoji:

- aplikacija kreira potreban folder
- ucitava built-in preset-e
- bira pocetni podrazumevani preset

Ako je storage fajl ostecen:

- alat ne sme da padne
- treba prijaviti kratko upozorenje u statusu ili logu
- treba ucitati built-in preset-e i cisto podrazumevano stanje

## UI / UX

Glavni prozor dobija novu, jasnu preset zonu iznad ili neposredno uz opsta batch podesavanja.

Predlozeni raspored:

- labela `Workflow preset`
- dropdown sa:
  - `USB standard`
  - `Mali fajl`
  - `High quality arhiva`
  - `HEVC manji fajl`
  - `VHS cleanup`
  - korisnicki preset-i
  - `Custom` kad je aktivno
- dugmad:
  - `Save Preset`
  - `Delete Preset`
  - `Import`
  - `Export`
- kratka opisna linija ispod dropdown-a koja objasnjava sta izabrani preset radi

Ponasanje:

- izbor preseta odmah popunjava kontrole
- `Save Preset` nudi naziv i cuva trenutno stanje
- `Delete Preset` radi samo za korisnicke preset-e
- `Import` cita `.json`
- `Export` pravi `.json`
- rucna izmena bilo kog opšteg polja aktivira `Custom`
- ako je aktivno `Custom`, opis prikazuje da forma vise nije identicna snimljenom preset-u

## Workflow Rules

Najvaznija pravila rada:

1. preset nikad ne menja `Input folder`
2. preset nikad ne menja `Output folder`
3. preset nikad ne menja `FFmpeg path`
4. preset nikad ne dira trim i segmente
5. izbor preseta odmah osvezava status i procene gde ima smisla
6. ako postoji vec skeniran queue, promena preseta ne brise listu, ali moze da osvezi procene i upozorenja
7. built-in preset ne moze da bude obrisan
8. ime korisnickog preseta mora biti citko i jedinstveno

## Error Handling

Sistem mora ostati blag i upotrebljiv:

- duplikat imena pri cuvanju: traziti potvrdu za overwrite ili sacuvati kao novo ime
- neispravan import JSON: jasna poruka bez rusenja
- nekompletan preset: odbiti import i objasniti sta fali
- ostecen `AppData` storage: fallback na built-in preset-e
- export greska: poruka sa putanjom i razlogom ako je poznat

## Reporting and Logging

Preset sistem treba da ostavi trag i van samog GUI-a:

- status poruka moze da kaze koji preset je aktivan
- session log treba da upise aktivni preset i glavne vrednosti
- `IZVESTAJ.txt` treba da navede preset ime ili `Custom`

To olaksava kasnije ponavljanje istog posla ili proveru kako je neki batch napravljen.

## Testing

Testovi treba da pokriju:

- GUI tokene za novi preset UI
- built-in preset definicije
- `Custom` stanje
- `AppData` storage helpers
- import/export tokene i logiku
- zastitu built-in preset-a od brisanja
- cuvanje i ucitavanje poslednjeg opšteg stanja
- status/report/log tokene za preset ime
- release README i builder tokene

Postojeci testovi za scan, split, preview, player, release paket i konverziju moraju ostati zeleni.

## Twenty Practical Improvements

Ova faza nosi sledeci niz konkretnih poboljsanja:

1. odvojen `Workflow preset` pojam
2. ugrađeni preset-i po nameni
3. korisnicki preset-i u `AppData`
4. auto-kreiranje preset storage foldera
5. bezbedan fallback kad storage nije ispravan
6. `Save Preset`
7. `Delete Preset`
8. `Import Preset`
9. `Export Preset`
10. `Custom` stanje pri rucnim izmenama
11. odmah-apply izbor iz dropdown-a
12. cuvanje poslednjeg aktivnog preseta
13. cuvanje poslednjih opštih batch vrednosti
14. preset opis u UI-ju
15. zastita built-in preseta od brisanja
16. overwrite logika za korisnicke preset-e
17. osvezavanje statusa/USB procena pri promeni preseta
18. preset ime u session log-u
19. preset ime u `IZVESTAJ.txt`
20. release/uputstvo pokrivanje za novi workflow

## Follow-on Phases

Posle ove faze najbolji naredni koraci ostaju:

1. `VHS-specific tools`
2. `Batch polish`
3. `Hardware encode options`

Preset sistem je temelj koji ce ove naredne faze uciniti mnogo brzim za svakodnevni rad.
