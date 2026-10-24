section .data
	;map assets
	puzzlenode db "[0]"
	puzzlenode_w equ 3
	puzzlenode_h equ 1

	puzzlenodeactive db "[1]"
	puzzlenodeactive_w equ 3
	puzzlenodeactive_h equ 1

	panelasset db "R"
	doorasset db "<","<","<"
	door_w equ 1
	door_h equ 3
	opendoorasset db ">",">",">"
	opendoor_w equ 1
	opendoor_h equ 3

	;player and npc assets
	playerIcon db "@"
	goblinIcon db "G"
	skeletonIcon db "S"
	orcIcon db "O"
	minibossIcon db "MBM","MBM","MBM"
	miniboss_w equ 3
	miniboss_h equ 3
	finalbossIcon db "KKKKK","KKKKK","KKKKK"
	finalboss_w equ 5
	finalboss_h equ 3
	shadeIcon db "DDDDD","DDDDD","DDDDD"   ;the Dark Shade of the Forgotten King
	shade_w equ 5
	shade_h equ 3
	ymirIcon db "YYYY","YYYY","YYYY","YYYY"       ;Grand Wizard Ymir (floor 17)
	keeperIcon db "JJJJ","JJJJ","JJJJ","JJJJ"     ;the Logic Keeper behind its ward (floor 21)
	keeperOpenIcon db "jjjj","jjjj","jjjj","jjjj" ;  ... with the ward broken
	bishopIcon db "PP","PP"                       ;a bishop (floor 12): all four look the same
	altairIcon db "TT","TT"                       ;Altair, the quick one of the pair (floor 26)
	altairRageIcon db "tt","tt"                   ;  ... after taking Smo's power
	smoIcon db "UUUU","UUUU","UUUU","UUUU"        ;Smo, the heavy one of the pair (floor 26)
	smoRageIcon db "uuuu","uuuu","uuuu","uuuu"    ;  ... after taking Altair's power
	big4_w equ 4
	big4_h equ 4
	shadeDarkIcon db "ddddd","ddddd","ddddd"   ;the Shade in darkness (can't be hurt)
	altairZeroIcon db "FF","FF"                   ;Altair carrying the 0 (exposed)
	smoZeroIcon db "HHHH","HHHH","HHHH","HHHH"    ;Smo carrying the 0 (exposed)
	unboundIcon db "ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ","ZZZZZZZ"   ;the Forgotten King, Unbound (7x7)
	ucopyIcon db "zzzz","zzzz","zzzz","zzzz"      ;a copy of the Unbound King (drawn from a buffer at its current size)
	unbound_w equ 7
	unbound_h equ 7

	;enemy stats 10 bytes
	ENEMY_HP_MIN equ 0
	ENEMY_HP_MAX equ 1
	ENEMY_DMG_MIN equ 2
	ENEMY_DMG_MAX equ 3
	ENEMY_ATK_BONUS equ 4 ;added to its d20 attack roll against your armor class
	ENEMY_RANGE equ 5 ;1 = melee, more = it attacks from that many cells away
	ENEMY_MOVE equ 6 ;cells it can move in one enemy turn (at most 6)
	ENEMY_W equ 7 ;size on the grid
	ENEMY_H equ 8
	ENEMY_BOSS equ 9 ;(normal|mini boss|final boss) = 0, 1, 2
	ENEMY_SIZE equ 10

	;hp min, hp max, dmg min, dmg max, attack bonus, range, move, width, height, boss
	enemyTable:
	goblin db 5,7, 1,3, 3, 1, 4, 1,1, 0 ;fast and weak
	skeleton db 6,8, 1,4, 2, 6, 3, 1,1, 0 ;shoots from 6 cells away
	orc db 12,16, 2,6, 4, 1, 3, 1,1, 0 ;slow, tough, hits hard
	miniboss db 40,50, 3,8, 5, 1, 5, miniboss_w,miniboss_h, 1
	finalboss db 140,155, 1,4, 5, 60, 0, finalboss_w,finalboss_h, 2 ;the Forgotten King on his throne (floor 30): never moves, reaches everywhere
	shade db 100,115, 3,9, 6, 3, 5, shade_w,shade_h, 2 ;his Dark Shade (floor 15)
	ymir db 110,125, 3,8, 6, 7, 4, big4_w,big4_h, 1 ;casts spells from range 7 (see bosses.inc)
	keeper db 130,145, 3,9, 6, 2, 5, big4_w,big4_h, 1 ;its ward cuts damage to a quarter until you solve the gate
	altair db 70,80, 2,7, 7, 2, 6, 2,2, 1 ;fast, reach 2 (a spear)
	smo db 110,125, 4,11, 5, 1, 4, big4_w,big4_h, 1 ;slow, hits very hard
	unbound db 200,220, 4,10, 7, 1, 5, unbound_w,unbound_h, 2 ;the King after his fake death
	bishop db 30,36, 1,4, 5, 99, 0, 2,2, 1 ;the Four Bishops (floor 12): never move, cast across the whole room
	ucopy db 200,220, 4,10, 7, 99, 0, 2,2, 1 ;a copy of the Unbound King (his Bishops and Altair & Smo forms): size, reach and speed set per form
	ENEMY_TYPES equ ($ - enemyTable) / ENEMY_SIZE
	ETYPE_GOBLIN equ 0
	ETYPE_SKELETON equ 1
	ETYPE_ORC equ 2
	ETYPE_MINIBOSS equ 3
	ETYPE_KING equ 4
	ETYPE_SHADE equ 5
	ETYPE_YMIR equ 6
	ETYPE_KEEPER equ 7
	ETYPE_ALTAIR equ 8
	ETYPE_SMO equ 9
	ETYPE_UNBOUND equ 10
	ETYPE_BISHOP equ 11
	ETYPE_UCOPY equ 12

	;the sprite of each enemy type, same order as the table
	enemySprites dd goblinIcon, skeletonIcon, orcIcon, minibossIcon, finalbossIcon, shadeIcon, ymirIcon, keeperIcon, altairIcon, smoIcon, unboundIcon, bishopIcon, ucopyIcon

	;which normal enemies show up: out of 10, (goblin, skeleton, orc) for floors 1-2, 3-6, 7+
	spawnOdds db 6,3,1, 4,4,2, 2,4,4, 8,0,2     ;(the last three: floor 1, no skeletons)

	;boss floors
	MINIBOSS_FLOORS equ 2
	minibossFloors db 4, 8
	BISHOP_FLOOR equ 12 ;the Four Bishops
	SHADE_FLOOR equ 15 ;the Dark Shade of the Forgotten King
	YMIR_FLOOR equ 17 ;Grand Wizard Ymir
	KEEPER_FLOOR equ 21 ;the Logic Keeper
	DUO_FLOOR equ 26 ;Altair and Smo
	FINAL_FLOOR equ 30 ;the Forgotten King himself

	;potions
	minorPotion db 6, 5		; heals 6 + 5% of your max HP
	regPotion db 12, 10		; heals 12 + 10% of your max HP
	largePotion db 24, 15	; heals 24 + 15% of your max HP

	;effects, one shared list for weapons, armor and spells. one number per item, 0 = none
	EFFECT_NONE      equ 0
	EFFECT_BURN      equ 1
	EFFECT_SLEEP     equ 2
	EFFECT_HOLD      equ 3
	EFFECT_HASTE     equ 4
	EFFECT_TELEPORT  equ 5
	EFFECT_SLOW      equ 6
	EFFECT_POISON    equ 7
	EFFECT_LIFESTEAL equ 8
	EFFECT_BLIND     equ 9
	EFFECT_PRONE     equ 10	;knocked down: loses its next turn
	EFFECT_FRIGHT    equ 11	;frightened: won't attack
	LAST_STATUS      equ 11

	;weapons stats 8 bytes plus spare
	WEAPON_TYPE equ 0
	WEAPON_CLASS equ 1
	WEAPON_MIN_DAMAGE equ 2
	WEAPON_MAX_DAMAGE equ 3
	WEAPON_STAT_SCALING equ 4
	WEAPON_ATTACK_RANGE equ 5
	WEAPON_EFFECT equ 6
	WEAPON_TWO_HANDED equ 7 ;the spare byte: 1 = needs both hands (no shield)

	;weapon type(melee|range),class limit(fighter|rouge|wizard),min damage, max damage, damage scaling stat(STR|DEX|CON|INT),range,effect,spare
	;melee weapons
	greatsword db 0b10,0b100,2,12,0b1000,2,0,1	;two-handed
	longsword db 0b10,0b110,1,8,0b1000,2,0,0
	shortsword db 0b10,0b110,1,6,0b0100,1,0,0
	pike db 0b10,0b100,1,10,0b1000,3,0,1	;two-handed
	rapier db 0b10,0b110,1,8,0b1100,1,0,0
	quarterstaff db 0b10,0b101,1,6,0b1000,2,0,0
	dagger db 0b10,0b111,1,4,0b1100,1,0,0

	;ranged weapons
	longbow db 0b01,0b100,1,8,0b0100,20,0,1	;two-handed
	shortbow db 0b01,0b110,1,6,0b0100,15,0,0
	lightcrossbow db 0b01,0b110,1,8,0b0100,12,0,0
	heavycrossbow db 0b01,0b100,1,10,0b1000,14,0,1	;two-handed

	;armor stats 8 bytes plus spare
	ARMOR_TYPE equ 0 ;(body|shield|helmet|gloves|boots)
	ARMOR_WEIGHT equ 1 ;(Heavy|Medium|Light|Clothes)
	ARMOR_AC equ 2 ; 
	ARMOR_AC_DEX_MAX equ 3
	ARMOR_MV_PENALTY equ 4
	ARMOR_STAT_BONUS equ 5 ;Increases player stat(STR|DEX|CON|INT)
	ARMOR_BONUS_AMOUNT equ 6
	ARMOR_EFFECT equ 7

	;body armor
	breastplate	   db 0b10000, 0b0100,4,2,0,0,0,0,0
	simplerobe     db 0b10000, 0b0001,0,99,0,0,0,0,0
	leatherarmor   db 0b10000, 0b0010,1,99,0,0,0,0,0

	;shield
	buckler	   	db 0b01000, 0b0010,1,99,0,0,0,0,0
	shield	   	db 0b01000, 0b0100,2,99,0,0,0,0,0

	;special items (rare drops and boss legendaries) - made by items.py
%include "items_rec.inc"

	;spells stats, 12 bytes each
	SPELL_TYPE equ 0 ;(Attack|Utility)
	SPELL_CLASS equ 1 ;(fighter|rouge|wizard)
	SPELL_MIN_DAMAGE equ 2
	SPELL_MAX_DAMAGE equ 3
	SPELL_STAT_SCALING equ 4 ;effectiveness based on stat (STR|DEX|CON|INT)
	SPELL_RANGE equ 5 ;max range of attack from player to target; for cone and line it is also their length
	SPELL_MANA_COST equ 6 ;Mana cost per use
	SPELL_EFFECT equ 7 ;effect number, see EFFECT_ above
	SPELL_SHAPE equ 8 ;(point|cone|line)
	SPELL_MAX_TARGET equ 9 ;max amount of independent target for spells
	SPELL_TARGETABLES equ 10 ;Enables what can be targeted by spell (Self|Enemy|Empty Space)
	SPELL_AREA equ 11 ;odd width of the square around the target, 1 = just the target

	;note for later, for spells like hold monster that need consentration maybe scale with con? would be wisdom but thats not an ingame stat
	;type, class, min, max, scaling, range, mana, effect, shape, max targets, targetables, area
	spellTable:
	firebolt db 0b10,0b001,1,10,0b0001,15,0,EFFECT_NONE,0b100,1,0b011,1
	fireball db 0b10,0b001,8,48,0b0001,17,5,EFFECT_NONE,0b100,1,0b111,5
	magicmissle db 0b10,0b001,1,4,0b0001,16,3,EFFECT_NONE,0b100,3,0b010,1
	scorchingray db 0b10,0b001,1,6,0b0001,16,3,EFFECT_NONE,0b100,3,0b010,1
	mistystep db 0b01,0b001,0,0,0b0000,20,3,EFFECT_TELEPORT,0b100,1,0b001,1
	sleep db 0b01,0b001,0,0,0b0000,10,3,EFFECT_SLEEP,0b100,1,0b010,1
	holdmonster db 0b01,0b001,0,0,0b0000,8,4,EFFECT_HOLD,0b100,1,0b010,1
	haste db 0b01,0b001,0,0,0b0000,0,4,EFFECT_HASTE,0b100,1,0b100,1
	rayoffrost db 0b10,0b001,2,8,0b0001,15,0,EFFECT_SLOW,0b100,1,0b010,1
	vampirictouch db 0b10,0b001,3,18,0b0001,1,3,EFFECT_LIFESTEAL,0b100,1,0b010,1
	sunbeam db 0b10,0b001,8,48,0b0001,18,6,EFFECT_BLIND,0b001,1,0b011,1
	icestorm db 0b10,0b001,6,40,0b0001,17,5,EFFECT_SLOW,0b100,1,0b011,5
	coneofcold db 0b10,0b001,8,64,0b0001,9,5,EFFECT_NONE,0b010,1,0b011,1
	SPELL_SIZE equ 12
	SPELL_COUNT equ ($ - spellTable) / SPELL_SIZE

	;spell names: one fixed-width slot per spell, in the SAME ORDER as the table above, zero padded
	NAME_LEN equ 16
	%macro fixedname 1
		%strlen _l %1
		db %1
		times NAME_LEN - _l db 0
	%endmacro
	spellNames:
		fixedname "Firebolt"
		fixedname "Fireball"
		fixedname "Magic Missile"
		fixedname "Scorching Ray"
		fixedname "Misty Step"
		fixedname "Sleep"
		fixedname "Hold Monster"
		fixedname "Haste"
		fixedname "Ray of Frost"
		fixedname "Vampiric Touch"
		fixedname "Sunbeam"
		fixedname "Ice Storm"
		fixedname "Cone of Cold"

	;enemy names, same order as the enemy table
	enemyNames:
		fixedname "Goblin"
		fixedname "Skeleton"
		fixedname "Orc"
		fixedname "Warden"
		fixedname "Forgotten King"
		fixedname "Dark Shade"
		fixedname "Wizard Ymir"
		fixedname "Logic Keeper"
		fixedname "Altair"
		fixedname "Smo"
		fixedname "King Unbound"
		fixedname "Bishop"
		fixedname "King Unbound"

	;the class bit for each class number (class '1','2','3' -> Fighter, Rogue, Wizard)

section .bss

section .text