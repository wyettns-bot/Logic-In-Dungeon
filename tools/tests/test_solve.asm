; test_solve.asm - TEST ONLY (appended to game.asm by testbuild.py "solve"): the ! key sets the torches right

test_solve:                     ; TEST ONLY: set the torches so the current trick is beaten
    pushad
    cmp dword [isUnbound], 0
    jne .unb
    mov eax, [bossRoom]         ; the bosses themselves
    cmp eax, 1
    je .ward
    cmp eax, 2
    je .circ
    cmp eax, 3
    je .circ
    cmp eax, BR_YMIR
    je .ymir
    cmp eax, BR_KEEPER
    je .keep
    jmp .d
.unb:
    mov eax, [uMode]
    cmp eax, UF_KEEPER
    je .keep
    cmp eax, UF_WARDEN
    je .ward
    cmp eax, UF_SHADE
    je .circ
    cmp eax, UF_YMIR
    je .ymir
    jmp .d
.ward:
    xor ebx, ebx
.w: mov eax, ebx
    and al, 1
    mov [nodeBit], al
    mov eax, ebx
    shr eax, 1
    mov [nodeBit+1], al
    push ebx
    call puzzle_solved
    pop ebx
    test eax, eax
    jnz .t
    inc ebx
    cmp ebx, 4
    jb .w
    jmp .t
.keep:
    xor ecx, ecx
.kl:mov [bx2], ecx
    xor ebx, ebx
.kb:mov eax, ebx
    and al, 1
    mov ecx, [bx2]
    mov [nodeBit+ecx*2], al
    mov eax, ebx
    shr eax, 1
    mov [nodeBit+ecx*2+1], al
    call keeper2_pair_ok
    jc .kn
    inc ebx
    cmp ebx, 4
    jb .kb
.kn:mov ecx, [bx2]
    inc ecx
    cmp ecx, 2
    jb .kl
    jmp .t
.circ:
    xor ebx, ebx
.c: xor ecx, ecx
.cb:cmp ecx, [circNT]
    jge .ce
    bt ebx, ecx
    setc al
    mov [nodeBit+ecx], al
    inc ecx
    jmp .cb
.ce:push ebx
    call circ_eval
    pop ebx
    cmp dword [circOut], 0
    jne .t
    inc ebx
    cmp ebx, 16
    jb .c
    jmp .t
.ymir:
    xor ebx, ebx
.y: xor ecx, ecx
.yb:cmp ecx, [circNT]
    jge .ye
    bt ebx, ecx
    setc al
    mov [nodeBit+ecx], al
    inc ecx
    jmp .yb
.ye:push ebx
    call circ_eval
    pop ebx
    call ymir_power
    test eax, eax
    jz .t
    inc ebx
    cmp ebx, 16
    jb .y
.t: call boss_torch
.d: popad
    ret
