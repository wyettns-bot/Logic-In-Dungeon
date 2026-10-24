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
    cmp edx, ETYPE_UNBOUND
    jne .sk
    cmp dword [uMode], UF_ALTAIR        ; the Unbound strikes as the boss he imitates
    jne .us
    mov bl, 'l'
.us:cmp dword [uMode], UF_SMO
    jne .go
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
