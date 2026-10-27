; =====================================================================
; circuit.inc  -  the logic circuit puzzles of the second half (floors 16-29)
;
; A circuit room has 3 or 4 torches (the inputs, [0] / [1]) wired into 2 or 3 gates.
; Gates feed other gates; the last gate's wire runs to the door. The door opens when
; that wire carries a 1. Every wire shows its value, and every gate shows its output,
; so the player can watch the signal travel and work out what to change.
;
; On the map (and so in the terminal):
;   gate: a 3x3 block, its border '%' when the gate outputs 0, '$' when it outputs 1,
;         and a letter in the middle:  A=AND  V=OR  X=XOR  a=NAND  v=NOR  E=XNOR  N=NOT  ?=hidden
;   wire: '-' / ':' carrying 0 (horizontal / vertical),  '=' / '|' carrying 1
;
;   floors 16-20: (A ? B) ? C                         two chained gates
;   floors 21-24: that, or (A ? B) ? NOT C           a NOT gate joins in
;   floors 25-29: (A ? B) ? (C ? D)  or the NOT one,  and one gate is hidden behind "?":
;                 only the plaque's riddle says what it is (its output still shows)
; The layouts are in circuits.inc (made by gen_circuits.py, which also checks them).
; =====================================================================

section .data
HALF_FLOOR equ 15               ; circuits start after this floor
gateLetter db 'A', 'V', 'X', 'a', 'v', 'E', 'N', 'L'    ; AND OR XOR NAND NOR XNOR NOT, L = the Shade's lantern
GT_NOT equ 6
GT_LANTERN equ 7                ; works like AND, drawn as the lantern in the middle of the Shade's room

%include "circuits.inc"

msgCirc db "CIRCUIT - power the wire that runs to the door."
msgCirclen equ $- msgCirc
msgCircHid db "CIRCUIT - power the door. The ? gate: "
msgCircHidlen equ $- msgCircHid

section .bss
circNT  resd 1                  ; torches
circTX  resb 4
circTY  resb 4
circNG  resd 1                  ; gates
circGA  resb 3                  ; first input (node number)
circGB  resb 3                  ; second input, 255 = NOT gate
circGX  resb 3                  ; centre of its 3x3 block
circGY  resb 3
circGT  resb 3                  ; gate type 0..5, 6 = NOT
circNW  resd 1                  ; wire cells
circWD  resd 1                  ; address of the wire cells: x, y, node
circOutNode resd 1
circHidden resd 1               ; gate number shown as "?", -1 = none, -2 = every gate (the King's last phase)
circVal resb 8                  ; the value on every node: 0..3 torches, 4..6 gates
circOut resd 1                  ; the value reaching the door
circTry resd 1
circCombo resd 1
circSols resd 1
cdI resd 1
cdJ resd 1

section .text

; ---------------------------------------------------------------------
; set up a circuit room
; ---------------------------------------------------------------------
setup_circuit:
    pushad
    mov dword [puzzleOn], 2
    mov dword [doorOpen], 0
    mov dword [circHidden], -1
    mov eax, CT_A                   ; which layout
    cmp dword [floorCount], 20
    jle .load
    mov eax, 2
    call rand_mod
    cmp dword [floorCount], 24
    jle .ac
    test eax, eax                   ; floors 25+: B or C
    mov eax, CT_B
    jz .load
    mov eax, CT_C
    jmp .load
.ac:
    test eax, eax                   ; floors 21-24: A or C
    mov eax, CT_A
    jz .load
    mov eax, CT_C
.load:
    cmp dword [demoLayout], 0       ; demo mode can ask for one layout (demo.inc)
    jl .ld
    mov eax, [demoLayout]
.ld:
    call circ_load
    jmp circ_pick_types

circ_load:                          ; eax = layout number: copy its torches, gates and wires   (keeps eax)
    pushad
    mov esi, [circTorchTab+eax*4]   ; torches: count, then x,y
    movzx ecx, byte [esi]
    mov [circNT], ecx
    xor edx, edx
.lt:
    cmp edx, ecx
    jge .lg
    mov bl, [esi+1+edx*2]
    mov [circTX+edx], bl
    mov bl, [esi+2+edx*2]
    mov [circTY+edx], bl
    inc edx
    jmp .lt
.lg:
    mov esi, [circGateTab+eax*4]    ; gates: count, then inA, inB, cx, cy
    movzx ecx, byte [esi]
    mov [circNG], ecx
    xor edx, edx
.lg2:
    cmp edx, ecx
    jge .lw
    mov bl, [esi+1+edx*4]
    mov [circGA+edx], bl
    mov bl, [esi+2+edx*4]
    mov [circGB+edx], bl
    mov bl, [esi+3+edx*4]
    mov [circGX+edx], bl
    mov bl, [esi+4+edx*4]
    mov [circGY+edx], bl
    inc edx
    jmp .lg2
.lw:
    mov esi, [circWireTab+eax*4]    ; wires: count (word), then x, y, node
    movzx ecx, word [esi]
    mov [circNW], ecx
    add esi, 2
    mov [circWD], esi
    mov esi, [circOutTab+eax*4]
    movzx ecx, byte [esi]
    mov [circOutNode], ecx
    popad
    ret

circ_pick_types:                    ; (still inside setup_circuit's pushad)
    ; pick gate types until the circuit is solvable, but not by most inputs
    mov dword [circTry], 300
.types:
    xor edx, edx
.gt:
    cmp edx, [circNG]
    jge .count
    mov byte [circGT+edx], GT_NOT
    cmp byte [circGB+edx], 255
    je .gn
    push edx
    mov eax, GATE_COUNT
    call rand_mod
    pop edx
    mov [circGT+edx], al
.gn:
    inc edx
    jmp .gt
.count:                             ; try every torch setting, count the ones that open the door
    mov dword [circSols], 0
    mov dword [circCombo], 0
.cl:
    mov ecx, [circNT]
    mov eax, 1
    shl eax, cl
    cmp [circCombo], eax
    jge .judge
    xor edx, edx
.cb:
    cmp edx, [circNT]
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
.judge:
    dec dword [circTry]
    jz .start                       ; (give up being picky)
    cmp dword [circSols], 0
    je .types                       ; nothing opens it
    mov ecx, [circNT]
    mov eax, 1
    shl eax, cl
    shr eax, 1
    cmp [circSols], eax
    jg .types                       ; too easy: more than half of all settings work
.start:                             ; a random starting setting that does NOT open the door
    mov dword [circTry], 100
.st:
    xor edx, edx
.sb:
    cmp edx, [circNT]
    jge .se
    push edx
    mov eax, 2
    call rand_mod
    pop edx
    mov [nodeBit+edx], al
    inc edx
    jmp .sb
.se:
    call circ_eval
    cmp dword [circOut], 0
    je .hide
    dec dword [circTry]
    jnz .st
.hide:
    cmp dword [floorCount], 25      ; floors 25+: one gate (not the NOT) is hidden
    jl .done
.hp:
    mov eax, [circNG]
    call rand_mod
    cmp byte [circGB+eax], 255
    je .hp
    mov [circHidden], eax
.done:
    call circ_eval
    popad
    ret

; ---------------------------------------------------------------------
; run the signals through the circuit
; ---------------------------------------------------------------------
circ_eval:
    pushad
    xor ecx, ecx
.t: cmp ecx, [circNT]
    jge .g
    mov al, [nodeBit+ecx]
    mov [circVal+ecx], al
    inc ecx
    jmp .t
.g: xor ecx, ecx
.gl:
    cmp ecx, [circNG]
    jge .out
    movzx ebx, byte [circGA+ecx]
    movzx eax, byte [circVal+ebx]   ; a
    movzx edx, byte [circGT+ecx]
    cmp edx, GT_NOT
    jne .two
    xor al, 1                       ; NOT a
    jmp .set
.two:
    movzx ebx, byte [circGB+ecx]
    movzx ebx, byte [circVal+ebx]   ; b
    shl eax, 1
    or eax, ebx                     ; a*2 + b: the row of the truth table
    cmp edx, GT_LANTERN
    jne .tt
    xor edx, edx                    ; the lantern is an AND
.tt:
    movzx edx, byte [gateTruth+edx]
    bt edx, eax
    setc al
.set:
    mov [circVal+4+ecx], al
    inc ecx
    jmp .gl
.out:
    mov ebx, [circOutNode]
    movzx eax, byte [circVal+ebx]
    mov [circOut], eax
    popad
    ret

; ---------------------------------------------------------------------
; what is where
; ---------------------------------------------------------------------
circ_find_gate:                     ; eax=x, ebx=y -> ecx = gate on that cell or -1, edx = 1 on its centre   (keeps eax, ebx)
    xor ecx, ecx
.l: cmp ecx, [circNG]
    jge .none
    movzx edx, byte [circGX+ecx]
    sub edx, eax
    cmp edx, -1
    jl .n
    cmp edx, 1
    jg .n
    movzx edx, byte [circGY+ecx]
    sub edx, ebx
    cmp edx, -1
    jl .n
    cmp edx, 1
    jg .n
    movzx edx, byte [circGX+ecx]    ; centre?
    cmp edx, eax
    jne .edge
    movzx edx, byte [circGY+ecx]
    cmp edx, ebx
    jne .edge
    mov edx, 1
    ret
.edge:
    xor edx, edx
    ret
.n: inc ecx
    jmp .l
.none:
    mov ecx, -1
    ret

circ_gate_obstacle:                 ; eax=x, ebx=y -> CF=1 on a gate   (keeps everything)
    push ecx
    push edx
    call circ_find_gate
    cmp ecx, -1
    pop edx
    pop ecx
    je .no
    stc
    ret
.no:
    clc
    ret

circ_glyph:                         ; eax=x, ebx=y -> al = the circuit's character there, or 0   (keeps ebx, esi, edi)
    push esi
    push edi
    push ecx
    push edx
    call circ_find_gate
    cmp ecx, -1
    je .wires
    test edx, edx
    jz .border
    movzx edx, byte [circGT+ecx]
    cmp edx, GT_LANTERN
    je .letter                      ; the lantern is never hidden
    push eax
    mov eax, SP_REVEAL              ; the Truth Amulet shows hidden gates
    call has_special
    pop eax
    jc .letter
    cmp ecx, [circHidden]
    mov al, '?'
    je .out
    cmp dword [circHidden], -2
    je .out
.letter:
    mov al, [gateLetter+edx]
    jmp .out
.border:
    cmp byte [circGT+ecx], GT_LANTERN
    jne .bv
    cmp dword [lanternT], 0
    mov al, '$'
    jne .out                        ; the lantern stays lit for its rounds
.bv:
    cmp byte [circVal+4+ecx], 0
    mov al, '%'
    je .out
    mov al, '$'
    jmp .out
.wires:
    mov esi, [circWD]
    xor ecx, ecx
.wl:
    cmp ecx, [circNW]
    jge .none
    lea edi, [ecx+ecx*2]
    cmp al, [esi+edi]               ; x (eax < 256 here)
    jne .wn
    cmp bl, [esi+edi+1]             ; y
    jne .wn
    movzx edx, byte [esi+edi+2]     ; the node this wire carries
    mov dl, [circVal+edx]           ; dl = its value
    xor dh, dh                      ; dh = 1 if it runs up/down here
    test ecx, ecx
    jz .nx
    cmp al, [esi+edi-3]             ; the previous cell of the same wire has the same x: vertical
    jne .nx
    mov ah, [esi+edi-1]
    cmp ah, [esi+edi+2]
    jne .nx
    mov dh, 1
.nx:
    push ecx
    inc ecx
    cmp ecx, [circNW]
    pop ecx
    jge .pick
    mov al, [esi+edi]
    cmp al, [esi+edi+3]             ; the next cell of the same wire has the same x: vertical
    jne .pick
    mov ah, [esi+edi+5]
    cmp ah, [esi+edi+2]
    jne .pick
    mov dh, 1
.pick:
    test dh, dh
    jnz .vert
    mov al, '-'
    test dl, dl
    jz .out
    mov al, '='
    jmp .out
.vert:
    mov al, ':'
    test dl, dl
    jz .out
    mov al, '|'
    jmp .out
.wn:
    inc ecx
    jmp .wl
.none:
    xor al, al
.out:
    pop edx
    pop ecx
    pop edi
    pop esi
    ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
circ_cell:                          ; eax=x, ebx=y: draw whatever belongs there
    pushad
    call cell_glyph
    call put_cell
    popad
    ret

circ_draw:                          ; every torch, gate and wire
    pushad
    mov dword [cdI], 0
.t: mov ecx, [cdI]
    cmp ecx, [circNT]
    jge .g0
    movzx eax, byte [circTX+ecx]
    movzx ebx, byte [circTY+ecx]
    call circ_cell
    inc eax
    call circ_cell
    inc eax
    call circ_cell
    inc dword [cdI]
    jmp .t
.g0:
    mov dword [cdI], 0
.g: mov ecx, [cdI]
    cmp ecx, [circNG]
    jge .w0
    mov dword [cdJ], 0
.gc:
    mov ecx, [cdI]
    mov eax, [cdJ]
    cmp eax, 9
    jge .gn
    xor edx, edx
    mov esi, 3
    div esi                         ; eax = row 0..2, edx = column 0..2
    movzx ebx, byte [circGY+ecx]
    lea ebx, [ebx+eax-1]
    movzx eax, byte [circGX+ecx]
    lea eax, [eax+edx-1]
    call circ_cell
    inc dword [cdJ]
    jmp .gc
.gn:
    inc dword [cdI]
    jmp .g
.w0:
    mov dword [cdI], 0
.w: mov ecx, [cdI]
    cmp ecx, [circNW]
    jge .d
    mov esi, [circWD]
    lea edi, [ecx+ecx*2]
    movzx eax, byte [esi+edi]
    movzx ebx, byte [esi+edi+1]
    call circ_cell
    inc dword [cdI]
    jmp .w
.d: popad
    ret

; ---------------------------------------------------------------------
; the plaque
; ---------------------------------------------------------------------
circ_plaque:
    pushad
    call msg_begin
    cmp dword [circHidden], -1
    jne .hid
    mov esi, msgCirc
    mov ecx, msgCirclen
    call msg_text
    jmp .e
.hid:
    mov esi, msgCircHid
    mov ecx, msgCircHidlen
    call msg_text
    mov eax, [circHidden]           ; the riddle of the hidden gate, without its name
    movzx eax, byte [circGT+eax]
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN
.trim:
    cmp byte [esi+ecx-1], ' '
    jne .skip
    dec ecx
    jmp .trim
.skip:
    cmp byte [esi], '-'             ; skip "XOR - "
    je .past
    inc esi
    dec ecx
    jmp .skip
.past:
    add esi, 2
    sub ecx, 2
    call msg_text
.e: call msg_end
    popad
    ret
