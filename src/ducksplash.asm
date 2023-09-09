INCLUDE "src/hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint

	ds $150 - @, 0

EntryPoint:
	; Disable audio.
	ld a, 0
	ld [rNR52], a

	; Important! Do not turn the LCD off outside of VBlank! This can cause hardware damage.
	call WaitVBlank

	; Turn the LCD off.
	ld a, 0
	ld [rLCDC], a

	; Copy the background tile data
	ld de, Tiles
	ld hl, $9000
	ld bc, TilesEnd - Tiles
	call CopyBytes

	; Copy the background tilemap data.
	ld de, Tilemap
	ld hl, $9800
	ld bc, TilemapEnd - Tilemap
	call CopyBytes

	; Copy the tile data
	ld de, Objects
	ld hl, $8000
	ld bc, ObjectsEnd - Objects
	call CopyBytes

	; Clear the OAM, which starts off with garbage values.
	ld a, 0
	; 160 bytes = 40 objects * 4 bytes
	ld b, 160
	ld hl, _OAMRAM
ClearOam:
	ld [hli], a
	dec b
	jp nz, ClearOam

	; Initialize variables and position the duck.
	ld a, 254
	ld [wRand], a
	ld a, 60
	ld [wNewFish], a
	ld a, %00000000
	ld [wDuckFlags], a
	ld a, 0
	ld [wDuckBob], a
	ld a, 0
	ld [wDuckOpen], a
	ld a, 72
	ld [wDuckX], a
	ld b, a
	ld a, 71
	ld [wDuckY], a
	ld c, a
	call PositionDuck

	; Turn the LCD on, and enable background and object rendering.
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
	ld [rLCDC], a

	; Initialize display registers.
	ld a, %11100100
	ld [rBGP], a
	ld a, %11100100
	ld [rOBP0], a
	ld [rOBP1], a

Main:
	call WaitVBlank

	call StepRand
	call UpdateKeys
	call ProcessKeysH
	call ProcessKeysV
	call BobDuck
	call ConstrainDuck
	call SpawnFish
	call MoveFish
	call EatFish
	call CloseDuckBill

	; Adjust duck position
	ld a, [wDuckX]
	ld b, a
	ld a, [wDuckY]
	ld c, a
	call PositionDuck

	jp Main

WaitVBlank:
	ld a, [rLY]
	cp 144
	; If we're already in VBlank, wait for the next one.
	jp nc, WaitVBlank
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2
	ret

BobDuck:
	ld a, [wDuckBob]
	inc a
	ld [wDuckBob], a
	ld b, a
	and a, %00001111
	jp nz, BobDuckRet
	ld a, b
	and a, %00100000
	ld a, [wDuckY]
	jp z, BobDuckDown
BobDuckUp:
	dec a
	jp BobDuckEnd
BobDuckDown:
	inc a
BobDuckEnd:
	ld [wDuckY], a
BobDuckRet:
	ret

ConstrainDuck:
ConstrainDuckCheckXUnder:
	ld a, [wDuckX]
	cp a, 8
	jp nc, ConstrainDuckCheckXOver
	ld a, 8
	ld [wDuckX], a
	jp ConstrainDuckCheckYUnder
ConstrainDuckCheckXOver:
	cp a, 136
	jp c, ConstrainDuckCheckYUnder
	ld a, 136
	ld [wDuckX], a
ConstrainDuckCheckYUnder:
	ld a, [wDuckY]
	cp a, 13
	jp nc, ConstrainDuckCheckYOver
	ld a, 13
	ld [wDuckY], a
	jp ConstrainDuckEnd
ConstrainDuckCheckYOver:
	cp a, 130
	jp c, ConstrainDuckEnd
	ld a, 130
	ld [wDuckY], a
ConstrainDuckEnd:
	ret

MACRO PutTileIndexAndFlags
	ld a, \3
	add a, c
	ld [hli], a
	ld a, \2
	add a, b
	ld [hli], a
	ld a, \1
	ld [hli], a
	ld a, d
	ld [hli], a
	ENDM

PositionDuck:
	; b = x
	; c = y
	; Modifies a, d, e, h, l
	;
	ld hl, _OAMRAM
	ld e, OBJ_TILE_DUCK_CLOSED
	ld a, [wDuckOpen]
	or a, a
	jp z, PositionDuckBillClosed
	ld e, OBJ_TILE_DUCK_OPEN
PositionDuckBillClosed:
	ld a, [wDuckFlags]
	ld d, a
	and a, %00100000
	jp z, PositionDuckRight
PositionDuckLeft:
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_02,0,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_01,8,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_00,16,0
	PutTileIndexAndFlags e,0,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_11,8,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_10,16,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_TAIL_0,24,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_BREAST,0,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_MIDDLE,8,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_MIDDLE,16,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_TAIL_1,24,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_3,0,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_2,8,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_1,16,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_0,24,24
	ret
PositionDuckRight:
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_00,8,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_01,16,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_02,24,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_TAIL_0,0,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_10,8,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_11,16,8
	PutTileIndexAndFlags e,24,8
	PutTileIndexAndFlags OBJ_TILE_DUCK_TAIL_1,0,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_MIDDLE,8,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_MIDDLE,16,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_BREAST,24,16
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_0,0,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_1,8,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_2,16,24
	PutTileIndexAndFlags OBJ_TILE_DUCK_BOTTOM_3,24,24
	ret

CopyBytes:
	; de = source address
	; hl = destination address
	; bc = length
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, CopyBytes
	ret

UpdateKeys:
  ld a, P1F_GET_BTN
  call UpdateKeysOneNibble
  ld b, a
  ld a, P1F_GET_DPAD
  call UpdateKeysOneNibble
  swap a
  xor a, b
  ld b, a
  ld a, P1F_GET_NONE
  ldh [rP1], a
  ld a, [wCurKeys]
  xor a, b
  and a, b
  ld [wNewKeys], a
  ld a, b
  ld [wCurKeys], a
  ret
UpdateKeysOneNibble:
  ldh [rP1], a
  call UpdateKeysRet
  ldh a, [rP1]
  ldh a, [rP1]
  ldh a, [rP1]
  or a, $F0
UpdateKeysRet:
  ret

ProcessKeysH:
	ld a, [wCurKeys]
	and a, PADF_LEFT
	jp z, ProcessKeysHCheckRight
	ld a, %00100000
	ld [wDuckFlags], a
	ld a, [wDuckX]
	dec a
	dec a
	ld [wDuckX], a
	jp ProcessKeysHAddRand
ProcessKeysHCheckRight:
	ld a, [wCurKeys]
	and a, PADF_RIGHT
	jp z, ProcessKeysHEnd
	ld a, %00000000
	ld [wDuckFlags], a
	ld a, [wDuckX]
	inc a
	inc a
	ld [wDuckX], a
ProcessKeysHAddRand:
	ld a, [wRand]
	add a, 33
	ld [wRand], a
ProcessKeysHEnd:
	ret

ProcessKeysV:
	ld a, [wCurKeys]
	and a, PADF_UP
	jp z, ProcessKeysVCheckDown
	ld a, [wDuckY]
	dec a
	dec a
	ld [wDuckY], a
	jp ProcessKeysVAddRand
ProcessKeysVCheckDown:
	ld a, [wCurKeys]
	and a, PADF_DOWN
	jp z, ProcessKeysVEnd
	ld a, [wDuckY]
	inc a
	inc a
	ld [wDuckY], a
ProcessKeysVAddRand:
	ld a, [wRand]
	sub a, 12
	ld [wRand], a
ProcessKeysVEnd:
	ret

StepRand:
	; Simple LCG: a = (5 * a + 1) % 256
	ld a, [wRand]
	ld b, a
	add a, a
	add a, a
	add a, b
	inc a
	ld [wRand], a
	ret

SpawnFish:
	ld a, [wNewFish]
	dec a
	jp nz, SpawnFishEnd

	ld hl, _OAMRAM + OAM_OFF_FISH_FIRST
	ld de, 8
	ld b, MAX_FISH_COUNT
SpawnFishLocateEmpty:
	ld a, 0
	cp a, [hl]
	jp nz, SpawnFishLocateEmptyContinue

	ld c, 115
	call StepRand
	; a is filled with a new random number as a result of StepRand:
SpawnFishCalculateYModulo:
	cp a, c
	jp c, SpawnFishCalculateYModuloEnd
	sub a, c
	jp SpawnFishCalculateYModulo

SpawnFishCalculateYModuloEnd:
	add a, 24
	ld c, a
	; c is now a random number between 24 and 138 (inclusive). Note that there is some unequal
	; distribution, i.e. some positions are much more likely as others. Oh well!

	; Set the Y position:
	ld [hli], a

	; Let's get another random number in b to decide what type of fish this is, and whether it should
	; be facing left or right.
	ld a, [wRand]
	ld b, a

	; Use this bit to determine flip orientation (happens to be the OAM X flip bit):
	and a, %00100000
	jp nz, SpawnFishSetXRight
	; signed -7:
	ld a, 249
	jp SpawnFishSetXFinish
SpawnFishSetXRight:
	ld a, 167
SpawnFishSetXFinish:
	ld d, a
	; Set the X position:
	ld [hli], a

	ld a, b
	; OK, this is magic. Load a couple bits from b (the random value).
	and a, %01100000
	rlca
	rlca
	rlca
	; Now, the bit used to determine X flip is the least significant bit, and a previously unused bit
	; is the second least significant bit. So, the X flip bit determines whether we're pointing to
	; OBJ_TILE_FISH_x_0 or OBJ_TILE_FISH_x_1. The second least significant bit determines whether
	; we're pointing to OBJ_TILE_FISH_0_x or OBJ_TILE_FISH_1_x.
	add a, OBJ_TILE_FISH_0_0
	ld e, a
	; Now e either points to OBJ_TILE_FISH_0_0, OBJ_TILE_FISH_1_0, OBJ_TILE_FISH_0_1, or
	; OBJ_TILE_FISH_1_1. Simple!

	; The shark (OBJ_TILE_FISH_2_x) is a rare fish. Let's give it a 1 in 8 chance by utilizing 2 bits
	; of b:
	ld a, b
	and a, %00000110
	jp nz, SpawnFishNotShark
	ld a, e
	; Note: This will either promote FISH_0 to FISH_1, or FISH_1 to FISH_2. This incidentally makes
	; FISH_1 more common than FISH_0.
	add a, 2
	ld e, a

SpawnFishNotShark:
	ld a, e
	ld [hli], a

	; Set the flags (X flip):
	ld a, b
	and a, %00100000
	ld [hli], a

	ld a, c
	ld [hli], a
	ld a, d
	add a, 8
	ld [hli], a
	; Load e into a, and then flip its least signifcant bit. This depends on the OBJ_TILE_FISH_0_x
	; indexes all being even numbers!
	ld a, e
	xor a, %00000001
	ld [hli], a
	ld a, b
	and a, %00100000
	ld [hli], a

	jp SpawnFishRandomize

SpawnFishLocateEmptyContinue:
	add hl, de
	dec b
	jp nz, SpawnFishLocateEmpty

SpawnFishRandomize:
	ld a, [wRand]
	srl a
	add a, 10
SpawnFishEnd:
	ld [wNewFish], a
	ret

MoveFish:
	ld e, MAX_FISH_COUNT
	ld hl, _OAMRAM + OAM_OFF_FISH_FIRST
MoveFishContinue:
	inc hl
	ld a, [hl]
	; Test if a >= 168 && a <= 248. If it is, mark y = 0 for both tiles and move on to the next fish
	; slot.
	cp a, 168
	jp c, MoveFishOnScreen
	cp a, 249
	jp nc, MoveFishOnScreen
	dec hl
	ld a, 0
	ld [hli], a
	inc hl
	inc hl
	inc hl
	ld [hli], a
	inc hl
	inc hl
	inc hl
	jp MoveFishNext
MoveFishOnScreen:
	inc hl
	inc hl
	ld a, [hl]
	dec hl
	dec hl
	and a, %00100000
	jp nz, MoveFishLeft
	inc [hl]
	inc hl
	inc hl
	inc hl
	inc hl
	inc [hl]
	inc hl
	inc hl
	inc hl
	jp MoveFishNext
MoveFishLeft:
	dec [hl]
	inc hl
	inc hl
	inc hl
	inc hl
	dec [hl]
	inc hl
	inc hl
	inc hl
MoveFishNext:
	dec e
	jp nz, MoveFishContinue
	ret

EatFish:
	ld hl, _OAMRAM
	ld a, [wDuckFlags]
	ld d, 20
	and a, %00100000
	jp z, EatFishDuckRight
	ld d, 3
EatFishDuckRight:
	ld e, MAX_FISH_COUNT
	ld hl, _OAMRAM + OAM_OFF_FISH_FIRST
	; Loop through all 4 fish.
EatFishContinue:
	ld a, [hl]
	or a, a
	; If fish.y == 0, skip to the next fish.
	jp z, EatFishNext
	ld c, a
	inc hl
	ld a, [hl]
	add a, 16
	ld b, a
	dec hl
	; Rough math:
	;
	; Duck bill = [wDuckX + 16, wDuckX + 24, wDuckY + 8, wDuckY + 16]
	; Fish = [fish.x, fish.x + 16, fish.y, fish.y + 8]
	;
	; wDuckX + 16 >= fish.x + 16? skip to the next fish
	; wDuckX + 24 <= fish.x? skip to the next fish
	; wDuckY + 8 >= fish.y + 8? skip to the next fish
	; wDuckY + 16 <= fish.y? skip to the next fish
	;
	; Don't forget to take into consideration the duck orientation! That's taken care of by the
	; d register.
	;
	; b = fish.x
	; c = fish.y
	ld a, [wDuckX]
	add a, d
	cp a, b
	jp nc, EatFishNext
	add a, 24
	cp a, b
	jp c, EatFishNext
	jp z, EatFishNext
	ld a, [wDuckY]
	cp a, c
	jp nc, EatFishNext
	add a, 16
	cp a, c
	jp c, EatFishNext
	jp z, EatFishNext
	ld [hl], 0
	inc hl
	inc hl
	inc hl
	inc hl
	ld [hl], 0
	ld a, 12
	ld [wDuckOpen], a
	jp EatFishNextHalf
EatFishNext:
	dec e
	jp z, EatFishRet
	inc hl
	inc hl
	inc hl
	inc hl
EatFishNextHalf:
	inc hl
	inc hl
	inc hl
	inc hl
	jp EatFishContinue
EatFishRet:
	ret

CloseDuckBill:
	ld a, [wDuckOpen]
	or a, a
	jp z, CloseDuckBillRet
	dec a
	ld [wDuckOpen], a
	or a, a
	jp nz, CloseDuckBillRet
CloseDuckBillRet:
	ret

Tiles:
INCBIN "res/background.2bpp"
TilesEnd:

Tilemap:
INCBIN "res/background.tilemap"
TilemapEnd:

Objects:
INCBIN "res/objects.2bpp"
ObjectsEnd:

SECTION "Variables", WRAM0

wRand: db
wNewFish: db
wDuckX: db
wDuckY: db
wDuckOpen: db
wDuckFlags: db
wDuckBob: db
wCurKeys: db
wNewKeys: db

DEF OBJ_TILE_DUCK_HEAD_00 EQU 0
DEF OBJ_TILE_DUCK_HEAD_01 EQU 1
DEF OBJ_TILE_DUCK_HEAD_02 EQU 2
DEF OBJ_TILE_DUCK_TAIL_0 EQU 3
DEF OBJ_TILE_DUCK_HEAD_10 EQU 4
DEF OBJ_TILE_DUCK_HEAD_11 EQU 5
DEF OBJ_TILE_DUCK_CLOSED EQU 6
DEF OBJ_TILE_DUCK_OPEN EQU 7
DEF OBJ_TILE_DUCK_TAIL_1 EQU 8
DEF OBJ_TILE_DUCK_MIDDLE EQU 9
DEF OBJ_TILE_DUCK_BREAST EQU 10
DEF OBJ_TILE_DUCK_BOTTOM_0 EQU 11
DEF OBJ_TILE_DUCK_BOTTOM_1 EQU 12
DEF OBJ_TILE_DUCK_BOTTOM_2 EQU 13
DEF OBJ_TILE_DUCK_BOTTOM_3 EQU 14
DEF OBJ_TILE_BUBBLE EQU 15
DEF OBJ_TILE_FISH_0_0 EQU 16
DEF OBJ_TILE_FISH_0_1 EQU 17
DEF OBJ_TILE_FISH_1_0 EQU 18
DEF OBJ_TILE_FISH_1_1 EQU 19
DEF OBJ_TILE_FISH_2_0 EQU 20
DEF OBJ_TILE_FISH_2_1 EQU 21

DEF OAM_OFF_FISH_FIRST EQU 15 * 4
; Each fish takes up 2 consecutive objects.
DEF MAX_FISH_COUNT EQU 4
