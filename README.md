# Logic In Dungeon (v28)

The game is the assembly program (`game.asm` plus its `.inc` files, and `CC.asm`).
`rd_gui.c` is the raylib front end. It runs the assembly game in a hidden terminal, reads what
the game prints, and draws the interface. All game rules stay in assembly.
`logicindungeon.asm` is the same game with every include pasted into one file (made by `python3 tools/inline_asm.py`).

## Build and run (Fedora)

    sudo dnf install nasm raylib-devel
    sh build_gui.sh          # builds ./game and ./rd_gui
    ./rd_gui                 # raylib window
    ./game                   # the terminal version still works on its own

To build the single file instead:

    nasm -f elf32 CC.asm -o CC.o
    nasm -f elf32 logicindungeon.asm -o game.o
    ld -m elf_i386 game.o CC.o -o game

If your raylib is built from source, run `RAYLIB_DIR=/path/to/raylib/src sh build_gui.sh`.

**Step-by-step setup for Fedora, Ubuntu/Debian, Arch and Windows (through WSL2) is in `HOW_TO_RUN.md`.**

## Sound and music (v16)

The window plays sound effects and music. Every file is found by name, and a missing file is
simply silent, so you can add audio a few files at a time.

- Sound effects: `assets/sfx/<name>.wav` (`.ogg`, `.mp3` and `.flac` work too). Numbered files
  (`footstep_1.wav`, `footstep_2.wav`, ...) are variants, and one is picked at random each time.
- Music: `assets/music/<name>.ogg` (or `.mp3` / `.wav`). The tracks loop and fade between each
  other. `victory` and `game_over` play once.
- **F9** turns sound on and off. **F10** turns music on and off.
- All 81 sound effects are in `assets/sfx`. Everything except the five footsteps was made from
  scratch by `tools/audio/sfx_synth.py` (`python3 tools/audio/sfx_synth.py OUTDIR [names...]`, needs numpy
  and scipy). See `CREDITS.txt`.

Music file names (add whichever you have):

| File | Plays |
|---|---|
| `title` | Title screen |
| `class_select` | Choosing a hero and the character sheet (falls back to `title`) |
| `explore` | Floors 1-15 |
| `circuits` | Floors 16-29 (falls back to `explore`) |
| `boss_warden`, `boss_bishops`, `boss_shade`, `boss_ymir`, `boss_keeper`, `boss_duo`, `boss_king`, `boss_unbound` | While that boss is in the room |
| `boss_generic` | Any boss without its own track |
| `victory`, `game_over` | Once, at the end |
| `level_up`, `floor_clear` | Optional short jingles. `level_up` replaces the level-up sound effect |

The King's fake death goes silent. The revival sound plays when he rises, and the white flash and
the roar land on its burst.

## The 30 floors

| Floors | What waits there |
|---|---|
| 1-14 | Logic gate rooms: torch pairs, one gate, a riddle on the plaque |
| 4, 8 | **Warden** |
| 12 | **The Four Bishops** (new in v20) |
| 15 | **Dark Shade of the Forgotten King** |
| 16, 18-20 | Circuits: `(A ? B) ? C`, three torches and two gates |
| 17 | **Grand Wizard Ymir** |
| 21 | **The Logic Keeper** |
| 22-24 | Circuits: the one above, or `(A ? B) ? NOT C` |
| 25, 27-29 | Circuits: four torches `(A ? B) ? (C ? D)`, or the NOT circuit. One gate is hidden (`???`) and the plaque gives its riddle |
| 26 | **Altair and Smo** |
| 30 | **The Forgotten King**, and then the Forgotten King, **Unbound** |

Boss rooms start the fight as soon as you walk in, and the door opens only when the boss (or both bosses) is dead.
Every boss is a logic puzzle as well as a fight. Stats are in `game_assets.asm`; the rules are in `bosses.inc`.
HP is the base roll; every enemy also gets +1 HP per floor, and bosses +25% (v20).

## The bosses

**Warden (floors 4 and 8, 3x3).** His shield shows a gate: AND or OR on floor 4, plus XOR on floor 8.
- He takes half damage until the torch pair matches that gate.
- The pair starts behind him. Matching it breaks the shield for 2 rounds.
- Then he shouts "Burn anew!", his beam throws the torches to the other side of the room, and the shield returns with a new gate and the torches set wrong.
- If someone is standing where the torches would land, they pick a free row instead.

**Dark Shade (floor 15, 5x3).** The room is dark.
- The Shade takes no damage in darkness and half damage in a lit torch's light (4 cells).
- The left torch pair feeds one gate and the right pair another. When both output 1, the lantern in the middle blazes for 2 rounds and the Shade takes full damage anywhere.
- The Shade hunts lit torches and snuffs one at most every other round. With NAND or NOR gates, putting a torch out can light the lantern by itself.
- When the lantern's 2 rounds end, the Shade shatters it: new gates, and the torches go dark.

**Grand Wizard Ymir (floor 17, 4x4).**
- The top-left and top-right torches feed the top gate; the bottom pair feeds the bottom gate.
- When a gate outputs 1, its blue power torch goes out. Each lit power torch gives Ymir 2 spells a turn (Firebolt, Frost Lance, Lightning, Meteor), so at most 4, and he can reach the whole room.
- He blinks away if you stand next to him.
- With both power torches out he is stunned and takes +50% damage. Then he releases a blue wave: it pushes you away (10-16 damage if you are within 2 cells), relights both power torches and sets new gates.

**The Four Bishops (floor 12, four 2x2, new in v20).**
- One in each corner, joined in a square by yellow lines. On each side stands a gate that is TRUE for the two bishops it joins.
- One bishop is secretly the 1. The two sides touching it show XOR, the other two NOR, so the 1 is where the two XORs meet.
- Once the 1 has been found twice, two neighbouring bishops are 1s: AND between them, XOR on the sides leaving them, NOR opposite.
- Only a 1 can be hurt; the 0s ignore every hit. When a 1 is hurt, the light moves to another bishop and the gates change.
- They never move. All four cast every round but only one beam lands: Smite (burns you for 2 a round, 2 rounds) and Judgment (knocks you back 2 squares), in turn.
- One shared health pool: when it is empty all four fall.

**Logic Keeper and its two Wardens (floor 21, reworked in v20).**
- Two Wardens fight beside the Keeper (they move and attack like any Warden), joined to it by blue links. While any Warden is linked, the Keeper can't be hurt.
- Each Warden has its own gate on its shield and its own torch pair. Match a pair to that Warden's gate: its shield breaks and its link is cut for 4 rounds, and it reels.
- Then it links up again with a new gate. A Warden that dies is cut for good. With both links cut the Keeper takes full damage; when it falls, its Wardens fall with it.
- The plaque gives both Wardens' riddles.

**Altair (2x2) and Smo (4x4) (floor 26).**
- A yellow NOT line joins them. One carries a 1 (half damage), the other a 0 (+50% damage).
- At the end of each of their turns there is a 50% chance they swap.
- When one falls, the bits are gone and the survivor takes the other's power: full HP, +2 to hit, +3 damage.

**Forgotten King (floor 30).**
- He stays on his throne and strikes you anywhere in the room.
- The throne is wired to a circuit of four torches and three gates. He can only be wounded while the wire into the throne carries a 1.
- At 2/3 and 1/3 HP he slams the throne and the circuit rewires. The second time every gate is hidden, and each plaque read gives the riddle of the next gate (the window keeps all of them pinned).
- At 0 HP he only pretends to die: the throne explodes and he rises as **the Forgotten King, Unbound**.
- Unbound, he takes the form of every boss in the game, always in the same order. After you **wound** him 3 times in one form (a hit that does 0 damage doesn't count), he changes form: the screen shakes, the room becomes that boss's arena, and **his body takes that boss's size, reach and speed**. Anyone standing where something new appears is moved to the nearest free space.
  1. **Warden (3x3):** a torch pair on the side away from him, a gate on his shield. He takes half damage until the pair matches.
  2. **Bishops (2x2):** he splits into four. He and three bishop copies stand in the corners, with gates on the square between them. Only the 1 can be hurt, and the copies share his health. Each wound moves the 1. Their volley lands one beam (Smite or Judgment). Nobody moves. The copies vanish when the form ends, and if a copy takes the last of his health, it was him all along.
  3. **Shade (5x3):** the Shade's circuit and lantern. He can only be hurt in torch light, or anywhere while the lantern burns.
  4. **Ymir (4x4, reach 7):** Ymir's circuit and two power torches. Each lit power torch is an extra strike. With both out he takes +50%.
  5. **Logic Keeper (4x4):** two shadow Wardens link to him, each with its own torch pair. He can't be hurt while either is linked. Match a pair to its Warden's gate to cut that link for 4 rounds. Shadow Wardens move and attack; killing one cuts it for good (no XP or loot).
  6. **Altair (2x2, quick, reach 2):** a bit over his head. A 1 means half damage, a 0 means +50%. It can flip every round.
  7. **Smo (4x4, slow, heavy):** the same bit.
  Then he starts again from the Warden.
- Killing him wins the game.

**What the terminal shows**
- Warden: the gate letter in the middle of his body, or `B` when the shield is broken.
- Shade: `D` in light, `d` in darkness.
- Ymir's power torches: `&` lit, `~` out.
- Logic Keeper: `J` linked (can't be hurt), `j` open.
- Bishops: `P`; the gates on the square are their letters (`A` AND, `X` XOR, `v` NOR).
- Altair and Smo: `T` / `U` carry the 1, `F` / `H` carry the 0, `t` / `u` are empowered.
- Unbound King (`Z`, his size changes with the form): his middle letter is the gate (Warden), `q` (Bishops; his copies are `P`), `D` / `d` (Shade), `f` (Ymir), `W` linked / `w` open (Keeper), or `1` / `0` (Altair and Smo).

The sprites are drawn by the Python scripts in `art/` (shapes plus an automatic outline). `art/all.png` and `art/unbound.png` are previews.

## The name (v12)

The game is now called **Logic In Dungeon** (it was Register Dungeon): the title screen, the window title and the victory text use the new name, and the single-file version is `logicindungeon.asm`.

## The look (v11)

The window uses a Stone & Iron theme: notched stone panels with chiselled edges and iron rivets, bronze title plaques, stone-tablet buttons that press in, square iron key tags, segmented troughs for HP (blood red), mana and XP, and parchment for item tooltips and the plaque's riddle. Only colours and shapes changed; the layout is the same. The palette is at the top of `rd_gui.c` (`C_BG`, `C_CARD`, `C_BRONZE`, ...).

## Balance changes in v10 (after playtesting)

- **Resting:** going through a door heals a third of your max HP.
- **Floors 1-2:** only 2-3 enemies, and floor 1 has no skeletons.
- **The floor 4 Warden:** 30-36 HP and three quarters of his damage. The floor 8 Warden is unchanged.
- **Starting HP:** Fighter 12, Rogue 11, Wizard 9.
- **Rogue:**
  - Starts with a Rapier.
  - **Cunning Action:** in a fight, hiding costs 3 movement instead of your attack, so you can step away, hide, step back and sneak attack in one turn.
  - At the end of the enemy turn, any enemy within 3 cells finds you, so you can't hide every turn to stay untouchable.

The bot playtest (`tools/playbot.py`) plays the real game. With these changes, all three classes reached floor 15 in every run, at level 10-11.

## Levels (1-20)

- **XP sources:**
  - Kills: goblin 10, skeleton 15, orc 20, plus 2 per floor. Bosses are worth 100-500.
  - Solving a room's puzzle: 25 + floor, or 40 + 2 x floor for a circuit.
  - Beating a boss trick: 15 + floor. Tricks are breaking a shield, lighting the lantern, putting out a power torch, breaking the ward, or powering the throne.
- **HP per level:** Fighter 6, Rogue 5, Wizard 4, plus your CON modifier. You heal by the amount you gain.
- **Stat points:** every even level gives one. In the window, click a stat box at the top. In the terminal, press **U** and then 1 STR, 2 DEX, 3 CON or 4 INT. A stat can go up to 24.
- **Modifiers:** every stat counts as **(stat - 10) / 2**, so 16 is +3. Damage, superiority dice, spells, AC and HP all use it.
- **Display:** the terminal shows `Lv:5* XP:310/450` on row 1 (the `*` means a point is waiting). The window shows a level badge and an XP bar.

| Level | Fighter | Rogue | Wizard |
|---|---|---|---|
| 3 | 5 superiority dice | Sneak attack 3d6 | Max mana +2 |
| 5 | 3 attacks a turn | Moving never gets you spotted | Mana regenerates 2x |
| 7 | Dice become d10 | 2 attacks a turn | Cantrips roll an extra die |
| 9 | Heal 1 HP a round | Sneak attack 4d6 | Max mana +2 |
| 10 | Action Surge twice | - | - |
| 11 | First hit each fight halved | First hit each fight halved | Spells +2 damage |
| 13 | 6 superiority dice | A kill hides you again | One free spell per fight |
| 15 | Dice become d12 | Sneak attack 5d6 | Max mana +2 |
| 17 | 4 attacks a turn | Ranged hits and spells halved | Mana regenerates 3x |
| 19 | Heal 2 HP a round | Sneak attack 6d6 | Cantrips: another die |
| 20 | Action Surge 3 times | Sneak attacks pierce shields | Spells +50% damage |

Enemies scale too: normal enemies get +2/3 HP per floor and +1 damage every 5 floors, and the bosses have more HP than in v8.

## Special items (38, all defined in `tools/items.py`)

There are three new gear slots: helmet, boots and a trinket (ring or amulet), on top of weapon, body armor and shield.
- The bag marks rare items with `+` (blue in the window) and legendary items with `#` (gold).
- In the window, hovering an item shows what it does.
- Rare items drop from the floor shown, and only ones your class can use.
- Each boss always drops the legendary made for your class.

### Rare drops

| Item | For | Floor | What it does |
|---|---|---|---|
| Ember Blade | Fighter / Rogue | 3+ | 1-6 damage, STR +1, burns |
| Frostbite | Any class | 3+ | 1-4 damage, DEX +2, slows |
| Venom Rapier | Fighter / Rogue | 6+ | 1-8 damage, DEX +1, poisons |
| Thunder Maul | Fighter | 10+ | 2-12 damage, two-handed, STR +2, can knock down |
| Wand of Embers | Wizard | 5+ | 1-6 damage, reach 2, INT +2, Spells deal +1 damage |
| Shadowweave | Fighter / Rogue | 6+ | AC +2, DEX +2, Moving never gets you spotted while hidden |
| Archmage Robe | Any class | 6+ | AC +1, INT +2, max mana +1 |
| Drakescale Mail | Fighter | 9+ | AC +5, CON +1, Enemies that hit you take 2 damage |
| Spiked Buckler | Fighter | 5+ | AC +1, Enemies that hit you take 2 damage |
| Mirror Shield | Fighter | 12+ | AC +2, Ranged attacks and spells hit you for half |
| Horned Helm | Fighter | 4+ | AC +1, STR +1 |
| Whisper Hood | Fighter / Rogue | 7+ | DEX +1, Sneak attacks roll +1d6 |
| Striding Boots | Any class | 4+ | +2 movement |
| Scholar's Ring | Any class | 2+ | INT +1, +30% experience |
| Lantern Charm | Any class | 12+ | CON +1, You shine: shadows near you can be hurt |
| Gatekey Charm | Any class | 8+ | Flip torches from 2 cells away |
| Amulet of Vigor | Any class | 10+ | CON +2 |

### Boss legendaries

| Boss | Fighter | Rogue | Wizard |
|---|---|---|---|
| Warden (4) | **Gatebreaker**: 1-10 damage, reach 3, two-handed, STR +2, Cuts through gate shields and the 1-bit (no halving) | **Keyknife**: 1-6 damage, DEX +2, Flip torches from 2 cells away | **Staff of Gates**: 1-6 damage, reach 2, INT +2, Flip torches from 2 cells away |
| Warden (8) | **XOR Edge**: 1-10 damage, STR +1, CON +1, can blind | **Twinfang**: 1-8 damage, DEX +2, poisons, One more attack every turn | **Circuit Rod**: 1-6 damage, reach 2, INT +2, Mana comes back twice as fast |
| Dark Shade | **Duskplate**: AC +7, CON +2, You shine: shadows near you can be hurt | **Shade Fang**: 1-6 damage, DEX +2, Heals you for a third of the damage it deals | **Umbral Robe**: AC +1, INT +2, max mana +1, Spells deal +2 damage |
| Ymir | **Frostbrand**: 2-12 damage, two-handed, STR +2, slows | **Icicle Crossbow**: 1-8 damage, range 12, DEX +2, slows | **Rimefrost Staff**: 1-6 damage, reach 2, INT +3, max mana +2, slows, Spells cost 1 less mana |
| Logic Keeper | **Keeper's Aegis**: AC +3, CON +2, The first hit you take in each fight is halved | **Keeper's Cloak**: AC +2, DEX +2, Ranged attacks and spells hit you for half | **Truth Amulet**: INT +2, max mana +1, Hidden ??? gates show what they are |
| Altair | **Stormspear**: 1-10 damage, reach 3, two-handed, STR +1, DEX +2, can knock down | **Stormstep Boots**: DEX +2, +3 movement | **Stormstaff**: 1-6 damage, reach 2, INT +3, Spells deal +2 damage |
| Smo | **Smo's Maul**: 2-14 damage, two-handed, STR +3, can knock down | **Ironheart**: CON +3, Heals 1 HP at the end of every round | **Heartstone**: CON +2, INT +2, Heals 1 HP at the end of every round |

To add or change an item, edit `tools/items.py` and run `python3 tools/items.py`. It rewrites `items_rec.inc`, `items_cat.inc`, `items_loot.inc` and `gui_items.h`.

## How circuits work

- Torches are inputs (lit = 1). Wires carry the value from left to right into gates, and the last
  gate's output wire runs to the door. When that wire carries a 1, the door opens and stays open.
- Stand next to a torch and click it, or walk into it in the terminal, to flip it.
- Gate types are rolled at random each room. The game rerolls until the circuit is solvable and at
  most half of all torch settings open the door. The torches start in a setting that does not open it.
- Terminal symbols:
  - `-` and `:` are unpowered wires; `=` and `|` are powered wires.
  - A gate's border is `%` when its output is 0 and `$` when it is 1.
  - The centre letter is the gate type: `A` AND, `V` OR, `X` XOR, `a` NAND, `v` NOR, `E` XNOR, `N` NOT, `?` hidden.
- In the window, gates are drawn as real gate symbols with a 0/1 badge on each output, and powered wires glow.

## Files

| File | Contents |
|---|---|
| `HOW_TO_RUN.md` | Step-by-step setup: Fedora, Ubuntu/Debian, Arch, Windows (WSL2), troubleshooting |
| `game.asm` | Main loop, input, combat, spells, drawing |
| `game_assets.asm` | Weapons, armor, spells, enemy stats, boss floors |
| `room.inc` | Door, plaque, 2-torch gate puzzles, boss rooms |
| `circuit.inc` | Circuit puzzles: setup, solvability check, evaluation, drawing |
| `progress.inc` | Levels, XP, perks, stat points, what your gear adds |
| `tools/playbot.py` | A bot that plays the real game in a terminal emulator and logs each floor (`CLS=1 MAXFLOOR=14 python3 tools/playbot.py`; needs `pip install pyte`, uses `tools/h.py`) |
| `tools/items.py` | Every special item: makes `items_rec.inc`, `items_cat.inc`, `items_loot.inc`, `gui_items.h` |
| `bosses.inc` | Ymir's spells, the Keeper's ward and second phase, Altair and Smo, the Unbound King's seven forms |
| `circuits.inc` | Circuit layouts. Generated by `python3 tools/gen_circuits.py`, which also checks that no wires touch |
| `enemies.inc` | Enemy types and AI |
| `features.inc` | Inventory, loot, Battle Master, stealth |
| `path.inc` | Pathfinding, and the invisible notes the window reads (previews, casts, attacks, icons) |
| `bosses2.inc` | The Four Bishops, the Logic Keeper's Wardens |
| `rd_gui.c`, `sprites.h` | raylib front end and pixel art. Section 1b loads and plays the audio, section 5 decides what plays |
| `assets/sfx`, `assets/music` | Sound effects and music |
| `tools/audio/sfx_synth.py` | Generates every sound effect from code |
