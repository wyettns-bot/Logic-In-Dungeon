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
%include "items_cat.inc"         ; the rare and legendary items (made by items.py)
CATALOG_COUNT equ ($ - catalogTable) / CAT_SIZE
%include "items_loot.inc"        ; which legendary each boss drops, per class

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
