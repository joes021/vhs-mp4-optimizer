# Video Converter / VHS MP4 Optimizer - kratko uputstvo

## Sta alat radi

Alat uzima velike video fajlove iz VHS/DVD digitalizacije i drugih izvora i pravi manje `.mp4` kopije za predaju musteriji. Originalne fajlove ne brise i ne menja.

## Pre pocetka

- Fajlove koje zelis da obradis stavi u jedan folder. Ulaz moze biti `.mp4`, `.avi`, `.mpg`, `.mpeg`, `.mov`, `.mkv`, `.m4v`, `.wmv`, `.ts`, `.m2ts` ili `.vob`. Program skenira i podfoldere, a preskace svoj output folder.
- USB za predaju musteriji formatiraj kao `exFAT` ako ce pojedinacni fajlovi biti veci od 4 GB.
- Ako zelis maksimalno da sacuvas original, zadrzi DV AVI ili veliki MP4 kao arhivu kod sebe.
- Ako alat nosis na drugi racunar, kopiraj ceo folder `release/VHS MP4 Optimizer`.

## Koraci

1. Pokreni Desktop precicu `VHS MP4 Optimizer`.
2. Klikni `Browse...` kod `Input folder` i izaberi folder sa velikim video fajlovima.
3. `Output folder` moze da ostane podrazumevano: `vhs-mp4-output`.
   - Glavni prozor je sada podeljen na `Source / Output / FFmpeg`, `Quick Setup` i skriveni `Advanced Settings`.
   - Za svakodnevni batch tok obicno ostajes u `Quick Setup`, a `Show Advanced` otvaras samo kad ti trebaju detaljni parametri.
4. Izaberi `Workflow preset` ako zelis gotov skup opštih batch podesavanja:
   - `USB standard` za najprakticniju predaju na USB, sa ukljucenim split tokom.
   - `Mali fajl` kada je prioritet sto manja velicina.
   - `High quality arhiva` kada zelis bolji kvalitet i bez obaveznog splitovanja.
   - `HEVC manji fajl` kada zelis jos manju velicinu uz H.265.
   - `VHS cleanup` kada hoces odmah ukljucen deinterlace, blagi denoise, audio normalize i `Auto apply crop if detected` za tipican VHS materijal.
   - ako posle rucno promenis neko opste polje, preset prelazi u `Custom`.
5. Po potrebi koristi:
   - `Save Preset` da sacuvas sopstveni workflow preset
   - `Delete Preset` da obrises korisnicki preset
   - `Import Preset` i `Export Preset` za `.json` razmenu preset-a
6. Ako ne koristis `Workflow preset`, ili hoces da proveris sta on radi, pogledaj `Quality mode`:
   - `Universal MP4 H.264` za najkompatibilniju predaju musteriji.
   - `Small MP4 H.264` kada fajl mora biti sto manji.
   - `High Quality MP4 H.264` za vazne snimke gde velicina nije glavni problem.
   - `HEVC H.265 Smaller` za manji fajl uz noviji H.265 kodek.
   - `Standard VHS`, `Smaller File`, `Better Quality` i `Custom` ostaju dostupni za stari VHS tok rada.
7. Ako dugacak snimak mora da stane na USB koji ne prima fajlove vece od 4 GB, ukljuci `Split output` i ostavi `Max part GB` na `3.8`.
8. Klikni `Scan Files`. Program pregleda izabrani folder i podfoldere.
9. Pogledaj `Media info` kolone i `Properties` panel na glavnom batch ekranu:
   - videces format, kontejner, rezoluciju, odnos stranica, FPS, broj frejmova, protok, audio i trajanje.
   - ako `ffprobe` ne moze da procita fajl, obrada moze da se nastavi, ali detalji i procena mogu ostati prazni.
10. Ako treba ozbiljniji pregled ili trim, izaberi fajl i klikni `Open Player` ili ga otvori duplim klikom u tabeli.
11. U prozoru `Player / Trim`:
   - `Playback mode` radi za moderne fajlove kao `.mp4`, `.mov` i `.mkv`.
   - `Preview mode` je fallback za `.avi`, MSDV i `.mpg`, ili kada playback ne moze da se ucita.
   - `Play / Pause`, timeline i `Frame` dugmad sluze za precizno trazenje kadra.
   - `Set Start`, `Set End`, `Cut Segment`, `Remove` i `Clear Cuts` rade trim i multi-cut unutar posebnog prozora.
   - `Aspect / Pixel shape` deo drzi lokalni `Aspect mode` izbor za taj fajl: `Auto`, `Keep Original`, `Force 4:3` i `Force 16:9`.
   - Linija `Detected: ... -> ...` pokazuje sta je alat procitao i na koju izlaznu sirinu/visinu planira da mapira video.
   - `DAR`, `SAR` i `Planned output aspect` u istom delu pomazu da odmah vidis da li je PAL/DV ili NTSC/DV snimak pravilno protumacen.
   - `Crop / Overscan` deo sluzi za skidanje crnih ivica i VHS overscan zone bez izlaska iz istog prozora.
   - `Detect Crop` predlaze crop za trenutno izabrani fajl, `Auto Crop` odmah prihvata auto rezultat, a `Clear Crop` vraca stanje na bez crop-a.
   - Polja `Left`, `Top`, `Right` i `Bottom` su rucna pixel korekcija kada hoces finije da pomeris granice.
   - `Crop overlay` pokazuje aktivni crop preko preview slike da odmah vidis koliko se sece sa svake strane.
   - `Save to Queue` vraca trim izmene nazad u glavni batch, bez posebnog exporta iz tog prozora.
12. Glavni batch ekran sada ostaje cist:
   - prikazuje queue, batch komande i `Properties` pregled za izabrani fajl
   - ne drzi stalno otvoren preview/trimming panel
   - pravi pregled, timeline, trim, crop i aspect rade samo u posebnom `Player / Trim` prozoru
   - kolone `Range`, `Crop` i `Aspect` i dalje pokazuju sta je vec upisano za svaki fajl
13. Ako snimak treba tehnicki popraviti, klikni `Show Advanced` pa koristi red `Video filters`:
   - `Deinterlace` za nazubljene linije kod VHS/DVD interlaced snimaka.
   - `Denoise` za blago smanjenje suma.
   - `Rotate/flip` za pogresno okrenute snimke.
   - `Scale` za izlaz na `PAL 576p`, `720p` ili `1080p`.
   - `Audio normalize` za tise ili neujednacene snimke.
   - `Auto apply crop if detected` automatski primenjuje detektovan crop pri `Start Conversion` za fajlove koji nemaju rucni crop.
14. U istom `Advanced Settings` delu imas i `Encode engine`:
   - `Auto` je bezbedan podrazumevani tok.
   - `CPU (libx264/libx265)` daje najpredvidljiviji kvalitet.
   - `NVIDIA NVENC`, `Intel QSV` i `AMD AMF` su dostupni kada ih FFmpeg i masina stvarno podrzavaju.
   - Ako hardware init padne, alat se bezbedno vraca na CPU umesto da prekine batch.
15. Pogledaj kolone `Estimate` i `USB note`:
   - `Estimate` je okvirna velicina gotovog MP4 fajla ili broj delova.
   - `USB note` javlja da li je bolje koristiti `Split output` ili `exFAT`.
16. Klikni `Test Sample` ako zelis prvo da napravis kratak probni MP4 od 120 sekundi. Sample ide u folder `samples`.
17. Klikni `Start Conversion`.
18. Program pre starta radi `FFmpeg preflight` proveru da uhvati losu ili pogresnu FFmpeg putanju.
19. Dok batch radi, `Pause` znaci: zavrsi trenutni fajl pa stani pre sledeceg.
20. Kada status predje na `Paused`, mozes da:
   - kliknes `Resume` da nastavis od prvog sledeceg `queued` fajla
   - koristis `Move Up` i `Move Down` da promenis redosled preostalih `queued` stavki
   - promenis opsta batch podesavanja i `Workflow preset`; queued fajlovi se odmah osvezavaju
   - otvoris `Open Player`, `Test Sample`, trim, crop i aspect za fajlove koji jos nisu krenuli
21. `Queue` meni i batch dugmad daju jos brzu kontrolu:
   - `Skip Selected` sklanja jedan queued fajl iz ove runde
   - `Retry Failed` vraca neuspele fajlove nazad u queue
   - `Clear Completed` cisti `done`, `skipped` i `stopped` stavke
   - `Save Queue` i `Load Queue` cuvaju ceo batch plan sa trim/crop/aspect stanjem
22. Prati `Total progress` za ceo posao i `File progress` za trenutni fajl, procenat i ETA.
   - Donji workspace je podeljen na `Status`, `Progress` i `Log`, a preview vise nije naguran u glavni ekran.
23. Kada zavrsi, program pravi `IZVESTAJ.txt`, pusti kratak Windows signal i prikaze obavestenje.
24. Klikni `Open Output` i prebaci gotove `.mp4` fajlove na USB ili cloud.
25. U meniju `Help` imas `About VHS MP4 Optimizer`, `Check for Updates` i `Open User Guide`.

## Split output

`Split output` pravi prave MP4 delove, na primer:

- `svadba-part001.mp4`
- `svadba-part002.mp4`
- `svadba-part003.mp4`

Ovo nije obicno secenje fajla na bajtove, nego FFmpeg pravi validne video delove koji mogu da se puste pojedinacno. Vrednost `3.8` je prakticna za FAT32 USB zato sto ostavlja malo rezerve ispod 4 GB.

## Player / Trim prozor

Ako kliknes `Open Player` ili uradis dupli klik na red u tabeli, otvara se poseban floating prozor `Player / Trim`. To je glavni editor za rad nad jednim fajlom i moze da stoji pored batch prozora.

- `Playback mode` daje pravi video pregled za `.mp4`, `.mov` i `.mkv`.
- `Preview mode` koristi isti precizan trim workflow i FFmpeg frame preview za `.avi`, MSDV, `.mpg` i slicne problematicke fajlove.
- veliki preview je levo, timeline je ispod preview-a, a trim/crop/aspect/properties alati su u desnoj koloni
- `Preview Frame` ne menja originalni fajl; samo pravi sliku za proveru kadra
- `Open Video` otvara originalni fajl u podrazumevanom Windows player-u
- `Start`, `End` i `CUT` oznake su stalno vidljive iznad trim sekcije, tako da se lako prati aktivan opseg
- `Apply Trim` upisuje jedan trim opseg, a `Cut Segment` / `Remove` / `Clear Cuts` rade multi-cut tok
- `Clear Trim` brise aktivni trim za taj fajl
- `Aspect / Pixel shape` sekcija u istom prozoru drzi lokalni `Aspect mode` za taj fajl:
  - `Auto` koristi metadata + PAL/DV ili NTSC/DV heuristiku.
  - `Keep Original` cuva isti prikaz izvora, ali po potrebi pravi square-pixel izlaz.
  - `Force 4:3` i `Force 16:9` rucno prepisuju auto odluku kad znas da je flag u fajlu pogresan.
- Status linija `Detected: ... -> ...` pokazuje sta je alat zakljucio i koju izlaznu geometriju planira.
- Linija sa `DAR`, `SAR` i `Planned output aspect` pomaze da odmah proveris da li je anamorphic materijal pravilno protumacen.
- `Crop / Overscan` deo u istom prozoru drzi `Detect Crop`, `Auto Crop`, `Clear Crop` i rucna polja `Left`, `Top`, `Right`, `Bottom`.
- `Crop overlay` preko preview slike pomaze da odmah vidis koliko se sece.
- `Save to Queue` ne pravi novi fajl odmah, nego samo cuva trim i segmente nazad u glavni batch.
- Ako zatvoris prozor sa nesacuvanim izmenama, alat te pita da li hoces `Save`, `Discard` ili da ostanes u prozoru.

## Aspect / Pixel shape

`Aspect / Pixel shape` resava stare PAL/DV i NTSC/DV snimke koji cesto imaju pogresan ili nedostajuci prikaz slike.

- `Aspect mode` radi po fajlu i ne dira druge stavke u queue-u dok ne kliknes `Save to Queue`.
- `Auto` je najbolji pocetak za vecinu materijala, jer cita `DAR` i `SAR`, pa po potrebi ukljuci PAL/DV ili NTSC/DV logiku.
- `Keep Original` zadrzava isti stvarni prikaz slike bez obzira na storage rezoluciju.
- `Force 4:3` koristi kada je izvorni snimak ocigledno standardni TV kadar.
- `Force 16:9` koristi kada je video sirok, a fajl je pogresno flagovan ili izgleda stisnuto.
- `Detected: ... -> ...` pokazuje prepoznati tip i planiranu izlaznu geometriju.
- `DAR`, `SAR` i `Planned output aspect` su najbrzi nacin da proveris da li ce izlaz izgledati ispravno na danasnjim playerima i televizorima.

## Video filters

`Video filters` su globalna podesavanja za ceo batch. Podrazumevano su iskljuceni, tako da program ne menja izgled snimka ako ih ne ukljucis.

- `Deinterlace` koristi `YADIF` i sluzi za VHS/DVD snimke koji imaju nazubljene linije pri pokretu.
- `Denoise` ima `Light` i `Medium`; kreni od `Light`, jer prejako ciscenje moze da omeksa sliku.
- `Rotate/flip` ispravlja snimke koji su okrenuti pogresno ili ogledalno.
- `Scale` pravi izlaz u originalnoj rezoluciji, `PAL 576p`, `720p` ili `1080p`.
- `Audio normalize` izjednacava tisinu/jacinu jednim FFmpeg `loudnorm` prolazom.
- `Auto apply crop if detected` koristi prethodno nadjen auto crop kada pustis batch, ali ne gazi rucni crop koji si postavio za konkretan fajl.

Za vazne snimke prvo klikni `Test Sample`, pogledaj uzorak, pa tek onda pusti ceo batch. `IZVESTAJ.txt` belezi aktivne filtere.

## Crop / Overscan

`Crop / Overscan` radi po fajlu i najkorisniji je za VHS snimke koji imaju crne ivice, head-switching sum ili stari TV overscan. Nalazi se u `Player / Trim` prozoru, tako da crop i trim ostaju u istom toku rada.

- `Detect Crop` analizira preview i predlaze koliko da se skine.
- `Auto Crop` odmah prihvata predlog i upisuje ga kao aktivan crop.
- `Clear Crop` brise i auto i rucni crop za izabrani fajl.
- `Left`, `Top`, `Right` i `Bottom` su pixel vrednosti po strani; njih koristi kad hoces da ispravis auto rezultat ili da sve podesis rucno.
- `Crop overlay` u preview delu pokazuje aktivnu crop zonu preko slike, pa mozes odmah da proveris da li je odseceno previse.

Praktican tok je: otvori fajl preko `Open Player`, klikni `Detect Crop` ili `Auto Crop`, po potrebi doteraj `Left`, `Top`, `Right` i `Bottom`, pogledaj `Crop overlay`, pa tek onda `Save to Queue`. Ako hoces da se batch sam osloni na vec nadjene auto rezultate, ukljuci `Auto apply crop if detected` pre `Start Conversion`.

## Workflow preset

`Workflow preset` je novi sloj iznad pojedinacnih kontrola. On ne dira `Input folder`, `Output folder`, `FFmpeg path`, trim ni segmente, nego samo opsta batch podesavanja:

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
- `Auto apply crop if detected`
- `Max part GB`

Kad izaberes preset, te vrednosti se odmah upisu u formu. Ako zatim rucno promenis neku od njih, stanje prelazi u `Custom`. To je korisno kad nadjes dobar odnos kvaliteta i velicine za konkretnu musteriju i hoces da ga sacuvas preko `Save Preset`.

## Pause / Resume batch

`Pause` ne prekida FFmpeg na pola trenutnog fajla. Umesto toga, alat zavrsava taj fajl i onda prelazi u stanje `Paused`.

- `Paused after current file` znaci da je zahtev za pauzu primljen i da se ceka kraj aktivnog fajla.
- `Paused` znaci da nijedan novi fajl nece krenuti dok ne kliknes `Resume`.
- `Resume` nastavlja od prvog sledeceg `queued` reda u tom trenutnom redosledu.
- `Move Up` i `Move Down` rade nad `queued` stavkama, pa mozes da prepakujes ostatak batch-a bez diranja vec zavrsenih fajlova.
- Ako tokom pauze promenis `Quality mode`, `CRF`, `Workflow preset`, `Split output` ili druge opste batch filtere, queued deo plana se odmah osvezava.
- Vec zavrseni fajlovi ostaju zavrseni; pause/resume ne vraca ih nazad u queue.

## Queue alati

Glavni meni `Queue` i batch dugmad u glavnom prozoru sluze za brze korekcije reda bez ponovnog skeniranja foldera.

- `Skip Selected` odmah prebacuje jedan queued fajl u `skipped`.
- `Retry Failed` vraca sve `failed` stavke nazad u `queued`.
- `Clear Completed` izbacuje `done`, `skipped` i `stopped` stavke iz liste.
- `Save Queue` cuva ceo batch plan u `.json`, ukljucujuci trim, crop, aspect i opsta podesavanja.
- `Load Queue` vraca taj isti plan kasnije, tako da mozes da nastavis posao bez novog ručnog preslaganja.

## Encode engine

`Encode engine` je u `Advanced Settings` delu i odredjuje da li kodiranje ide preko CPU ili podrzanog hardverskog enkodera.

- `Auto` ostavlja provereni CPU tok kao podrazumevani izbor.
- `CPU (libx264/libx265)` je najpredvidljiviji za kvalitet i kompatibilnost.
- `NVIDIA NVENC`, `Intel QSV` i `AMD AMF` koriste hardware encode kada ih FFmpeg i masina stvarno podrzavaju.
- Status linija pokazuje `RuntimeReadyModes`, pa odmah vidis sta je spremno za rad.
- Ako hardware init ne uspe, alat bezbedno pada nazad na CPU umesto da prekine batch.

## Help / About / Update

- `Help -> About VHS MP4 Optimizer` pokazuje `Current version`, `Release tag`, `Git ref`, `Install type`, `Install path` i GitHub repo.
- `Help -> Open User Guide` otvara lokalno uputstvo iz release paketa.
- `Help -> Check for Updates` proverava poslednji GitHub release i pita pre bilo kakvog preuzimanja.
- Pri pokretanju program povremeno sam proveri da li postoji noviji release, ali nista ne preuzima bez pitanja.

## Procena za USB

Procena velicine je orijentaciona, jer realna velicina zavisi od sadrzaja snimka. Dobra je za odluku pre pokretanja posla:

- ako `USB note` kaze `FAT32 rizik`, ukljuci `Split output` ili formatiraj USB kao `exFAT`
- ako je split ukljucen, program prikazuje procenjen broj MP4 delova

## Media info / Properties

`Scan Files` koristi `ffprobe` iz FFmpeg paketa da procita tehnicke podatke o svakom ulaznom fajlu. U tabeli se vide kratke vrednosti, a `Properties` panel na glavnom batch ekranu prikazuje detalje za izabrani fajl:

- kontejner i format
- trajanje i velicina
- ukupni bitrate
- video kodek, rezolucija, odnos stranica, FPS, broj frejmova i video bitrate
- audio kodek, broj kanala, sample rate i audio bitrate

Ovi podaci pomazu da odmah vidis da li je fajl stvarno DV/MSDV AVI, MPEG/DVD export, H.264 MP4, HEVC, telefon `.mov`, `.mkv` arhiva ili nesto drugo.

## Izvestaj

Posle obrade u output folderu nastaje `IZVESTAJ.txt`. U njemu su podesavanja, status svakog ulaznog fajla i napomena da originalni fajlovi nisu menjani. Taj fajl mozes da ostavis musteriji uz gotove MP4 fajlove.

Izvestaj sadrzi i kratak `USB PREDAJA CHECKLIST` sa podsetnikom za `exFAT`, `FAT32`, proveru MP4 fajlova i kopiranje izvestaja.

## Release folder

Folder `release/VHS MP4 Optimizer` je spreman za kopiranje na drugi Windows racunar. U njemu su launcher, ikona, skripte, `README - kako se koristi.txt` i `USB PREDAJA CHECKLIST.txt`. Ako se izvorne skripte promene, pokreni `scripts/build-vhs-mp4-release.ps1` da se release folder osvezi.

## Portable ZIP i Setup installer

Ako hoces paket za slanje drugima preko GitHub-a ili clouda:

- `scripts/build-vhs-mp4-installer.ps1` pravi:
  - portable ZIP paket
  - `installer-manifest.json`
  - `Setup.exe` kada je dostupan `ISCC.exe` iz Inno Setup-a
- `scripts/publish-vhs-mp4-github-release.ps1` cita taj manifest i kaci artefakte na GitHub release

Tipican tok:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-vhs-mp4-installer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/publish-vhs-mp4-github-release.ps1
```

Portable ZIP zavrsava u `dist/VHS MP4 Optimizer`, a installer koristi Inno Setup skriptu `packaging/vhs-mp4-optimizer.iss`.

## Preporuka za prvi test

Prvo probaj `Test Sample` na jednom pravom fajlu iz svake grupe koju cesto dobijas, na primer `.mp4`, DV/MSDV `.avi`, `.mpg/.mpeg`, `.mov`, `.mkv`, `.wmv`, `.m2ts` ili `.vob`. Ako `Universal MP4 H.264` daje prevelik fajl, probaj `Small MP4 H.264` ili `HEVC H.265 Smaller`. Ako ti slika izgleda previse stisnuto, koristi `High Quality MP4 H.264`.
