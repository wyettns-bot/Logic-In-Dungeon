; game.asm  -  SPELL DEMO build
; Explore (real time) / Combat (turn based) modes, random enemies, and a working spell system
; driven by the spell table in game_assets.asm.
;
; Build:  ./build.sh          (or by hand:)
;   nasm -f elf32 CC.asm -o CC.o
;   nasm -f elf32 registerdungeon.asm -o registerdungeon.o   (single file: everything is inside)
;   ld -m elf_i386 registerdungeon.o CC.o -o registerdungeon

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

; ===== game_assets.asm (pasted in) =====
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

	;enemy stats 10 bytes
	ENEMY_HP_MIN equ 0
	ENEMY_HP_MAX equ 1
	ENEMY_DMG_MIN equ 2
	ENEMY_DMG_MAX equ 3
	ENEMY_ATK_BONUS equ 4 ;added to its d20 attack roll against your armor class
	ENEMY_RANGE equ 5 ;1 = melee, more = it attacks from that many cells away
	ENEMY_MOVE equ 6 ;cells it can move in one enemy turn (at most 4)
	ENEMY_W equ 7 ;size on the grid
	ENEMY_H equ 8
	ENEMY_BOSS equ 9 ;(normal|mini boss|final boss) = 0, 1, 2
	ENEMY_SIZE equ 10

	;hp min, hp max, dmg min, dmg max, attack bonus, range, move, width, height, boss
	enemyTable:
	goblin db 5,7, 1,3, 3, 1, 4, 1,1, 0 ;fast and weak
	skeleton db 6,8, 1,4, 2, 6, 3, 1,1, 0 ;shoots from 6 cells away
	orc db 12,16, 2,6, 4, 1, 3, 1,1, 0 ;slow, tough, hits hard
	miniboss db 40,50, 3,8, 5, 1, 3, miniboss_w,miniboss_h, 1
	finalboss db 100,120, 4,10, 6, 2, 3, finalboss_w,finalboss_h, 2 ;the Forgotten King
	ENEMY_TYPES equ ($ - enemyTable) / ENEMY_SIZE
	ETYPE_GOBLIN equ 0
	ETYPE_SKELETON equ 1
	ETYPE_ORC equ 2
	ETYPE_MINIBOSS equ 3
	ETYPE_KING equ 4

	;the sprite of each enemy type, same order as the table
	enemySprites dd goblinIcon, skeletonIcon, orcIcon, minibossIcon, finalbossIcon

	;which normal enemies show up: out of 10, (goblin, skeleton, orc) for floors 1-2, 3-6, 7+
	spawnOdds db 6,3,1, 4,4,2, 2,4,4

	;boss floors
	MINIBOSS_FLOORS equ 3
	minibossFloors db 4, 6, 11
	FINAL_FLOOR equ 15

	;potions
	minorPotion db 3		; heals 3
	regPotion db 6			; heals 6
	largePotion db 12       ; heals 12

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

	;the class bit for each class number (class '1','2','3' -> Fighter, Rogue, Wizard)

section .bss

section .text
; ===== end of game_assets.asm =====


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
MAX_ENEMIES equ 4
TB_COL      equ 46       ; the clickable turn-based button on row 23
TB_LEN      equ 19
START_X     equ 1
START_Y     equ 6
TICK_MS     equ 90
NOTICE      equ 6        ; explore: enemies this close start chasing you
AGGRO       equ 3        ; explore: enemies this close start COMBAT (set to 0 to switch combat off)
ESTEPS      equ 4        ; enemy phase lasts this many ticks
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

basehp db 12, 9, 7      ; Fighter, Rogue, Wizard

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
        db "   The last register is cleared. You have won!", 10
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

    call init_features              ; bag, starting gear, class features (features.inc)
    mov dword [inFight], 0
    mov dword [tbForced], 0
    call setup_room                 ; floor 1: the tutorial room, door open (room.inc)
    call spawn_enemies
    call redraw_all
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
    mov ebx, [strength]
    shr ebx, 3
    add eax, ebx
    mov [dmg], eax
    mov ecx, [eIdx]
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
    mov eax, DICE_MAX
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
    movzx eax, byte [spellTable+ebx+SPELL_MANA_COST]
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
    movzx eax, byte [esi+SPELL_MANA_COST]
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
.d: ret

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
    call get_scaling_stat       ; + (best flagged stat) / 8
    shr eax, 3
    add [dmg], eax
    mov eax, [dmg]
    add [totalDmg], eax
    mov ecx, [eIdx]
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
    movzx eax, byte [esi+SPELL_MANA_COST]
    sub [playerMana], eax
    call draw_mana
    cmp dword [gameMode], MODE_COMBAT
    jne .cast
    mov dword [attacked], 1     ; a spell is this turn's action
    mov dword [attacksLeft], 0
.cast:
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
    cmp dword [manaTick], MANA_REGEN_TICKS
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
    mov eax, [playerX]
    mov ebx, [tgtX]
    call step_toward
    mov [nX], eax
    mov eax, [playerY]
    mov ebx, [tgtY]
    call step_toward
    mov [nY], eax
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

; ===== room.inc (pasted in) =====
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
msgWarden db "A Warden guards this room! Defeat it to open the door."
msgWardenlen equ $- msgWarden
msgKing db "The Forgotten King stirs on his throne..."
msgKinglen equ $- msgKing
msgFalls db "The guardian falls. The door grinds open."
msgFallslen equ $- msgFalls

section .bss
doorOpen   resd 1
bossRoom   resd 1               ; 0 normal, 1 Warden (mini boss), 2 the Forgotten King
puzzleOn   resd 1               ; 0 in the tutorial room
puzzleGate resd 1               ; 0..5  (AND OR XOR NAND NOR XNOR)
puzzleAll  resd 1               ; 1 = every accepted input must be shown
puzzlePairs resd 1
nodeBit    resb MAX_PAIRS*2     ; 0 / 1 for each torch
roomTmp    resd 1
roomTry    resd 1
seenSet    resd 1
touched    resd 1               ; 1 = touch_node flipped the torch, 0 = it was too far

section .text

; ---------------------------------------------------------------------
; set up the room you just entered (call AFTER floorCount is set)
; ---------------------------------------------------------------------
setup_room:
    mov dword [puzzleOn], 0
    mov dword [doorOpen], 1
    mov dword [bossRoom], 0
    cmp dword [floorCount], 1
    jle .r                          ; tutorial room: no puzzle, door open
    mov eax, [floorCount]           ; boss rooms have no puzzle: the boss IS the lock
    cmp eax, FINAL_FLOOR
    je .king
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
    ret
.mini:
    mov dword [bossRoom], 1
    mov dword [doorOpen], 0
    ret
.puzzle:
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

puzzle_solved:                      ; -> eax = 1 if the torches satisfy the gate
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

node_at:                            ; eax=x, ebx=y -> eax = torch number or -1, edx = column inside its "[0]"
    cmp dword [puzzleOn], 0
    je .none
    push ebx
    push ecx
    sub ebx, NODE_Y0
    js .nope
    mov ecx, eax
    mov eax, ebx                    ; which pair row?
    xor edx, edx
    push ecx
    mov ecx, NODE_DY
    div ecx
    pop ecx
    test edx, edx
    jnz .nope                       ; between the pair rows
    cmp eax, [puzzlePairs]
    jge .nope
    mov ebx, eax                    ; ebx = pair
    mov eax, ecx
    sub eax, NODE_X
    js .nope
    cmp eax, puzzlenode_w*2
    jge .nope
    xor edx, edx
    mov ecx, puzzlenode_w
    div ecx                         ; eax = 0 (A) or 1 (B), edx = column 0..2
    lea eax, [ebx*2+eax]
    pop ecx
    pop ebx
    ret
.nope:
    pop ecx
    pop ebx
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
    je .floor
    mov ecx, edx                    ; column inside the sprite
    cmp byte [nodeBit+eax], 0
    jne .lit
    mov dl, [puzzlenode+ecx]        ; "[0]"
    jmp .out
.lit:
    mov dl, [puzzlenodeactive+ecx]  ; "[1]"
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
    call draw_door
    cmp dword [puzzleOn], 0
    je .d
    mov eax, PLAQUE_X
    mov ebx, PLAQUE_Y
    call room_glyph
    call put_cell
    xor ecx, ecx                    ; every cell of every torch pair
.pair:
    cmp ecx, [puzzlePairs]
    jge .d
    xor esi, esi
.col:
    cmp esi, puzzlenode_w*2
    jge .np
    mov eax, NODE_X
    add eax, esi
    imul ebx, ecx, NODE_DY
    add ebx, NODE_Y0
    call room_glyph
    call put_cell
    inc esi
    jmp .col
.np:
    inc ecx
    jmp .pair
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
    mov ecx, eax                    ; where is it?  pair = n/2, side = n%2
    shr ecx, 1
    imul ebx, ecx, NODE_DY
    add ebx, NODE_Y0                ; ebx = its row
    mov eax, [roomTmp]
    and eax, 1
    imul eax, eax, puzzlenode_w
    add eax, NODE_X                 ; eax = its left column
    mov ecx, [playerY]              ; you must be within 1 row ...
    sub ecx, ebx
    jns .y
    neg ecx
.y: cmp ecx, 1
    jg .far
    mov ecx, [playerX]              ; ... and within 1 column of its 3 cells
    sub ecx, eax
    cmp ecx, -1
    jl .far
    cmp ecx, puzzlenode_w
    jg .far
    mov ecx, [roomTmp]
    xor byte [nodeBit+ecx], 1
    mov dword [touched], 1
    call draw_room_objects
    cmp dword [doorOpen], 0
    jne .d                          ; already open: it stays open
    call puzzle_solved
    test eax, eax
    jz .d
    mov dword [doorOpen], 1
    call draw_door
    msg msgOpen
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
    cmp dword [bossRoom], 1
    je .w
    cmp dword [bossRoom], 2
    je .k
    ret
.w: msg msgWarden
    ret
.k: msg msgKing
    ret

; ===== end of room.inc =====

; ===== enemies.inc (pasted in) =====
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
    mov esi, [enemySprites+esi*4]
    mov dl, [esi+ebx]
    pop esi
    pop ebx
    pop eax
    ret

draw_enemy:                     ; ecx = enemy: draw every cell of its body
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

enemy_move_to:                  ; move enemy [eI] so its top-left is at [nX],[nY] - only if its WHOLE body fits there
    mov ecx, [eI]
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

enemy_step_toward_player:       ; enemy [eI] takes one step, aiming its MIDDLE at you
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
    jmp enemy_move_to

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
    call set_area_to_enemy      ; (before it disappears: we need its size)
    call enemy_rec
    mov dword [enemyHP+ecx*4], 0
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
    mov ebx, [floorCount]       ; + (floor-1)/3
    dec ebx
    push eax
    mov eax, ebx
    xor edx, edx
    mov ebx, 3
    div ebx
    mov ebx, eax
    pop eax
    add eax, ebx
    mov [enemyHP+ecx*4], eax
    pop esi
    ret

pick_normal_type:               ; -> eax = goblin / skeleton / orc, by this floor's odds
    mov ebx, 0                  ; tier: floors 1-2, 3-6, 7+
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
    mov eax, ETYPE_MINIBOSS     ; a boss room: just the boss, in the middle of the room
    cmp dword [bossRoom], 2
    jne .b
    mov eax, ETYPE_KING
.b: mov [enemyType], eax
    mov dword [enemyX], 26
    mov dword [enemyY], 5
    xor ecx, ecx
    call roll_hp
    ret
.normal:
    mov eax, 2
    call rand_mod
    add eax, 3                  ; 3..4 enemies
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
    call dist_to_player
    movzx edx, byte [esi+ENEMY_RANGE]
    cmp eax, edx
    jg .n                       ; out of its reach
    movzx ebx, byte [esi+ENEMY_ATK_BONUS]
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
    call absorb_damage          ; Parry and Rally soak it first
    sub [playerHP], eax
    mov ecx, [eI]
    call say_enemy_attack
    jmp .n
.miss:
    mov ecx, [eI]
    mov eax, -1
    call say_enemy_attack
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
draw_panel:
    pushad
    mov dword [pi], 0
.l: mov eax, [pi]
    cmp eax, MAX_ENEMIES
    jge .d
    xor ecx, ecx
.f: mov byte [panelBuf+ecx], ' '
    inc ecx
    cmp ecx, 24
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
    mov byte [panelBuf+3], 'H'
    mov byte [panelBuf+4], 'P'
    mov byte [panelBuf+5], ':'
    mov eax, [enemyHP+ecx*4]    ; up to 3 digits
    mov ebx, 10
    xor edx, edx
    div ebx
    add dl, '0'
    mov [panelBuf+8], dl
    test eax, eax
    jz .s0
    xor edx, edx
    div ebx
    add dl, '0'
    mov [panelBuf+7], dl
    test eax, eax
    jz .s0
    add al, '0'
    mov [panelBuf+6], al
.s0:
    mov dword [pj], 1
    mov dword [pk], 10
.s: imul ebx, [pi], STAT_STRIDE
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
.w: mov eax, [pi]
    add eax, 2
    mov ebx, PANEL_COL
    call goto_rc
    print_string panelBuf, 24
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

; ===== end of enemies.inc =====

; ===== features.inc (pasted in) =====
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
CAT_SIZE   equ 24

%macro catalog 5                 ; label, "Name", record, kind, weight
%1:
    fixedname %2
    dd %3
    db %4, %5, 0, 0
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
CATALOG_COUNT equ ($ - catalogTable) / CAT_SIZE

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
          dd cat_dagger,     cat_leather        ; Rogue
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
msgPicked  db "You pick up an item"
msgPickedlen equ $- msgPicked
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
    movzx ebx, byte [edi]       ; heal amount
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
    jne .w
.star:
    mov byte [menuBuf+21], '*'
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
    shr eax, 3
    pop ebx
    add eax, ebx
    ret

absorb_damage:                  ; eax = damage coming in -> eax = damage that reaches your HP
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
    cmp dword [hidden], 0       ; ROGUE: sneak attack = 2d6 + 2, then you are seen
    je .nosneak
    mov eax, 6
    call rand_mod
    mov ebx, eax
    mov eax, 6
    call rand_mod
    add eax, ebx
    add eax, 4
    add [dmg], eax
    mov dword [hidden], 0
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
    sub [enemyHP+ecx*4], eax
    call wake_enemy             ; getting hurt ends Sleep
    mov esi, msgHit
    mov ecx, msgHitlen
    call say_num                ; "You hit for N"
    mov ecx, [eIdx]
    cmp dword [enemyHP+ecx*4], 0
    jg .alive
    call kill_enemy
    jmp .ok
.alive:
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
    mov dword [attacksLeft], 1
    movzx eax, byte [class]
    cmp eax, '1'
    jne .a
    mov dword [attacksLeft], 2  ; the fighter attacks twice
.a: ret

end_of_combat:                  ; call when a fight is over: dice come back
    mov dword [diceLeft], DICE_MAX
    mov dword [surgeUsed], 0
    mov dword [pendingMan], 0
    mov dword [tempHP], 0
    mov dword [parryBonus], 0
    ret

spend_die:                      ; -> eax = d8 + STR/8, or CF=1 if no dice are left
    cmp dword [diceLeft], 0
    jle .none
    dec dword [diceLeft]
    mov eax, 8
    call rand_mod
    inc eax
    mov ebx, [strength]
    shr ebx, 3
    add eax, ebx
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

action_surge:                   ; G key: once per fight, two extra attacks
    cmp dword [surgeUsed], 0
    jne .r
    movzx eax, byte [class]
    cmp eax, '1'
    jne .r
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
    cmp dword [attacksLeft], 0  ; ...and in a fight, hiding is your action for the turn
    jle .busy
    mov dword [attacksLeft], 0
.ok:
    mov dword [hidden], 1
    msg msgHidden
.r: ret
.busy:
    msg msgAct
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
    call roll_loot              ; esi = the item
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
    msg msgPicked
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
    jne .gone
    mov dword [equipShield], 0
    mov dword [wornS], -1
.gone:
    mov dword [inv+eax*4], 0
    call recalc_gear
    call draw_inventory
    call draw_mana              ; AC and weapon line
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
.r: ret

; =====================================================================
; one call to set everything up (after character creation, and in reset_arena)
; =====================================================================
init_features:
    mov dword [diceLeft], DICE_MAX
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
    mov dword [wornW], -1
    mov dword [wornB], -1
    mov dword [wornS], -1
    call build_spell_list
    call give_start_gear
    call recalc_gear
    call begin_player_turn
    ret

; ===== end of features.inc =====

