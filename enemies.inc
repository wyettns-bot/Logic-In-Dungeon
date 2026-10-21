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
