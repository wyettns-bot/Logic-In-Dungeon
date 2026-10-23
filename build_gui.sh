#!/bin/sh
# Builds the assembly game AND the raylib window.   sh build_gui.sh   then   ./rd_gui
#   Fedora:  sudo dnf install nasm raylib-devel
#   raylib built from source instead?  RAYLIB_DIR=/path/to/raylib/src sh build_gui.sh
cd "$(dirname "$0")" || exit 1
sh build.sh || exit 1                                   # the game itself (assembly)
if [ -n "$RAYLIB_DIR" ]; then
    gcc -O2 rd_gui.c -o rd_gui -I"$RAYLIB_DIR" -L"$RAYLIB_DIR" -lraylib -lGL -lm -lpthread -ldl -lrt -lX11 -lutil || exit 1
else
    gcc -O2 rd_gui.c -o rd_gui -lraylib -lm -lutil || exit 1
fi
echo "built ./rd_gui  -  run it with:  ./rd_gui"
