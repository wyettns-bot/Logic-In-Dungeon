; =====================================================================
; demo.inc  -  demo mode: one room of each kind, for showing the game
;
; The window's Demo button sends "d" + Enter on the title screen (CC.asm sets demoFlag).
; After you pick a class, the game shows a room list instead of floor 1; the window
; draws it as buttons, which send the room's letter (a-m). The terminal shows the same list.
;
; In demo mode:
;   - every room starts a fresh hero of your class, levelled up to about where a player
;     would be on that floor: its stat points go to the class's main stat, and it carries
;     the legendaries of the bosses before that floor (worn - except the Truth Amulet,
;     which would give away the hidden gates; it waits in the bag);
;   - you can't die: at 0 HP your HP fills up again;
;   - leaving through the door, beating the last boss, or pressing # (the window's
;     "Room list" button) goes back to the list.
; =====================================================================

section .data
demoList db 27, "[2J", 27, "[H", 10
         db "  DEMO MODE: choose a room", 10, 10
         db "  Puzzle rooms", 10
         db "   a  One torch pair (floor 2)", 10
         db "   b  Every accepted input (floor 5)", 10
         db "   c  Two gates in a chain (floor 16)", 10
         db "   d  A circuit with NOT (floor 22)", 10
         db "   e  A hidden gate (floor 25)", 10, 10
         db "  Bosses", 10
         db "   f  Warden (floor 4)", 10
         db "   g  The Four Bishops (floor 12)", 10
         db "   h  Dark Shade (floor 15)", 10
         db "   i  Grand Wizard Ymir (floor 17)", 10
         db "   j  Logic Keeper (floor 21)", 10
         db "   k  Altair and Smo (floor 26)", 10
         db "   l  The Forgotten King (floor 30)", 10
         db "   m  The Unbound (floor 30)", 10, 10
         db "  q  Quit", 10
demoListlen equ $- demoList

DEMO_N       equ 13
DEMO_UNBOUND equ 12                     ; entry m: the King rises at once
;                a   b   c   d     e     f   g   h   i   j   k   l   m
demoFloor db     2,  5, 16, 22,   25,    4, 12, 15, 17, 21, 26, 30, 30
demoLay   db    -1, -1, -1, CT_C, CT_B, -1, -1, -1, -1, -1, -1, -1, -1   ; circuit layout (-1 = the floor's own choice)
demoLevel db     1,  3, 11, 15,   16,    3,  8, 10, 12, 14, 17, 18, 18   ; about where a player is by then
demoMain  db     0, 1, 3                ; the stat points go to STR (Fighter), DEX (Rogue), INT (Wizard)
demoLootFloor db 4, 8, 15, 17, 21, 26, 26   ; the floor of each bossLoot row (items_loot.inc)
DEMO_LOOT equ 7
demoLayout dd -1                        ; setup_circuit uses this layout when it is 0 or more

msgDemoSaved db "Demo mode: you can't die here. Your HP is full again."
msgDemoSavedlen equ $- msgDemoSaved

section .bss
demoMode  resd 1                        ; 1 = demo mode
demoPick  resd 1                        ; the room chosen (0..12)
demoI     resd 1
demoBase  resd 4                        ; STR DEX CON INT as the hero was made (before any level)
demoSaved resd 1

section .text

demo_pick:                              ; show the room list, wait for a letter, then enter that room
    call disarm
    print_string demoList, demoListlen
.wait:
    mov eax, 3
    xor ebx, ebx
    mov ecx, inbuf
    mov edx, 255
    int 0x80
    cmp eax, 0
    jle .wait                           ; (read gives up every 0.1 s: just ask again)
    mov al, [inbuf]
    cmp al, 27
    je .wait                            ; a mouse report from the terminal: not a choice
    or al, 0x20                         ; lower case
    cmp al, 'q'
    je quit
    sub al, 'a'
    cmp al, DEMO_N
    jae .wait
    movzx eax, al
    mov [demoPick], eax
    mov dword [wonGame], 0
    movzx ebx, byte [demoFloor+eax]
    mov [floorCount], ebx
    movsx ebx, byte [demoLay+eax]
    mov [demoLayout], ebx
    call demo_hero
    mov dword [trickCount], 0
    call enter_floor                    ; the room, its enemies, the boss's first words (game.asm)
    mov dword [demoLayout], -1
    cmp dword [demoPick], DEMO_UNBOUND
    jne .r
    call king_rise                      ; straight to the Unbound (bosses.inc)
.r: ret

demo_hero:                              ; a fresh hero, levelled and geared for floor [floorCount], full HP and mana
    cld
    cmp dword [demoSaved], 0
    jne .fresh
    mov esi, baseStat                   ; the first room: remember the hero as it was made
    mov edi, demoBase
    mov ecx, 4
    rep movsd
    mov dword [demoSaved], 1
.fresh:
    mov esi, demoBase                   ; back to level 1 with the starting gear
    mov edi, baseStat
    mov ecx, 4
    rep movsd
    mov dword [playerLevel], 1
    mov dword [playerXP], 0
    mov dword [statPoints], 0
    mov dword [hpGained], 0
    call apply_perks
    call init_features                  ; the bag, the starting weapon and armor (features.inc)
    mov eax, [demoPick]
    movzx eax, byte [demoLevel+eax]
    cmp eax, 1
    jle .stats
    mov ebx, [xpTable+eax*4-8]          ; the XP that level needs
    mov [playerXP], ebx
.lv:
    cmp [playerLevel], eax
    jge .lvd
    push eax
    call level_up                       ; HP, perks, a stat point on even levels (progress.inc)
    pop eax
    jmp .lv
.lvd:
    call draw_level
.stats:                                 ; spend the stat points: the main stat, then CON, up to 24
    cmp dword [statPoints], 0
    je .gear
    call class_index
    movzx eax, byte [demoMain+eax]
    cmp dword [baseStat+eax*4], 24
    jl .up
    mov eax, 2                          ; CON
    cmp dword [baseStat+eax*4], 24
    jge .gear                           ; both at their peak: keep the points
.up:
    inc dword [baseStat+eax*4]
    dec dword [statPoints]
    jmp .stats
.gear:
    call recalc_gear
    mov dword [demoI], 0
.gl:
    mov ecx, [demoI]
    cmp ecx, DEMO_LOOT
    jge .full
    movzx eax, byte [demoLootFloor+ecx]
    cmp eax, [floorCount]
    jge .gn                             ; that boss comes later
    call class_index
    imul ecx, ecx, 3
    add ecx, eax
    mov esi, [bossLoot+ecx*4]           ; the legendary that boss drops for your class
    call add_item
    jc .gn                              ; the bag is full
    cmp esi, cat_truthamulet
    je .gn                              ; it would show the hidden gates: left in the bag
    call equip_item                     ; put it on (a later one replaces an earlier one)
    mov dword [refuseMsg], 0
.gn:
    inc dword [demoI]
    jmp .gl
.full:
    mov eax, [playerMaxHP]
    mov [playerHP], eax
    mov eax, [playerMaxMana]
    mov [playerMana], eax
    mov dword [hasteTimer], 0
    mov dword [holyBurn], 0
    mov dword [statPick], 0
    mov dword [lvLen], 0                ; no level-up line: the room's own message comes first
    mov dword [phase], PHASE_PLAYER
    ret

demo_save:                              ; demo mode, HP hit 0: fill it up again
    push eax
    mov eax, [playerMaxHP]
    mov [playerHP], eax
    call draw_hp
    msg msgDemoSaved
    pop eax
    ret
