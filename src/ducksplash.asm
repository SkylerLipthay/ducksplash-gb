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

	; Load and position the duck.
	ld a, %00000000
	ld [wDuckFlags], a
	ld a, 0
	ld [wDuckBob], a
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

	call UpdateKeys
	call ProcessKeysH
	call ProcessKeysV
	call BobDuck
	call ConstrainDuck

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
	; Modifies a, d, h, l
	;
	ld hl, _OAMRAM
	ld a, [wDuckFlags]
	ld d, a
	and a, %00100000
	jp z, PositionDuckRight
PositionDuckLeft:
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_02,0,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_01,8,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_HEAD_00,16,0
	PutTileIndexAndFlags OBJ_TILE_DUCK_CLOSED,0,8
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
	PutTileIndexAndFlags OBJ_TILE_DUCK_CLOSED,24,8
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
ProcessKeysVCheckDown:
	ld a, [wCurKeys]
	and a, PADF_DOWN
	jp z, ProcessKeysVEnd
	ld a, [wDuckY]
	inc a
	inc a
	ld [wDuckY], a
ProcessKeysVEnd:
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

wDuckX: db
wDuckY: db
wDuckFlags: db
wDuckBob: db
wCurKeys: db
wNewKeys: db

DEF OBJ_TILE_EMPTY EQU 0
DEF OBJ_TILE_DUCK_HEAD_00 EQU 1
DEF OBJ_TILE_DUCK_HEAD_01 EQU 2
DEF OBJ_TILE_DUCK_HEAD_02 EQU 3
DEF OBJ_TILE_DUCK_BUBBLE EQU 4
DEF OBJ_TILE_DUCK_TAIL_0 EQU 5
DEF OBJ_TILE_DUCK_HEAD_10 EQU 6
DEF OBJ_TILE_DUCK_HEAD_11 EQU 7
DEF OBJ_TILE_DUCK_CLOSED EQU 8
DEF OBJ_TILE_DUCK_OPEN EQU 9
DEF OBJ_TILE_FISH_0_0 EQU 10
DEF OBJ_TILE_FISH_0_1 EQU 11
DEF OBJ_TILE_DUCK_TAIL_1 EQU 12
DEF OBJ_TILE_DUCK_MIDDLE EQU 13
DEF OBJ_TILE_DUCK_BREAST EQU 14
DEF OBJ_TILE_FISH_1_0 EQU 15
DEF OBJ_TILE_FISH_1_1 EQU 16
DEF OBJ_TILE_DUCK_BOTTOM_0 EQU 17
DEF OBJ_TILE_DUCK_BOTTOM_1 EQU 18
DEF OBJ_TILE_DUCK_BOTTOM_2 EQU 19
DEF OBJ_TILE_DUCK_BOTTOM_3 EQU 20
DEF OBJ_TILE_FISH_2_0 EQU 21
DEF OBJ_TILE_FISH_2_1 EQU 22
