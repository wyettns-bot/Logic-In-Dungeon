section .data

    ; =========================
    ; Screen and basic text
    ; =========================
    clear_screen db 0x1B, "[2J", 0x1B, "[H"
    clear_screenlen equ $ - clear_screen

    newline db 10

    title db 10, "============================================================================================================="
          db 10, " _  __              _          __   _   _          ___                 _   _              _  _____           "
          db 10, "| |/ /_ _ _  _ _ __| |_   ___ / _| | |_| |_  ___  | __|__ _ _ __ _ ___| |_| |_ ___ _ _   | |/ /_ _|_ _  __ _ "
          db 10, "| ' <| '_| || | '_ \  _| / _ \  _| |  _| ' \/ -_) | _/ _ \ '_/ _` / _ \  _|  _/ -_) ' \  | ' < | || ' \/ _` |"
          db 10, "|_|\_\_|  \_, | .__/\__| \___/_|    \__|_||_\___| |_|\___/_| \__, \___/\__|\__\___|_||_| |_|\_\___|_||_\__, |"
          db 10, "          |__/|_|                                            |___/                                     |___/ "
          db 10, "============================================================================================================="
          db 10, "                                         Press Enter to Continue "
          db 10, 10
    titlelen equ $ - title


    ; =========================
    ; Class selection
    ; =========================

    classSelection db 10, "====================================================="
                   db 10, "                    Select a class"
                   db 10, "====================================================="
                   db 10, "1. Fighter"
                   db 10, "2. Rogue"
                   db 10, "3. Wizard"
                   db 10, "Select a class: "

    classSelectionlen equ $ - classSelection


    ; =========================
    ; Character sheet
    ; =========================

    characterSheet db 10, "====================================================="
                   db 10, "                   Character Sheet"
                   db 10, "=====================================================",10

    characterSheetlen equ $ - characterSheet

    str_text db 10, "STRENGTH: "
    str_textlen equ $ - str_text

    dex_text db 10, "DEXTERITY: "
    dex_textlen equ $ - dex_text

    con_text db 10, "CONSTITUTION: "
    con_textlen equ $ - con_text

    int_text db 10, "INTELLIGENCE: "
    int_textlen equ $ - int_text


    ; =========================
    ; Per-class inventory / proficiencies
    ; =========================

    fighterInventoryProf db 10, "====================================================="
                         db 10, "         Inventory: Longsword, Breastplate"
                         db 10, "====================================================="
                         db 10, "   Proficiencies: Heavy Armor, Martial Weapons,"
                         db 10, "  Simple Weapons, Medium Armor, Light Armor, Shields"
                         db 10, "====================================================="
                         db 10, "      Special Trait: Can attack twice per Turn"
                         db 10, "====================================================="
    fighterInventoryProflen equ $ - fighterInventoryProf

    rogueInventoryProf   db 10, "====================================================="
                         db 10, "      Inventory: Shortsword, Leather Armor "
                         db 10, "====================================================="
                         db 10, " Proficiencies: Light Armor, Stealth, Simple Weapons,"
                         db 10, "         Light Crossbow, Short Swords, Rapiers"
                         db 10, "====================================================="
                         db 10, " Special Trait: Can enter stealth and stealth attack"
                         db 10, "====================================================="
    rogueInventoryProflen equ $ - rogueInventoryProf

    wizardInventoryProf  db 10, "====================================================="
                         db 10, "        Inventory: Quarterstaff, Simple Robe"
                         db 10, "====================================================="
                         db 10, "   Proficiencies: Arcana, Daggers, Quarter Staffs"
                         db 10, "====================================================="
                         db 10, "           Special Trait: Can cast spells"
                         db 10, "====================================================="
    wizardInventoryProflen equ $ - wizardInventoryProf
    
    ; =========================
    ; Class names
    ; =========================
    nameFighter db "  FIGHTER"
    nameFighterlen equ $ - nameFighter

    nameRogue db "  ROGUE"
    nameRoguelen equ $ - nameRogue

    nameWizard db "  WIZARD"
    nameWizardlen equ $ - nameWizard


    ; =========================
    ; Continue prompt
    ; =========================

    continueprompt db 10, "Would you like to continue? (y/n): "
    continuepromptlen equ $ - continueprompt


    ; =========================
    ; Extra stat allocation
    ; =========================

    extraStatstitle  db 10, "====================================================="
                     db 10, "                    Extra Stats"
                     db 10, "====================================================="

    extraStatstitlelen equ $ - extraStatstitle


    askExtraStats db 10, "You have 3 extra stat points."
                  db 10, "Spend them however you like."
                  db 10

    askExtraStatslen equ $ - askExtraStats


    pointsRemainingText db 10, "Extra points remaining: "
    pointsRemainingTextlen equ $ - pointsRemainingText


    extraStatsMenuText db 10, "Choose a stat to increase:"
                       db 10, "1. Strength"
                       db 10, "2. Dexterity"
                       db 10, "3. Constitution"
                       db 10, "4. Intelligence"
                       db 10, "5. Skip One"
                       db 10, "6. Exit"
                       db 10, "Selection: "

    extraStatsMenuTextLen equ $ - extraStatsMenuText


    invalidChoiceText db 10, "Invalid choice. Try again.", 10
    invalidChoiceTextLen equ $ - invalidChoiceText


    finishedText db 10, "Character creation complete!"
                 db 10, "Your character is ready."
                 db 10

    finishedTextlen equ $ - finishedText


section .bss

    ; =========================
    ; User input
    ; =========================

    class resb 2
    continue_input resb 2
    statChoice resb 2


    ; =========================
    ; Character attributes
    ; =========================

    strength resd 1
    dex resd 1
    con resd 1
    intel resd 1
    inventoryProf resd 1
    inventoryProflen resd 1
    classLabel resd 1
    classLabellen resd 1


    ; =========================
    ; Extra stat points
    ; =========================

    extraPoints resd 1


    ; =========================
    ; Integer conversion buffer
    ; =========================

    number_buffer resb 12


section .text

    global character_creation
    
    global strength, dex, con, intel
    global class, classLabel,classLabellen
    global inventoryProf, inventoryProflen
    global print_sheet, print_integer, print_clear, print_newline


; =========================================================
; PROGRAM ENTRY
; =========================================================

character_creation:



    mov eax, 4
    mov ebx, 1
    mov ecx, title
    mov edx, titlelen
    int 0x80
    mov eax, 3
    mov ebx, 0
    mov ecx, continue_input
    mov edx, 2
    int 0x80


; =========================================================
; CLASS SELECTION
; =========================================================

selectClass:

    call print_clear

    mov eax, 4
    mov ebx, 1
    mov ecx, classSelection
    mov edx, classSelectionlen
    int 0x80


    ; Read class selection

    mov eax, 3
    mov ebx, 0
    mov ecx, class
    mov edx, 2
    int 0x80


    ; Determine selected class

    mov al, [class]

    cmp al, '1'
    je fighter

    cmp al, '2'
    je rogue

    cmp al, '3'
    je wizard

    ; Invalid input

    jmp selectClass


; =========================================================
; FIGHTER CLASS
; =========================================================

fighter:

    mov dword [strength], 16
    mov dword [dex], 13
    mov dword [con], 16
    mov dword [intel], 10

    mov dword [inventoryProf], fighterInventoryProf
    mov dword [inventoryProflen], fighterInventoryProflen
    mov dword [classLabel], nameFighter
    mov dword [classLabellen], nameFighterlen

    jmp showCharacter


; =========================================================
; ROGUE CLASS
; =========================================================

rogue:

    mov dword [strength], 12
    mov dword [dex], 16
    mov dword [con], 13
    mov dword [intel], 12

    mov dword [inventoryProf], rogueInventoryProf
    mov dword [inventoryProflen], rogueInventoryProflen
    mov dword [classLabel], nameRogue
    mov dword [classLabellen], nameRoguelen

    jmp showCharacter


; =========================================================
; WIZARD CLASS
; =========================================================

wizard:

    mov dword [strength], 10
    mov dword [dex], 14
    mov dword [con], 10
    mov dword [intel], 16

    mov dword [inventoryProf], wizardInventoryProf
    mov dword [inventoryProflen], wizardInventoryProflen
    mov dword [classLabel], nameWizard
    mov dword [classLabellen], nameWizardlen

    jmp showCharacter



; =========================================================
; INITIAL CHARACTER SHEET
; =========================================================

showCharacter:

    call print_clear

    call print_sheet


    ; Ask whether the player wants to continue

    mov eax, 4
    mov ebx, 1
    mov ecx, continueprompt
    mov edx, continuepromptlen
    int 0x80


    ; Read answer

    mov eax, 3
    mov ebx, 0
    mov ecx, continue_input
    mov edx, 2
    int 0x80


    ; Check answer

    mov al, [continue_input]

    cmp al, 'n'
    je selectClass

    cmp al, 'N'
    je selectClass

    cmp al, 'y'
    je extraStatsMenu

    cmp al, 'Y'
    je extraStatsMenu


    ; Invalid answer: ask again

    jmp showCharacter


; =========================================================
; EXTRA STAT ALLOCATION MENU
; =========================================================

extraStatsMenu:

    ; Give the player exactly 3 points

    mov dword [extraPoints], 3


    ; Display introductory message

    call print_clear

    mov eax, 4
    mov ebx, 1
    mov ecx, extraStatstitle
    mov edx, extraStatstitlelen
    int 0x80


    mov eax, 4
    mov ebx, 1
    mov ecx, askExtraStats
    mov edx, askExtraStatslen
    int 0x80


; =========================================================
; ALLOCATION LOOP
; =========================================================

allocateStats:

    ; Clear the screen

    call print_clear


    ; Display extra stats title

    mov eax, 4
    mov ebx, 1
    mov ecx, extraStatstitle
    mov edx, extraStatstitlelen
    int 0x80


    ; Display current character attributes

    call print_sheet


    ; Display remaining points

    mov eax, 4
    mov ebx, 1
    mov ecx, pointsRemainingText
    mov edx, pointsRemainingTextlen
    int 0x80


    mov eax, [extraPoints]
    call print_integer

    call print_newline


    ; Display allocation choices

    mov eax, 4
    mov ebx, 1
    mov ecx, extraStatsMenuText
    mov edx, extraStatsMenuTextLen
    int 0x80


    ; Read player selection

    mov eax, 3
    mov ebx, 0
    mov ecx, statChoice
    mov edx, 2
    int 0x80


    ; Determine which stat to increase

    mov al, [statChoice]

    cmp al, '1'
    je increaseStrength

    cmp al, '2'
    je increaseDex

    cmp al, '3'
    je increaseCon

    cmp al, '4'
    je increaseIntel

    cmp al, '5'
    je increaseSkip

    cmp al, '6'
    je increaseExit


    ; Invalid selection

    mov eax, 4
    mov ebx, 1
    mov ecx, invalidChoiceText
    mov edx, invalidChoiceTextLen
    int 0x80

    jmp allocateStats


; =========================================================
; INCREASE STRENGTH
; =========================================================

increaseStrength:

    inc dword [strength]

    jmp spendPoint


; =========================================================
; INCREASE DEXTERITY
; =========================================================

increaseDex:

    inc dword [dex]

    jmp spendPoint


; =========================================================
; INCREASE CONSTITUTION
; =========================================================

increaseCon:

    inc dword [con]

    jmp spendPoint


; =========================================================
; INCREASE INTELLIGENCE
; =========================================================

increaseIntel:

    inc dword [intel]

    jmp spendPoint

; =========================================================
; SINGLE SKIP
; =========================================================

increaseSkip:

    ; Subtract one from the remaining points

    dec dword [extraPoints]


    ; Check whether points remain

    cmp dword [extraPoints], 0

    jne allocateStats


    ; All 3 points have been spent

    jmp finishCharacter

; =========================================================
; SKIP ALL
; =========================================================

increaseExit:

    ; Subtract one from the remaining points

    mov dword [extraPoints], 0


    ; Check whether points remain

    cmp dword [extraPoints], 0

    jne allocateStats


    ; All 3 points have been spent

    jmp finishCharacter


; =========================================================
; SPEND ONE POINT
; =========================================================

spendPoint:

    ; Subtract one from the remaining points

    dec dword [extraPoints]


    ; Check whether points remain

    cmp dword [extraPoints], 0

    jne allocateStats


    ; All 3 points have been spent

    jmp finishCharacter


; =========================================================
; FINAL CHARACTER SHEET
; =========================================================

finishCharacter:

    call print_clear

    call print_sheet


    ; Display completion message

    mov eax, 4
    mov ebx, 1
    mov ecx, finishedText
    mov edx, finishedTextlen
    int 0x80


    ; Exit program

    ret


; =========================================================
; PRINT CHARACTER SHEET
; =========================================================

print_sheet:

    ; Display character sheet heading

    mov eax, 4
    mov ebx, 1
    mov ecx, characterSheet
    mov edx, characterSheetlen
    int 0x80


    ; -------------------------
    ; Strength
    ; -------------------------

    mov eax, 4
    mov ebx, 1
    mov ecx, str_text
    mov edx, str_textlen
    int 0x80

    mov eax, [strength]
    call print_integer

    call print_newline


    ; -------------------------
    ; Dexterity
    ; -------------------------

    mov eax, 4
    mov ebx, 1
    mov ecx, dex_text
    mov edx, dex_textlen
    int 0x80

    mov eax, [dex]
    call print_integer

    call print_newline


    ; -------------------------
    ; Constitution
    ; -------------------------

    mov eax, 4
    mov ebx, 1
    mov ecx, con_text
    mov edx, con_textlen
    int 0x80

    mov eax, [con]
    call print_integer

    call print_newline


    ; -------------------------
    ; Intelligence
    ; -------------------------

    mov eax, 4
    mov ebx, 1
    mov ecx, int_text
    mov edx, int_textlen
    int 0x80

    mov eax, [intel]
    call print_integer

    call print_newline


    ; -------------------------
    ; Inventory / Proficiencies
    ; -------------------------

    mov eax, 4
    mov ebx, 1
    mov ecx, [inventoryProf]
    mov edx, [inventoryProflen]
    int 0x80

    call print_newline


    ret


; =========================================================
; PRINT INTEGER
;
; Input:
;   EAX = unsigned integer to print
;
; Uses:
;   number_buffer
; =========================================================

print_integer:

    mov edi, number_buffer

    add edi, 11

    mov byte [edi], 0

    mov ebx, 10


.convert:

    xor edx, edx

    div ebx


    add dl, '0'

    dec edi

    mov [edi], dl


    test eax, eax

    jnz .convert


    ; Write converted number

    mov eax, 4
    mov ebx, 1
    mov ecx, edi


    mov edx, number_buffer

    add edx, 11

    sub edx, edi

    int 0x80


    ret


; =========================================================
; CLEAR SCREEN
; =========================================================

print_clear:

    mov eax, 4
    mov ebx, 1
    mov ecx, clear_screen
    mov edx, clear_screenlen
    int 0x80

    ret


; =========================================================
; PRINT NEWLINE
; =========================================================

print_newline:

    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 0x80

    ret


; =========================================================
; EXIT PROGRAM
; =========================================================

exit:

    mov eax, 1

    xor ebx, ebx

    int 0x80
