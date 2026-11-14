# FORBIDDEN REDEMPTION

Joc 2D pixel-art top-down pentru Game Jam-ul **„BOUNCE BACK”** (Godot 4.7, renderer Compatibility, export Web / itch.io).
Cavalerul atacă umbrele cu sabia și le întoarce proiectilele cu scutul. Saltul oferă o fereastră scurtă de invulnerabilitate.
Povestea completă și succesiunea etajelor: [docs/STORY_AND_GDD.md](docs/STORY_AND_GDD.md).

## Controale

| Tastă | Acțiune |
|---|---|
| WASD | mișcare (`SPEED = 220`) |
| P | atac cu sabia în direcția cursorului |
| L / Click stânga | **Scut / parry** (lovitura reflectată pleacă spre cursor) |
| Space | salt eschivant (invulnerabilitate scurtă, cooldown 0.8 s) |
| R | reîncearcă etajul după moarte |
| Click / Space / Enter | avansează dialogul, grăbește harta |

## Mecanica „Bounce Back”

| Regulă | Valoare | Unde |
|---|---|---|
| Fereastră parry activă | 0.15 s | `Player.PARRY_ACTIVE_TIME` |
| Perfect Parry | primele 0.05 s → viteză ×1.8, `piercing = true`, hitstop 0.05 s | `Player.PERFECT_WINDOW`, `Projectile.reflect()` |
| Normal Parry | ×1.2, dispare la primul inamic | `Projectile.NORMAL_SPEED_MULT` |
| Cooldown la ratare | 0.5 s | `Player.MISS_COOLDOWN` |
| Bounce back from death | Perfect Parry la `hp == 1` din 3 → +1 HP | `Player.try_parry()` |
| Ricoșeu din zid | o singură dată (`bounces_left = 1`), `velocity.bounce(normal)` | `Projectile._physics_process()` |
| Sulițe roșii | `unparryable = true`: nu pot fi parate, te ferești | `Enemy` tip 3 și boșii 4–5 |

## Cele 50 de subsoluri: 5 capitole

Se joacă toate etajele, de la -1 la -50 (`GameState.floor_step = 1`). Fiecare capitol are 10 subsoluri:
9 etaje cu inamicii capitolului, apoi boss-ul. Pe primul etaj al capitolului apare „CAPITOLUL N”.
În capitol, numărul de inamici crește (etajele 1–3 / 4–6 / 7–9), iar ritmul lor (`floor_difficulty`)
urcă până la ~×1.3 la etajul 9.

| Capitol | Subsoluri | Inamici | Boss (etajul 10) | Puterea boss-ului |
|---|---|---|---|---|
| 1 Cripta Fantomelor | -1 … -9 | Fantome (glob lent) | Marele Duh al Criptei (10 HP) | globuri, inele + **teleport** |
| 2 Catacombele Spiritelor | -11 … -19 | Spirite (evantai de 3) | Oracolul Fără Ochi (13 HP) | **evantaie triple**, spirale |
| 3 Osuarul Scheleților | -21 … -29 | Scheleți Arcași (săgeți rapide) | Comandantul de Os (16 HP) | salve, **ploaie de săgeți** |
| 4 Cazarma Coruptă | -31 … -39 | Cavaleri Fantomă (sabie / suliță roșie) | Garda Regală Căzută (20 HP) | săbii, sulițe + **șarjă** (sari cu Space!) |
| 5 Abisul Cărții | -41 … -49 | toți | Avatarul Cărții (25 HP, 3 faze) | toate puterile de mai sus |

Din faza 2, fiecare boss **cheamă ajutoare** din capitolul lui (max. 3); ele dispar când boss-ul moare.
Pentru o sesiune scurtă de jam, `floor_step = 5` dă „Puțurile Abisale” (-1, -5, -10 … -50).

## Fantoma Regelui (ghidul)

În subsoluri, spiritul Regelui (`entities/GhostGuide.gd`) plutește lângă Cavaler și îi dă sfaturi
într-un balon: la începutul fiecărui capitol (cine sunt dușmanii), la fiecare boss (puterea lui),
pe etajele obișnuite (sfaturi generale prin rotație) și la evenimente: prima lovitură primită,
o singură inimă rămasă, 3 parry-uri ratate la rând, primul PERFECT, primul Bounce Back, prima suliță
roșie, faza 2 a boss-ului, ajutoarele, șarja, teleportul. Sfaturile de eveniment se spun o singură
dată pe tură (`GameState.seen_tips`). La Game Over, panoul afișează un sfat al Regelui.

## Structura de foldere

```
forbidden-dungeon/
├── project.godot              # 1152x648, Nearest, input map, layere fizică, autoload-uri
├── autoload/
│   └── GameState.gd           # AUTOLOAD: poveste, etaje, HP, tranziții, hitstop, shake, SFX
├── entities/                  # entități reutilizabile
│   ├── Player.tscn / .gd      # Cavalerul + parry
│   ├── Enemy.tscn / .gd       # toți inamicii (enemy_type 0..3) + boșii (is_boss, boss_index 1..5)
│   ├── Projectile.tscn / .gd  # reflectare, piercing, ricoșeu
│   └── GhostGuide.gd          # fantoma Regelui care dă sfaturi
├── scenes/                    # cele 5 scene principale
│   ├── IntroGates.tscn / .gd  # Actul I: porțile + fasciculul magenta
│   ├── MirrorRoom.tscn / .gd  # Parter 0: numele, Regele din oglindă / Poțiunea
│   ├── CastleMap.tscn / .gd   # secțiunea castelului +2 … -50
│   ├── DungeonFloor.tscn / .gd# arena subsolurilor -1 … -50 (+ Cufărul Regal la -50)
│   └── ThroneEnding.tscn / .gd# Actul IV: tronul, Cartea, titlul, finalul
├── props/                     # obiecte de poveste desenate procedural
│   ├── Trapdoor.gd  MagicMirror.gd  Crown.gd  GateDoor.gd
│   └── Stairs.gd    Throne.gd       DarkBook.gd
├── common/                    # helperi reutilizabili
│   ├── SpriteLib.gd           # SpriteFrames din PNG-urile 16x16
│   ├── Actor.gd               # personaj de cutscene (walk_to, tremble, float)
│   ├── FX.gd                  # particule CPUParticles2D, texte plutitoare, flash
│   ├── ShakeCamera.gd  CheckerFloor.gd  NeonBeam.gd  NeonWall.gd
├── ui/
│   ├── CRTOverlay.tscn        # AUTOLOAD: CanvasLayer 100 cu shader-ul de scanlines
│   ├── DialogBox.gd           # dialog cu mașină de scris (await dialog.say(...))
│   └── HUD.gd                 # inimi, etaj, bara boss-ului, Game Over
├── shaders/
│   ├── crt_scanlines.gdshader # dungi CRT (FNaF 4)
│   ├── neon_beam.gdshader     # fascicul vertical magenta (Tomb of the Mask)
│   └── checkerboard.gdshader  # podea în carouri #0e1b33 / #152647
├── assets/sprites/            # 0x72 Dungeon Tileset II + Kenney Tiny Dungeon (CC0)
├── tests/                     # teste automate (vezi mai jos)
└── docs/STORY_AND_GDD.md
```

Straturi de coliziune: `1 player`, `2 enemies`, `3 walls`, `4 projectiles`.

## Fluxul scenelor

```
IntroGates ──click porți──▶ MirrorRoom (vizita 1: nume) ──trapă──▶ CastleMap ─▶ DungeonFloor -1
      ▲                                                                 ▲              │ curățat
      │                                                                 └──Puț Abisal──┘ (-5, -10 … -50)
      │                                       -50: boss 5 + Cufărul Regal
      │                                                   │ BOUNCE BACK!
ThroneEnding (+2) ◀── CastleMap (0→+1→+2) ◀── MirrorRoom (vizita 2: Poțiunea) ◀── CastleMap (-50→0)
```

Orice schimbare de etaj trece prin `GameState.travel_to(etaj)` → `CastleMap` → `GameState.arrive()`.

## Arborii de noduri

Nodurile marcate cu `*` sunt create din cod în `_ready()`.

### Autoload-uri
```
GameState (Node) [GameState.gd]
├── *FadeLayer (CanvasLayer, layer 90) └── *ColorRect    # fade negru între scene
└── *AudioStreamPlayer x10                              # SFX procedurale
CRTOverlay (CanvasLayer, layer 100) [CRTOverlay.tscn]
└── Scanlines (ColorRect, full rect, mouse_filter=Ignore, ShaderMaterial crt_scanlines)
```

### Entități
```
Player (CharacterBody2D, layer 1, mask walls+enemies, motion_mode Floating) [Player.gd]
├── Sprite (AnimatedSprite2D, scale 2)          # idle / run / hit (SpriteLib "knight")
├── CollisionShape2D (CircleShape2D r=8)        # hurtbox mic, top-down
├── ParryArea2D (Area2D, layer 0, mask projectiles)
│   └── CollisionShape2D (CircleShape2D r=34)
└── ParrySparks (CPUParticles2D, one_shot)

Enemy (CharacterBody2D, layer 2, mask walls+enemies) [Enemy.gd]
├── Sprite (AnimatedSprite2D)                   # aspect ales după enemy_type / boss_index
└── CollisionShape2D (CircleShape2D, duplicat per instanță, mărit pentru boși)

Projectile (Area2D, layer 4, mask player+enemies) [Projectile.gd]   # desenat în _draw()
├── CollisionShape2D (CircleShape2D r=6)
└── Trail (CPUParticles2D, local_coords=false)
```

### IntroGates.tscn
```
IntroGates (Node2D) [IntroGates.gd]           # _draw(): stele, castel degradat neon, arcada porții
├── Camera2D [ShakeCamera]                     # zoom-in rapid la final
├── Beam (Node2D)
│   ├── Glow (ColorRect) [NeonBeam]            # fascicul magenta lat, slab
│   └── Core (ColorRect) [NeonBeam]            # fascicul magenta intens
├── Gates (Node2D)
│   ├── GateLeft (Node2D) [GateDoor]
│   └── GateRight (Node2D) [GateDoor]
├── GateParticles (CPUParticles2D)
├── Knight (Node2D) [Actor]                    # tremură de frică
└── UI (CanvasLayer)
    ├── Narration (Label)
    ├── ClickPrompt (Label)  "[ CLICK PE PORȚI ]"
    └── Controls (Label)
```

### MirrorRoom.tscn
```
MirrorRoom (Node2D) [MirrorRoom.gd]            # _draw(): peretele din spate cu arcade neon
├── Camera2D [ShakeCamera]
├── Floor (ColorRect) [CheckerFloor]
├── BeamLeft / BeamRight (ColorRect) [NeonBeam]
├── Stairs (Node2D) [Stairs]                   # spre +1 / +2
├── Mirror (Node2D) [MagicMirror]
│   ├── KingGhost (Node2D) [Actor]             # Regele spectral
│   └── Sparkles (CPUParticles2D)
├── Trapdoor (Area2D) [Trapdoor]               # spre Subsolul -1
├── Knight (Node2D) [Actor]
├── King (Node2D) [Actor]                      # Regele reînviat (vizita 2)
├── Crown (Node2D) [Crown]
├── Potion (Sprite2D)
│   └── Pour (CPUParticles2D)
├── DialogBox (CanvasLayer) [DialogBox]
└── UI (CanvasLayer)
    └── *NamePanel (PanelContainer) └── *VBox: Label, HBox(LineEdit, Button "Confirmă")
```

### CastleMap.tscn
```
CastleMap (Node2D) [CastleMap.gd]              # _draw(): turnul, +2 … 0 … -50, zone, boși
├── Camera2D [ShakeCamera]                     # urmărește iconița pe verticală
├── BeamLeft / BeamRight (ColorRect) [NeonBeam]
├── KingIcon (Node2D) [Actor]                  # vizibil doar la urcarea 0 → +2
├── KnightIcon (Node2D) [Actor]
│   └── Trail (CPUParticles2D)
└── UI (CanvasLayer)
    ├── Title (Label)   ├── FloorLabel (Label)
    ├── Banner (Label)  "BOUNCE BACK!" / "SUBSOL -15"
    └── Hint (Label)
```

### DungeonFloor.tscn
```
DungeonFloor (Node2D) [DungeonFloor.gd]
├── Camera2D [ShakeCamera]
├── BeamLeft / BeamRight (ColorRect) [NeonBeam]
├── Floor (ColorRect) [CheckerFloor]           # arena 1024x480
├── Walls (Node2D)
│   └── *NeonWall (StaticBody2D, layer 3) x4 margini + 2–4 stâlpi (bank shots)
├── Exit (Area2D) [Trapdoor]                   # „Puțul Abisal”, apare după curățare
├── Enemies (Node2D)
│   ├── *Enemy (instanțe Enemy.tscn) …
│   └── *Chest (Actor "chest") + *NeonBeam auriu   # doar la -50
├── Player (instanță Player.tscn)
├── Projectiles (Node2D, z_index 5)
│   └── *Projectile …
├── Guide (Node2D) [GhostGuide]                # fantoma Regelui, urmărește jucătorul
│   ├── *Actor "king_old" (spectral)
│   └── *Bubble (PanelContainer) └── *VBox: Label „Regele (fantoma)”, Label sfat
├── HUD (CanvasLayer) [HUD]
│   └── *inimi, etaj + capitol, statistici, bara boss-ului, banner, panou Game Over cu sfat
└── DialogBox (CanvasLayer) [DialogBox]
```

### ThroneEnding.tscn
```
ThroneEnding (Node2D) [ThroneEnding.gd]        # _draw(): peretele cu vitralii
├── Camera2D [ShakeCamera]
├── BeamLeft / BeamRight (ColorRect) [NeonBeam]
├── Floor (ColorRect) [CheckerFloor]
├── Carpet (ColorRect) ├── CarpetEdgeL └── CarpetEdgeR
├── Throne (Node2D) [Throne]
├── Spirits (Node2D)
│   └── *Actor x10 (fantome, scheleți, Cavaleri Fantomă → săteni / cavaleri care îngenunchează)
├── Knight (Node2D) [Actor]
├── King (Node2D) [Actor]
├── Crown (Node2D) [Crown]                     # mutată pe capul Regelui
├── Vortex (CPUParticles2D)                    # vârtejul de lumină (radial_accel negativ)
├── Book (Node2D) [DarkBook]                   # se trântește, se ferecă, titlul auriu
│   └── *TitleLabel (Label) "FORBIDDEN REDEMPTION"
├── DialogBox (CanvasLayer) [DialogBox]
└── UI (CanvasLayer)
    ├── Confetti (CPUParticles2D)
    ├── TitleBanner (Label)  "[NUME] — GENERALUL ARMATEI REGALE"
    └── EndPanel (PanelContainer) └── VBox: GameTitle, Stats, Thanks, Replay (Button)
```

## API-ul `GameState` (autoload)

| Funcție / variabilă | Rol |
|---|---|
| `player_name`, `current_floor`, `target_floor`, `player_hp`, `max_hp` | starea jocului |
| `mirror_visit`, `has_potion`, `has_crown` | progresul poveștii |
| `travel_to(etaj)` / `arrive()` | trece prin CastleMap și intră în scena etajului |
| `next_floor_down(f)`, `zone_index(f)`, `is_boss_floor(f)`, `boss_index(f)` | logica etajelor |
| `chapter_number(f)`, `chapter_floor(f)`, `is_chapter_start(f)` | capitolele (10 subsoluri fiecare) |
| `enemy_types_for_floor(f)`, `enemy_count_for_floor(f)`, `floor_difficulty(f)` | compoziția și ritmul fiecărei arene |
| `seen_tips` | sfaturile unice ale fantomei deja spuse |
| `damage_player()`, `heal_player()`, `restore_full_hp()` + semnalul `hp_changed` | HP persistent |
| `hitstop(durată)`, `shake(px)`, `play_sfx(nume)` | „juice” |
| `change_scene(path)` | tranziție cu fade |

## Rulare și export Web

1. Deschide proiectul în **Godot 4.7** (scena principală: `scenes/IntroGates.tscn`) și apasă F5.
   O scenă rulată separat (F6) pe `DungeonFloor.tscn` pornește automat la Subsolul -1.
2. **Project → Export → Add… → Web**, exportă ca `index.html` într-un folder gol, arhivează conținutul
   (cu `index.html` în rădăcina zip-ului) și încarcă pe itch.io ca proiect HTML (viewport 1152x648).
   Exportul single-thread nu are nevoie de SharedArrayBuffer.
3. La export, în tab-ul *Resources* adaugă `tests/*` la *Filters to exclude*.

## Teste automate

```bash
godot --headless --path . res://tests/MechanicsTest.tscn
```
Verifică regulile de parry (fereastră perfectă/normală, ×1.8/×1.2, piercing, ricoșeu unic,
+1 HP la 1 HP, sulițe nereflectabile, cooldown, revenirea din hitstop), progresia celor 50 de etaje,
puterile boșilor (șarja lovește, saltul o evită, teleport, ajutoare în faza 2) și fantoma-ghid.

```bash
godot --headless --path . res://tests/SmokeTest.tscn
```
Joacă automat tot jocul (Intro → Oglindă → cele 50 de subsoluri cu cei 5 boși → Comoara → Bounce Back
→ Final) și se termină cu `SMOKE OK`. Opțiuni după `--`: `--step=5` (varianta scurtă) și
`--shots=<folder>` (fără `--headless`) pentru capturi de ecran.

## Credite

Vezi [CREDITS.md](CREDITS.md).
