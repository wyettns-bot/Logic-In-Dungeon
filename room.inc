; =====================================================================
; room.inc  -  the 1x3 door, the plaque, and the logic gate puzzles
;
; Floor 1 is the tutorial room: the door is open.
; From floor 2 on, the game picks a logic gate and puts PAIRS of torches in the
; room. Each pair is one input to the gate: the left torch is A, the right one is B.
; [0] = unlit (0), [1] = lit (1). Click a torch next to you to flip it.
;   floors 2-3: light ANY one pair the gate accepts
;   floor 4+:   one pair for EVERY input the gate accepts, each pair different
; The plaque (R) beside the door says which gate it is, in a riddle.
; After floor 15 the rooms hold whole circuits instead: see circuit.inc.
; Uses from game.asm: put_cell rand_mod msg msg_begin msg_text msg_end
;   floorCount playerX playerY  and from game_assets.asm: doorasset opendoorasset
;   door_h puzzlenode puzzlenodeactive puzzlenode_w panelasset
; =====================================================================

section .data

DOOR_X   equ 50                 ; the door is 1 wide and door_h (3) tall, on the right wall
DOOR_Y   equ 5                  ; top cell of the door (rows 5..7, centred on the entrance row 6)
PLAQUE_X equ 50
PLAQUE_Y equ 9                  ; just below the door
NODE_X   equ 36                 ; left edge of every torch pair: "[A][B]" is 6 cells wide
NODE_Y0  equ 2                  ; row of the first pair; each next pair is 3 rows lower
NODE_DY  equ 3
MAX_PAIRS equ 3

GATE_COUNT equ 6
; which inputs each gate accepts, as a 4-bit set. Bit number = A*2 + B:
;   bit0 = 00, bit1 = 01, bit2 = 10, bit3 = 11
;              AND     OR      XOR     NAND    NOR     XNOR
gateTruth  db 0b1000, 0b1110, 0b0110, 0b0111, 0b0001, 0b1001

; the plaque riddles, one per gate, all padded to the same length (RIDDLE_LEN)
RIDDLE_LEN equ 44
%macro riddle 1
    %strlen _rl %1
    db %1
    times RIDDLE_LEN - _rl db ' '
%endmacro
riddles:
    riddle "AND - both must burn, or none may pass."
    riddle "OR - one, the other, or both. Never none."
    riddle "XOR - one and none, but not all."
    riddle "NAND - anything at all, but never both."
    riddle "NOR - only darkness opens the way."
    riddle "XNOR - twins: alike in light or in dark."

needAny  db " (light one pair)"
needAnylen equ $- needAny
needAll  db " (every true pair, each different)"
needAlllen equ $- needAll
noPlaque db "The plaque is blank. The door is already open."
noPlaquelen equ $- noPlaque
msgOpen  db "Click. The door grinds open."
msgOpenlen equ $- msgOpen
msgSealed db "The door is sealed. Read the plaque (R)."
msgSealedlen equ $- msgSealed
msgReach db "Too far - walk next to the torch first."
msgReachlen equ $- msgReach
msgInFight db "You can't leave mid-fight."
msgInFightlen equ $- msgInFight
msgBossSeal db "The door won't budge while the guardian lives."
msgBossSeallen equ $- msgBossSeal
msgWarden db "A Warden blocks the way! Light the torch pair to match the gate on his shield."
msgWardenlen equ $- msgWarden
msgKing db "The Forgotten King watches from his throne. Power the throne's wire to wound him."
msgKinglen equ $- msgKing
msgFalls db "The guardian falls. The door grinds open."
msgFallslen equ $- msgFalls
msgShade db "The Dark Shade rises. Darkness hides it - light burns it."
msgShadelen equ $- msgShade

section .bss
doorOpen   resd 1
bossRoom   resd 1               ; 0 normal, 1 Warden, 2 the Forgotten King, 3 his Dark Shade, 4 Ymir, 5 Logic Keeper, 6 Altair and Smo
puzzleOn   resd 1               ; 0 in the tutorial room
puzzleGate resd 1               ; 0..5  (AND OR XOR NAND NOR XNOR)
puzzleAll  resd 1               ; 1 = every accepted input must be shown
puzzlePairs resd 1
nodeBit    resb 8               ; 0 / 1 for each torch
roomTmp    resd 1
roomTry    resd 1
seenSet    resd 1
touched    resd 1               ; 1 = touch_node flipped the torch, 0 = it was too far
pairX      resd 1               ; where the torch pairs stand (the Warden and the Unbound King move them)
pairY      resd 1

section .text

; ---------------------------------------------------------------------
; set up the room you just entered (call AFTER floorCount is set)
; ---------------------------------------------------------------------
setup_room:
    mov dword [puzzleOn], 0
    mov dword [doorOpen], 1
    mov dword [bossRoom], 0
    mov dword [pairX], NODE_X
    mov dword [pairY], NODE_Y0
    cmp dword [floorCount], 1
    jle .r                          ; tutorial room: no puzzle, door open
    mov eax, [floorCount]           ; boss rooms: the door stays shut until the boss is dead
    cmp eax, FINAL_FLOOR
    je .king
    cmp eax, SHADE_FLOOR
    je .shade
    cmp eax, YMIR_FLOOR
    je .ymir
    cmp eax, DUO_FLOOR
    je .duo
    cmp eax, KEEPER_FLOOR
    jne .notkeeper
    mov dword [bossRoom], BR_KEEPER ; the Logic Keeper and its Wardens: a torch pair beside each (bosses2.inc)
    jmp keeper2_setup
.notkeeper:
    cmp eax, BISHOP_FLOOR
    jne .notbish
    mov dword [bossRoom], BR_BISHOP ; the Four Bishops: no torches, the gates are on the square
    mov dword [doorOpen], 0
    ret
.notbish:
    xor ecx, ecx
.mb:
    cmp ecx, MINIBOSS_FLOORS
    jge .puzzle
    cmp al, [minibossFloors+ecx]
    je .mini
    inc ecx
    jmp .mb
.king:
    mov dword [bossRoom], 2
    mov dword [doorOpen], 0
    jmp king_room_setup             ; the throne circuit (bosses.inc)
.mini:
    mov dword [bossRoom], 1
    mov dword [doorOpen], 0
    jmp warden_room_setup           ; the torch pair behind the Warden (bosses.inc)
.shade:
    mov dword [bossRoom], 3
    mov dword [doorOpen], 0
    jmp shade_room_setup            ; four torches, two gates, the lantern (bosses.inc)
.ymir:
    mov dword [bossRoom], BR_YMIR
    mov dword [doorOpen], 0
    jmp ymir_room_setup             ; four torches, two gates, two power torches (bosses.inc)
.duo:
    mov dword [bossRoom], BR_DUO
    mov dword [doorOpen], 0
    ret
.puzzle:
    cmp dword [floorCount], HALF_FLOOR
    jle .pairs
    call setup_circuit              ; the second half: whole circuits
    ret
.pairs:
    mov dword [puzzleOn], 1
    mov dword [doorOpen], 0
    mov eax, GATE_COUNT
    call rand_mod
    mov [puzzleGate], eax
    mov dword [puzzleAll], 0
    mov dword [puzzlePairs], 1
    cmp dword [floorCount], 3
    jle .roll                       ; floors 2-3: one pair is enough
    mov dword [puzzleAll], 1        ; floor 4+: one pair per accepted input
    call truth_set
    xor ecx, ecx                    ; count the bits in the truth set
.cnt:
    test eax, eax
    jz .cdone
    mov edx, eax
    and edx, 1
    add ecx, edx
    shr eax, 1
    jmp .cnt
.cdone:
    mov [puzzlePairs], ecx
.roll:                              ; random torches, but never already solved
    mov dword [roomTry], 60
.again:
    xor ecx, ecx
.bits:
    mov eax, [puzzlePairs]
    shl eax, 1
    cmp ecx, eax
    jge .check
    push ecx
    mov eax, 2
    call rand_mod
    pop ecx
    mov [nodeBit+ecx], al
    inc ecx
    jmp .bits
.check:
    call puzzle_solved
    test eax, eax
    jz .r
    dec dword [roomTry]
    jnz .again
.r: ret

truth_set:                          ; -> eax = the accepted-inputs bit set of this room's gate
    mov eax, [puzzleGate]
    movzx eax, byte [gateTruth+eax]
    ret

puzzle_solved:                      ; -> eax = 1 if the torches satisfy the gate (or power the circuit's door)
    cmp dword [puzzleOn], 2
    jne .pairs
    call circ_eval
    mov eax, [circOut]
    ret
.pairs:
    call truth_set
    mov [roomTmp], eax
    mov dword [seenSet], 0
    xor ecx, ecx                    ; pair number
.l: cmp ecx, [puzzlePairs]
    jge .yes
    movzx eax, byte [nodeBit+ecx*2]     ; A
    shl eax, 1
    movzx edx, byte [nodeBit+ecx*2+1]   ; B
    or eax, edx                     ; eax = A*2 + B, the input this pair shows
    mov edx, [roomTmp]
    bt edx, eax
    jnc .no                         ; the gate rejects this input
    cmp dword [puzzleAll], 0
    je .next
    mov edx, [seenSet]
    bt edx, eax
    jc .no                          ; the same input twice: not "each different"
    bts edx, eax
    mov [seenSet], edx
.next:
    inc ecx
    jmp .l
.yes:
    mov eax, 1
    ret
.no:
    xor eax, eax
    ret

; ---------------------------------------------------------------------
; what is where
; ---------------------------------------------------------------------
is_door:                            ; eax=x, ebx=y -> CF=1 on a door cell
    cmp eax, DOOR_X
    jne .no
    cmp ebx, DOOR_Y
    jl .no
    cmp ebx, DOOR_Y + door_h - 1
    jg .no
    stc
    ret
.no:
    clc
    ret

torch_count:                        ; -> eax = how many torches this room has   (keeps the rest)
    cmp dword [puzzleOn], 2
    jne .p
    mov eax, [circNT]
    ret
.p: mov eax, [puzzlePairs]
    shl eax, 1
    ret

torch_pos:                          ; eax = torch number -> eax = its left column, edx = its row   (keeps the rest)
    cmp dword [puzzleOn], 2
    jne .p
    movzx edx, byte [circTY+eax]
    movzx eax, byte [circTX+eax]
    ret
.p: call keeper_like
    jne .p2
    push ecx                        ; the Keeper's room: each pair beside its own Warden
    mov ecx, eax
    shr ecx, 1
    mov edx, [kPY+ecx*4]
    and eax, 1
    imul eax, eax, puzzlenode_w
    add eax, [kPX+ecx*4]
    pop ecx
    ret
.p2:mov edx, eax                    ; pairs: pair = n/2 (its row), side = n%2 (A left, B right)
    shr edx, 1
    imul edx, edx, NODE_DY
    add edx, [pairY]
    and eax, 1
    imul eax, eax, puzzlenode_w
    add eax, [pairX]
    ret

node_at:                            ; eax=x, ebx=y -> eax = torch number or -1, edx = column inside its "[0]"   (keeps ebx)
    cmp dword [puzzleOn], 0
    je .none
    push ecx
    push esi
    push edi
    mov esi, eax
    mov edi, ebx
    call torch_count
    mov ecx, eax
.l: dec ecx
    js .nope
    mov eax, ecx
    call torch_pos
    cmp edx, edi
    jne .l
    mov edx, esi
    sub edx, eax
    js .l
    cmp edx, puzzlenode_w
    jge .l
    mov eax, ecx
    pop edi
    pop esi
    pop ecx
    ret
.nope:
    pop edi
    pop esi
    pop ecx
.none:
    mov eax, -1
    ret

is_plaque:                          ; eax=x, ebx=y -> CF=1 on the plaque
    cmp dword [puzzleOn], 0
    je .no
    cmp eax, PLAQUE_X
    jne .no
    cmp ebx, PLAQUE_Y
    jne .no
    stc
    ret
.no:
    clc
    ret

obstacle_at:                        ; eax=x, ebx=y -> CF=1 if nobody can stand there (door, plaque, torch)
    push eax
    push edx
    call is_door
    jc .yes
    call is_plaque
    jc .yes
    push eax
    call node_at
    cmp eax, -1
    pop eax
    jne .yes
    call boss_obstacle              ; Ymir's power torches
    jc .yes
    cmp dword [puzzleOn], 2
    jne .free
    call circ_gate_obstacle         ; circuit gates (wires can be walked over)
    jc .yes
.free:
    pop edx
    pop eax
    clc
    ret
.yes:
    pop edx
    pop eax
    stc
    ret

room_glyph:                         ; eax=x, ebx=y -> dl = the room object there, or '.'   (keeps eax, ebx, ecx)
    push eax
    push ecx
    push edx
    mov dl, '.'
    call is_door
    jnc .p
    mov ecx, ebx
    sub ecx, DOOR_Y
    mov dl, [doorasset+ecx]         ; '<' closed
    cmp dword [doorOpen], 0
    je .out
    mov dl, [opendoorasset+ecx]     ; '>' open
    jmp .out
.p: call is_plaque
    jnc .n
    mov dl, [panelasset]
    jmp .out
.n: call node_at
    cmp eax, -1
    je .circ
    mov ecx, edx                    ; column inside the sprite
    cmp byte [nodeBit+eax], 0
    jne .lit
    mov dl, [puzzlenode+ecx]        ; "[0]"
    jmp .out
.lit:
    mov dl, [puzzlenodeactive+ecx]  ; "[1]"
    jmp .out
.circ:
    mov eax, [esp+8]                ; x again
    call boss_glyph                 ; Ymir's power torches -> al, or 0
    test al, al
    jz .c2
    mov dl, al
    jmp .out
.c2:
    cmp dword [puzzleOn], 2
    jne .floor
    mov eax, [esp+8]                ; x again (node_at changed eax)
    call circ_glyph
    test al, al
    jz .floor
    mov dl, al
    jmp .out
.floor:
    mov dl, '.'
.out:
    mov al, dl                      ; hand dl back past the pops
    pop edx
    mov dl, al
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------
; drawing
; ---------------------------------------------------------------------
draw_door:
    pushad
    xor ebx, ebx
.l: cmp ebx, door_h
    jge .d
    push ebx
    add ebx, DOOR_Y
    mov eax, DOOR_X
    call room_glyph
    call put_cell
    pop ebx
    inc ebx
    jmp .l
.d: popad
    ret

draw_room_objects:                  ; door, plaque and every torch
    pushad
    call boss_draw_objects          ; Ymir's power torches
    call draw_door
    cmp dword [puzzleOn], 0
    je .d
    mov eax, PLAQUE_X
    mov ebx, PLAQUE_Y
    call room_glyph
    call put_cell
    cmp dword [puzzleOn], 2
    jne .pairs
    call circ_draw
    jmp .d
.pairs:
    xor ecx, ecx                    ; every cell of every torch (wherever torch_pos puts it)
.tor:
    call torch_count
    cmp ecx, eax
    jge .d
    mov eax, ecx
    call torch_pos                  ; eax = column, edx = row
    mov ebx, edx
    xor esi, esi
.col:
    cmp esi, puzzlenode_w
    jge .np
    push eax
    add eax, esi
    call room_glyph
    call put_cell
    pop eax
    inc esi
    jmp .col
.np:
    inc ecx
    jmp .tor
.d: popad
    ret

; ---------------------------------------------------------------------
; the player's hands
; ---------------------------------------------------------------------
read_plaque:
    pushad
    cmp dword [puzzleOn], 0
    jne .say
    msg noPlaque
    jmp .d
.say:
    cmp dword [bossRoom], 0
    je .say2
    call boss_plaque                ; CF=1: the boss room said it
    jc .d
.say2:
    cmp dword [puzzleOn], 2
    jne .gate
    call circ_plaque
    jmp .d
.gate:
    call msg_begin
    mov eax, [puzzleGate]
    imul esi, eax, RIDDLE_LEN
    add esi, riddles
    mov ecx, RIDDLE_LEN             ; trim the padding
.t: cmp byte [esi+ecx-1], ' '
    jne .p
    dec ecx
    jmp .t
.p: call msg_text
    cmp dword [puzzleAll], 0
    jne .all
    mov esi, needAny
    mov ecx, needAnylen
    call msg_text
    jmp .e
.all:
    mov esi, needAll
    mov ecx, needAlllen
    call msg_text
.e: call msg_end
.d: popad
    ret

touch_node:                         ; eax = torch number: flip it if you are next to it ([touched] = 1 if it flipped)
    pushad
    mov dword [touched], 0
    mov [roomTmp], eax
    call torch_pos                  ; eax = its left column, edx = its row
    mov ebx, edx
    mov edi, 1                      ; how far you can reach: 1, or 2 with a Gatekey
    push eax
    mov eax, SP_REACH
    call has_special
    pop eax
    jnc .rr
    mov edi, 2
.rr:
    mov ecx, [playerY]              ; you must be within reach rows ...
    sub ecx, ebx
    jns .y
    neg ecx
.y: cmp ecx, edi
    jg .far
    mov ecx, [playerX]              ; ... and within reach columns of its 3 cells
    sub ecx, eax
    neg edi
    cmp ecx, edi
    jl .far
    neg edi
    add edi, puzzlenode_w - 1
    cmp ecx, edi
    jg .far
    mov ecx, [roomTmp]
    xor byte [nodeBit+ecx], 1
    mov dword [touched], 1
    cmp dword [puzzleOn], 2
    jne .redraw
    call circ_eval                  ; the new signal runs through the wires
.redraw:
    call draw_room_objects
    cmp dword [bossRoom], 0
    je .door
    call boss_torch                 ; boss rooms: the torches fight the boss, the door waits for its death
    jmp .d
.door:
    cmp dword [doorOpen], 0
    jne .d                          ; already open: it stays open
    call puzzle_solved
    test eax, eax
    jz .d
    mov dword [doorOpen], 1
    call draw_door
    msg msgOpen
    call xp_puzzle              ; experience for solving it (progress.inc)
    jmp .d
.far:
.d: popad
    ret

; ---------------------------------------------------------------------
; boss rooms
; ---------------------------------------------------------------------
room_cleared:                       ; called when the last enemy dies
    cmp dword [bossRoom], 0
    je .r
    cmp dword [bossRoom], 2
    je .won
    cmp dword [doorOpen], 0
    jne .r
    mov dword [doorOpen], 1
    call draw_door
    msg msgFalls
.r: ret
.won:
    mov dword [wonGame], 1          ; the main loop shows the victory screen
    ret

say_sealed:                         ; walking into a closed door
    cmp dword [bossRoom], 0
    jne .boss
    msg msgSealed
    ret
.boss:
    msg msgBossSeal
    ret

announce_room:                      ; on entering a room
    cmp dword [bossRoom], 0
    je .nb
    call start_combat               ; boss rooms start the fight at once
.nb:
    cmp dword [bossRoom], 1
    je .w
    cmp dword [bossRoom], 2
    je .k
    cmp dword [bossRoom], 3
    je .s
    jmp announce_boss               ; the bosses from bosses.inc
.s: msg msgShade
    ret
.w: msg msgWarden
    ret
.k: msg msgKing
    ret

%include "circuit.inc"
