#!/bin/sh
# Register Dungeon build.   sh build.sh   then   ./game
cd "$(dirname "$0")" || exit 1
nasm -f elf32 CC.asm -o CC.o || exit 1
nasm -f elf32 game.asm -o game.o || exit 1        # pulls in game_assets.asm, room.inc, enemies.inc, features.inc
ld -m elf_i386 game.o CC.o -o game || exit 1
echo "built ./game"
