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
