# DOCUMENT DE POVESTE ȘI GAME DESIGN: "FORBIDDEN REDEMPTION"
**Temă Game Jam:** Bounce Back
**Gen:** 2D Top-Down Parry Action / Narrative Dungeon Crawler (Pixel Art)

---

## 1. SINOPSISUL POVEȘTII
Într-un regat măcinat de timp domnea un Rege bătrân care, în lăcomia și uitarea sa, nu și-a mai amintit unde și-a ascuns comoara regală. Săpând și căutând prin cele mai adânci catacombe ale palatului, Regele a deschis din greșeală **Cartea Întunericului**. Forțele abisale au năpădit castelul: locuitorii și gărzile au fost transformați în fantome, spirite, scheleți și cavaleri fantomă, iar Regele a murit, sufletul său rămânând încarcerat în **Oglinda de la Parterul Castelului (Etajul 0)**.

Un Cavaler rătăcitor (Jucătorul) află de existența castelului blestemat și pornește în căutarea lui.

---

## 2. REFERINȚE VIZUALE OBLIGATORII
1. **Stilul "Tomb of the Mask":**
   - Folosit la scena porților exterioare, la harta secțiunii castelului și la efectele magice.
   - Fundal negru intens cu un fascicul vertical uriaș de lumină **Magenta Neon** care iese din porțile castelului și titluri/coroane în **Galben Auriu**.
2. **Stilul "FNaF 4 Retro Minigames":**
   - Folosit în interiorul camerelor castelului și în arenele de luptă.
   - Podea în carouri (tablă de șah) albastru-închis cu negru, personaje pixel-art 16x16 văzute top-down/2.5D și efect de **CRT Scanlines** (dungi orizontale negre semi-transparente peste tot ecranul).

---

## 3. SUCCESIUNEA SCENELOR ȘI A ETAJELOR (FLOW-UL COMPLET)

### ACTUL I: PORȚILE ȘI OGLINDA (ETAJUL 0)
1. **Scena `IntroGates.tscn` (Exteriorul Castelului):**
   - Cavalerul ajunge în fața castelului degradat și se înfricoșează (tremur ușor de sprite + text narativ).
   - **Interacțiune:** Jucătorul dă **CLICK pe porțile palatului**.
   - **Animație:** Porțile se deschid, un fascicul vertical magenta (stil *Tomb of the Mask*) țâșnește spre cer, iar camera face zoom-in rapid în interiorul palatului.
2. **Scena `MirrorRoom.tscn` (Parter - Etajul 0 - Prima Vizită):**
   - Cavalerul înaintează pe podeaua în carouri albastre până în fața Oglinzii Blestemate.
   - În oglindă apare silueta spectrală a Regelui.
   - **Input Jucător:** Apare o casetă (`LineEdit`) în care jucătorul își introduce numele (`GameState.player_name`).
   - **Dialog Rege:** *"Ascultă-mă, [Nume Jucător]! Căutându-mi comoara uitată, am eliberat blestemul Cărții Întunericului și am fost închis în această oglindă. Te pot călăuzi prin catacombe! Coboară până la Subsolul -50, înfruntă armata umbrelor întorcându-le propriile atacuri și găsește Comoara Regală!"*
   - Se deschide trapa către Subsolul `-1`.

### ACTUL II: COBORÂREA ÎN CELE 50 DE SUBSOLURI (ETAJUL -1 -> -50)
3. **Scena `CastleMap.tscn` (Secțiunea Transversală a Castelului):**
   - Între etaje, jucătorul vede o secțiune verticală a întregului castel:
     - `+2`: Sala Tronului
     - `+1`: Galeria Regală
     - `0`: Parter (Sala Oglinzii)
     - `-1 ... -50`: Subsolurile Castelului
   - O iconiță cu Cavalerul coboară animat către etajul curent.
4. **Scena `DungeonFloor.tscn` (Arenele Subterane -1 până la -50):**
   - **Notă de Pacing pentru Game Jam:** Poți parcurge etajele individual sau prin "Puțuri Abisale" care coboară câte 5 etaje per luptă câștigată (`-5, -10, -15, -20 ... -50`), astfel încât jucătorul să experimenteze toate zonele și toți cei 5 Boși într-o sesiune de 10 minute.
   - **Structura Zonelor și a Boșilor:**
     - **Subsol -1 .. -9:** *Cripta Fantomelor* (Inamici: Fantome) -> **Nivelul -10 (BOSS 1): Marele Duh al Criptei**.
     - **Subsol -11 .. -19:** *Catacombele Spiritelor* (Inamici: Spirite cu atac triplu) -> **Nivelul -20 (BOSS 2): Oracolul Fără Ochi**.
     - **Subsol -21 .. -29:** *Osuarul Scheleților* (Inamici: Scheleți Arcași) -> **Nivelul -30 (BOSS 3): Comandantul de Os**.
     - **Subsol -31 .. -39:** *Cazarma Coruptă* (Inamici: Cavaleri Fantomă) -> **Nivelul -40 (BOSS 4): Garda Regală Căzută**.
     - **Subsol -41 .. -49:** *Abisul Cărții* (Toate tipurile de monștri) -> **Nivelul -50 (BOSS 5 - CEL MAI GREU): Avatarul Cărții Întunericului**.

### ACTUL III: COMOARA ȘI "BOUNCE BACK" LA PARTER (-50 -> 0)
5. **Descoperirea Comorii (La Subsolul -50, după înfrângerea Boss-ului 5):**
   - Apare Cufărul Regal. Înăuntru, pe lângă aur și **Coroana Regală**, Cavalerul descoperă **Poțiunea Vieții Veșnice** (care oferă tinerețe veșnică sau poate reînvia o persoană din morți).
   - Cavalerul decide să nu o păstreze pentru sine, ci să i-o dăruiască Regelui.
   - **Ascensiunea ("Bounce Back"):** Pe harta secțiunii castelului (`CastleMap.tscn`), Cavalerul urcă fulgerător din străfundul `-50` înapoi la Parter (`0`).
6. **Scena `MirrorRoom.tscn` (Parter - Etajul 0 - A Doua Vizită):**
   - Cavalerul toarnă Poțiunea în Oglinda Spartă.
   - Oglinda strălucește orbitor, iar Regele reînvie în carne și oase, tânăr și eliberat.
   - Cavalerul îi oferă **Coroana Regală**.
   - Împreună, pornesc pe scările superioare, urcând încă **2 etaje (`+1` și `+2`)** spre Sala Tronului.

### ACTUL IV: SALA TRONULUI ȘI CARTEA "FORBIDDEN REDEMPTION" (ETAJUL +2)
7. **Scena `ThroneEnding.tscn` (Etajul +2 - Sala Tronului):**
   - Regele își așază Coroana pe cap și se pune pe Tronul Regal.
   - În acel moment, un vârtej de lumină absoarbe tot întunericul din castel înapoi în **Cartea Blestemată** din care ieșise.
   - Cartea se trântește și se ferecă în prim-plan, iar pe coperta ei apare inscripționat cu litere aurii titlul jocului: **"FORBIDDEN REDEMPTION"**.
   - **Transformarea Finală:** Toate fantomele și toți scheleții din castel revin la viață ca foștii locuitori ai cetății! Cavalerii Fantomă își recapătă chipul uman și îngenunchează în fața Regelui și a Cavalerului (`[Nume Jucător]`), care este numit **Generalul Armatei Regale**.

---

## 4. HARTA CASTELULUI

```
                   =========================================
                  /          TURNUL TRONULUI (+2)           \
                 /   [TRONUL REGAL & CARTEA BLESTEMATĂ]      \
                +---------------------------------------------+
                |  ETAJ +2 : Sala Tronului (Finalul Jocului)  |  <-- PASUL 4: Urcă 2 etaje (+1, +2),
                +---------------------------------------------+               Regele se așază pe tron!
                |  ETAJ +1 : Galeria Cavalerilor              |
 ===============+=============================================+===============
 [PORȚILE] ---> |  PARTER 0: SALA OGLINZII SPARTE [REGE]      |  <-- PASUL 1: Intri, scrii numele.
 (Click Intro)  |            (Punct de Plecare & Reînviere)   |  <-- PASUL 3: Torni Poțiunea în oglindă!
 ===============+=============================================+===============
       |        |  SUBSOL  -1 ..  -9 : Cripta Fantomelor      |        ^
       |        |  SUBSOL -10 [BOSS 1: Marele Duh]            |        |
       v        +---------------------------------------------+        |
    COBORÂRE    |  SUBSOL -11 .. -19 : Catacombele Spiritelor |    BOUNCE BACK!
    PRIN CELE   |  SUBSOL -20 [BOSS 2: Oracolul Orb]          |   (Urcare rapidă
     50 DE      +---------------------------------------------+    de la -50 la 0
    SUBSOLURI   |  SUBSOL -21 .. -29 : Osuarul Scheleților    |    cu Poțiunea și
       |        |  SUBSOL -30 [BOSS 3: Comandantul de Os]     |       Coroana)
       |        +---------------------------------------------+        |
       |        |  SUBSOL -31 .. -39 : Cavaleri Fantomă       |        |
       v        |  SUBSOL -40 [BOSS 4: Garda Căzută]          |        |
                +---------------------------------------------+        |
                |  SUBSOL -41 .. -49 : Abisul Întunericului   |        |
                |  SUBSOL -50 [BOSS FINAL: Umbra Cărții]      |        |
                |             [COMOARA + POȚIUNEA]            | -------+
                +=============================================+
```
