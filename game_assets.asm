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

	;enemy stats 10 bytes
	ENEMY_HP_MIN equ 0
	ENEMY_HP_MAX equ 1
	ENEMY_DMG_MIN equ 2
	ENEMY_DMG_MAX equ 3
	ENEMY_ATK_BONUS equ 4 ;added to its d20 attack roll against your armor class
	ENEMY_RANGE equ 5 ;1 = melee, more = it attacks from that many cells away
	ENEMY_MOVE equ 6 ;cells it can move in one enemy turn (at most 4)
	ENEMY_W equ 7 ;size on the grid
	ENEMY_H equ 8
	ENEMY_BOSS equ 9 ;(normal|mini boss|final boss) = 0, 1, 2
	ENEMY_SIZE equ 10

	;hp min, hp max, dmg min, dmg max, attack bonus, range, move, width, height, boss
	enemyTable:
	goblin db 5,7, 1,3, 3, 1, 4, 1,1, 0 ;fast and weak
	skeleton db 6,8, 1,4, 2, 6, 3, 1,1, 0 ;shoots from 6 cells away
	orc db 12,16, 2,6, 4, 1, 3, 1,1, 0 ;slow, tough, hits hard
	miniboss db 40,50, 3,8, 5, 1, 3, miniboss_w,miniboss_h, 1
	finalboss db 100,120, 4,10, 6, 2, 3, finalboss_w,finalboss_h, 2 ;the Forgotten King
	ENEMY_TYPES equ ($ - enemyTable) / ENEMY_SIZE
	ETYPE_GOBLIN equ 0
	ETYPE_SKELETON equ 1
	ETYPE_ORC equ 2
	ETYPE_MINIBOSS equ 3
	ETYPE_KING equ 4

	;the sprite of each enemy type, same order as the table
	enemySprites dd goblinIcon, skeletonIcon, orcIcon, minibossIcon, finalbossIcon

	;which normal enemies show up: out of 10, (goblin, skeleton, orc) for floors 1-2, 3-6, 7+
	spawnOdds db 6,3,1, 4,4,2, 2,4,4

	;boss floors
	MINIBOSS_FLOORS equ 3
	minibossFloors db 4, 6, 11
	FINAL_FLOOR equ 15

	;potions
	minorPotion db 3		; heals 3
	regPotion db 6			; heals 6
	largePotion db 12       ; heals 12

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

	;the class bit for each class number (class '1','2','3' -> Fighter, Rogue, Wizard)

section .bss

section .text