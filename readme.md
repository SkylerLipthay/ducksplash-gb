# Ducksplash for Game Boy

A small Game Boy game. You play as a duck who moves around the screen to eat fish.

## Demo

![](www/gameplay.gif?raw=true)

## Building

Building this project requires `make` and the [RGBDS](https://rgbds.gbdev.io/) toolchain to be installed. Once the prerequisites are installed, just run `make` and find the output ROM at `build/ducksplash.gb`.

## Purpose

This was my first attempt at writing a retro console game. There's lots to be improved and fully understood.

The [Game Boy Pan Docs](https://gbdev.io/pandocs/), the [Game Boy ASM Tutorial](https://gbdev.io/gb-asm-tutorial/index.html), and [The Ultimate Game Boy Talk](https://www.youtube.com/watch?v=HyzD8pNlpwI) are awesome guides.

## TODO

* Spawn a bubble that floats to the surface when a fish is eaten (`OBJ_TILE_BUBBLE` already exists)
* Play a peep sound when a fish is eaten
* Add a "wave" visual effect to the background layer to simulate water
* Reorganize code, document things better, etc.
