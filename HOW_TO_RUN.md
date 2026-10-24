# How to run Logic In Dungeon

The game has two parts:

- **`game`**: the game itself. It's 32-bit Linux assembly, built with `nasm` and `ld`. It runs on its own in a terminal.
- **`rd_gui`**: the window (C + raylib). It starts `game` in a hidden terminal and draws the graphics, sound and music.

Both need **Linux**. On Windows, you run them inside **WSL2**, Microsoft's built-in Linux. WSL2 shows Linux windows and plays their sound like normal Windows apps.

Every route ends the same way: unzip the folder, run `sh build_gui.sh`, then `./rd_gui`.

---

## 1. Get the files

1. Download `logic_in_dungeon.zip`.
2. Unzip it. In a Linux terminal:

       cd ~/Downloads
       unzip logic_in_dungeon.zip -d ~/
       cd ~/logic_in_dungeon_v27

   (Use the folder name the zip actually unpacks to.)

---

## 2. Linux

### Fedora

    sudo dnf install nasm gcc raylib-devel unzip
    sh build_gui.sh
    ./rd_gui

### Ubuntu / Debian / Linux Mint / Pop!_OS

First install the tools:

    sudo apt update
    sudo apt install build-essential nasm git unzip \
        libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libgl1-mesa-dev libasound2-dev

Some newer releases have raylib in their package list. Try it first:

    sudo apt install libraylib-dev && sh build_gui.sh

If that package is missing, or the build fails, build raylib 5.5 from source. It takes about a minute:

    cd ~
    git clone --depth 1 --branch 5.5 https://github.com/raysan5/raylib.git
    cd raylib/src
    make PLATFORM=PLATFORM_DESKTOP
    cd ~/logic_in_dungeon_v27
    RAYLIB_DIR=$HOME/raylib/src sh build_gui.sh
    ./rd_gui

### Arch / Manjaro

    sudo pacman -S nasm gcc raylib unzip
    sh build_gui.sh
    ./rd_gui

### Terminal only (no window, no raylib needed)

    sh build.sh
    ./game

Use a terminal at least 80 columns wide and 24 rows tall.

---

## 3. Windows 10 / 11 (through WSL2)

### One-time setup

1. **Install WSL2.** Right-click the Start button and open **Terminal (Admin)** (on Windows 10 it may be called **Windows PowerShell (Admin)**). Run:

       wsl --install

   This installs WSL2 with Ubuntu. **Restart the PC** when it asks.

2. **Finish setting up Ubuntu.** After the restart, Ubuntu opens by itself (or open **Ubuntu** from the Start menu). Pick a Linux username and password. The password is what `sudo` will ask for.

3. **Check for updates.** In PowerShell, run `wsl --update`. Windows 11, and Windows 10 with recent updates, include **WSLg**, which shows Linux windows and plays their sound. Nothing else needs installing.

4. **Install the tools and raylib.** In the Ubuntu window:

       sudo apt update
       sudo apt install build-essential nasm git unzip \
           libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libgl1-mesa-dev libasound2-dev
       cd ~
       git clone --depth 1 --branch 5.5 https://github.com/raysan5/raylib.git
       cd raylib/src
       make PLATFORM=PLATFORM_DESKTOP

### Build and play

Your Windows drive appears inside Ubuntu as `/mnt/c`. Copy the zip into your Linux home folder first: games built and run there are faster and avoid file-permission trouble.

    cp /mnt/c/Users/<YourWindowsName>/Downloads/logic_in_dungeon.zip ~/
    cd ~
    unzip logic_in_dungeon.zip -d ~/
    cd ~/logic_in_dungeon_v27
    RAYLIB_DIR=$HOME/raylib/src sh build_gui.sh
    ./rd_gui

The game opens in its own window on your Windows desktop.

**Next time,** open **Ubuntu** from the Start menu and run:

    cd ~/logic_in_dungeon_v27 && ./rd_gui

---

## 4. Troubleshooting

| Problem | Fix |
|---|---|
| `nasm: command not found` | Install nasm (see your section above). |
| `raylib.h: No such file or directory` | raylib isn't installed. Build it from source and use `RAYLIB_DIR=...` as shown. |
| `cannot find -lraylib` | Same as above: point `RAYLIB_DIR` at the `raylib/src` folder that contains `libraylib.a`. |
| Linker errors about `X11`, `GL`, `pthread` | Use the `RAYLIB_DIR=... sh build_gui.sh` form. It links every library raylib needs. |
| Window opens but no sound | Check that `assets/sfx` and `assets/music` sit next to `rd_gui`, and check the volume in the in-game **Options** menu. On WSL, run `wsl --update` in PowerShell. |
| WSL: `cannot open display` / no window appears | Run `wsl --update` and `wsl --shutdown` in PowerShell, then open Ubuntu again. |
| `Permission denied` running `./rd_gui` | `chmod +x rd_gui game` |
| Text in the terminal version is garbled | Make the terminal at least 80x24. |

Always run `rd_gui` from inside the game folder. It looks for `./game`, `assets/` and `settings.cfg` next to itself.
