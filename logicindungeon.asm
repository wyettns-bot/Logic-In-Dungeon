; game.asm  -  SPELL DEMO build
; Explore (real time) / Combat (turn based) modes, random enemies, and a working spell system
; driven by the spell table in game_assets.asm.
;
; Build:  ./build.sh          (or by hand:)
;   nasm -f elf32 CC.asm -o CC.o
;   nasm -f elf32 game.asm -o game.o        (game_assets.asm is %included)
;   ld -m elf_i386 game.o CC.o -o game

;macros
%macro print_string 2
    mov eax, 4
    mov ebx, 1
    mov ecx, %1
    mov edx, %2
    int 0x80
%endmacro

%macro msg 1                    ; say_str on a message label (needs <label> and <label>len)
    mov esi, %1
    mov ecx, %1 %+ len
    call say_str
%endmacro

%macro mtext 1                  ; append a piece of text to the message being built
    mov esi, %1
    mov ecx, %1 %+ len
    call msg_text
%endmacro

;externs
extern character_creation
extern classLabel
extern classLabellen
extern print_clear
extern class
extern print_integer
extern print_newline
extern strength,dex,con, intel

; ===== begin game_assets.asm =====
section .data
	;map assets
	puzzlenode db "[0]"
	puzzlenode_w equ 3
	puzzlenode_h equ 1

	puzzlenodeactive db "[1]"
	puzzlenodeactive_w equ 3
	puzzlenodeactive_h equ 1

	panelasset db "R"
	doorasset db "<","<","<"
	door_w equ 1
	door_h equ 3
	opendoorasset db ">",">",">"
	opendoor_w equ 1
	opendoor_h equ 3

	;player and npc assets
	playerIcon db "@"
	goblinIcon db "G"
	skeletonIcon db "S"
	orcIcon db "O"
	minibossIcon db "MBM","MBM","MBM"
	miniboss_w equ 3
	miniboss_h equ 3
	finalbossIcon db "KKKKK","KKKKK","KKKKK"
	finalboss_w equ 5
	finalboss_h equ 3
	shadeIcon db "DDDDD","DDDDD","DDDDD"   ;the Dark Shade of the Forgotten King
	shade_w equ 5
	shade_h equ 3
	ymirIcon db "YYYY","YYYY","YYYY","YYYY"       ;Grand Wizard Ymir (floor 17)
	keeperIcon db "JJJJ","JJJJ","JJJJ","JJJJ"     ;the Logic Keeper behind its ward (floor 21)
	keeperOpenIcon db "jjjj","jjjj","jjjj","jjjj" ;  ... with the ward broken
	bishopIcon db "PP","PP"                       ;a bishop (floor 12): all four look the same
	altairIcon db "TT","TT"                       ;Altair, the quick one of the pair (floor 26)
	altairRageIcon db "tt","tt"                   ;  ... after taking Smo's power
	smoIcon db "UUUU","UUUU","UUUU","UUUU"        ;Smo, the heavy one of the pair (floor 26)
	smoRageIcon db "uuuu","uuuu","uuuu","uuuu"    ;  ... after taking Altair's power
	big4_w equ 4
	big4_h equ 4
	shadeDarkIcon db "ddddd","ddddd","ddddd"   ;the Shade in darkness (can't be hurt)
	altairZeroIcon db "FF","FF"                   ;Altair carrying the 0 (exposed)
	smoZeroIcon db "HHHH","HHHH","HHHH","HHHH"    ;Smo carrying the 0 (exposed)
	unboundIcon db "ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ"   ;the Forgotten King, Unbound (7x7)
	ucopyIcon db "zzzz","zzzz","zzzz","zzzz"      ;a copy of the Unbound King (drawn from a buffer at its current size)
	unbound_w equ 7
	unbound_h equ 7

	;enemy stats 10 bytes
	ENEMY_HP_MIN equ 0
	ENEMY_HP_MAX equ 1
	ENEMY_DMG_MIN equ 2
	ENEMY_DMG_MAX equ 3
	ENEMY_ATK_BONUS equ 4 ;added to its d20 attack roll against your armor class
	ENEMY_RANGE equ 5 ;1 = melee, more = it attacks from that many cells away
	ENEMY_MOVE equ 6 ;cells it can move in one enemy turn (at most 6)
	ENEMY_W equ 7 ;size on the grid
	ENEMY_H equ 8
	ENEMY_BOSS equ 9 ;(normal|mini boss|final boss) = 0, 1, 2
	ENEMY_SIZE equ 10

	;hp min, hp max, dmg min, dmg max, attack bonus, range, move, width, height, boss
	enemyTable:
	goblin db 5,7, 1,3, 3, 1, 4, 1,1, 0 ;fast and weak
	skeleton db 6,8, 1,4, 2, 6, 3, 1,1, 0 ;shoots from 6 cells away
	orc db 12,16, 2,6, 4, 1, 3, 1,1, 0 ;slow, tough, hits hard
	miniboss db 40,50, 3,8, 5, 1, 5, miniboss_w,miniboss_h, 1
	finalboss db 140,155, 1,4, 5, 60, 0, finalboss_w,finalboss_h, 2 ;the Forgotten King on his throne (floor 30): never moves, reaches everywhere
	shade db 100,115, 3,9, 6, 3, 5, shade_w,shade_h, 2 ;his Dark Shade (floor 15)
	ymir db 110,125, 3,8, 6, 7, 4, big4_w,big4_h, 1 ;casts spells from range 7 (see bosses.inc)
	keeper db 130,145, 3,9, 6, 2, 5, big4_w,big4_h, 1 ;its ward cuts damage to a quarter until you solve the gate
	altair db 70,80, 2,7, 7, 2, 6, 2,2, 1 ;fast, reach 2 (a spear)
	smo db 110,125, 4,11, 5, 1, 4, big4_w,big4_h, 1 ;slow, hits very hard
	unbound db 200,220, 4,10, 7, 1, 5, unbound_w,unbound_h, 2 ;the King after his fake death
	bishop db 30,36, 1,4, 5, 99, 0, 2,2, 1 ;the Four Bishops (floor 12): never move, cast across the whole room
	ucopy db 200,220, 4,10, 7, 99, 0, 2,2, 1 ;a copy of the Unbound King (his Bishops and Altair & Smo forms): size, reach and speed set per form
	ENEMY_TYPES equ ($ - enemyTable) / ENEMY_SIZE
	ETYPE_GOBLIN equ 0
	ETYPE_SKELETON equ 1
	ETYPE_ORC equ 2
	ETYPE_MINIBOSS equ 3
	ETYPE_KING equ 4
	ETYPE_SHADE equ 5
	ETYPE_YMIR equ 6
	ETYPE_KEEPER equ 7
	ETYPE_ALTAIR equ 8
	ETYPE_SMO equ 9
	ETYPE_UNBOUND equ 10
	ETYPE_BISHOP equ 11
	ETYPE_UCOPY equ 12

	;the sprite of each enemy type, same order as the table
	enemySprites dd goblinIcon, skeletonIcon, orcIcon, minibossIcon, finalbossIcon, shadeIcon, ymirIcon, keeperIcon, altairIcon, smoIcon, unboundIcon, bishopIcon, ucopyIcon

	;which normal enemies show up: out of 10, (goblin, skeleton, orc) for floors 1-2, 3-6, 7+
	spawnOdds db 6,3,1, 4,4,2, 2,4,4, 8,0,2     ;(the last three: floor 1, no skeletons)

	;boss floors
	MINIBOSS_FLOORS equ 2
	minibossFloors db 4, 8
	BISHOP_FLOOR equ 12 ;the Four Bishops
	SHADE_FLOOR equ 15 ;the Dark Shade of the Forgotten King
	YMIR_FLOOR equ 17 ;Grand Wizard Ymir
	KEEPER_FLOOR equ 21 ;the Logic Keeper
	DUO_FLOOR equ 26 ;Altair and Smo
	FINAL_FLOOR equ 30 ;the Forgotten King himself

	;potions
	minorPotion db 6, 5		; heals 6 + 5% of your max HP
	regPotion db 12, 10		; heals 12 + 10% of your max HP
	largePotion db 24, 15	; heals 24 + 15% of your max HP

	;effects, one shared list for weapons, armor and spells. one number per item, 0 = none
	EFFECT_NONE      equ 0
	EFFECT_BURN      equ 1
	EFFECT_SLEEP     equ 2
	EFFECT_HOLD      equ 3
	EFFECT_HASTE     equ 4
	EFFECT_TELEPORT  equ 5
	EFFECT_SLOW      equ 6
	EFFECT_POISON    equ 7
	EFFECT_LIFESTEAL equ 8
	EFFECT_BLIND     equ 9
	EFFECT_PRONE     equ 10	;knocked down: loses its next turn
	EFFECT_FRIGHT    equ 11	;frightened: won't attack
	LAST_STATUS      equ 11

	;weapons stats 8 bytes plus spare
	WEAPON_TYPE equ 0
	WEAPON_CLASS equ 1
	WEAPON_MIN_DAMAGE equ 2
	WEAPON_MAX_DAMAGE equ 3
	WEAPON_STAT_SCALING equ 4
	WEAPON_ATTACK_RANGE equ 5
	WEAPON_EFFECT equ 6
	WEAPON_TWO_HANDED equ 7 ;the spare byte: 1 = needs both hands (no shield)

	;weapon type(melee|range),class limit(fighter|rouge|wizard),min damage, max damage, damage scaling stat(STR|DEX|CON|INT),range,effect,spare
	;melee weapons
	greatsword db 0b10,0b100,2,12,0b1000,2,0,1	;two-handed
	longsword db 0b10,0b110,1,8,0b1000,2,0,0
	shortsword db 0b10,0b110,1,6,0b0100,1,0,0
	pike db 0b10,0b100,1,10,0b1000,3,0,1	;two-handed
	rapier db 0b10,0b110,1,8,0b1100,1,0,0
	quarterstaff db 0b10,0b101,1,6,0b1000,2,0,0
	dagger db 0b10,0b111,1,4,0b1100,1,0,0

	;ranged weapons
	longbow db 0b01,0b100,1,8,0b0100,20,0,1	;two-handed
	shortbow db 0b01,0b110,1,6,0b0100,15,0,0
	lightcrossbow db 0b01,0b110,1,8,0b0100,12,0,0
	heavycrossbow db 0b01,0b100,1,10,0b1000,14,0,1	;two-handed

	;armor stats 8 bytes plus spare
	ARMOR_TYPE equ 0 ;(body|shield|helmet|gloves|boots)
	ARMOR_WEIGHT equ 1 ;(Heavy|Medium|Light|Clothes)
	ARMOR_AC equ 2 ; 
	ARMOR_AC_DEX_MAX equ 3
	ARMOR_MV_PENALTY equ 4
	ARMOR_STAT_BONUS equ 5 ;Increases player stat(STR|DEX|CON|INT)
	ARMOR_BONUS_AMOUNT equ 6
	ARMOR_EFFECT equ 7

	;body armor
	breastplate	   db 0b10000, 0b0100,4,2,0,0,0,0,0
	simplerobe     db 0b10000, 0b0001,0,99,0,0,0,0,0
	leatherarmor   db 0b10000, 0b0010,1,99,0,0,0,0,0

	;shield
	buckler	   	db 0b01000, 0b0010,1,99,0,0,0,0,0
	shield	   	db 0b01000, 0b0100,2,99,0,0,0,0,0

	;special items (rare drops and boss legendaries) - made by items.py
; ===== begin items_rec.inc =====
; items_rec.inc - generated by items.py (special weapon and armor records)
it_embersword db 0b10, 0b110, 1, 6, 0b1100, 1, 1, 0
it_frostbite db 0b10, 0b111, 1, 4, 0b1100, 1, 6, 0
it_venomrapier db 0b10, 0b110, 1, 8, 0b1100, 1, 7, 0
it_thundermaul db 0b10, 0b100, 2, 12, 0b1000, 1, 10, 1
it_emberwand db 0b10, 0b001, 1, 6, 0b0001, 2, 0, 0
it_shadowweave db 0b010000, 0b0010, 2, 99, 0, 0, 0, 0, 0
it_archrobe db 0b010000, 0b0001, 1, 99, 0, 0, 0, 0, 0
it_drakemail db 0b010000, 0b0100, 5, 2, 0, 0, 0, 0, 0
it_spikebuckler db 0b001000, 0b0100, 1, 99, 0, 0, 0, 0, 0
it_mirrorshield db 0b001000, 0b0100, 2, 99, 0, 0, 0, 0, 0
it_hornedhelm db 0b000100, 0b1000, 1, 99, 0, 0, 0, 0, 0
it_whisperhood db 0b000100, 0b0010, 0, 99, 0, 0, 0, 0, 0
it_stridingboots db 0b000001, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_scholarring db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_lanterncharm db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_gatekey db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_vigoramulet db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_gatebreaker db 0b10, 0b100, 1, 10, 0b1000, 3, 0, 1
it_keyknife db 0b10, 0b110, 1, 6, 0b0100, 1, 0, 0
it_gatestaff db 0b10, 0b001, 1, 6, 0b0001, 2, 0, 0
it_xoredge db 0b10, 0b110, 1, 10, 0b1100, 1, 9, 0
it_twinfang db 0b10, 0b110, 1, 8, 0b0100, 1, 7, 0
it_circuitrod db 0b10, 0b001, 1, 6, 0b0001, 2, 0, 0
it_duskplate db 0b010000, 0b1000, 7, 0, 2, 0, 0, 0, 0
it_shadefang db 0b10, 0b110, 1, 6, 0b0100, 1, 0, 0
it_umbralrobe db 0b010000, 0b0001, 1, 99, 0, 0, 0, 0, 0
it_frostbrand db 0b10, 0b100, 2, 12, 0b1000, 1, 6, 1
it_iciclebow db 0b01, 0b110, 1, 8, 0b0100, 12, 6, 0
it_rimestaff db 0b10, 0b001, 1, 6, 0b0001, 2, 6, 0
it_aegis db 0b001000, 0b0100, 3, 99, 0, 0, 0, 0, 0
it_keepercloak db 0b010000, 0b0010, 2, 99, 0, 0, 0, 0, 0
it_truthamulet db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_stormspear db 0b10, 0b110, 1, 10, 0b1100, 3, 10, 1
it_stormboots db 0b000001, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_stormstaff db 0b10, 0b001, 1, 6, 0b0001, 2, 0, 0
it_smomaul db 0b10, 0b100, 2, 14, 0b1000, 1, 10, 1
it_ironheart db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
it_heartstone db 0b100000, 0b1111, 0, 99, 0, 0, 0, 0, 0
; ===== end items_rec.inc =====

	;spells stats, 12 bytes each
	SPELL_TYPE equ 0 ;(Attack|Utility)
	SPELL_CLASS equ 1 ;(fighter|rouge|wizard)
	SPELL_MIN_DAMAGE equ 2
	SPELL_MAX_DAMAGE equ 3
	SPELL_STAT_SCALING equ 4 ;effectiveness based on stat (STR|DEX|CON|INT)
	SPELL_RANGE equ 5 ;max range of attack from player to target; for cone and line it is also their length
	SPELL_MANA_COST equ 6 ;Mana cost per use
	SPELL_EFFECT equ 7 ;effect number, see EFFECT_ above
	SPELL_SHAPE equ 8 ;(point|cone|line)
	SPELL_MAX_TARGET equ 9 ;max amount of independent target for spells
	SPELL_TARGETABLES equ 10 ;Enables what can be targeted by spell (Self|Enemy|Empty Space)
	SPELL_AREA equ 11 ;odd width of the square around the target, 1 = just the target

	;note for later, for spells like hold monster that need consentration maybe scale with con? would be wisdom but thats not an ingame stat
	;type, class, min, max, scaling, range, mana, effect, shape, max targets, targetables, area
	spellTable:
	firebolt db 0b10,0b001,1,10,0b0001,15,0,EFFECT_NONE,0b100,1,0b011,1
	fireball db 0b10,0b001,8,48,0b0001,17,5,EFFECT_NONE,0b100,1,0b111,5
	magicmissle db 0b10,0b001,1,4,0b0001,16,3,EFFECT_NONE,0b100,3,0b010,1
	scorchingray db 0b10,0b001,1,6,0b0001,16,3,EFFECT_NONE,0b100,3,0b010,1
	mistystep db 0b01,0b001,0,0,0b0000,20,3,EFFECT_TELEPORT,0b100,1,0b001,1
	sleep db 0b01,0b001,0,0,0b0000,10,3,EFFECT_SLEEP,0b100,1,0b010,1
	holdmonster db 0b01,0b001,0,0,0b0000,8,4,EFFECT_HOLD,0b100,1,0b010,1
	haste db 0b01,0b001,0,0,0b0000,0,4,EFFECT_HASTE,0b100,1,0b100,1
	rayoffrost db 0b10,0b001,2,8,0b0001,15,0,EFFECT_SLOW,0b100,1,0b010,1
	vampirictouch db 0b10,0b001,3,18,0b0001,1,3,EFFECT_LIFESTEAL,0b100,1,0b010,1
	sunbeam db 0b10,0b001,8,48,0b0001,18,6,EFFECT_BLIND,0b001,1,0b011,1
	icestorm db 0b10,0b001,6,40,0b0001,17,5,EFFECT_SLOW,0b100,1,0b011,5
	coneofcold db 0b10,0b001,8,64,0b0001,9,5,EFFECT_NONE,0b010,1,0b011,1
	SPELL_SIZE equ 12
	SPELL_COUNT equ ($ - spellTable) / SPELL_SIZE

	;spell names: one fixed-width slot per spell, in the SAME ORDER as the table above, zero padded
	NAME_LEN equ 16
	%macro fixedname 1
		%strlen _l %1
		db %1
		times NAME_LEN - _l db 0
	%endmacro
	spellNames:
		fixedname "Firebolt"
		fixedname "Fireball"
		fixedname "Magic Missile"
		fixedname "Scorching Ray"
		fixedname "Misty Step"
		fixedname "Sleep"
		fixedname "Hold Monster"
		fixedname "Haste"
		fixedname "Ray of Frost"
		fixedname "Vampiric Touch"
		fixedname "Sunbeam"
		fixedname "Ice Storm"
		fixedname "Cone of Cold"

	;enemy names, same order as the enemy table
	enemyNames:
		fixedname "Goblin"
		fixedname "Skeleton"
		fixedname "Orc"
		fixedname "Warden"
		fixedname "Forgotten King"
		fixedname "Dark Shade"
		fixedname "Wizard Ymir"
		fixedname "Logic Keeper"
		fixedname "Altair"
		fixedname "Smo"
		fixedname "King Unbound"
		fixedname "Bishop"
		fixedname "King Unbound"

	;the class bit for each class number (class '1','2','3' -> Fighter, Rogue, Wizard)

section .bss

section .text; ===== end game_assets.asm =====

section .data
; ---- screen layout (1-based terminal rows/columns) ----
; rows: 2 ====, 3 class/HP/floor, 4 stats, 5 ====, 6 top border, 7..19 playable, 20 bottom border
GRID_COL equ 2
GRID_ROW equ 7
GRID_W   equ 51
GRID_H   equ 13
MENU_COL equ 56          ; spell list (rows 7..19) and enemy panel (rows 2..5) sit right of the grid
PANEL_COL equ 56

; ---- game rules ----
MOVE_MAX    equ 10
MAX_ENEMIES equ 6        ; (the panel lists them in two columns)
TB_COL      equ 46       ; the clickable turn-based button on row 23
TB_LEN      equ 19
START_X     equ 1
START_Y     equ 6
TICK_MS     equ 90
NOTICE      equ 6        ; explore: enemies this close start chasing you
AGGRO       equ 3        ; explore: enemies this close start COMBAT (set to 0 to switch combat off)
ESTEPS      equ 6        ; enemy phase lasts this many ticks (= the most cells anyone moves in a turn)
AREA_MAX    equ 128      ; most cells one spell can cover
STAT_STRIDE equ 12       ; one timer byte per effect number (0..11) for each enemy
MAX_MANA    equ 7        ; the mana pool (Fireball costs 5, Sunbeam 6: one big spell, then recharge)
MANA_REGEN_TICKS equ 6   ; +1 mana every 6 ticks (about 0.5 s while exploring)
ROUND_UNITS equ 12       ; one combat round ages statuses and mana by this many ticks

MODE_EXPLORE equ 0
MODE_COMBAT  equ 1
PHASE_PLAYER equ 0
PHASE_ENEMY  equ 1

mouseOn db 27, "[?1000h", 27, "[?1003h", 27, "[?1006h", 27, "[?25l"
mouseOnLen equ $- mouseOn
mouseOff db 27, "[?25h", 27, "[?1006l", 27, "[?1003l", 27, "[?1000l"
mouseOffLen equ $- mouseOff

basehp db 12, 11, 9     ; Fighter, Rogue, Wizard

; stat variables in the order of the scaling bits: bit0=INT, bit1=CON, bit2=DEX, bit3=STR
statTable dd intel, con, dex, strength

; how long each status lasts, in ticks (index = EFFECT_ number)
statusDur       db 0, 30, 70, 50, 60, 0, 60, 48, 0, 60, 12, 24
; which effects are statuses an ENEMY can carry (haste/teleport/lifesteal are not)
isEnemyStatus   db 0,  1,  1,  1,  0, 0,  1,  1, 0,  1,  1,  1
; the letter shown in the enemy panel for each status
statusLetters   db 0, 'b','z','H', 0, 0,'s','p', 0, 'B','v','f'

keyChars db "123456789abcd"

escOpen db 27, "["
escOpenLen equ $- escOpen
semi    db ";"
hch     db "H"
slash   db "/"
blank2  db "  "
blank4  db "    "
blank8  db "        "
freeTxt db "free  "
hasteTxt db "HASTED  "
eol     db 27, "[K"                 ; erase from the cursor to the end of the line
eollen  equ $- eol

manaLbl db "Mana: "
manaLbllen equ $- manaLbl

hdrEnemy db "ENEMIES"
hdrEnemylen equ $- hdrEnemy
hdrMenu db "SPELLS   [key] mana"
hdrMenulen equ $- hdrMenu
legend1 db "z=sleep H=hold B=blind"
legend1len equ $- legend1
legend2 db "b=burn p=poison s=slow"
legend2len equ $- legend2
legend3 db "v=prone f=fear"
legend3len equ $- legend3
hdrBag db "BAG  * = worn          "
hdrBaglen equ $- hdrBag
msgMiss db "Enemy misses"
msgMisslen equ $- msgMiss
acLbl db "AC: "
acLbllen equ $- acLbl
wpnLbl db "   Weapon: "
wpnLbllen equ $- wpnLbl
fistTxt db "Fists"
diceLbl db "Dice: "
diceLbllen equ $- diceLbl
nextLbl db "  Next: "
nextLbllen equ $- nextLbl
hidTxt db "HIDDEN  "
dash db "-"

modeExplore db "Mode: Exploring"
modeExplorelen equ $- modeExplore
modeYou db "Mode: COMBAT - your turn"
modeYoulen equ $- modeYou
modeEnemy db "Mode: COMBAT - enemy turn"
modeEnemylen equ $- modeEnemy
modeTBYou db "Mode: Turn-based - your turn"
modeTBYoulen equ $- modeTBYou
modeTBEnemy db "Mode: Turn-based - others move"
modeTBEnemylen equ $- modeTBEnemy
tbOff db "[T] Turn-based: OFF"
tbOn  db "[T] Turn-based: ON "
msgTBFight db "You can't leave turn-based mode during a fight"
msgTBFightlen equ $- msgTBFight

msgHit   db "You hit for "
msgHitlen equ $- msgHit
msgHurt  db "Enemy hits you for "
msgHurtlen equ $- msgHurt
msgDead  db "You died!"
msgDeadlen equ $- msgDead
msgClear db "Room cleared!"
msgClearlen equ $- msgClear

msgWiz   db "Only wizards can cast spells (pick class 3)"
msgWizlen equ $- msgWiz
msgNoMana db "Not enough mana"
msgNoManalen equ $- msgNoMana
msgTurn  db "Not your turn"
msgTurnlen equ $- msgTurn
msgAct   db "You already acted this turn (Space to end it)"
msgActlen equ $- msgAct
msgPick  db "Pick a target. Right-click cancels."
msgPicklen equ $- msgPick
msgDart  db ": target "
msgDartlen equ $- msgDart
msgDartNext db " - click the next one (the same enemy again is fine)"
msgDartNextlen equ $- msgDartNext
msgBad   db "Invalid target (out of range, or wrong kind of target)"
msgBadlen equ $- msgBad
msgTele  db "Can't teleport there"
msgTelelen equ $- msgTele
msgSepHit db " - hit "
msgSepHitlen equ $- msgSepHit
msgSepDmg db "  dmg "
msgSepDmglen equ $- msgSepDmg
msgSepDone db " - done"
msgSepDonelen equ $- msgSepDone
winText db 27, "[2J", 27, "[H", 10
        db "=====================================================", 10
        db "          The Forgotten King falls silent.", 10
        db "     The last gate is solved. You have won!", 10
        db "=====================================================", 10, 10
        db "              Play again? (Y/N)", 10
winTextlen equ $- winText
msgNewRun db "A new descent begins. Good luck."
msgNewRunlen equ $- msgNewRun
msgReset db "Arena reset: new enemies, full HP and mana"
msgResetlen equ $- msgReset

linebar: db 10, "=====================================================", 10
linebarlen equ $ - linebar

Hpbar: db "              HP: "
Hpbarlen equ $ - Hpbar

floorCountLabel db "          Floor: "
floorCountLabellen equ $- floorCountLabel

strLabel db "STR: "
strLabellen equ $- strLabel

dexLabel db "        DEX: "
dexLabellen equ $- dexLabel

conLabel db "        CON: "
conLabellen equ $- conLabel

intLabel db "         Int: "
intLabellen equ $- intLabel

basegrid db "#####################################################", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#...................................................#", 10
         db "#####################################################", 10
basegridlen equ $- basegrid

movementLabel db "Movement: "
movementLabellen equ $- movementLabel

HELP_LEN equ 54
helpFighter db "[1-c] Use  [M] Maneuver [P] Parry [L] Rally [G] Surge "
helpRogue   db "[1-c] Use item  [H] Hide                              "
helpWizard  db "[1-d] Cast  [I] Spells / Bag                          "
actionBar2 db "[X] Discard  [Space] End turn  [R] Reset  [Q] Quit"
actionBar2len equ $- actionBar2

section .bss

playerHP    resd 1
playerMaxHP resd 1
playerMana  resd 1
playerMaxMana resd 1
manaTick    resd 1
hasteTimer  resd 1
movementPoint resd 1
floorCount resd 1

termios_orig resb 36
termios_raw resb 36
inbuf resb 256
inLen resd 1
inPtr resd 1
tspec resd 2

playerX resd 1
playerY resd 1
mouseBtn resd 1
mouseX resd 1
mouseY resd 1
mouseEvt resb 1

gameMode resd 1
wonGame resd 1           ; set when the Forgotten King dies
inFight resd 1           ; 1 = enemies are actually fighting you
tbForced resd 1          ; 1 = you switched turn-based mode on yourself
phase resd 1
moving resd 1
attacked resd 1          ; 1 = already used this turn's action (attack or spell)
enemySteps resd 1
tickCount resd 1
lastTick resd 1
seed resd 1

enemyX  resd MAX_ENEMIES
enemyY  resd MAX_ENEMIES
enemyHP resd MAX_ENEMIES
statusTimer resb MAX_ENEMIES*STAT_STRIDE

; ---- spell system ----
armedSpell resd 1        ; index of the spell being aimed, -1 = none
spellPtr   resd 1        ; address of the armed spell's record
selIdx resd 1
selPtr resd 1
hoverKind resd 1         ; what the on-screen preview is: 1 = walking path, 2 = spell area
areaCount resd 1
areaValid resd 1
areaX resd AREA_MAX
areaY resd AREA_MAX
prevCount resd 1
prevX resd AREA_MAX
prevY resd AREA_MAX
dirX resd 1
dirY resd 1
dMax resd 1
dotv resd 1
vx resd 1
vy resd 1
Lv resd 1
shapeK resd 1
half resd 1
dxv resd 1
dyv resd 1
hitCount resd 1
totalDmg resd 1
darts resd 1
dartN resd 1             ; targets chosen so far for a multi-target spell
dartI resd 1
dartX resd 8
dartY resd 8
ai resd 1
pvi resd 1
mi resd 1
pi resd 1
pj resd 1
pk resd 1
ei resd 1
ej resd 1
changed resd 1
slowFlag resd 1
roundK resd 1
menuBuf resb 24
panelBuf resb 24
nameBuf resb 16

tgtX resd 1
tgtY resd 1
newX resd 1
newY resd 1
nX resd 1
nY resd 1
pathX resd 1
pathY resd 1
pathI resd 1
pathMode resd 1
hoverOn resd 1
gotoRow resd 1
gotoCol resd 1
cellChar resb 1
eI resd 1
eIdx resd 1
dmg resd 1
spawnN resd 1
spawnI resd 1
tries resd 1
gX resd 1
gY resd 1
sayNum resd 1
sayPtr resd 1
sayLen resd 1

section .text
global _start

_start:
    call character_creation

    mov dword [floorCount], 1
    movzx ebx, byte [class]          ; 'class' is the ASCII char '1'..'3'
    sub ebx, '1'
    movzx eax, byte [basehp + ebx]
    mov [playerHP], eax
    mov [playerMaxHP], eax
    mov dword [playerMaxMana], MAX_MANA
    mov dword [playerMana], MAX_MANA

    mov dword [gameMode], MODE_EXPLORE
    mov dword [phase], PHASE_PLAYER
    mov dword [moving], 0
    mov dword [hoverOn], 0
    mov dword [hoverKind], 0
    mov dword [armedSpell], -1
    mov dword [hasteTimer], 0
    mov dword [manaTick], 0
    mov dword [movementPoint], MOVE_MAX
    mov dword [playerX], START_X
    mov dword [playerY], START_Y

    call get_ms
    xor eax, [tspec+4]
    mov [seed], eax

    call init_progress              ; level 1, no XP (progress.inc)
    call init_features              ; bag, starting gear, class features (features.inc)
    mov dword [inFight], 0
    mov dword [tbForced], 0
    call setup_room                 ; floor 1: the tutorial room, door open (room.inc)
    call spawn_enemies
    call redraw_all
    call announce_room              ; (only matters when a test build starts on a boss floor)
    call get_ms
    mov [lastTick], eax
    call enter_raw

;-----------------------------------------------------------------
; main loop
;-----------------------------------------------------------------
main_loop:
    cmp dword [wonGame], 0
    je .play
    call victory_screen         ; the Forgotten King is dead
.play:
    mov eax, 3
    xor ebx, ebx
    mov ecx, inbuf
    mov edx, 255
    int 0x80
    cmp eax, 0
    jg .have
    je .tickcheck
    cmp eax, -4
    je .tickcheck
    jmp quit
.have:
    mov [inLen], eax
    mov byte [inbuf+eax], 0
    mov dword [inPtr], inbuf

.next:
    cmp dword [wonGame], 0
    jne main_loop
    mov esi, [inPtr]
    mov eax, esi
    sub eax, inbuf
    cmp eax, [inLen]
    jge .tickcheck
    cmp byte [esi], 27
    je .esc

    movzx eax, byte [esi]       ; plain keypress
    inc dword [inPtr]
    cmp dword [statPick], 0     ; choosing a stat: only 1-4 count, anything else means "later"
    je .keys
    cmp al, '1'
    jb .unpick
    cmp al, '4'
    jbe .keys
.unpick:
    mov dword [statPick], 0
.keys:
    cmp al, 'q'
    je quit
    cmp al, 'Q'
    je quit
    cmp al, ' '
    je .endturn
    cmp al, 'r'
    je .reset
    cmp al, 'R'
    je .reset
    cmp al, 't'
    je .tb
    cmp al, 'T'
    je .tb
    cmp al, 'x'
    je .discard
    cmp al, 'X'
    je .discard
    cmp al, 'i'
    je .bag
    cmp al, 'I'
    je .bag
    cmp al, 'm'
    je .man
    cmp al, 'M'
    je .man
    cmp al, 'g'
    je .surge
    cmp al, 'G'
    je .surge
    cmp al, 'h'
    je .hide
    cmp al, 'H'
    je .hide
    cmp al, 'p'
    je .parry
    cmp al, 'P'
    je .parry
    cmp al, 'l'
    je .rally
    cmp al, 'L'
    je .rally
    cmp al, 'u'
    je .upgrade
    cmp al, 'U'
    je .upgrade
    cmp al, '1'                 ; 1..9 -> slots 0..8 (a spell, or a bag item while the bag is open)
    jb .notdigit
    cmp al, '9'
    ja .notdigit
    sub eax, '1'
    call key_slot
    jmp .next
.notdigit:
    cmp al, 'a'                 ; a..d -> slots 9..12
    jb .next
    cmp al, 'd'
    ja .next
    sub eax, 'a'-9
    call key_slot
    jmp .next
.bag:
    call toggle_bag
    jmp .next
.tb:
    call toggle_tb
    jmp .next
.discard:
    call start_discard
    jmp .next
.man:
    movzx eax, byte [class]
    cmp eax, '1'
    jne .next
    cmp dword [diceLeft], 0
    jg .mok
    msg msgNoDice
    jmp .next
.mok:
    call cycle_maneuver
    call draw_mana
    jmp .next
.surge:
    cmp dword [gameMode], MODE_COMBAT
    jne .next
    call action_surge
    jmp .next
.hide:
    call try_hide
    call draw_mana
    jmp .next
.parry:
    call use_parry
    call draw_mana
    jmp .next
.rally:
    call use_rally
    call draw_mana
    jmp .next
.upgrade:
    call start_stat_pick        ; spend a stat point (progress.inc)
    jmp .next

.endturn:
    call end_turn
    jmp .next
.reset:
    call reset_arena
    jmp .next

.esc:
    cmp word [esi+1], '[<'
    jne .skip
    add esi, 3
    call parse_num
    mov [mouseBtn], eax
    call parse_num
    mov [mouseX], eax
    call parse_num
    mov [mouseY], eax
    mov al, [esi-1]
    mov [mouseEvt], al
    mov [inPtr], esi
    cmp al, 'M'
    jne .next
    mov eax, [mouseBtn]
    cmp eax, 35
    je .hover
    cmp eax, 0
    je .click
    cmp eax, 2
    je .rclick
    jmp .next

.hover:
    call on_hover
    jmp .next
.click:
    call on_click
    jmp .next
.rclick:                        ; right click: drop the spell if one is armed, else stop walking
    cmp dword [armedSpell], -1
    je .stopwalk
    call disarm
    jmp .next
.stopwalk:
    call clear_preview
    mov dword [moving], 0
    jmp .next
.skip:
    inc dword [inPtr]
    jmp .next

.tickcheck:
    call get_ms
    mov ebx, eax
    sub ebx, [lastTick]
    cmp ebx, TICK_MS
    jb main_loop
    mov [lastTick], eax
    call world_tick
    jmp main_loop

victory_screen:                 ; you won: ask whether to play again
    mov dword [wonGame], 0
    call print_clear
    print_string winText, winTextlen
.wait:
    mov eax, 3
    xor ebx, ebx
    mov ecx, inbuf
    mov edx, 255
    int 0x80
    cmp eax, 0
    jle .wait                   ; (read gives up every 0.1 s: just ask again)
    mov al, [inbuf]
    or al, 0x20                 ; lower case
    cmp al, 'y'
    je .again
    cmp al, 'n'
    je quit
    cmp al, 'q'
    je quit
    jmp .wait
.again:
    mov dword [floorCount], 1   ; a fresh run with the same hero
    call reset_arena
    msg msgNewRun
    ret

quit:
    call leave_raw
    mov eax, 26
    mov ebx, 1
    call goto_rc
    call print_newline
    call print_newline
    mov eax, 1
    xor ebx, ebx
    int 0x80

;-----------------------------------------------------------------
; the world clock
;-----------------------------------------------------------------
world_tick:
    inc dword [tickCount]
    call boss_tick              ; boss events: the Logic Keeper's second phase, delayed boss messages
    call progress_tick          ; the level-up line (progress.inc)
    cmp dword [gameMode], MODE_COMBAT
    je .combat
    call player_walk_step       ; EXPLORE: everything moves in real time
    cmp dword [hasteTimer], 0
    je .nohaste
    call player_walk_step       ; hasted: a second step every tick
.nohaste:
    call enemies_explore
    call check_aggro
    call status_unit_tick       ; mana regen, status timers, burn and poison damage
    ret
.combat:
    cmp dword [phase], PHASE_ENEMY
    je .enemy
    call player_walk_step
    ret
.enemy:
    call enemy_phase_tick
    ret

check_aggro:                    ; a awake enemy within AGGRO cells starts combat
    mov dword [eI], 0
.l: mov ecx, [eI]
    cmp ecx, MAX_ENEMIES
    jge .r
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    imul ebx, ecx, STAT_STRIDE
    cmp byte [statusTimer+ebx+EFFECT_SLEEP], 0
    jne .n                      ; sleeping or held enemies don't notice you
    cmp byte [statusTimer+ebx+EFFECT_HOLD], 0
    jne .n
    call dist_to_player
    push eax
    call effective_aggro        ; stealthy rogues can get much closer
    mov ebx, eax
    pop eax
    cmp eax, ebx
    jle start_combat
.n: inc dword [eI]
    jmp .l
.r: ret

reset_movement:                 ; movement points for a new turn (doubled while hasted, less in heavy armor)
    mov eax, MOVE_MAX
    cmp dword [hasteTimer], 0
    je .s
    add eax, MOVE_MAX
.s: sub eax, [moveMalus]
    add eax, [gMove]            ; Striding Boots and friends
    mov [movementPoint], eax
    ret

start_combat:
    call clear_preview
    mov dword [moving], 0
    mov dword [inFight], 1
    mov dword [gameMode], MODE_COMBAT
    mov dword [phase], PHASE_PLAYER
    call reset_movement
    mov dword [attacked], 0
    call begin_player_turn
    call draw_movement
    call draw_mode
    ret

check_combat_end:
    call count_alive
    test eax, eax
    jnz .r
    cmp dword [inFight], 0
    je .rc                      ; no fight was going on
    mov dword [inFight], 0
    mov dword [moving], 0
    call end_of_combat          ; the fighter's dice come back
    cmp dword [tbForced], 0
    jne .stay                   ; you turned turn-based on yourself: stay in it
    mov dword [gameMode], MODE_EXPLORE
.stay:
    call draw_movement
    call draw_mode
    call draw_mana
    msg msgClear
.rc:
    call room_cleared           ; boss rooms: open the door (its message comes last), or win the game
.r: ret

toggle_tb:                      ; T key or the button: switch turn-based mode on/off
    cmp dword [gameMode], MODE_COMBAT
    je .off
    mov dword [tbForced], 1
    call clear_preview
    mov dword [moving], 0
    mov dword [gameMode], MODE_COMBAT
    mov dword [phase], PHASE_PLAYER
    call reset_movement
    mov dword [attacked], 0
    call begin_player_turn
    call draw_movement
    call draw_mode
    ret
.off:
    cmp dword [inFight], 0
    jne .cant                   ; like BG3: you can't drop out of a real fight
    mov dword [tbForced], 0
    call clear_preview
    mov dword [moving], 0
    mov dword [gameMode], MODE_EXPLORE
    mov dword [phase], PHASE_PLAYER
    call draw_movement
    call draw_mode
    ret
.cant:
    msg msgTBFight
    ret

end_turn:
    cmp dword [gameMode], MODE_COMBAT
    jne .r
    cmp dword [phase], PHASE_ENEMY
    je .r
    call disarm
    mov dword [moving], 0
    mov dword [phase], PHASE_ENEMY
    mov dword [enemySteps], ESTEPS
    call draw_mode
.r: ret

reset_arena:                    ; R key: fresh enemies, full HP and mana, back to exploring
    call disarm
    mov eax, [playerMaxHP]
    mov [playerHP], eax
    mov eax, [playerMaxMana]
    mov [playerMana], eax
    mov dword [hasteTimer], 0
    mov dword [moving], 0
    mov dword [hoverOn], 0
    mov dword [gameMode], MODE_EXPLORE
    mov dword [phase], PHASE_PLAYER
    mov dword [playerX], START_X
    mov dword [playerY], START_Y
    call init_features
    mov dword [inFight], 0
    mov dword [tbForced], 0
    call setup_room
    call spawn_enemies
    call redraw_all
    msg msgReset
    call announce_room
    ret

;-----------------------------------------------------------------
; enemies
;-----------------------------------------------------------------
enemies_explore:
    mov dword [eI], 0
.l: mov ecx, [eI]
    cmp ecx, MAX_ENEMIES
    jge .d
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    imul ebx, ecx, STAT_STRIDE
    cmp byte [statusTimer+ebx+EFFECT_SLEEP], 0
    jne .n                      ; asleep: does nothing
    cmp byte [statusTimer+ebx+EFFECT_HOLD], 0
    jne .n                      ; held: does nothing
    cmp byte [statusTimer+ebx+EFFECT_PRONE], 0
    jne .n                      ; knocked down: does nothing
    mov dword [slowFlag], 0
    cmp byte [statusTimer+ebx+EFFECT_SLOW], 0
    je .noslow
    mov dword [slowFlag], 1     ; slowed: acts half as often
.noslow:
    cmp byte [statusTimer+ebx+EFFECT_BLIND], 0
    jne .wander                 ; blind: can't see you, so it only stumbles about
    call dist_to_player
    push eax
    call effective_notice
    mov ebx, eax
    pop eax
    cmp eax, ebx
    jg .wander
    mov eax, 3                  ; chase every 4th tick (every 8th when slowed)
    cmp dword [slowFlag], 0
    je .m1
    mov eax, 7
.m1: test [tickCount], eax
    jnz .n
    call enemy_step_toward_player
    jmp .n
.wander:
    mov eax, 7                  ; wander every 8th tick (every 16th when slowed)
    cmp dword [slowFlag], 0
    je .m2
    mov eax, 15
.m2: test [tickCount], eax
    jnz .n
    call enemy_wander
.n: inc dword [eI]
    jmp .l
.d: ret

enemy_phase_tick:
    cmp dword [inFight], 0
    jne .fight
    call enemies_explore        ; turn-based but nobody is fighting: they wander, and may notice you
    call check_aggro            ; (that would start a real fight and give you the turn)
    cmp dword [phase], PHASE_ENEMY
    jne .r
    dec dword [enemySteps]
    jnz .r
    jmp .endphase
.fight:
    mov dword [eI], 0
.l: mov ecx, [eI]
    cmp ecx, MAX_ENEMIES
    jge .done
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    imul ebx, ecx, STAT_STRIDE
    cmp byte [statusTimer+ebx+EFFECT_SLEEP], 0
    jne .n
    cmp byte [statusTimer+ebx+EFFECT_HOLD], 0
    jne .n
    cmp byte [statusTimer+ebx+EFFECT_PRONE], 0
    jne .n                      ; knocked down: loses its turn
    cmp byte [statusTimer+ebx+EFFECT_SLOW], 0
    je .go
    test dword [tickCount], 1
    jnz .n                      ; slowed: only every other tick
.go:
    call enemy_rec
    movzx eax, byte [esi+ENEMY_MOVE]
.mv:
    mov edx, ESTEPS
    sub edx, [enemySteps]       ; which step of the enemy turn this is (0..3)
    cmp edx, eax
    jge .n                      ; it has used up its movement
    cmp byte [statusTimer+ebx+EFFECT_BLIND], 0
    jne .blind
    cmp byte [statusTimer+ebx+EFFECT_FRIGHT], 0
    jne .blind                  ; frightened: keeps its distance
    cmp dword [hidden], 0
    jne .blind                  ; you're hidden: they search blindly
    call boss_move              ; some bosses go somewhere else (the Shade hunts torches)
    jc .n
    call dist_to_player
    movzx edx, byte [esi+ENEMY_RANGE]
    cmp eax, edx
    jle .n                      ; already in range: archers stay back and shoot
    call enemy_step_toward_player
    jmp .n
.blind:
    call enemy_wander
.n: inc dword [eI]
    jmp .l
.done:
    dec dword [enemySteps]
    jnz .r
    call enemies_attack
    call boss_round             ; end of the enemy turn: boss timers, switches and waves
    call player_round_end       ; regeneration (progress.inc)
.endphase:
    mov dword [roundK], ROUND_UNITS
.age:                           ; one combat round = ROUND_UNITS ticks of status time and mana
    call status_unit_tick
    dec dword [roundK]
    jnz .age
    cmp dword [gameMode], MODE_COMBAT
    jne .r                      ; the burn/poison finished the last enemy
    mov dword [phase], PHASE_PLAYER
    call reset_movement
    mov dword [attacked], 0
    call begin_player_turn
    call draw_movement
    call draw_mode
.r: ret

player_attack:                  ; plain melee hit on enemy [eIdx]
    mov dword [attacked], 1
    mov dword [moving], 0
    mov eax, 4
    call rand_mod
    add eax, 2
    push eax
    mov eax, [strength]
    call stat_mod               ; (STR - 10) / 2
    pop ebx
    add eax, ebx
    cmp eax, 1
    jge .p1
    mov eax, 1
.p1:
    mov ecx, [eIdx]
    call boss_cut               ; boss shields, wards, light and bits (bosses.inc)
    mov [dmg], eax
    sub [enemyHP+ecx*4], eax
    call wake_enemy             ; getting hurt ends Sleep
    mov eax, [dmg]
    mov esi, msgHit
    mov ecx, msgHitlen
    call say_num
    mov ecx, [eIdx]
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    call kill_enemy
    call check_combat_end
    ret
.alive:
    call draw_panel
    ret

enemy_wander:
    mov eax, 3
    call rand_mod
    dec eax
    mov ecx, [eI]
    add eax, [enemyX+ecx*4]
    mov [nX], eax
    mov eax, 3
    call rand_mod
    dec eax
    mov ecx, [eI]
    add eax, [enemyY+ecx*4]
    mov [nY], eax
    jmp enemy_move_to

count_alive:
    xor eax, eax
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .d
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    inc eax
.n: inc ecx
    jmp .l
.d: ret

next_room:
    call rest_at_door           ; catch your breath: a third of your max HP back (progress.inc)
    inc dword [floorCount]
    call setup_room             ; pick this room's logic gate (from floor 2 on)
    mov dword [inFight], 0
    mov dword [playerX], START_X
    mov dword [playerY], START_Y
    mov dword [moving], 0
    mov dword [hoverOn], 0
    mov dword [armedSpell], -1
    mov dword [gameMode], MODE_EXPLORE
    xor eax, eax                ; items left on the floor stay behind in the old room
    mov edi, groundItem
    mov ecx, MAX_GROUND
    cld
    rep stosd
    call end_of_combat
    call spawn_enemies
    cmp dword [tbForced], 0
    je .draw
    mov dword [gameMode], MODE_COMBAT   ; you left turn-based mode on: stay in it
    mov dword [phase], PHASE_PLAYER
    call reset_movement
    call begin_player_turn
.draw:
    call redraw_all
    call announce_room          ; "The Warden guards this room!"
    ret

;-----------------------------------------------------------------
; random numbers and the clock
;-----------------------------------------------------------------
rand_mod:                       ; eax = n  ->  eax = 0..n-1   (clobbers ecx, edx)
    mov ecx, eax
    mov eax, [seed]
    imul eax, eax, 1664525
    add eax, 1013904223
    mov [seed], eax
    shr eax, 16
    xor edx, edx
    div ecx
    mov eax, edx
    ret

get_ms:                         ; -> eax = ms   (clobbers ebx, ecx, edx)
    mov eax, 265
    mov ebx, 1
    mov ecx, tspec
    int 0x80
    mov eax, [tspec]
    imul eax, eax, 1000
    mov ecx, eax
    mov eax, [tspec+4]
    xor edx, edx
    mov ebx, 1000000
    div ebx
    add eax, ecx
    ret

;-----------------------------------------------------------------
; terminal setup / teardown
;-----------------------------------------------------------------
enter_raw:
    mov eax, 54
    xor ebx, ebx
    mov ecx, 0x5401
    mov edx, termios_orig
    int 0x80
    mov esi, termios_orig
    mov edi, termios_raw
    mov ecx, 9
    cld
    rep movsd
    and dword [termios_raw+12], ~(2|8)
    mov byte [termios_raw+22], 1         ; VTIME = 0.1 s
    mov byte [termios_raw+23], 0         ; VMIN  = 0
    mov eax, 54
    xor ebx, ebx
    mov ecx, 0x5402
    mov edx, termios_raw
    int 0x80
    mov eax, 4
    mov ebx, 1
    mov ecx, mouseOn
    mov edx, mouseOnLen
    int 0x80
    ret

leave_raw:
    mov eax, 4
    mov ebx, 1
    mov ecx, mouseOff
    mov edx, mouseOffLen
    int 0x80
    mov eax, 54
    xor ebx, ebx
    mov ecx, 0x5402
    mov edx, termios_orig
    int 0x80
    ret

;-----------------------------------------------------------------
; parsing / coordinates
;-----------------------------------------------------------------
parse_num:
    xor eax, eax
.l: movzx ecx, byte [esi]
    inc esi
    sub ecx, '0'
    cmp ecx, 9
    ja  .done
    imul eax, eax, 10
    add eax, ecx
    jmp .l
.done: ret

screen_to_grid:
    mov eax, [mouseX]
    sub eax, GRID_COL
    mov ebx, [mouseY]
    sub ebx, GRID_ROW
    cmp eax, GRID_W
    jae .out
    cmp ebx, GRID_H
    jae .out
    clc
    ret
.out: stc
    ret

;-----------------------------------------------------------------
; drawing helpers
;-----------------------------------------------------------------
goto_rc:                        ; eax = row, ebx = col
    pushad
    mov [gotoRow], eax
    mov [gotoCol], ebx
    print_string escOpen, escOpenLen
    mov eax, [gotoRow]
    call print_integer
    print_string semi, 1
    mov eax, [gotoCol]
    call print_integer
    print_string hch, 1
    popad
    ret

put_cell:                       ; eax = gx, ebx = gy, dl = character
    pushad
    mov [cellChar], dl
    add eax, GRID_COL
    add ebx, GRID_ROW
    xchg eax, ebx
    call goto_rc
    print_string cellChar, 1
    popad
    ret

cell_glyph:                     ; eax=x, ebx=y -> dl = what belongs on that cell (keeps eax,ebx,ecx)
    push eax
    push ebx
    push ecx
    mov [gX], eax
    mov [gY], ebx
    mov eax, [gX]
    mov ebx, [gY]
    call room_glyph             ; door, plaque, torch, or '.'
    mov eax, [gX]
    cmp eax, [playerX]
    jne .e
    mov eax, [gY]
    cmp eax, [playerY]
    jne .e
    mov dl, '@'
    jmp .d
.e: mov eax, [gX]
    mov ebx, [gY]
    call enemy_at
    cmp eax, -1
    je .g
    mov ecx, eax                ; which cell of its body is this?
    mov eax, [gX]
    sub eax, [enemyX+ecx*4]
    mov ebx, [gY]
    sub ebx, [enemyY+ecx*4]
    call enemy_cell_char
    jmp .d
.g: mov eax, [gX]               ; an item lying on the floor
    mov ebx, [gY]
    call ground_at
    cmp eax, -1
    je .d
    push esi
    mov esi, [groundItem+eax*4]
    call ground_glyph
    pop esi
.d: pop ecx
    pop ebx
    pop eax
    ret

say_num:                        ; esi = text, ecx = length, eax = number   (message line, row 24)
    pushad
    mov [sayNum], eax
    mov [sayPtr], esi
    mov [sayLen], ecx
    mov eax, 24
    mov ebx, 1
    call goto_rc
    print_string [sayPtr], [sayLen]
    mov eax, [sayNum]
    call print_integer
    print_string eol, eollen
    popad
    ret

say_str:                        ; esi = text, ecx = length
    pushad
    mov [sayPtr], esi
    mov [sayLen], ecx
    mov eax, 24
    mov ebx, 1
    call goto_rc
    print_string [sayPtr], [sayLen]
    print_string eol, eollen
    popad
    ret

; --- build a message piece by piece: msg_begin, msg_text / msg_name / msg_num ..., msg_end ---
msg_begin:
    pushad
    mov eax, 24
    mov ebx, 1
    call goto_rc
    popad
    ret
msg_text:                       ; esi = text, ecx = length
    pushad
    mov [sayPtr], esi
    mov [sayLen], ecx
    print_string [sayPtr], [sayLen]
    popad
    ret
msg_num:                        ; eax = number
    pushad
    call print_integer
    popad
    ret
msg_end:
    pushad
    print_string eol, eollen
    popad
    ret

print_name:                     ; esi = name slot (zero terminated, at most NAME_LEN)
    pushad
    xor edx, edx
.l: cmp edx, NAME_LEN
    jge .p
    cmp byte [esi+edx], 0
    je .p
    inc edx
    jmp .l
.p: mov eax, 4
    mov ebx, 1
    mov ecx, esi
    int 0x80
    popad
    ret

name_to_buf:                    ; esi = name slot -> nameBuf (NAME_LEN bytes, zeros become spaces)
    pushad
    xor ecx, ecx
.l: cmp ecx, NAME_LEN
    jge .d
    mov al, [esi+ecx]
    test al, al
    jnz .s
    mov al, ' '
.s: mov [nameBuf+ecx], al
    inc ecx
    jmp .l
.d: popad
    ret

draw_hp:
    pushad
    mov eax, 3
    mov ebx, [classLabellen]
    add ebx, Hpbarlen+1
    call goto_rc
    mov eax, [playerHP]
    call print_integer
    print_string slash, 1
    mov eax, [playerMaxHP]
    call print_integer
    print_string blank4, 4
    popad
    ret

draw_mana:                      ; row 21, col 24: mana (or the fighter's dice), plus HASTED / HIDDEN
    pushad
    call draw_gear_line
    mov eax, 21
    mov ebx, 24
    call goto_rc
    movzx eax, byte [class]
    cmp eax, '1'
    jne .mana
    print_string diceLbl, diceLbllen      ; FIGHTER: "Dice: 3/4  Next: Trip Attack"
    mov eax, [diceLeft]
    call print_integer
    print_string slash, 1
    mov eax, [pkDice]
    call print_integer
    print_string nextLbl, nextLbllen
    mov eax, [pendingMan]
    test eax, eax
    jz .noman
    dec eax
    imul esi, eax, NAME_LEN
    add esi, manNames
    call name_to_buf
    print_string nameBuf, 15
    jmp .d
.noman:
    print_string dash, 1
    print_string blank8, 8
    print_string blank8, 6
    jmp .d
.mana:
    movzx eax, byte [class]
    cmp eax, '2'
    jne .wiz
    print_string blank8, 8      ; the rogue has no mana: only HIDDEN shows
    print_string blank4, 4
    jmp .n
.wiz:
    print_string manaLbl, manaLbllen
    mov eax, [playerMana]
    call print_integer
    print_string slash, 1
    mov eax, [playerMaxMana]
    call print_integer
    print_string blank2, 2
    cmp dword [hasteTimer], 0
    je .n
    print_string hasteTxt, 8
    jmp .d
.n: cmp dword [hidden], 0
    je .n2
    print_string hidTxt, 8
    jmp .d
.n2: print_string blank8, 8
.d: popad
    ret

draw_gear_line:                 ; row 1: "AC: 15   Weapon: Longsword"
    pushad
    mov eax, 1
    mov ebx, 1
    call goto_rc
    print_string acLbl, acLbllen
    mov eax, [playerAC]
    call print_integer
    print_string wpnLbl, wpnLbllen
    mov esi, [equipWeapon]
    test esi, esi
    jz .fist
    call name_to_buf
    print_string nameBuf, NAME_LEN
    jmp .r
.fist:
    print_string fistTxt, 5
    print_string blank8, 8
    print_string blank8, 3
.r: popad
    ret

draw_movement:
    pushad
    mov eax, 21
    mov ebx, 11
    call goto_rc
    cmp dword [gameMode], MODE_COMBAT
    je .c
    print_string freeTxt, 6
    jmp .d
.c: mov eax, [movementPoint]
    call print_integer
    print_string blank4, 4
.d: popad
    ret

draw_mode:
    pushad
    mov eax, 23
    mov ebx, 1
    call goto_rc
    cmp dword [gameMode], MODE_COMBAT
    je .c
    print_string modeExplore, modeExplorelen
    jmp .p
.c: cmp dword [inFight], 0
    je .tb
    cmp dword [phase], PHASE_ENEMY
    je .e
    print_string modeYou, modeYoulen
    jmp .p
.e: print_string modeEnemy, modeEnemylen
    jmp .p
.tb: cmp dword [phase], PHASE_ENEMY
    je .te
    print_string modeTBYou, modeTBYoulen
    jmp .p
.te: print_string modeTBEnemy, modeTBEnemylen
.p: print_string eol, eollen
    mov eax, 23                 ; the button
    mov ebx, TB_COL
    call goto_rc
    cmp dword [gameMode], MODE_COMBAT
    je .on
    print_string tbOff, TB_LEN
    jmp .d
.on: print_string tbOn, TB_LEN
.d: popad
    ret

draw_spell_menu:                ; YOUR class's spells, rows 7..19; '>' marks the armed one
    pushad
    cmp dword [bagOpen], 0
    jne .d                      ; the bag is using the panel
    mov dword [mi], 0
.l: mov eax, [mi]
    cmp eax, [spellListN]
    jge .d
    movzx edx, byte [spellList+eax]
    mov [selIdx], edx           ; (scratch) the real spell number on this row
    mov byte [menuBuf], ' '
    cmp edx, [armedSpell]
    jne .m
    mov byte [menuBuf], '>'
.m: mov byte [menuBuf+1], '['
    mov dl, [keyChars+eax]
    mov [menuBuf+2], dl
    mov byte [menuBuf+3], ']'
    mov byte [menuBuf+4], ' '
    mov eax, [selIdx]
    imul esi, eax, NAME_LEN
    add esi, spellNames
    call name_to_buf
    xor ecx, ecx
.c: mov dl, [nameBuf+ecx]
    mov [menuBuf+5+ecx], dl
    inc ecx
    cmp ecx, 14
    jl .c
    mov byte [menuBuf+19], ' '
    imul ebx, [selIdx], SPELL_SIZE
    push esi
    lea esi, [spellTable+ebx]
    call spell_cost             ; what it costs YOU (gear, the free spell)
    pop esi
    xor edx, edx
    mov ecx, 10
    div ecx
    add dl, '0'
    mov [menuBuf+21], dl
    mov dl, ' '
    test eax, eax
    jz .t
    mov dl, al
    add dl, '0'
.t: mov [menuBuf+20], dl
    mov eax, [mi]
    add eax, GRID_ROW
    mov ebx, MENU_COL
    call goto_rc
    print_string menuBuf, 22
    inc dword [mi]
    jmp .l
.d: popad
    ret

redraw_all:
    call print_clear
    print_string linebar,linebarlen
    mov eax, 4
    mov ebx, 1
    mov ecx, [classLabel]
    mov edx, [classLabellen]
    int 0x80
    print_string Hpbar,Hpbarlen
    mov eax, [playerHP]
    call print_integer
    print_string slash, 1
    mov eax, [playerMaxHP]
    call print_integer
    print_string floorCountLabel,floorCountLabellen
    mov eax, [floorCount]
    call print_integer
    call print_newline
    print_string strLabel,strLabellen
    mov eax,[strength]
    call print_integer
    print_string dexLabel,dexLabellen
    mov eax,[dex]
    call print_integer
    print_string conLabel,conLabellen
    mov eax,[con]
    call print_integer
    print_string intLabel,intLabellen
    mov eax,[intel]
    call print_integer
    print_string linebar,linebarlen
    print_string basegrid,basegridlen
    print_string movementLabel,movementLabellen
    call draw_movement
    call draw_mana
    mov eax, 22
    mov ebx, 1
    call goto_rc
    movzx eax, byte [class]     ; the keys YOUR class has
    sub eax, '1'
    imul eax, eax, HELP_LEN
    add eax, helpFighter
    mov [sayPtr], eax
    print_string [sayPtr], HELP_LEN
    mov eax, 25
    mov ebx, 1
    call goto_rc
    print_string actionBar2,actionBar2len
    call draw_mode
    mov eax, 1
    mov ebx, PANEL_COL
    call goto_rc
    print_string hdrEnemy,hdrEnemylen
    mov eax, 20
    mov ebx, MENU_COL
    call goto_rc
    print_string legend1,legend1len
    mov eax, 21
    mov ebx, MENU_COL
    call goto_rc
    print_string legend2,legend2len
    mov eax, 22
    mov ebx, MENU_COL
    call goto_rc
    print_string legend3,legend3len
    call draw_panel
    call draw_panel_header
    call draw_spell_menu
    cmp dword [bagOpen], 0
    je .nobag
    call draw_inventory
.nobag:
    call draw_room_objects      ; door, plaque, torches
    call draw_enemies
    mov eax, [playerX]
    mov ebx, [playerY]
    mov dl, '@'
    call put_cell
    call draw_level             ; "Lv:5 XP:310/450" (progress.inc)
    ret

;-----------------------------------------------------------------
; walking-path logic (unchanged idea: diagonal first, then straight)
;-----------------------------------------------------------------
step_toward:                    ; eax = current, ebx = target -> eax one step closer
    cmp eax, ebx
    je .d
    jl .up
    dec eax
    ret
.up: inc eax
.d: ret

calc_dist:                      ; steps from the player to [tgtX],[tgtY] -> eax
    mov eax, [tgtX]
    sub eax, [playerX]
    jns .a
    neg eax
.a: mov ebx, [tgtY]
    sub ebx, [playerY]
    jns .b
    neg ebx
.b: cmp eax, ebx
    jge .c
    mov eax, ebx
.c: ret

draw_path:
    jmp path_preview            ; path.inc: goes round obstacles, never paints over torches or doors
draw_path_old:
    mov eax, [playerX]
    mov [pathX], eax
    mov eax, [playerY]
    mov [pathY], eax
    mov dword [pathI], 0
.next:
    mov eax, [pathX]
    cmp eax, [tgtX]
    jne .step
    mov eax, [pathY]
    cmp eax, [tgtY]
    je .done
.step:
    mov eax, [pathX]
    mov ebx, [tgtX]
    call step_toward
    mov [pathX], eax
    mov eax, [pathY]
    mov ebx, [tgtY]
    call step_toward
    mov [pathY], eax
    inc dword [pathI]
    cmp dword [pathMode], 0
    jne .draw
    mov eax, [pathX]
    mov ebx, [pathY]
    call cell_glyph
    jmp .put
.draw:
    mov eax, [pathX]
    mov ebx, [pathY]
    call enemy_at
    cmp eax, -1
    jne .next
    mov dl, '*'
    cmp dword [gameMode], MODE_COMBAT
    jne .put
    mov eax, [pathI]
    cmp eax, [movementPoint]
    jle .put
    mov dl, 'x'
.put:
    mov eax, [pathX]
    mov ebx, [pathY]
    call put_cell
    jmp .next
.done:
    ret

;-----------------------------------------------------------------
; SPELLS: arming, aiming (preview), casting
;-----------------------------------------------------------------
select_spell:                   ; eax = menu row -> the spell on that row of YOUR class's list
    cmp eax, [spellListN]
    jae .r
    movzx eax, byte [spellList+eax]
    cmp eax, [armedSpell]
    jne .try
    call disarm                 ; pressing the armed spell's key again cancels it
    ret
.try:
    mov [selIdx], eax
    imul ebx, eax, SPELL_SIZE
    add ebx, spellTable
    mov [selPtr], ebx
    movzx ecx, byte [class]     ; can this class cast it? (class '1'..'3' -> bit table)
    sub ecx, '1'
    cmp ecx, 2
    ja .wrong
    movzx edx, byte [classBit+ecx]
    mov esi, ebx
    movzx eax, byte [esi+SPELL_CLASS]
    test eax, edx
    jz .wrong
    call spell_cost
    cmp eax, [playerMana]
    jg .nomana
    cmp dword [gameMode], MODE_COMBAT
    jne .arm
    cmp dword [phase], PHASE_ENEMY
    je .notturn
    cmp dword [attacksLeft], 0
    jle .noaction
.arm:
    call clear_preview
    mov dword [dartN], 0        ; a newly armed spell starts with no targets picked
    mov dword [moving], 0
    mov eax, [selIdx]
    mov [armedSpell], eax
    mov eax, [selPtr]
    mov [spellPtr], eax
    call draw_spell_menu
    mov esi, [spellPtr]
    cmp byte [esi+SPELL_TARGETABLES], 0b100
    jne .pick
    mov eax, [playerX]          ; self-only spells (Haste) go off immediately
    mov [tgtX], eax
    mov eax, [playerY]
    mov [tgtY], eax
    call cast_spell
    ret
.pick:
    msg msgPick
.r: ret
.wrong:
    msg msgWiz
    ret
.nomana:
    msg msgNoMana
    ret
.notturn:
    msg msgTurn
    ret
.noaction:
    msg msgAct
    ret

disarm:
    mov dword [dartN], 0        ; forget half-chosen targets
    call clear_preview
    cmp dword [armedSpell], -1
    je .r
    mov dword [armedSpell], -1
    call draw_spell_menu
.r: ret

target_ok:                      ; is the cell at [tgtX],[tgtY] a legal target for the armed spell? -> eax 1/0
    mov esi, [spellPtr]
    mov eax, [tgtX]
    mov ebx, [tgtY]
    cmp eax, [playerX]
    jne .notself
    cmp ebx, [playerY]
    jne .notself
    mov ecx, 0b100              ; Self
    jmp .test
.notself:
    call enemy_at
    cmp eax, -1
    je .empty
    mov ecx, 0b010              ; Enemy
    jmp .test
.empty:
    mov ecx, 0b001              ; Empty space
.test:
    movzx eax, byte [esi+SPELL_TARGETABLES]
    test eax, ecx
    jz .no
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

add_area_cell:                  ; eax = x, ebx = y: remember the cell if it is inside the room (clobbers ecx)
    cmp eax, GRID_W
    jae .r
    cmp ebx, GRID_H
    jae .r
    mov ecx, [areaCount]
    cmp ecx, AREA_MAX
    jge .r
    mov [areaX+ecx*4], eax
    mov [areaY+ecx*4], ebx
    inc dword [areaCount]
.r: ret

compute_area:                   ; fills areaX/areaY/areaCount and areaValid for the armed spell aimed at [tgtX],[tgtY]
    mov dword [areaCount], 0
    mov dword [areaValid], 0
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_SHAPE]
    cmp eax, 0b100
    je .point
    cmp eax, 0b010
    mov dword [shapeK], 1       ; cone
    je .dir
    mov dword [shapeK], 2       ; line
    jmp .dir

.point:                         ; a square of SPELL_AREA x SPELL_AREA cells around the target
    call calc_dist
    mov esi, [spellPtr]
    movzx ecx, byte [esi+SPELL_RANGE]
    cmp eax, ecx
    jg .pcells                  ; out of range: still show the area, but as invalid
    call target_ok
    mov [areaValid], eax
.pcells:
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_AREA]
    shr eax, 1                  ; width 5 -> 2 cells each side of the middle
    mov [half], eax
    neg eax
    mov [dyv], eax
.prow:
    mov eax, [half]
    neg eax
    mov [dxv], eax
.pcol:
    mov eax, [tgtX]
    add eax, [dxv]
    mov ebx, [tgtY]
    add ebx, [dyv]
    call add_area_cell
    inc dword [dxv]
    mov eax, [dxv]
    cmp eax, [half]
    jle .pcol
    inc dword [dyv]
    mov eax, [dyv]
    cmp eax, [half]
    jle .prow
    ret

.dir:                           ; cone / line: they start at the player and point toward the target cell
    mov eax, [tgtX]
    sub eax, [playerX]
    mov [dirX], eax
    mov eax, [tgtY]
    sub eax, [playerY]
    mov [dirY], eax
    mov eax, [dirX]
    or eax, [dirY]
    jz .dret                    ; no direction (clicked on yourself)
    call target_ok
    mov [areaValid], eax
    mov eax, [dirX]               ; dMax = the bigger of |dirX| and |dirY|
    test eax, eax
    jns .a1
    neg eax
.a1: mov ebx, [dirY]
    test ebx, ebx
    jns .a2
    neg ebx
.a2: cmp eax, ebx
    jge .a3
    mov eax, ebx
.a3: mov [dMax], eax
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_RANGE]   ; for cone and line the range is their length
    mov [Lv], eax
    neg eax
    mov [vy], eax
.vyl:
    mov eax, [Lv]
    neg eax
    mov [vx], eax
.vxl:
    mov eax, [vx]               ; v = (vx,vy) is a cell relative to the player
    or eax, [vy]
    jz .vnext
    mov eax, [vx]               ; dot = v . d   must be positive (cell is in front of us)
    imul eax, [dirX]
    mov ebx, [vy]
    imul ebx, [dirY]
    add eax, ebx
    jle .vnext
    mov [dotv], eax
    mov eax, [vx]               ; cross = vx*dirY - vy*dirX  (how far off the aim line the cell is)
    imul eax, [dirY]
    mov ebx, [vy]
    imul ebx, [dirX]
    sub eax, ebx
    test eax, eax
    jns .c1
    neg eax
.c1: add eax, eax               ; 2*|cross|
    cmp dword [shapeK], 1
    jne .lcmp
    cmp eax, [dotv]             ; cone:  2*|cross| <= dot   (the cone is as wide as it is long)
    jg .vnext
    jmp .vok
.lcmp:
    cmp eax, [dMax]             ; line:  stays within half a cell of the aim line
    jg .vnext
.vok:
    mov eax, [playerX]
    add eax, [vx]
    mov ebx, [playerY]
    add ebx, [vy]
    call add_area_cell
.vnext:
    inc dword [vx]
    mov eax, [vx]
    cmp eax, [Lv]
    jle .vxl
    inc dword [vy]
    mov eax, [vy]
    cmp eax, [Lv]
    jle .vyl
.dret:
    ret

draw_spell_preview:             ; '+' = this would work, 'x' = invalid target / out of range
    call compute_area
    mov dword [prevCount], 0
    mov dword [pvi], 0
.l: mov eax, [pvi]
    cmp eax, [areaCount]
    jge .d
    mov ebx, [areaY+eax*4]
    mov eax, [areaX+eax*4]
    call cell_glyph
    cmp dl, '.'
    jne .skip                   ; only paint empty floor
.paint:
    mov ecx, [prevCount]
    mov [prevX+ecx*4], eax
    mov [prevY+ecx*4], ebx
    inc dword [prevCount]
    mov dl, '+'
    cmp dword [areaValid], 0
    jne .put
    mov dl, 'x'
.put:
    call put_cell
.skip:
    inc dword [pvi]
    jmp .l
.d: call area_note              ; the whole area for the window, enemies' squares included
    ret

clear_preview:                  ; take whatever preview is on screen (path or spell) off again
    cmp dword [hoverOn], 0
    je .r
    cmp dword [hoverKind], 2
    je .spell
    mov dword [pathMode], 0
    call draw_path
    jmp .off
.spell:
    mov dword [pvi], 0
.l: mov eax, [pvi]
    cmp eax, [prevCount]
    jge .z
    mov ebx, [prevY+eax*4]
    mov eax, [prevX+eax*4]
    call cell_glyph
    call put_cell
    inc dword [pvi]
    jmp .l
.z: mov dword [prevCount], 0
    call osc_begin              ; tell the window the area is gone
    mov al, 'C'
    call osc_char
    call osc_send
.off:
    mov dword [hoverOn], 0
.r: ret

get_scaling_stat:               ; esi = spell record -> eax = the best of the stats the spell scales with
    movzx edx, byte [esi+SPELL_STAT_SCALING]   ; (clobbers ebx, ecx, edx)
    xor eax, eax
    xor ecx, ecx
.l: cmp ecx, 4
    jge .d
    bt edx, ecx
    jnc .n
    mov ebx, [statTable+ecx*4]
    mov ebx, [ebx]
    cmp ebx, eax
    jbe .n
    mov eax, ebx
.n: inc ecx
    jmp .l
.d: ret

apply_status:                   ; eax = EFFECT_ number -> start that status on enemy [eIdx] (if it is one)
    cmp eax, LAST_STATUS
    ja .r
    cmp byte [isEnemyStatus+eax], 0
    je .r
    push esi
    mov ecx, [eIdx]
    call enemy_rec
    cmp byte [esi+ENEMY_BOSS], 0
    pop esi
    je .ok
    cmp eax, EFFECT_SLEEP       ; bosses can't be put to sleep, held or knocked down
    je .r
    cmp eax, EFFECT_HOLD
    je .r
    cmp eax, EFFECT_PRONE
    je .r
    cmp eax, EFFECT_BLIND       ; ... nor blinded or frightened: nothing makes a boss useless
    je .r
    cmp eax, EFFECT_FRIGHT
    je .r
.ok:
    movzx edx, byte [statusDur+eax]
    imul ecx, [eIdx], STAT_STRIDE
    mov [statusTimer+ecx+eax], dl
.r: ret

hit_enemy:                      ; the armed spell lands on enemy [eIdx]
    mov esi, [spellPtr]
    inc dword [hitCount]
    movzx eax, byte [esi+SPELL_MAX_DAMAGE]
    test eax, eax
    jz .status                  ; utility spells deal no damage
    movzx ebx, byte [esi+SPELL_MIN_DAMAGE]
    sub eax, ebx
    inc eax
    call rand_mod               ; 0 .. (max-min)
    add eax, ebx                ; min .. max
    mov [dmg], eax
    call get_scaling_stat       ; + the modifier of the best flagged stat
    call stat_mod
    add [dmg], eax
    mov esi, [spellPtr]
    mov eax, [dmg]
    call spell_bonus            ; extra cantrip dice, gear and level bonuses (progress.inc)
    cmp eax, 1
    jge .sb
    mov eax, 1
.sb:
    mov [dmg], eax
    mov eax, [dmg]
    mov ecx, [eIdx]
    call boss_cut               ; boss shields, wards, light and bits (bosses.inc)
    mov [dmg], eax
    add [totalDmg], eax
    sub [enemyHP+ecx*4], eax
    call wake_enemy             ; getting hurt ends Sleep
    cmp byte [esi+SPELL_EFFECT], EFFECT_LIFESTEAL
    jne .status
    mov eax, [dmg]              ; lifesteal: heal for half the damage dealt
    inc eax
    shr eax, 1
    add eax, [playerHP]
    cmp eax, [playerMaxHP]
    jle .heal
    mov eax, [playerMaxHP]
.heal:
    mov [playerHP], eax
    call draw_hp
.status:
    movzx eax, byte [esi+SPELL_EFFECT]
    call apply_status
    mov ecx, [eIdx]
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    call kill_enemy
    ret
.alive:
    call redraw_enemy
    ret

report_cast:                    ; "Fireball - hit 3  dmg 41"
    pushad
    call msg_begin
    mov eax, [armedSpell]
    imul esi, eax, NAME_LEN
    add esi, spellNames
    call print_name
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_EFFECT]
    cmp dword [hitCount], 0
    jne .hit
    cmp eax, EFFECT_TELEPORT
    je .done
    cmp eax, EFFECT_HASTE
    je .done
.hit:
    mtext msgSepHit
    mov eax, [hitCount]
    call msg_num
    cmp dword [totalDmg], 0
    je .e
    mtext msgSepDmg
    mov eax, [totalDmg]
    call msg_num
    jmp .e
.done:
    mtext msgSepDone
.e: call msg_end
    popad
    ret

pick_dart:                      ; a multi-target spell: remember [tgtX],[tgtY] for the next dart, cast when all are chosen
    call compute_area
    cmp dword [areaValid], 0
    jne .ok
    msg msgBad
    ret
.ok:
    mov ecx, [dartN]
    mov eax, [tgtX]
    mov [dartX+ecx*4], eax
    mov eax, [tgtY]
    mov [dartY+ecx*4], eax
    inc dword [dartN]
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_MAX_TARGET]
    cmp [dartN], eax
    jge cast_spell              ; every dart has a target: fire
    call msg_begin              ; "Magic Missile: target 1/3 - click the next one ..."
    mov eax, [armedSpell]
    imul esi, eax, NAME_LEN
    add esi, spellNames
    call print_name
    mov esi, msgDart
    mov ecx, msgDartlen
    call msg_text
    mov eax, [dartN]
    call msg_num
    mov esi, slash
    mov ecx, 1
    call msg_text
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_MAX_TARGET]
    call msg_num
    mov esi, msgDartNext
    mov ecx, msgDartNextlen
    call msg_text
    call msg_end
    ret

cast_spell:                     ; cast the armed spell at [tgtX],[tgtY]
    call compute_area
    cmp dword [areaValid], 0
    jne .valid
    msg msgBad
    ret
.valid:
    mov esi, [spellPtr]
    cmp byte [esi+SPELL_EFFECT], EFFECT_TELEPORT
    jne .spend
    mov eax, [tgtX]
    mov ebx, [tgtY]
    call obstacle_at
    jnc .spend
    msg msgTele
    ret
.spend:
    mov esi, [spellPtr]
    call spell_cost
    cmp eax, 0
    jne .paid
    cmp byte [esi+SPELL_MANA_COST], 0
    je .paid
    mov dword [freeSpellUsed], 1    ; that was the wizard's free spell of the fight
    push eax
    msg msgFree
    pop eax
.paid:
    sub [playerMana], eax
    call draw_mana
    cmp dword [gameMode], MODE_COMBAT
    jne .cast
    mov dword [attacked], 1     ; a spell is this turn's action
    mov dword [attacksLeft], 0
.cast:
    call cast_note              ; the window animates it (path.inc)
    mov dword [hitCount], 0
    mov dword [totalDmg], 0
    mov esi, [spellPtr]
    movzx eax, byte [esi+SPELL_MAX_TARGET]   ; magic missile / scorching ray fire several darts
    test eax, eax
    jnz .dset
    mov eax, 1
.dset:
    mov [darts], eax
    mov dword [dartI], 0
.dart:
    cmp dword [dartN], 0
    je .sameArea                ; one target for every dart
    mov ecx, [dartI]            ; multi-target: this dart goes where you clicked for it
    mov eax, [dartX+ecx*4]
    mov [tgtX], eax
    mov eax, [dartY+ecx*4]
    mov [tgtY], eax
    call compute_area
    inc dword [dartI]
.sameArea:
    mov dword [ai], 0
    mov dword [hitMask], 0
.cell:
    mov eax, [ai]
    cmp eax, [areaCount]
    jge .dartend
    mov ebx, [areaY+eax*4]
    mov eax, [areaX+eax*4]
    call enemy_at
    cmp eax, -1
    je .nextcell
    bt dword [hitMask], eax
    jc .nextcell                ; already hit by this dart (a big enemy fills several cells)
    bts dword [hitMask], eax
    mov [eIdx], eax
    call hit_enemy
.nextcell:
    inc dword [ai]
    jmp .cell
.dartend:
    dec dword [darts]
    jnz .dart
    mov esi, [spellPtr]         ; effects that act on the caster
    movzx eax, byte [esi+SPELL_EFFECT]
    cmp eax, EFFECT_TELEPORT
    je .tele
    cmp eax, EFFECT_HASTE
    je .haste
    jmp .after
.tele:
    mov eax, [playerX]
    mov ebx, [playerY]
    mov dl, '.'
    call put_cell
    mov eax, [tgtX]
    mov [playerX], eax
    mov eax, [tgtY]
    mov [playerY], eax
    mov eax, [playerX]
    mov ebx, [playerY]
    mov dl, '@'
    call put_cell
    mov dword [moving], 0
    jmp .after
.haste:
    movzx eax, byte [statusDur+EFFECT_HASTE]
    mov [hasteTimer], eax
    cmp dword [gameMode], MODE_COMBAT
    jne .hd
    add dword [movementPoint], MOVE_MAX     ; hasted in combat: a second helping of movement
    call draw_movement
.hd:
    call draw_mana
.after:
    mov dword [dartN], 0
    call report_cast
    call disarm
    cmp dword [gameMode], MODE_EXPLORE
    jne .cend
    cmp dword [hitCount], 0     ; hurting something while exploring starts combat
    je .done
    call count_alive
    test eax, eax
    jz .done
    call start_combat
    mov dword [attacked], 1
    mov dword [attacksLeft], 0
    jmp .done
.cend:
    cmp dword [hitCount], 0
    je .cend2
    mov dword [inFight], 1      ; turn-based and you hurt something: now it's a fight
    call draw_mode
.cend2:
    call check_combat_end
.done:
    call draw_panel
    ret

;-----------------------------------------------------------------
; time passing: mana, haste, enemy statuses, burn and poison
;-----------------------------------------------------------------
status_unit_tick:               ; one unit of time (one explore tick; a combat round is ROUND_UNITS of these)
    pushad
    inc dword [manaTick]
    mov eax, [pkManaPeriod]     ; 12 ticks (1 a combat round), 6 at wizard level 5, 4 at 17; halved by a mana-regen item
    cmp dword [gameMode], MODE_EXPLORE
    jne .mpc
    imul eax, 3                 ; exploring: half as fast again (about 1 every 1.5 s)
    shr eax, 1
.mpc:
    push eax
    mov eax, SP_MANAREGEN
    call has_special
    pop eax
    jnc .mp
    shr eax, 1
.mp:
    cmp eax, 1
    jge .mp2
    mov eax, 1
.mp2:
    cmp [manaTick], eax
    jl .haste
    mov dword [manaTick], 0
    mov eax, [playerMana]
    cmp eax, [playerMaxMana]
    jge .haste
    inc dword [playerMana]
    call draw_mana
.haste:
    cmp dword [hasteTimer], 0
    je .enemies
    dec dword [hasteTimer]
    jnz .enemies
    call draw_mana              ; haste just ran out
.enemies:
    mov dword [ei], 0
.eloop:
    mov ecx, [ei]
    cmp ecx, MAX_ENEMIES
    jge .done
    cmp dword [enemyHP+ecx*4], 0
    jle .enext
    mov dword [changed], 0
    mov dword [ej], 1
.sloop:
    mov ecx, [ei]
    imul ebx, ecx, STAT_STRIDE
    add ebx, [ej]
    movzx eax, byte [statusTimer+ebx]
    test eax, eax
    jz .snext
    dec eax
    mov [statusTimer+ebx], al
    test eax, eax
    jnz .still
    mov dword [changed], 1      ; a status just ran out
.still:
    cmp dword [ej], EFFECT_BURN
    mov ebx, 6                  ; burn hurts every 6 ticks
    je .dot
    cmp dword [ej], EFFECT_POISON
    mov ebx, 9                  ; poison every 9 ticks
    jne .snext
.dot:
    xor edx, edx
    div ebx                     ; eax = remaining time, edx = eax mod period
    test edx, edx
    jnz .snext
    mov ecx, [ei]
    dec dword [enemyHP+ecx*4]
    call wake_enemy             ; getting hurt ends Sleep
    mov dword [changed], 1
    cmp dword [enemyHP+ecx*4], 0
    jg .snext
    mov [eIdx], ecx
    call kill_enemy
    jmp .enext
.snext:
    inc dword [ej]
    cmp dword [ej], LAST_STATUS
    jle .sloop
    cmp dword [changed], 0
    je .enext
    mov ecx, [ei]
    mov [eIdx], ecx
    call redraw_enemy
.enext:
    inc dword [ei]
    jmp .eloop
.done:
    cmp dword [gameMode], MODE_COMBAT
    jne .ret
    call check_combat_end
.ret:
    popad
    ret

;-----------------------------------------------------------------
; player: input handlers and walking
;-----------------------------------------------------------------
on_hover:
    cmp dword [moving], 0
    jne .outside
    cmp dword [gameMode], MODE_COMBAT
    jne .ok
    cmp dword [phase], PHASE_ENEMY
    je .outside
.ok:
    call screen_to_grid
    jc .outside
    mov [newX], eax
    mov [newY], ebx
    cmp dword [armedSpell], -1
    jne .spell
    cmp dword [hoverOn], 0
    je .draw
    cmp eax, [tgtX]
    jne .redraw
    cmp ebx, [tgtY]
    je .ret
.redraw:
    call clear_preview
.draw:
    mov eax, [newX]
    mov [tgtX], eax
    mov eax, [newY]
    mov [tgtY], eax
    mov dword [pathMode], 1
    mov dword [hoverKind], 1
    call draw_path
    mov dword [hoverOn], 1
    ret
.spell:                         ; a spell is armed: show its area instead of the walking path
    cmp dword [hoverOn], 0
    je .sdraw
    cmp eax, [tgtX]
    jne .sredraw
    cmp ebx, [tgtY]
    je .ret
.sredraw:
    call clear_preview
.sdraw:
    mov eax, [newX]
    mov [tgtX], eax
    mov eax, [newY]
    mov [tgtY], eax
    mov dword [hoverKind], 2
    call draw_spell_preview
    mov dword [hoverOn], 1
    ret
.outside:
    call clear_preview
.ret:
    ret

on_click:
    cmp dword [mouseY], 23      ; the turn-based button
    jne .grid
    mov eax, [mouseX]
    cmp eax, TB_COL
    jl .grid
    cmp eax, TB_COL + TB_LEN
    jge .grid
    call toggle_tb
    ret
.grid:
    call screen_to_grid
    jc .r
    mov [newX], eax
    mov [newY], ebx
    call clear_preview
    cmp dword [armedSpell], -1
    je .nospell
    mov esi, [spellPtr]
    cmp byte [esi+SPELL_MAX_TARGET], 1
    jbe .single
    mov eax, [newX]             ; a multi-target spell: this click picks one dart's target
    mov [tgtX], eax
    mov eax, [newY]
    mov [tgtY], eax
    call pick_dart
    ret
.single:
    mov eax, [newX]             ; a spell is armed: the click is the cast
    mov [tgtX], eax
    mov eax, [newY]
    mov [tgtY], eax
    call cast_spell
    ret
.nospell:
    mov eax, [newX]
    mov ebx, [newY]
    call is_plaque
    jnc .notplaque
    call read_plaque            ; reading it is free, from anywhere
    ret
.notplaque:
    call node_at
    cmp eax, -1
    je .notnode
    cmp dword [gameMode], MODE_COMBAT
    jne .touch
    cmp dword [phase], PHASE_ENEMY
    je .r
.touch:
    call touch_node
    cmp dword [touched], 0
    jne .r
    msg msgReach                ; too far: walk toward it
    jmp .move
.notnode:
    cmp dword [gameMode], MODE_COMBAT
    jne .explore
    cmp dword [phase], PHASE_ENEMY
    je .r
    mov eax, [newX]
    mov ebx, [newY]
    call enemy_at
    cmp eax, -1
    je .move
    mov [eIdx], eax
    cmp dword [attacksLeft], 0
    jle .noatt
    call attack_enemy           ; uses the weapon's own range; CF = out of range
    jc .move                    ; too far: walk toward it instead
    call check_combat_end
    ret
.noatt:
    msg msgAct
    ret
.explore:                       ; exploring: clicking an enemy in weapon range starts the fight with your hit
    mov eax, [newX]
    mov ebx, [newY]
    call enemy_at
    cmp eax, -1
    je .move
    mov [eIdx], eax
    call weapon_range
    mov ecx, [eIdx]
    push eax
    call dist_to_player
    pop ebx
    cmp eax, ebx
    jg .move
    call start_combat
    call attack_enemy
    call check_combat_end
    ret
.move:
    mov eax, [newX]
    mov [tgtX], eax
    mov eax, [newY]
    mov [tgtY], eax
    call calc_dist
    test eax, eax
    jz .r
    mov dword [moving], 1       ; (turn-based: you walk until your movement runs out)
.r: ret

player_walk_step:
    cmp dword [moving], 0
    je .r
    mov eax, [playerX]
    cmp eax, [tgtX]
    jne .go
    mov eax, [playerY]
    cmp eax, [tgtY]
    jne .go
    mov dword [moving], 0
    ret
.go:
    cmp dword [gameMode], MODE_COMBAT
    jne .calc
    cmp dword [movementPoint], 0
    jg .calc
    mov dword [moving], 0
    ret
.calc:
    mov dword [pfIgnore], -1    ; find the way round whatever is in the way (path.inc)
    mov dword [pfMeBlocks], 0
    mov eax, [tgtX]
    mov ebx, [tgtY]
    call pf_build
    mov eax, [playerX]
    mov ebx, [playerY]
    call pf_next
    jc .straight
    mov [nX], eax
    mov [nY], ebx
    jmp .stepped
.straight:                      ; no way round (or the target is a wall of things): straight line, as before
    mov eax, [playerX]
    mov ebx, [tgtX]
    call step_toward
    mov [nX], eax
    mov eax, [playerY]
    mov ebx, [tgtY]
    call step_toward
    mov [nY], eax
.stepped:
    mov eax, [nX]
    mov ebx, [nY]
    call enemy_at
    cmp eax, -1
    jne .stop
    mov eax, [nX]
    mov ebx, [nY]
    call is_door
    jnc .obst
    mov dword [moving], 0
    cmp dword [doorOpen], 0
    je .sealed
    cmp dword [inFight], 0
    jne .infight
    jmp next_room
.sealed:
    call say_sealed
    ret
.infight:
    msg msgInFight
    ret
.obst:
    call obstacle_at            ; plaque or torch in the way
    jc .stop
.move:
    mov eax, [playerX]
    mov [gX], eax
    mov eax, [playerY]
    mov [gY], eax
    mov eax, [nX]
    mov [playerX], eax
    mov eax, [nY]
    mov [playerY], eax
    mov eax, [gX]               ; redraw the cell you left (it may hold an item)
    mov ebx, [gY]
    call cell_glyph
    call put_cell
    mov eax, [playerX]
    mov ebx, [playerY]
    mov dl, '@'
    call put_cell
    call check_pickup
    call stealth_step
    cmp dword [gameMode], MODE_COMBAT
    jne .r
    dec dword [movementPoint]
    call draw_movement
.r: ret
.stop:
    mov dword [moving], 0
    ret

draw_panel_header:              ; row 6 over the right-hand panel: SPELLS or BAG
    pushad
    mov eax, 6                  ; wipe the old header first
    mov ebx, MENU_COL
    call goto_rc
    print_string blank8, 8
    print_string blank8, 8
    print_string blank8, 8
    mov eax, 6
    mov ebx, MENU_COL
    call goto_rc
    cmp dword [bagOpen], 0
    jne .bag
    print_string hdrMenu,hdrMenulen
    print_string blank4, 3
    jmp .d
.bag:
    print_string hdrBag,hdrBaglen
.d: popad
    ret

weapon_range:                   ; -> eax = the attack range of the weapon you hold
    mov esi, [equipWeapon]
    test esi, esi
    jz .f
    mov esi, [esi+CAT_PTR]
    movzx eax, byte [esi+WEAPON_ATTACK_RANGE]
    ret
.f: mov eax, 1
    ret

; ===== begin path.inc =====
; =====================================================================
; path.inc  -  finding a way around things
;
; pf_build fills a distance map: how many steps every cell is from a target, walking in 8
; directions and going around doors, plaques, torches, gates and other bodies. pf_next then
; picks the neighbour that is one step closer. The player walks this way, the path preview
; follows it, and small enemies use it to reach you. pf_build_big does the same for a big
; body: it maps every place its top-left corner could stand with the whole body fitting.
;
; The window also gets the preview as an invisible message (an "OSC" escape code that a
; normal terminal ignores), so it can draw the path and spell areas itself without the game
; writing over torches and doors.
; =====================================================================

section .data
pfDX   dd 1, -1, 0, 0, 1, 1, -1, -1      ; straight moves first: on a tie they win (nicer paths)
pfDY   dd 0, 0, 1, -1, 1, -1, 1, -1
oscPre db 27, "]77;"
oscPrelen equ $- oscPre
oscEnd db 7
hexCh  db "0123456789abcdef"
dirCh  db "64283917"                     ; numpad digits for the 8 directions above (6 = right ...)

section .bss
pfDist  resb GRID_W*GRID_H               ; 255 = can't get there
pfBlk   resb GRID_W*GRID_H
pfQ     resd GRID_W*GRID_H
pfPos   resb GRID_W*GRID_H               ; big bodies: 1 = its top-left can't be here (the body wouldn't fit)
pbW     resd 1                           ; the big body being routed: width, height, reach
pbH     resd 1
pbR     resd 1
pfIgnore resd 1                          ; this enemy's own body doesn't block it (-1 = none)
pfMeBlocks resd 1                        ; 1 = the player's cell blocks (for enemies)
pfTX    resd 1
pfTY    resd 1
pfX     resd 1
pfY     resd 1
pfBest  resd 1
pfBX    resd 1
pfBY    resd 1
pfBD    resd 1                           ; tie-break: distance as the crow flies, squared
oscBuf  resb 400
oscLen  resd 1
pathCX  resd 80                          ; the cells the preview painted (to clean up)
pathCY  resd 80
pathCN  resd 1

section .text
; eax=x, ebx=y -> ecx = index into the maps
pf_idx:
    imul ecx, ebx, GRID_W
    add ecx, eax
    ret

pf_build:                               ; eax=target x, ebx=target y. Uses [pfIgnore], [pfMeBlocks]
    pushad
    mov [pfTX], eax
    mov [pfTY], ebx
    xor ebx, ebx                        ; 1) what blocks
.by: cmp ebx, GRID_H
    jge .bfs
    xor eax, eax
.bx: cmp eax, GRID_W
    jge .bny
    call pf_idx
    mov byte [pfDist+ecx], 255
    mov byte [pfBlk+ecx], 0
    push eax
    push ebx
    push ecx
    call obstacle_at
    jc .blocked
    cmp dword [pfMeBlocks], 0
    je .en
    cmp eax, [playerX]
    jne .en
    cmp ebx, [playerY]
    je .blocked
.en:
    call enemy_at                       ; (clobbers ecx)
    cmp eax, -1
    je .free
    cmp eax, [pfIgnore]
    je .free
.blocked:
    pop ecx
    mov byte [pfBlk+ecx], 1
    jmp .nx
.free:
    pop ecx
.nx:
    pop ebx
    pop eax
    inc eax
    jmp .bx
.bny:
    inc ebx
    jmp .by
.bfs:                                   ; 2) spread out from the target (it may itself be "blocked": a door, an enemy)
    mov eax, [pfTX]
    mov ebx, [pfTY]
    cmp eax, GRID_W
    jae .done
    cmp ebx, GRID_H
    jae .done
    call pf_idx
    mov byte [pfDist+ecx], 0
    mov [pfQ], ecx
    xor esi, esi                        ; head
    mov edi, 1                          ; tail
.q: cmp esi, edi
    jge .done
    mov ecx, [pfQ+esi*4]
    inc esi
    mov eax, ecx                        ; back to x, y
    xor edx, edx
    mov ebx, GRID_W
    div ebx                             ; eax = y, edx = x
    mov [pfY], eax
    mov [pfX], edx
    movzx ebp, byte [pfDist+ecx]
    inc ebp
    xor ecx, ecx
.n: cmp ecx, 8
    jge .q
    mov eax, [pfX]
    add eax, [pfDX+ecx*4]
    mov ebx, [pfY]
    add ebx, [pfDY+ecx*4]
    cmp eax, GRID_W
    jae .nn
    cmp ebx, GRID_H
    jae .nn
    push ecx
    call pf_idx
    cmp byte [pfBlk+ecx], 0
    jne .nn2
    cmp byte [pfDist+ecx], 255
    jne .nn2
    mov edx, ebp
    mov [pfDist+ecx], dl
    mov [pfQ+edi*4], ecx
    inc edi
.nn2:
    pop ecx
.nn:
    inc ecx
    jmp .n
.done:
    popad
    ret

pf_build_big:                           ; ecx = a big enemy: map how many steps its top-left is from
    pushad                              ;   any spot where its body has you within its reach
    mov [pfIgnore], ecx
    mov dword [pfMeBlocks], 1           ; (it can't stand on you)
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    mov [pbW], eax
    movzx eax, byte [esi+ENEMY_H]
    mov [pbH], eax
    movzx eax, byte [esi+ENEMY_RANGE]
    cmp eax, 1
    jge .rg
    mov eax, 1
.rg:mov [pbR], eax
    mov eax, -1                         ; 1) what blocks (no target: no spreading yet)
    mov ebx, -1
    call pf_build
    xor edi, edi                        ; 2) every top-left spot: does the body fit? is it a goal?
    xor esi, esi                        ;    edi = queue tail
    xor ebx, ebx
.py:cmp ebx, GRID_H
    jge .bfs
    xor eax, eax
.px:cmp eax, GRID_W
    jge .pny
    call pf_idx
    mov byte [pfPos+ecx], 1
    push eax
    push ebx
    mov edx, eax                        ; the body's right edge / bottom edge must be inside
    add edx, [pbW]
    cmp edx, GRID_W
    ja .nofit
    mov edx, ebx
    add edx, [pbH]
    cmp edx, GRID_H
    ja .nofit
    xor ebp, ebp                        ; every cell of the body free?
.fy:cmp ebp, [pbH]
    jge .fit
    xor edx, edx
.fx:cmp edx, [pbW]
    jge .fyn
    push eax
    push ebx
    add eax, edx
    add ebx, ebp
    push ecx
    call pf_idx
    cmp byte [pfBlk+ecx], 0
    pop ecx
    pop ebx
    pop eax
    jne .nofit
    inc edx
    jmp .fx
.fyn:
    inc ebp
    jmp .fy
.fit:
    mov byte [pfPos+ecx], 0
    call pb_gap                         ; eax,ebx = top-left -> edx = steps between body and you
    cmp edx, [pbR]
    jg .nofit
    mov byte [pfDist+ecx], 0            ; in reach from here: a goal
    mov [pfQ+edi*4], ecx
    inc edi
.nofit:
    pop ebx
    pop eax
    inc eax
    jmp .px
.pny:
    inc ebx
    jmp .py
.bfs:                                   ; 3) spread out from every goal over spots where it fits
    xor esi, esi
.q: cmp esi, edi
    jge .done
    mov ecx, [pfQ+esi*4]
    inc esi
    mov eax, ecx
    xor edx, edx
    mov ebx, GRID_W
    div ebx                             ; eax = y, edx = x
    mov [pfY], eax
    mov [pfX], edx
    movzx ebp, byte [pfDist+ecx]
    inc ebp
    cmp ebp, 250
    jae .q
    xor ecx, ecx
.n: cmp ecx, 8
    jge .q
    mov eax, [pfX]
    add eax, [pfDX+ecx*4]
    mov ebx, [pfY]
    add ebx, [pfDY+ecx*4]
    cmp eax, GRID_W
    jae .nn
    cmp ebx, GRID_H
    jae .nn
    push ecx
    call pf_idx
    cmp byte [pfPos+ecx], 0
    jne .nn2
    cmp byte [pfDist+ecx], 255
    jne .nn2
    mov edx, ebp
    mov [pfDist+ecx], dl
    mov [pfQ+edi*4], ecx
    inc edi
.nn2:
    pop ecx
.nn:
    inc ecx
    jmp .n
.done:
    popad
    ret

pb_gap:                                 ; eax,ebx = a big body's top-left ([pbW] x [pbH]) -> edx = its distance to you   (keeps the rest)
    push eax
    push ebx
    push ecx
    xor ecx, ecx                        ; dx
    cmp [playerX], eax
    jge .r1
    mov ecx, eax
    sub ecx, [playerX]
    jmp .y
.r1:add eax, [pbW]
    dec eax
    cmp [playerX], eax
    jle .y
    mov ecx, [playerX]
    sub ecx, eax
.y: xor edx, edx                        ; dy
    cmp [playerY], ebx
    jge .r2
    mov edx, ebx
    sub edx, [playerY]
    jmp .m
.r2:add ebx, [pbH]
    dec ebx
    cmp [playerY], ebx
    jle .m
    mov edx, [playerY]
    sub edx, ebx
.m: cmp edx, ecx
    jge .r
    mov edx, ecx
.r: pop ecx
    pop ebx
    pop eax
    ret

pf_dist_at:                             ; eax=x, ebx=y -> edx = steps from the target (255 = none)
    push ecx
    mov edx, 255
    cmp eax, GRID_W
    jae .r
    cmp ebx, GRID_H
    jae .r
    call pf_idx
    movzx edx, byte [pfDist+ecx]
.r: pop ecx
    ret

pf_next:                                ; eax=x, ebx=y -> eax,ebx = the next cell toward the target; CF=1 = no way
    pushad
    mov [pfX], eax
    mov [pfY], ebx
    call pf_dist_at
    mov [pfBest], edx                   ; must beat where we stand
    mov dword [pfBD], 0x7fffffff
    mov dword [pfBX], -1
    xor ecx, ecx
.n: cmp ecx, 8
    jge .pick
    mov eax, [pfX]
    add eax, [pfDX+ecx*4]
    mov ebx, [pfY]
    add ebx, [pfDY+ecx*4]
    call pf_dist_at
    cmp edx, 255
    je .nn
    cmp edx, [pfBest]
    jg .nn
    jl .take                            ; strictly closer
    ; same distance: only switch if nearer the target as the crow flies
    cmp dword [pfBX], -1
    je .nn                              ; (equal to where we stand and nothing better yet: not a step forward)
    call .crow
    cmp edi, [pfBD]
    jge .nn
    jmp .take2
.take:
    call .crow
.take2:
    mov [pfBest], edx
    mov [pfBD], edi
    mov [pfBX], eax
    mov [pfBY], ebx
.nn:
    inc ecx
    jmp .n
.pick:
    cmp dword [pfBX], -1
    je .none
    mov eax, [pfX]                      ; must actually be closer than where we stand
    mov ebx, [pfY]
    call pf_dist_at
    cmp [pfBest], edx
    jge .none
    popad
    mov eax, [pfBX]
    mov ebx, [pfBY]
    clc
    ret
.none:
    popad
    stc
    ret
.crow:                                  ; eax,ebx = a cell -> edi = squared distance to the target
    push eax
    push ebx
    sub eax, [pfTX]
    imul eax, eax
    sub ebx, [pfTY]
    imul ebx, ebx
    lea edi, [eax+ebx]
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------
; invisible notes for the window: ESC ] 77 ; <text> BEL
; ---------------------------------------------------------------------
osc_begin:
    mov dword [oscLen], 0
    ret
osc_char:                               ; al = a character
    push ecx
    mov ecx, [oscLen]
    cmp ecx, 390
    jae .r
    mov [oscBuf+ecx], al
    inc dword [oscLen]
.r: pop ecx
    ret
osc_num:                                ; eax = a number (0..9999)
    pushad
    xor ecx, ecx
    mov ebx, 10
.d: xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .d
.p: pop eax
    add al, '0'
    call osc_char
    loop .p
    popad
    ret
osc_send:
    pushad
    print_string oscPre, oscPrelen
    print_string oscBuf, [oscLen]
    print_string oscEnd, 1
    popad
    ret

; ---------------------------------------------------------------------
; the walking-path preview
; ---------------------------------------------------------------------
path_preview:                           ; draw ([pathMode]=1) or remove (0) the path to [tgtX],[tgtY]
    pushad
    cmp dword [pathMode], 0
    jne .draw
    xor esi, esi                        ; remove: put back what was under each painted cell
.e: cmp esi, [pathCN]
    jge .eo
    mov eax, [pathCX+esi*4]
    mov ebx, [pathCY+esi*4]
    call cell_glyph
    call put_cell
    inc esi
    jmp .e
.eo:
    mov dword [pathCN], 0
    call osc_begin
    mov al, 'C'
    call osc_char
    call osc_send
    popad
    ret
.draw:
    mov dword [pfIgnore], -1
    mov dword [pfMeBlocks], 0
    mov eax, [tgtX]
    mov ebx, [tgtY]
    call pf_build
    mov dword [pathCN], 0
    call osc_begin
    mov al, 'P'
    call osc_char
    mov eax, [playerX]
    mov [pathX], eax
    mov eax, [playerY]
    mov [pathY], eax
    mov dword [pathI], 0
.s: cmp dword [pathI], 70
    jge .send
    mov eax, [pathX]
    cmp eax, [tgtX]
    jne .step
    mov eax, [pathY]
    cmp eax, [tgtY]
    je .send
.step:
    mov eax, [pathX]
    mov ebx, [pathY]
    call pf_next
    jnc .have
    mov eax, [pathX]                    ; no way round: the straight line, like before
    mov ebx, [tgtX]
    call step_toward
    push eax
    mov eax, [pathY]
    mov ebx, [tgtY]
    call step_toward
    mov ebx, eax
    pop eax
.have:
    mov ecx, eax                        ; direction digit for the window
    sub ecx, [pathX]
    mov edx, ebx
    sub edx, [pathY]
    push eax
    push ebx
    xor edi, edi
.fd: cmp edi, 8
    jge .fdn
    cmp ecx, [pfDX+edi*4]
    jne .fdx
    cmp edx, [pfDY+edi*4]
    je .fdn
.fdx: inc edi
    jmp .fd
.fdn:
    cmp edi, 8
    jl .dok
    xor edi, edi
.dok:
    mov al, [dirCh+edi]
    call osc_char
    pop ebx
    pop eax
    mov [pathX], eax
    mov [pathY], ebx
    inc dword [pathI]
    call cell_glyph                     ; only paint empty floor (never over torches, doors, plaques)
    cmp dl, '.'
    jne .s
    mov ecx, [pathCN]
    cmp ecx, 80
    jae .s
    mov [pathCX+ecx*4], eax
    mov [pathCY+ecx*4], ebx
    inc dword [pathCN]
    mov dl, '*'
    cmp dword [gameMode], MODE_COMBAT
    jne .put
    mov ecx, [pathI]
    cmp ecx, [movementPoint]
    jle .put
    mov dl, 'x'
.put:
    call put_cell
    jmp .s
.send:
    call osc_send
    popad
    ret

; ---------------------------------------------------------------------
; the spell-area preview, for the window: A<valid>,<x0>,<y0>,<w>,<h>,<hex bits row by row>
; ---------------------------------------------------------------------
area_note:
    pushad
    call osc_begin
    mov al, 'A'
    call osc_char
    mov eax, [areaValid]
    test eax, eax
    setnz al
    movzx eax, al
    call osc_num
    cmp dword [areaCount], 0
    je .send
    mov eax, 9999                       ; bounding box
    mov ebx, 9999
    mov ecx, -1
    mov edx, -1
    xor esi, esi
.bb: cmp esi, [areaCount]
    jge .bbd
    mov edi, [areaX+esi*4]
    cmp edi, eax
    jge .b1
    mov eax, edi
.b1: cmp edi, ecx
    jle .b2
    mov ecx, edi
.b2: mov edi, [areaY+esi*4]
    cmp edi, ebx
    jge .b3
    mov ebx, edi
.b3: cmp edi, edx
    jle .b4
    mov edx, edi
.b4: inc esi
    jmp .bb
.bbd:
    mov [pfX], eax                      ; x0, y0, w, h
    mov [pfY], ebx
    sub ecx, eax
    inc ecx
    mov [pfTX], ecx
    sub edx, ebx
    inc edx
    mov [pfTY], edx
    mov ebp, ecx
    imul ebp, edx
    cmp ebp, GRID_W*GRID_H              ; (areas always fit on the grid)
    ja .send
    push eax
    mov al, ','
    call osc_char
    pop eax
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [pfY]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [pfTX]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [pfTY]
    call osc_num
    mov al, ','
    call osc_char
    ; the bits, built in pfBlk (scratch: the next pf_build fills it again)
    xor ecx, ecx
.z: cmp ecx, ebp
    jge .fill
    mov byte [pfBlk+ecx], 0
    inc ecx
    jmp .z
.fill:
    xor esi, esi
.f: cmp esi, [areaCount]
    jge .hex
    mov eax, [areaY+esi*4]
    sub eax, [pfY]
    imul eax, [pfTX]
    add eax, [areaX+esi*4]
    sub eax, [pfX]
    cmp eax, ebp
    jae .fn
    mov byte [pfBlk+eax], 1
.fn: inc esi
    jmp .f
.hex:
    xor esi, esi                        ; 4 cells per hex digit
.h: cmp esi, ebp
    jge .send
    xor edx, edx
    xor ecx, ecx
.hb: cmp ecx, 4
    jge .hd
    shl edx, 1
    lea eax, [esi+ecx]
    cmp eax, ebp
    jge .hz
    movzx eax, byte [pfBlk+eax]
    or edx, eax
.hz: inc ecx
    jmp .hb
.hd:
    mov al, [hexCh+edx]
    call osc_char
    add esi, 4
    jmp .h
.send:
    call osc_send
    popad
    ret

; ---------------------------------------------------------------------
; a spell is cast: S<spell>,<you x>,<you y>,<n>,<x,y> x n,<area x0>,<y0>,<w>,<h>  (for its animation)
; ---------------------------------------------------------------------
cast_note:
    pushad
    call osc_begin
    mov al, 'S'
    call osc_char
    mov eax, [armedSpell]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerX]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerY]
    call osc_num
    mov al, ','
    call osc_char
    mov ecx, [dartN]
    test ecx, ecx
    jnz .darts
    mov eax, 1
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [tgtX]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [tgtY]
    call osc_num
    jmp .area
.darts:
    mov eax, ecx
    call osc_num
    xor esi, esi
.dl: cmp esi, [dartN]
    jge .area
    mov al, ','
    call osc_char
    mov eax, [dartX+esi*4]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [dartY+esi*4]
    call osc_num
    inc esi
    jmp .dl
.area:                                  ; the area's box
    mov eax, 9999
    mov ebx, 9999
    mov ecx, -1
    mov edx, -1
    xor esi, esi
.bb: cmp esi, [areaCount]
    jge .bbd
    mov edi, [areaX+esi*4]
    cmp edi, eax
    jge .b1
    mov eax, edi
.b1: cmp edi, ecx
    jle .b2
    mov ecx, edi
.b2: mov edi, [areaY+esi*4]
    cmp edi, ebx
    jge .b3
    mov ebx, edi
.b3: cmp edi, edx
    jle .b4
    mov edx, edi
.b4: inc esi
    jmp .bb
.bbd:
    cmp dword [areaCount], 0
    je .send
    sub ecx, eax
    inc ecx
    sub edx, ebx
    inc edx
    push edx
    push ecx
    push ebx
    push eax
    mov al, ','
    call osc_char
    pop eax
    call osc_num
    mov al, ','
    call osc_char
    pop eax
    call osc_num
    mov al, ','
    call osc_char
    pop eax
    call osc_num
    mov al, ','
    call osc_char
    pop eax
    call osc_num
.send:
    call osc_send
    popad
    ret

; ---------------------------------------------------------------------
; an enemy's ranged attack: E<kind>,<from x>,<from y>,<you x>,<you y>,<hit>  (for its animation)
;   kinds: a arrow (skeleton), l lightning (Altair), s slam (Smo), k bolt (the King), u orb (the Unbound)
; ---------------------------------------------------------------------
attack_note:                            ; [eI] = the attacker, eax = 1 hit / 0 miss
    pushad
    mov [pfBest], eax
    mov ecx, [eI]
    mov edx, [enemyType+ecx*4]
    mov bl, 'l'
    cmp edx, ETYPE_ALTAIR
    je .go
    mov bl, 's'
    cmp edx, ETYPE_SMO
    je .go
    mov bl, 'k'
    cmp edx, ETYPE_KING
    je .go
    mov bl, 'u'
    cmp edx, ETYPE_UCOPY
    je .ub
    cmp edx, ETYPE_UNBOUND
    jne .sk
.ub:cmp dword [uMode], UF_DUO           ; the Unbound strikes as the boss he imitates:
    jne .go                             ;   the quick body throws lightning, the heavy one slams
    push esi
    call enemy_rec
    cmp byte [esi+ENEMY_W], 2
    pop esi
    mov bl, 'l'
    je .go
    mov bl, 's'
    jmp .go
.sk:
    mov bl, 'a'
    cmp edx, ETYPE_SKELETON
    jne .r
    push ebx
    call dist_to_player
    pop ebx
    cmp eax, 1
    jle .r                              ; a skeleton next to you just swings
.go:
    mov [pfBX], ebx
    call osc_begin
    mov al, 'E'
    call osc_char
    mov eax, [pfBX]
    call osc_char
    mov ecx, [eI]
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    shr eax, 1
    add eax, [enemyX+ecx*4]
    call osc_num
    mov al, ','
    call osc_char
    movzx eax, byte [esi+ENEMY_H]
    shr eax, 1
    add eax, [enemyY+ecx*4]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerX]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerY]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [pfBest]
    call osc_num
    call osc_send
.r: popad
    ret

; ---------------------------------------------------------------------
; little icons over heads, sent only when something changes:
;   F<parry>,<rally temp HP>,<surge on>,<maneuver ready>       (the fighter)
;   N<i>:<x>:<y>:<w>:<h>:<status bits>;...                    (every living enemy)
; ---------------------------------------------------------------------
section .bss
lastF   resd 4
lastN   resd MAX_ENEMIES*6
section .text
head_notes:                             ; call every tick
    pushad
    xor ebx, ebx                        ; 1) the fighter
    mov eax, [parryBonus]
    cmp eax, [lastF]
    setne bl
    mov ecx, [tempHP]
    cmp ecx, [lastF+4]
    setne bh
    or bl, bh
    xor edx, edx                        ; surge on = used this turn and attacks left
    cmp dword [surgeUsed], 0
    je .s0
    cmp dword [attacksLeft], 0
    jle .s0
    mov edx, 1
.s0:
    cmp edx, [lastF+8]
    je .s1
    mov bl, 1
.s1:
    mov esi, [pendingMan]
    cmp esi, [lastF+12]
    je .s2
    mov bl, 1
.s2:
    test bl, bl
    jz .enemies
    mov [lastF], eax
    mov [lastF+4], ecx
    mov [lastF+8], edx
    mov [lastF+12], esi
    call osc_begin
    mov al, 'F'
    call osc_char
    mov eax, [lastF]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [lastF+4]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [lastF+8]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [lastF+12]
    call osc_num
    call osc_send
.enemies:                               ; 2) enemies: position, size, statuses
    xor ebp, ebp                        ; changed?
    xor ecx, ecx
.e: cmp ecx, MAX_ENEMIES
    jge .esend
    imul edi, ecx, 24
    xor eax, eax                        ; status bits (0 if dead)
    cmp dword [enemyHP+ecx*4], 0
    jle .bits
    imul ebx, ecx, STAT_STRIDE
    mov esi, 1
.b: cmp esi, LAST_STATUS
    jg .bits
    cmp byte [statusTimer+ebx+esi], 0
    je .bn
    bts eax, esi
.bn:inc esi
    jmp .b
.bits:
    or eax, 0x80000000                  ; (so a living enemy with no status still differs from "never sent")
    cmp dword [enemyHP+ecx*4], 0
    jg .al
    xor eax, eax
.al:
    cmp eax, [lastN+edi]
    je .px
    mov [lastN+edi], eax
    mov ebp, 1
.px:mov eax, [enemyX+ecx*4]
    cmp eax, [lastN+edi+4]
    je .py
    mov [lastN+edi+4], eax
    mov ebp, 1
.py:mov eax, [enemyY+ecx*4]
    cmp eax, [lastN+edi+8]
    je .en
    mov [lastN+edi+8], eax
    mov ebp, 1
.en:inc ecx
    jmp .e
.esend:
    test ebp, ebp
    jz .r
    call osc_begin
    mov al, 'N'
    call osc_char
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .send
    cmp dword [enemyHP+ecx*4], 0
    jle .ln
    mov eax, ecx
    call osc_num
    mov al, ':'
    call osc_char
    mov eax, [enemyX+ecx*4]
    call osc_num
    mov al, ':'
    call osc_char
    mov eax, [enemyY+ecx*4]
    call osc_num
    mov al, ':'
    call osc_char
    push esi
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    call osc_num
    mov al, ':'
    call osc_char
    movzx eax, byte [esi+ENEMY_H]
    pop esi
    call osc_num
    mov al, ':'
    call osc_char
    imul edi, ecx, 24
    mov eax, [lastN+edi]
    and eax, 0xffff
    call osc_num
    mov al, ';'
    call osc_char
.ln:inc ecx
    jmp .l
.send:
    call osc_send
.r: popad
    ret
; ===== end path.inc =====
; ===== begin room.inc =====
; =====================================================================
; room.inc  -  the 1x3 door, the plaque, and the logic gate puzzles
;
; Floor 1 is the tutorial room: the door is open.
; From floor 2 on, the game picks a logic gate and puts PAIRS of torches in the
; room. Each pair is one input to the gate: the left torch is A, the right one is B.
; [0] = unlit (0), [1] = lit (1). Click a torch next to you to flip it.
;   floors 2-3: light ANY one pair the gate accepts
;   floor 4+:   one pair for EVERY input the gate accepts, each pair different
; The plaque (R) beside the door says which gate it is, in a riddle.
; After floor 15 the rooms hold whole circuits instead: see circuit.inc.
; Uses from game.asm: put_cell rand_mod msg msg_begin msg_text msg_end
;   floorCount playerX playerY  and from game_assets.asm: doorasset opendoorasset
;   door_h puzzlenode puzzlenodeactive puzzlenode_w panelasset
; =====================================================================

section .data

DOOR_X   equ 50                 ; the door is 1 wide and door_h (3) tall, on the right wall
DOOR_Y   equ 5                  ; top cell of the door (rows 5..7, centred on the entrance row 6)
PLAQUE_X equ 50
PLAQUE_Y equ 9                  ; just below the door
NODE_X   equ 36                 ; left edge of every torch pair: "[A][B]" is 6 cells wide
NODE_Y0  equ 2                  ; row of the first pair; each next pair is 3 rows lower
NODE_DY  equ 3
MAX_PAIRS equ 3

GATE_COUNT equ 6
; which inputs each gate accepts, as a 4-bit set. Bit number = A*2 + B:
;   bit0 = 00, bit1 = 01, bit2 = 10, bit3 = 11
;              AND     OR      XOR     NAND    NOR     XNOR
gateTruth  db 0b1000, 0b1110, 0b0110, 0b0111, 0b0001, 0b1001

; the plaque riddles, one per gate, all padded to the same length (RIDDLE_LEN)
RIDDLE_LEN equ 44
%macro riddle 1
    %strlen _rl %1
    db %1
    times RIDDLE_LEN - _rl db ' '
%endmacro
riddles:
    riddle "AND - both must burn, or none may pass."
    riddle "OR - one, the other, or both. Never none."
    riddle "XOR - one and none, but not all."
    riddle "NAND - anything at all, but never both."
    riddle "NOR - only darkness opens the way."
    riddle "XNOR - twins: alike in light or in dark."

needAny  db " (light one pair)"
needAnylen equ $- needAny
needAll  db " (every true pair, each different)"
needAlllen equ $- needAll
noPlaque db "The plaque is blank. The door is already open."
noPlaquelen equ $- noPlaque
msgOpen  db "Click. The door grinds open."
msgOpenlen equ $- msgOpen
msgSealed db "The door is sealed. Read the plaque (R)."
msgSealedlen equ $- msgSealed
msgReach db "Too far - walk next to the torch first."
msgReachlen equ $- msgReach
msgInFight db "You can't leave mid-fight."
msgInFightlen equ $- msgInFight
msgBossSeal db "The door won't budge while the guardian lives."
msgBossSeallen equ $- msgBossSeal
msgWarden db "A Warden blocks the way! Light the torch pair to match the gate on his shield."
msgWardenlen equ $- msgWarden
msgKing db "The Forgotten King sits immune on his throne. Power the circuit - its blue torch will blast him."
msgKinglen equ $- msgKing
msgFalls db "The guardian falls. The door grinds open."
msgFallslen equ $- msgFalls
msgShade db "The Dark Shade rises. Its torches burn cold - only the lantern can reveal it."
msgShadelen equ $- msgShade

section .bss
doorOpen   resd 1
bossRoom   resd 1               ; 0 normal, 1 Warden, 2 the Forgotten King, 3 his Dark Shade, 4 Ymir, 5 Logic Keeper, 6 Altair and Smo
puzzleOn   resd 1               ; 0 in the tutorial room
puzzleGate resd 1               ; 0..5  (AND OR XOR NAND NOR XNOR)
puzzleAll  resd 1               ; 1 = every accepted input must be shown
puzzlePairs resd 1
nodeBit    resb 8               ; 0 / 1 for each torch
roomTmp    resd 1
roomTry    resd 1
seenSet    resd 1
touched    resd 1               ; 1 = touch_node flipped the torch, 0 = it was too far
pairX      resd 1               ; where the torch pairs stand (the Warden and the Unbound King move them)
pairY      resd 1

section .text

; ---------------------------------------------------------------------
; set up the room you just entered (call AFTER floorCount is set)
; ---------------------------------------------------------------------
setup_room:
    mov dword [puzzleOn], 0
    mov dword [doorOpen], 1
    mov dword [bossRoom], 0
    mov dword [pairX], NODE_X
    mov dword [pairY], NODE_Y0
    cmp dword [floorCount], 1
    jle .r                          ; tutorial room: no puzzle, door open
    mov eax, [floorCount]           ; boss rooms: the door stays shut until the boss is dead
    cmp eax, FINAL_FLOOR
    je .king
    cmp eax, SHADE_FLOOR
    je .shade
    cmp eax, YMIR_FLOOR
    je .ymir
    cmp eax, DUO_FLOOR
    je .duo
    cmp eax, KEEPER_FLOOR
    jne .notkeeper
    mov dword [bossRoom], BR_KEEPER ; the Logic Keeper and its Wardens: a torch pair beside each (bosses2.inc)
    jmp keeper2_setup
.notkeeper:
    cmp eax, BISHOP_FLOOR
    jne .notbish
    mov dword [bossRoom], BR_BISHOP ; the Four Bishops: no torches, the gates are on the square
    mov dword [doorOpen], 0
    ret
.notbish:
    xor ecx, ecx
.mb:
    cmp ecx, MINIBOSS_FLOORS
    jge .puzzle
    cmp al, [minibossFloors+ecx]
    je .mini
    inc ecx
    jmp .mb
.king:
    mov dword [bossRoom], 2
    mov dword [doorOpen], 0
    jmp king_room_setup             ; the throne circuit (bosses.inc)
.mini:
    mov dword [bossRoom], 1
    mov dword [doorOpen], 0
    jmp warden_room_setup           ; the torch pair behind the Warden (bosses.inc)
.shade:
    mov dword [bossRoom], 3
    mov dword [doorOpen], 0
    jmp shade_room_setup            ; four torches, two gates, the lantern (bosses.inc)
.ymir:
    mov dword [bossRoom], BR_YMIR
    mov dword [doorOpen], 0
    jmp ymir_room_setup             ; four torches, two gates, two power torches (bosses.inc)
.duo:
    mov dword [bossRoom], BR_DUO
    mov dword [doorOpen], 0
    ret
.puzzle:
    cmp dword [floorCount], HALF_FLOOR
    jle .pairs
    call setup_circuit              ; the second half: whole circuits
    ret
.pairs:
    mov dword [puzzleOn], 1
    mov dword [doorOpen], 0
    mov eax, GATE_COUNT
    call rand_mod
    mov [puzzleGate], eax
    mov dword [puzzleAll], 0
    mov dword [puzzlePairs], 1
    cmp dword [floorCount], 3
    jle .roll                       ; floors 2-3: one pair is enough
    mov dword [puzzleAll], 1        ; floor 4+: one pair per accepted input
    call truth_set
    xor ecx, ecx                    ; count the bits in the truth set
.cnt:
    test eax, eax
    jz .cdone
    mov edx, eax
    and edx, 1
    add ecx, edx
    shr eax, 1
    jmp .cnt
.cdone:
    mov [puzzlePairs], ecx
.roll:                              ; random torches, but never already solved
    mov dword [roomTry], 60
.again:
    xor ecx, ecx
.bits:
    mov eax, [puzzlePairs]
    shl eax, 1
    cmp ecx, eax
    jge .check
    push ecx
    mov eax, 2
    call rand_mod
    pop ecx
    mov [nodeBit+ecx], al
    inc ecx
    jmp .bits
.check:
    call puzzle_solved
    test eax, eax
    jz .r
    dec dword [roomTry]
    jnz .again
.r: ret

truth_set:                          ; -> eax = the accepted-inputs bit set of this room's gate
    mov eax, [puzzleGate]
    movzx eax, byte [gateTruth+eax]
    ret

puzzle_solved:                      ; -> eax = 1 if the torches satisfy the gate (or power the circuit's door)
    cmp dword [puzzleOn], 2
    jne .pairs
    call circ_eval
    mov eax, [circOut]
    ret
.pairs:
    call truth_set
    mov [roomTmp], eax
    mov dword [seenSet], 0
    xor ecx, ecx                    ; pair number
.l: cmp ecx, [puzzlePairs]
    jge .yes
    movzx eax, byte [nodeBit+ecx*2]     ; A
    shl eax, 1
    movzx edx, byte [nodeBit+ecx*2+1]   ; B
    or eax, edx                     ; eax = A*2 + B, the input this pair shows
    mov edx, [roomTmp]
    bt edx, eax
    jnc .no                         ; the gate rejects this input
    cmp dword [puzzleAll], 0
    je .next
    mov edx, [seenSet]
    bt edx, eax
    jc .no                          ; the same input twice: not "each different"
    bts edx, eax
    mov [seenSet], edx
.next:
    inc ecx
    jmp .l
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; ---------------------------------------------------------------------
; what is where
; ---------------------------------------------------------------------
is_door:                            ; eax=x, ebx=y -> CF=1 on a door cell
    cmp eax, DOOR_X
    jne .no
    cmp ebx, DOOR_Y
    jl .no
    cmp ebx, DOOR_Y + door_h - 1
    jg .no
    stc
    ret
.no:
    clc
    ret

torch_count:                        ; -> eax = how many torches this room has   (keeps the rest)
    cmp dword [puzzleOn], 2
    jne .p
    mov eax, [circNT]
    ret
.p: mov eax, [puzzlePairs]
    shl eax, 1
    ret

torch_pos:                          ; eax = torch number -> eax = its left column, edx = its row   (keeps the rest)
    cmp dword [puzzleOn], 2
    jne .p
    movzx edx, byte [circTY+eax]
    movzx eax, byte [circTX+eax]
    ret
.p: call keeper_like
    jne .p2
    push ecx                        ; the Keeper's room: each pair beside its own Warden
    mov ecx, eax
    shr ecx, 1
    mov edx, [kPY+ecx*4]
    and eax, 1
    imul eax, eax, puzzlenode_w
    add eax, [kPX+ecx*4]
    pop ecx
    ret
.p2:mov edx, eax                    ; pairs: pair = n/2 (its row), side = n%2 (A left, B right)
    shr edx, 1
    imul edx, edx, NODE_DY
    add edx, [pairY]
    and eax, 1
    imul eax, eax, puzzlenode_w
    add eax, [pairX]
    ret

node_at:                            ; eax=x, ebx=y -> eax = torch number or -1, edx = column inside its "[0]"   (keeps ebx)
    cmp dword [puzzleOn], 0
    je .none
    push ecx
    push esi
    push edi
    mov esi, eax
    mov edi, ebx
    call torch_count
    mov ecx, eax
.l: dec ecx
    js .nope
    mov eax, ecx
    call torch_pos
    cmp edx, edi
    jne .l
    mov edx, esi
    sub edx, eax
    js .l
    cmp edx, puzzlenode_w
    jge .l
    mov eax, ecx
    pop edi
    pop esi
    pop ecx
    ret
.nope:
    pop edi
    pop esi
    pop ecx
.none:
    mov eax, -1
    ret

is_plaque:                          ; eax=x, ebx=y -> CF=1 on the plaque
    cmp dword [puzzleOn], 0
    je .no
    cmp eax, PLAQUE_X
    jne .no
    cmp ebx, PLAQUE_Y
    jne .no
    stc
    ret
.no:
    clc
    ret

obstacle_at:                        ; eax=x, ebx=y -> CF=1 if nobody can stand there (door, plaque, torch)
    push eax
    push edx
    call is_door
    jc .yes
    call is_plaque
    jc .yes
    push eax
    call node_at
    cmp eax, -1
    pop eax
    jne .yes
    call boss_obstacle              ; Ymir's power torches
    jc .yes
    cmp dword [puzzleOn], 2
    jne .free
    call circ_gate_obstacle         ; circuit gates (wires can be walked over)
    jc .yes
.free:
    pop edx
    pop eax
    clc
    ret
.yes:
    pop edx
    pop eax
    stc
    ret

room_glyph:                         ; eax=x, ebx=y -> dl = the room object there, or '.'   (keeps eax, ebx, ecx)
    push eax
    push ecx
    push edx
    mov dl, '.'
    call is_door
    jnc .p
    mov ecx, ebx
    sub ecx, DOOR_Y
    mov dl, [doorasset+ecx]         ; '<' closed
    cmp dword [doorOpen], 0
    je .out
    mov dl, [opendoorasset+ecx]     ; '>' open
    jmp .out
.p: call is_plaque
    jnc .n
    mov dl, [panelasset]
    jmp .out
.n: call node_at
    cmp eax, -1
    je .circ
    mov ecx, edx                    ; column inside the sprite
    cmp byte [nodeBit+eax], 0
    jne .lit
    mov dl, [puzzlenode+ecx]        ; "[0]"
    jmp .out
.lit:
    mov dl, [puzzlenodeactive+ecx]  ; "[1]"
    jmp .out
.circ:
    mov eax, [esp+8]                ; x again
    call boss_glyph                 ; Ymir's power torches -> al, or 0
    test al, al
    jz .c2
    mov dl, al
    jmp .out
.c2:
    cmp dword [puzzleOn], 2
    jne .floor
    mov eax, [esp+8]                ; x again (node_at changed eax)
    call circ_glyph
    test al, al
    jz .floor
    mov dl, al
    jmp .out
.floor:
    mov dl, '.'
.out:
    mov al, dl                      ; hand dl back past the pops
    pop edx
    mov dl, al
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
draw_door:
    pushad
    xor ebx, ebx
.l: cmp ebx, door_h
    jge .d
    push ebx
    add ebx, DOOR_Y
    mov eax, DOOR_X
    call room_glyph
    call put_cell
    pop ebx
    inc ebx
    jmp .l
.d: popad
    ret

draw_room_objects:                  ; door, plaque and every torch
    pushad
    call boss_draw_objects          ; Ymir's power torches
    call draw_door
    cmp dword [puzzleOn], 0
    je .d
    mov eax, PLAQUE_X
    mov ebx, PLAQUE_Y
    call room_glyph
    call put_cell
    cmp dword [puzzleOn], 2
    jne .pairs
    call circ_draw
    jmp .d
.pairs:
    xor ecx, ecx                    ; every cell of every torch (wherever torch_pos puts it)
.tor:
    call torch_count
    cmp ecx, eax
    jge .d
    mov eax, ecx
    call torch_pos                  ; eax = column, edx = row
    mov ebx, edx
    xor esi, esi
.col:
    cmp esi, puzzlenode_w
    jge .np
    push eax
    add eax, esi
    call room_glyph
    call put_cell
    pop eax
    inc esi
    jmp .col
.np:
    inc ecx
    jmp .tor
.d: popad
    ret

; ---------------------------------------------------------------------
; the player's hands
; ---------------------------------------------------------------------
read_plaque:
    pushad
    cmp dword [puzzleOn], 0
    jne .say
    msg noPlaque
    jmp .d
.say:
    cmp dword [bossRoom], 0
    je .say2
    call boss_plaque                ; CF=1: the boss room said it
    jc .d
.say2:
    cmp dword [puzzleOn], 2
    jne .gate
    call circ_plaque
    jmp .d
.gate:
    call msg_begin
    mov eax, [puzzleGate]
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN             ; trim the padding
.t: cmp byte [esi+ecx-1], ' '
    jne .p
    dec ecx
    jmp .t
.p: call msg_text
    cmp dword [puzzleAll], 0
    jne .all
    mov esi, needAny
    mov ecx, needAnylen
    call msg_text
    jmp .e
.all:
    mov esi, needAll
    mov ecx, needAlllen
    call msg_text
.e: call msg_end
.d: popad
    ret

touch_node:                         ; eax = torch number: flip it if you are next to it ([touched] = 1 if it flipped)
    pushad
    mov dword [touched], 0
    mov [roomTmp], eax
    call torch_pos                  ; eax = its left column, edx = its row
    mov ebx, edx
    mov edi, 1                      ; how far you can reach: 1, or 2 with a Gatekey
    push eax
    mov eax, SP_REACH
    call has_special
    pop eax
    jnc .rr
    mov edi, 2
.rr:
    mov ecx, [playerY]              ; you must be within reach rows ...
    sub ecx, ebx
    jns .y
    neg ecx
.y: cmp ecx, edi
    jg .far
    mov ecx, [playerX]              ; ... and within reach columns of its 3 cells
    sub ecx, eax
    neg edi
    cmp ecx, edi
    jl .far
    neg edi
    add edi, puzzlenode_w - 1
    cmp ecx, edi
    jg .far
    mov ecx, [roomTmp]
    xor byte [nodeBit+ecx], 1
    mov dword [touched], 1
    cmp dword [puzzleOn], 2
    jne .redraw
    call circ_eval                  ; the new signal runs through the wires
.redraw:
    call draw_room_objects
    cmp dword [bossRoom], 0
    je .door
    call boss_torch                 ; boss rooms: the torches fight the boss, the door waits for its death
    jmp .d
.door:
    cmp dword [doorOpen], 0
    jne .d                          ; already open: it stays open
    call puzzle_solved
    test eax, eax
    jz .d
    mov dword [doorOpen], 1
    call draw_door
    msg msgOpen
    call xp_puzzle              ; experience for solving it (progress.inc)
    jmp .d
.far:
.d: popad
    ret

; ---------------------------------------------------------------------
; boss rooms
; ---------------------------------------------------------------------
room_cleared:                       ; called when the last enemy dies
    cmp dword [bossRoom], 0
    je .r
    cmp dword [bossRoom], 2
    je .won
    cmp dword [doorOpen], 0
    jne .r
    mov dword [doorOpen], 1
    call draw_door
    msg msgFalls
.r: ret
.won:
    mov dword [wonGame], 1          ; the main loop shows the victory screen
    ret

say_sealed:                         ; walking into a closed door
    cmp dword [bossRoom], 0
    jne .boss
    msg msgSealed
    ret
.boss:
    msg msgBossSeal
    ret

announce_room:                      ; on entering a room
    cmp dword [bossRoom], 0
    je .nb
    call start_combat               ; boss rooms start the fight at once
.nb:
    cmp dword [bossRoom], 1
    je .w
    cmp dword [bossRoom], 2
    je .k
    cmp dword [bossRoom], 3
    je .s
    jmp announce_boss               ; the bosses from bosses.inc
.s: msg msgShade
    ret
.w: msg msgWarden
    ret
.k: msg msgKing
    ret

; ===== begin circuit.inc =====
; =====================================================================
; circuit.inc  -  the logic circuit puzzles of the second half (floors 16-29)
;
; A circuit room has 3 or 4 torches (the inputs, [0] / [1]) wired into 2 or 3 gates.
; Gates feed other gates; the last gate's wire runs to the door. The door opens when
; that wire carries a 1. Every wire shows its value, and every gate shows its output,
; so the player can watch the signal travel and work out what to change.
;
; On the map (and so in the terminal):
;   gate: a 3x3 block, its border '%' when the gate outputs 0, '$' when it outputs 1,
;         and a letter in the middle:  A=AND  V=OR  X=XOR  a=NAND  v=NOR  E=XNOR  N=NOT  ?=hidden
;   wire: '-' / ':' carrying 0 (horizontal / vertical),  '=' / '|' carrying 1
;
;   floors 16-20: (A ? B) ? C                         two chained gates
;   floors 21-24: that, or (A ? B) ? NOT C           a NOT gate joins in
;   floors 25-29: (A ? B) ? (C ? D)  or the NOT one,  and one gate is hidden behind "?":
;                 only the plaque's riddle says what it is (its output still shows)
; The layouts are in circuits.inc (made by gen_circuits.py, which also checks them).
; =====================================================================

section .data
HALF_FLOOR equ 15               ; circuits start after this floor
gateLetter db 'A', 'V', 'X', 'a', 'v', 'E', 'N', 'L'    ; AND OR XOR NAND NOR XNOR NOT, L = the Shade's lantern
GT_NOT equ 6
GT_LANTERN equ 7                ; works like AND, drawn as the lantern in the middle of the Shade's room

; ===== begin circuits.inc =====
; circuits.inc - generated by gen_circuits.py (the room layouts of the circuit puzzles)
; per template:  torches: count, then x,y   gates: count, then inA, inB (255 = NOT gate), cx, cy
;                wires: count (word), then x, y, node   and the output node
CIRC_TEMPLATES equ 6
circ_A_torches db 3, 24,1, 24,5, 24,10
circ_A_gates db 2, 0,1,33,3, 4,2,42,6
circ_A_wires dw 43
    db 27,1,0, 28,1,0, 29,1,0, 30,1,0, 31,1,0, 31,2,0, 27,5,1, 28,5,1, 29,5,1, 30,5,1, 31,5,1, 31,4,1
    db 35,3,4, 36,3,4, 37,3,4, 38,3,4, 39,3,4, 40,3,4, 40,4,4, 40,5,4, 27,10,2, 28,10,2, 29,10,2, 30,10,2
    db 31,10,2, 32,10,2, 33,10,2, 34,10,2, 35,10,2, 36,10,2, 37,10,2, 38,10,2, 39,10,2, 40,10,2, 40,9,2, 40,8,2
    db 40,7,2, 44,6,5, 45,6,5, 46,6,5, 47,6,5, 48,6,5, 49,6,5
circ_A_out db 5
circ_C_torches db 3, 24,1, 24,5, 24,10
circ_C_gates db 3, 0,1,33,3, 2,255,33,10, 4,5,42,6
circ_C_wires dw 40
    db 27,1,0, 28,1,0, 29,1,0, 30,1,0, 31,1,0, 31,2,0, 27,5,1, 28,5,1, 29,5,1, 30,5,1, 31,5,1, 31,4,1
    db 27,10,2, 28,10,2, 29,10,2, 30,10,2, 31,10,2, 35,3,4, 36,3,4, 37,3,4, 38,3,4, 39,3,4, 40,3,4, 40,4,4
    db 40,5,4, 35,10,5, 36,10,5, 37,10,5, 38,10,5, 39,10,5, 40,10,5, 40,9,5, 40,8,5, 40,7,5, 44,6,6, 45,6,6
    db 46,6,6, 47,6,6, 48,6,6, 49,6,6
circ_C_out db 6
circ_B_torches db 4, 24,0, 24,4, 24,8, 24,12
circ_B_gates db 3, 0,1,33,2, 2,3,33,10, 4,5,42,6
circ_B_wires dw 48
    db 27,0,0, 28,0,0, 29,0,0, 30,0,0, 31,0,0, 31,1,0, 27,4,1, 28,4,1, 29,4,1, 30,4,1, 31,4,1, 31,3,1
    db 27,8,2, 28,8,2, 29,8,2, 30,8,2, 31,8,2, 31,9,2, 27,12,3, 28,12,3, 29,12,3, 30,12,3, 31,12,3, 31,11,3
    db 35,2,4, 36,2,4, 37,2,4, 38,2,4, 39,2,4, 40,2,4, 40,3,4, 40,4,4, 40,5,4, 35,10,5, 36,10,5, 37,10,5
    db 38,10,5, 39,10,5, 40,10,5, 40,9,5, 40,8,5, 40,7,5, 44,6,6, 45,6,6, 46,6,6, 47,6,6, 48,6,6, 49,6,6
circ_B_out db 6
circ_S_torches db 4, 8,2, 8,10, 40,2, 40,10
circ_S_gates db 3, 0,1,16,6, 3,2,34,6, 4,5,25,6
circ_S_wires dw 40
    db 11,2,0, 12,2,0, 13,2,0, 14,2,0, 14,3,0, 14,4,0, 14,5,0, 11,10,1, 12,10,1, 13,10,1, 14,10,1, 14,9,1
    db 14,8,1, 14,7,1, 39,2,2, 38,2,2, 37,2,2, 36,2,2, 36,3,2, 36,4,2, 36,5,2, 39,10,3, 38,10,3, 37,10,3
    db 36,10,3, 36,9,3, 36,8,3, 36,7,3, 18,6,4, 19,6,4, 20,6,4, 21,6,4, 22,6,4, 23,6,4, 32,6,5, 31,6,5
    db 30,6,5, 29,6,5, 28,6,5, 27,6,5
circ_S_out db 6
circ_Y_torches db 4, 8,1, 40,1, 8,11, 40,11
circ_Y_gates db 2, 1,0,25,3, 2,3,25,9
circ_Y_wires dw 56
    db 11,1,0, 12,1,0, 13,1,0, 14,1,0, 15,1,0, 16,1,0, 17,1,0, 18,1,0, 19,1,0, 20,1,0, 21,1,0, 22,1,0
    db 23,1,0, 24,1,0, 39,1,1, 38,1,1, 37,1,1, 36,1,1, 35,1,1, 34,1,1, 33,1,1, 32,1,1, 31,1,1, 30,1,1
    db 29,1,1, 28,1,1, 27,1,1, 26,1,1, 11,11,2, 12,11,2, 13,11,2, 14,11,2, 15,11,2, 16,11,2, 17,11,2, 18,11,2
    db 19,11,2, 20,11,2, 21,11,2, 22,11,2, 23,11,2, 24,11,2, 39,11,3, 38,11,3, 37,11,3, 36,11,3, 35,11,3, 34,11,3
    db 33,11,3, 32,11,3, 31,11,3, 30,11,3, 29,11,3, 28,11,3, 27,11,3, 26,11,3
circ_Y_out db 4
circ_K_torches db 4, 8,0, 8,4, 8,8, 8,12
circ_K_gates db 3, 0,1,17,2, 2,3,17,10, 4,5,26,6
circ_K_wires dw 48
    db 11,0,0, 12,0,0, 13,0,0, 14,0,0, 15,0,0, 15,1,0, 11,4,1, 12,4,1, 13,4,1, 14,4,1, 15,4,1, 15,3,1
    db 11,8,2, 12,8,2, 13,8,2, 14,8,2, 15,8,2, 15,9,2, 11,12,3, 12,12,3, 13,12,3, 14,12,3, 15,12,3, 15,11,3
    db 19,2,4, 20,2,4, 21,2,4, 22,2,4, 23,2,4, 24,2,4, 24,3,4, 24,4,4, 24,5,4, 19,10,5, 20,10,5, 21,10,5
    db 22,10,5, 23,10,5, 24,10,5, 24,9,5, 24,8,5, 24,7,5, 28,6,6, 29,6,6, 30,6,6, 31,6,6, 32,6,6, 33,6,6
circ_K_out db 6
circTorchTab dd circ_A_torches, circ_C_torches, circ_B_torches, circ_S_torches, circ_Y_torches, circ_K_torches
circGateTab dd circ_A_gates, circ_C_gates, circ_B_gates, circ_S_gates, circ_Y_gates, circ_K_gates
circWireTab dd circ_A_wires, circ_C_wires, circ_B_wires, circ_S_wires, circ_Y_wires, circ_K_wires
circOutTab dd circ_A_out, circ_C_out, circ_B_out, circ_S_out, circ_Y_out, circ_K_out
CT_A equ 0
CT_C equ 1
CT_B equ 2
CT_S equ 3
CT_Y equ 4
CT_K equ 5
; ===== end circuits.inc =====

msgCirc db "CIRCUIT - power the wire that runs to the door."
msgCirclen equ $- msgCirc
msgCircHid db "CIRCUIT - power the door. The ? gate: "
msgCircHidlen equ $- msgCircHid

section .bss
circNT  resd 1                  ; torches
circTX  resb 4
circTY  resb 4
circNG  resd 1                  ; gates
circGA  resb 3                  ; first input (node number)
circGB  resb 3                  ; second input, 255 = NOT gate
circGX  resb 3                  ; centre of its 3x3 block
circGY  resb 3
circGT  resb 3                  ; gate type 0..5, 6 = NOT
circNW  resd 1                  ; wire cells
circWD  resd 1                  ; address of the wire cells: x, y, node
circOutNode resd 1
circHidden resd 1               ; gate number shown as "?", -1 = none, -2 = every gate (the King's last phase)
circVal resb 8                  ; the value on every node: 0..3 torches, 4..6 gates
circOut resd 1                  ; the value reaching the door
circTry resd 1
circCombo resd 1
circSols resd 1
cdI resd 1
cdJ resd 1

section .text

; ---------------------------------------------------------------------
; set up a circuit room
; ---------------------------------------------------------------------
setup_circuit:
    pushad
    mov dword [puzzleOn], 2
    mov dword [doorOpen], 0
    mov dword [circHidden], -1
    mov eax, CT_A                   ; which layout
    cmp dword [floorCount], 20
    jle .load
    mov eax, 2
    call rand_mod
    cmp dword [floorCount], 24
    jle .ac
    test eax, eax                   ; floors 25+: B or C
    mov eax, CT_B
    jz .load
    mov eax, CT_C
    jmp .load
.ac:
    test eax, eax                   ; floors 21-24: A or C
    mov eax, CT_A
    jz .load
    mov eax, CT_C
.load:
    call circ_load
    jmp circ_pick_types

circ_load:                          ; eax = layout number: copy its torches, gates and wires   (keeps eax)
    pushad
    mov esi, [circTorchTab+eax*4]   ; torches: count, then x,y
    movzx ecx, byte [esi]
    mov [circNT], ecx
    xor edx, edx
.lt:
    cmp edx, ecx
    jge .lg
    mov bl, [esi+1+edx*2]
    mov [circTX+edx], bl
    mov bl, [esi+2+edx*2]
    mov [circTY+edx], bl
    inc edx
    jmp .lt
.lg:
    mov esi, [circGateTab+eax*4]    ; gates: count, then inA, inB, cx, cy
    movzx ecx, byte [esi]
    mov [circNG], ecx
    xor edx, edx
.lg2:
    cmp edx, ecx
    jge .lw
    mov bl, [esi+1+edx*4]
    mov [circGA+edx], bl
    mov bl, [esi+2+edx*4]
    mov [circGB+edx], bl
    mov bl, [esi+3+edx*4]
    mov [circGX+edx], bl
    mov bl, [esi+4+edx*4]
    mov [circGY+edx], bl
    inc edx
    jmp .lg2
.lw:
    mov esi, [circWireTab+eax*4]    ; wires: count (word), then x, y, node
    movzx ecx, word [esi]
    mov [circNW], ecx
    add esi, 2
    mov [circWD], esi
    mov esi, [circOutTab+eax*4]
    movzx ecx, byte [esi]
    mov [circOutNode], ecx
    popad
    ret

circ_pick_types:                    ; (still inside setup_circuit's pushad)
    ; pick gate types until the circuit is solvable, but not by most inputs
    mov dword [circTry], 300
.types:
    xor edx, edx
.gt:
    cmp edx, [circNG]
    jge .count
    mov byte [circGT+edx], GT_NOT
    cmp byte [circGB+edx], 255
    je .gn
    push edx
    mov eax, GATE_COUNT
    call rand_mod
    pop edx
    mov [circGT+edx], al
.gn:
    inc edx
    jmp .gt
.count:                             ; try every torch setting, count the ones that open the door
    mov dword [circSols], 0
    mov dword [circCombo], 0
.cl:
    mov ecx, [circNT]
    mov eax, 1
    shl eax, cl
    cmp [circCombo], eax
    jge .judge
    xor edx, edx
.cb:
    cmp edx, [circNT]
    jge .ce
    mov eax, [circCombo]
    mov ecx, edx
    shr eax, cl
    and al, 1
    mov [nodeBit+edx], al
    inc edx
    jmp .cb
.ce:
    call circ_eval
    mov eax, [circOut]
    add [circSols], eax
    inc dword [circCombo]
    jmp .cl
.judge:
    dec dword [circTry]
    jz .start                       ; (give up being picky)
    cmp dword [circSols], 0
    je .types                       ; nothing opens it
    mov ecx, [circNT]
    mov eax, 1
    shl eax, cl
    shr eax, 1
    cmp [circSols], eax
    jg .types                       ; too easy: more than half of all settings work
.start:                             ; a random starting setting that does NOT open the door
    mov dword [circTry], 100
.st:
    xor edx, edx
.sb:
    cmp edx, [circNT]
    jge .se
    push edx
    mov eax, 2
    call rand_mod
    pop edx
    mov [nodeBit+edx], al
    inc edx
    jmp .sb
.se:
    call circ_eval
    cmp dword [circOut], 0
    je .hide
    dec dword [circTry]
    jnz .st
.hide:
    cmp dword [floorCount], 25      ; floors 25+: one gate (not the NOT) is hidden
    jl .done
.hp:
    mov eax, [circNG]
    call rand_mod
    cmp byte [circGB+eax], 255
    je .hp
    mov [circHidden], eax
.done:
    call circ_eval
    popad
    ret

; ---------------------------------------------------------------------
; run the signals through the circuit
; ---------------------------------------------------------------------
circ_eval:
    pushad
    xor ecx, ecx
.t: cmp ecx, [circNT]
    jge .g
    mov al, [nodeBit+ecx]
    mov [circVal+ecx], al
    inc ecx
    jmp .t
.g: xor ecx, ecx
.gl:
    cmp ecx, [circNG]
    jge .out
    movzx ebx, byte [circGA+ecx]
    movzx eax, byte [circVal+ebx]   ; a
    movzx edx, byte [circGT+ecx]
    cmp edx, GT_NOT
    jne .two
    xor al, 1                       ; NOT a
    jmp .set
.two:
    movzx ebx, byte [circGB+ecx]
    movzx ebx, byte [circVal+ebx]   ; b
    shl eax, 1
    or eax, ebx                     ; a*2 + b: the row of the truth table
    cmp edx, GT_LANTERN
    jne .tt
    xor edx, edx                    ; the lantern is an AND
.tt:
    movzx edx, byte [gateTruth+edx]
    bt edx, eax
    setc al
.set:
    mov [circVal+4+ecx], al
    inc ecx
    jmp .gl
.out:
    mov ebx, [circOutNode]
    movzx eax, byte [circVal+ebx]
    mov [circOut], eax
    popad
    ret

; ---------------------------------------------------------------------
; what is where
; ---------------------------------------------------------------------
circ_find_gate:                     ; eax=x, ebx=y -> ecx = gate on that cell or -1, edx = 1 on its centre   (keeps eax, ebx)
    xor ecx, ecx
.l: cmp ecx, [circNG]
    jge .none
    movzx edx, byte [circGX+ecx]
    sub edx, eax
    cmp edx, -1
    jl .n
    cmp edx, 1
    jg .n
    movzx edx, byte [circGY+ecx]
    sub edx, ebx
    cmp edx, -1
    jl .n
    cmp edx, 1
    jg .n
    movzx edx, byte [circGX+ecx]    ; centre?
    cmp edx, eax
    jne .edge
    movzx edx, byte [circGY+ecx]
    cmp edx, ebx
    jne .edge
    mov edx, 1
    ret
.edge:
    xor edx, edx
    ret
.n: inc ecx
    jmp .l
.none:
    mov ecx, -1
    ret

circ_gate_obstacle:                 ; eax=x, ebx=y -> CF=1 on a gate   (keeps everything)
    push ecx
    push edx
    call circ_find_gate
    cmp ecx, -1
    pop edx
    pop ecx
    je .no
    stc
    ret
.no:
    clc
    ret

circ_glyph:                         ; eax=x, ebx=y -> al = the circuit's character there, or 0   (keeps ebx, esi, edi)
    push esi
    push edi
    push ecx
    push edx
    call circ_find_gate
    cmp ecx, -1
    je .wires
    test edx, edx
    jz .border
    movzx edx, byte [circGT+ecx]
    cmp edx, GT_LANTERN
    je .letter                      ; the lantern is never hidden
    push eax
    mov eax, SP_REVEAL              ; the Truth Amulet shows hidden gates
    call has_special
    pop eax
    jc .letter
    cmp ecx, [circHidden]
    mov al, '?'
    je .out
    cmp dword [circHidden], -2
    je .out
.letter:
    mov al, [gateLetter+edx]
    jmp .out
.border:
    cmp byte [circGT+ecx], GT_LANTERN
    jne .bv
    cmp dword [lanternT], 0
    mov al, '$'
    jne .out                        ; the lantern stays lit for its rounds
.bv:
    cmp byte [circVal+4+ecx], 0
    mov al, '%'
    je .out
    mov al, '$'
    jmp .out
.wires:
    mov esi, [circWD]
    xor ecx, ecx
.wl:
    cmp ecx, [circNW]
    jge .none
    lea edi, [ecx+ecx*2]
    cmp al, [esi+edi]               ; x (eax < 256 here)
    jne .wn
    cmp bl, [esi+edi+1]             ; y
    jne .wn
    movzx edx, byte [esi+edi+2]     ; the node this wire carries
    mov dl, [circVal+edx]           ; dl = its value
    xor dh, dh                      ; dh = 1 if it runs up/down here
    test ecx, ecx
    jz .nx
    cmp al, [esi+edi-3]             ; the previous cell of the same wire has the same x: vertical
    jne .nx
    mov ah, [esi+edi-1]
    cmp ah, [esi+edi+2]
    jne .nx
    mov dh, 1
.nx:
    push ecx
    inc ecx
    cmp ecx, [circNW]
    pop ecx
    jge .pick
    mov al, [esi+edi]
    cmp al, [esi+edi+3]             ; the next cell of the same wire has the same x: vertical
    jne .pick
    mov ah, [esi+edi+5]
    cmp ah, [esi+edi+2]
    jne .pick
    mov dh, 1
.pick:
    test dh, dh
    jnz .vert
    mov al, '-'
    test dl, dl
    jz .out
    mov al, '='
    jmp .out
.vert:
    mov al, ':'
    test dl, dl
    jz .out
    mov al, '|'
    jmp .out
.wn:
    inc ecx
    jmp .wl
.none:
    xor al, al
.out:
    pop edx
    pop ecx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
circ_cell:                          ; eax=x, ebx=y: draw whatever belongs there
    pushad
    call cell_glyph
    call put_cell
    popad
    ret

circ_draw:                          ; every torch, gate and wire
    pushad
    mov dword [cdI], 0
.t: mov ecx, [cdI]
    cmp ecx, [circNT]
    jge .g0
    movzx eax, byte [circTX+ecx]
    movzx ebx, byte [circTY+ecx]
    call circ_cell
    inc eax
    call circ_cell
    inc eax
    call circ_cell
    inc dword [cdI]
    jmp .t
.g0:
    mov dword [cdI], 0
.g: mov ecx, [cdI]
    cmp ecx, [circNG]
    jge .w0
    mov dword [cdJ], 0
.gc:
    mov ecx, [cdI]
    mov eax, [cdJ]
    cmp eax, 9
    jge .gn
    xor edx, edx
    mov esi, 3
    div esi                         ; eax = row 0..2, edx = column 0..2
    movzx ebx, byte [circGY+ecx]
    lea ebx, [ebx+eax-1]
    movzx eax, byte [circGX+ecx]
    lea eax, [eax+edx-1]
    call circ_cell
    inc dword [cdJ]
    jmp .gc
.gn:
    inc dword [cdI]
    jmp .g
.w0:
    mov dword [cdI], 0
.w: mov ecx, [cdI]
    cmp ecx, [circNW]
    jge .d
    mov esi, [circWD]
    lea edi, [ecx+ecx*2]
    movzx eax, byte [esi+edi]
    movzx ebx, byte [esi+edi+1]
    call circ_cell
    inc dword [cdI]
    jmp .w
.d: popad
    ret

; ---------------------------------------------------------------------
; the plaque
; ---------------------------------------------------------------------
circ_plaque:
    pushad
    call msg_begin
    cmp dword [circHidden], -1
    jne .hid
    mov esi, msgCirc
    mov ecx, msgCirclen
    call msg_text
    jmp .e
.hid:
    mov esi, msgCircHid
    mov ecx, msgCircHidlen
    call msg_text
    mov eax, [circHidden]           ; the riddle of the hidden gate, without its name
    movzx eax, byte [circGT+eax]
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN
.trim:
    cmp byte [esi+ecx-1], ' '
    jne .skip
    dec ecx
    jmp .trim
.skip:
    cmp byte [esi], '-'             ; skip "XOR - "
    je .past
    inc esi
    dec ecx
    jmp .skip
.past:
    add esi, 2
    sub ecx, 2
    call msg_text
.e: call msg_end
    popad
    ret
; ===== end circuit.inc =====
; ===== end room.inc =====
; ===== begin enemies.inc =====
; =====================================================================
; enemies.inc  -  enemy types from the stat table in game_assets.asm
;                 (goblin, skeleton, orc, the Warden mini boss, the Forgotten King),
;                 bodies bigger than one cell, and how they fight.
;
; Every enemy has a TYPE (enemyType[]). Its row in enemyTable says its HP, damage,
; attack bonus, range, speed and size; enemySprites says how it looks.
; A big enemy's position (enemyX/enemyY) is its TOP-LEFT cell.
; =====================================================================

section .data
ignoreE dd -1                   ; enemy_at skips this enemy (used while one checks its own new spot)
msgHitsYou db " hits you for "
msgHitsYoulen equ $- msgHitsYou
msgMisses db " misses"
msgMisseslen equ $- msgMisses
msgComma db ", "

section .bss
enemyType resd MAX_ENEMIES
ew   resd 1                     ; scratch: width / height of the enemy being worked on
eh   resd 1
emx  resd 1
emy  resd 1
rx   resd 1                     ; redraw_area's rectangle
ry   resd 1
rw   resd 1
rh   resd 1
spType resd 1
hitMask resd 1                  ; enemies a spell dart already hit (so a big one isn't hit once per cell)
atkCount resd 1                 ; attackers listed so far this enemy turn
forceDrop resd 1                ; 1 = the next drop_loot always drops (bosses)
stX  resd 1                     ; enemy_try_step: where it was and where it wanted to go
stY  resd 1
stNX resd 1
stNY resd 1

section .text

enemy_rec:                      ; ecx = enemy number -> esi = its row in enemyTable   (keeps everything else)
    push eax
    mov eax, [enemyType+ecx*4]
    imul esi, eax, ENEMY_SIZE
    add esi, enemyTable
    pop eax
    ret

enemy_at:                       ; eax=x, ebx=y -> eax = the enemy covering that cell, or -1   (clobbers ecx)
    push edx
    push esi
    push edi
    mov edx, eax
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .none
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    cmp ecx, [ignoreE]
    je .n
    call enemy_rec
    mov eax, edx                ; inside its columns?
    sub eax, [enemyX+ecx*4]
    js .n
    movzx edi, byte [esi+ENEMY_W]
    cmp eax, edi
    jge .n
    mov eax, ebx                ; inside its rows?
    sub eax, [enemyY+ecx*4]
    js .n
    movzx edi, byte [esi+ENEMY_H]
    cmp eax, edi
    jge .n
    mov eax, ecx
    jmp .out
.n: inc ecx
    jmp .l
.none:
    mov eax, -1
.out:
    pop edi
    pop esi
    pop edx
    ret

dist_to_player:                 ; ecx = enemy number -> eax = steps from you to its NEAREST cell   (clobbers ebx)
    push esi
    push edx
    call enemy_rec
    mov eax, [playerX]
    sub eax, [enemyX+ecx*4]     ; you - its left edge
    js .xneg                    ; you are to its left
    movzx edx, byte [esi+ENEMY_W]
    dec edx
    sub eax, edx                ; you - its right edge
    jg .xok                     ; you are to its right
    xor eax, eax                ; you are level with one of its columns
    jmp .xok
.xneg:
    neg eax
.xok:
    mov ebx, [playerY]
    sub ebx, [enemyY+ecx*4]
    js .yneg
    movzx edx, byte [esi+ENEMY_H]
    dec edx
    sub ebx, edx
    jg .yok
    xor ebx, ebx
    jmp .yok
.yneg:
    neg ebx
.yok:
    cmp eax, ebx
    jge .r
    mov eax, ebx
.r: pop edx
    pop esi
    ret

enemy_cell_char:                ; ecx = enemy, eax = column, ebx = row inside its body -> dl = that character
    push eax
    push ebx
    push esi
    call enemy_rec
    movzx esi, byte [esi+ENEMY_W]
    imul ebx, esi               ; row * width
    add ebx, eax                ; + column
    mov esi, [enemyType+ecx*4]
    call boss_sprite            ; its sprite (a broken ward or a rage changes some bosses' look)
    mov dl, [esi+ebx]
    pop esi
    pop ebx
    pop eax
    ret

draw_enemy:                     ; ecx = enemy: draw every cell of its body (nothing if it is dead)
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    ret
.alive:
    pushad
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    mov [ew], eax
    movzx eax, byte [esi+ENEMY_H]
    mov [eh], eax
    xor ebx, ebx
.y: cmp ebx, [eh]
    jge .d
    xor eax, eax
.x: cmp eax, [ew]
    jge .ny
    call enemy_cell_char        ; dl
    push eax
    push ebx
    add eax, [enemyX+ecx*4]
    add ebx, [enemyY+ecx*4]
    call put_cell
    pop ebx
    pop eax
    inc eax
    jmp .x
.ny:
    inc ebx
    jmp .y
.d: popad
    ret

redraw_area:                    ; put back whatever belongs on the cells [rx],[ry] .. +[rw]-1,+[rh]-1
    pushad
    xor ebx, ebx
.y: cmp ebx, [rh]
    jge .d
    xor ecx, ecx
.x: cmp ecx, [rw]
    jge .ny
    push ebx
    mov eax, [rx]
    add eax, ecx
    add ebx, [ry]
    cmp eax, GRID_W
    jae .skip
    cmp ebx, GRID_H
    jae .skip
    call cell_glyph             ; keeps eax, ebx, ecx
    call put_cell
.skip:
    pop ebx
    inc ecx
    jmp .x
.ny:
    inc ebx
    jmp .y
.d: popad
    ret

set_area_to_enemy:              ; ecx = enemy -> [rx],[ry],[rw],[rh] = its body
    push esi
    push eax
    call enemy_rec
    mov eax, [enemyX+ecx*4]
    mov [rx], eax
    mov eax, [enemyY+ecx*4]
    mov [ry], eax
    movzx eax, byte [esi+ENEMY_W]
    mov [rw], eax
    movzx eax, byte [esi+ENEMY_H]
    mov [rh], eax
    pop eax
    pop esi
    ret

enemy_rooted:                   ; ecx = enemy -> CF=1 if it must never leave its place   (keeps all)
    push esi
    call enemy_rec
    cmp byte [esi+ENEMY_MOVE], 1    ; speed 0 (the bishops, the Forgotten King, the Unbound's bishop form): CF=1
    pop esi
    ret

enemy_move_to:                  ; move enemy [eI] so its top-left is at [nX],[nY] - only if its WHOLE body fits there
    mov ecx, [eI]
    call enemy_rooted           ; the bishops and the King on his throne never move
    jc .no
    mov eax, [nX]
    cmp eax, [enemyX+ecx*4]
    jne .check
    mov eax, [nY]
    cmp eax, [enemyY+ecx*4]
    je .no                      ; not actually moving
.check:
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    mov [ew], eax
    movzx eax, byte [esi+ENEMY_H]
    mov [eh], eax
    mov [ignoreE], ecx          ; it may overlap its own old body
    mov dword [emy], 0
.yl:
    mov eax, [emy]
    cmp eax, [eh]
    jge .fits
    mov dword [emx], 0
.xl:
    mov eax, [emx]
    cmp eax, [ew]
    jge .ny
    mov eax, [nX]
    add eax, [emx]
    mov ebx, [nY]
    add ebx, [emy]
    cmp eax, GRID_W
    jae .blocked                ; (unsigned: also catches negatives)
    cmp ebx, GRID_H
    jae .blocked
    cmp eax, [playerX]
    jne .notyou
    cmp ebx, [playerY]
    je .blocked
.notyou:
    call obstacle_at            ; door, plaque, torches
    jc .blocked
    call enemy_at               ; another enemy
    cmp eax, -1
    jne .blocked
    inc dword [emx]
    jmp .xl
.ny:
    inc dword [emy]
    jmp .yl
.fits:
    mov dword [ignoreE], -1
    mov ecx, [eI]
    call set_area_to_enemy      ; remember where it was ...
    mov eax, [nX]
    mov [enemyX+ecx*4], eax     ; ... move it ...
    mov eax, [nY]
    mov [enemyY+ecx*4], eax
    call redraw_area            ; ... tidy the cells it left ...
    mov ecx, [eI]
    call draw_enemy             ; ... and draw it in its new place
    ret
.blocked:
    mov dword [ignoreE], -1
.no:
    ret

enemy_step_toward_player:       ; enemy [eI] takes one step toward you, finding the way round things (path.inc)
    mov ecx, [eI]
    call enemy_rec
    cmp byte [esi+ENEMY_W], 1
    jne .big
    cmp byte [esi+ENEMY_H], 1
    je .small
.big:                               ; a big body: route its top-left over every spot where it fits
    call pf_build_big
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    mov ebx, [enemyY+ecx*4]
    call pf_dist_at
    test edx, edx
    jz .stay                        ; you are already within its reach
    cmp edx, 255
    je .straight                    ; no way round (or it stands somewhere odd): old straight step
    call pf_next
    jc .straight
    mov [nX], eax
    mov [nY], ebx
    jmp enemy_move_to
.small:
    mov [pfIgnore], ecx
    mov dword [pfMeBlocks], 0
    mov eax, [playerX]
    mov ebx, [playerY]
    call pf_build
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    mov ebx, [enemyY+ecx*4]
    call pf_next
    jc .straight
    cmp eax, [playerX]              ; the next cell is you: it is already next to you
    jne .go
    cmp ebx, [playerY]
    je .stay
.go:
    mov [nX], eax
    mov [nY], ebx
    jmp enemy_move_to
.stay:
    ret
.straight:
    mov ecx, [eI]
    call enemy_rec
    movzx edx, byte [esi+ENEMY_W]
    shr edx, 1
    mov ebx, [playerX]
    sub ebx, edx
    mov eax, [enemyX+ecx*4]
    call step_toward
    mov [nX], eax
    mov ecx, [eI]
    call enemy_rec
    movzx edx, byte [esi+ENEMY_H]
    shr edx, 1
    mov ebx, [playerY]
    sub ebx, edx
    mov eax, [enemyY+ecx*4]
    call step_toward
    mov [nY], eax
    jmp enemy_try_step

enemy_try_step:                 ; move enemy [eI] to [nX],[nY]; if its body doesn't fit, try only the x step, then only the y step
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    mov [stX], eax
    mov eax, [enemyY+ecx*4]
    mov [stY], eax
    mov eax, [nX]
    mov [stNX], eax
    mov eax, [nY]
    mov [stNY], eax
    call enemy_move_to
    call .moved
    jnz .r
    mov eax, [stNX]             ; x only
    mov [nX], eax
    mov eax, [stY]
    mov [nY], eax
    call enemy_move_to
    call .moved
    jnz .r
    mov eax, [stX]              ; y only
    mov [nX], eax
    mov eax, [stNY]
    mov [nY], eax
    call enemy_move_to
.r: ret
.moved:                         ; ZF=0 if it has moved
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    cmp eax, [stX]
    jne .y
    mov eax, [enemyY+ecx*4]
    cmp eax, [stY]
.y: ret

draw_enemies:
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .d
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    call draw_enemy
.n: inc ecx
    jmp .l
.d: ret

redraw_enemy:                   ; enemy [eIdx] changed (hurt, got a status): redraw it and the panel
    pushad
    mov ecx, [eIdx]
    call draw_enemy
    call draw_panel
    popad
    ret

kill_enemy:                     ; enemy [eIdx] dies
    pushad
    mov ecx, [eIdx]
    cmp dword [enemyType+ecx*4], ETYPE_KING
    jne .real
    call king_fall              ; the King on his throne only pretends to die (bosses.inc)
    popad
    ret
.real:
    cmp dword [isUnbound], 0
    je .nu
    call unbound_kill           ; his copies and shadow Wardens (bosses.inc)
    jnc .him
    popad
    ret
.him:
    mov ecx, [eIdx]
.nu:
    cmp dword [enemyType+ecx*4], ETYPE_BISHOP
    jne .rk
    call bishop_kill_all        ; one shared pool: all four go together (bosses2.inc)
.rk:
    cmp dword [enemyType+ecx*4], ETYPE_KEEPER
    jne .rr
    call keeper2_kill_all       ; its Wardens fall with it
.rr:
    call set_area_to_enemy      ; (before it disappears: we need its size)
    call enemy_rec
    mov dword [enemyHP+ecx*4], 0
    call duo_check              ; Altair and Smo: the survivor takes the fallen one's power
    call xp_for_kill            ; experience (progress.inc)
    call boss_loot              ; bosses leave their legendary (bosses.inc)
    imul edi, ecx, STAT_STRIDE
    add edi, statusTimer
    xor eax, eax
    push ecx
    mov ecx, STAT_STRIDE
    cld
    rep stosb                   ; forget all its statuses
    pop ecx
    call redraw_area            ; its body is gone from the screen
    cmp byte [esi+ENEMY_BOSS], 0
    je .drop
    mov dword [forceDrop], 1    ; bosses always leave something behind
.drop:
    mov eax, [rx]
    mov ebx, [ry]
    call drop_loot
    mov dword [forceDrop], 0
    call draw_panel
    popad
    ret

; ---------------------------------------------------------------------
; filling a room
; ---------------------------------------------------------------------
roll_hp:                        ; ecx = enemy (type set) -> enemyHP = its HP roll, a little more on deeper floors
    push esi
    call enemy_rec
    movzx eax, byte [esi+ENEMY_HP_MAX]
    movzx ebx, byte [esi+ENEMY_HP_MIN]
    sub eax, ebx
    inc eax
    push ecx
    call rand_mod               ; keeps ebx
    pop ecx
    add eax, ebx
    mov ebx, [floorCount]       ; + (floor-1): deeper enemies are tougher
    dec ebx
    add eax, ebx
    cmp byte [esi+ENEMY_BOSS], 0
    je .hp
    cmp dword [floorCount], 9   ; bosses from floor 9 on: +25%
    jl .hp
    mov ebx, eax
    shr ebx, 2
    add eax, ebx
.hp:
    mov [enemyHP+ecx*4], eax
    pop esi
    ret

pick_normal_type:               ; -> eax = goblin / skeleton / orc, by this floor's odds
    mov ebx, 9                  ; tier: floor 1, floor 2, floors 3-6, 7+
    cmp dword [floorCount], 1
    jle .t
    mov ebx, 0
    cmp dword [floorCount], 2
    jle .t
    mov ebx, 3
    cmp dword [floorCount], 6
    jle .t
    mov ebx, 6
.t: push ebx
    mov eax, 10
    call rand_mod               ; 0..9
    pop ebx
    xor ecx, ecx
.l: movzx edx, byte [spawnOdds+ebx+ecx]
    cmp eax, edx
    jl .got
    sub eax, edx
    inc ecx
    cmp ecx, 2
    jl .l
.got:
    mov eax, ecx
    ret

spawn_enemies:
    xor ecx, ecx
.w: cmp ecx, MAX_ENEMIES
    jge .w2
    mov dword [enemyHP+ecx*4], 0
    inc ecx
    jmp .w
.w2:
    mov edi, statusTimer        ; clear every status timer
    xor eax, eax
    mov ecx, MAX_ENEMIES*STAT_STRIDE
    cld
    rep stosb
    cmp dword [bossRoom], 0
    je .normal
    jmp boss_spawn              ; a boss room: just the boss (or the pair), see bosses.inc
.normal:
    mov eax, 2
    call rand_mod
    add eax, 2                  ; floors 1-2: 2..3 enemies
    cmp dword [floorCount], 2
    jle .cnt
    inc eax                     ; floors 3-6: 3..4
    cmp dword [floorCount], 6
    jle .cnt
    inc eax                     ; floors 7-14: 4..5
    cmp dword [floorCount], 14
    jle .cnt
    inc eax                     ; floor 15 on: 5..6
.cnt:
    mov [spawnN], eax
    mov dword [spawnI], 0
.next:
    mov eax, [spawnI]
    cmp eax, [spawnN]
    jge .done
    mov dword [tries], 50
.try:
    dec dword [tries]
    jz .skip
    mov eax, 21
    call rand_mod
    add eax, 14                 ; x = 14..34: far enough to aim in peace, near enough for most spells
    mov [nX], eax
    mov eax, GRID_H
    call rand_mod
    mov [nY], eax
    mov eax, [nX]
    mov ebx, [nY]
    call enemy_at
    cmp eax, -1
    jne .try
    mov eax, [nX]
    mov ebx, [nY]
    call obstacle_at            ; not on a torch, gate, door or plaque
    jc .try
    call pick_normal_type
    mov ecx, [spawnI]
    mov [enemyType+ecx*4], eax
    mov eax, [nX]
    mov [enemyX+ecx*4], eax
    mov eax, [nY]
    mov [enemyY+ecx*4], eax
    call roll_hp
.skip:
    inc dword [spawnI]
    jmp .next
.done:
    ret

; ---------------------------------------------------------------------
; their attacks
; ---------------------------------------------------------------------
say_enemy_attack:               ; ecx = enemy, eax = damage (or -1 for a miss): adds "Orc hits you for 4" to this turn's line
    pushad
    mov [sayNum], eax
    cmp dword [atkCount], 0
    jne .more
    call msg_begin              ; first attacker this turn: start the line
    jmp .name
.more:
    mov esi, msgComma
    mov ecx, 2
    call msg_text
.name:
    inc dword [atkCount]
    mov ecx, [eI]
    mov eax, [enemyType+ecx*4]
    imul esi, eax, NAME_LEN
    add esi, enemyNames
    call print_name
    cmp dword [sayNum], -1
    je .miss
    mov esi, msgHitsYou
    mov ecx, msgHitsYoulen
    call msg_text
    mov eax, [sayNum]
    call msg_num
    jmp .e
.miss:
    mov esi, msgMisses
    mov ecx, msgMisseslen
    call msg_text
.e: popad
    ret

enemies_attack:                 ; end of the enemy turn: everyone in range attacks you (one line lists them all)
    mov dword [atkCount], 0
    cmp dword [hidden], 0       ; hiding mid-fight only works if nobody is within 3 cells
    je .seek
    call nearest_enemy_dist
    cmp eax, 3
    jg .seek
    mov dword [hidden], 0
    call draw_mana
.seek:
    cmp dword [hidden], 0
    jne .alive                  ; nobody can find a hidden rogue to hit
    mov dword [eI], 0
.l: mov ecx, [eI]
    cmp ecx, MAX_ENEMIES
    jge .done
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    imul ebx, ecx, STAT_STRIDE
    cmp byte [statusTimer+ebx+EFFECT_SLEEP], 0
    jne .n
    cmp byte [statusTimer+ebx+EFFECT_HOLD], 0
    jne .n
    cmp byte [statusTimer+ebx+EFFECT_BLIND], 0
    jne .n                      ; blind enemies swing at nothing
    cmp byte [statusTimer+ebx+EFFECT_PRONE], 0
    jne .n
    cmp byte [statusTimer+ebx+EFFECT_FRIGHT], 0
    jne .n                      ; frightened enemies don't dare
    call enemy_rec
    cmp dword [enemyType+ecx*4], ETYPE_YMIR
    jne .unb
    call ymir_act               ; Ymir casts spells instead
    jmp .n
.unb:
    cmp dword [enemyType+ecx*4], ETYPE_BISHOP
    jne .unb2
    call bishop_act                 ; the bishops' volley (bosses2.inc)
    jmp .n
.unb2:
    cmp dword [enemyType+ecx*4], ETYPE_UCOPY
    je .unbc                        ; (a copy of the Unbound King fights like him)
    cmp dword [enemyType+ecx*4], ETYPE_UNBOUND
    jne .plain
.unbc:
    call unbound_act            ; the Unbound King may strike several times
    jmp .n
.plain:
    call dist_to_player
    movzx edx, byte [esi+ENEMY_RANGE]
    cmp eax, edx
    jg .n                       ; out of its reach
    movzx ebx, byte [esi+ENEMY_ATK_BONUS]
    mov edx, [floorCount]       ; deeper enemies hit more often: +1 to hit every 4 floors from floor 8
    sub edx, 4
    jns .fh
    xor edx, edx
.fh:
    shr edx, 2
    add ebx, edx
    add ebx, [empowered+ecx*4]  ; empowered (Altair / Smo): +2 to hit
    add ebx, [empowered+ecx*4]
    call enemy_hit_roll         ; d20 + its bonus against your armor class
    jc .miss
    mov ecx, [eI]
    call enemy_rec
    movzx eax, byte [esi+ENEMY_DMG_MAX]
    movzx ebx, byte [esi+ENEMY_DMG_MIN]
    sub eax, ebx
    inc eax
    call rand_mod               ; keeps ebx
    add eax, ebx                ; min .. max
    call first_warden_softer    ; the floor 4 Warden hits for 3/4 (bosses.inc)
    mov edx, [floorCount]       ; deeper enemies hit harder: + (floor-2)/3, so from floor 5
    sub edx, 2
    jns .fd
    xor edx, edx
.fd:
    push eax
    mov eax, edx
    xor edx, edx
    mov ecx, 3
    div ecx
    mov edx, eax
    pop eax
    add eax, edx
    cmp dword [floorCount], 9   ; bosses from floor 9 on: +25%
    jl .nb
    mov ecx, [eI]
    push esi
    call enemy_rec
    cmp byte [esi+ENEMY_BOSS], 0
    pop esi
    je .nb
    mov edx, eax
    shr edx, 2
    add eax, edx
.nb:
    mov edx, [eI]
    imul edx, [empowered+edx*4], 3
    add eax, edx                ; empowered: +3 damage
    call absorb_damage          ; Parry and Rally soak it first
    sub [playerHP], eax
    mov ecx, [eI]
    call say_enemy_attack
    mov eax, 1
    call attack_note            ; the window animates arrows, lightning, slams (path.inc)
    jmp .n
.miss:
    mov ecx, [eI]
    mov eax, -1
    call say_enemy_attack
    xor eax, eax
    call attack_note
.n: inc dword [eI]
    jmp .l
.done:
    cmp dword [atkCount], 0
    je .chk
    call msg_end                ; finish the line
.chk:
    cmp dword [playerHP], 0
    jg .alive
    mov dword [playerHP], 0
    call draw_hp
    msg msgDead
    jmp quit
.alive:
    call draw_hp
    ret

; ---------------------------------------------------------------------
; the enemy panel: "O1 HP: 14 sz"
; ---------------------------------------------------------------------
draw_panel:                     ; the enemy list: two per row, 12 columns each ("G1  15 zb"), rows 2..4 - fits 80 columns
    pushad
    mov dword [pi], 0
.l: mov eax, [pi]
    cmp eax, MAX_ENEMIES
    jge .d
    xor ecx, ecx
.f: mov byte [panelBuf+ecx], ' '
    inc ecx
    cmp ecx, 12
    jl .f
    mov ecx, [pi]
    cmp dword [enemyHP+ecx*4], 0
    jle .w
    mov eax, [enemyType+ecx*4]
    mov esi, [enemySprites+eax*4]
    mov al, [esi]               ; its letter
    mov [panelBuf], al
    mov al, cl
    add al, '1'
    mov [panelBuf+1], al
    mov eax, [enemyHP+ecx*4]    ; up to 3 digits, right-aligned in columns 3..5
    mov ebx, 10
    xor edx, edx
    div ebx
    add dl, '0'
    mov [panelBuf+5], dl
    test eax, eax
    jz .s0
    xor edx, edx
    div ebx
    add dl, '0'
    mov [panelBuf+4], dl
    test eax, eax
    jz .s0
    add al, '0'
    mov [panelBuf+3], al
.s0:
    mov dword [pj], 1
    mov dword [pk], 7           ; statuses in columns 7..11
.s: cmp dword [pk], 12
    jge .w
    imul ebx, [pi], STAT_STRIDE
    add ebx, [pj]
    cmp byte [statusTimer+ebx], 0
    je .sn
    mov ecx, [pj]
    mov al, [statusLetters+ecx]
    test al, al
    jz .sn
    mov ecx, [pk]
    mov [panelBuf+ecx], al
    inc dword [pk]
.sn: inc dword [pj]
    cmp dword [pj], LAST_STATUS
    jle .s
.w: mov eax, [pi]                ; enemy i: row 2 + i/2, column 56 or 68
    shr eax, 1
    add eax, 2
    mov ebx, [pi]
    and ebx, 1
    imul ebx, ebx, 12
    add ebx, PANEL_COL
    call goto_rc
    print_string panelBuf, 12
    inc dword [pi]
    jmp .l
.d: popad
    ret

wake_enemy:                     ; ecx = enemy: any damage wakes a sleeping enemy   (keeps every register and flag)
    pushfd
    push ebx
    imul ebx, ecx, STAT_STRIDE
    mov byte [statusTimer+ebx+EFFECT_SLEEP], 0
    pop ebx
    popfd
    ret
; ===== end enemies.inc =====
; ===== begin features.inc =====
; =====================================================================
; features.inc  -  inventory + equipment, loot, Battle Master fighter,
;                  stealth rogue
;
; Include it at the very END of game.asm:      %include "features.inc"
; It uses these things that already exist in the demo:
;   rand_mod  get_scaling_stat  dist_to_player  enemy_move_to  apply_status
;   kill_enemy  redraw_enemy  put_cell  goto_rc  name_to_buf  say_num  say_str
;   msg_begin  msg_text  msg_end  print_name  draw_hp  draw_movement
;   playerX playerY playerHP playerMaxHP movementPoint dmg eIdx eI nX nY
;   enemyX enemyY enemyHP statusTimer statusDur STAT_STRIDE MAX_ENEMIES
;   class dex strength   fixedname (macro from game_assets.asm)  menuBuf nameBuf mi
; =====================================================================

section .data

; ---------------------------------------------------------------------
; 1. CLASSES. A 4th class is one new bit. Your existing 3-bit masks stay valid.
; ---------------------------------------------------------------------
CLASS_FIGHTER equ 0b100
CLASS_ROGUE   equ 0b010
CLASS_WIZARD  equ 0b001
ALL_CLASSES   equ 0b111
; class '1','2','3'  ->  its bit
classBit db CLASS_FIGHTER, CLASS_ROGUE, CLASS_WIZARD


; ---------------------------------------------------------------------
; 2. ITEMS. One CATALOG lists every item in the game: its name, its record
;    (the weapon / armor / potion data you already wrote), its kind, and how
;    often it drops. The bag, the equipment and the loot all use catalog entries.
; ---------------------------------------------------------------------
ITEM_WEAPON equ 1
ITEM_ARMOR  equ 2
ITEM_POTION equ 3
ITEM_SCROLL equ 4                ; a wizard spell to learn; its 'record' is the spell number

ARMOR_BODY   equ 0b10000
ARMOR_SHIELD equ 0b01000
ARMOR_HELM   equ 0b00100
ARMOR_BOOTS  equ 0b00001
ARMOR_TRINKET equ 0b100000          ; rings and amulets: anyone can wear one
; (EFFECT_PRONE / FRIGHT / MARK and WEAPON_TWO_HANDED are in game_assets.asm)
WTYPE_RANGED equ 0b01

INV_MAX    equ 12
MAX_GROUND equ 8
SPOT_RANGE equ 3                 ; a hidden rogue can be spotted only this close (but never when adjacent)
SPOT_ODDS  equ 16                ; ... with a 1 in 16 chance per step
DROP_CHANCE equ 45               ; percent chance an enemy drops something

CAT_NAME   equ 0                 ; 16 bytes, zero padded
CAT_PTR    equ 16                ; address of the weapon / armor / potion record
CAT_KIND   equ 20
CAT_WEIGHT equ 21                ; loot weight, 0 = never drops
CAT_RARITY equ 22                ; 0 common, 1 rare, 2 legendary (bosses only)
CAT_FLOOR  equ 23                ; rare items only drop from this floor on
CAT_BSTR   equ 24                ; stat bonuses while worn: STR DEX CON INT (4 bytes)
CAT_BAC    equ 28                ; extra AC
CAT_BMANA  equ 29                ; extra max mana
CAT_SPECIAL equ 30               ; special power (SP_ numbers in progress.inc)
CAT_SPVAL  equ 31                ; ... and how strong it is
CAT_SIZE   equ 32

%macro catalog 5                 ; label, "Name", record, kind, weight   (a plain item)
%1:
    fixedname %2
    dd %3
    db %4, %5, 0, 0
    times 8 db 0
%endmacro
%macro catalogx 15               ; a special item: ... rarity, floor, STR, DEX, CON, INT, AC, mana, special, value
%1:
    fixedname %2
    dd %3
    db %4, %5, %6, %7
    db %8, %9, %10, %11, %12, %13, %14, %15
%endmacro

catalogTable:
    catalog cat_minor,        "Minor Potion",    minorPotion,   ITEM_POTION, 40
    catalog cat_reg,          "Potion",          regPotion,     ITEM_POTION, 25
    catalog cat_large,        "Large Potion",    largePotion,   ITEM_POTION, 10
    catalog cat_dagger,       "Dagger",          dagger,        ITEM_WEAPON, 10
    catalog cat_shortsword,   "Shortsword",      shortsword,    ITEM_WEAPON, 8
    catalog cat_longsword,    "Longsword",       longsword,     ITEM_WEAPON, 6
    catalog cat_rapier,       "Rapier",          rapier,        ITEM_WEAPON, 5
    catalog cat_quarterstaff, "Quarterstaff",    quarterstaff,  ITEM_WEAPON, 5
    catalog cat_greatsword,   "Greatsword",      greatsword,    ITEM_WEAPON, 2
    catalog cat_pike,         "Pike",            pike,          ITEM_WEAPON, 2
    catalog cat_shortbow,     "Shortbow",        shortbow,      ITEM_WEAPON, 6
    catalog cat_longbow,      "Longbow",         longbow,       ITEM_WEAPON, 3
    catalog cat_lightxbow,    "Light Crossbow",  lightcrossbow, ITEM_WEAPON, 4
    catalog cat_simplerobe,   "Simple Robe",     simplerobe,    ITEM_ARMOR,  6
    catalog cat_leather,      "Leather Armor",   leatherarmor,  ITEM_ARMOR,  8
    catalog cat_breastplate,  "Breastplate",     breastplate,   ITEM_ARMOR,  3
    catalog cat_buckler,      "Buckler",         buckler,       ITEM_ARMOR,  7
    catalog cat_shield,       "Shield",          shield,        ITEM_ARMOR,  4
    ; spell scrolls (weight 25 each): only drop for a wizard, and only spells it doesn't know yet
    ; (the number is the spell's position in the spell table: firebolt 0, fireball 1, ...)
    catalog scr_fireball,     "Fireball",         1, ITEM_SCROLL, 25
    catalog scr_missile,      "Magic Missile",    2, ITEM_SCROLL, 25
    catalog scr_scorch,       "Scorching Ray",    3, ITEM_SCROLL, 25
    catalog scr_misty,        "Misty Step",       4, ITEM_SCROLL, 25
    catalog scr_sleep,        "Sleep",            5, ITEM_SCROLL, 25
    catalog scr_hold,         "Hold Monster",     6, ITEM_SCROLL, 25
    catalog scr_haste,        "Haste",            7, ITEM_SCROLL, 25
    catalog scr_vampiric,     "Vampiric Touch",   9, ITEM_SCROLL, 25
    catalog scr_sunbeam,      "Sunbeam",         10, ITEM_SCROLL, 25
    catalog scr_icestorm,     "Ice Storm",       11, ITEM_SCROLL, 25
    catalog scr_cone,         "Cone of Cold",    12, ITEM_SCROLL, 25
; ===== begin items_cat.inc =====
; items_cat.inc - generated by items.py (catalog entries of the special items)
;          label, name, record, kind, weight, rarity, floor, STR, DEX, CON, INT, AC, mana, special, value
    catalogx cat_embersword, "Ember Blade", it_embersword, ITEM_WEAPON, 5, 1, 3, 1, 0, 0, 0, 0, 0, 0, 0
    catalogx cat_frostbite, "Frostbite", it_frostbite, ITEM_WEAPON, 5, 1, 3, 0, 2, 0, 0, 0, 0, 0, 0
    catalogx cat_venomrapier, "Venom Rapier", it_venomrapier, ITEM_WEAPON, 4, 1, 6, 0, 1, 0, 0, 0, 0, 0, 0
    catalogx cat_thundermaul, "Thunder Maul", it_thundermaul, ITEM_WEAPON, 3, 1, 10, 2, 0, 0, 0, 0, 0, 0, 0
    catalogx cat_emberwand, "Wand of Embers", it_emberwand, ITEM_WEAPON, 5, 1, 5, 0, 0, 0, 2, 0, 0, 3, 1
    catalogx cat_shadowweave, "Shadowweave", it_shadowweave, ITEM_ARMOR, 4, 1, 6, 0, 2, 0, 0, 0, 0, 4, 0
    catalogx cat_archrobe, "Archmage Robe", it_archrobe, ITEM_ARMOR, 4, 1, 6, 0, 0, 0, 2, 0, 1, 0, 0
    catalogx cat_drakemail, "Drakescale Mail", it_drakemail, ITEM_ARMOR, 3, 1, 9, 0, 0, 1, 0, 0, 0, 5, 2
    catalogx cat_spikebuckler, "Spiked Buckler", it_spikebuckler, ITEM_ARMOR, 4, 1, 5, 0, 0, 0, 0, 0, 0, 5, 2
    catalogx cat_mirrorshield, "Mirror Shield", it_mirrorshield, ITEM_ARMOR, 3, 1, 12, 0, 0, 0, 0, 0, 0, 6, 0
    catalogx cat_hornedhelm, "Horned Helm", it_hornedhelm, ITEM_ARMOR, 5, 1, 4, 1, 0, 0, 0, 0, 0, 0, 0
    catalogx cat_whisperhood, "Whisper Hood", it_whisperhood, ITEM_ARMOR, 4, 1, 7, 0, 1, 0, 0, 0, 0, 9, 1
    catalogx cat_stridingboots, "Striding Boots", it_stridingboots, ITEM_ARMOR, 5, 1, 4, 0, 0, 0, 0, 0, 0, 8, 2
    catalogx cat_scholarring, "Scholar's Ring", it_scholarring, ITEM_ARMOR, 5, 1, 2, 0, 0, 0, 1, 0, 0, 10, 3
    catalogx cat_lanterncharm, "Lantern Charm", it_lanterncharm, ITEM_ARMOR, 3, 1, 12, 0, 0, 1, 0, 0, 0, 17, 0
    catalogx cat_gatekey, "Gatekey Charm", it_gatekey, ITEM_ARMOR, 4, 1, 8, 0, 0, 0, 0, 0, 0, 16, 0
    catalogx cat_vigoramulet, "Amulet of Vigor", it_vigoramulet, ITEM_ARMOR, 4, 1, 10, 0, 0, 2, 0, 0, 0, 0, 0
    catalogx cat_gatebreaker, "Gatebreaker", it_gatebreaker, ITEM_WEAPON, 0, 2, 0, 2, 0, 0, 0, 0, 0, 2, 0
    catalogx cat_keyknife, "Keyknife", it_keyknife, ITEM_WEAPON, 0, 2, 0, 0, 2, 0, 0, 0, 0, 16, 0
    catalogx cat_gatestaff, "Staff of Gates", it_gatestaff, ITEM_WEAPON, 0, 2, 0, 0, 0, 0, 2, 0, 0, 16, 0
    catalogx cat_xoredge, "XOR Edge", it_xoredge, ITEM_WEAPON, 0, 2, 0, 1, 0, 1, 0, 0, 0, 0, 0
    catalogx cat_twinfang, "Twinfang", it_twinfang, ITEM_WEAPON, 0, 2, 0, 0, 2, 0, 0, 0, 0, 14, 0
    catalogx cat_circuitrod, "Circuit Rod", it_circuitrod, ITEM_WEAPON, 0, 2, 0, 0, 0, 0, 2, 0, 0, 12, 0
    catalogx cat_duskplate, "Duskplate", it_duskplate, ITEM_ARMOR, 0, 2, 0, 0, 0, 2, 0, 0, 0, 17, 0
    catalogx cat_shadefang, "Shade Fang", it_shadefang, ITEM_WEAPON, 0, 2, 0, 0, 2, 0, 0, 0, 0, 1, 0
    catalogx cat_umbralrobe, "Umbral Robe", it_umbralrobe, ITEM_ARMOR, 0, 2, 0, 0, 0, 0, 2, 0, 1, 3, 2
    catalogx cat_frostbrand, "Frostbrand", it_frostbrand, ITEM_WEAPON, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0
    catalogx cat_iciclebow, "Icicle Crossbow", it_iciclebow, ITEM_WEAPON, 0, 2, 0, 0, 2, 0, 0, 0, 0, 0, 0
    catalogx cat_rimestaff, "Rimefrost Staff", it_rimestaff, ITEM_WEAPON, 0, 2, 0, 0, 0, 0, 3, 0, 2, 15, 0
    catalogx cat_aegis, "Keeper's Aegis", it_aegis, ITEM_ARMOR, 0, 2, 0, 0, 0, 2, 0, 0, 0, 7, 0
    catalogx cat_keepercloak, "Keeper's Cloak", it_keepercloak, ITEM_ARMOR, 0, 2, 0, 0, 2, 0, 0, 0, 0, 6, 0
    catalogx cat_truthamulet, "Truth Amulet", it_truthamulet, ITEM_ARMOR, 0, 2, 0, 0, 0, 0, 2, 0, 1, 11, 0
    catalogx cat_stormspear, "Stormspear", it_stormspear, ITEM_WEAPON, 0, 2, 0, 1, 2, 0, 0, 0, 0, 0, 0
    catalogx cat_stormboots, "Stormstep Boots", it_stormboots, ITEM_ARMOR, 0, 2, 0, 0, 2, 0, 0, 0, 0, 8, 3
    catalogx cat_stormstaff, "Stormstaff", it_stormstaff, ITEM_WEAPON, 0, 2, 0, 0, 0, 0, 3, 0, 0, 3, 2
    catalogx cat_smomaul, "Smo's Maul", it_smomaul, ITEM_WEAPON, 0, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0
    catalogx cat_ironheart, "Ironheart", it_ironheart, ITEM_ARMOR, 0, 2, 0, 0, 0, 3, 0, 0, 0, 13, 1
    catalogx cat_heartstone, "Heartstone", it_heartstone, ITEM_ARMOR, 0, 2, 0, 0, 0, 2, 2, 0, 0, 13, 1
; ===== end items_cat.inc =====
CATALOG_COUNT equ ($ - catalogTable) / CAT_SIZE
; ===== begin items_loot.inc =====
; items_loot.inc - generated by items.py: the legendary each boss drops, for Fighter, Rogue, Wizard
bossLoot:
    dd cat_gatebreaker, cat_keyknife, cat_gatestaff   ; Warden (4)
    dd cat_xoredge, cat_twinfang, cat_circuitrod   ; Warden (8)
    dd cat_duskplate, cat_shadefang, cat_umbralrobe   ; Dark Shade
    dd cat_frostbrand, cat_iciclebow, cat_rimestaff   ; Ymir
    dd cat_aegis, cat_keepercloak, cat_truthamulet   ; Logic Keeper
    dd cat_stormspear, cat_stormboots, cat_stormstaff   ; Altair
    dd cat_smomaul, cat_ironheart, cat_heartstone   ; Smo
; ===== end items_loot.inc =====

; bare hands: used when no weapon is equipped (melee, any class, 1-2 damage, scales with STR)
fists db 0b10,0b111,1,2,0b1000,1,0,0

; armor each class can wear, by ARMOR_WEIGHT bits (Heavy|Medium|Light|Clothes), class order '1','2','3'
;   Fighter: everything, and shields.  Rogue: light armor.  Wizard: clothes only.
armorProf db 0b1111, 0b0011, 0b0001
msgNoArmor db "You aren't trained to wear that"
msgNoArmorlen equ $- msgNoArmor
msgNoShield db "Only a fighter is trained with shields"
msgNoShieldlen equ $- msgNoShield

; what each class starts with (weapon, armor), in class order '1','2','3'
startGear dd cat_longsword,  cat_breastplate    ; Fighter
          dd cat_rapier,     cat_leather        ; Rogue
          dd cat_quarterstaff, cat_simplerobe   ; Wizard

; ---------------------------------------------------------------------
; 3. BATTLE MASTER (fighter): superiority dice + maneuvers
; ---------------------------------------------------------------------
DICE_MAX equ 4                   ; 4 dice (d8), refilled when a fight ends
MAN_SWEEP  equ 1                 ; also hits a second adjacent enemy for the die roll
MAN_PUSH   equ 2                 ; + die damage, knocks the target back 3 cells
MAN_TRIP   equ 3                 ; + die damage, target is knocked prone (loses its turn)
MAN_MENACE equ 4                 ; + die damage, target is frightened (won't attack)
MAN_PARRY  equ 5                 ; reduces the next hit you take by die + STR/8
MAN_RALLY  equ 6                 ; temporary HP of die + STR/8
MAN_COUNT  equ 6

manNames:
    fixedname "Sweeping Attack"
    fixedname "Pushing Attack"
    fixedname "Trip Attack"
    fixedname "Menacing Attack"
    fixedname "Parry"
    fixedname "Rally"

; ---------------------------------------------------------------------
; messages
; ---------------------------------------------------------------------
msgBagFull db "Your bag is full"
msgBagFulllen equ $- msgBagFull
msgPicked  db "You pick up "
msgPickedlen equ $- msgPicked
msgHideMove db "Hiding costs 3 movement and you don't have it"
msgHideMovelen equ $- msgHideMove
msgNoHide  db "An enemy is too close to hide"
msgNoHidelen equ $- msgNoHide
msgHidden  db "You slip into the shadows"
msgHiddenlen equ $- msgHidden
msgSpotted db "You were spotted!"
msgSpottedlen equ $- msgSpotted
msgSurge   db "Action Surge! Two more attacks"
msgSurgelen equ $- msgSurge
msgNoDice  db "No superiority dice left"
msgNoDicelen equ $- msgNoDice
msgManSet  db "Maneuver ready: "
msgManSetlen equ $- msgManSet
msgParry   db "Parry ready: the next hit is reduced by "
msgParrylen equ $- msgParry
msgRally   db "Rally: temporary HP +"
msgRallylen equ $- msgRally
msgLearn   db "You learn "
msgLearnlen equ $- msgLearn
msgBang    db "!"
msgBanglen equ $- msgBang
msgWhich   db "Discard which item? Press its key (X cancels)"
msgWhichlen equ $- msgWhich
msgTossed  db "Item thrown away"
msgTossedlen equ $- msgTossed
msgKeep    db "Nothing thrown away"
msgKeeplen equ $- msgKeep
msgNoUse   db "You can't use that"
msgNoUselen equ $- msgNoUse
blank24    db "                        "

section .bss

; ---- bag, equipment, ground ----
inv         resd INV_MAX         ; catalog entry address, 0 = empty slot
equipWeapon resd 1               ; catalog entry address, 0 = fists
equipBody   resd 1
equipShield resd 1
equipHelm   resd 1
equipBoots  resd 1
equipTrinket resd 1
wornH resd 1
wornF resd 1
wornT resd 1
wornW resd 1                     ; which BAG SLOT holds each worn item (-1 = none), so copies don't get mixed up
wornB resd 1
wornS resd 1
playerAC    resd 1
moveMalus   resd 1               ; heavy armor takes movement points away
groundX     resd MAX_GROUND
groundY     resd MAX_GROUND
groundItem  resd MAX_GROUND      ; catalog entry address, 0 = free slot

; ---- class features ----
diceLeft    resd 1
pendingMan  resd 1               ; maneuver chosen for the next hit (0 = none)
attacksLeft resd 1               ; fighter 2, everybody else 1, per turn
tempHP      resd 1
parryBonus  resd 1
hidden      resd 1               ; rogue stealth
surgeUsed   resd 1

refuseMsg   resd 1               ; why equip_item said no: 0 generic, 1 armor training, 2 shield
discardMode resd 1               ; 1 = the next slot key throws that item away
bagOpen     resd 1               ; 1 = the right-hand panel shows the bag instead of the spells

; ---- spells a class can use (menu list) ----
spellList   resb 32
spellListN  resd 1

; ---- scratch ----
curSlot resd 1
gearIdx resd 1
curRec  resd 1
dropSlot resd 1
bossDrop resd 1                 ; the legendary the next drop_loot leaves (0 = roll)
dropX   resd 1
dropY   resd 1
pickSlot resd 1
nearD   resd 1
sweepDmg resd 1
dieVal  resd 1
pushLeft resd 1

section .text

; =====================================================================
; INVENTORY AND EQUIPMENT
; =====================================================================
add_item:                       ; esi = catalog entry -> eax = bag slot, or CF=1 if the bag is full
    xor ecx, ecx
.l: cmp ecx, INV_MAX
    jge .full
    cmp dword [inv+ecx*4], 0
    je .put
    inc ecx
    jmp .l
.put:
    mov [inv+ecx*4], esi
    mov eax, ecx
    clc
    ret
.full:
    stc
    ret

recalc_gear:                    ; armor class and movement penalty from what you wear
    call recalc_stats           ; your stats with gear (progress.inc)
    mov dword [moveMalus], 0
    mov ebx, 10                 ; unarmored AC
    mov ecx, 99                 ; DEX cap: none when unarmored
    mov esi, [equipBody]
    test esi, esi
    jz .shield
    mov esi, [esi+CAT_PTR]      ; the armor record
    movzx eax, byte [esi+ARMOR_AC]
    add ebx, eax
    movzx ecx, byte [esi+ARMOR_AC_DEX_MAX]
    movzx eax, byte [esi+ARMOR_MV_PENALTY]
    add [moveMalus], eax
.shield:
    mov esi, [equipShield]
    test esi, esi
    jz .dex
    mov esi, [esi+CAT_PTR]
    movzx eax, byte [esi+ARMOR_AC]
    add ebx, eax
    movzx eax, byte [esi+ARMOR_MV_PENALTY]
    add [moveMalus], eax
.dex:
    mov esi, [equipHelm]        ; helmet and boots
    test esi, esi
    jz .bt
    mov esi, [esi+CAT_PTR]
    movzx eax, byte [esi+ARMOR_AC]
    add ebx, eax
.bt:
    mov esi, [equipBoots]
    test esi, esi
    jz .ga
    mov esi, [esi+CAT_PTR]
    movzx eax, byte [esi+ARMOR_AC]
    add ebx, eax
.ga:
    add ebx, [gAC]
    mov eax, [dex]
    sub eax, 10
    sar eax, 1                  ; (DEX - 10) / 2
    jns .pos
    xor eax, eax
.pos:
    cmp eax, ecx
    jle .ok
    mov eax, ecx                ; heavier armor caps how much DEX helps
.ok:
    add ebx, eax
    mov [playerAC], ebx
    ret

equip_item:                     ; eax = bag slot. Weapons/armor are worn, potions are drunk. CF=1 = refused
    mov esi, [inv+eax*4]
    test esi, esi
    jz .no
    mov [curSlot], eax
    movzx ebx, byte [esi+CAT_KIND]
    mov edi, [esi+CAT_PTR]      ; edi = the item's record
    cmp ebx, ITEM_POTION
    je .potion
    cmp ebx, ITEM_ARMOR
    je .armor
    movzx ecx, byte [class]     ; weapon: is it allowed for this class?
    sub ecx, '1'
    cmp ecx, 2
    ja .no
    movzx edx, byte [classBit+ecx]
    movzx ebx, byte [edi+WEAPON_CLASS]
    test ebx, edx
    jz .no
    cmp byte [edi+WEAPON_TWO_HANDED], 0
    je .setw
    cmp dword [equipShield], 0
    jne .no                     ; a two-hander needs both hands free
.setw:
    mov [equipWeapon], esi
    mov eax, [curSlot]
    mov [wornW], eax
    call recalc_gear            ; weapons can carry stat bonuses too
    clc
    ret
.armor:
    movzx ecx, byte [class]     ; are you trained for this kind of armor?
    sub ecx, '1'
    cmp ecx, 2
    ja .no
    movzx edx, byte [armorProf+ecx]
    movzx ebx, byte [edi+ARMOR_WEIGHT]
    test ebx, edx
    jz .noarmor
    cmp byte [edi+ARMOR_TYPE], ARMOR_HELM
    je .helm
    cmp byte [edi+ARMOR_TYPE], ARMOR_BOOTS
    je .boots
    cmp byte [edi+ARMOR_TYPE], ARMOR_TRINKET
    je .trinket
    cmp byte [edi+ARMOR_TYPE], ARMOR_SHIELD
    jne .body
    cmp ecx, 0                  ; shields: fighters only
    jne .noshield
    jmp .shieldit
.body:
    mov [equipBody], esi
    mov eax, [curSlot]
    mov [wornB], eax
    jmp .regear
.helm:
    mov [equipHelm], esi
    mov eax, [curSlot]
    mov [wornH], eax
    jmp .regear
.boots:
    mov [equipBoots], esi
    mov eax, [curSlot]
    mov [wornF], eax
    jmp .regear
.trinket:
    mov [equipTrinket], esi
    mov eax, [curSlot]
    mov [wornT], eax
    jmp .regear
.shieldit:
    mov ebx, [equipWeapon]
    test ebx, ebx
    jz .setsh
    mov ebx, [ebx+CAT_PTR]
    cmp byte [ebx+WEAPON_TWO_HANDED], 0
    jne .no                     ; can't hold a shield with a two-hander
.setsh:
    mov [equipShield], esi
    mov eax, [curSlot]
    mov [wornS], eax
.regear:
    call recalc_gear
    clc
    ret
.potion:
    mov eax, [curSlot]
    jmp use_potion
.no:
    stc
    ret
.noarmor:
    mov dword [refuseMsg], 1
    stc
    ret
.noshield:
    mov dword [refuseMsg], 2
    stc
    ret

use_potion:                     ; eax = bag slot: heal, and the potion is used up
    mov esi, [inv+eax*4]
    mov edi, [esi+CAT_PTR]
    push edx
    push eax
    movzx eax, byte [edi+1]     ; heal: a flat amount + a share of your max HP
    imul eax, [playerMaxHP]
    xor edx, edx
    mov ebx, 100
    div ebx
    movzx ebx, byte [edi]
    add ebx, eax
    pop eax
    pop edx
    add ebx, [playerHP]
    cmp ebx, [playerMaxHP]
    jle .h
    mov ebx, [playerMaxHP]
.h: mov [playerHP], ebx
    mov dword [inv+eax*4], 0
    call draw_hp
    clc
    ret

give_start_gear:                ; the starting weapon and armor of your class, put on
    movzx eax, byte [class]
    sub eax, '1'
    cmp eax, 2
    ja .r
    shl eax, 3                  ; 8 bytes per class
    mov [gearIdx], eax          ; its own variable: equip_item uses curSlot
    mov esi, [startGear+eax]
    call add_item
    jc .r
    call equip_item
    mov eax, [gearIdx]
    mov esi, [startGear+eax+4]
    call add_item
    jc .r
    call equip_item
.r: ret

draw_inventory:                 ; the bag, in the right-hand panel (rows 7..); '*' marks what you wear
    pushad
    mov dword [mi], 0
.l: mov eax, [mi]
    cmp eax, INV_MAX
    jge .d
    xor ecx, ecx
.f: mov byte [menuBuf+ecx], ' '
    inc ecx
    cmp ecx, 22
    jl .f
    mov eax, [mi]
    mov dl, [keyChars+eax]
    mov byte [menuBuf], '['
    mov [menuBuf+1], dl
    mov byte [menuBuf+2], ']'
    mov esi, [inv+eax*4]
    test esi, esi
    jz .w
    push esi
    lea esi, [esi+CAT_NAME]
    call name_to_buf
    xor ecx, ecx
.c: mov dl, [nameBuf+ecx]
    mov [menuBuf+4+ecx], dl
    inc ecx
    cmp ecx, 16
    jl .c
    pop esi
    mov eax, [mi]
    cmp eax, [wornW]
    je .star
    cmp eax, [wornB]
    je .star
    cmp eax, [wornS]
    je .star
    cmp eax, [wornH]
    je .star
    cmp eax, [wornF]
    je .star
    cmp eax, [wornT]
    jne .rar
.star:
    mov byte [menuBuf+21], '*'
.rar:
    mov eax, [mi]               ; '+' rare, '#' legendary
    mov esi, [inv+eax*4]
    cmp byte [esi+CAT_RARITY], 1
    jb .w
    mov byte [menuBuf+20], '+'
    je .w
    mov byte [menuBuf+20], '#'
.w: mov eax, [mi]
    add eax, GRID_ROW
    mov ebx, MENU_COL
    call goto_rc
    print_string menuBuf, 22
    inc dword [mi]
    jmp .l
.d: popad
    ret

; =====================================================================
; DAMAGE, ARMOR, ATTACKS
; =====================================================================
roll_item_damage:               ; esi = weapon OR spell record -> eax = damage. (Both use the same first 6 fields.)
    movzx eax, byte [esi+WEAPON_MAX_DAMAGE]
    movzx ebx, byte [esi+WEAPON_MIN_DAMAGE]
    sub eax, ebx
    inc eax
    call rand_mod               ; 0 .. (max-min)   (keeps ebx and esi)
    add ebx, eax                ; ebx = min + roll
    push ebx
    call get_scaling_stat       ; eax = best stat the item scales with
    call stat_mod               ; its modifier
    pop ebx
    add eax, ebx
    cmp eax, 1
    jge .r
    mov eax, 1                  ; a hit always does at least 1
.r: ret

absorb_damage:                  ; eax = damage coming in -> eax = damage that reaches your HP
    push ecx
    mov ecx, [eI]
    call incoming_hit           ; reflect, first hit, thorns (progress.inc)
    pop ecx
    mov ebx, [parryBonus]       ; Parry soaks the first hit
    test ebx, ebx
    jz .temp
    mov dword [parryBonus], 0
    sub eax, ebx
    jns .temp
    xor eax, eax
.temp:
    mov ebx, [tempHP]           ; then temporary HP (from Rally)
    test ebx, ebx
    jz .r
    cmp eax, ebx
    jl .part
    sub eax, ebx
    mov dword [tempHP], 0
    ret
.part:
    sub [tempHP], eax
    xor eax, eax
.r: ret

nearest_enemy_dist:             ; -> eax = distance to the closest living enemy (99 if none)
    mov dword [nearD], 99
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .d
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    push ecx
    call dist_to_player
    pop ecx
    cmp eax, [nearD]
    jge .n
    mov [nearD], eax
.n: inc ecx
    jmp .l
.d: mov eax, [nearD]
    ret

attack_enemy:                   ; attack enemy [eIdx] with the equipped weapon. CF=1 = could not (out of range / no attacks left)
    cmp dword [attacksLeft], 0
    jle .no
    mov esi, [equipWeapon]
    test esi, esi
    jz .fists
    mov esi, [esi+CAT_PTR]
    jmp .have
.fists:
    mov esi, fists
.have:
    mov [curRec], esi
    mov ecx, [eIdx]
    call dist_to_player         ; eax = distance
    mov esi, [curRec]
    movzx ebx, byte [esi+WEAPON_ATTACK_RANGE]
    cmp eax, ebx
    jg .no                      ; out of the weapon's range
    dec dword [attacksLeft]
    call roll_item_damage
    mov [dmg], eax
    mov esi, [curRec]           ; RANGED weapons are weaker at point-blank
    test byte [esi+WEAPON_TYPE], WTYPE_RANGED
    jz .nopen
    call nearest_enemy_dist
    cmp eax, 1
    jg .nopen
    shr dword [dmg], 1
.nopen:
    mov dword [attackPierce], 0
    mov eax, SP_PIERCE
    call has_special
    jnc .np
    mov dword [attackPierce], 1
.np:
    cmp dword [hidden], 0       ; ROGUE: sneak attack = Nd6 (2 at first, more with levels and gear), then you are seen
    je .nosneak
    mov ecx, [pkSneak]
    add ecx, [gSneak]
    cmp ecx, 2
    jge .sd
    mov ecx, 2
.sd:
    push ecx
    mov eax, 6
    call rand_mod
    inc eax
    add [dmg], eax
    pop ecx
    loop .sd
    mov dword [hidden], 0
    cmp dword [pkPierceSneak], 0
    je .ns2
    mov dword [attackPierce], 1
.ns2:
    call draw_mana
.nosneak:
    mov eax, [pendingMan]       ; FIGHTER: a chosen maneuver spends a die on this hit
    test eax, eax
    jz .noman
    call spend_die
    jc .noman
    call apply_maneuver
.noman:
    mov dword [pendingMan], 0
    mov eax, [dmg]
    mov ecx, [eIdx]
    call boss_cut               ; boss shields, wards, light and bits (bosses.inc)
    mov [dmg], eax
    sub [enemyHP+ecx*4], eax
    call wake_enemy             ; getting hurt ends Sleep
    mov dword [attackPierce], 0
    mov esi, msgHit
    mov ecx, msgHitlen
    call say_num                ; "You hit for N"
    mov ecx, [eIdx]
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    call kill_enemy
    cmp dword [pkRehide], 0     ; ROGUE level 13: a kill hides you again
    je .ok
    mov dword [hidden], 1
    msg msgVanish
    jmp .ok
.alive:
    call weapon_on_hit          ; burn / slow / poison / ..., lifesteal (progress.inc)
    call redraw_enemy
.ok:
    mov dword [inFight], 1      ; you struck: this is a fight now
    call draw_mode
    call draw_mana              ; dice, next maneuver, HIDDEN
    clc
    ret
.no:
    stc
    ret

; =====================================================================
; FIGHTER: BATTLE MASTER
; =====================================================================
begin_player_turn:              ; call when a new player turn starts
    mov eax, [pkAttacks]        ; fighter 2 (more with levels), rogue 1 (2 at level 7), wizard 1
    cmp eax, 1
    jge .a
    mov eax, 1
.a: push eax
    mov eax, SP_EXTRA
    call has_special
    pop eax
    jnc .s
    inc eax
.s: mov [attacksLeft], eax
    ret

end_of_combat:                  ; call when a fight is over: dice come back
    mov eax, [pkDice]
    mov [diceLeft], eax
    call new_fight_state        ; first-hit, free spell, Action Surges
    mov dword [surgeUsed], 0
    mov dword [pendingMan], 0
    mov dword [tempHP], 0
    mov dword [parryBonus], 0
    ret

spend_die:                      ; -> eax = d8 + STR/8, or CF=1 if no dice are left
    cmp dword [diceLeft], 0
    jle .none
    dec dword [diceLeft]
    mov eax, [pkDie]            ; d8, d10 at level 7, d12 at level 15
    call rand_mod
    inc eax
    push eax
    mov eax, [strength]
    call stat_mod
    pop ebx
    add eax, ebx
    cmp eax, 1
    jge .ok
    mov eax, 1
.ok:
    clc
    ret
.none:
    stc
    ret

cycle_maneuver:                 ; M key: none > sweeping > pushing > trip > menacing > none   (spent when your next hit lands)
    inc dword [pendingMan]
    cmp dword [pendingMan], MAN_MENACE
    jle .r
    mov dword [pendingMan], 0
.r: ret

use_parry:                      ; P key: spend a die now; the next hit you take is reduced by it
    call fighter_check
    jc .r
    call spend_die
    jc .nodice
    add [parryBonus], eax
    mov esi, msgParry
    mov ecx, msgParrylen
    call say_num
.r: ret
.nodice:
    msg msgNoDice
    ret

use_rally:                      ; L key: spend a die now for temporary HP
    call fighter_check
    jc .r
    call spend_die
    jc .nodice
    add [tempHP], eax
    mov esi, msgRally
    mov ecx, msgRallylen
    call say_num
.r: ret
.nodice:
    msg msgNoDice
    ret

fighter_check:                  ; CF=1 unless you are a fighter
    movzx eax, byte [class]
    cmp eax, '1'
    jne .no
    clc
    ret
.no:
    stc
    ret

apply_maneuver:                 ; eax = die value; the chosen maneuver is in [pendingMan]; changes [dmg] / the target
    mov [dieVal], eax
    mov ebx, [pendingMan]
    cmp ebx, MAN_SWEEP
    je .sweep
    cmp ebx, MAN_PUSH
    je .push
    cmp ebx, MAN_TRIP
    je .trip
    cmp ebx, MAN_MENACE
    je .menace
    ret
.sweep:
    mov eax, [dieVal]
    jmp sweep_hit
.push:
    mov eax, [dieVal]
    add [dmg], eax
    mov eax, 3
    jmp push_enemy
.trip:
    mov eax, [dieVal]
    add [dmg], eax
    mov eax, EFFECT_PRONE
    jmp apply_status
.menace:
    mov eax, [dieVal]
    add [dmg], eax
    mov eax, EFFECT_FRIGHT
    jmp apply_status

sweep_hit:                      ; eax = damage: also hit ONE other enemy that is next to the player
    mov [sweepDmg], eax
    xor ecx, ecx
.l: cmp ecx, MAX_ENEMIES
    jge .r
    cmp ecx, [eIdx]
    je .n
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    push ecx
    call dist_to_player
    pop ecx
    cmp eax, 1
    jg .n
    mov eax, [sweepDmg]
    call boss_cut
    sub [enemyHP+ecx*4], eax
    call wake_enemy             ; getting hurt ends Sleep
    mov edx, [eIdx]             ; remember the main target, work on this one, restore
    push edx
    mov [eIdx], ecx
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    call kill_enemy
    jmp .rest
.alive:
    call redraw_enemy
.rest:
    pop edx
    mov [eIdx], edx
    ret
.n: inc ecx
    jmp .l
.r: ret

push_enemy:                     ; eax = cells: shove enemy [eIdx] straight away from the player (stops at walls/enemies/exit)
    mov [pushLeft], eax
.step:
    cmp dword [pushLeft], 0
    jle .r
    dec dword [pushLeft]
    mov ecx, [eIdx]
    mov eax, [enemyX+ecx*4]
    sub eax, [playerX]
    call sign_eax
    mov ecx, [eIdx]
    add eax, [enemyX+ecx*4]
    mov [nX], eax
    mov ecx, [eIdx]
    mov eax, [enemyY+ecx*4]
    sub eax, [playerY]
    call sign_eax
    mov ecx, [eIdx]
    add eax, [enemyY+ecx*4]
    mov [nY], eax
    mov ecx, [eIdx]
    mov [eI], ecx               ; enemy_move_to works on [eI]
    call enemy_move_to
    mov ecx, [eIdx]
    mov eax, [enemyX+ecx*4]
    cmp eax, [nX]
    jne .r                      ; it didn't move, so something was in the way
    mov eax, [enemyY+ecx*4]
    cmp eax, [nY]
    jne .r
    jmp .step
.r: ret

sign_eax:                       ; eax -> -1, 0 or 1
    test eax, eax
    jz .r
    js .n
    mov eax, 1
    ret
.n: mov eax, -1
.r: ret

action_surge:                   ; G key: two extra attacks, once per fight (more often at levels 10 and 20)
    cmp dword [surgesLeft], 0
    jle .r
    movzx eax, byte [class]
    cmp eax, '1'
    jne .r
    dec dword [surgesLeft]
    mov dword [surgeUsed], 1
    add dword [attacksLeft], 2
    msg msgSurge
.r: ret

; =====================================================================
; ROGUE: STEALTH
; =====================================================================
try_hide:                       ; H key (rogue only)
    movzx eax, byte [class]
    cmp eax, '2'
    jne .r
    call nearest_enemy_dist
    cmp eax, 1
    jle .seen                   ; you can't vanish right in front of someone...
    cmp dword [inFight], 0
    je .ok
    cmp dword [movementPoint], 3    ; ...and in a fight it costs 3 movement (Cunning Action), not your attack
    jl .busy
    sub dword [movementPoint], 3
    call draw_movement
.ok:
    mov dword [hidden], 1
    msg msgHidden
.r: ret
.busy:
    msg msgHideMove
    ret
.seen:
    msg msgNoHide
    ret

effective_aggro:                ; -> eax = how close an enemy must be to start combat
    mov eax, AGGRO              ; while hidden it's 0: the fight only starts when you are SPOTTED or you strike first
    cmp dword [hidden], 0
    je .r
    xor eax, eax
.r: ret

effective_notice:               ; -> eax = how close an enemy must be to start chasing (2 while hidden)
    mov eax, NOTICE
    cmp dword [hidden], 0
    je .r
    mov eax, 2
.r: ret

stealth_step:                   ; call after each step you take: hidden characters can be spotted
    cmp dword [hidden], 0
    je .r
    cmp dword [pkStealth], 0    ; rogue level 5, or Shadowweave: never spotted while moving
    jne .r
    mov eax, SP_STEALTH
    call has_special
    jc .r
    call nearest_enemy_dist
    cmp eax, 1
    jle .r                      ; right next to an enemy you stay hidden: that's how you sneak attack
    cmp eax, SPOT_RANGE
    jg .r
    mov eax, SPOT_ODDS
    call rand_mod
    test eax, eax
    jnz .r                      ; a 1 in SPOT_ODDS chance per step while an enemy is 2..SPOT_RANGE cells away
    mov dword [hidden], 0
    msg msgSpotted
    call draw_mana              ; take HIDDEN off the screen
.r: ret

; =====================================================================
; SPELLS YOUR CLASS CAN CAST
; =====================================================================
build_spell_list:               ; spellList[] = the spells your class can cast, spellListN = how many
    mov dword [spellListN], 0
    movzx ecx, byte [class]
    sub ecx, '1'
    cmp ecx, 2
    ja .r
    movzx edx, byte [classBit+ecx]
    xor ecx, ecx
.l: cmp ecx, SPELL_COUNT
    jge .r
    imul ebx, ecx, SPELL_SIZE
    movzx eax, byte [spellTable+ebx+SPELL_CLASS]
    test eax, edx
    jz .n
    cmp byte [spellTable+ebx+SPELL_MANA_COST], 0
    jne .n                      ; you start with the cantrips only; the rest are scrolls to find
    mov eax, [spellListN]
    mov [spellList+eax], cl
    inc dword [spellListN]
.n: inc ecx
    jmp .l
.r: ret

knows_spell:                    ; eax = spell number -> CF=1 if it is already in your spell list   (keeps all)
    push ecx
    xor ecx, ecx
.l: cmp ecx, [spellListN]
    jge .no
    cmp al, [spellList+ecx]
    je .yes
    inc ecx
    jmp .l
.yes:
    pop ecx
    stc
    ret
.no:
    pop ecx
    clc
    ret

loot_weight:                    ; edx = catalog offset -> eax = its drop weight for YOU (0 = can't drop)
    movzx eax, byte [catalogTable+edx+CAT_WEIGHT]
    cmp byte [catalogTable+edx+CAT_RARITY], 0
    je .common
    push ebx                    ; rare: deep enough, and something YOU can use
    movzx ebx, byte [catalogTable+edx+CAT_FLOOR]
    cmp [floorCount], ebx
    pop ebx
    jl .zero
    push esi
    lea esi, [catalogTable+edx]
    call can_use_item
    pop esi
    jnc .zero
.common:
    cmp byte [catalogTable+edx+CAT_KIND], ITEM_SCROLL
    jne .r
    cmp byte [class], '3'
    jne .zero                   ; scrolls only drop for a wizard ...
    push eax
    mov eax, [catalogTable+edx+CAT_PTR]
    call knows_spell
    pop eax
    jc .zero                    ; ... and never a spell you already know
.r: ret
.zero:
    xor eax, eax
    ret

; =====================================================================
; LOOT
; =====================================================================
roll_loot:                      ; -> esi = a catalog entry, chosen by weight
    xor ebx, ebx                ; ebx = total weight
    xor ecx, ecx
.sum:
    cmp ecx, CATALOG_COUNT
    jge .roll
    imul edx, ecx, CAT_SIZE
    call loot_weight
    add ebx, eax
    inc ecx
    jmp .sum
.roll:
    mov eax, ebx
    call rand_mod               ; 0 .. total-1
    xor ecx, ecx
.walk:
    imul edx, ecx, CAT_SIZE
    push eax
    call loot_weight
    mov ebx, eax
    pop eax
    cmp eax, ebx
    jl .found                   ; the roll landed inside this item's slice of the total
    sub eax, ebx
    inc ecx
    jmp .walk
.found:
    lea esi, [catalogTable+edx]
    ret

ground_at:                      ; eax = x, ebx = y -> eax = ground slot, or -1   (clobbers ecx)
    xor ecx, ecx
.l: cmp ecx, MAX_GROUND
    jge .none
    cmp dword [groundItem+ecx*4], 0
    je .n
    cmp eax, [groundX+ecx*4]
    jne .n
    cmp ebx, [groundY+ecx*4]
    jne .n
    mov eax, ecx
    ret
.n: inc ecx
    jmp .l
.none:
    mov eax, -1
    ret

can_use_item:                   ; esi = catalog entry -> CF=1 if your class can use it   (keeps all)
    pushad
    call class_index
    mov edi, [esi+CAT_PTR]
    cmp byte [esi+CAT_KIND], ITEM_WEAPON
    jne .ar
    movzx edx, byte [classBit+eax]
    test byte [edi+WEAPON_CLASS], dl
    jnz .yes
    jmp .no
.ar:
    cmp byte [esi+CAT_KIND], ITEM_ARMOR
    jne .yes
    cmp byte [edi+ARMOR_TYPE], ARMOR_SHIELD
    jne .w
    test eax, eax
    jnz .no                     ; shields: fighters only
.w: movzx edx, byte [armorProf+eax]
    test byte [edi+ARMOR_WEIGHT], dl
    jz .no
.yes:
    popad
    stc
    ret
.no:
    popad
    clc
    ret

ground_glyph:                   ; esi = catalog entry -> dl   ('!' potion, '/' weapon, ']' armor, '?' scroll)
    mov dl, '?'
    cmp byte [esi+CAT_KIND], ITEM_SCROLL
    je .d
    mov dl, '!'
    cmp byte [esi+CAT_KIND], ITEM_POTION
    je .d
    mov dl, '/'
    cmp byte [esi+CAT_KIND], ITEM_WEAPON
    je .d
    mov dl, ']'
.d: ret

drop_loot:                      ; eax = x, ebx = y: maybe leave an item on the floor (call when an enemy dies)
    mov [dropX], eax
    mov [dropY], ebx
    cmp dword [forceDrop], 0
    jne .sure                   ; bosses always drop
    mov eax, 100
    call rand_mod
    cmp eax, DROP_CHANCE
    jge .r
.sure:
    xor ecx, ecx                ; find a free ground slot
.f: cmp ecx, MAX_GROUND
    jge .r
    cmp dword [groundItem+ecx*4], 0
    je .got
    inc ecx
    jmp .f
.got:
    mov [dropSlot], ecx
    mov esi, [bossDrop]         ; a boss drops its legendary for your class
    mov dword [bossDrop], 0
    test esi, esi
    jnz .have
    call roll_loot              ; esi = the item
.have:
    mov ecx, [dropSlot]
    mov [groundItem+ecx*4], esi
    mov eax, [dropX]
    mov [groundX+ecx*4], eax
    mov ebx, [dropY]
    mov [groundY+ecx*4], ebx
    call ground_glyph
    call put_cell               ; eax = x, ebx = y, dl = glyph
.r: ret

check_pickup:                   ; call after the player steps: walking onto an item picks it up
    mov eax, [playerX]
    mov ebx, [playerY]
    call ground_at
    cmp eax, -1
    je .r
    mov [pickSlot], eax
    mov esi, [groundItem+eax*4]
    cmp byte [esi+CAT_KIND], ITEM_SCROLL
    je .scroll
    call add_item
    jc .full
    mov ecx, [pickSlot]
    mov dword [groundItem+ecx*4], 0
    push esi                    ; "You pick up Gatebreaker (LEGENDARY)"
    call msg_begin
    mtext msgPicked
    pop esi
    push esi
    call print_name
    pop esi
    movzx eax, byte [esi+CAT_RARITY]
    test eax, eax
    jz .pe
    mov esi, pickRarity
    mov ecx, 7
    cmp eax, 1
    je .pr
    add esi, 7
    mov ecx, 12
.pr: call msg_text
.pe: call msg_end
    cmp dword [bagOpen], 0
    je .r
    call draw_inventory         ; show it in the bag right away
.r: ret
.full:
    msg msgBagFull
    ret
.scroll:                        ; a scroll isn't carried: you learn the spell on the spot
    mov ecx, [pickSlot]
    mov dword [groundItem+ecx*4], 0
    mov eax, [esi+CAT_PTR]      ; the spell number
    call knows_spell
    jc .r
    mov ecx, [spellListN]
    mov [spellList+ecx], al
    inc dword [spellListN]
    call msg_begin
    mov esi, msgLearn
    mov ecx, msgLearnlen
    call msg_text
    imul esi, eax, NAME_LEN
    add esi, spellNames
    call print_name
    mov esi, msgBang
    mov ecx, msgBanglen
    call msg_text
    call msg_end
    call draw_spell_menu
    ret


; =====================================================================
; ARMOR CLASS: do enemies hit you?
; =====================================================================
enemy_hit_roll:                 ; ebx = its attack bonus -> CF=0 the enemy hits you, CF=1 it misses (d20 + bonus >= your AC)
    mov eax, 20
    call rand_mod               ; keeps ebx
    add eax, 1                  ; d20 is 1..20
    add eax, ebx
    cmp eax, [playerAC]
    jge .hit
    stc
    ret
.hit:
    clc
    ret

; =====================================================================
; BAG / SPELL PANEL GLUE
; =====================================================================
clear_panel:                    ; blank the right-hand panel rows 7..19
    pushad
    mov dword [mi], 0
.l: mov eax, [mi]
    add eax, GRID_ROW
    mov ebx, MENU_COL
    call goto_rc
    print_string blank24, 24
    inc dword [mi]
    cmp dword [mi], 13
    jl .l
    popad
    ret

start_discard:                  ; X key: the next slot key throws that item away (X again cancels)
    cmp dword [discardMode], 0
    jne .cancel
    cmp dword [bagOpen], 0
    jne .on
    call toggle_bag             ; show the bag first
.on:
    mov dword [discardMode], 1
    msg msgWhich
    ret
.cancel:
    mov dword [discardMode], 0
    msg msgKeep
    ret

discard_item:                   ; eax = bag slot: throw it away (taking it off first if you wear it)
    mov dword [discardMode], 0
    cmp eax, INV_MAX
    jae .none
    cmp dword [inv+eax*4], 0
    je .none
    cmp eax, [wornW]
    jne .b
    mov dword [equipWeapon], 0  ; back to fists
    mov dword [wornW], -1
.b: cmp eax, [wornB]
    jne .s
    mov dword [equipBody], 0
    mov dword [wornB], -1
.s: cmp eax, [wornS]
    jne .h
    mov dword [equipShield], 0
    mov dword [wornS], -1
.h: cmp eax, [wornH]
    jne .f
    mov dword [equipHelm], 0
    mov dword [wornH], -1
.f: cmp eax, [wornF]
    jne .t
    mov dword [equipBoots], 0
    mov dword [wornF], -1
.t: cmp eax, [wornT]
    jne .gone
    mov dword [equipTrinket], 0
    mov dword [wornT], -1
.gone:
    mov dword [inv+eax*4], 0
    call recalc_gear
    call draw_inventory
    call draw_mana              ; AC and weapon line
    call draw_stats
    call draw_hp
    msg msgTossed
    ret
.none:
    msg msgKeep
    ret

toggle_bag:                     ; I key (only the wizard switches: the others always see their bag)
    cmp byte [class], '3'
    jne .r0
    call disarm                 ; no half-aimed spell while you rummage
    xor dword [bagOpen], 1
    call clear_panel
    call draw_panel_header
    cmp dword [bagOpen], 0
    je .spells
    call draw_inventory
    ret
.spells:
    call draw_spell_menu
    ret
.r0:
    ret

key_slot:                       ; a 1-9 / a-d key: eax = 0..12. Casts a spell, or equips / uses a bag item
    cmp dword [statPick], 0
    jne pick_stat               ; U was pressed: 1-4 raise a stat
    cmp dword [discardMode], 0
    jne discard_item
    cmp dword [bagOpen], 0
    je select_spell
    cmp eax, INV_MAX
    jae .r
    mov dword [refuseMsg], 0
    call equip_item
    jnc .ok
    cmp dword [refuseMsg], 1
    je .ar
    cmp dword [refuseMsg], 2
    je .sh
    msg msgNoUse
    jmp .ok
.ar: msg msgNoArmor
    jmp .ok
.sh: msg msgNoShield
.ok:
    call draw_inventory
    call draw_mana              ; AC and weapon line
    call draw_stats             ; gear can change your stats, HP and mana
    call draw_hp
.r: ret

; =====================================================================
; one call to set everything up (after character creation, and in reset_arena)
; =====================================================================
init_features:
    mov eax, [pkDice]
    mov [diceLeft], eax
    mov dword [pendingMan], 0
    mov dword [tempHP], 0
    mov dword [parryBonus], 0
    mov dword [hidden], 0
    mov dword [surgeUsed], 0
    mov dword [bagOpen], 1      ; fighters and rogues have no spells: their panel is the bag
    cmp byte [class], '3'
    jne .bag
    mov dword [bagOpen], 0      ; the wizard's panel starts on the spells
.bag:
    mov dword [discardMode], 0
    cld
    xor eax, eax
    mov edi, inv
    mov ecx, INV_MAX
    rep stosd
    mov edi, groundItem
    mov ecx, MAX_GROUND
    rep stosd
    mov dword [equipWeapon], 0
    mov dword [equipBody], 0
    mov dword [equipShield], 0
    mov dword [equipHelm], 0
    mov dword [equipBoots], 0
    mov dword [equipTrinket], 0
    mov dword [wornH], -1
    mov dword [wornF], -1
    mov dword [wornT], -1
    mov dword [wornW], -1
    mov dword [wornB], -1
    mov dword [wornS], -1
    call build_spell_list
    call give_start_gear
    call recalc_gear
    call new_fight_state
    call begin_player_turn
    ret
; ===== end features.inc =====
; ===== begin bosses.inc =====
; =====================================================================
; bosses.inc  -  every boss rule that is more than "hit it until it dies"
;
;   floors 4, 8  the Warden: a gate symbol on his shield. While the torch pair doesn't
;                match that gate he takes half damage. Match it and the shield breaks for
;                2 rounds; then it returns with a new gate and the torches leap to the
;                other side of the room.            (centre letter = the gate, B = broken)
;   floor 15     the Dark Shade: dark room, and the torches burn cold blue: no light. It can
;                only be hurt while the lantern burns (full damage), or next to you if you
;                carry a light (half). Two gates
;                light the lantern. It hunts lit torches and snuffs them.   (D lit, d dark)
;   floor 17     Grand Wizard Ymir: the top pair feeds the top gate, the bottom pair the
;                bottom gate. A gate that outputs 1 puts out a power torch (& lit, ~ out).
;                Every lit power torch = 2 spells a turn. Both out: he is stunned and
;                takes +50%, then a blue wave pushes you away, relights them, new gates.
;   floor 21     the Logic Keeper: a ward cuts hits to a quarter until you solve its gate;
;                at half HP it rewrites the gate.     (J warded, j ward broken)
;   floor 26     Altair and Smo: one carries a 1 (half damage), the other a 0 (+50%), and
;                they may swap at the end of every boss turn. When one falls the other
;                gets its power back at full HP.   (T/U = 1, F/H = 0, t/u = empowered)
;   floor 30     the Forgotten King: on his throne, immune to every attack. The throne
;                circuit ends in a blue cannon torch: power it and it blasts him for 1/6 of
;                his health, then the torches scramble. At 2/3 and 1/3 HP he rewires the
;                circuit (the last time every gate is hidden). At 0 HP he only pretends to die:
;                he rises as the Forgotten King, Unbound (7x7) and uses the other bosses'
;                tricks in turn, 2 rounds each, with one torch pair at the top of the room.
;                (his middle letter: A/V/X.. = gate shield, f = fuel, D/d = light, 1/0 = bit)
; =====================================================================

section .data
BR_YMIR   equ 4                 ; bossRoom numbers (1 Warden, 2 King, 3 Shade are in room.inc)
BR_KEEPER equ 5
BR_DUO    equ 6
LIGHT_R   equ 4                 ; how far a lit torch's light reaches (cells)
CANNON_X  equ 34                ; the King's blue cannon torch, at the end of the throne circuit
CANNON_Y  equ 6

bossTypeOf dd 0, ETYPE_MINIBOSS, ETYPE_KING, ETYPE_SHADE, ETYPE_YMIR, ETYPE_KEEPER, ETYPE_ALTAIR, ETYPE_BISHOP
bossStartX db 0, 26, 38, 22, 17, 30, 23, 2
bossStartY db 0,  5,  5,  9,  4,  4,  3, 1

wardenRows db 6, 3, 9           ; rows the Warden's torch pair may stand on

; Ymir's spells: name slot (12 bytes), then min and max damage
YSPELL_LEN equ 12
ymirSpellNames:
    db "Firebolt",0,0,0,0
    db "Frost Lance",0
    db "Lightning",0,0,0
    db "Meteor",0,0,0,0,0,0
ymirDmg db 1,3,  1,2,  1,4,  2,4     ; small: up to 4 of them a turn
YMIR_REACH equ 60              ; he reaches the whole room (and his body cannot cross the gate column)
P1_X equ 25                     ; Ymir's power torches
P1_Y equ 5
P2_X equ 25
P2_Y equ 7

msgCasts db " casts "
msgCastslen equ $- msgCasts
msgBlinks db " blinks away and"
msgBlinkslen equ $- msgBlinks
msgSp db " "
msgSplen equ $- msgSp
msgYMiss db " miss"
msgYMisslen equ $- msgYMiss
msgComma2 db ", "
msgComma2len equ $- msgComma2

msgYmir db "Grand Wizard Ymir: each lit power torch is two of his spells. Put them out!"
msgYmirlen equ $- msgYmir
msgKeeper db "The Logic Keeper raises its ward. Solve the gate (R) to break it!"
msgKeeperlen equ $- msgKeeper
msgDuo db "Altair and Smo block the way. The 1 is shielded, the 0 is exposed!"
msgDuolen equ $- msgDuo
msgWardBreak db "The ward shatters! The Logic Keeper staggers."
msgWardBreaklen equ $- msgWardBreak
msgWardUp db "The Logic Keeper rewrites the gate! Its ward returns. Read the plaque."
msgWardUplen equ $- msgWardUp
msgSmoRise db "Smo absorbs Altair's power and rises again!"
msgSmoRiselen equ $- msgSmoRise
msgAltRise db "Altair absorbs Smo's power and rises again!"
msgAltRiselen equ $- msgAltRise
msgShieldBreak db "The gate opens - the Warden's shield breaks for two rounds!"
msgShieldBreaklen equ $- msgShieldBreak
msgBurn db "WARDEN: Burn anew! (his beam throws the torches across the room)"
msgBurnlen equ $- msgBurn
msgLantern db "The lantern blazes! The Shade has nowhere to hide."
msgLanternlen equ $- msgLantern
msgShatter db "The Shade shatters the lantern. Darkness returns."
msgShatterlen equ $- msgShatter
msgSnuff db "The Shade snuffs out a torch."
msgSnufflen equ $- msgSnuff
msgSnuffLit db "The Shade snuffs a torch - and the lantern flares up!"
msgSnuffLitlen equ $- msgSnuffLit
msgSpent db "Ymir's power is spent! He staggers, open to attack."
msgSpentlen equ $- msgSpent
msgWave db "Ymir releases a blue wave! The power torches blaze again."
msgWavelen equ $- msgWave
msgWaveHit db "Ymir's blue wave crashes into you for "
msgWaveHitlen equ $- msgWaveHit
msgBlast   db "The blue torch fires! A huge blast strikes the King for "
msgBlastlen equ $- msgBlast
msgBlastEnd db " - the torches go dark again."
msgBlastEndlen equ $- msgBlastEnd
msgRewire db "The King slams his throne! The circuit rewires itself."
msgRewirelen equ $- msgRewire
msgRewire2 db "The King slams his throne! Every gate goes dark - read the plaque."
msgRewire2len equ $- msgRewire2
msgFallen db "The Forgotten King has fallen..."
msgFallenlen equ $- msgFallen
msgUnbound db "...no. The throne explodes. The Forgotten King rises, UNBOUND!"
msgUnboundlen equ $- msgUnbound
msgMode0 db "The Unbound shakes the room into the Warden's hall - match the gate on his shield!"
msgMode0len equ $- msgMode0
msgMode1 db "The Unbound shakes the room into the Bishops' chapel - he splits in four! Only the 1 can be hurt."
msgMode1len equ $- msgMode1
msgMode2 db "The Unbound shakes the room into the Shade's dark - only the lantern's light can hurt him!"
msgMode2len equ $- msgMode2
msgMode3 db "The Unbound shakes the room into Ymir's tower - every lit power torch is another strike!"
msgMode3len equ $- msgMode3
msgMode4 db "The Unbound shakes the room into the Keeper's vault - two Wardens link to him. Cut both links!"
msgMode4len equ $- msgMode4
msgMode5 db "The Unbound shakes the room and splits into Altair and Smo - 1 is shielded, 0 is exposed!"
msgMode5len equ $- msgMode5
modeMsgs dd msgMode0, msgMode1, msgMode2, msgMode3, msgMode4, msgMode5
modeLens dd msgMode0len, msgMode1len, msgMode2len, msgMode3len, msgMode4len, msgMode5len
; the Unbound's forms, in turn: he takes each boss's size, reach and speed
UF_WARDEN equ 0
UF_BISHOP equ 1
UF_SHADE  equ 2
UF_YMIR   equ 3
UF_KEEPER equ 4
UF_DUO    equ 5                ; Altair & Smo: he splits into a quick 2x2 Unbound and a heavy 4x4 one
UF_COUNT  equ 6
;            width, height, reach, move
uFormStats db miniboss_w,miniboss_h, 1, 5     ; the Warden
           db 2,2, 99, 0                       ; a bishop (he and his three copies never move)
           db shade_w,shade_h, 3, 5            ; the Shade
           db big4_w,big4_h, 7, 4              ; Ymir (casts from 7 cells)
           db big4_w,big4_h, 2, 5              ; the Logic Keeper
           db 2,2, 2, 6                        ; Altair & Smo: the quick one (a spear) ...
duoHeavy   db big4_w,big4_h, 1, 4              ;   ... and the heavy one (slow, hits hard)

plqWarden db "WARDEN - light the pair so the gate on his shield lets it through."
plqWardenlen equ $- plqWarden
plqShade db "LANTERN - power both gates to light the lantern. The torches' cold fire gives no light."
plqShadelen equ $- plqShade
plqYmir db "POWER - a gate that outputs 1 puts out one of Ymir's power torches."
plqYmirlen equ $- plqYmir
plqThrone db "THRONE - power the circuit: the blue torch at its end blasts the King."
plqThronelen equ $- plqThrone
plqGate db "THRONE - gate "
plqGatelen equ $- plqGate
plqColon db ": "
plqColonlen equ $- plqColon

section .bss
bossMax     resd 1              ; the boss's starting HP
bossHalf    resd 1
wardUp      resd 1              ; Logic Keeper
keeperPhase resd 1
duoMax      resd 2              ; Altair and Smo
empowered   resd MAX_ENEMIES
bitsOn      resd 1              ;   1 while both live
bitOwner    resd 1              ;   which of them carries the 1
wShield     resd 1              ; Warden: 1 = shield up
wTimer      resd 1              ;   rounds until it returns
wSide       resd 1              ;   0 = torches on the right, 1 = on the left
wardenBuf   resb 9              ;   his 3x3 sprite with the gate letter in the middle
lanternT    resd 1              ; Shade: rounds the lantern still burns
snuffCD     resd 1              ;   rounds until it can snuff again
exhaustR    resd 1              ; Ymir: rounds of exhaustion left
kingOpen    resd 1              ; King: the throne wire carried a 1 last time we looked
kingStage   resd 1              ;   0, 1 (rewired at 2/3), 2 (rewired at 1/3, gates hidden)
kingDying   resd 1              ;   1 during the fake death
dyingT      resd 1
isUnbound   resd 1              ;   1 once he has risen
uMode       resd 1              ;   which boss he imitates (UF_*)
uExtras     resd 1              ;   extra bodies he brought (enemies 1..n): bishop copies, shadow Wardens
uDead       resd 1              ;   1 once he is truly dead (his copies can't kill him twice)
uDuoBig     resd 1              ;   Altair & Smo form: 1 = he is the heavy one, his copy the quick one
bfE         resd 1              ;   body_fits / place_body: which enemy's body
ucopyBuf    resb 49
uHits       resd 1              ;   hits taken in this form: 3 and he changes
uSwitch     resd 1              ;   1 = change form at the next tick
kingBit     resd 1
unboundBuf  resb 49
bfX         resd 1
bfY         resd 1
nuPX        resd 1
nuR         resd 1
plaqueIdx   resd 1              ; which hidden gate the throne plaque talks about next
bossTpl     resd 1
noteBuf     resb 120            ; a boss message to show on the next tick (so it isn't overwritten)
noteLen     resd 1
modeNoteLater resd 1
blinked     resd 1
castFirst   resd 1
castN       resd 1
oldBX       resd 1
oldBY       resd 1
aimX        resd 1
aimY        resd 1
bTmp        resd 1
bTmp2       resd 1
bBest       resd 1
bI          resd 1
bLI         resd 1
oldPX       resd 1
oldPY       resd 1

section .text

; ---------------------------------------------------------------------
; small helpers
; ---------------------------------------------------------------------
note_set:                           ; esi = text, ecx = length: the message for the next tick
    pushad
    mov edi, noteBuf
    mov [noteLen], ecx
    cld
    rep movsb
    popad
    ret

note_num:                           ; eax = number: append it to the note
    pushad
    mov edi, noteBuf
    add edi, [noteLen]
    xor ecx, ecx
    mov ebx, 10
.d: xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .d
.p: pop eax
    add al, '0'
    stosb
    inc dword [noteLen]
    loop .p
    popad
    ret

%macro note 1
    mov esi, %1
    mov ecx, %1 %+ len
    call note_set
%endmacro

near_your_light:                    ; ecx = enemy -> CF=1 if you carry light and it is within 2 cells   (keeps all)
    push eax
    push ebx
    mov eax, SP_LIGHT
    call has_special
    jnc .no
    call dist_to_player
    cmp eax, 2
    jg .no
    pop ebx
    pop eax
    stc
    ret
.no:
    pop ebx
    pop eax
    clc
    ret

sign:                               ; eax -> -1, 0 or 1
    test eax, eax
    jz .r
    js .n
    mov eax, 1
    ret
.n: mov eax, -1
.r: ret

coin:                               ; -> eax = 0 or 1   (keeps the rest but ecx, edx)
    mov eax, 2
    jmp rand_mod

scramble_pair:                      ; roll the torch pair until it does NOT satisfy the gate
    pushad
    mov dword [bTmp], 40
.r: call coin
    mov [nodeBit], al
    call coin
    mov [nodeBit+1], al
    call puzzle_solved
    test eax, eax
    jz .d
    dec dword [bTmp]
    jnz .r
.d: popad
    ret

rect_dist:                          ; distance (in steps) from enemy ecx's body to the torch eax -> eax   (keeps the rest)
    push ebx
    push edx
    push esi
    push edi
    call torch_pos                  ; eax = left column, edx = row
    mov edi, eax                    ; torch x0
    mov [bTmp2], edx
    call enemy_rec
    mov eax, [enemyX+ecx*4]         ; dx = gap between [x0,x0+2] and the body's columns
    movzx ebx, byte [esi+ENEMY_W]
    add ebx, eax
    dec ebx                         ; body x1
    xor edx, edx
    cmp edi, ebx
    jle .a
    mov edx, edi
    sub edx, ebx
    jmp .b
.a: lea ebx, [edi+2]
    cmp eax, ebx
    jle .b
    mov edx, eax
    sub edx, ebx
.b: push edx                        ; dy
    mov eax, [enemyY+ecx*4]
    movzx ebx, byte [esi+ENEMY_H]
    add ebx, eax
    dec ebx
    mov edi, [bTmp2]
    xor edx, edx
    cmp edi, ebx
    jle .c
    mov edx, edi
    sub edx, ebx
    jmp .e
.c: cmp eax, edi
    jle .e
    mov edx, eax
    sub edx, edi
.e: pop eax
    cmp eax, edx
    jge .r
    mov eax, edx
.r: pop edi
    pop esi
    pop edx
    pop ebx
    ret

in_light:                           ; ecx = enemy -> CF=1 if it stands in torch light   (keeps everything)
    clc                             ; the Shade's torches are cold blue fire and give no light -
    ret                             ;   only the lantern (or a light you carry) can reach it
in_light_old:                       ; (the old rule, kept for reference)
    pushad
    call torch_count
    mov [bLI], eax
.l: dec dword [bLI]
    js .no
    mov eax, [bLI]
    cmp byte [nodeBit+eax], 0
    je .l
    call rect_dist
    cmp eax, LIGHT_R
    jg .l
    popad
    stc
    ret
.no:
    popad
    clc
    ret

lit_torches:                        ; -> eax = how many torches are lit
    push ecx
    push edx
    call torch_count
    mov ecx, eax
    xor eax, eax
.l: dec ecx
    js .d
    movzx edx, byte [nodeBit+ecx]
    add eax, edx
    jmp .l
.d: pop edx
    pop ecx
    ret

player_dead_check:                  ; a boss rule hurt you outside the attack line
    cmp dword [playerHP], 0
    jg .ok
    mov dword [playerHP], 0
    call draw_hp
    msg msgDead
    jmp quit
.ok:
    call draw_hp
    ret

; ---------------------------------------------------------------------
; boss circuits (the Shade's lantern, Ymir's gates, the King's throne)
; ---------------------------------------------------------------------
circ_boss_setup:                    ; eax = CT_S / CT_Y / CT_K
    pushad
    mov [bossTpl], eax
    mov dword [puzzleOn], 2
    mov dword [circHidden], -1
    call circ_load
    mov dword [circTry], 300
.types:
    xor edx, edx
.gt:
    cmp edx, [circNG]
    jge .judge
    push edx
    mov eax, GATE_COUNT
    call rand_mod
    pop edx
    mov [circGT+edx], al
    inc edx
    jmp .gt
.judge:
    cmp dword [bossTpl], CT_S
    jne .k
    mov byte [circGT+2], GT_LANTERN ; the middle gate is the lantern
    jmp .start
.k: cmp dword [bossTpl], CT_K
    jne .start
    mov dword [circSols], 0         ; the throne: solvable, but by at most half the settings
    mov dword [circCombo], 0
.cl:
    cmp dword [circCombo], 16
    jge .cj
    xor edx, edx
.cb:
    cmp edx, 4
    jge .ce
    mov eax, [circCombo]
    mov ecx, edx
    shr eax, cl
    and al, 1
    mov [nodeBit+edx], al
    inc edx
    jmp .cb
.ce:
    call circ_eval
    mov eax, [circOut]
    add [circSols], eax
    inc dword [circCombo]
    jmp .cl
.cj:
    dec dword [circTry]
    jz .start
    cmp dword [circSols], 0
    je .types
    cmp dword [circSols], 8
    jg .types
.start:                             ; a starting setting that leaves the boss at full power
    mov dword [circTry], 200
.st:
    xor edx, edx
.sb:
    cmp edx, [circNT]
    jge .se
    push edx
    call coin
    pop edx
    mov [nodeBit+edx], al
    inc edx
    jmp .sb
.se:
    call circ_eval
    cmp dword [bossTpl], CT_Y
    jne .one
    mov al, [circVal+4]             ; Ymir: both power torches lit (both gates output 0)
    or al, [circVal+5]
    jz .done
    jmp .again
.one:
    cmp dword [circOut], 0
    je .done
.again:
    dec dword [circTry]
    jnz .st
.done:
    call circ_eval
    popad
    ret

shade_room_setup:
    mov eax, CT_S
    jmp circ_boss_setup
ymir_room_setup:
    mov eax, CT_Y
    jmp circ_boss_setup
king_room_setup:
    mov eax, CT_K
    jmp circ_boss_setup

; ---------------------------------------------------------------------
; the Warden's torch pair
; ---------------------------------------------------------------------
warden_room_setup:
    mov dword [puzzleOn], 1
    mov dword [puzzlePairs], 1
    mov dword [puzzleAll], 0
    mov dword [wSide], 0            ; first behind him (the right: you come in from the left)
    call warden_gate
    call warden_place
    call scramble_pair
    ret

warden_gate:                        ; floor 4: AND or OR. floor 8: AND, OR or XOR
    mov eax, 2
    cmp dword [floorCount], 4
    jle .r
    mov eax, 3
.r: call rand_mod
    mov [puzzleGate], eax
    ret

warden_place:                       ; put the pair on side [wSide], on a row nobody stands on
    pushad
    mov eax, 36
    cmp dword [wSide], 0
    je .x
    mov eax, 10
.x: mov [pairX], eax
    mov dword [bI], 0
.row:
    mov eax, [bI]
    cmp eax, 3
    jge .fallback
    movzx eax, byte [wardenRows+eax]
    mov [pairY], eax
    xor edi, edi                    ; check the 6 cells
.c: cmp edi, puzzlenode_w*2
    jge .found
    mov eax, [pairX]
    add eax, edi
    mov ebx, [pairY]
    cmp eax, [playerX]
    jne .e
    cmp ebx, [playerY]
    je .busy
.e: call enemy_at
    cmp eax, -1
    jne .busy
    inc edi
    jmp .c
.busy:
    inc dword [bI]
    jmp .row
.fallback:                          ; (never happens: the Warden and you can block 2 rows at most)
    mov dword [pairY], 6
.found:
    popad
    ret

warden_torch:
    cmp dword [wShield], 0
    je .r
    call puzzle_solved
    test eax, eax
    jz .r
    mov dword [wShield], 0
    mov dword [wTimer], 2
    call xp_trick
    msg msgShieldBreak
.r: ret

warden_reshield:                    ; the shield returns: a new gate, the torches leap across
    mov eax, [pairX]                ; remember where they were
    mov [rx], eax
    mov eax, [pairY]
    mov [ry], eax
    mov dword [rw], puzzlenode_w*2
    mov dword [rh], 1
    mov dword [wShield], 1
    call warden_gate
    xor dword [wSide], 1
    call warden_place
    call scramble_pair
    call redraw_area                ; the old spot is empty floor now
    call draw_room_objects
    xor ecx, ecx
    call draw_enemy                 ; his shield shows the new gate
    note msgBurn
    ret

; ---------------------------------------------------------------------
; filling a boss room (called by spawn_enemies)
; ---------------------------------------------------------------------
boss_spawn:
    xor eax, eax
    mov ecx, MAX_ENEMIES
    mov edi, empowered
    cld
    rep stosd
    xor eax, eax
    mov [noteLen], eax
    mov [wardUp], eax
    mov [keeperPhase], eax
    mov [bitsOn], eax
    mov [wTimer], eax
    mov [lanternT], eax
    mov [snuffCD], eax
    mov [exhaustR], eax
    mov [kingOpen], eax
    mov [kingStage], eax
    mov [kingDying], eax
    mov [isUnbound], eax
    mov [plaqueIdx], eax
    mov dword [wShield], 1
    mov ebx, [bossRoom]
    mov eax, [bossTypeOf+ebx*4]
    mov [enemyType], eax
    movzx eax, byte [bossStartX+ebx]
    mov [enemyX], eax
    movzx eax, byte [bossStartY+ebx]
    mov [enemyY], eax
    xor ecx, ecx
    call roll_hp
    cmp dword [bossRoom], 1         ; the first Warden (floor 4) is softer: 30-36 HP
    jne .hp
    cmp dword [floorCount], 4
    jg .hp
    mov eax, 7
    call rand_mod
    add eax, 30
    mov [enemyHP], eax
.hp:
    mov eax, [enemyHP]
    mov [bossMax], eax
    shr eax, 1
    mov [bossHalf], eax
    cmp dword [bossRoom], BR_KEEPER
    jne .bish
    jmp keeper2_spawn               ; the Keeper and its two Wardens (bosses2.inc)
.bish:
    cmp dword [bossRoom], BR_BISHOP
    jne .duo
    jmp bishop_spawn                ; the Four Bishops (bosses2.inc)
.duo:
    cmp dword [bossRoom], BR_DUO
    jne .r
    mov dword [enemyType+4], ETYPE_SMO
    mov dword [enemyX+4], 30
    mov dword [enemyY+4], 5
    mov ecx, 1
    call roll_hp
    mov eax, [enemyHP]
    mov [duoMax], eax
    mov eax, [enemyHP+4]
    mov [duoMax+4], eax
    mov dword [bitsOn], 1
    call coin
    mov [bitOwner], eax
.r: ret

first_warden_softer:                ; eax = damage rolled by enemy [eI] -> 3/4 of it for the floor 4 Warden   (keeps the rest)
    push ecx
    push edx
    mov ecx, [eI]
    cmp dword [enemyType+ecx*4], ETYPE_MINIBOSS
    jne .r
    cmp dword [floorCount], 4
    jg .r
    lea eax, [eax+eax*2]
    shr eax, 2
    cmp eax, 1
    jge .r
    mov eax, 1
.r: pop edx
    pop ecx
    ret

boss_loot:                          ; ecx = the enemy that just died: a boss leaves its legendary for your class
    pushad
    mov eax, [enemyType+ecx*4]
    mov ebx, -1
    cmp eax, ETYPE_MINIBOSS
    jne .s
    xor ebx, ebx                    ; the Warden: floor 4 or floor 8
    cmp dword [floorCount], 4
    jle .got
    mov ebx, 1
    jmp .got
.s: cmp eax, ETYPE_SHADE
    jne .y
    mov ebx, 2
.y: cmp eax, ETYPE_YMIR
    jne .k
    mov ebx, 3
.k: cmp eax, ETYPE_KEEPER
    jne .a
    mov ebx, 4
.a: cmp eax, ETYPE_ALTAIR
    jne .m
    mov ebx, 5
.m: cmp eax, ETYPE_SMO
    jne .got
    mov ebx, 6
.got:
    cmp ebx, -1
    je .r
    imul ebx, ebx, 12
    call class_index
    mov eax, [bossLoot+ebx+eax*4]
    mov [bossDrop], eax
.r: popad
    ret

announce_boss:                      ; the room message for bosses 4..6
    cmp dword [bossRoom], BR_YMIR
    jne .k
    msg msgYmir
    ret
.k: cmp dword [bossRoom], BR_KEEPER
    jne .bi
    msg msgKeeper2
    ret
.bi:cmp dword [bossRoom], BR_BISHOP
    jne .d
    msg msgBishops
    ret
.d: cmp dword [bossRoom], BR_DUO
    jne .r
    msg msgDuo
.r: ret

; ---------------------------------------------------------------------
; how bosses look (enemy_cell_char asks this for every cell)
; ---------------------------------------------------------------------
boss_sprite:                        ; esi = enemy type, ecx = enemy -> esi = the sprite to draw   (keeps the rest)
    cmp esi, ETYPE_KEEPER
    jne .w
    cmp dword [wardUp], 0
    jne .n
    mov esi, keeperOpenIcon         ; the ward is broken
    ret
.w: cmp esi, ETYPE_MINIBOSS
    jne .s
    push eax
    mov eax, [minibossIcon]
    mov [wardenBuf], eax
    mov eax, [minibossIcon+4]
    mov [wardenBuf+4], eax
    mov al, [minibossIcon+8]
    mov [wardenBuf+8], al
    call keeper_like
    jne .wsolo
    cmp dword [kLink+ecx*4-4], 0    ; a Keeper's Warden: its own gate while linked
    je .wd
    mov eax, [kGate+ecx*4-4]
    mov al, [gateLetter+eax]
    mov [wardenBuf+4], al
    jmp .wd
.wsolo:
    cmp dword [wShield], 0
    je .wd
    mov eax, [puzzleGate]
    mov al, [gateLetter+eax]
    mov [wardenBuf+4], al           ; the gate on his shield
.wd:
    pop eax
    mov esi, wardenBuf
    ret
.s: cmp esi, ETYPE_SHADE
    jne .a
    mov esi, shadeIcon
    cmp dword [lanternT], 0
    jne .sr
    call in_light
    jc .sr
    mov esi, shadeDarkIcon
.sr:
    ret
.a: cmp esi, ETYPE_ALTAIR
    jne .m
    mov esi, altairRageIcon
    cmp dword [empowered+ecx*4], 0
    jne .ar
    mov esi, altairIcon
    cmp dword [bitsOn], 0
    je .ar
    cmp ecx, [bitOwner]
    je .ar
    mov esi, altairZeroIcon
.ar:
    ret
.m: cmp esi, ETYPE_SMO
    jne .u
    mov esi, smoRageIcon
    cmp dword [empowered+ecx*4], 0
    jne .mr
    mov esi, smoIcon
    cmp dword [bitsOn], 0
    je .mr
    cmp ecx, [bitOwner]
    je .mr
    mov esi, smoZeroIcon
.mr:
    ret
.u: cmp esi, ETYPE_UNBOUND
    je .uz
    cmp esi, ETYPE_UCOPY
    jne .n
.uz:push eax
    push ecx
    push edx
    push edi
    push ebx
    mov ebx, unbound                ; his body (Z), or a copy's (z), at its current size ...
    mov edi, unboundBuf
    mov al, 'Z'
    cmp esi, ETYPE_UCOPY
    jne .ub
    mov ebx, ucopy
    mov edi, ucopyBuf
    mov al, 'z'
.ub:push edi
    movzx ecx, byte [ebx+ENEMY_W]
    movzx edx, byte [ebx+ENEMY_H]
    imul ecx, edx
    cld
    rep stosb
    pop edi
    movzx edx, byte [ebx+ENEMY_H]   ; ... with the form's letter in the middle cell
    shr edx, 1
    movzx eax, byte [ebx+ENEMY_W]
    imul edx, eax
    shr eax, 1
    add edx, eax
    add edi, edx
    mov ecx, [esp+12]               ; (the enemy, for the light test and the bit)
    mov eax, [uMode]
    cmp eax, UF_WARDEN
    jne .u1
    mov eax, [puzzleGate]
    mov al, [gateLetter+eax]
    jmp .uset
.u1:
    cmp eax, UF_YMIR
    jne .u2
    mov al, 'f'
    jmp .uset
.u2:
    cmp eax, UF_SHADE
    jne .u3
    mov al, 'D'
    cmp dword [lanternT], 0
    jne .uset
    mov al, 'd'
    call in_light
    jnc .uset
    mov al, 'D'
    jmp .uset
.u3:
    cmp eax, UF_BISHOP
    jne .u4
    mov al, 'q'                     ; (it doesn't tell you which one is the 1)
    jmp .uset
.u4:
    cmp eax, UF_KEEPER
    jne .u5
    mov al, 'W'
    cmp dword [wardUp], 0
    jne .uset
    mov al, 'w'
    jmp .uset
.u5:
    mov edx, [kingBit]              ; Altair & Smo: his bit; his copy carries the other one
    test ecx, ecx
    jz .u6
    xor edx, 1
.u6:mov al, '0'
    test edx, edx
    jz .uset
    mov al, '1'
.uset:
    mov [edi], al
    pop ebx
    pop edi
    pop edx
    pop ecx
    pop eax
    mov esi, unboundBuf
    cmp dword [enemyType+ecx*4], ETYPE_UCOPY
    jne .ur
    mov esi, ucopyBuf
.ur:ret
.n: mov esi, [enemySprites+esi*4]
    ret

; ---------------------------------------------------------------------
; damage: every hit on an enemy passes through here
; ---------------------------------------------------------------------
boss_cut:                           ; eax = damage about to hit enemy ecx -> eax after the boss's rules   (keeps the rest)
    push ebx
    push edx
    cmp dword [isUnbound], 0
    je .nu
    call unbound_cut                ; every form of the Unbound King
    jmp .r
.nu:
    mov ebx, [enemyType+ecx*4]
    cmp dword [bossRoom], BR_KEEPER
    jne .bsh
    call keeper2_cut                ; the Keeper and its Wardens (bosses2.inc)
    jmp .r
.bsh:
    cmp ebx, ETYPE_BISHOP
    jne .w
    call bishop_cut
    jmp .r
.w: cmp ebx, ETYPE_MINIBOSS
    jne .s
    cmp dword [wShield], 0
    je .r
    cmp dword [attackPierce], 0
    jne .r                          ; Gatebreaker and friends cut through
    shr eax, 1                      ; the gate shield halves it
    jmp .r
.s: cmp ebx, ETYPE_SHADE
    jne .y
    cmp dword [lanternT], 0
    jne .r                          ; the lantern: full damage
    call in_light
    jc .lit
    call near_your_light            ; a Lantern Charm / Duskplate lights the Shade up next to you
    jnc .zero                       ; darkness: nothing
.lit:
    shr eax, 1                      ; torch light: half
    jmp .r
.y: cmp ebx, ETYPE_YMIR
    jne .d
    cmp dword [exhaustR], 0
    je .r
    jmp .more
.d: cmp ebx, ETYPE_ALTAIR
    je .duo
    cmp ebx, ETYPE_SMO
    jne .k
.duo:
    cmp dword [bitsOn], 0
    je .r
    cmp ecx, [bitOwner]
    jne .more                       ; carrying the 0: +50%
    cmp dword [attackPierce], 0
    jne .r
    shr eax, 1                      ; carrying the 1: half
    jmp .r
.k: cmp ebx, ETYPE_KING
    jne .u
    jmp .zero                       ; on his throne he is immune: only the blue cannon torch hurts him
.u: jmp .r
.more:
    mov edx, eax
    shr edx, 1
    add eax, edx                    ; +50%
    jmp .r
.zero:
    xor eax, eax
.r: pop edx
    pop ebx
    ret

; ---------------------------------------------------------------------
; the room: Ymir's power torches are part of the map
; ---------------------------------------------------------------------
boss_glyph:                         ; eax=x, ebx=y -> al = '&' / '~' on a power torch, else 0   (keeps the rest)
    push eax
    call bishop_glyph               ; the gates between the bishops (bosses2.inc)
    test al, al
    jz .nb
    add esp, 4                      ; a bishop gate: al is the answer
    ret
.nb:pop eax                         ; (bishop_glyph cleared al: x must come back whole)
    cmp dword [bossRoom], 2         ; the King's blue cannon torch
    jne .nk
    cmp dword [isUnbound], 0
    jne .nk
    cmp dword [puzzleOn], 2
    jne .nk
    cmp eax, CANNON_X
    jne .nk
    cmp ebx, CANNON_Y
    jne .nk
    mov al, '}'
    ret
.nk:
    call ymir_layout
    jne .no
    cmp dword [puzzleOn], 2
    jne .no
    cmp eax, P1_X
    jne .no
    cmp ebx, P1_Y
    je .p1
    cmp ebx, P2_Y
    je .p2
.no:
    xor al, al
.ret:
    ret
.p1:
    mov al, '&'
    cmp byte [circVal+4], 0
    je .r
    mov al, '~'
.r: ret
.p2:
    mov al, '&'
    cmp byte [circVal+5], 0
    je .r
    mov al, '~'
    ret

boss_obstacle:                      ; eax=x, ebx=y -> CF=1 on a power torch   (keeps everything)
    push eax
    call boss_glyph
    test al, al
    pop eax
    jz .no
    stc
    ret
.no:
    clc
    ret

ymir_layout:                        ; ZF=1 if the room has Ymir's power torches (Ymir, or the Unbound's Ymir form)   (keeps all)
    cmp dword [bossRoom], BR_YMIR
    je .r
    cmp dword [isUnbound], 0
    je .nz
    cmp dword [uMode], UF_YMIR
    ret
.nz:
    cmp esp, 0                      ; (ZF=0)
.r: ret

boss_draw_objects:
    call bishop_draw_gates
    cmp dword [bossRoom], 2         ; the King's cannon
    jne .yl
    cmp dword [isUnbound], 0
    jne .yl
    pushad
    mov eax, CANNON_X
    mov ebx, CANNON_Y
    call cell_glyph
    call put_cell
    popad
.yl:
    call ymir_layout
    jne .r
    pushad
    mov eax, P1_X
    mov ebx, P1_Y
    call cell_glyph
    call put_cell
    mov eax, P2_X
    mov ebx, P2_Y
    call cell_glyph
    call put_cell
    popad
.r: ret

ymir_power:                         ; -> eax = lit power torches (0..2)
    xor eax, eax
    cmp byte [circVal+4], 0
    jne .b
    inc eax
.b: cmp byte [circVal+5], 0
    jne .r
    inc eax
.r: ret

; ---------------------------------------------------------------------
; a torch was flipped in a boss room (called by touch_node)
; ---------------------------------------------------------------------
boss_torch:
    mov eax, [bossRoom]
    cmp eax, 1
    jne .k
    call warden_torch
    jmp .d
.k: cmp eax, 2
    jne .s
    cmp dword [isUnbound], 0
    je .kt
    cmp dword [uMode], UF_KEEPER    ; the Unbound's Keeper form: the shadow Wardens' pairs
    jne .us
    call keeper2_torch
    jmp .d
.us:
    cmp dword [uMode], UF_SHADE     ; the Unbound's Shade form: the lantern
    jne .d
    call shade_torch
    jmp .d
.kt:
    call king_torch
    jmp .d
.s: cmp eax, 3
    jne .y
    call shade_torch
    jmp .d
.y: cmp eax, BR_YMIR
    jne .kp
    call ymir_torch
    jmp .d
.kp:
    cmp eax, BR_KEEPER
    jne .d
    call keeper2_torch
.d: call draw_room_objects
    call draw_enemies               ; (light and gate letters on the bosses may have changed)
    call draw_panel
    ret

boss_plaque:                        ; -> CF=1 if this boss room has its own plaque text
    mov eax, [bossRoom]
    cmp eax, BR_KEEPER
    jne .bp
    call keeper2_plaque
    stc
    ret
.bp:cmp eax, BR_BISHOP
    jne .w0
    msg plqBishops
    stc
    ret
.w0:
    cmp eax, 1
    jne .s
    msg plqWarden
    stc
    ret
.s: cmp eax, 3
    jne .y
    msg plqShade
    stc
    ret
.y: cmp eax, BR_YMIR
    jne .k
    msg plqYmir
    stc
    ret
.k: cmp eax, 2
    jne .no
    cmp dword [isUnbound], 0
    je .kk
    cmp dword [uMode], UF_KEEPER    ; the Unbound's Keeper form: the shadow Wardens' gates
    jne .no                         ; (otherwise his pair: the normal riddle)
    call keeper2_plaque
    stc
    ret
.kk:
    cmp dword [circHidden], -2
    je .hid
    msg plqThrone
    stc
    ret
.hid:                               ; every gate hidden: one riddle per read, in turn
    pushad
    call msg_begin
    mtext plqGate
    mov eax, [plaqueIdx]
    inc eax
    call msg_num
    mtext plqColon
    mov eax, [plaqueIdx]
    movzx eax, byte [circGT+eax]
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN
.t: cmp byte [esi+ecx-1], ' '
    jne .sk
    dec ecx
    jmp .t
.sk:
    cmp byte [esi], '-'             ; skip the gate's name
    je .past
    inc esi
    dec ecx
    jmp .sk
.past:
    add esi, 2
    sub ecx, 2
    call msg_text
    call msg_end
    mov eax, [plaqueIdx]
    inc eax
    cmp eax, [circNG]
    jl .st
    xor eax, eax
.st:
    mov [plaqueIdx], eax
    popad
    stc
    ret
.no:
    clc
    ret

; ---------------------------------------------------------------------
; the Logic Keeper
; ---------------------------------------------------------------------
keeper_torch:
    cmp dword [wardUp], 0
    je .r
    call puzzle_solved
    test eax, eax
    jz .r
    mov dword [wardUp], 0
    call xp_trick
    cmp dword [enemyHP], 0
    jle .r
    movzx eax, byte [statusDur+EFFECT_PRONE]
    shl eax, 1                      ; it staggers for two rounds
    mov [statusTimer+EFFECT_PRONE], al
    msg msgWardBreak
.r: ret

keeper_phase2:                      ; at half HP: a new gate, new torches, and the ward is back
    mov dword [keeperPhase], 2
    call setup_room
    mov eax, [pairX]
    mov [rx], eax
    mov eax, [pairY]
    mov [ry], eax
    mov dword [rw], puzzlenode_w*2
    mov dword [rh], MAX_PAIRS*NODE_DY
    call redraw_area
    call draw_room_objects
    mov dword [wardUp], 1
    xor ecx, ecx
    call draw_enemy
    note msgWardUp
    ret

; ---------------------------------------------------------------------
; the Dark Shade
; ---------------------------------------------------------------------
shade_torch:
    cmp dword [lanternT], 0
    jne .r
    cmp dword [circOut], 0
    je .r
    mov dword [lanternT], 2         ; the lantern burns for two rounds
    call xp_trick
    msg msgLantern
.r: ret

shade_round:
    cmp dword [enemyHP], 0
    jle .r
    cmp dword [lanternT], 0
    je .snuff
    dec dword [lanternT]
    jnz .r
    mov eax, CT_S                   ; the lantern breaks: new gates, torches set dark again
    call circ_boss_setup
    call circ_draw
    xor ecx, ecx
    call draw_enemy
    note msgShatter
    ret
.snuff:
    cmp dword [snuffCD], 0
    je .look
    dec dword [snuffCD]
    ret
.look:
    xor ecx, ecx
    mov dword [bI], 0
.l: mov eax, [bI]
    cmp eax, [circNT]
    jge .r
    cmp byte [nodeBit+eax], 0
    je .n
    call rect_dist
    cmp eax, 1
    jg .n
    mov eax, [bI]                   ; next to a lit torch: out it goes
    mov byte [nodeBit+eax], 0
    call circ_eval
    call draw_room_objects
    xor ecx, ecx
    call draw_enemy
    mov dword [snuffCD], 2
    cmp dword [circOut], 0
    je .quiet
    mov dword [lanternT], 2         ; with NAND / NOR gates, darkness lights the lantern!
    call circ_draw
    note msgSnuffLit
    ret
.quiet:
    note msgSnuff
    ret
.n: inc dword [bI]
    jmp .l
.r: ret

boss_move:                          ; ecx = enemy, esi = its row: CF=1 if this boss moved its own way   (keeps everything)
    pushad
    cmp dword [enemyType+ecx*4], ETYPE_SHADE
    jne .no
    cmp dword [lanternT], 0
    jne .no                         ; while the lantern burns it just fights
    mov dword [bBest], 999          ; the nearest lit torch
    mov dword [bTmp], -1
    mov dword [bI], 0
.l: mov eax, [bI]
    cmp eax, [circNT]
    jge .pick
    cmp byte [nodeBit+eax], 0
    je .n
    call rect_dist
    cmp eax, [bBest]
    jge .n
    mov [bBest], eax
    mov eax, [bI]
    mov [bTmp], eax
.n: inc dword [bI]
    jmp .l
.pick:
    cmp dword [bTmp], -1
    je .no                          ; no light anywhere: hunt you instead
    cmp dword [bBest], 1
    jle .yes                        ; already beside it: wait to snuff it
    mov eax, [bTmp]
    call torch_pos
    inc eax                         ; aim at the middle of the torch
    mov [aimX], eax
    mov [aimY], edx
    mov [eI], ecx
    call enemy_step_toward_aim
.yes:
    popad
    stc
    ret
.no:
    popad
    clc
    ret

enemy_step_toward_aim:              ; enemy [eI] takes one step, aiming its middle at [aimX],[aimY]
    mov ecx, [eI]
    call enemy_rec
    movzx edx, byte [esi+ENEMY_W]
    shr edx, 1
    mov ebx, [aimX]
    sub ebx, edx
    mov eax, [enemyX+ecx*4]
    call step_toward
    mov [nX], eax
    mov ecx, [eI]
    call enemy_rec
    movzx edx, byte [esi+ENEMY_H]
    shr edx, 1
    mov ebx, [aimY]
    sub ebx, edx
    mov eax, [enemyY+ecx*4]
    call step_toward
    mov [nY], eax
    jmp enemy_try_step

; ---------------------------------------------------------------------
; Grand Wizard Ymir
; ---------------------------------------------------------------------
ymir_torch:
    cmp dword [exhaustR], 0
    jne .r
    call ymir_power
    test eax, eax
    jnz .r
    cmp dword [enemyHP], 0
    jle .r
    call xp_trick
    mov dword [exhaustR], 2         ; stunned through his next turn, +50% damage until the wave
    movzx eax, byte [statusDur+EFFECT_PRONE]
    shl eax, 1
    mov [statusTimer+EFFECT_PRONE], al
    msg msgSpent
.r: mov eax, P1_X                   ; show the power torches as they are now
    mov ebx, P1_Y
    call cell_glyph
    call put_cell
    mov eax, P2_X
    mov ebx, P2_Y
    call cell_glyph
    call put_cell
    ret

ymir_round:
    cmp dword [exhaustR], 0
    je .r
    dec dword [exhaustR]
    jnz .r
    cmp dword [enemyHP], 0
    jle .r
    ; the blue wave: heavy damage if you are close, then a push away from him
    mov eax, CT_Y
    call circ_boss_setup            ; new gates, both power torches lit again
    mov eax, msgWave
    mov ecx, msgWavelen
    mov esi, eax
    call note_set
    xor ecx, ecx
    call dist_to_player
    cmp eax, 2
    jg .push
    mov eax, 7
    call rand_mod
    add eax, 10                     ; 10..16
    call absorb_damage
    sub [playerHP], eax
    push eax
    mov esi, msgWaveHit
    mov ecx, msgWaveHitlen
    call note_set
    pop eax
    call note_num
.push:
    mov eax, [enemyX]               ; his middle
    add eax, 2
    mov ebx, [enemyY]
    add ebx, 2
    push ebx
    mov eax, [playerX]              ; direction away from him: the sign of (you - his middle)
    sub eax, [enemyX]
    sub eax, 2
    call sign
    mov [aimX], eax
    pop ebx
    mov eax, [playerY]
    sub eax, ebx
    call sign
    mov [aimY], eax
    mov eax, [aimX]
    or eax, [aimY]
    jnz .go
    mov dword [aimX], -1
.go:
    mov dword [bI], 4               ; up to 4 cells
.step:
    mov eax, [playerX]
    add eax, [aimX]
    mov ebx, [playerY]
    add ebx, [aimY]
    cmp eax, GRID_W
    jae .stop
    cmp ebx, GRID_H
    jae .stop
    call obstacle_at
    jc .stop
    push eax
    call enemy_at
    cmp eax, -1
    pop eax
    jne .stop
    mov [playerX], eax
    mov [playerY], ebx
    dec dword [bI]
    jnz .step
.stop:
    mov dword [moving], 0
    call redraw_all
    call player_dead_check
.r: ret

ymir_act:                           ; enemy [eI] is Ymir: blink if you are next to him, then 2 spells per lit power torch
    mov dword [blinked], 0
    mov dword [castFirst], 1
    mov ecx, [eI]
    call dist_to_player
    cmp eax, 1
    jg .cast
    mov dword [tries], 40           ; blink: a random free spot at least 6 columns from you
.bl:
    mov eax, 31
    call rand_mod
    add eax, 10
    mov [nX], eax
    mov eax, GRID_H - 3
    call rand_mod
    mov [nY], eax
    mov eax, [nX]
    sub eax, [playerX]
    cdq
    xor eax, edx
    sub eax, edx
    cmp eax, 6
    jl .again
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    mov [oldBX], eax
    mov eax, [enemyY+ecx*4]
    mov [oldBY], eax
    call enemy_move_to
    mov ecx, [eI]
    mov eax, [enemyX+ecx*4]
    cmp eax, [oldBX]
    jne .moved
    mov eax, [enemyY+ecx*4]
    cmp eax, [oldBY]
    jne .moved
.again:
    dec dword [tries]
    jnz .bl
    jmp .cast
.moved:
    mov dword [blinked], 1
.cast:
    mov ecx, [eI]
    call dist_to_player
    cmp eax, YMIR_REACH
    jg .r
    call ymir_power
    shl eax, 1                      ; 2 strikes per lit power torch
    mov [bI], eax
.c: cmp dword [bI], 0
    je .r
    call ymir_cast
    dec dword [bI]
    jmp .c
.r: ret

ymir_cast:                          ; one spell: "Wizard Ymir casts Firebolt 4, Lightning miss, ..."
    mov eax, 4
    call rand_mod
    mov [castN], eax
    cmp dword [castFirst], 0
    je .later
    mov dword [castFirst], 0
    cmp dword [atkCount], 0
    jne .more
    call msg_begin
    jmp .name
.more:
    mtext msgComma2
.name:
    inc dword [atkCount]
    mov ecx, [eI]
    mov eax, [enemyType+ecx*4]
    imul esi, eax, NAME_LEN
    add esi, enemyNames
    call print_name
    cmp dword [blinked], 0
    je .c
    mtext msgBlinks
.c: mtext msgCasts
    jmp .spell
.later:
    mtext msgComma2
.spell:
    mov esi, [castN]
    imul esi, esi, YSPELL_LEN
    add esi, ymirSpellNames
    call print_name
    mov ecx, [eI]
    call enemy_rec
    movzx ebx, byte [esi+ENEMY_ATK_BONUS]
    call enemy_hit_roll
    jc .miss
    mov eax, [castN]
    movzx ebx, byte [ymirDmg+eax*2]
    movzx eax, byte [ymirDmg+eax*2+1]
    sub eax, ebx
    inc eax
    call rand_mod
    add eax, ebx
    mov ebx, [floorCount]           ; + floor/8
    shr ebx, 3
    add eax, ebx
    call absorb_damage
    sub [playerHP], eax
    push eax
    mtext msgSp
    pop eax
    call msg_num
    ret
.miss:
    mtext msgYMiss
    ret

; ---------------------------------------------------------------------
; Altair and Smo
; ---------------------------------------------------------------------
duo_check:                          ; ecx = the enemy that just died
    pushad
    cmp dword [bossRoom], BR_DUO
    jne .r
    mov dword [bitsOn], 0           ; the NOT link breaks
    mov edx, ecx
    xor edx, 1
    cmp dword [enemyHP+edx*4], 0
    jle .r
    cmp dword [empowered+edx*4], 0
    jne .r
    mov dword [empowered+edx*4], 1
    mov eax, [duoMax+edx*4]
    mov [enemyHP+edx*4], eax        ; back to full health
    mov esi, msgSmoRise
    mov ecx, msgSmoRiselen
    cmp edx, 1
    je .s
    mov esi, msgAltRise
    mov ecx, msgAltRiselen
.s: call note_set
    mov ecx, edx
    call draw_enemy
.r: popad
    ret

duo_round:
    cmp dword [bitsOn], 0
    je .r
    call coin                       ; 50%: the 1 and the 0 swap
    test eax, eax
    jz .r
    xor dword [bitOwner], 1
    xor ecx, ecx
    call draw_enemy
    mov ecx, 1
    call draw_enemy
    call draw_panel
.r: ret

; ---------------------------------------------------------------------
; the Forgotten King
; ---------------------------------------------------------------------
king_torch:                         ; a torch flipped: does the circuit power the blue cannon torch?
    cmp dword [isUnbound], 0
    jne .r
    cmp dword [kingDying], 0
    jne .r
    cmp dword [circOut], 0
    je .r
    pushad
    mov eax, [bossMax]              ; the blast: a sixth of his health (rounded up: 6 blasts)
    add eax, 5
    xor edx, edx
    mov ebx, 6
    div ebx
    mov [bTmp], eax
    call xp_trick
    call msg_begin
    mtext msgBlast
    mov eax, [bTmp]
    call msg_num
    mtext msgBlastEnd
    call msg_end
    call king_scramble              ; the cannon is spent: the torches go dark (unsolved) again
    mov eax, [bTmp]
    sub [enemyHP], eax
    cmp dword [enemyHP], 0
    jg .alive
    mov dword [eIdx], 0
    call kill_enemy                 ; (he only pretends to die: king_fall)
    jmp .d
.alive:
    xor ecx, ecx
    call draw_enemy
.d: call draw_panel
    popad
.r: ret

king_scramble:                      ; new torch settings that leave the cannon unpowered
    pushad
    mov dword [circTry], 200
.st:xor edx, edx
.sb:cmp edx, [circNT]
    jge .se
    push edx
    call coin
    pop edx
    mov [nodeBit+edx], al
    inc edx
    jmp .sb
.se:call circ_eval
    cmp dword [circOut], 0
    je .ok
    dec dword [circTry]
    jnz .st
.ok:call circ_draw
    call draw_room_objects
    popad
    ret

king_rewire:                        ; eax = 0: new gates, 1: new gates, all hidden
    push eax
    mov eax, CT_K
    call circ_boss_setup
    pop eax
    test eax, eax
    jz .sh
    mov dword [circHidden], -2
    mov dword [plaqueIdx], 0
.sh:
    mov dword [kingOpen], 0
    call circ_draw
    ret

king_fall:                          ; ecx = the King: his "death"
    mov dword [enemyHP+ecx*4], 1
    cmp dword [kingDying], 0
    jne .r
    mov dword [kingDying], 1
    call xp_for_kill                ; his "death" is worth its XP
    mov dword [dyingT], 30          ; about 3 seconds of silence
    imul edi, ecx, STAT_STRIDE      ; no burning, no poison: just lying there
    add edi, statusTimer
    xor eax, eax
    push ecx
    mov ecx, STAT_STRIDE
    cld
    rep stosb
    pop ecx
    imul edi, ecx, STAT_STRIDE
    mov byte [statusTimer+edi+EFFECT_PRONE], 255
    note msgFallen
.r: ret

king_rise:                          ; the throne explodes; he rises as the Unbound King
    mov dword [kingDying], 0
    mov dword [isUnbound], 1
    mov dword [uDead], 0
    mov dword [uExtras], 0
    mov dword [enemyType], ETYPE_UNBOUND
    mov eax, 38                     ; stand on the side away from you
    cmp dword [playerX], 25
    jl .x
    mov eax, 6
.x: mov [enemyX], eax
    mov dword [enemyY], 3
    mov edi, statusTimer
    xor eax, eax
    mov ecx, STAT_STRIDE
    cld
    rep stosb
    xor ecx, ecx
    call roll_hp
    mov eax, [enemyHP]
    mov [bossMax], eax
    mov dword [uHits], 0
    mov dword [uSwitch], 0
    mov dword [circNT], 0
    mov dword [circNG], 0
    mov dword [circNW], 0
    mov dword [uMode], UF_COUNT-1   ; (enter the first form, the Warden, below)
    call unbound_next_mode
    call coin
    mov [kingBit], eax
    call redraw_all
    note msgUnbound
    mov dword [modeNoteLater], 1    ; his first trick is announced a moment later
    ret

unbound_set_size:                   ; his body, reach and speed become the imitated boss's   (keeps all)
    pushad
    mov eax, [uMode]
    lea esi, [uFormStats+eax*4]
    mov al, [esi]
    mov [unbound+ENEMY_W], al
    mov al, [esi+1]
    mov [unbound+ENEMY_H], al
    mov al, [esi+2]
    mov [unbound+ENEMY_RANGE], al
    mov al, [esi+3]
    mov [unbound+ENEMY_MOVE], al
    popad
    ret

unbound_next_mode:                  ; the next form: the room shakes and becomes that boss's arena
    call unbound_clear_extras       ; the last form's copies and Wardens fade
    mov eax, [uMode]
    inc eax
    cmp eax, UF_COUNT
    jb .m
    xor eax, eax
.m: mov [uMode], eax
    call unbound_set_size
    mov dword [uHits], 0
    mov dword [lanternT], 0
    mov dword [wardUp], 0
    mov dword [circNT], 0
    mov dword [circNG], 0
    mov dword [circNW], 0
    mov eax, [uMode]
    cmp eax, UF_BISHOP
    je .bish
    cmp eax, UF_SHADE
    je .shade
    cmp eax, UF_YMIR
    je .ymir
    cmp eax, UF_KEEPER
    je .keep
    cmp eax, UF_DUO
    je .duo
    mov dword [puzzleOn], 1         ; the Warden's hall - one pair, on the side away from him
    mov dword [puzzlePairs], 1
    mov dword [puzzleAll], 0
    mov dword [wSide], 0
    cmp dword [enemyX], 22
    jl .ws
    mov dword [wSide], 1
.ws:
    mov eax, GATE_COUNT
    call rand_mod
    mov [puzzleGate], eax
    call warden_place
    call scramble_pair
    jmp .placed
.bish:                              ; the Bishops' chapel - he and three copies in the corners
    mov dword [puzzleOn], 0
    call unbound_bishops
    call unbound_nudge_player       ; (the corners are fixed: only you step aside)
    jmp .say
.shade:                             ; the Shade's dark - its circuit and the lantern
    mov eax, CT_S
    call circ_boss_setup
    jmp .placed
.ymir:                              ; Ymir's tower - his circuit and both power torches
    mov eax, CT_Y
    call circ_boss_setup
    jmp .placed
.keep:                              ; the Keeper's vault - two shadow Wardens and their pairs
    call unbound_keeper
    jmp .placed
.duo:                               ; Altair & Smo - two of him, the bit, no torches at all
    call unbound_duo
    jmp .say
.placed:
    call unbound_nudge              ; nobody stands inside the new things
.say:
    call redraw_all
    mov eax, [uMode]
    mov esi, [modeMsgs+eax*4]
    mov ecx, [modeLens+eax*4]
    call note_set
    ret

unbound_clear_stat:                 ; ecx = enemy: forget its statuses   (keeps all)
    pushad
    imul edi, ecx, STAT_STRIDE
    add edi, statusTimer
    xor eax, eax
    mov ecx, STAT_STRIDE
    cld
    rep stosb
    popad
    ret

unbound_bishops:                    ; enemy i stands in corner (i + bishRot) & 3; enemies 1..3 are copies of him
    pushad
    mov esi, uFormStats+UF_BISHOP*4 ; (2x2, they never move, they cast across the room)
    call unbound_copy_stats
    mov eax, 4
    call rand_mod
    mov [bishRot], eax
    mov ebx, eax
    xor ecx, ecx
.l: cmp ecx, 4
    jge .hp
    lea edx, [ecx+ebx]
    and edx, 3
    mov edi, [bishCX+edx*4]
    mov [enemyX+ecx*4], edi
    mov edi, [bishCY+edx*4]
    mov [enemyY+ecx*4], edi
    test ecx, ecx
    jz .n
    mov dword [enemyType+ecx*4], ETYPE_UCOPY
    mov edi, [enemyHP]              ; every copy shows his health (one shared pool)
    mov [enemyHP+ecx*4], edi
    call unbound_clear_stat
.n: inc ecx
    jmp .l
.hp:
    mov dword [uExtras], 3
    mov eax, [enemyHP]
    mov [bishPool], eax
    xor eax, eax
    mov [bishFound], eax
    mov [bishReset], eax
    mov [bishSpell], eax
    mov [bishActed], eax
    mov [bishOne], eax
    mov [bishOne+4], eax
    mov [bishOne+8], eax
    mov [bishOne+12], eax
    mov eax, 4
    call rand_mod
    mov dword [bishOne+eax*4], 1
    call bishop_gates
    popad
    ret

unbound_keeper:                     ; two shadow Wardens (enemies 1 and 2), each with its own torch pair
    pushad
    call keeper2_setup
    mov dword [enemyType+4], ETYPE_MINIBOSS
    mov dword [enemyX+4], 22
    mov dword [enemyY+4], 1
    mov dword [enemyType+8], ETYPE_MINIBOSS
    mov dword [enemyX+8], 22
    mov dword [enemyY+8], 9
    mov eax, [floorCount]           ; shadows: weaker than the real thing
    add eax, 15
    mov [enemyHP+4], eax
    mov [enemyHP+8], eax
    mov ecx, 1
    call unbound_clear_stat
    mov ecx, 2
    call unbound_clear_stat
    mov dword [uExtras], 2
    mov dword [kLink], 1
    mov dword [kLink+4], 1
    mov dword [kCut], 0
    mov dword [kCut+4], 0
    xor ecx, ecx
    call keeper2_newgate
    mov ecx, 1
    call keeper2_newgate
    call keeper2_ward
    popad
    ret

unbound_clear_extras:               ; his copies / shadow Wardens vanish from the map
    pushad
    mov ecx, 1
.l: cmp ecx, [uExtras]
    jg .d
    mov dword [enemyHP+ecx*4], 0
    call unbound_clear_stat
    call set_area_to_enemy
    call redraw_area
    inc ecx
    jmp .l
.d: mov dword [uExtras], 0
    mov dword [wardUp], 0
    mov dword [kLink], 0
    mov dword [kLink+4], 0
    mov dword [bishRot], 0
    popad
    ret

unbound_kill:                       ; kill_enemy, enemy ecx while he is Unbound -> CF=1: nothing more to do
    cmp dword [uDead], 0
    jne .done
    test ecx, ecx
    jz .him
    cmp dword [enemyType+ecx*4], ETYPE_UCOPY
    je .him                         ; a copy took the last of the shared health: it was him all along
    pushad                          ; a shadow Warden falls: gone for good (no XP, no loot)
    mov dword [enemyHP+ecx*4], 0
    call unbound_clear_stat
    call set_area_to_enemy
    call redraw_area
    mov dword [kLink+ecx*4-4], 0
    mov dword [kCut+ecx*4-4], 0
    mov eax, [wardUp]
    call keeper2_ward
    cmp eax, 0
    je .w
    cmp dword [wardUp], 0
    jne .w
    msg msgKeepOpen
.w: xor ecx, ecx
    call draw_enemy
    call draw_panel
    popad
.done:
    stc
    ret
.him:
    mov dword [uDead], 1
    call unbound_clear_extras
    mov dword [eIdx], 0
    clc
    ret

unbound_cut:                        ; eax = damage about to hit enemy ecx while he is Unbound -> eax   (keeps the rest)
    push edx
    mov edx, [uMode]
    cmp edx, UF_BISHOP
    jne .k
    call bishop_cut                 ; only a 1 can be hurt (his copies share his health)
    jmp .count
.k: cmp edx, UF_KEEPER
    jne .solo
    call keeper2_cut                ; immune while a shadow Warden is linked
    test ecx, ecx
    jnz .r
    jmp .count
.solo:
    cmp edx, UF_DUO
    je .b
    test ecx, ecx
    jnz .r
    cmp edx, UF_WARDEN
    jne .s
    push eax                        ; gate shield: half unless the pair matches his gate
    push ecx
    call puzzle_solved
    mov edx, eax
    pop ecx
    pop eax
    test edx, edx
    jnz .count
    cmp dword [attackPierce], 0
    jne .count
    shr eax, 1
    jmp .count
.s: cmp edx, UF_SHADE
    jne .y
    cmp dword [lanternT], 0
    jne .count                      ; the lantern burns: full damage
    call near_your_light            ; darkness: only a light you carry, and only half
    jnc .uz
    shr eax, 1
    jmp .count
.uz:xor eax, eax
    jmp .r
.y: cmp edx, UF_YMIR
    jne .b
    push eax
    call ymir_power
    mov edx, eax
    pop eax
    test edx, edx
    jz .more                        ; both power torches out: +50%
    jmp .count
.b: mov edx, [kingBit]               ; Altair & Smo: his bit, and the opposite on his copy
    test ecx, ecx
    jz .bb
    xor edx, 1
.bb:test edx, edx
    jz .bm
    cmp dword [attackPierce], 0
    jne .bs
    shr eax, 1                      ; the 1: half
    jmp .bs
.bm:mov edx, eax                    ; the 0: +50%
    shr edx, 1
    add eax, edx
.bs:call unbound_share              ; one shared health
    jmp .count
.more:
    mov edx, eax
    shr edx, 1
    add eax, edx
.count:                             ; really wounded 3 times in one form: he changes (at the next tick)
    test eax, eax
    jz .r
    inc dword [uHits]
    cmp dword [uHits], 3
    jl .r
    mov dword [uSwitch], 1
.r: pop edx
    ret

keeper_like:                        ; ZF=1 in the Keeper's room or the Unbound's Keeper form   (keeps all)
    cmp dword [bossRoom], BR_KEEPER
    je .r
    cmp dword [isUnbound], 0
    je .nz
    cmp dword [uMode], UF_KEEPER
    ret
.nz:
    cmp esp, 0
.r: ret

bishop_like:                        ; ZF=1 in the Bishops' room or the Unbound's Bishop form   (keeps all)
    cmp dword [bossRoom], BR_BISHOP
    je .r
    cmp dword [isUnbound], 0
    je .nz
    cmp dword [uMode], UF_BISHOP
    ret
.nz:
    cmp esp, 0
.r: ret

body_fits:                          ; eax=x, ebx=y: would enemy [bfE]'s body fit with its top-left there? CF=1 = no
    pushad
    mov [bfX], eax
    mov [bfY], ebx
    mov ecx, [bfE]
    call enemy_rec
    movzx eax, byte [esi+ENEMY_W]
    mov [ew], eax
    movzx eax, byte [esi+ENEMY_H]
    mov [eh], eax
    mov [ignoreE], ecx
    mov dword [emy], 0
.yl: mov eax, [emy]
    cmp eax, [eh]
    jge .yes
    mov dword [emx], 0
.xl: mov eax, [emx]
    cmp eax, [ew]
    jge .ny
    mov eax, [bfX]
    add eax, [emx]
    mov ebx, [bfY]
    add ebx, [emy]
    cmp eax, GRID_W
    jae .no
    cmp ebx, GRID_H
    jae .no
    cmp eax, [playerX]
    jne .np
    cmp ebx, [playerY]
    je .no
.np: call obstacle_at
    jc .no
    call enemy_at
    cmp eax, -1
    jne .no
    inc dword [emx]
    jmp .xl
.ny: inc dword [emy]
    jmp .yl
.yes:
    mov dword [ignoreE], -1
    popad
    clc
    ret
.no:
    mov dword [ignoreE], -1
    popad
    stc
    ret

place_body:                         ; ecx = enemy, eax,ebx = where we'd like its top-left: the nearest spot it fits
    pushad
    mov [bfE], ecx
    mov [aimX], eax
    mov [aimY], ebx
    call body_fits
    jnc .set
    mov dword [nuR], 1
.r: cmp dword [nuR], 14
    jg .d
    mov edi, [nuR]
    neg edi
.y: cmp edi, [nuR]
    jg .rn
    mov esi, [nuR]
    neg esi
.x: cmp esi, [nuR]
    jg .yn
    mov eax, esi                    ; only the ring at distance r
    cdq
    xor eax, edx
    sub eax, edx
    push eax
    mov eax, edi
    cdq
    xor eax, edx
    sub eax, edx
    mov ebx, eax
    pop eax
    cmp eax, [nuR]
    je .ring
    cmp ebx, [nuR]
    jne .xn
.ring:
    mov eax, [aimX]
    add eax, esi
    mov ebx, [aimY]
    add ebx, edi
    call body_fits
    jnc .set
.xn:inc esi
    jmp .x
.yn:inc edi
    jmp .y
.rn:inc dword [nuR]
    jmp .r
.set:
    mov ecx, [bfE]
    mov [enemyX+ecx*4], eax
    mov [enemyY+ecx*4], ebx
.d: mov dword [bfE], 0
    popad
    ret

unbound_copy_stats:                 ; esi = width, height, reach, move: his copies take them   (keeps all)
    push eax
    mov al, [esi]
    mov [ucopy+ENEMY_W], al
    mov al, [esi+1]
    mov [ucopy+ENEMY_H], al
    mov al, [esi+2]
    mov [ucopy+ENEMY_RANGE], al
    mov al, [esi+3]
    mov [ucopy+ENEMY_MOVE], al
    pop eax
    ret

unbound_duo:                        ; Altair & Smo: he becomes one of them and a copy of him the other
    pushad
    mov dword [puzzleOn], 0
    call coin
    mov [kingBit], eax              ; his bit (the copy carries the other)
    call coin
    mov [uDuoBig], eax
    mov esi, duoHeavy               ; (unbound_set_size made him the quick one)
    test eax, eax
    jz .cp
    mov al, [duoHeavy]              ; he is the heavy one ...
    mov [unbound+ENEMY_W], al
    mov al, [duoHeavy+1]
    mov [unbound+ENEMY_H], al
    mov al, [duoHeavy+2]
    mov [unbound+ENEMY_RANGE], al
    mov al, [duoHeavy+3]
    mov [unbound+ENEMY_MOVE], al
    mov esi, uFormStats+UF_DUO*4    ; ... and his copy the quick one
.cp:call unbound_copy_stats
    call unbound_nudge              ; he fits, you step aside ...
    mov dword [enemyType+4], ETYPE_UCOPY
    mov eax, [enemyHP]              ; ... then his copy appears beside him (one shared health)
    mov [enemyHP+4], eax
    mov ecx, 1
    call unbound_clear_stat
    mov dword [uExtras], 1
    mov eax, [enemyX]
    add eax, 6
    cmp eax, 44
    jl .x
    mov eax, [enemyX]
    sub eax, 6
.x: mov ebx, [enemyY]
    mov dword [enemyX+4], -60       ; (off the map while it looks for a spot)
    mov dword [enemyY+4], -60
    mov ecx, 1
    call place_body
    call unbound_nudge_player
    popad
    ret

unbound_share:                      ; eax = damage about to hit body ecx: every body shows the shared health   (keeps all)
    pushad
    mov ebx, [enemyHP]
    sub ebx, eax                    ; his health after the hit
    xor edx, edx
.l: cmp edx, [uExtras]
    jg .d
    cmp dword [enemyHP+edx*4], 0
    jle .n
    mov [enemyHP+edx*4], ebx
.n: inc edx
    jmp .l
.d: add [enemyHP+ecx*4], eax        ; (the caller takes the damage off the one it hit)
    popad
    ret

unbound_nudge:                      ; move the Unbound, then you, out of anything the new room put there
    pushad
    mov eax, [playerX]              ; 1) him: the nearest place his whole body fits
    mov [nuPX], eax                 ;    (you don't block him while he looks: you move next)
    mov dword [playerX], -100
    mov eax, [enemyX]
    mov ebx, [enemyY]
    call body_fits
    jnc .him_ok
    mov dword [nuR], 1
.hr: cmp dword [nuR], 14
    jg .him_ok
    mov edi, [nuR]
    neg edi
.hy: cmp edi, [nuR]
    jg .hrn
    mov esi, [nuR]
    neg esi
.hx: cmp esi, [nuR]
    jg .hyn
    mov eax, esi                    ; only the ring at distance r
    cdq
    xor eax, edx
    sub eax, edx
    mov ebx, edi
    push eax
    mov eax, ebx
    cdq
    xor eax, edx
    sub eax, edx
    mov ebx, eax
    pop eax
    cmp eax, [nuR]
    je .ring
    cmp ebx, [nuR]
    jne .hxn
.ring:
    mov eax, [enemyX]
    add eax, esi
    mov ebx, [enemyY]
    add ebx, edi
    call body_fits
    jc .hxn
    mov [enemyX], eax
    mov [enemyY], ebx
    jmp .him_ok
.hxn: inc esi
    jmp .hx
.hyn: inc edi
    jmp .hy
.hrn: inc dword [nuR]
    jmp .hr
.him_ok:
    mov eax, [nuPX]                 ; 2) you: the nearest free cell
    mov [playerX], eax
    popad
unbound_nudge_player:               ; you: step to the nearest free cell if something stands on you
    pushad
    mov eax, [playerX]
    mov ebx, [playerY]
    call cell_free
    jnc .done
    mov dword [nuR], 1
.pr: cmp dword [nuR], 12
    jg .done
    mov edi, [nuR]
    neg edi
.py: cmp edi, [nuR]
    jg .prn
    mov esi, [nuR]
    neg esi
.px: cmp esi, [nuR]
    jg .pyn
    mov eax, [playerX]
    add eax, esi
    mov ebx, [playerY]
    add ebx, edi
    call cell_free
    jc .pxn
    mov [playerX], eax
    mov [playerY], ebx
    jmp .done
.pxn: inc esi
    jmp .px
.pyn: inc edi
    jmp .py
.prn: inc dword [nuR]
    jmp .pr
.done:
    mov dword [moving], 0
    popad
    ret

cell_free:                          ; eax=x, ebx=y -> CF=1 if you can't stand there   (keeps all)
    pushad
    cmp eax, GRID_W
    jae .no
    cmp ebx, GRID_H
    jae .no
    call obstacle_at
    jc .no
    call enemy_at
    cmp eax, -1
    jne .no
    popad
    clc
    ret
.no:
    popad
    stc
    ret

unbound_round:
    call coin
    mov [kingBit], eax
    mov dword [bishActed], 0        ; the Bishop form: a new volley next turn
    cmp dword [uMode], UF_KEEPER
    jne .sh
    jmp keeper2_round               ; the Keeper form: cut links count down, then join again
.sh:
    cmp dword [uMode], UF_SHADE     ; the Shade form: the lantern burns for two rounds, then new gates
    jne .d
    cmp dword [lanternT], 0
    je .d
    dec dword [lanternT]
    jnz .d
    mov eax, CT_S
    call circ_boss_setup
    call unbound_nudge
    call redraw_all
.d: xor ecx, ecx
    call draw_enemy
    call draw_panel
    ret

unbound_act:                        ; enemy [eI]: one strike, or 1 + lit torches while he drinks their light
    cmp dword [uMode], UF_BISHOP
    jne .nb
    jmp bishop_act                  ; the Bishop form: the volley of all four
.nb:
    mov dword [bI], 1
    cmp dword [uMode], UF_YMIR
    jne .l
    call ymir_power                 ; Ymir form: one strike more per lit power torch
    inc eax
    mov [bI], eax
.l: cmp dword [bI], 0
    je .r
    mov ecx, [eI]
    call dist_to_player
    call enemy_rec
    movzx edx, byte [esi+ENEMY_RANGE]
    cmp eax, edx
    jg .r
    movzx ebx, byte [esi+ENEMY_ATK_BONUS]
    call enemy_hit_roll
    jc .miss
    mov ecx, [eI]
    call enemy_rec
    movzx eax, byte [esi+ENEMY_DMG_MAX]
    movzx ebx, byte [esi+ENEMY_DMG_MIN]
    sub eax, ebx
    inc eax
    call rand_mod
    add eax, ebx
    push eax
    mov eax, [floorCount]           ; + floor/5
    xor edx, edx
    mov ebx, 5
    div ebx
    pop ebx
    add eax, ebx
    call absorb_damage
    sub [playerHP], eax
    mov ecx, [eI]
    call say_enemy_attack
    mov eax, 1
    call attack_note
    jmp .n
.miss:
    mov ecx, [eI]
    mov eax, -1
    call say_enemy_attack
    xor eax, eax
    call attack_note
.n: dec dword [bI]
    jmp .l
.r: ret

; ---------------------------------------------------------------------
; every tick, and the end of every boss turn
; ---------------------------------------------------------------------
boss_tick:
    call bishop_tick                ; a hurt 1 moves the light (bosses2.inc)
    cmp dword [bossRoom], BR_KEEPER
    jne .king
    cmp dword [keeperPhase], 1
    jne .note
    cmp dword [enemyHP], 0
    jle .note
    mov eax, [enemyHP]
    cmp eax, [bossHalf]
    jg .note
    call keeper_phase2
    jmp .note
.king:
    cmp dword [bossRoom], 2
    jne .note
    cmp dword [kingDying], 0
    je .stage
    dec dword [dyingT]
    jnz .note
    call king_rise
    jmp .note
.stage:
    cmp dword [isUnbound], 0
    je .stg
    cmp dword [uSwitch], 0
    je .note
    cmp dword [enemyHP], 0
    jle .note
    mov dword [uSwitch], 0
    call unbound_next_mode
    jmp .note
.stg:
    cmp dword [enemyHP], 0
    jle .note
    mov eax, [enemyHP]              ; hp * 3 against max * 2 and max * 1
    imul eax, eax, 3
    mov ebx, [bossMax]
    cmp dword [kingStage], 0
    jne .s2
    shl ebx, 1
    cmp eax, ebx
    jg .note
    mov dword [kingStage], 1
    xor eax, eax
    call king_rewire
    note msgRewire
    jmp .note
.s2:
    cmp dword [kingStage], 1
    jne .note
    cmp eax, ebx
    jg .note
    mov dword [kingStage], 2
    mov eax, 1
    call king_rewire
    note msgRewire2
.note:
    cmp dword [noteLen], 0
    jne .say
    cmp dword [modeNoteLater], 0
    je .r
    dec dword [modeNoteLater]
    jnz .r
    mov dword [modeNoteLater], 0
    mov eax, [uMode]
    mov esi, [modeMsgs+eax*4]
    mov ecx, [modeLens+eax*4]
    jmp .say2
.say:
    mov esi, noteBuf
    mov ecx, [noteLen]
    mov dword [noteLen], 0
    cmp dword [modeNoteLater], 1
    jne .say2
    mov dword [modeNoteLater], 12   ; wait about a second before the next line
.say2:
    call say_str
    call draw_panel
.r: ret

boss_round:                         ; the boss turn just ended
    mov eax, [bossRoom]
    cmp eax, 1
    jne .s
    cmp dword [wShield], 0
    jne .r
    dec dword [wTimer]
    jnz .r
    cmp dword [enemyHP], 0
    jle .r
    jmp warden_reshield
.s: cmp eax, 3
    jne .y
    jmp shade_round
.y: cmp eax, BR_YMIR
    jne .d
    jmp ymir_round
.d: cmp eax, BR_DUO
    jne .kp2
    jmp duo_round
.kp2:
    cmp eax, BR_KEEPER
    jne .bs2
    jmp keeper2_round
.bs2:
    cmp eax, BR_BISHOP
    jne .k
    jmp bishop_round
.k: cmp eax, 2
    jne .r
    cmp dword [isUnbound], 0
    je .r
    cmp dword [enemyHP], 0
    jle .r
    jmp unbound_round
.r: ret
; ===== end bosses.inc =====
; ===== begin bosses2.inc =====
; =====================================================================
; bosses2.inc  -  the Four Bishops (floor 12) and the Logic Keeper's Wardens (floor 21)
;
;   floor 12   the Four Bishops: one in each corner, joined in a square by yellow lines. On
;              each side stands a gate that is TRUE for the two bishops it joins. One bishop
;              is secretly the 1 (after it has been found twice: two neighbours are 1s).
;              Only a 1 can be hurt; the 0s ignore every hit. All four cast every round, but
;              only the 1's spell lands: Smite (burns you for 2 rounds) or Judgment (knocks
;              you back 2 squares), in turn. They never move. One shared health pool: when
;              it is gone, all four are. When a 1 is hurt, the 1 moves and the gates change.
;
;   floor 21   the Logic Keeper and two Wardens, joined to it by blue links. While any
;              Warden is linked the Keeper can't be hurt. Each Warden has its own gate and
;              its own torch pair beside it: match the pair to that Warden's gate and its
;              shield breaks and its link is cut for 4 rounds (it reels, too). Then it links
;              up again with a new gate. A Warden that dies is cut for good. The Wardens
;              move and fight like any Warden. A dead Warden's link is cut for good.
; =====================================================================

section .data
BR_BISHOP equ 7
bishCX   dd 8, 41, 41, 8          ; the four corners (top-left of each 2x2 bishop): TL, TR, BR, BL
bishCY   dd 1, 1, 10, 10
bishGX   dd 25, 42, 25, 9         ; the gate on each side: top (TL-TR), right (TR-BR), bottom (BR-BL), left (BL-TL)
bishGY   dd 2, 6, 11, 6
msgBishops  db "The Four Bishops! One of them is the 1 - the gates between them never lie. Only the 1 can be hurt."
msgBishopslen equ $- msgBishops
msgBishFound db "Found the 1! The bishops' light shifts - the 1 is somewhere else now."
msgBishFoundlen equ $- msgBishFound
msgBishTwo  db "Found again! Now TWO bishops shine as 1s - read the gates."
msgBishTwolen equ $- msgBishTwo
msgBishZero db "That bishop is a 0 - the blow passes through it."
msgBishZerolen equ $- msgBishZero
msgSmite    db "The bishops cast Smite - holy fire burns you for "
msgSmitelen equ $- msgSmite
msgJudge    db "The bishops cast Judgment - the light hurls you back for "
msgJudgelen equ $- msgJudge
msgBishMiss db "The bishops' beams all miss."
msgBishMisslen equ $- msgBishMiss
msgHolyBurn db "Holy fire burns you for 2"
msgHolyBurnlen equ $- msgHolyBurn
plqBishops  db "BISHOPS - each gate is true for the two bishops it joins. The 1 can be hurt; the 0s can't."
plqBishopslen equ $- plqBishops
msgKeeper2  db "The Logic Keeper and its two Wardens! While a Warden is linked to it, the Keeper can't be hurt."
msgKeeper2len equ $- msgKeeper2
msgLinkCut  db "A Warden's link is cut! Its shield breaks for 4 rounds."
msgLinkCutlen equ $- msgLinkCut
msgLinkBack db "A Warden links to the Keeper again - with a new gate on its shield."
msgLinkBacklen equ $- msgLinkBack
msgKeepOpen db "Both links are cut - the Logic Keeper is open to attack!"
msgKeepOpenlen equ $- msgKeepOpen
plqKeeper2  db "WARDENS - "
plqKeeper2len equ $- plqKeeper2
plqTop      db "top: "
plqToplen equ $- plqTop
plqBot      db "   bottom: "
plqBotlen equ $- plqBot
kPX      dd 12, 12                ; each Warden's torch pair (left column, row)
kPY      dd 3, 9

section .bss
bishOne   resd 4                  ; 1 = that bishop is a 1
bishGate  resd 4                  ; gate number on each side
bishFound resd 1                  ; how many times a 1 has been hit
bishPool  resd 1                  ; the shared health
bishRot   resd 1                  ; enemy i stands in corner (i + bishRot) & 3 (the Unbound's copies)
bishReset resd 1                  ; 1 = a 1 was hurt: move the 1 at the next tick
bishSpell resd 1                  ; 0 = Smite next, 1 = Judgment
bishActed resd 1                  ; this enemy turn's volley is done
holyBurn  resd 1                  ; rounds of holy fire left on you
kGate     resd 2                  ; each Warden's gate
kLink     resd 2                  ; 1 = linked to the Keeper
kCut      resd 2                  ; rounds left with its link cut
bx2       resd 1
bTry      resd 1
by2       resd 1

section .text
; ---------------------------------------------------------------------
; the Four Bishops
; ---------------------------------------------------------------------
bishop_spawn:
    pushad
    mov dword [bishRot], 0
    xor ecx, ecx
.l: cmp ecx, 4
    jge .hp
    mov dword [enemyType+ecx*4], ETYPE_BISHOP
    mov eax, [bishCX+ecx*4]
    mov [enemyX+ecx*4], eax
    mov eax, [bishCY+ecx*4]
    mov [enemyY+ecx*4], eax
    inc ecx
    jmp .l
.hp:
    xor ecx, ecx
    call roll_hp                    ; one shared pool
    mov eax, [enemyHP]
    mov [bishPool], eax
    mov [bossMax], eax
    mov [enemyHP+4], eax
    mov [enemyHP+8], eax
    mov [enemyHP+12], eax
    mov dword [bishFound], 0
    mov dword [bishReset], 0
    mov dword [bishSpell], 0
    mov dword [holyBurn], 0
    mov dword [bishOne], 0
    mov dword [bishOne+4], 0
    mov dword [bishOne+8], 0
    mov dword [bishOne+12], 0
    mov eax, 4
    call rand_mod
    mov dword [bishOne+eax*4], 1
    call bishop_gates
    popad
    ret

bishop_gates:                       ; each side's gate from the two bishops it joins: true for them
    pushad
    xor ecx, ecx
.l: cmp ecx, 4
    jge .d
    mov eax, [bishOne+ecx*4]
    lea edx, [ecx+1]
    and edx, 3
    add eax, [bishOne+edx*4]        ; 0 = two 0s, 1 = a 1 and a 0, 2 = two 1s
    mov ebx, 4                      ; two 0s: NOR
    cmp eax, 1
    jne .g2
    mov ebx, 2                      ; a 1 and a 0: XOR
.g2:cmp eax, 2
    jne .set
    xor ebx, ebx                    ; two 1s: AND
.set:
    mov [bishGate+ecx*4], ebx
    inc ecx
    jmp .l
.d: popad
    ret

bishop_move_one:                    ; a 1 was hurt: the light moves (two neighbouring 1s once found twice)
    pushad
    inc dword [bishFound]
    xor ecx, ecx                    ; remember the old ones in esi (bits)
    xor esi, esi
.o: cmp ecx, 4
    jge .new
    cmp dword [bishOne+ecx*4], 0
    je .on
    bts esi, ecx
.on:inc ecx
    jmp .o
.new:
    mov dword [bTry], 30
.again:
    mov dword [bishOne], 0
    mov dword [bishOne+4], 0
    mov dword [bishOne+8], 0
    mov dword [bishOne+12], 0
    mov eax, 4
    call rand_mod
    mov dword [bishOne+eax*4], 1
    cmp dword [bishFound], 2
    jl .chk
    inc eax                         ; two found: a neighbour shines too
    and eax, 3
    mov dword [bishOne+eax*4], 1
.chk:
    xor ecx, ecx                    ; must differ from before
    xor edi, edi
.c: cmp ecx, 4
    jge .cmp
    cmp dword [bishOne+ecx*4], 0
    je .cn
    bts edi, ecx
.cn:inc ecx
    jmp .c
.cmp:
    dec dword [bTry]
    jz .ok
    cmp edi, esi
    je .again
    test edi, esi                   ; and none of the old 1s stays a 1
    jnz .again
.ok:
    call bishop_gates
    cmp dword [bishFound], 2        ; the trick's XP only for the first two finds
    jg .noxp
    call xp_trick
.noxp:
    cmp dword [bishFound], 2
    je .two
    msg msgBishFound
    jmp .d
.two:
    msg msgBishTwo
.d: popad
    ret

bishop_cut:                         ; eax = damage about to hit bishop ecx -> eax (0 if it is a 0)   (keeps the rest)
    cmp dword [bishOne+ecx*4], 0
    jne .one
    push esi
    push ecx
    msg msgBishZero
    pop ecx
    pop esi
    xor eax, eax
    ret
.one:
    test eax, eax
    jz .r
    push ebx
    mov ebx, [bishPool]             ; the shared pool takes it; every bishop shows the pool
    sub ebx, eax
    mov [bishPool], ebx
    push ecx
    xor ecx, ecx
.s: cmp ecx, 4
    jge .sd
    cmp dword [enemyHP+ecx*4], 0
    jle .sn
    mov [enemyHP+ecx*4], ebx
.sn:inc ecx
    jmp .s
.sd:pop ecx
    add [enemyHP+ecx*4], eax        ; (the caller takes the damage off this one)
    pop ebx
    mov dword [bishReset], 1
.r: ret

bishop_kill_all:                    ; one bishop died: the pool is gone, so are the rest
    pushad
    xor ecx, ecx
.l: cmp ecx, 4                     ; (the others' HP already shows the empty pool: wipe them all from the map)
    jge .d
    cmp dword [enemyType+ecx*4], ETYPE_BISHOP
    jne .n
    mov dword [enemyHP+ecx*4], 0
    call set_area_to_enemy
    call redraw_area
.n: inc ecx
    jmp .l
.d: mov dword [enemyHP], 0          ; (so the gates on the square go too)
    call bishop_draw_gates
    popad
    ret

bishop_act:                         ; enemy [eI] is a bishop: the first one this turn casts the volley for all four
    cmp dword [bishActed], 0
    jne .r
    mov dword [bishActed], 1
    call bishop_note                ; four beams for the window
    xor ecx, ecx                    ; which bishops are 1s (alive)
    mov dword [bI], 0
.l: cmp ecx, 4
    jge .done
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    cmp dword [bishOne+ecx*4], 0
    je .n
    push ecx
    mov [eI], ecx
    mov esi, bishop                 ; (the Unbound's copies cast with a bishop's power too)
    movzx ebx, byte [esi+ENEMY_ATK_BONUS]
    call enemy_hit_roll
    pop ecx
    jc .done                        ; the one real beam missed
    push ecx
    mov esi, bishop
    movzx eax, byte [esi+ENEMY_DMG_MAX]
    movzx ebx, byte [esi+ENEMY_DMG_MIN]
    sub eax, ebx
    inc eax
    call rand_mod
    add eax, ebx
    mov ebx, [floorCount]           ; + floor/3
    push eax
    mov eax, ebx
    xor edx, edx
    mov ebx, 3
    div ebx
    pop ebx
    add eax, ebx
    call absorb_damage
    sub [playerHP], eax
    add [bI], eax
    pop ecx
    mov [bx2], ecx
    jmp .done                       ; only one beam ever lands
.n: inc ecx
    jmp .l
.done:
    cmp dword [bI], 0
    jne .hit
    msg msgBishMiss
    jmp .flip
.hit:
    call msg_begin
    cmp dword [bishSpell], 0
    jne .judge
    mtext msgSmite
    mov eax, [bI]
    call msg_num
    call msg_end
    mov dword [holyBurn], 2         ; Smite: holy fire, 2 more rounds
    jmp .after
.judge:
    mtext msgJudge
    mov eax, [bI]
    call msg_num
    call msg_end
    mov ecx, [bx2]
    call bishop_knockback
.after:
    call draw_hp
    call player_dead_check
.flip:
    xor dword [bishSpell], 1
.r: ret

bishop_knockback:                   ; ecx = the bishop whose light hit: push you 2 squares away from it
    pushad
    mov eax, [enemyX+ecx*4]
    inc eax                         ; its middle
    mov ebx, [enemyY+ecx*4]
    inc ebx
    mov esi, [playerX]
    sub esi, eax
    mov edi, [playerY]
    sub edi, ebx
    xor eax, eax                    ; step direction: the sign of each
    test esi, esi
    jz .y
    mov eax, 1
    jg .y
    mov eax, -1
.y: xor ebx, ebx
    test edi, edi
    jz .go
    mov ebx, 1
    jg .go
    mov ebx, -1
.go:
    mov [bx2], eax
    mov [by2], ebx
    mov dword [bTry], 2
.st:mov eax, [playerX]
    add eax, [bx2]
    mov ebx, [playerY]
    add ebx, [by2]
    call cell_free
    jc .d
    push dword [playerX]            ; move first, then tidy the cell you left
    push dword [playerY]
    mov [playerX], eax
    mov [playerY], ebx
    mov dl, '@'
    call put_cell
    pop ebx
    pop eax
    call cell_glyph
    call put_cell
    dec dword [bTry]
    jnz .st
.d: mov dword [moving], 0
    popad
    ret

bishop_round:                       ; end of the bishops' turn
    mov dword [bishActed], 0
    ret

holy_burn_tick:                     ; your round ends: holy fire burns   (called from player_round_end)
    cmp dword [holyBurn], 0
    je .r
    dec dword [holyBurn]
    sub dword [playerHP], 2
    call draw_hp
    msg msgHolyBurn
    call player_dead_check
.r: ret

bishop_glyph:                       ; eax=x, ebx=y -> al = the gate letter on a side of the square, else 0   (keeps the rest)
    push ecx
    push edx
    call bishop_like
    jne .no
    cmp dword [enemyHP], 0          ; (gone with the bishops)
    jle .no
    xor ecx, ecx
.l: cmp ecx, 4
    jge .no
    cmp eax, [bishGX+ecx*4]
    jne .n
    cmp ebx, [bishGY+ecx*4]
    jne .n
    mov edx, ecx                    ; side k joins enemies (k - bishRot) and the next
    sub edx, [bishRot]
    and edx, 3
    mov edx, [bishGate+edx*4]
    mov al, [gateLetter+edx]
    pop edx
    pop ecx
    ret
.n: inc ecx
    jmp .l
.no:
    xor al, al
    pop edx
    pop ecx
    ret

bishop_draw_gates:
    call bishop_like
    jne .r
    pushad
    xor ecx, ecx
.l: cmp ecx, 4
    jge .d
    mov eax, [bishGX+ecx*4]
    mov ebx, [bishGY+ecx*4]
    call cell_glyph
    call put_cell
    inc ecx
    jmp .l
.d: popad
.r: ret

bishop_note:                        ; B<spell>,<you x>,<you y>,<x,y> per bishop (their middles) - for the beams
    pushad
    call osc_begin
    mov al, 'B'
    call osc_char
    mov eax, [bishSpell]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerX]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [playerY]
    call osc_num
    xor ecx, ecx
.l: cmp ecx, 4
    jge .s
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    mov al, ','
    call osc_char
    mov eax, [enemyX+ecx*4]
    call osc_num
    mov al, ','
    call osc_char
    mov eax, [enemyY+ecx*4]
    call osc_num
.n: inc ecx
    jmp .l
.s: call osc_send
    popad
    ret

bishop_tick:                        ; every tick: a hurt 1 moves the light (after the hit has resolved)
    cmp dword [bishReset], 0
    je .r
    mov dword [bishReset], 0
    cmp dword [bishPool], 0
    jle .r
    call bishop_move_one
    call bishop_draw_gates
.r: ret

; ---------------------------------------------------------------------
; the Logic Keeper and its Wardens
; ---------------------------------------------------------------------
keeper2_setup:                      ; the room: two torch pairs, one beside each Warden
    mov dword [puzzleOn], 1
    mov dword [puzzlePairs], 2
    mov dword [puzzleAll], 0
    mov dword [doorOpen], 0
    ret

keeper2_spawn:                      ; the Keeper (enemy 0) and the Wardens (1 top, 2 bottom)
    pushad
    mov dword [enemyX], 30
    mov dword [enemyY], 4
    mov dword [enemyType+4], ETYPE_MINIBOSS
    mov dword [enemyX+4], 22
    mov dword [enemyY+4], 1
    mov dword [enemyType+8], ETYPE_MINIBOSS
    mov dword [enemyX+8], 22
    mov dword [enemyY+8], 9
    mov ecx, 1
    call roll_hp
    mov ecx, 2
    call roll_hp
    mov dword [kLink], 1
    mov dword [kLink+4], 1
    mov dword [kCut], 0
    mov dword [kCut+4], 0
    xor ecx, ecx
    call keeper2_newgate
    mov ecx, 1
    call keeper2_newgate
    call keeper2_ward
    popad
    ret

keeper2_newgate:                    ; ecx = Warden 0/1: a new gate, and its pair set so it does NOT match
    pushad
    mov [bx2], ecx
    mov eax, GATE_COUNT
    call rand_mod
    mov ecx, [bx2]
    mov [kGate+ecx*4], eax
    mov dword [bTry], 40
.r: mov eax, 2
    call rand_mod
    mov ecx, [bx2]
    mov [nodeBit+ecx*2], al
    mov eax, 2
    call rand_mod
    mov ecx, [bx2]
    mov [nodeBit+ecx*2+1], al
    call keeper2_pair_ok
    jnc .d
    dec dword [bTry]
    jnz .r
.d: popad
    ret

keeper2_pair_ok:                    ; [bx2] = Warden -> CF=1 if its pair matches its gate   (keeps all)
    pushad
    mov ecx, [bx2]
    movzx eax, byte [nodeBit+ecx*2]
    shl eax, 1
    movzx edx, byte [nodeBit+ecx*2+1]
    or eax, edx
    mov edx, [kGate+ecx*4]
    movzx edx, byte [gateTruth+edx]
    bt edx, eax
    popad
    ret

keeper2_ward:                       ; the Keeper is shielded while any living Warden is linked
    pushad
    mov dword [wardUp], 0
    xor ecx, ecx
.l: cmp ecx, 2
    jge .d
    cmp dword [enemyHP+4+ecx*4], 0
    jle .n
    cmp dword [kLink+ecx*4], 0
    je .n
    mov dword [wardUp], 1
.n: inc ecx
    jmp .l
.d: popad
    ret

keeper2_torch:                      ; a torch flipped: does a pair now match its Warden's gate?
    pushad
    xor ecx, ecx
.l: cmp ecx, 2
    jge .d
    mov [bx2], ecx
    cmp dword [enemyHP+4+ecx*4], 0
    jle .n
    cmp dword [kLink+ecx*4], 0
    je .n
    call keeper2_pair_ok
    jnc .n
    mov ecx, [bx2]
    mov dword [kLink+ecx*4], 0      ; cut!
    mov dword [kCut+ecx*4], 4
    lea ebx, [ecx+1]
    imul ebx, ebx, STAT_STRIDE
    movzx eax, byte [statusDur+EFFECT_PRONE]
    shl eax, 1
    mov [statusTimer+ebx+EFFECT_PRONE], al   ; it reels
    call xp_trick
    msg msgLinkCut
    mov ecx, [bx2]
.n: inc ecx
    jmp .l
.d: mov eax, [wardUp]
    call keeper2_ward
    cmp eax, 0
    je .x
    cmp dword [wardUp], 0
    jne .x
    msg msgKeepOpen
.x: xor ecx, ecx
    call draw_enemy
    mov ecx, 1
    call draw_enemy
    mov ecx, 2
    call draw_enemy
    popad
    ret

keeper2_round:                      ; end of the boss turn: cut links count down, then join again
    pushad
    xor ecx, ecx
.l: cmp ecx, 2
    jge .d
    cmp dword [kCut+ecx*4], 0
    je .n
    dec dword [kCut+ecx*4]
    jnz .n
    cmp dword [enemyHP+4+ecx*4], 0
    jle .n
    mov dword [kLink+ecx*4], 1
    call keeper2_newgate
    msg msgLinkBack
.n: inc ecx
    jmp .l
.d: call keeper2_ward
    call draw_room_objects
    xor ecx, ecx
    call draw_enemy
    mov ecx, 1
    call draw_enemy
    mov ecx, 2
    call draw_enemy
    popad
    ret

keeper2_cut:                        ; eax = damage about to hit enemy ecx in the Keeper's room -> eax   (keeps the rest)
    test ecx, ecx
    jnz .warden
    cmp dword [wardUp], 0
    je .r
    xor eax, eax                    ; the Keeper, still linked: nothing gets through
    ret
.warden:
    cmp dword [kLink+ecx*4-4], 0
    je .r                           ; link cut: its shield is broken too
    cmp dword [attackPierce], 0
    jne .r
    shr eax, 1                      ; its gate shield halves it
.r: ret

keeper2_plaque:                     ; "WARDENS - top: AND - ...   bottom: XOR - ..."
    pushad
    call msg_begin
    mtext plqKeeper2
    mtext plqTop
    mov eax, [kGate]
    call .name
    mtext plqBot
    mov eax, [kGate+4]
    call .name
    call msg_end
    popad
    ret
.name:                              ; eax = gate: print its riddle line (name - rhyme)
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN
.t: cmp byte [esi+ecx-1], ' '
    jne .p
    dec ecx
    jmp .t
.p: call msg_text
    ret

keeper2_kill_all:                   ; the Keeper fell: its Wardens fall with it
    pushad
    mov ecx, 1
.l: cmp ecx, 3
    jge .d
    cmp dword [enemyHP+ecx*4], 0
    jle .n
    mov dword [enemyHP+ecx*4], 0
    call set_area_to_enemy
    call redraw_area
.n: inc ecx
    jmp .l
.d: popad
    ret
; ===== end bosses2.inc =====
; ===== begin progress.inc =====
; =====================================================================
; progress.inc  -  levels 1-20, experience, class perks, stat points,
;                  and what your gear adds to you (stats, AC, mana, specials)
;
; Stats use the modifier  (stat - 10) / 2,  rounded down: 16 -> +3, 9 -> -1.
;
; XP comes from kills (more on deeper floors), from solving a room's puzzle,
; and from beating a boss trick (breaking a shield, lighting the lantern, ...).
; Every level: max HP + your class's die (Fighter 6, Rogue 5, Wizard 4) + CON modifier.
; Every even level: one stat point. Press U, then 1 STR  2 DEX  3 CON  4 INT.
;
;          Fighter                Rogue                    Wizard
;   L3     5 superiority dice     sneak attack 3d6         max mana +2
;   L5     3 attacks a turn       moving never spots you   mana regenerates 2x
;   L7     dice become d10        2 attacks a turn         cantrips roll an extra die
;   L9     heal 1 HP a round      sneak attack 4d6         max mana +2
;   L10    Action Surge twice     -                        -
;   L11    first hit halved       first hit halved         spells +2 damage
;   L13    6 superiority dice     a kill hides you again   one free spell per fight
;   L15    dice become d12        sneak attack 5d6         max mana +2
;   L17    4 attacks a turn       ranged hits halved       mana regenerates 3x
;   L19    heal 2 HP a round      sneak attack 6d6         cantrips: another die
;   L20    Action Surge 3 times   sneak attacks pierce     spells deal +50%
; =====================================================================

section .data
MAX_LEVEL equ 20
; total XP needed to REACH level 2, 3, ... 20
xpTable dd 50, 150, 280, 430, 600, 800, 1000, 1250, 1500, 1800, 2150, 2550, 3000, 3500, 4050, 4650, 5300, 6000, 7000
classHP db 6, 5, 4              ; HP per level: Fighter, Rogue, Wizard (before CON)

; XP for killing each enemy type (normal enemies also get + 2 per floor)
xpKill dw 10, 15, 20, 100, 500, 300, 350, 400, 250, 250, 0, 300, 0   ; (... the Unbound, a bishop, an Unbound copy)

; special numbers (must match items.py)
SP_LIFESTEAL equ 1
SP_PIERCE    equ 2
SP_SPELLPOW  equ 3
SP_STEALTH   equ 4
SP_THORNS    equ 5
SP_REFLECT   equ 6
SP_FIRSTHIT  equ 7
SP_MOVE      equ 8
SP_SNEAK     equ 9
SP_XP        equ 10
SP_REVEAL    equ 11
SP_MANAREGEN equ 12
SP_REGEN     equ 13
SP_EXTRA     equ 14
SP_CHEAP     equ 15
SP_REACH     equ 16
SP_LIGHT     equ 17

; what the level-up line says about the new perk (0 = nothing new), per class, levels 1..20
%macro perk 2
%1 db %2, 0
%endmacro
perk pkF3,  " 5 superiority dice!"
perk pkF5,  " A third attack each turn!"
perk pkF7,  " Your dice are d10 now!"
perk pkF9,  " You heal 1 HP every round."
perk pkF10, " Action Surge twice per fight!"
perk pkF11, " The first hit in each fight is halved."
perk pkF13, " 6 superiority dice!"
perk pkF15, " Your dice are d12 now!"
perk pkF17, " A fourth attack each turn!"
perk pkF19, " You heal 2 HP every round."
perk pkF20, " Action Surge three times per fight!"
perk pkR3,  " Sneak attack 3d6!"
perk pkR5,  " Moving no longer gives you away."
perk pkR7,  " Two attacks each turn!"
perk pkR9,  " Sneak attack 4d6!"
perk pkR11, " The first hit in each fight is halved."
perk pkR13, " A kill hides you again."
perk pkR15, " Sneak attack 5d6!"
perk pkR17, " Ranged hits and spells do half to you."
perk pkR19, " Sneak attack 6d6!"
perk pkR20, " Sneak attacks pierce every shield!"
perk pkW3,  " Max mana +2!"
perk pkW5,  " Mana comes back twice as fast."
perk pkW7,  " Cantrips roll an extra die!"
perk pkW9,  " Max mana +2!"
perk pkW11, " Spells deal +2 damage!"
perk pkW13, " One free spell in every fight!"
perk pkW15, " Max mana +2!"
perk pkW17, " Mana comes back three times as fast."
perk pkW19, " Cantrips roll another die!"
perk pkW20, " Your spells deal +50% damage!"
perkText dd 0,0,pkF3,0,pkF5,0,pkF7,0,pkF9,pkF10,pkF11,0,pkF13,0,pkF15,0,pkF17,0,pkF19,pkF20
         dd 0,0,pkR3,0,pkR5,0,pkR7,0,pkR9,0,pkR11,0,pkR13,0,pkR15,0,pkR17,0,pkR19,pkR20
         dd 0,0,pkW3,0,pkW5,0,pkW7,0,pkW9,0,pkW11,0,pkW13,0,pkW15,0,pkW17,0,pkW19,pkW20

msgLvUp db "LEVEL UP! You are level "
msgLvUplen equ $- msgLvUp
msgLvHP db " (+"
msgLvHPlen equ $- msgLvHP
msgLvHP2 db " HP)."
msgLvHP2len equ $- msgLvHP2
msgLvPick db " Press U to raise a stat."
msgLvPicklen equ $- msgLvPick
msgPickAsk db "Raise which stat? 1 STR  2 DEX  3 CON  4 INT   (any other key: later)"
msgPickAsklen equ $- msgPickAsk
msgNoPts db "No stat points to spend. You get one every even level."
msgNoPtslen equ $- msgNoPts
msgRaised db " is now "
msgRaisedlen equ $- msgRaised
msgMaxed db "That stat is already at its peak (24)."
msgMaxedlen equ $- msgMaxed
statNames db "STR", "DEX", "CON", "INT"
starCh db "*"
lvLbl db "Lv:"
lvLbllen equ $- lvLbl
xpLbl db " XP:"
xpLbllen equ $- xpLbl
msgVanish db "You slip back into the shadows."
msgVanishlen equ $- msgVanish
msgFree db "Free spell!"
msgFreelen equ $- msgFree
msgSteal db "You drink "
msgSteallen equ $- msgSteal
pickRarity db " (rare)", " (LEGENDARY)"

section .bss
playerLevel resd 1
playerXP    resd 1
statPoints  resd 1
statPick    resd 1              ; 1 = the next key 1-4 raises a stat
hpGained    resd 1              ; HP from levels (class die only; CON is added on top)
baseStat    resd 4              ; STR DEX CON INT before gear
; perks for the current level
pkDice      resd 1
pkDie       resd 1
pkAttacks   resd 1
pkSurges    resd 1
pkSneak     resd 1
pkRegen     resd 1
pkFirstHit  resd 1
pkStealth   resd 1
pkRehide    resd 1
pkReflect   resd 1
pkPierceSneak resd 1
pkMana      resd 1
pkManaPeriod resd 1
pkCantrip   resd 1
pkSpellDmg  resd 1
pkFreeSpell resd 1
pkSpellHalf resd 1              ; 1 = spells +50%
; what the gear adds
gStat       resd 4
gAC         resd 1
gMana       resd 1
gFlags      resd 1              ; bit n = special n is worn
gSpell      resd 1
gThorns     resd 1
gMove       resd 1
gSneak      resd 1
gXP         resd 1
gRegen      resd 1
; per fight
firstHitUsed resd 1
freeSpellUsed resd 1
surgesLeft  resd 1
attackPierce resd 1             ; 1 while this hit cuts through shields
; scratch
lvBuf       resb 160            ; the level-up line, shown when nothing else is waiting
lvLen       resd 1
lvTmp       resd 1
lvOldMax    resd 1
pgI         resd 1

section .text

; ---------------------------------------------------------------------
; helpers
; ---------------------------------------------------------------------
stat_mod:                           ; eax = stat -> eax = (stat - 10) / 2, rounded down
    sub eax, 10
    sar eax, 1
    ret

has_special:                        ; eax = special number -> CF=1 if any worn item has it   (keeps all)
    push edx
    mov edx, [gFlags]
    bt edx, eax
    pop edx
    ret

class_index:                        ; -> eax = 0 Fighter, 1 Rogue, 2 Wizard
    movzx eax, byte [class]
    sub eax, '1'
    ret

lv_add:                             ; esi = text, ecx = length: append to the level-up line
    pushad
    mov edi, lvBuf
    add edi, [lvLen]
    add [lvLen], ecx
    cld
    rep movsb
    popad
    ret

lv_num:                             ; eax = number: append it
    pushad
    xor ecx, ecx
    mov ebx, 10
.d: xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz .d
    mov edi, lvBuf
    add edi, [lvLen]
.p: pop eax
    add al, '0'
    stosb
    inc dword [lvLen]
    loop .p
    popad
    ret

; ---------------------------------------------------------------------
; start of a game
; ---------------------------------------------------------------------
init_progress:                      ; after character creation (stats are set)
    mov dword [playerLevel], 1
    mov dword [playerXP], 0
    mov dword [statPoints], 0
    mov dword [statPick], 0
    mov dword [hpGained], 0
    mov dword [lvLen], 0
    mov eax, [strength]
    mov [baseStat], eax
    mov eax, [dex]
    mov [baseStat+4], eax
    mov eax, [con]
    mov [baseStat+8], eax
    mov eax, [intel]
    mov [baseStat+12], eax
    call apply_perks
    call new_fight_state
    ret

new_fight_state:                    ; per-fight things come back
    mov dword [firstHitUsed], 0
    mov dword [freeSpellUsed], 0
    mov eax, [pkSurges]
    mov [surgesLeft], eax
    ret

; ---------------------------------------------------------------------
; perks: everything that depends on your level
; ---------------------------------------------------------------------
%macro atleast 3                    ; dest += %3 if level >= %2
    cmp dword [playerLevel], %2
    jl %%no
    add dword [%1], %3
%%no:
%endmacro

apply_perks:
    pushad
    xor eax, eax
    mov edi, pkDice
    mov ecx, 17                     ; every pk... variable
    cld
    rep stosd
    mov dword [pkDie], 8
    mov dword [pkManaPeriod], 12
    call class_index
    cmp eax, 0
    jne .rogue
    mov dword [pkDice], 4
    atleast pkDice, 3, 1
    atleast pkDice, 13, 1
    atleast pkDie, 7, 2
    atleast pkDie, 15, 2
    mov dword [pkAttacks], 2
    atleast pkAttacks, 5, 1
    atleast pkAttacks, 17, 1
    mov dword [pkSurges], 1
    atleast pkSurges, 10, 1
    atleast pkSurges, 20, 1
    atleast pkRegen, 9, 1
    atleast pkRegen, 19, 1
    atleast pkFirstHit, 11, 1
    jmp .d
.rogue:
    cmp eax, 1
    jne .wiz
    mov dword [pkAttacks], 1
    atleast pkAttacks, 7, 1
    mov dword [pkSneak], 2
    atleast pkSneak, 3, 1
    atleast pkSneak, 9, 1
    atleast pkSneak, 15, 1
    atleast pkSneak, 19, 1
    atleast pkStealth, 5, 1
    atleast pkFirstHit, 11, 1
    atleast pkRehide, 13, 1
    atleast pkReflect, 17, 1
    atleast pkPierceSneak, 20, 1
    jmp .d
.wiz:
    mov dword [pkAttacks], 1
    atleast pkMana, 3, 2
    atleast pkMana, 9, 2
    atleast pkMana, 15, 2
    cmp dword [playerLevel], 5
    jl .p1
    mov dword [pkManaPeriod], 6
.p1:
    cmp dword [playerLevel], 17
    jl .p2
    mov dword [pkManaPeriod], 4
.p2:
    atleast pkCantrip, 7, 1
    atleast pkCantrip, 19, 1
    atleast pkSpellDmg, 11, 2
    atleast pkFreeSpell, 13, 1
    atleast pkSpellHalf, 20, 1
.d: popad
    ret

; ---------------------------------------------------------------------
; gear: add up everything you wear, then work out your real stats
; (called by recalc_gear before it works out your AC)
; ---------------------------------------------------------------------
gearSlots dd equipWeapon, equipBody, equipShield, equipHelm, equipBoots, equipTrinket

recalc_stats:
    pushad
    xor eax, eax
    mov edi, gStat
    mov ecx, 13                     ; gStat[4] .. gRegen
    cld
    rep stosd
    mov dword [pgI], 0
.l: mov eax, [pgI]
    cmp eax, 6
    jge .sum
    mov esi, [gearSlots+eax*4]
    mov esi, [esi]                  ; the catalog entry worn there, or 0
    test esi, esi
    jz .n
    xor ecx, ecx
.st:
    movsx eax, byte [esi+CAT_BSTR+ecx]
    add [gStat+ecx*4], eax
    inc ecx
    cmp ecx, 4
    jl .st
    movsx eax, byte [esi+CAT_BAC]
    add [gAC], eax
    movsx eax, byte [esi+CAT_BMANA]
    add [gMana], eax
    movzx eax, byte [esi+CAT_SPECIAL]
    test eax, eax
    jz .n
    mov edx, [gFlags]
    bts edx, eax
    mov [gFlags], edx
    movzx edx, byte [esi+CAT_SPVAL]
    cmp eax, SP_SPELLPOW
    jne .s1
    add [gSpell], edx
.s1:
    cmp eax, SP_THORNS
    jne .s2
    add [gThorns], edx
.s2:
    cmp eax, SP_MOVE
    jne .s3
    add [gMove], edx
.s3:
    cmp eax, SP_SNEAK
    jne .s4
    add [gSneak], edx
.s4:
    cmp eax, SP_XP
    jne .s5
    add [gXP], edx
.s5:
    cmp eax, SP_REGEN
    jne .n
    add [gRegen], edx
.n: inc dword [pgI]
    jmp .l
.sum:                               ; your real stats
    mov eax, [baseStat]
    add eax, [gStat]
    mov [strength], eax
    mov eax, [baseStat+4]
    add eax, [gStat+4]
    mov [dex], eax
    mov eax, [baseStat+8]
    add eax, [gStat+8]
    mov [con], eax
    mov eax, [baseStat+12]
    add eax, [gStat+12]
    mov [intel], eax
    ; max mana
    mov eax, MAX_MANA
    add eax, [pkMana]
    add eax, [gMana]
    mov [playerMaxMana], eax
    cmp [playerMana], eax
    jle .hp
    mov [playerMana], eax
.hp:                                ; max HP = class base + level dice + CON mod per level after the first
    mov eax, [playerMaxHP]
    mov [lvOldMax], eax
    call class_index
    movzx ebx, byte [basehp+eax]
    add ebx, [hpGained]
    mov eax, [con]
    call stat_mod
    mov ecx, [playerLevel]
    dec ecx
    imul eax, ecx
    add ebx, eax
    cmp ebx, 1
    jge .hp2
    mov ebx, 1
.hp2:
    mov [playerMaxHP], ebx
    mov eax, ebx
    sub eax, [lvOldMax]             ; more max HP: you get the difference now
    jle .clamp
    add [playerHP], eax
.clamp:
    mov eax, [playerMaxHP]
    cmp [playerHP], eax
    jle .r
    mov [playerHP], eax
.r: popad
    ret

; ---------------------------------------------------------------------
; experience
; ---------------------------------------------------------------------
gain_xp:                            ; eax = XP earned
    pushad
    mov ebx, [gXP]                  ; the Scholar's Ring: +10% per point
    imul ebx, eax
    push eax
    mov eax, ebx
    xor edx, edx
    mov ecx, 10
    div ecx
    pop ebx
    add eax, ebx
    add [playerXP], eax
.lv:
    mov eax, [playerLevel]
    cmp eax, MAX_LEVEL
    jge .d
    mov ebx, [xpTable+eax*4-4]
    cmp [playerXP], ebx
    jl .d
    call level_up
    jmp .lv
.d: call draw_level
    popad
    ret

level_up:
    pushad
    inc dword [playerLevel]
    call class_index
    movzx ebx, byte [classHP+eax]
    add [hpGained], ebx
    test dword [playerLevel], 1
    jnz .odd
    inc dword [statPoints]
.odd:
    mov eax, [playerMaxHP]
    mov [lvTmp], eax
    call apply_perks
    call recalc_gear                ; (it calls recalc_stats: the new max HP heals you by the difference)
    mov dword [lvLen], 0            ; "LEVEL UP! You are level 5 (+9 HP). A third attack each turn! Press U..."
    mov esi, msgLvUp
    mov ecx, msgLvUplen
    call lv_add
    mov eax, [playerLevel]
    call lv_num
    mov esi, msgLvHP
    mov ecx, msgLvHPlen
    call lv_add
    mov eax, [playerMaxHP]
    sub eax, [lvTmp]
    call lv_num
    mov esi, msgLvHP2
    mov ecx, msgLvHP2len
    call lv_add
    call class_index
    imul eax, eax, 20
    add eax, [playerLevel]
    mov esi, [perkText+eax*4-4]
    test esi, esi
    jz .pts
    mov edi, esi                    ; its length
    xor ecx, ecx
.len:
    cmp byte [edi+ecx], 0
    je .add
    inc ecx
    jmp .len
.add:
    call lv_add
.pts:
    cmp dword [statPoints], 0
    je .show
    mov esi, msgLvPick
    mov ecx, msgLvPicklen
    call lv_add
.show:
    call draw_hp
    call draw_mana
    call draw_stats
    popad
    ret

xp_for_kill:                        ; ecx = enemy that died
    pushad
    mov eax, [enemyType+ecx*4]
    movzx ebx, word [xpKill+eax*2]
    call enemy_rec
    cmp byte [esi+ENEMY_BOSS], 0
    jne .g
    mov eax, [floorCount]
    shl eax, 1
    add ebx, eax
.g: mov eax, ebx
    call gain_xp
    popad
    ret

xp_puzzle:                          ; a room's puzzle is solved
    pushad
    mov eax, [floorCount]
    add eax, 25
    cmp dword [puzzleOn], 2
    jne .g
    mov eax, [floorCount]           ; circuits are worth more
    shl eax, 1
    add eax, 40
.g: call gain_xp
    popad
    ret

xp_trick:                           ; a boss trick beaten: 15 + the floor
    pushad
    mov eax, [floorCount]
    add eax, 15
    call gain_xp
    popad
    ret

rest_at_door:                       ; going through the door: no healing - potions only
    ret
    pushad
    mov eax, [playerMaxHP]
    xor edx, edx
    mov ecx, 3
    div ecx
    add eax, [playerHP]
    cmp eax, [playerMaxHP]
    jle .s
    mov eax, [playerMaxHP]
.s: mov [playerHP], eax
    popad
    ret

progress_tick:                      ; every tick: show the level-up line once nothing else is waiting
    call head_notes                 ; icons over heads, when something changed (path.inc)
    cmp dword [lvLen], 0
    je .r
    cmp dword [noteLen], 0
    jne .r
    mov esi, lvBuf
    mov ecx, [lvLen]
    mov dword [lvLen], 0
    call say_str
.r: ret

; ---------------------------------------------------------------------
; spending stat points (U, then 1-4)
; ---------------------------------------------------------------------
start_stat_pick:
    cmp dword [statPoints], 0
    jg .ok
    msg msgNoPts
    ret
.ok:
    mov dword [statPick], 1
    msg msgPickAsk
    ret

pick_stat:                          ; eax = key slot 0..12 while picking
    mov dword [statPick], 0
    cmp eax, 3
    ja .r                           ; any other key: later
    cmp dword [baseStat+eax*4], 24
    jl .up
    msg msgMaxed
    ret
.up:
    inc dword [baseStat+eax*4]
    dec dword [statPoints]
    mov [lvTmp], eax
    call recalc_gear
    call msg_begin                  ; "STR is now 17"
    mov eax, [lvTmp]
    lea esi, [statNames+eax*2]
    add esi, eax
    mov ecx, 3
    call msg_text
    mtext msgRaised
    mov eax, [lvTmp]
    mov eax, [baseStat+eax*4]
    call msg_num
    call msg_end
    call draw_hp
    call draw_mana
    call draw_stats
    call draw_level
.r: ret

; ---------------------------------------------------------------------
; drawing: "Lv:5* XP:310/450" on row 1 (the * means a stat point waits), and the stat row
; ---------------------------------------------------------------------
draw_level:
    pushad
    mov eax, 1
    mov ebx, 36
    call goto_rc
    print_string blank8, 8
    print_string blank8, 8
    print_string blank8, 4
    mov eax, 1
    mov ebx, 36
    call goto_rc
    print_string lvLbl, lvLbllen
    mov eax, [playerLevel]
    call print_integer
    cmp dword [statPoints], 0
    je .x
    print_string starCh, 1
.x: print_string xpLbl, xpLbllen
    mov eax, [playerXP]
    call print_integer
    cmp dword [playerLevel], MAX_LEVEL
    jge .r
    print_string slash, 1
    mov eax, [playerLevel]
    mov eax, [xpTable+eax*4-4]
    call print_integer
.r: popad
    ret

draw_stats:                         ; row 4: STR DEX CON INT (with gear)
    pushad
    mov eax, 4
    mov ebx, 1
    call goto_rc
    print_string blank24, 24
    print_string blank24, 24
    mov eax, 4
    mov ebx, 1
    call goto_rc
    print_string strLabel, strLabellen
    mov eax, [strength]
    call print_integer
    print_string dexLabel, dexLabellen
    mov eax, [dex]
    call print_integer
    print_string conLabel, conLabellen
    mov eax, [con]
    call print_integer
    print_string intLabel, intLabellen
    mov eax, [intel]
    call print_integer
    popad
    ret

; ---------------------------------------------------------------------
; little rules used all over
; ---------------------------------------------------------------------
spell_cost:                         ; esi = spell record -> eax = what it costs YOU
    movzx eax, byte [esi+SPELL_MANA_COST]
    test eax, eax
    jz .r
    push eax
    mov eax, SP_CHEAP
    call has_special
    pop eax
    jnc .f
    cmp eax, 1
    jle .f
    dec eax
.f: cmp dword [pkFreeSpell], 0
    je .r
    cmp dword [freeSpellUsed], 0
    jne .r
    xor eax, eax                    ; the wizard's free spell of the fight
.r: ret

spell_bonus:                        ; esi = spell record, eax = damage rolled -> eax with level and gear bonuses
    push ebx
    push ecx
    push edx
    mov [lvTmp], eax
    cmp byte [esi+SPELL_MANA_COST], 0
    jne .nc
    mov ecx, [pkCantrip]            ; cantrips: extra dice
.c: test ecx, ecx
    jz .nc
    push ecx
    movzx eax, byte [esi+SPELL_MAX_DAMAGE]
    movzx ebx, byte [esi+SPELL_MIN_DAMAGE]
    sub eax, ebx
    inc eax
    call rand_mod
    add eax, ebx
    add [lvTmp], eax
    pop ecx
    dec ecx
    jmp .c
.nc:
    mov eax, [lvTmp]
    add eax, [gSpell]
    add eax, [pkSpellDmg]
    cmp dword [pkSpellHalf], 0
    je .r
    mov ebx, eax
    shr ebx, 1
    add eax, ebx
.r: pop edx
    pop ecx
    pop ebx
    ret

player_round_end:                   ; end of every combat round: regeneration
    call holy_burn_tick             ; the bishops' Smite (bosses2.inc)
    pushad
    mov eax, [pkRegen]
    add eax, [gRegen]
    test eax, eax
    jz .r
    add eax, [playerHP]
    cmp eax, [playerMaxHP]
    jle .s
    mov eax, [playerMaxHP]
.s: mov [playerHP], eax
    call draw_hp
.r: popad
    ret

incoming_hit:                       ; ecx = the enemy hitting you, eax = damage -> eax after your defences   (keeps the rest)
    push ebx
    push edx
    push esi
    mov ebx, eax
    cmp dword [pkReflect], 0        ; ranged: halved by Mirror Shield, Keeper's Cloak, the rogue's level 17
    jne .rf
    mov eax, SP_REFLECT
    call has_special
    jnc .fh
.rf:
    push ebx
    call dist_to_player
    pop ebx
    cmp eax, 1
    jle .fh
    shr ebx, 1
.fh:
    cmp dword [firstHitUsed], 0     ; the first hit of each fight
    jne .th
    cmp dword [pkFirstHit], 0
    jne .half
    mov eax, SP_FIRSTHIT
    call has_special
    jnc .th
.half:
    mov dword [firstHitUsed], 1
    shr ebx, 1
.th:
    mov eax, [gThorns]              ; thorns: it hurts them too (never kills: they keep 1 HP)
    test eax, eax
    jz .r
    cmp ecx, -1
    je .r
    sub [enemyHP+ecx*4], eax
    cmp dword [enemyHP+ecx*4], 1
    jge .r
    mov dword [enemyHP+ecx*4], 1
.r: mov eax, ebx
    pop esi
    pop edx
    pop ebx
    ret

weapon_on_hit:                      ; the hit landed on enemy [eIdx] (still alive): the weapon's effect, lifesteal
    pushad
    mov esi, [equipWeapon]
    test esi, esi
    jz .ls
    mov edi, [esi+CAT_PTR]
    movzx eax, byte [edi+WEAPON_EFFECT]
    test eax, eax
    jz .ls
    cmp eax, EFFECT_BURN            ; burn, slow and poison always; the strong ones 1 time in 3
    je .apply
    cmp eax, EFFECT_SLOW
    je .apply
    cmp eax, EFFECT_POISON
    je .apply
    push eax
    mov eax, 3
    call rand_mod
    mov edx, eax
    pop eax
    test edx, edx
    jnz .ls
.apply:
    call apply_status
.ls:
    mov eax, SP_LIFESTEAL
    call has_special
    jnc .r
    mov eax, [dmg]
    xor edx, edx
    mov ebx, 3
    div ebx
    test eax, eax
    jz .r
    add eax, [playerHP]
    cmp eax, [playerMaxHP]
    jle .h
    mov eax, [playerMaxHP]
.h: mov [playerHP], eax
    call draw_hp
.r: popad
    ret
; ===== end progress.inc =====
