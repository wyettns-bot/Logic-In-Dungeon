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
    cmp dword [enemyType+ecx*4], ETYPE_UNBOUND
    jne .plain
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
