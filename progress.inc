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

TRICK_XP_MAX equ 3                 ; boss tricks that pay XP on each floor
section .bss
playerLevel resd 1
playerXP    resd 1
statPoints  resd 1
trickCount  resd 1              ; boss tricks paid for on this floor (see xp_trick)
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
    mov dword [trickCount], 0
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

xp_trick:                           ; a boss trick beaten: 15 + the floor - only the first 3 on each floor pay
    cmp dword [trickCount], TRICK_XP_MAX   ; (so a boss's trick can't be repeated to farm experience;
    jae .r                                 ;  restarting the room doesn't reset the count, a new floor does)
    inc dword [trickCount]
    pushad
    mov eax, [floorCount]
    add eax, 15
    call gain_xp
    popad
.r: ret

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
