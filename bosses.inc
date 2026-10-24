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
