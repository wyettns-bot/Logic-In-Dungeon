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

%include "game_assets.asm"      ; weapons, armor, the SPELL table, spell names, class bits

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
    call keeper_like                    ; the Keeper's Wardens stand guard beside it (and the Unbound's)
    jne .mv
    cmp dword [enemyType+ecx*4], ETYPE_MINIBOSS
    jne .mv
    xor eax, eax
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

%include "path.inc"             ; finding a way round things; notes for the window
%include "room.inc"             ; the 1x3 door, the plaque, logic gate puzzles, boss rooms
%include "enemies.inc"          ; enemy types, big bodies, how they fight
%include "features.inc"         ; inventory, loot, Battle Master, stealth
%include "bosses.inc"           ; Ymir, the Logic Keeper, Altair and Smo
%include "bosses2.inc"          ; the Four Bishops, the Keeper's Wardens
%include "progress.inc"         ; levels, XP, perks, what your gear adds
