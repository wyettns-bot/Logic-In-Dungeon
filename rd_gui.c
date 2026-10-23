/*
 * rd_gui.c  -  Logic In Dungeon, raylib front end
 *
 * The game is still the assembly program (./game). This program runs it in an invisible
 * terminal, reads what it prints, works out the game state from it (HP, mana, enemies,
 * spells, bag, messages, the map) and draws a proper interface around it. Your clicks and
 * keys go back to the assembly as ordinary terminal input. No game rules live here.
 *
 * Build (Fedora):   sudo dnf install raylib-devel
 *                   gcc rd_gui.c -o rd_gui -lraylib -lm -lutil
 * Run:              ./rd_gui            (runs ./game from the same folder)
 */
#include "raylib.h"
#include "rlgl.h"
#include <math.h>

/* ---- the dungeon look: every "rounded" box is drawn as a notched stone slab ---- */
static void slab_fill_v(Rectangle r, float rd, int seg, Color c) {     /* sharp corners cut at 45 degrees */
    (void)rd; (void)seg;
    if (r.width <= 0 || r.height <= 0) return;
    float n = fminf(6.0f, fminf(r.width, r.height) * 0.25f);
    DrawRectangleRec((Rectangle){ r.x + n, r.y, r.width - 2 * n, r.height }, c);
    DrawRectangleRec((Rectangle){ r.x, r.y + n, n, r.height - 2 * n }, c);
    DrawRectangleRec((Rectangle){ r.x + r.width - n, r.y + n, n, r.height - 2 * n }, c);
    Vector2 t[4][3] = {
        { { r.x, r.y + n }, { r.x + n, r.y + n }, { r.x + n, r.y } },
        { { r.x + r.width - n, r.y }, { r.x + r.width - n, r.y + n }, { r.x + r.width, r.y + n } },
        { { r.x, r.y + r.height - n }, { r.x + n, r.y + r.height }, { r.x + n, r.y + r.height - n } },
        { { r.x + r.width - n, r.y + r.height - n }, { r.x + r.width - n, r.y + r.height }, { r.x + r.width, r.y + r.height - n } } };
    for (int i = 0; i < 4; i++) { DrawTriangle(t[i][0], t[i][1], t[i][2], c); DrawTriangle(t[i][0], t[i][2], t[i][1], c); }
}
static void slab_line_v(Rectangle r, float rd, int seg, float th, Color c) {
    (void)rd; (void)seg;
    if (r.width <= 0 || r.height <= 0) return;
    float n = fminf(6.0f, fminf(r.width, r.height) * 0.25f), h = th / 2;
    Vector2 p[8] = { { r.x + n, r.y + h }, { r.x + r.width - n, r.y + h }, { r.x + r.width - h, r.y + n }, { r.x + r.width - h, r.y + r.height - n },
                     { r.x + r.width - n, r.y + r.height - h }, { r.x + n, r.y + r.height - h }, { r.x + h, r.y + r.height - n }, { r.x + h, r.y + n } };
    for (int i = 0; i < 8; i++) DrawLineEx(p[i], p[(i + 1) % 8], th, c);
}
#define DrawRectangleRounded(...) slab_fill_v(__VA_ARGS__)
#define DrawRectangleRoundedLinesEx(...) slab_line_v(__VA_ARGS__)
#include <pty.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <math.h>
#include <sys/wait.h>
#include "sprites.h"
#include "gui_items.h"

/* ================================================================== */
/* 1. the invisible terminal the assembly game runs in                 */
/* ================================================================== */
#define COLS 120
#define ROWS 26
static char scr[ROWS][COLS];
static int cur_r, cur_c, mouse_on, game_fd = -1, game_over;
static pid_t game_pid = -1;
static char last_frame[ROWS][COLS];
static int have_last;
static const char *game_path = "./game";

static void clear_screen(void) { memset(scr, ' ', sizeof scr); }
static void newline(void) {
    if (cur_r == ROWS - 1) { memmove(scr[0], scr[1], (ROWS - 1) * COLS); memset(scr[ROWS - 1], ' ', COLS); }
    else cur_r++;
}
static void put_char(char ch) { if (cur_c >= COLS) { cur_c = 0; newline(); } scr[cur_r][cur_c++] = ch; }

/* every message the game prints goes into this queue, so a sound can play for each one,
   even when two in a row read the same ("You hit for 5", "You hit for 5") */
static char msgq[16][COLS + 1]; static int msgq_n;
static void msg_written(void) {
    int a = 0, b = cur_c;
    while (a < b && scr[23][a] == ' ') a++;
    while (b > a && scr[23][b - 1] == ' ') b--;
    if (b <= a || msgq_n >= 16) return;
    memcpy(msgq[msgq_n], &scr[23][a], b - a); msgq[msgq_n][b - a] = 0; msgq_n++;
}

/* invisible notes from the game: ESC ] 77 ; <text> BEL (a terminal ignores them) */
static char osc_buf[512]; static int osc_len;
static void handle_osc(const char *t);
static void handle_osc_fx(const char *t);
static void handle_osc_attack(const char *t);
static void handle_osc_enemy(const char *t);
static enum { NORMAL, ESC_SEEN, CSI, OSC } pstate;
static char csi_buf[32];
static int csi_len;

static void run_csi(char fin) {
    int priv = csi_len > 0 && csi_buf[0] == '?', p[8] = {0}, np = 0, have = 0;
    for (int i = priv; i < csi_len && np < 8; i++) {
        char c = csi_buf[i];
        if (c >= '0' && c <= '9') { p[np] = p[np] * 10 + (c - '0'); have = 1; }
        else if (c == ';') { np++; have = 0; }
    }
    if (have || np) np++;
    if (fin == 'H' || fin == 'f') {
        cur_r = (np >= 1 && p[0] ? p[0] : 1) - 1; cur_c = (np >= 2 && p[1] ? p[1] : 1) - 1;
        if (cur_r < 0) cur_r = 0;
        if (cur_r >= ROWS) cur_r = ROWS - 1;
        if (cur_c < 0) cur_c = 0;
        if (cur_c >= COLS) cur_c = COLS - 1;
    } else if (fin == 'J') {
        if (np && p[0] == 2) clear_screen();
        else { memset(&scr[cur_r][cur_c], ' ', COLS - cur_c); for (int r = cur_r + 1; r < ROWS; r++) memset(scr[r], ' ', COLS); }
    } else if (fin == 'K') {
        memset(&scr[cur_r][cur_c], ' ', COLS - cur_c);
        if (cur_r == 23) msg_written();      /* the game just finished printing a message (even the same text again) */
    }
    else if ((fin == 'h' || fin == 'l') && priv) {
        for (int i = 0; i < np; i++) if (p[i] == 1000 || p[i] == 1003 || p[i] == 1006) {
            if (fin == 'l' && mouse_on) { memcpy(last_frame, scr, sizeof scr); have_last = 1; }
            mouse_on = fin == 'h';
        }
    }
}
static void feed(const char *b, int n) {
    for (int i = 0; i < n; i++) {
        unsigned char ch = (unsigned char)b[i];
        if (pstate == NORMAL) {
            if (ch == 27) pstate = ESC_SEEN;
            else if (ch == '\r') cur_c = 0;
            else if (ch == '\n') newline();
            else if (ch == '\b') { if (cur_c) cur_c--; }
            else if (ch >= 32 && ch < 127) put_char((char)ch);
        } else if (pstate == ESC_SEEN) { if (ch == '[') { pstate = CSI; csi_len = 0; } else if (ch == ']') { pstate = OSC; osc_len = 0; } else pstate = NORMAL; }
        else if (pstate == OSC) {
            if (ch == 7 || ch == 27) { osc_buf[osc_len] = 0; handle_osc(osc_buf); pstate = ch == 27 ? ESC_SEEN : NORMAL; }
            else if (osc_len < 511) osc_buf[osc_len++] = (char)ch;
        }
        else {
            if (ch >= 0x40 && ch <= 0x7e) { csi_buf[csi_len] = 0; run_csi((char)ch); pstate = NORMAL; }
            else if (csi_len < 31) csi_buf[csi_len++] = (char)ch;
        }
    }
}
static void game_send(const char *s, int n) { if (!game_over && game_fd >= 0) (void)!write(game_fd, s, n); }
static void send_key(char k) { game_send(&k, 1); }
static void send_mouse(int button, int col, int row) {   /* a press; the game ignores releases */
    char b[48]; int n = snprintf(b, sizeof b, "\x1b[<%d;%d;%dM", button, col, row); game_send(b, n);
}
static int pumped;                                          /* bytes the game printed this frame (0 = the screen is settled) */
static void pump_game(void) {
    char buf[8192];
    pumped = 0;
    for (;;) {
        ssize_t n = read(game_fd, buf, sizeof buf);
        if (n > 0) { feed(buf, (int)n); pumped += (int)n; continue; }
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) break;
        if (!game_over) { game_over = 1; if (have_last) { memcpy(scr, last_frame, sizeof scr); mouse_on = 1; } }
        break;
    }
}
static void start_game(void) {
    struct winsize ws = { ROWS, COLS, 0, 0 };
    clear_screen(); cur_r = cur_c = 0; mouse_on = 0; game_over = 0; have_last = 0; pstate = NORMAL;
    game_pid = forkpty(&game_fd, NULL, NULL, &ws);
    if (game_pid < 0) { perror("forkpty"); exit(1); }
    if (game_pid == 0) { setenv("TERM", "xterm", 1); execl(game_path, game_path, (char *)NULL); _exit(127); }
    fcntl(game_fd, F_SETFL, fcntl(game_fd, F_GETFL) | O_NONBLOCK);
}
static void stop_game(void) {
    if (game_pid > 0) { kill(game_pid, SIGCONT); kill(game_pid, SIGTERM); waitpid(game_pid, NULL, 0); }
    if (game_fd >= 0) close(game_fd);
    game_pid = -1; game_fd = -1;
}

/* ================================================================== */
/* 1b. sound effects and music                                         */
/* ================================================================== */
/* Files are found by name: assets/sfx/<name>.wav (or .ogg/.mp3), with numbered variants
   <name>_1, <name>_2 ... picked at random; music is assets/music/<name>.ogg (or .mp3/.wav).
   A missing file is simply silent. F9 turns sound on/off, F10 music. */
static int audio_ok, snd_on = 1, mus_on = 1;

/* ---- the Options menu's settings, kept in settings.cfg ---- */
static struct {
    float master, music, sfx;            /* 0..1 */
    int ui_snd, mute_unfocused;          /* interface sounds, silence when the window is in the background */
    int fullscreen, win, scale;          /* win: window size preset 0..3, scale: 0..3 = 90/100/110/120% text */
    int shake, calm, cb;                 /* screen shake, reduce flashing, colourblind-friendly puzzles */
} set = { 1.0f, 0.8f, 0.9f, 1, 1, 0, 1, 1, 1, 0, 0 };
static const char *set_path = "settings.cfg";
static const float SCALES[4] = { 0.9f, 1.0f, 1.1f, 1.2f };
static void settings_load(void) {
    FILE *f = fopen(set_path, "r");
    if (!f) return;
    char k[32]; float v;
    while (fscanf(f, " %31[^=]=%f", k, &v) == 2) {
        float c01 = v < 0 ? 0 : v > 1 ? 1 : v; int i = (int)v;
        if (!strcmp(k, "master")) set.master = c01; else if (!strcmp(k, "music")) set.music = c01; else if (!strcmp(k, "sfx")) set.sfx = c01;
        else if (!strcmp(k, "ui_sounds")) set.ui_snd = !!i; else if (!strcmp(k, "mute_unfocused")) set.mute_unfocused = !!i;
        else if (!strcmp(k, "fullscreen")) set.fullscreen = !!i; else if (!strcmp(k, "window")) set.win = i < 0 ? 0 : i > 3 ? 3 : i;
        else if (!strcmp(k, "text_scale")) set.scale = i < 0 ? 0 : i > 3 ? 3 : i;
        else if (!strcmp(k, "screen_shake")) set.shake = !!i; else if (!strcmp(k, "reduce_flashing")) set.calm = !!i;
        else if (!strcmp(k, "colourblind")) set.cb = !!i;
    }
    fclose(f);
}
static void settings_save(void) {
#ifdef RD_TEST
    return;                               /* tests never touch your settings */
#endif
    FILE *f = fopen(set_path, "w");
    if (!f) return;
    fprintf(f, "master=%.2f\nmusic=%.2f\nsfx=%.2f\nui_sounds=%d\nmute_unfocused=%d\nfullscreen=%d\nwindow=%d\ntext_scale=%d\nscreen_shake=%d\nreduce_flashing=%d\ncolourblind=%d\n",
            set.master, set.music, set.sfx, set.ui_snd, set.mute_unfocused, set.fullscreen, set.win, set.scale, set.shake, set.calm, set.cb);
    fclose(f);
}
#ifdef RD_TEST
static FILE *snd_log;
#endif
static const char *asset_path(const char *rel) {         /* the working folder first, then next to the program */
    static char p[600];
    snprintf(p, sizeof p, "%s", rel);
    if (FileExists(p)) return p;
    snprintf(p, sizeof p, "%s%s", GetApplicationDirectory(), rel);
    return FileExists(p) ? p : NULL;
}
static const char *find_audio(const char *dir, const char *name) {
    static const char *ext[] = { ".wav", ".ogg", ".mp3", ".flac" };
    char rel[160];
    for (int e = 0; e < 4; e++) {
        snprintf(rel, sizeof rel, "assets/%s/%s%s", dir, name, ext[e]);
        const char *p = asset_path(rel);
        if (p) return p;
    }
    return NULL;
}
#define VOICES 3                                           /* the same sound can overlap itself 3 times */
typedef struct { char name[32]; int nv; Sound v[8][VOICES]; double last; } Sfx;
static Sfx sfx_tab[160]; static int n_sfx;
static Sfx *sfx_get(const char *name) {                    /* loaded on first use, kept after */
    for (int i = 0; i < n_sfx; i++) if (!strcmp(sfx_tab[i].name, name)) return &sfx_tab[i];
    if (n_sfx >= 160) return NULL;
    Sfx *s = &sfx_tab[n_sfx++];
    memset(s, 0, sizeof *s); snprintf(s->name, sizeof s->name, "%s", name);
    const char *dir = name[0] == '@' ? "music" : "sfx", *base = name[0] == '@' ? name + 1 : name;  /* "@x" = a jingle in assets/music */
    for (int k = 0; k <= 8 && s->nv < 8; k++) {
        char nm[48];
        if (k == 0) snprintf(nm, sizeof nm, "%s", base); else snprintf(nm, sizeof nm, "%s_%d", base, k);
        const char *p = find_audio(dir, nm);
        if (!p) { if (k >= 1) break; continue; }
        if (!audio_ok) { s->nv++; continue; }             /* no sound card (tests): just count the files */
        Sound snd0 = LoadSound(p);
        if (!snd0.frameCount) continue;
        s->v[s->nv][0] = snd0;
        for (int j = 1; j < VOICES; j++) s->v[s->nv][j] = LoadSoundAlias(snd0);
        s->nv++;
    }
    return s;
}
static int sfx_exists(const char *name) { Sfx *s = sfx_get(name); return s && s->nv > 0; }

typedef struct { char name[32], alt[32]; float delay, vol, pitch; int cancel; } Pending;
static Pending pend[48];
static void snd_full(const char *name, const char *alt, float delay, float vol, float pitch, int cancel) {
    for (int i = 0; i < 48; i++) if (!pend[i].name[0]) {
        snprintf(pend[i].name, 32, "%s", name); snprintf(pend[i].alt, 32, "%s", alt ? alt : "");
        pend[i].delay = delay; pend[i].vol = vol; pend[i].pitch = pitch; pend[i].cancel = cancel; return;
    }
}
static void snd(const char *name) { snd_full(name, NULL, 0, 1, 1, 0); }
static void snd_at(const char *name, float delay) { snd_full(name, NULL, delay, 1, 1, 0); }
static void snd_or(const char *name, const char *alt) { snd_full(name, alt, 0, 1, 1, 0); }   /* plays alt if name has no file */
static void snd_cancel_world(void) { for (int i = 0; i < 48; i++) if (pend[i].cancel) pend[i].name[0] = 0; }
static void snd_fire(Pending *p) {
    const char *name = p->name;
    if (p->alt[0] && !sfx_exists(name)) name = p->alt;
    Sfx *s = sfx_get(name);
    if (!s) return;
    double now = GetTime();
    if (now - s->last < 0.05) return;                      /* the same sound twice in one instant = once */
    s->last = now;
#ifdef RD_TEST
    if (snd_log) { fprintf(snd_log, "%.2f sfx %s\n", now, name); fflush(snd_log); }
#endif
    if (!audio_ok || !snd_on || !s->nv) return;
    if (!set.ui_snd && (!strncmp(name, "ui_", 3) || !strcmp(name, "menu_start"))) return;
    int vi = GetRandomValue(0, s->nv - 1);
    Sound *pick = &s->v[vi][0];
    for (int j = 0; j < VOICES; j++) if (!IsSoundPlaying(s->v[vi][j])) { pick = &s->v[vi][j]; break; }
    SetSoundVolume(*pick, p->vol * set.sfx); SetSoundPitch(*pick, p->pitch);
    PlaySound(*pick);
}
static void options_set_open(int open);
static void snd_stop(const char *name) {
    Sfx *s = sfx_get(name);
    if (s && audio_ok) for (int i = 0; i < s->nv; i++) for (int j = 0; j < VOICES; j++) StopSound(s->v[i][j]);
}
static void snd_update(float dt) {
    for (int i = 0; i < 48; i++) if (pend[i].name[0]) {
        pend[i].delay -= dt;
        if (pend[i].delay <= 0) { snd_fire(&pend[i]); pend[i].name[0] = 0; }
    }
}

/* music: one track at a time, faded out and in */
static Music mus; static int mus_loaded, mus_loop; static char mus_name[32], mus_want[32];
static float mus_vol;
static int jingle(const char *n) { return !strcmp(n, "victory") || !strcmp(n, "game_over"); }
static void music_want(const char *choices) {             /* "boss_ymir|boss_generic|explore": the first that exists */
    char buf[160]; snprintf(buf, sizeof buf, "%s", choices);
    static char cache_n[48][32]; static int cache_ok[48], n_cache;
    for (char *tok = strtok(buf, "|"); tok; tok = strtok(NULL, "|")) {
        int ok = -1;
        for (int i = 0; i < n_cache; i++) if (!strcmp(cache_n[i], tok)) ok = cache_ok[i];
        if (ok < 0) { ok = find_audio("music", tok) != NULL; if (n_cache < 48) { snprintf(cache_n[n_cache], 32, "%s", tok); cache_ok[n_cache++] = ok; } }
        if (ok) { snprintf(mus_want, sizeof mus_want, "%s", tok); return; }
    }
    mus_want[0] = 0;                                       /* none of them: silence */
}
static void music_update(float dt) {
    if (strcmp(mus_name, mus_want)) {                      /* a different track is wanted: fade the old one out */
        if (mus_loaded) {
            mus_vol -= dt / 0.9f;
            if (mus_vol <= 0) { StopMusicStream(mus); UnloadMusicStream(mus); mus_loaded = 0; }
        }
        if (!mus_loaded) {
            snprintf(mus_name, sizeof mus_name, "%s", mus_want);
#ifdef RD_TEST
            if (snd_log) { fprintf(snd_log, "%.2f music %s\n", GetTime(), mus_name[0] ? mus_name : "(silence)"); fflush(snd_log); }
#endif
            const char *p = mus_name[0] && audio_ok ? find_audio("music", mus_name) : NULL;
            if (p) {
                mus = LoadMusicStream(p);
                if (mus.frameCount) { mus_loop = !jingle(mus_name); mus.looping = mus_loop; PlayMusicStream(mus); mus_loaded = 1; mus_vol = mus_loop ? 0 : 1; }
            }
        }
    } else if (mus_loaded && mus_vol < 1) { mus_vol += dt / 1.2f; if (mus_vol > 1) mus_vol = 1; }
    if (mus_loaded) { SetMusicVolume(mus, mus_on ? mus_vol * 0.7f * set.music : 0); UpdateMusicStream(mus); }
}
static void audio_init(void) {
    InitAudioDevice();
    audio_ok = IsAudioDeviceReady();
#ifdef RD_TEST
    const char *lp = getenv("RD_SNDLOG"); if (lp) snd_log = fopen(lp, "w");
#endif
}

/* icons over heads, from the game's notes */
static struct { int parry, rally, surge, man; } fst;
typedef struct { int alive, x, y, w, h, bits; } EnemyHead;
static EnemyHead nst[6];
static void snd(const char *name);
/* the path / spell-area preview, as the game describes it (grid coordinates) */
static int pv_kind;                        /* 0 none, 1 walking path, 2 spell area */
static char pv_path[100];                  /* numpad digits, one per step from the player */
static int pv_ax, pv_ay, pv_aw, pv_ah, pv_valid; static unsigned char pv_bits[700];
static void handle_osc(const char *t) {
    if (strncmp(t, "77;", 3)) return;
    t += 3;
    if (t[0] == 'C') pv_kind = 0;
    else if (t[0] == 'P') { snprintf(pv_path, sizeof pv_path, "%s", t + 1); pv_kind = 1; }
    else if (t[0] == 'A') {
        int v = 0, x0 = 0, y0 = 0, w = 0, h = 0, n = 0;
        int got = sscanf(t + 1, "%d,%d,%d,%d,%d,%n", &v, &x0, &y0, &w, &h, &n);
        pv_valid = v; pv_kind = 2; pv_aw = pv_ah = 0;
        if (got == 5 && w > 0 && h > 0 && w * h <= 700) {
            pv_ax = x0; pv_ay = y0; pv_aw = w; pv_ah = h;
            const char *hx = t + 1 + n;
            for (int i = 0; i < w * h; i++) {
                int d = i / 4 < (int)strlen(hx) ? hx[i / 4] : '0';
                d = d >= 'a' ? d - 'a' + 10 : d - '0';
                pv_bits[i] = (d >> (3 - i % 4)) & 1;
            }
        }
    }
    else if (t[0] == 'S' || t[0] == 'E' || t[0] == 'B') handle_osc_fx(t);
    else if (t[0] == 'F') {                               /* the fighter: parry, rally HP, surge on, maneuver ready */
        int a = 0, b = 0, c = 0, d = 0; sscanf(t + 1, "%d,%d,%d,%d", &a, &b, &c, &d);
        if (a && !fst.parry) snd("parry_ready");
        if (b > fst.rally) snd("rally");
        if (c && !fst.surge) snd("action_surge");
        if (d && d != fst.man) snd("maneuver_ready");
        fst.parry = a; fst.rally = b; fst.surge = c; fst.man = d;
    } else if (t[0] == 'N') {                             /* every enemy: where it is and what ails it */
        memset(nst, 0, sizeof nst);
        const char *p = t + 1;
        while (*p) {
            int i, x, y, w, h, bits, n = 0;
            if (sscanf(p, "%d:%d:%d:%d:%d:%d;%n", &i, &x, &y, &w, &h, &bits, &n) < 6 || !n) break;
            if (i >= 0 && i < 6) nst[i] = (EnemyHead){ 1, x, y, w, h, bits };
            p += n;
        }
    }
}

/* ================================================================== */
/* 2. reading the game state off the screen                            */
/* ================================================================== */
/* where the assembly prints things (0-based row/column) */
#define MAP_R0 5          /* map rows 5..19 (walls included), columns 0..52 */
#define MAP_W 53
#define MAP_H 15
#define PANEL_C 55        /* enemy list rows 1..4, spell/bag list rows 6..18 */

typedef struct { int present; char letter; int hp, hpmax; char st[12]; float flash; } Enemy;
typedef struct { int present; char key; char name[20]; int cost, armed, worn, rarity; } Slot;
static struct {
    int in_game, hp, hpmax, floor, ac, stat[4], move, mana, manamax, dice, dicemax, hasted, hidden, mode, tb_on, bag;
    int level, xp, xpnext, points;
    char cls[16], weapon[24], next_man[24], msg[120], help[2][80];
    Enemy en[6]; Slot slot[13];
} S;
enum { M_EXPLORE, M_TB_YOU, M_TB_OTHERS, M_FIGHT_YOU, M_FIGHT_ENEMY };

static int xp_gain; static float xp_gain_t;   /* the "+25 XP" that floats up */
static char log_txt[60][120];
static int log_n;
static float hurt_t;
static int log_scroll; static float wheel;                /* the log: lines scrolled back, this frame's mouse wheel */
static int chosen_class;                  /* remembered from the class screen */
static char gate_txt[240];
static char king_riddle[3][80];           /* the throne's hidden gates, one riddle each */                /* the plaque's riddle, kept for the rest of the floor */
static int gate_floor = -1;

static void row_text(int r, int c0, int c1, char *out) {           /* columns c0..c1-1, trimmed */
    int a = c0, b = c1;
    while (a < b && scr[r][a] == ' ') a++;
    while (b > a && scr[r][b - 1] == ' ') b--;
    memcpy(out, &scr[r][a], b - a); out[b - a] = 0;
}
static int screen_has(const char *s) {
    char line[COLS + 1];
    for (int r = 0; r < ROWS; r++) { memcpy(line, scr[r], COLS); line[COLS] = 0; if (strstr(line, s)) return 1; }
    return 0;
}
static int find_int(const char *line, const char *key, int *v) {
    const char *p = strstr(line, key); return p && sscanf(p + strlen(key), "%d", v) == 1;
}
static int map_shown(void) {
    return mouse_on && scr[MAP_R0][0] == '#' && scr[MAP_R0 + MAP_H - 1][0] == '#' && scr[MAP_R0][MAP_W - 1] == '#';
}

static void fx_from_msg(const char *m);
static void parse_state(void) {
    char t[COLS + 1];
    int prev_hp = S.hp, prev_floor = S.floor;
    S.in_game = map_shown();
    if (!S.in_game) return;
    row_text(0, 0, 34, t);
    find_int(t, "AC:", &S.ac);
    char *w = strstr(t, "Weapon:"); snprintf(S.weapon, sizeof S.weapon, "%s", w ? w + 8 : "");
    {   /* "Lv:5* XP:310/450" (the * = a stat point is waiting) */
        int prev_xp = S.xp, prev_lv = S.level;
        row_text(0, 35, 54, t);
        S.level = 0; S.xp = 0; S.xpnext = 0;
        find_int(t, "Lv:", &S.level);
        S.points = strchr(t, '*') != NULL;
        char *x = strstr(t, "XP:"); if (x) { if (sscanf(x + 3, "%d/%d", &S.xp, &S.xpnext) < 2) S.xpnext = 0; }
        if (S.xp > prev_xp && prev_lv > 0 && S.level >= prev_lv) { xp_gain = S.xp - prev_xp; xp_gain_t = 1.6f; }
    }
    row_text(2, 0, 54, t);
    sscanf(t, "%15s", S.cls);
    { char *h = strstr(t, "HP:"); if (h) sscanf(h + 3, "%d/%d", &S.hp, &S.hpmax); }
    find_int(t, "Floor:", &S.floor);
    row_text(3, 0, 54, t);
    find_int(t, "STR:", &S.stat[0]); find_int(t, "DEX:", &S.stat[1]); find_int(t, "CON:", &S.stat[2]); find_int(t, "Int:", &S.stat[3]);
    row_text(20, 0, 54, t);
    S.move = -1; find_int(t, "Movement:", &S.move);
    S.mana = S.manamax = -1; { char *m = strstr(t, "Mana:"); if (m) sscanf(m + 5, "%d/%d", &S.mana, &S.manamax); }
    S.dice = S.dicemax = -1; { char *d = strstr(t, "Dice:"); if (d) sscanf(d + 5, "%d/%d", &S.dice, &S.dicemax); }
    S.next_man[0] = 0; { char *n = strstr(t, "Next:"); if (n) { n += 5; while (*n == ' ') n++; if (*n != '-') snprintf(S.next_man, sizeof S.next_man, "%s", n); } }
    S.hasted = strstr(t, "HASTED") != NULL; S.hidden = strstr(t, "HIDDEN") != NULL;
    row_text(22, 0, COLS, t);
    S.tb_on = strstr(t, "Turn-based: ON") != NULL;
    S.mode = strstr(t, "COMBAT - your") ? M_FIGHT_YOU : strstr(t, "COMBAT - enemy") ? M_FIGHT_ENEMY :
             strstr(t, "Turn-based - your") ? M_TB_YOU : strstr(t, "Turn-based - others") ? M_TB_OTHERS : M_EXPLORE;
    row_text(23, 0, COLS, S.msg);
    row_text(21, 0, 54, S.help[0]); row_text(24, 0, COLS, S.help[1]);
    /* enemies */
    if (S.floor != prev_floor) for (int i = 0; i < 6; i++) S.en[i].present = 0;
    for (int i = 0; i < 6; i++) {                      /* two columns: enemy i on row 1 + i/2 */
        Enemy *e = &S.en[i];
        int er = 1 + i / 2, ec = PANEL_C + (i & 1) * 12;   /* "G1  15 zb": two per row, 12 columns each */
        char *row = scr[er] + ec;
        char hb[4] = { row[3], row[4], row[5], 0 };
        int hp = atoi(hb), ok = isalpha((unsigned char)row[0]) && isdigit((unsigned char)row[1]) && isdigit((unsigned char)row[5]);
        if (!ok) { e->present = 0; continue; }
        if (!e->present || e->letter != row[0]) e->hpmax = hp;
        else if (hp < e->hp) e->flash = 0.5f;
        if (hp > e->hpmax) e->hpmax = hp;
        e->present = 1; e->letter = row[0]; e->hp = hp;
        row_text(er, ec + 7, ec + 12, e->st);
    }
    /* the spell list or the bag */
    row_text(5, PANEL_C, COLS, t);
    S.bag = strncmp(t, "BAG", 3) == 0;
    for (int i = 0; i < 13; i++) {
        Slot *s = &S.slot[i]; char *row = scr[6 + i] + PANEL_C;
        memset(s, 0, sizeof *s);
        if (S.bag) {
            if (row[0] != '[' || row[2] != ']') continue;
            s->key = row[1];
            row_text(6 + i, PANEL_C + 4, PANEL_C + 20, s->name);
            s->present = s->name[0] != 0;                     /* "[3]" with no name = an empty slot */
            s->worn = row[21] == '*';
            s->rarity = row[20] == '+' ? 1 : row[20] == '#' ? 2 : 0;
        } else {
            if (row[1] != '[' || row[3] != ']') continue;
            s->present = 1; s->key = row[2]; s->armed = row[0] == '>';
            row_text(6 + i, PANEL_C + 5, PANEL_C + 19, s->name);
            s->cost = atoi(row + 20);
        }
    }
    /* the plaque: "XOR - one and none, but not all. (light one pair)" */
    {
        const char *g[] = { "AND - ", "OR - ", "XOR - ", "NAND - ", "NOR - ", "XNOR - ", "CIRCUIT - ", "WARDEN - ", "LANTERN - ", "POWER - ", "THRONE - " };
        for (int i = 0; i < 11; i++) if (!strncmp(S.msg, g[i], strlen(g[i]))) { snprintf(gate_txt, sizeof gate_txt, "%s", S.msg); gate_floor = S.floor; }
        int kn;
        if (sscanf(S.msg, "THRONE - gate %d:", &kn) == 1 && kn >= 1 && kn <= 3) {   /* keep every riddle read so far */
            const char *rt = strchr(S.msg, ':');
            snprintf(king_riddle[kn - 1], 80, "%s", rt ? rt + 2 : "");
            int n = snprintf(gate_txt, sizeof gate_txt, "THRONE - ");
            for (int k = 0; k < 3; k++) if (king_riddle[k][0]) n += snprintf(gate_txt + n, sizeof gate_txt - n, "%d: %s  ", k + 1, king_riddle[k]);
        }
        if (strstr(S.msg, "slams his throne")) memset(king_riddle, 0, sizeof king_riddle);
    }
    /* message log + getting hurt */
    /* (the log itself is filled from the message queue in snd_watch: every line, even two printed at once) */
    if (prev_hp > 0 && S.hp < prev_hp && S.floor == prev_floor) hurt_t = 0.6f;
}

/* ================================================================== */
/* 3. look and feel                                                    */
/* ================================================================== */
#define W 1720             /* the layout is drawn on a 1720x880 canvas, scaled to fit the window */
#define H 880
#define TS 32              /* map tile */
#define MAP_X 12
#define MAP_Y 82

/* Stone & Iron: cold grey-blue stone, iron, bronze trim, bone-white text, torch-orange highlights */
static const Color C_BG = { 13, 14, 17, 255 }, C_CARD = { 36, 39, 45, 255 }, C_CARD2 = { 48, 52, 59, 255 },
    C_LINE = { 82, 86, 94, 255 }, C_TEXT = { 234, 226, 208, 255 }, C_DIM = { 150, 145, 132, 255 },
    C_GOLD = { 240, 192, 96, 255 }, C_RED = { 214, 66, 58, 255 }, C_GREEN = { 120, 196, 110, 255 },
    C_BLUE = { 96, 146, 230, 255 }, C_PURPLE = { 168, 120, 232, 255 }, C_AMBER = { 240, 140, 52, 255 };
static const Color C_BRONZE = { 166, 116, 62, 255 }, C_IRON = { 104, 108, 116, 255 }, C_HI = { 78, 83, 92, 255 }, C_SH = { 16, 17, 20, 255 },
    C_PARCH = { 222, 204, 160, 255 }, C_INK = { 54, 38, 22, 255 };

static Font F, FB;
static float T;
static Vector2 mouse;              /* in canvas coordinates */
static int click, rclick;          /* this frame */

#define TS_(size) ((size) <= 30 ? (size) * SCALES[set.scale] : (size))   /* the Options menu's text size (big titles stay put) */
static void txt(const char *s, float x, float y, float size, Color c) { DrawTextEx(F, s, (Vector2){ x, y - (TS_(size) - size) * 0.5f }, TS_(size), 0, c); }
static void txtb(const char *s, float x, float y, float size, Color c) { DrawTextEx(FB, s, (Vector2){ x, y - (TS_(size) - size) * 0.5f }, TS_(size), 0, c); }
static float tw(const char *s, float size) { return MeasureTextEx(F, s, TS_(size), 0).x; }
static float twb(const char *s, float size) { return MeasureTextEx(FB, s, TS_(size), 0).x; }
static void txt_c(const char *s, float cx, float y, float size, Color c, int bold) {
    float w = bold ? twb(s, size) : tw(s, size);
    if (bold) txtb(s, cx - w / 2, y, size, c); else txt(s, cx - w / 2, y, size, c);
}
static int hover(Rectangle r) { return CheckCollisionPointRec(mouse, r); }
static void bevel(Rectangle r, float th, Color hi, Color sh) {   /* chiselled edge: light top-left, dark bottom-right */
    float n = fminf(6.0f, fminf(r.width, r.height) * 0.25f);
    DrawLineEx((Vector2){ r.x + n, r.y + th / 2 }, (Vector2){ r.x + r.width - n, r.y + th / 2 }, th, hi);
    DrawLineEx((Vector2){ r.x + th / 2, r.y + n }, (Vector2){ r.x + th / 2, r.y + r.height - n }, th, hi);
    DrawLineEx((Vector2){ r.x + n, r.y + r.height - th / 2 }, (Vector2){ r.x + r.width - n, r.y + r.height - th / 2 }, th, sh);
    DrawLineEx((Vector2){ r.x + r.width - th / 2, r.y + n }, (Vector2){ r.x + r.width - th / 2, r.y + r.height - n }, th, sh);
}
static void rivet(float x, float y) {
    DrawCircle((int)x, (int)y + 1, 3.5f, C_SH);
    DrawCircle((int)x, (int)y, 3.5f, C_IRON);
    DrawCircle((int)x - 1, (int)y - 1, 1.3f, (Color){ 170, 174, 180, 255 });
}
static void stone_specks(Rectangle r, int seed) {          /* a little grit in the stone */
    for (int i = 0; i < (int)(r.width * r.height / 2600); i++) {
        unsigned int x = (unsigned int)(i * 2654435761u + seed * 97u); x ^= x >> 13; x *= 0x5bd1e995; x ^= x >> 15;
        float px = r.x + 6 + (x % 1000) / 1000.0f * (r.width - 12), py = r.y + 6 + ((x >> 10) % 1000) / 1000.0f * (r.height - 12);
        DrawRectangle((int)px, (int)py, 2, 2, Fade(BLACK, 0.18f));
    }
}
static void card(Rectangle r) {
    DrawRectangleRounded((Rectangle){ r.x + 4, r.y + 6, r.width, r.height }, 0, 0, Fade(BLACK, 0.5f));
    DrawRectangleRounded(r, 0, 0, C_CARD);
    stone_specks(r, (int)(r.x + r.y));
    bevel((Rectangle){ r.x + 2, r.y + 2, r.width - 4, r.height - 4 }, 2, C_HI, C_SH);
    DrawRectangleRoundedLinesEx(r, 0, 0, 2, (Color){ 22, 23, 27, 255 });
    rivet(r.x + 10, r.y + 10); rivet(r.x + r.width - 10, r.y + 10);
    rivet(r.x + 10, r.y + r.height - 10); rivet(r.x + r.width - 10, r.y + r.height - 10);
}
static void card_title(const char *s, float x, float y) {   /* an engraved bronze plaque */
    float w = twb(s, 15) + 22;
    Rectangle p = { x - 4, y - 4, w, 24 };
    DrawRectangleRounded(p, 0, 0, (Color){ 70, 50, 30, 255 });
    bevel(p, 1, (Color){ 196, 146, 84, 255 }, (Color){ 40, 26, 14, 255 });
    DrawRectangleRoundedLinesEx(p, 0, 0, 1, (Color){ 30, 20, 10, 255 });
    txtb(s, x + 7, y + 1, 15, (Color){ 24, 16, 8, 255 });
    txtb(s, x + 7, y, 15, (Color){ 240, 200, 140, 255 });
}
static int hover_key;                                      /* which button the mouse is over this frame */
static void ui_hovered(Rectangle r) { hover_key = (int)(r.x * 7 + r.y * 13 + r.width * 3 + 1); }
static int button(Rectangle r, const char *label, Color accent, int enabled) {   /* a stone tablet that presses in */
    int h = enabled && hover(r), down = h && IsMouseButtonDown(MOUSE_BUTTON_LEFT);
    if (h) ui_hovered(r);
    if (h && click) snd("ui_click");
    Rectangle b = down ? (Rectangle){ r.x + 1, r.y + 2, r.width, r.height } : r;
    if (!down) DrawRectangleRounded((Rectangle){ r.x + 2, r.y + 3, r.width, r.height }, 0, 0, Fade(BLACK, 0.5f));
    DrawRectangleRounded(b, 0, 0, h ? (Color){ 64, 66, 72, 255 } : C_CARD2);
    if (h) DrawRectangleRounded(b, 0, 0, Fade(accent, 0.18f));
    if (down) bevel(b, 2, C_SH, C_HI); else bevel(b, 2, C_HI, C_SH);
    DrawRectangleRoundedLinesEx(b, 0, 0, 1, enabled ? (h ? accent : C_BRONZE) : Fade(C_LINE, 0.5f));
    float fs = 18;
    while (fs > 11 && twb(label, fs) > b.width - 14) fs -= 1;      /* bigger text settings: shrink to fit the tablet */
    txt_c(label, b.x + b.width / 2, b.y + b.height / 2 - 9, fs, enabled ? C_TEXT : C_DIM, 1);
    return h && click;
}
static void keycap(const char *k, float x, float y) {        /* a square iron tag */
    float w = tw(k, 14) + 12;
    DrawRectangleRec((Rectangle){ x, y + 2, w, 20 }, C_SH);
    DrawRectangleRec((Rectangle){ x, y, w, 19 }, C_IRON);
    DrawRectangleLinesEx((Rectangle){ x, y, w, 19 }, 1, (Color){ 140, 144, 150, 255 });
    txt(k, x + 6, y + 2, 14, (Color){ 20, 20, 24, 255 });
}
static void bar(Rectangle r, float frac, Color c, const char *label) {   /* a square stone trough with segments */
    frac = frac < 0 ? 0 : frac > 1 ? 1 : frac;
    DrawRectangleRec(r, (Color){ 10, 10, 12, 255 });
    if (frac > 0) {
        DrawRectangleRec((Rectangle){ r.x, r.y, r.width * frac, r.height }, c);
        DrawRectangleRec((Rectangle){ r.x, r.y, r.width * frac, r.height * 0.3f }, Fade(WHITE, 0.16f));
        DrawRectangleRec((Rectangle){ r.x, r.y + r.height * 0.75f, r.width * frac, r.height * 0.25f }, Fade(BLACK, 0.22f));
    }
    if (r.height >= 10) for (int i = 1; i < 10; i++) DrawRectangleRec((Rectangle){ r.x + r.width * i / 10 - 1, r.y, 2, r.height }, Fade(BLACK, 0.45f));
    bevel(r, 2, C_SH, C_HI);
    DrawRectangleLinesEx(r, 1, Fade(C_BRONZE, 0.7f));
    if (label) { txt_c(label, r.x + r.width / 2 + 1, r.y + r.height / 2 - 7, 16, BLACK, 1); txt_c(label, r.x + r.width / 2, r.y + r.height / 2 - 8, 16, WHITE, 1); }
}
static Color hp_color(float f) { return f > 0.3f ? (Color){ 168, 30, 34, 255 } : (Color){ 220, 50, 40, 255 }; }   /* blood red (brighter when low) */

/* ---------------- pixel sprites ---------------- */
static Color pal(char c) {
    switch (c) {
    case 'k': return (Color){ 20, 20, 28, 255 }; case 's': return (Color){ 232, 184, 144, 255 }; case 'S': return (Color){ 190, 136, 100, 255 };
    case 'm': return (Color){ 204, 210, 222, 255 }; case 'M': return (Color){ 120, 126, 142, 255 }; case 'r': return (Color){ 196, 44, 44, 255 };
    case 'R': return (Color){ 120, 22, 32, 255 }; case 'b': return (Color){ 62, 112, 224, 255 }; case 'B': return (Color){ 30, 56, 140, 255 };
    case 'g': return (Color){ 84, 176, 72, 255 }; case 'G': return (Color){ 40, 96, 48, 255 }; case 'y': return (Color){ 244, 204, 64, 255 };
    case 'Y': return (Color){ 172, 122, 30, 255 }; case 'w': return (Color){ 244, 244, 240, 255 }; case 'W': return (Color){ 224, 218, 192, 255 };
    case 'n': return (Color){ 136, 88, 46, 255 }; case 'N': return (Color){ 82, 52, 26, 255 }; case 'p': return (Color){ 146, 84, 210, 255 };
    case 'P': return (Color){ 82, 42, 134, 255 }; case 'c': return (Color){ 124, 226, 255, 255 }; case 'e': return (Color){ 112, 112, 124, 255 };
    case 'E': return (Color){ 60, 60, 72, 255 }; case 'l': return (Color){ 152, 102, 62, 255 }; case 'h': return (Color){ 48, 52, 64, 255 };
    case 'H': return (Color){ 78, 84, 100, 255 }; case 'v': return (Color){ 112, 142, 62, 255 }; case 'V': return (Color){ 70, 92, 36, 255 };
    case 'o': return (Color){ 244, 140, 48, 255 }; case 'O': return (Color){ 176, 72, 24, 255 }; case 'i': return (Color){ 214, 242, 255, 255 };
    case 'I': return (Color){ 112, 176, 228, 255 }; case 'q': return (Color){ 156, 150, 134, 255 }; case 'Q': return (Color){ 98, 92, 82, 255 };
    case 'u': return (Color){ 206, 146, 66, 255 }; case 'U': return (Color){ 126, 80, 36, 255 }; case 't': return (Color){ 84, 236, 204, 255 };
    case 'T': return (Color){ 26, 124, 112, 255 }; case 'x': return (Color){ 150, 206, 255, 255 }; case 'X': return (Color){ 52, 96, 170, 255 };
    default: return BLANK;
    }
}
static void sprite(const char **rows, int h, float x, float y, float sc, Color tint, int mirror) {
    int w = (int)strlen(rows[0]);
    for (int r = 0; r < h; r++) for (int c = 0; c < w * (mirror ? 2 : 1); c++) {
        char ch = c < w ? rows[r][c] : rows[r][2 * w - 1 - c];
        if (ch == '.') continue;
        Color col = pal(ch);
        col.r = (unsigned char)(col.r * tint.r / 255); col.g = (unsigned char)(col.g * tint.g / 255);
        col.b = (unsigned char)(col.b * tint.b / 255); col.a = (unsigned char)(col.a * tint.a / 255);
        DrawRectangleRec((Rectangle){ x + c * sc, y + r * sc, sc + 0.02f, sc + 0.02f }, col);
    }
}
static void sprite_flip(const char **rows, int h, float x, float y, float sc, Color tint) {   /* facing the other way */
    int w = (int)strlen(rows[0]);
    for (int r = 0; r < h; r++) for (int c = 0; c < w; c++) {
        char ch = rows[r][c];
        if (ch == '.') continue;
        Color col = pal(ch);
        col.r = (unsigned char)(col.r * tint.r / 255); col.g = (unsigned char)(col.g * tint.g / 255);
        col.b = (unsigned char)(col.b * tint.b / 255); col.a = (unsigned char)(col.a * tint.a / 255);
        DrawRectangleRec((Rectangle){ x + (w - 1 - c) * sc, y + r * sc, sc + 0.02f, sc + 0.02f }, col);
    }
}
static const char **class_sprite(void) {
    int c = chosen_class;
    if (!strcmp(S.cls, "FIGHTER")) c = 1; else if (!strcmp(S.cls, "ROGUE")) c = 2; else if (!strcmp(S.cls, "WIZARD")) c = 3;
    return c == 2 ? SPR_ROGUE : c == 3 ? SPR_WIZARD : SPR_FIGHTER;
}
static const char **enemy_sprite(char l) { return l == 'S' ? SPR_SKELETON : l == 'O' ? SPR_ORC : SPR_GOBLIN; }
static const char *enemy_name(char l) {
    return l == 'G' ? "Goblin" : l == 'S' ? "Skeleton" : l == 'O' ? "Orc" : l == 'M' ? "Warden" : l == 'K' ? "Forgotten King" : l == 'D' ? "Dark Shade" :
           l == 'Y' ? "Grand Wizard Ymir" : (l == 'J' || l == 'j') ? "Logic Keeper" : (l == 'T' || l == 't') ? "Altair" : (l == 'U' || l == 'u') ? "Smo" : l == 'Z' ? "Forgotten King, Unbound" : l == 'P' ? "Bishop" : "Enemy";
}
static const ItemInfo *item_info(const char *n) {
    for (int i = 0; i < ITEM_INFO_N; i++) if (!strcmp(ITEM_INFO[i].name, n)) return &ITEM_INFO[i];
    return NULL;
}
static const char **icon_sprite(const char *ic) {
    static const struct { const char *n; const char **spr; } T2[] = {
        { "staff", SPR_I_STAFF }, { "dagger", SPR_I_DAGGER }, { "bow", SPR_I_BOW }, { "maul", SPR_I_MAUL },
        { "halberd", SPR_I_HALBERD }, { "spear", SPR_I_SPEAR }, { "greatsword", SPR_I_GREATSWORD }, { "shield", SPR_I_SHIELD },
        { "robe", SPR_I_ROBE }, { "helm", SPR_I_HELM }, { "hood", SPR_I_HOOD }, { "boots", SPR_I_BOOTS },
        { "ring", SPR_I_RING }, { "amulet", SPR_I_AMULET }, { "armor", SPR_ARMOR } };
    for (unsigned i = 0; i < sizeof T2 / sizeof T2[0]; i++) if (!strcmp(ic, T2[i].n)) return T2[i].spr;
    return SPR_SWORD;
}
static const char **item_sprite(const char *n) {
    const ItemInfo *ii = item_info(n);
    if (ii) return icon_sprite(ii->icon);
    if (strstr(n, "staff") || strstr(n, "Staff")) return SPR_I_STAFF;
    if (strstr(n, "Dagger")) return SPR_I_DAGGER;
    if (strstr(n, "bow") || strstr(n, "Crossbow")) return SPR_I_BOW;
    if (strstr(n, "Robe")) return SPR_I_ROBE;
    if (strstr(n, "Buckler") || strstr(n, "Shield")) return SPR_I_SHIELD;
    if (strstr(n, "Pike")) return SPR_I_SPEAR;
    if (strstr(n, "Greatsword")) return SPR_I_GREATSWORD;
    if (strstr(n, "Potion")) return SPR_POTION;
    if (strstr(n, "Robe") || strstr(n, "Armor") || strstr(n, "plate") || strstr(n, "Buckler") || strstr(n, "Shield")) return SPR_ARMOR;
    return SPR_SWORD;
}
static float rnd(int i) { unsigned int x = (unsigned int)i * 2654435761u; x ^= x >> 13; x *= 0x5bd1e995; x ^= x >> 15; return (x & 0xffff) / 65535.0f; }

static void flame(float cx, float by, float sz, float t) {
    float f = 1 + 0.12f * sinf(t * 17) + 0.08f * sinf(t * 29);
    DrawCircleGradient((int)cx, (int)(by - sz * 0.6f), sz * 2.4f, Fade((Color){ 255, 160, 50, 255 }, 0.22f), BLANK);
    DrawTriangle((Vector2){ cx, by - sz * 1.6f * f }, (Vector2){ cx - sz * 0.7f, by }, (Vector2){ cx + sz * 0.7f, by }, (Color){ 236, 96, 26, 255 });
    DrawTriangle((Vector2){ cx + sinf(t * 11) * 1.5f, by - sz * 1.15f * f }, (Vector2){ cx - sz * 0.45f, by }, (Vector2){ cx + sz * 0.45f, by }, (Color){ 255, 186, 56, 255 });
    DrawTriangle((Vector2){ cx, by - sz * 0.6f * f }, (Vector2){ cx - sz * 0.2f, by }, (Vector2){ cx + sz * 0.2f, by }, (Color){ 255, 246, 190, 255 });
}
static void status_icon(char letter, float x, float y, float s) {
    int k = letter == 'z' ? 0 : letter == 'H' ? 1 : letter == 'B' ? 2 : letter == 'b' ? 3 : letter == 'p' ? 4 : letter == 's' ? 5 : letter == 'v' ? 6 : letter == 'f' ? 7 : -1;
    if (k < 0) return;
    Color bg[] = { {90,70,170,255},{150,80,190,255},{40,40,50,255},{220,90,30,255},{70,150,60,255},{60,130,200,255},{120,100,80,255},{170,40,40,255} };
    DrawRectangleRounded((Rectangle){ x, y, s, s }, 0.3f, 6, bg[k]);
    float cx = x + s / 2, cy = y + s / 2;
    switch (k) {
    case 0: txtb("z", x + s * 0.2f, y + s * 0.3f, s * 0.6f, WHITE); txtb("Z", x + s * 0.48f, y + s * 0.02f, s * 0.6f, WHITE); break;
    case 1: DrawRing((Vector2){ cx - s * 0.13f, cy }, s * 0.13f, s * 0.21f, 0, 360, 16, WHITE); DrawRing((Vector2){ cx + s * 0.13f, cy }, s * 0.13f, s * 0.21f, 0, 360, 16, WHITE); break;
    case 2: DrawEllipse((int)cx, (int)cy, s * 0.32f, s * 0.19f, WHITE); DrawCircle((int)cx, (int)cy, s * 0.1f, BLACK);
            DrawLineEx((Vector2){ x + s * 0.2f, y + s * 0.8f }, (Vector2){ x + s * 0.8f, y + s * 0.2f }, s * 0.09f, C_RED); break;
    case 3: flame(cx, y + s * 0.82f, s * 0.3f, T); break;
    case 4: DrawCircle((int)cx, (int)(cy + s * 0.08f), s * 0.22f, (Color){ 190, 255, 120, 255 });
            DrawTriangle((Vector2){ cx, y + s * 0.16f }, (Vector2){ cx - s * 0.2f, cy + s * 0.05f }, (Vector2){ cx + s * 0.2f, cy + s * 0.05f }, (Color){ 190, 255, 120, 255 }); break;
    case 5: DrawTriangle((Vector2){ x + s * 0.27f, y + s * 0.2f }, (Vector2){ cx, cy }, (Vector2){ x + s * 0.73f, y + s * 0.2f }, WHITE);
            DrawTriangle((Vector2){ cx, cy }, (Vector2){ x + s * 0.27f, y + s * 0.8f }, (Vector2){ x + s * 0.73f, y + s * 0.8f }, WHITE); break;
    case 6: DrawTriangle((Vector2){ x + s * 0.22f, cy }, (Vector2){ cx, y + s * 0.82f }, (Vector2){ x + s * 0.78f, cy }, WHITE);
            DrawRectangleRec((Rectangle){ cx - s * 0.09f, y + s * 0.18f, s * 0.18f, s * 0.33f }, WHITE); break;
    case 7: DrawRectangleRec((Rectangle){ cx - s * 0.08f, y + s * 0.15f, s * 0.16f, s * 0.44f }, WHITE); DrawCircle((int)cx, (int)(y + s * 0.78f), s * 0.09f, WHITE); break;
    }
}
static const char *status_name(char l) {
    return l == 'z' ? "Asleep" : l == 'H' ? "Held" : l == 'B' ? "Blind" : l == 'b' ? "Burning" : l == 'p' ? "Poisoned" : l == 's' ? "Slowed" : l == 'v' ? "Prone" : l == 'f' ? "Frightened" : "";
}
static Color spell_color(const char *n) {
    if (strstr(n, "Fire") || strstr(n, "Scorch")) return (Color){ 255, 128, 48, 255 };
    if (strstr(n, "Frost") || strstr(n, "Ice") || strstr(n, "Cold")) return (Color){ 120, 210, 255, 255 };
    if (strstr(n, "Sunbeam") || strstr(n, "Haste")) return (Color){ 255, 222, 100, 255 };
    if (strstr(n, "Vampiric")) return (Color){ 220, 50, 70, 255 };
    if (strstr(n, "Misty")) return (Color){ 200, 210, 230, 255 };
    return C_PURPLE;
}

/* ================================================================== */
/* 4. the map                                                          */
/* ================================================================== */
static char mc(int c, int r) { return (c < 0 || c >= MAP_W || r < 0 || r >= MAP_H) ? ' ' : scr[MAP_R0 + r][c]; }
static Rectangle tile(int c, int r) { return (Rectangle){ MAP_X + c * TS, MAP_Y + r * TS, TS, TS }; }

static void floor_tile(float x, float y, int i) {
    DrawRectangleRec((Rectangle){ x, y, TS, TS }, (i & 1) ? (Color){ 52, 54, 64, 255 } : (Color){ 47, 49, 58, 255 });
    DrawRectangleRec((Rectangle){ x, y, TS, 1 }, Fade(WHITE, 0.035f));
    if (rnd(i * 7) > 0.65f) DrawRectangleRec((Rectangle){ x + 4 + rnd(i) * (TS - 10), y + 4 + rnd(i + 3) * (TS - 10), 2, 2 }, Fade(BLACK, 0.3f));
}
static void wall_tile(float x, float y, int i) {
    DrawRectangleRec((Rectangle){ x, y, TS, TS }, (Color){ 56, 46, 38, 255 });
    int bh = TS / 4, bw = TS / 2;
    for (int r = 0; r < 4; r++) {
        int off = ((r + i) & 1) ? bw / 2 : 0;
        for (int c = -1; c < 3; c++) {
            float bx = x + c * bw + off, x0 = bx < x ? x : bx, x1 = bx + bw > x + TS ? x + TS : bx + bw;
            if (x1 - x0 <= 2) continue;
            unsigned char v = (unsigned char)(86 + 18 * rnd(i * 17 + r * 5 + c));
            DrawRectangleRec((Rectangle){ x0 + 1, y + r * bh + 1, x1 - x0 - 2, bh - 2 }, (Color){ v, (unsigned char)(v - 14), (unsigned char)(v - 28), 255 });
        }
    }
}
static void tall_door(int c, int r0, int n, int open) {
    Rectangle d = { MAP_X + c * TS + 2, MAP_Y + r0 * TS, TS - 4, n * TS };
    if (open) {
        DrawRectangleRec(d, (Color){ 6, 7, 10, 255 });
        DrawRectangleGradientH((int)d.x, (int)d.y, (int)d.width, (int)d.height, Fade((Color){ 110, 230, 120, 255 }, 0.0f), Fade((Color){ 110, 230, 120, 255 }, 0.25f));
        float cy = d.y + d.height / 2, a = 0.6f + 0.4f * sinf(T * 3);
        DrawTriangle((Vector2){ d.x + 8, cy - 9 }, (Vector2){ d.x + 8, cy + 9 }, (Vector2){ d.x + 22, cy }, Fade((Color){ 120, 240, 130, 255 }, a));
    } else {
        DrawRectangleRec(d, (Color){ 112, 72, 38, 255 });
        for (float px = d.x + 7; px < d.x + d.width; px += 7) DrawRectangleRec((Rectangle){ px, d.y, 1, d.height }, (Color){ 70, 44, 22, 255 });
        for (int b = 0; b < 3; b++) DrawRectangleRec((Rectangle){ d.x, d.y + 10 + b * (d.height - 26) / 2, d.width, 5 }, (Color){ 72, 74, 86, 255 });
        DrawCircle((int)(d.x + 6), (int)(d.y + d.height / 2), 3, C_GOLD);
    }
    DrawRectangleLinesEx(d, 2, (Color){ 20, 18, 16, 255 });
}
static Color C_TEAL = { 84, 236, 204, 255 }, C_ICE = { 150, 220, 255, 255 }, C_EMBER = { 255, 120, 40, 255 };
static void fill_shape(Vector2 *p, int n, Vector2 ctr, Color col);
static void quad_curve(Vector2 a, Vector2 ctl, Vector2 b, float th, Color col, Vector2 *pts, int *np);
static int is_gate_mid(int c, int r);
static int gate_truth(char g);
static const char *gate_name(char g);
static void gate_icon(char g, float cx, float cy, float sz, Color line, Color fill);
static void shield_bubble(Rectangle b, Color c, float strength);
static int map_has(char ch);
static void draw_boss_at(int c0, int r0, int c1, int r1, int king);
static void draw_boss(const char *letters, int king) {   /* king: 0 Warden, 1 King, 2 Dark Shade */
    int r0 = 99, r1 = -1, c0 = 99, c1 = -1;
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (strchr(letters, mc(c, r))) {
        if (r < r0) r0 = r;
        if (r > r1) r1 = r;
        if (c < c0) c0 = c;
        if (c > c1) c1 = c;
    }
    if (r1 < 0) return;
    draw_boss_at(c0, r0, c1, r1, king);
}
static int warden_blocks(int *cs, int *rs, int max) {      /* every 3x3 Warden ("MBM" rows), top-left corners */
    static char used[MAP_H][MAP_W]; memset(used, 0, sizeof used);
    int n = 0;
    for (int r = 1; r < MAP_H - 3; r++) for (int c = 1; c < MAP_W - 3; c++) {
        if (used[r][c] || mc(c, r) != 'M' || mc(c + 2, r) != 'M' || mc(c, r + 1) != 'M' || mc(c, r + 2) != 'M' || mc(c + 2, r + 2) != 'M') continue;
        if (n < max) { cs[n] = c; rs[n] = r; n++; }
        for (int y = 0; y < 3; y++) for (int x = 0; x < 3; x++) used[r + y][c + x] = 1;
    }
    return n;
}
static void draw_boss_at(int c0, int r0, int c1, int r1, int king) {
    float x = MAP_X + c0 * TS, y = MAP_Y + r0 * TS, w = (c1 - c0 + 1) * TS, h = (r1 - r0 + 1) * TS;
    DrawEllipse((int)(x + w / 2), (int)(y + h - 4), w * 0.4f, 8, Fade(BLACK, 0.45f));
    DrawCircleGradient((int)(x + w / 2), (int)(y + h / 2), w * 0.7f, Fade(king == 1 ? C_GOLD : C_PURPLE, 0.16f + 0.05f * sinf(T * 2)), BLANK);
    if (king == 2) {                                     /* the Dark Shade: the King as a shadow, smoking */
        DrawCircleGradient((int)(x + w / 2), (int)(y + h / 2), w * 0.8f, Fade((Color){ 40, 0, 70, 255 }, 0.55f), BLANK);
        for (int i = 0; i < 18; i++) {
            float ph = fmodf(T * 0.4f + rnd(i), 1.0f);
            DrawCircle((int)(x + 10 + rnd(i + 5) * (w - 20)), (int)(y + h - ph * (h + 30)), 5 * (1 - ph) + 2, Fade((Color){ 90, 40, 140, 255 }, 0.45f * (1 - ph)));
        }
        int dark = map_has('d');                           /* in darkness it is only a shape you can't hit */
        sprite(SPR_KING_HALF, 24, x, y + sinf(T * 1.1f) * 3, w / 40.0f, (Color){ 110, 70, 170, (unsigned char)(dark ? 70 + 20 * sinf(T * 2) : 200 + 40 * sinf(T * 2)) }, 1);
        float ey = y + 9 * w / 40.0f + sinf(T * 1.1f) * 3;
        for (int e = -1; e <= 1; e += 2) DrawCircleGradient((int)(x + w / 2 + e * w * 0.16f), (int)(ey + 4), 7, Fade((Color){ 200, 120, 255, 255 }, dark ? 0.6f : 0.9f), BLANK);
        if (!dark) for (int i = 0; i < 10; i++) {          /* in the light it burns */
            float ph = fmodf(T * 1.2f + rnd(i + 300), 1.0f);
            DrawCircle((int)(x + rnd(i + 310) * w), (int)(y + h - ph * h), 3 * (1 - ph) + 1, Fade(C_EMBER, 0.8f * (1 - ph)));
        }
    } else if (king) sprite(SPR_KING_HALF, 24, x, y + sinf(T * 1.3f) * 1.5f, w / 40.0f, WHITE, 1);
    else {
        sprite(SPR_WARDEN_HALF, 24, x, y + sinf(T * 1.6f) * 1.5f, w / 24.0f, WHITE, 1);
        char g = mc(c0 + 1, r0 + 1);                       /* the gate on his shield (B = broken) */
        float sx = x + w * 0.5f, sy = y + h * 0.55f;
        DrawCircle((int)sx, (int)sy, 20, (Color){ 26, 28, 40, 235 });
        if (gate_truth(g)) {
            DrawCircleLines((int)sx, (int)sy, 20, C_BLUE);
            gate_icon(g, sx - 2, sy, 22, (Color){ 235, 240, 255, 255 }, Fade(C_BLUE, 0.35f));
            txt_c(gate_name(g), sx, sy + 22, 14, C_TEXT, 1);
            shield_bubble((Rectangle){ x, y, w, h }, C_BLUE, 1);
        } else {                                           /* broken: cracks */
            DrawCircleLines((int)sx, (int)sy, 20, C_DIM);
            DrawLineEx((Vector2){ sx - 10, sy - 14 }, (Vector2){ sx + 2, sy }, 2, C_DIM);
            DrawLineEx((Vector2){ sx + 2, sy }, (Vector2){ sx - 4, sy + 14 }, 2, C_DIM);
            DrawLineEx((Vector2){ sx + 2, sy }, (Vector2){ sx + 12, sy + 6 }, 2, C_DIM);
            txt_c("BROKEN", sx, sy + 22, 13, C_RED, 1);
        }
    }
}

/* ---- the bosses of the second half (32x32 sprites) ---- */
static int map_has(char ch) {
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (mc(c, r) == ch) return 1;
    return 0;
}
static int boss_rect(const char *letters, Rectangle *out) {   /* the cells a big enemy covers, in canvas pixels */
    int r0 = 99, r1 = -1, c0 = 99, c1 = -1;
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (strchr(letters, mc(c, r))) {
        if (r < r0) r0 = r;
        if (r > r1) r1 = r;
        if (c < c0) c0 = c;
        if (c > c1) c1 = c;
    }
    if (r1 < 0) return 0;
    *out = (Rectangle){ MAP_X + c0 * TS, MAP_Y + r0 * TS, (c1 - c0 + 1) * TS, (r1 - r0 + 1) * TS };
    return 1;
}
static void bolt(Vector2 a, Vector2 b, int seed, float th, Color col) {     /* a jagged lightning line */
    Vector2 p = a;
    for (int i = 1; i <= 6; i++) {
        float f = i / 6.0f;
        Vector2 q = { a.x + (b.x - a.x) * f, a.y + (b.y - a.y) * f };
        if (i < 6) { q.x += (rnd(seed * 13 + i + (int)(T * 20)) - 0.5f) * 14; q.y += (rnd(seed * 7 + i + (int)(T * 20)) - 0.5f) * 14; }
        DrawLineEx(p, q, th + 3, Fade(col, 0.25f));
        DrawLineEx(p, q, th, col);
        p = q;
    }
}
static void draw_boss2(const char *letters, int who) {   /* who: 0 Ymir, 1 Logic Keeper, 2 Altair, 3 Smo */
    Rectangle b;
    if (!boss_rect(letters, &b)) return;
    float x = b.x, y = b.y, w = b.width, sc = w / 32.0f, cx = x + w / 2, cy = y + b.height / 2;
    int rage = (who == 2 && map_has('t')) || (who == 3 && map_has('u'));
    DrawEllipse((int)cx, (int)(y + b.height - 4), w * 0.42f, 8 * sc / 2 + 4, Fade(BLACK, 0.45f));
    if (who == 0) {                                      /* Ymir: frost aura, falling snow, glowing crystal and orb */
        DrawCircleGradient((int)cx, (int)cy, w * 0.8f, Fade(C_ICE, 0.16f + 0.05f * sinf(T * 2)), BLANK);
        for (int i = 0; i < 16; i++) {
            float ph = fmodf(T * 0.25f + rnd(i + 40), 1.0f);
            DrawCircle((int)(x - 20 + rnd(i + 60) * (w + 40) + sinf(T + i) * 6), (int)(y - 20 + ph * (b.height + 30)), 2, Fade(WHITE, 0.7f * (1 - ph)));
        }
        float bobY = sinf(T * 1.4f) * 2;
        sprite(SPR_YMIR, 32, x, y + bobY, sc, WHITE, 0);
        DrawCircleGradient((int)(x + 5.5f * sc), (int)(y + 4.5f * sc + bobY), 10 * sc, Fade(C_ICE, 0.45f + 0.2f * sinf(T * 4)), BLANK);
        DrawCircleGradient((int)(x + 28 * sc), (int)(y + 5.5f * sc + bobY), 9 * sc, Fade((Color){ 124, 226, 255, 255 }, 0.5f + 0.25f * sinf(T * 5)), BLANK);
    } else if (who == 1) {                               /* the Logic Keeper: a teal ward while it holds */
        int ward = map_has('J');
        sprite(SPR_KEEPER, 32, x, y + sinf(T * 1.2f) * 1.2f, sc, WHITE, 0);
        float glow = ward ? 0.5f + 0.3f * sinf(T * 3) : 0.12f;
        DrawCircleGradient((int)(x + 24.5f * sc), (int)(y + 18 * sc), 8 * sc, Fade(C_TEAL, glow), BLANK);   /* the gate on its shield */
        if (ward) {
            DrawEllipse((int)cx, (int)cy, w * 0.66f, b.height * 0.66f, Fade(C_TEAL, 0.10f + 0.04f * sinf(T * 2)));
            DrawEllipseLines((int)cx, (int)cy, w * 0.66f, b.height * 0.66f, Fade(C_TEAL, 0.7f));
            DrawEllipseLines((int)cx, (int)cy, w * 0.66f + 3, b.height * 0.66f + 3, Fade(C_TEAL, 0.25f));
            for (int i = 0; i < 8; i++) {                /* rune sparks running round the ward */
                float a = T * 0.8f + i * PI / 4;
                Vector2 p = { cx + cosf(a) * w * 0.66f, cy + sinf(a) * b.height * 0.66f };
                DrawCircleGradient((int)p.x, (int)p.y, 7, Fade(C_TEAL, 0.8f), BLANK);
                DrawRectangle((int)p.x - 2, (int)p.y - 2, 4, 4, (Color){ 220, 255, 245, 255 });
            }
        }
    } else if (who == 2) {                               /* Altair: lightning on the spear; wild arcs when empowered */
        if (rage) DrawCircleGradient((int)cx, (int)cy, w * 1.4f, Fade(C_ICE, 0.25f + 0.1f * sinf(T * 6)), BLANK);
        sprite(SPR_ALTAIR, 32, x, y + sinf(T * 2.2f) * 1.2f, sc, rage ? (Color){ 230, 245, 255, 255 } : WHITE, 0);
        Vector2 tip = { x + 29 * sc, y + 2 * sc };
        DrawCircleGradient((int)tip.x, (int)tip.y, 14, Fade(C_ICE, 0.6f + 0.3f * sinf(T * 9)), BLANK);
        if (rage || fmodf(T, 1.2f) < 0.15f) bolt(tip, (Vector2){ tip.x + 18, tip.y - 14 }, 1, 1.5f, (Color){ 210, 240, 255, 255 });
        if (rage) for (int k = 0; k < 3; k++) {
            float a = T * 3 + k * 2.1f;
            bolt((Vector2){ cx, cy }, (Vector2){ cx + cosf(a) * w * 0.9f, cy + sinf(a) * w * 0.9f }, k + 3, 1.5f, (Color){ 170, 220, 255, 255 });
        }
    } else {                                             /* Smo: smoulders; burns when empowered */
        if (rage) {
            DrawCircleGradient((int)cx, (int)cy, w * 0.85f, Fade(C_EMBER, 0.42f + 0.1f * sinf(T * 5)), BLANK);
            for (int i = 0; i < 14; i++) {
                float ph = fmodf(T * 0.5f + rnd(i + 90), 1.0f);
                DrawCircle((int)(x + rnd(i + 70) * w), (int)(y + b.height - ph * (b.height + 20)), 3 * (1 - ph) + 1, Fade(C_EMBER, 0.8f * (1 - ph)));
            }
        }
        sprite(SPR_SMO, 32, x, y + sinf(T * 1.0f) * 1.0f, sc, rage ? (Color){ 255, 215, 190, 255 } : WHITE, 0);
        float ey = y + 9.5f * sc + sinf(T * 1.0f);
        DrawCircleGradient((int)(x + 16.5f * sc), (int)ey, (rage ? 16 : 10) * sc / 4 + 4, Fade(C_EMBER, rage ? 0.9f : 0.5f), BLANK);
    }
}


/* ---- v8 boss pieces ---- */
static Vector2 player_px(void);
static int gate_truth(char g) {   /* bit (a*2+b) set = that input passes */
    return g == 'A' ? 8 : g == 'V' ? 14 : g == 'X' ? 6 : g == 'a' ? 7 : g == 'v' ? 1 : g == 'E' ? 9 : 0;
}
static const char *gate_name(char g) {
    return g == 'A' ? "AND" : g == 'V' ? "OR" : g == 'X' ? "XOR" : g == 'a' ? "NAND" : g == 'v' ? "NOR" : g == 'E' ? "XNOR" : "?";
}
static void gate_icon(char g, float cx, float cy, float sz, Color line, Color fill) {   /* a small gate symbol, sz = its height */
    Vector2 pts[80]; int np = 0;
    float h = sz, w = sz, sx = cx - w / 2, sy = cy - h / 2;
    int bubble = g == 'a' || g == 'v' || g == 'E';
    float bw = bubble ? w * 0.8f : w, th = sz / 12 + 1;
    if (g == 'A' || g == 'a') {
        float rad = h / 2, ax = sx + bw - rad;
        pts[np++] = (Vector2){ sx, sy }; pts[np++] = (Vector2){ ax, sy };
        for (int i = 0; i <= 16; i++) { float an = -PI / 2 + PI * i / 16; pts[np++] = (Vector2){ ax + cosf(an) * rad, cy + sinf(an) * rad }; }
        pts[np++] = (Vector2){ sx, sy + h };
        fill_shape(pts, np, (Vector2){ sx + bw * 0.45f, cy }, fill);
        for (int i = 0; i < np; i++) DrawLineEx(pts[i], pts[(i + 1) % np], th, line);
    } else {
        Vector2 tl = { sx, sy }, bl = { sx, sy + h }, tip = { sx + bw, cy };
        pts[np++] = bl;
        quad_curve(bl, (Vector2){ sx + w * 0.28f, cy }, tl, 0, line, pts, &np);
        quad_curve(tl, (Vector2){ sx + bw * 0.62f, sy }, tip, 0, line, pts, &np);
        quad_curve(tip, (Vector2){ sx + bw * 0.62f, sy + h }, bl, 0, line, pts, &np);
        fill_shape(pts, np, (Vector2){ sx + bw * 0.5f, cy }, fill);
        for (int i = 0; i < np - 1; i++) DrawLineEx(pts[i], pts[i + 1], th, line);
        if (g == 'X' || g == 'E') quad_curve((Vector2){ sx - sz * 0.18f, sy + h }, (Vector2){ sx - sz * 0.18f + w * 0.28f, cy }, (Vector2){ sx - sz * 0.18f, sy }, th, line, NULL, NULL);
    }
    if (bubble) DrawRing((Vector2){ sx + bw + sz * 0.1f, cy }, sz * 0.06f, sz * 0.06f + th, 0, 360, 16, line);
}
static void draw_lantern(int c, int r) {                  /* the Shade's lantern: lit when both gates output 1 */
    int lit = mc(c - 1, r - 1) == '$';
    float cx = MAP_X + c * TS + TS / 2.0f, cy = MAP_Y + r * TS + TS / 2.0f;
    if (lit) {
        DrawCircleGradient((int)cx, (int)cy, 260, Fade((Color){ 255, 190, 90, 255 }, 0.20f + 0.05f * sinf(T * 7)), BLANK);
        DrawCircleGradient((int)cx, (int)cy, 90, Fade((Color){ 255, 220, 140, 255 }, 0.45f), BLANK);
    }
    DrawLineEx((Vector2){ cx, cy - 46 }, (Vector2){ cx, cy - 26 }, 3, (Color){ 90, 90, 100, 255 });   /* chain */
    for (int i = 0; i < 3; i++) DrawCircleLines((int)cx, (int)(cy - 44 + i * 7), 3, (Color){ 120, 120, 130, 255 });
    Rectangle body = { cx - 16, cy - 24, 32, 44 };
    DrawRectangleRounded((Rectangle){ body.x - 4, body.y - 4, body.width + 8, 8 }, 0.5f, 6, (Color){ 60, 60, 70, 255 });
    DrawRectangleRounded((Rectangle){ body.x - 4, body.y + body.height - 4, body.width + 8, 8 }, 0.5f, 6, (Color){ 60, 60, 70, 255 });
    DrawRectangleRec(body, lit ? (Color){ 255, 214, 130, 255 } : (Color){ 30, 32, 44, 255 });
    for (int i = 0; i < 3; i++) DrawRectangleRec((Rectangle){ body.x + 2 + i * 13, body.y, 3, body.height }, (Color){ 60, 60, 70, 255 });
    if (lit) flame(cx, cy + 14, 10, T * 1.3f);
    else DrawCircle((int)cx, (int)(cy + 10), 4, (Color){ 70, 60, 50, 255 });
    DrawRectangleLinesEx(body, 2, (Color){ 20, 20, 28, 255 });
    txt_c(lit ? "LANTERN" : "lantern", cx, cy + 30, 14, lit ? C_GOLD : C_DIM, 1);
}
/* torches on the map: "[0]" / "[1]" */
typedef struct { int c, r, lit; } TorchPos;
static int find_torches(TorchPos *out, int max) {
    int n = 0;
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 2; c++)
        if (mc(c, r) == '[' && (mc(c + 1, r) == '0' || mc(c + 1, r) == '1') && mc(c + 2, r) == ']' && n < max) out[n++] = (TorchPos){ c, r, mc(c + 1, r) == '1' };
    return n;
}
static int unbound_mode_char(void) {                      /* the Unbound King's middle letter, or 0 */
    Rectangle b;
    if (!boss_rect("Z", &b)) return 0;
    int c0 = (int)((b.x - MAP_X) / TS), r0 = (int)((b.y - MAP_Y) / TS), w = (int)(b.width / TS), h = (int)(b.height / TS);
    return mc(c0 + w / 2, r0 + h / 2);                    /* his size changes with the boss he imitates */
}
static int unbound_mode_char(void);
static int room_is_dark(void) {
    int um = unbound_mode_char();
    if (S.floor == 15 || um == 'D' || um == 'd') {          /* the Shade's room (or the Unbound's Shade form), unless the lantern burns */
        for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (mc(c, r) == 'L' && is_gate_mid(c, r)) return mc(c - 1, r - 1) != '$';
        return 1;
    }
    return 0;
}
static void draw_darkness(void) {                          /* black over everything the light doesn't reach */
    TorchPos tp[8]; int n = find_torches(tp, 8);
    Vector2 me = player_px();
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) for (int q = 0; q < 4; q++) {   /* quarter cells: softer edges */
        float fc = c + (q & 1) * 0.5f - 0.25f, fr = r + (q >> 1) * 0.5f - 0.25f;
        float best = 99;
        for (int i = 0; i < n; i++) if (tp[i].lit) {        /* soft round light (the rule itself counts 4 steps) */
            float dx = fc < tp[i].c ? tp[i].c - fc : fc > tp[i].c + 2 ? fc - tp[i].c - 2 : 0, dy = fabsf(fr - tp[i].r);
            float d = sqrtf(dx * dx + dy * dy);
            if (d < best) best = d;
        }
        float a = best <= 2.5f ? 0.0f : best >= 5.5f ? 0.74f : (best - 2.5f) / 3.0f * 0.74f;
        if (me.x >= 0) {                                   /* you carry a faint light of your own */
            float d = fmaxf(fabsf(MAP_X + fc * TS + TS / 2.0f - me.x), fabsf(MAP_Y + fr * TS + TS / 2.0f - me.y)) / TS;
            if (d < 1.5f && a > 0.45f) a = 0.45f;
        }
        Rectangle tq = tile(c, r);
        if (a > 0) DrawRectangleRec((Rectangle){ tq.x + (q & 1) * TS / 2.0f, tq.y + (q >> 1) * TS / 2.0f, TS / 2.0f, TS / 2.0f }, Fade((Color){ 4, 3, 10, 255 }, a));
    }
    for (int i = 0; i < n; i++) if (tp[i].lit) {
        float cx = MAP_X + (tp[i].c + 1) * TS + TS / 2.0f, cy = MAP_Y + tp[i].r * TS + TS / 2.0f;
        DrawCircleGradient((int)cx, (int)cy, TS * 5.0f, Fade((Color){ 255, 170, 70, 255 }, 0.10f + 0.03f * sinf(T * 9 + i)), BLANK);
    }
}
static void bit_badge(float cx, float y, int bit) {        /* a 1 or a 0 floating over a head */
    float bob = sinf(T * 3) * 2;
    Rectangle b = { cx - 14, y - 34 + bob, 28, 28 };
    Color c = bit ? C_GOLD : C_RED;
    DrawCircleGradient((int)cx, (int)(b.y + 14), 26, Fade(c, 0.35f), BLANK);
    DrawRectangleRounded(b, 0.35f, 6, bit ? (Color){ 255, 214, 110, 255 } : (Color){ 220, 70, 70, 255 });
    DrawRectangleRoundedLinesEx(b, 0.35f, 6, 2, Fade(BLACK, 0.6f));
    txt_c(bit ? "1" : "0", cx, b.y + 2, 24, bit ? (Color){ 60, 30, 0, 255 } : WHITE, 1);
}
static void shield_bubble(Rectangle b, Color c, float strength) {
    float cx = b.x + b.width / 2, cy = b.y + b.height / 2, rx = b.width * 0.62f + 6, ry = b.height * 0.62f + 6;
    DrawEllipse((int)cx, (int)cy, rx, ry, Fade(c, 0.08f * strength + 0.03f * sinf(T * 3)));
    DrawEllipseLines((int)cx, (int)cy, rx, ry, Fade(c, 0.75f * strength));
    DrawEllipseLines((int)cx, (int)cy, rx + 3, ry + 3, Fade(c, 0.3f * strength));
}
static void exposed_mark(Rectangle b) {                    /* red flicker: takes extra damage */
    float a = 0.35f + 0.25f * sinf(T * 10);
    DrawRectangleRoundedLinesEx((Rectangle){ b.x - 4, b.y - 4, b.width + 8, b.height + 8 }, 0.2f, 6, 3, Fade(C_RED, a));
}
static void draw_throne_and_king(const char *letters) {   /* phase 1: the King on his throne */
    Rectangle b;
    if (!boss_rect(letters, &b)) return;
    float cx = b.x + b.width / 2, sc = 5;
    float tx = cx - 24 * sc, ty = b.y + b.height - 32 * sc + 26;
    sprite(SPR_THRONE, 32, tx, ty, sc, WHITE, 0);
    int c0 = (int)((b.x - MAP_X) / TS), r0 = (int)((b.y - MAP_Y) / TS);
    int open = mc(c0 - 1, r0 + 1) == '=';                 /* the wire into the throne */
    DrawCircleGradient((int)cx, (int)(b.y + b.height / 2), b.width * 0.7f, Fade(open ? C_GOLD : C_PURPLE, 0.16f + 0.05f * sinf(T * 2)), BLANK);
    sprite(SPR_KING_HALF, 24, b.x, b.y + sinf(T * 1.3f) * 1.5f, b.width / 40.0f, WHITE, 1);
    if (!open) shield_bubble(b, C_GOLD, 1);
    else for (int i = 0; i < 6; i++) {                     /* sparks: the circuit's power runs through him */
        float a = T * 4 + i;
        DrawCircle((int)(cx + cosf(a) * b.width * 0.55f), (int)(b.y + b.height / 2 + sinf(a * 1.3f) * b.height * 0.5f), 3, Fade(C_GOLD, 0.9f));
    }
}
static void draw_unbound(void) {
    Rectangle b;
    if (!boss_rect("Z", &b)) return;
    int m = unbound_mode_char();
    float cx = b.x + b.width / 2, cy = b.y + b.height / 2;
    float side = fmaxf(fminf(b.width, b.height), 3 * TS), sc = side / 48;   /* fits the boss he imitates (small forms stand a cell taller, like the bishops) */
    float sx = cx - 24 * sc, sy = b.y + b.height - 48 * sc;
    int face_left = cx > MAP_X + MAP_W * TS / 2.0f && m == 'q';         /* as a bishop on the right, he faces the middle */
    DrawEllipse((int)cx, (int)(b.y + b.height - 6), b.width * 0.45f, 14, Fade(BLACK, 0.5f));
    if (m == 'D' || m == 'd') {                            /* the Shade's form: a shadow of himself, smoking */
        int dark = m == 'd';
        float by = b.y + sinf(T * 1.1f) * 3;
        DrawCircleGradient((int)cx, (int)cy, b.width * 0.9f, Fade((Color){ 40, 0, 70, 255 }, 0.6f), BLANK);
        for (int i = 0; i < 26; i++) {                     /* smoke curling up off him */
            float ph = fmodf(T * 0.35f + rnd(i + 500), 1.0f);
            DrawCircle((int)(b.x + 14 + rnd(i + 520) * (b.width - 28) + sinf(T + i) * 6), (int)(b.y + b.height - ph * (b.height + 50)),
                       7 * (1 - ph) + 3, Fade((Color){ 90, 40, 140, 255 }, 0.4f * (1 - ph)));
        }
        unsigned char a = (unsigned char)(dark ? 80 + 30 * sinf(T * 2) : 215 + 35 * sinf(T * 2));
        by = sy + sinf(T * 1.1f) * 3;
        sprite(SPR_UNBOUND_SHADE, 48, sx, by, sc, (Color){ 255, 255, 255, a }, 0);
        for (int e = 0; e < 2; e++)                         /* the eyes burn even in the dark */
            DrawCircleGradient((int)(sx + (e ? 27 : 22) * sc), (int)(by + 8.5f * sc), 9, Fade((Color){ 200, 120, 255, 255 }, dark ? 0.7f : 0.95f), BLANK);
        if (!dark) for (int i = 0; i < 12; i++) {           /* in the light he burns */
            float ph = fmodf(T * 1.2f + rnd(i + 540), 1.0f);
            DrawCircle((int)(b.x + rnd(i + 560) * b.width), (int)(b.y + b.height - ph * b.height), 3 * (1 - ph) + 1, Fade(C_EMBER, 0.8f * (1 - ph)));
        }
        return;
    }
    DrawCircleGradient((int)cx, (int)cy, b.width * 0.85f, Fade((Color){ 255, 120, 40, 255 }, 0.18f + 0.06f * sinf(T * 3)), BLANK);
    for (int i = 0; i < 12; i++) {                         /* embers rising off him */
        float ph = fmodf(T * 0.6f + rnd(i + 200), 1.0f);
        DrawCircle((int)(b.x + rnd(i + 230) * b.width), (int)(b.y + b.height - ph * (b.height + 40)), 3 * (1 - ph) + 1, Fade(C_GOLD, 0.7f * (1 - ph)));
    }
    float alpha = m == 'd' ? 0.35f : 1.0f;
    Color ut = { 255, 255, 255, (unsigned char)(255 * alpha) };
    if (m == 'q') ut = (Color){ 235, 225, 255, 255 };                    /* the Bishop form: a cold, pale light */
    if (m == 'W' || m == 'w') ut = (Color){ 200, 230, 255, 255 };        /* the Keeper form: blue */
    if (face_left) sprite_flip(SPR_UNBOUND, 48, sx, sy + sinf(T * 1.2f) * 2, sc, ut);
    else sprite(SPR_UNBOUND, 48, sx, sy + sinf(T * 1.2f) * 2, sc, ut, 0);
    if (m == 'q') DrawRing((Vector2){ cx, sy + 2 * sc }, 16, 18, 0, 360, 28, Fade((Color){ 200, 225, 255, 255 }, 0.55f + 0.2f * sinf(T * 3)));   /* a bishop's cold halo */
    if (m == 'W') shield_bubble(b, (Color){ 90, 170, 255, 255 }, 1);   /* linked to his Wardens: immune */
    if (gate_truth((char)m)) {                             /* the Warden's trick: a gate on his chest */
        TorchPos tp[4]; int n = find_torches(tp, 4), ok = 0;
        if (n >= 2) ok = (gate_truth((char)m) >> (tp[0].lit * 2 + tp[1].lit)) & 1;
        DrawCircle((int)cx, (int)(sy + 25 * sc), 22, (Color){ 30, 32, 44, 230 });
        gate_icon((char)m, cx - 2, sy + 25 * sc, 26, ok ? C_GOLD : (Color){ 230, 230, 240, 255 }, Fade(ok ? C_GOLD : C_BLUE, 0.3f));
        txt_c(gate_name((char)m), cx, sy + 25 * sc + 20, 14, C_TEXT, 1);
        if (!ok) shield_bubble(b, C_BLUE, 1);
    } else if (m == 'f') {                                 /* Ymir's trick: he drinks the torch light */
        TorchPos tp[4]; int n = find_torches(tp, 4);
        for (int i = 0; i < n; i++) if (tp[i].lit) {
            Vector2 a = { MAP_X + (tp[i].c + 1) * TS + TS / 2.0f, MAP_Y + tp[i].r * TS + TS / 2.0f };
            for (int k = 0; k < 10; k++) {
                float f = fmodf(T * 0.8f + k / 10.0f, 1.0f);
                DrawCircle((int)(a.x + (cx - a.x) * f), (int)(a.y + (cy - a.y) * f + sinf(f * 9 + i) * 8), 5 * (1 - f) + 2, Fade(C_EMBER, 0.8f));
            }
        }
    } else if (m == '1' || m == '0') {                     /* Altair and Smo's trick: a bit over his head */
        bit_badge(cx, fmaxf(fminf(b.y, sy + 4 * sc), MAP_Y + TS + 34), m == '1');   /* (never up in the top bar) */
        if (m == '1') shield_bubble(b, C_GOLD, 1); else exposed_mark(b);
    }
}
static void draw_power_torch(Rectangle t, int lit) {      /* Ymir's blue power torches */
    float cx = t.x + TS / 2, by = t.y + 10;
    DrawEllipse((int)cx, (int)(t.y + TS - 2), 14, 4, Fade(BLACK, 0.5f));
    if (lit) DrawCircleGradient((int)cx, (int)by, TS * 1.8f, Fade(C_ICE, 0.35f + 0.1f * sinf(T * 6)), BLANK);
    sprite(SPR_BRAZIER, 16, t.x - 8, t.y - 16, 3, (Color){ 170, 190, 230, 255 }, 0);
    if (lit) {
        float f = 1 + 0.15f * sinf(T * 15);
        DrawTriangle((Vector2){ cx, by - 22 * f }, (Vector2){ cx - 8, by + 8 }, (Vector2){ cx + 8, by + 8 }, (Color){ 60, 140, 255, 255 });
        DrawTriangle((Vector2){ cx, by - 14 * f }, (Vector2){ cx - 5, by + 8 }, (Vector2){ cx + 5, by + 8 }, (Color){ 150, 220, 255, 255 });
        DrawTriangle((Vector2){ cx, by - 6 * f }, (Vector2){ cx - 2, by + 8 }, (Vector2){ cx + 2, by + 8 }, WHITE);
    } else for (int k = 0; k < 3; k++) DrawCircle((int)(cx - 6 + k * 6), (int)(by + 6), 2, (Color){ 120, 150, 190, 255 });
    txtb("POWER", cx + 18, t.y + 8, 12, lit ? C_ICE : C_DIM);
}

/* ---- one-shot effects: Ymir's spells, the ward breaking, a partner rising ---- */
enum { FX_FIRE = 1, FX_FROST, FX_BOLT, FX_METEOR, FX_SHATTER, FX_RISE, FX_REWARD, FX_WAVE, FX_FALLEN, FX_UNBOUND, FX_SLAM, FX_LASER, FX_LANTERN, FX_LEVEL };
static Vector2 laser_old[4], laser_new[4]; static int laser_n;   /* where the Warden's torches were / went */
static float shake_t;
typedef struct { int kind; float t, delay; } Fx;
static Fx fx[8];
static void fx_add(int kind, float delay) {
    for (int i = 0; i < 8; i++) if (!fx[i].kind) { fx[i] = (Fx){ kind, 0, delay }; return; }
}
static int spell_kind(const char *q) {
    return !strncmp(q, "Fire", 4) ? FX_FIRE : !strncmp(q, "Frost", 5) ? FX_FROST : !strncmp(q, "Light", 5) ? FX_BOLT : !strncmp(q, "Meteor", 6) ? FX_METEOR : 0;
}
static void fx_from_msg(const char *m) {                  /* a new log line: start whatever effect it describes */
    if (strstr(m, "Wizard Ymir")) {
        const char *p = strstr(m, " casts ");
        if (p && spell_kind(p + 7)) fx_add(spell_kind(p + 7), 0);
        p = strstr(m, ", then ");
        if (p && spell_kind(p + 7)) fx_add(spell_kind(p + 7), 0.55f);
    }
    if (strstr(m, "ward shatters")) fx_add(FX_SHATTER, 0);
    if (strstr(m, "rewrites the gate")) fx_add(FX_REWARD, 0);
    if (strstr(m, "rises again")) fx_add(FX_RISE, 0);
    if (strstr(m, "blue wave")) fx_add(FX_WAVE, 0);
    if (strstr(m, "has fallen")) fx_add(FX_FALLEN, 0);
    if (strstr(m, "UNBOUND")) fx_add(FX_UNBOUND, 2.75f);
    if (strstr(m, "The Unbound shakes the room")) shake_t = 1.0f;        /* lands on the revival sound's burst */
    if (strstr(m, "slams his throne")) { fx_add(FX_SLAM, 0); shake_t = 0.5f; }
    if (strstr(m, "lantern blazes") || strstr(m, "lantern flares")) fx_add(FX_LANTERN, 0);
    if (strstr(m, "LEVEL UP")) fx_add(FX_LEVEL, 0);
}
static void draw_fx_overlay(float dt) {                  /* the King's fake death: drawn over the whole window */
    for (int i = 0; i < 8; i++) {
        Fx *f = &fx[i];
        if (f->delay > 0) continue;                         /* not started yet */
        if (f->kind == FX_FALLEN) {
            float k = f->t;
            if (k > 3.4f) { f->kind = 0; continue; }
            float a = k < 0.8f ? k / 0.8f : 1;
            DrawRectangle(0, 0, W, H, Fade(BLACK, 0.72f * a));
            const char *t1 = "THE FORGOTTEN KING HAS FALLEN";
            txt_c(t1, W / 2.0f, H / 2.0f - 50, 64, Fade(C_GOLD, a), 1);
            txt_c("the circuit falls silent...", W / 2.0f, H / 2.0f + 30, 24, Fade(C_DIM, a), 0);
        } else if (f->kind == FX_UNBOUND) {
            float k = f->t;
            if (k < 0.1f && shake_t < 0.7f) shake_t = 0.8f;
            if (k > 3.0f) { f->kind = 0; continue; }
            if (k < 0.25f) DrawRectangle(0, 0, W, H, set.calm ? Fade((Color){ 60, 0, 0, 255 }, 0.5f * (1 - k * 4)) : Fade(WHITE, 1 - k * 4));
            float a = k < 2.2f ? 1 : 1 - (k - 2.2f) / 0.8f;
            DrawRectangle(0, 0, W, H, Fade((Color){ 40, 0, 0, 255 }, 0.35f * a));
            txt_c("THE FORGOTTEN KING", W / 2.0f, H / 2.0f - 90, 48, Fade(C_GOLD, a), 1);
            txt_c("UNBOUND", W / 2.0f + (rnd((int)(T * 40)) - 0.5f) * 8 * a, H / 2.0f - 40, 110, Fade(C_RED, a), 1);
        }
    }
    (void)dt;
}
static Vector2 player_px(void) {
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (mc(c, r) == '@') return (Vector2){ MAP_X + c * TS + TS / 2.0f, MAP_Y + r * TS + TS / 2.0f };
    return (Vector2){ -1, -1 };
}
/* ---- your spells, and ranged attacks: animated from the game's notes ---- */
typedef struct { int kind, n, seed; float t, delay, dur; Vector2 src, tg[8]; Rectangle area; } SpellFx;
static SpellFx sfx_fx[12];
static Vector2 grid_px(int gx, int gy) { return (Vector2){ MAP_X + (gx + 1) * TS + TS / 2.0f, MAP_Y + (gy + 1) * TS + TS / 2.0f }; }
static void spellfx_add(SpellFx f) {
    for (int i = 0; i < 12; i++) if (!sfx_fx[i].dur) { f.seed = GetRandomValue(0, 99999); sfx_fx[i] = f; return; }
}
static const float SPELL_DUR[13] = { 0.75f, 1.2f, 0.9f, 1.0f, 0.8f, 1.3f, 1.1f, 0.9f, 0.8f, 1.2f, 1.0f, 1.2f, 1.0f };
static void handle_osc_fx(const char *t) {
    if (t[0] == 'S') {                                    /* S<spell>,<px>,<py>,<n>,<x,y>*n[,<x0>,<y0>,<w>,<h>] */
        int v[40], n = 0; const char *p = t + 1;
        while (*p && n < 40) { v[n++] = atoi(p); while (*p && *p != ',') p++; if (*p == ',') p++; }
        if (n < 6 || v[0] < 0 || v[0] > 12) return;
        SpellFx f = { 0 };
        f.kind = v[0]; f.src = grid_px(v[1], v[2]); f.n = v[3] < 1 ? 1 : v[3] > 8 ? 8 : v[3];
        for (int i = 0; i < f.n && 5 + i * 2 < n; i++) f.tg[i] = grid_px(v[4 + i * 2], v[5 + i * 2]);
        int k = 4 + f.n * 2;
        if (k + 3 < n) f.area = (Rectangle){ MAP_X + (v[k] + 1) * TS, MAP_Y + (v[k + 1] + 1) * TS, v[k + 2] * TS, v[k + 3] * TS };
        else f.area = (Rectangle){ f.tg[0].x - TS / 2, f.tg[0].y - TS / 2, TS, TS };
        f.dur = SPELL_DUR[f.kind];
        spellfx_add(f);
    } else handle_osc_attack(t);
}
static void handle_osc_attack(const char *t) {
    if (t[0] == 'B') {                                    /* B<spell>,<px>,<py>,<x,y> per bishop */
        int v[20], n = 0; const char *p = t + 1;
        while (*p && n < 20) { v[n++] = atoi(p); while (*p && *p != ',') p++; if (*p == ',') p++; }
        if (n < 5) return;
        SpellFx f = { 0 };
        f.kind = v[0] ? 21 : 20; f.src = grid_px(v[1], v[2]); f.n = 0;
        for (int i = 3; i + 1 < n && f.n < 8; i += 2) { Vector2 c = grid_px(v[i], v[i + 1]); f.tg[f.n++] = (Vector2){ c.x + TS / 2.0f, c.y + TS / 2.0f }; }
        f.dur = 1.0f;
        spellfx_add(f);
    } else if (t[0] == 'E') handle_osc_enemy(t);
}
static void handle_osc_enemy(const char *t) {            /* E<kind>,<ex>,<ey>,<px>,<py>,<hit> */
    char kind = t[1]; int v[5] = { 0 }, n = 0; const char *p = t + 2;
    while (*p && n < 5) { v[n++] = atoi(p); while (*p && *p != ',') p++; if (*p == ',') p++; }
    if (n < 5) return;
    static double last; static int stack;
    double now = GetTime(); stack = now - last < 0.25 ? stack + 1 : 0; last = now;   /* several in one turn: one after another */
    SpellFx f = { 0 };
    f.kind = kind == 'a' ? 30 : kind == 'l' ? 31 : kind == 's' ? 32 : kind == 'k' ? 33 : 34;
    Vector2 from = grid_px(v[0], v[1]), to = grid_px(v[2], v[3]);
    if (!v[4]) { to.x += (GetRandomValue(0, 1) ? 1 : -1) * 26; to.y += GetRandomValue(-20, 20); }   /* a miss flies wide */
    f.src = from; f.tg[0] = to; f.n = v[4];
    f.dur = f.kind == 32 ? 0.8f : 0.6f; f.delay = stack * 0.18f;
    spellfx_add(f);
}
static void glow_dot(Vector2 p, float r, Color c) { DrawCircleGradient((int)p.x, (int)p.y, r * 2.4f, Fade(c, 0.35f), BLANK); DrawCircleV(p, r, c); DrawCircleV(p, r * 0.45f, Fade(WHITE, 0.9f)); }
static Vector2 lerpv(Vector2 a, Vector2 b, float k) { return (Vector2){ a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k }; }
static void burst(Vector2 p, float k, float size, Color c, int seed) {        /* an expanding flash with sparks, k = 0..1 */
    if (k < 0 || k > 1) return;
    DrawCircleGradient((int)p.x, (int)p.y, size * (0.4f + k), Fade(c, 0.6f * (1 - k)), BLANK);
    DrawRing(p, size * k * 0.9f, size * k * 0.9f + 3, 0, 360, 28, Fade(c, 0.8f * (1 - k)));
    for (int i = 0; i < 10; i++) {
        float an = rnd(seed + i) * 2 * PI, d = size * (0.3f + 0.9f * k) * (0.6f + 0.4f * rnd(seed + i + 50));
        DrawCircleV((Vector2){ p.x + cosf(an) * d, p.y + sinf(an) * d }, 2.5f * (1 - k) + 0.5f, Fade(c, 1 - k));
    }
}
static void beam(Vector2 a, Vector2 b, float w, Color c, float alpha) {
    DrawLineEx(a, b, w * 3, Fade(c, 0.18f * alpha));
    DrawLineEx(a, b, w, Fade(c, 0.85f * alpha));
    DrawLineEx(a, b, w * 0.35f, Fade(WHITE, 0.9f * alpha));
}
static void draw_spell_fx(float dt) {
    static const Color FIRE = { 255, 130, 40, 255 }, FROST = { 150, 220, 255, 255 }, ARC = { 190, 120, 255, 255 }, GOLDL = { 255, 220, 120, 255 }, BLOOD = { 220, 40, 60, 255 };
    for (int i = 0; i < 12; i++) {
        SpellFx *f = &sfx_fx[i];
        if (!f->dur) continue;
        if (f->delay > 0) { f->delay -= dt; continue; }
        f->t += dt;
        float k = f->t / f->dur;
        if (k >= 1) { f->dur = 0; continue; }
        Vector2 s = f->src, g = f->tg[0];
        Vector2 ac = { f->area.x + f->area.width / 2, f->area.y + f->area.height / 2 };
        switch (f->kind) {
        case 0: {   /* Firebolt: a flying fireball, then a burst */
            float fl = 0.45f;
            if (k < fl) { Vector2 p = lerpv(s, g, k / fl);
                for (int j = 1; j < 6; j++) glow_dot(lerpv(s, g, fmaxf(0, k / fl - j * 0.04f)), 6 - j, Fade(FIRE, 1 - j * 0.15f));
                glow_dot(p, 7, FIRE); }
            else burst(g, (k - fl) / (1 - fl), 34, FIRE, f->seed);
        } break;
        case 1: {   /* Fireball: a thrown orb, then the explosion fills the area */
            float fl = 0.38f;
            if (k < fl) { float q = k / fl; Vector2 p = lerpv(s, ac, q); p.y -= sinf(q * PI) * 60;
                glow_dot(p, 9, FIRE); }
            else { float q = (k - fl) / (1 - fl), rad = fmaxf(f->area.width, f->area.height) * 0.6f + 20;
                if (q < 0.15f && set.shake) shake_t = fmaxf(shake_t, 0.25f);
                DrawCircleGradient((int)ac.x, (int)ac.y, rad * (0.5f + 0.7f * q), Fade(FIRE, 0.75f * (1 - q)), BLANK);
                DrawCircleGradient((int)ac.x, (int)ac.y, rad * 0.5f * (0.5f + q), Fade(GOLDL, 0.8f * (1 - q)), BLANK);
                for (int j = 0; j < 26; j++) { float an = rnd(f->seed + j) * 2 * PI, d = rad * q * (0.4f + 0.8f * rnd(f->seed + j + 9));
                    DrawCircleV((Vector2){ ac.x + cosf(an) * d, ac.y + sinf(an) * d - q * 20 }, 4 * (1 - q) + 1, Fade(j & 1 ? FIRE : GOLDL, 1 - q)); }
                DrawRing(ac, rad * q, rad * q + 4, 0, 360, 40, Fade(GOLDL, 0.7f * (1 - q))); }
        } break;
        case 2: case 3: {   /* Magic Missile darts curve to each target; Scorching Ray beams one after another */
            for (int d = 0; d < f->n; d++) {
                float st = d * (f->kind == 2 ? 0.1f : 0.22f), q = (k * f->dur - st) / 0.42f;
                Vector2 tg = f->tg[d];
                if (f->kind == 2) {
                    float side = (rnd(f->seed + d) - 0.5f) * 140;
                    Vector2 ctl = { (s.x + tg.x) / 2 - (tg.y - s.y) * side / 300, (s.y + tg.y) / 2 + (tg.x - s.x) * side / 300 - 30 };
                    if (q > 0 && q < 0.7f) { float u = q / 0.7f; Vector2 p = { (1 - u) * (1 - u) * s.x + 2 * (1 - u) * u * ctl.x + u * u * tg.x, (1 - u) * (1 - u) * s.y + 2 * (1 - u) * u * ctl.y + u * u * tg.y };
                        glow_dot(p, 5, ARC); }
                    else if (q >= 0.7f && q < 1) burst(tg, (q - 0.7f) / 0.3f, 18, ARC, f->seed + d * 7);
                } else {
                    if (q > 0 && q < 1) { Vector2 j1 = { (rnd(f->seed + d * 3 + (int)(T * 30)) - 0.5f) * 6, 0 };
                        beam(s, (Vector2){ tg.x + j1.x, tg.y }, 5, FIRE, q < 0.6f ? 1 : (1 - q) / 0.4f);
                        burst(tg, q, 20, FIRE, f->seed + d * 5); }
                }
            }
        } break;
        case 4: {   /* Misty Step: a puff where you vanish and where you appear */
            for (int w2 = 0; w2 < 2; w2++) { Vector2 p = w2 ? g : s; float q = (k - w2 * 0.2f) / 0.8f;
                if (q < 0 || q > 1) continue;
                for (int j = 0; j < 9; j++) { float an = rnd(f->seed + j + w2 * 20) * 2 * PI, d = 8 + 26 * q;
                    DrawCircleGradient((int)(p.x + cosf(an) * d), (int)(p.y + sinf(an) * d - q * 10), 14 * (1 - q * 0.5f), Fade((Color){ 190, 200, 230, 255 }, 0.5f * (1 - q)), BLANK); } }
        } break;
        case 5: {   /* Sleep: a soft shimmer over the area, little z's drifting up */
            DrawRectangleRec(f->area, Fade(ARC, 0.18f * sinf(k * PI)));
            for (int j = 0; j < 10; j++) { float st = rnd(f->seed + j) * 0.5f, q = (k - st) / 0.5f;
                if (q < 0 || q > 1) continue;
                float x = f->area.x + rnd(f->seed + j + 30) * f->area.width, y = f->area.y + f->area.height * 0.7f - q * 50;
                txtb("z", x, y, 14 + 8 * q, Fade((Color){ 220, 200, 255, 255 }, 1 - q)); }
        } break;
        case 6: {   /* Hold Monster: golden chains snap in and a rune ring turns */
            float q = fminf(1, k * 3), fade = k > 0.75f ? (1 - k) / 0.25f : 1;
            for (int j = 0; j < 4; j++) { float an = PI / 4 + j * PI / 2; Vector2 from = { g.x + cosf(an) * 70, g.y + sinf(an) * 70 };
                Vector2 to = lerpv(from, g, q);
                for (int l = 0; l < 6; l++) { Vector2 p = lerpv(from, to, l / 6.0f); DrawRing(p, 3, 5.5f, 0, 360, 10, Fade(GOLDL, fade)); } }
            DrawRing(g, 22, 25, T * 200, T * 200 + 300, 30, Fade(GOLDL, 0.8f * fade));
        } break;
        case 7: {   /* Haste: speed streaks around you */
            for (int j = 0; j < 12; j++) { float x = s.x - 20 + rnd(f->seed + j) * 40, ph = fmodf(k * 3 + rnd(f->seed + j + 9), 1.0f);
                float y = s.y + 20 - ph * 50; DrawLineEx((Vector2){ x, y }, (Vector2){ x, y + 14 }, 2, Fade((Color){ 120, 200, 255, 255 }, 1 - ph)); }
            DrawRing(s, 18 + 10 * k, 21 + 10 * k, 0, 360, 30, Fade((Color){ 120, 200, 255, 255 }, 0.8f * (1 - k)));
        } break;
        case 8: {   /* Ray of Frost: an icy beam and a frost burst */
            float a = k < 0.6f ? 1 : (1 - k) / 0.4f;
            beam(s, g, 6, FROST, a);
            for (int j = 0; j < 8; j++) { Vector2 p = lerpv(s, g, fmodf(rnd(f->seed + j) + k * 2, 1.0f)); DrawPoly(p, 6, 3, T * 90, Fade(WHITE, a)); }
            burst(g, k, 26, FROST, f->seed);
        } break;
        case 9: {   /* Vampiric Touch: red wisps flow from the target into you */
            for (int j = 0; j < 9; j++) { float q = fmodf(k * 1.6f + j / 9.0f, 1.0f); if (k > 0.8f && q > (1 - k) * 5) continue;
                Vector2 p = lerpv(g, s, q); p.y += sinf(q * PI * 2 + j) * 14;
                glow_dot(p, 4, BLOOD); }
            DrawCircleGradient((int)s.x, (int)s.y, 30, Fade(BLOOD, 0.35f * sinf(k * PI)), BLANK);
        } break;
        case 10: {  /* Sunbeam: a golden beam through the line */
            float a = k < 0.15f ? k / 0.15f : k > 0.7f ? (1 - k) / 0.3f : 1, w = 10 + 4 * sinf(T * 30);
            Vector2 dir = { g.x - s.x, g.y - s.y }; float L = sqrtf(dir.x * dir.x + dir.y * dir.y) + 0.01f;
            Vector2 far = { s.x + dir.x / L * fmaxf(L, f->area.width + f->area.height), s.y + dir.y / L * fmaxf(L, f->area.width + f->area.height) };
            {   float lo = MAP_X + TS, hi = MAP_X + (MAP_W - 1) * TS, top = MAP_Y + TS, bot = MAP_Y + (MAP_H - 1) * TS, kk = 1;   /* stop at the walls */
                if (far.x > hi) { kk = fminf(kk, (hi - s.x) / (far.x - s.x)); }
                if (far.x < lo) { kk = fminf(kk, (lo - s.x) / (far.x - s.x)); }
                if (far.y > bot) { kk = fminf(kk, (bot - s.y) / (far.y - s.y)); }
                if (far.y < top) { kk = fminf(kk, (top - s.y) / (far.y - s.y)); }
                far = lerpv(s, far, fmaxf(0, kk)); }
            beam(s, far, w, GOLDL, a);
            for (int j = 0; j < 10; j++) { Vector2 p = lerpv(s, far, rnd(f->seed + j)); DrawCircleV((Vector2){ p.x, p.y - fmodf(k * 60 + j * 7, 30) }, 2, Fade(WHITE, a)); }
        } break;
        case 11: {  /* Ice Storm: hail falling across the area */
            DrawRectangleRec(f->area, Fade(FROST, 0.15f * sinf(k * PI)));
            for (int j = 0; j < 40; j++) { float st = rnd(f->seed + j) * 0.7f, q = (k - st) / 0.3f;
                if (q < 0 || q > 1) continue;
                float x = f->area.x + rnd(f->seed + j + 40) * f->area.width, y = f->area.y + rnd(f->seed + j + 80) * f->area.height;
                Vector2 p = { x - 30 * (1 - q), y - 80 * (1 - q) };
                DrawLineEx((Vector2){ p.x - 6, p.y - 14 }, p, 2, Fade(WHITE, 0.9f)); DrawCircleV(p, 2.5f, FROST);
                if (q > 0.9f) burst((Vector2){ x, y }, (q - 0.9f) * 10, 8, FROST, j); }
        } break;
        case 30: {  /* a skeleton's arrow */
            float q = fminf(1, k / 0.6f); Vector2 p = lerpv(s, g, q), d = { g.x - s.x, g.y - s.y };
            float L = sqrtf(d.x * d.x + d.y * d.y) + 0.01f; Vector2 u = { d.x / L, d.y / L };
            if (q < 1) { DrawLineEx((Vector2){ p.x - u.x * 16, p.y - u.y * 16 }, p, 2.5f, (Color){ 150, 110, 70, 255 });
                DrawTriangle(p, (Vector2){ p.x - u.x * 7 - u.y * 4, p.y - u.y * 7 + u.x * 4 }, (Vector2){ p.x - u.x * 7 + u.y * 4, p.y - u.y * 7 - u.x * 4 }, (Color){ 220, 220, 230, 255 });
                DrawTriangle(p, (Vector2){ p.x - u.x * 7 + u.y * 4, p.y - u.y * 7 - u.x * 4 }, (Vector2){ p.x - u.x * 7 - u.y * 4, p.y - u.y * 7 + u.x * 4 }, (Color){ 220, 220, 230, 255 }); }
            else if (f->n) burst(g, (k - 0.6f) / 0.4f, 14, (Color){ 230, 230, 240, 255 }, f->seed);
        } break;
        case 31: {  /* Altair's lightning */
            float a = k < 0.5f ? 1 : (1 - k) / 0.5f;
            if (k < 0.7f) { bolt(s, g, f->seed + (int)(T * 20), 3.5f, Fade((Color){ 200, 235, 255, 255 }, a)); bolt(s, g, f->seed + 7 + (int)(T * 20), 1.5f, Fade(WHITE, a)); }
            if (f->n) burst(g, k, 30, (Color){ 170, 220, 255, 255 }, f->seed);
        } break;
        case 32: {  /* Smo's slam: shockwave rings from him */
            if (k < 0.1f && set.shake) shake_t = fmaxf(shake_t, 0.35f);
            for (int r = 0; r < 3; r++) { float q = k * 1.3f - r * 0.15f; if (q < 0 || q > 1) continue;
                float rad = 20 + q * 220; DrawRing(s, rad, rad + 6 * (1 - q) + 1, 0, 360, 48, Fade((Color){ 255, 190, 120, 255 }, 0.8f * (1 - q))); }
            for (int j = 0; j < 12; j++) { float an = rnd(f->seed + j) * 2 * PI, d = 30 + 90 * k; DrawCircleV((Vector2){ s.x + cosf(an) * d, s.y + sinf(an) * d - 30 * sinf(k * PI) }, 3, Fade((Color){ 120, 100, 90, 255 }, 1 - k)); }
            if (f->n && k > 0.4f) burst(g, (k - 0.4f) / 0.6f, 26, (Color){ 255, 170, 90, 255 }, f->seed);
        } break;
        case 33: case 34: {  /* the King's bolt / the Unbound's dark orb */
            Color c = f->kind == 33 ? (Color){ 255, 214, 110, 255 } : (Color){ 200, 40, 70, 255 };
            float fl = 0.55f;
            if (k < fl) { float q = k / fl; Vector2 p = lerpv(s, g, q); p.y -= sinf(q * PI) * 30;
                for (int j = 1; j < 5; j++) { float qq = fmaxf(0, q - j * 0.05f); Vector2 pp = lerpv(s, g, qq); pp.y -= sinf(qq * PI) * 30; glow_dot(pp, 6 - j, Fade(c, 1 - j * 0.2f)); }
                glow_dot(p, f->kind == 33 ? 7 : 9, c); }
            else if (f->n) burst(g, (k - fl) / (1 - fl), 32, c, f->seed);
        } break;
        case 20: case 21: {   /* the bishops: four beams converge on you (20 Smite, 21 Judgment) */
            Color bc = f->kind == 20 ? (Color){ 255, 214, 110, 255 } : (Color){ 235, 240, 255, 255 };
            float a = k < 0.2f ? k / 0.2f : k > 0.7f ? (1 - k) / 0.3f : 1;
            for (int j = 0; j < f->n; j++) beam(f->tg[j], s, 4 + 2 * sinf(T * 25 + j), bc, a);
            if (f->kind == 20) burst(s, k, 36, (Color){ 255, 160, 60, 255 }, f->seed);
            else { DrawRing(s, 60 * k, 60 * k + 5, 0, 360, 36, Fade(bc, 1 - k)); DrawRing(s, 40 * k, 40 * k + 3, 0, 360, 36, Fade(bc, 1 - k)); }
        } break;
        case 12: {  /* Cone of Cold: a frost cone fanning out from you */
            Vector2 dir = { ac.x - s.x, ac.y - s.y }; float L = sqrtf(dir.x * dir.x + dir.y * dir.y) + 0.01f, an = atan2f(dir.y, dir.x);
            float reach = (L + fmaxf(f->area.width, f->area.height) * 0.5f) * fminf(1, k * 2.5f), a = k > 0.6f ? (1 - k) / 0.4f : 1;
            for (int j = 0; j < 14; j++) { float a1 = an - 0.55f + 1.1f * j / 14, a2 = an - 0.55f + 1.1f * (j + 1) / 14;
                Vector2 p1 = { s.x + cosf(a1) * reach, s.y + sinf(a1) * reach }, p2 = { s.x + cosf(a2) * reach, s.y + sinf(a2) * reach };
                DrawTriangle(s, p2, p1, Fade(FROST, 0.28f * a)); DrawTriangle(s, p1, p2, Fade(FROST, 0.28f * a)); }
            for (int j = 0; j < 20; j++) { float aa = an - 0.5f + rnd(f->seed + j) * 1.0f, d = reach * rnd(f->seed + j + 20);
                DrawPoly((Vector2){ s.x + cosf(aa) * d, s.y + sinf(aa) * d }, 6, 3, T * 120, Fade(WHITE, a)); }
        } break;
        }
    }
}

static void draw_fx(float dt) {
    static int fx_floor = -1;
    static TorchPos last_t[8]; static int last_n = -1, last_floor = -1;
    if (S.floor != fx_floor) { memset(fx, 0, sizeof fx); fx_floor = S.floor; }
    if (shake_t > 0) shake_t -= dt;
    {   /* the Warden's torches jumped: beam them */
        TorchPos now[8]; int n = find_torches(now, 8), moved = 0;
        if (S.floor == last_floor && n == last_n && n > 0 && n <= 4) for (int i = 0; i < n; i++) if (now[i].c != last_t[i].c || now[i].r != last_t[i].r) moved = 1;
        if (moved && map_has('M')) {
            laser_n = n;
            for (int i = 0; i < n; i++) {
                laser_old[i] = (Vector2){ MAP_X + (last_t[i].c + 1) * TS + TS / 2.0f, MAP_Y + last_t[i].r * TS + TS / 2.0f };
                laser_new[i] = (Vector2){ MAP_X + (now[i].c + 1) * TS + TS / 2.0f, MAP_Y + now[i].r * TS + TS / 2.0f };
            }
            fx_add(FX_LASER, 0);
        }
        memcpy(last_t, now, sizeof now); last_n = n; last_floor = S.floor;
    }
    for (int i = 0; i < 8; i++) {
        Fx *f = &fx[i];
        if (!f->kind) continue;
        if (f->delay > 0) { f->delay -= dt; continue; }
        f->t += dt;
        Vector2 pl = player_px();
        Rectangle b;
        if (f->kind <= FX_METEOR) {                       /* Ymir's spells fly from his orb to you */
            if (!boss_rect("Y", &b) || pl.x < 0) { f->kind = 0; continue; }
            float fly = f->kind == FX_BOLT ? 0.3f : f->kind == FX_METEOR ? 0.7f : 0.6f, sc = b.width / 32;
            Vector2 a = f->kind == FX_METEOR ? (Vector2){ pl.x - 160, MAP_Y - 60 } : (Vector2){ b.x + 28 * sc, b.y + 5.5f * sc };
            Color col = f->kind == FX_FIRE ? C_EMBER : f->kind == FX_FROST ? C_ICE : f->kind == FX_BOLT ? (Color){ 220, 240, 255, 255 } : (Color){ 255, 90, 30, 255 };
            float big = f->kind == FX_METEOR ? 2.0f : 1.0f;
            if (f->t < fly) {
                float k = f->t / fly;
                if (f->kind != FX_METEOR) DrawCircleGradient((int)a.x, (int)a.y, 26, Fade(col, 0.7f * (1 - k)), BLANK);   /* the cast flash */
                if (f->kind == FX_BOLT) { bolt(a, pl, i, 4, col); bolt(a, pl, i + 9, 2, WHITE); }
                else {
                    k = k * k * (3 - 2 * k);
                    Vector2 p = { a.x + (pl.x - a.x) * k, a.y + (pl.y - a.y) * k };
                    for (int s2 = 1; s2 <= 10; s2++) { float kk = k - s2 * 0.025f; if (kk < 0) break;   /* the trail */
                        DrawCircle((int)(a.x + (pl.x - a.x) * kk + (rnd(s2 + i * 20 + (int)(T * 30)) - 0.5f) * 6),
                                   (int)(a.y + (pl.y - a.y) * kk + (rnd(s2 * 3 + i * 20 + (int)(T * 30)) - 0.5f) * 6), (11 - s2) * big, Fade(col, 0.6f - s2 * 0.05f)); }
                    DrawCircleGradient((int)p.x, (int)p.y, 30 * big, Fade(col, 0.85f), BLANK);
                    DrawCircle((int)p.x, (int)p.y, 9 * big, col);
                    DrawCircle((int)p.x, (int)p.y, 5 * big, WHITE);
                    if (f->kind == FX_FROST) for (int s2 = 0; s2 < 4; s2++) { float an = s2 * PI / 2 + T * 6;
                        DrawLineEx(p, (Vector2){ p.x + cosf(an) * 16, p.y + sinf(an) * 16 }, 2, (Color){ 230, 250, 255, 255 }); }
                }
            } else if (f->t < fly + 0.45f) {
                float k = (f->t - fly) / 0.45f, rad = 48 * big;
                DrawCircleGradient((int)pl.x, (int)pl.y, rad * (0.5f + k), Fade(col, 0.85f * (1 - k)), BLANK);
                DrawRing(pl, rad * k, rad * k + 4, 0, 360, 32, Fade(col, 1 - k));
                for (int s2 = 0; s2 < 10; s2++) { float an = s2 * PI / 5 + i;
                    DrawCircle((int)(pl.x + cosf(an) * rad * k * 1.2f), (int)(pl.y + sinf(an) * rad * k * 1.2f), 4 * big, Fade(col, 1 - k)); }
            } else f->kind = 0;
        } else if (f->kind == FX_SHATTER || f->kind == FX_REWARD) {   /* the ward bursts, or forms again */
            if (!boss_rect("Jj", &b)) { f->kind = 0; continue; }
            float k = f->t / 0.9f, cx = b.x + b.width / 2, cy = b.y + b.height / 2;
            if (k >= 1) { f->kind = 0; continue; }
            if (f->kind == FX_SHATTER) for (int s = 0; s < 18; s++) {
                float an = s * PI / 9 + rnd(s), d = b.width * (0.66f + k * 0.9f);
                Vector2 p = { cx + cosf(an) * d, cy + sinf(an) * d * 0.9f };
                DrawTriangle(p, (Vector2){ p.x + 6, p.y + 3 }, (Vector2){ p.x + 2, p.y - 6 }, Fade(C_TEAL, 1 - k));
            } else {
                float d = b.width * (1.6f - k * 0.94f);
                DrawEllipseLines((int)cx, (int)cy, d, d, Fade(C_TEAL, k));
                DrawEllipseLines((int)cx, (int)cy, d + 2, d + 2, Fade(C_TEAL, k * 0.5f));
            }
        } else if (f->kind == FX_WAVE) {                  /* Ymir's blue wave rolls across the room */
            float k = f->t / 1.4f;
            if (k >= 1 || !boss_rect("Y", &b)) { f->kind = 0; continue; }
            Vector2 c0 = { b.x + b.width / 2, b.y + b.height / 2 };
            for (int s2 = 0; s2 < 3; s2++) { float kk = k - s2 * 0.08f; if (kk <= 0) continue;
                DrawRing(c0, 1700 * kk * 0.9f, 1700 * kk * 0.9f + 22, 0, 360, 96, Fade(C_ICE, 0.55f * (1 - kk))); }
            DrawCircleGradient((int)c0.x, (int)c0.y, 180, Fade(C_ICE, 0.6f * (1 - k)), BLANK);
        } else if (f->kind == FX_SLAM) {                  /* the King slams the throne: a gold shock ring */
            float k = f->t / 0.9f;
            if (k >= 1 || !boss_rect("K", &b)) { f->kind = 0; continue; }
            Vector2 c0 = { b.x + b.width / 2, b.y + b.height };
            DrawRing(c0, 900 * k, 900 * k + 14, 0, 360, 96, Fade(C_GOLD, 0.7f * (1 - k)));
        } else if (f->kind == FX_LANTERN) {
            float k = f->t / 1.0f;
            if (k >= 1) { f->kind = 0; continue; }
            DrawRectangle(MAP_X, MAP_Y, MAP_W * TS, MAP_H * TS, Fade((Color){ 255, 220, 150, 255 }, 0.45f * (1 - k)));
        } else if (f->kind == FX_LASER) {                 /* the Warden's beam throws the torches across the room */
            float k = f->t / 1.3f;
            if (k >= 1 || !boss_rect("MBAVX", &b)) { f->kind = 0; continue; }
            Vector2 eye = { b.x + b.width / 2, b.y + 22 };
            for (int i = 0; i < laser_n; i++) {
                Vector2 tgt = k < 0.5f ? laser_old[i] : laser_new[i];
                float a = k < 0.5f ? 1 - fabsf(k - 0.25f) * 4 : 1 - fabsf(k - 0.75f) * 4;
                if (a <= 0) continue;
                DrawLineEx(eye, tgt, 12, Fade(C_RED, 0.25f * a));
                DrawLineEx(eye, tgt, 4, Fade((Color){ 255, 90, 90, 255 }, a));
                DrawLineEx(eye, tgt, 1.5f, Fade(WHITE, a));
                DrawCircleGradient((int)tgt.x, (int)tgt.y, 30, Fade(k < 0.5f ? C_RED : C_GOLD, a), BLANK);
            }
            DrawCircleGradient((int)eye.x, (int)eye.y, 20, Fade(C_RED, 0.9f), BLANK);
        } else if (f->kind == FX_LEVEL) {                 /* a golden column of light on you */
            float k = f->t / 1.6f;
            if (k >= 1 || pl.x < 0) { if (k >= 1) f->kind = 0; continue; }
            float a = k < 0.2f ? k / 0.2f : 1 - (k - 0.2f) / 0.8f;
            DrawRectangleGradientV((int)pl.x - 18, MAP_Y, 36, (int)(pl.y - MAP_Y + 16), Fade(C_GOLD, 0), Fade(C_GOLD, 0.55f * a));
            DrawCircleGradient((int)pl.x, (int)pl.y, 60, Fade(C_GOLD, 0.6f * a), BLANK);
            for (int s2 = 0; s2 < 12; s2++) {
                float an = s2 * PI / 6 + T * 2, d = 20 + k * 50;
                DrawCircle((int)(pl.x + cosf(an) * d), (int)(pl.y + sinf(an) * d - k * 30), 3, Fade(C_GOLD, a));
            }
            char lvt[24]; snprintf(lvt, sizeof lvt, "LEVEL %d", S.level);
            txt_c(lvt, pl.x, pl.y - 70 - k * 30, 30, Fade(C_GOLD, a), 1);
        } else if (f->kind == FX_RISE) {                  /* the survivor flares up */
            int found = boss_rect("t", &b) || boss_rect("u", &b);
            float k = f->t / 1.0f;
            if (!found || k >= 1) { f->kind = 0; continue; }
            Color col = map_has('t') ? C_ICE : C_EMBER;
            DrawCircleGradient((int)(b.x + b.width / 2), (int)(b.y + b.height / 2), b.width * (0.5f + 1.5f * k), Fade(col, 0.7f * (1 - k)), BLANK);
            DrawRectangle((int)b.x, (int)(b.y - 400 * (1 - k)), (int)b.width, (int)(400 * (1 - k)) + (int)b.height, Fade(WHITE, (set.calm ? 0.08f : 0.25f) * (1 - k)));
        }
    }
}

/* ---- circuits: wires and gates ---- */
static int is_wire(char c) { return c == '-' || c == '=' || c == ':' || c == '|'; }
static int wire_on(char c) { return c == '=' || c == '|'; }
static int is_gate_edge(char c) { return c == '%' || c == '$'; }
static int is_gate_mid(int c, int r) {                    /* the centre of a 3x3 gate block */
    return is_gate_edge(mc(c - 1, r)) && is_gate_edge(mc(c + 1, r)) && is_gate_edge(mc(c, r - 1)) && is_gate_edge(mc(c, r + 1))
        && strchr("AVXavEN?L", mc(c, r)) && mc(c, r) != 0;
}
static int part_of_gate(int c, int r) {
    for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) if (is_gate_mid(c + dx, r + dy)) return 1;
    return 0;
}
/* a wire may run under someone standing on it: guess it from the neighbours */
static int wire_here(int c, int r, int *on) {
    char ch = mc(c, r);
    if (is_wire(ch)) { *on = wire_on(ch); return 1; }
    if (ch == '.' || ch == '#' || ch == ' ' || is_gate_edge(ch) || part_of_gate(c, r)) return 0;
    int n = 0, lit = 0, dx[4] = { 1, -1, 0, 0 }, dy[4] = { 0, 0, 1, -1 };
    int ends = 0;   /* a wire end touches a torch on its left or a gate / door on its right */
    for (int k = 0; k < 4; k++) { char nb = mc(c + dx[k], r + dy[k]); if (is_wire(nb)) { n++; lit |= wire_on(nb); } }
    if (mc(c - 1, r) == ']' || (is_gate_edge(mc(c - 1, r)) && part_of_gate(c - 1, r))) ends++;
    if (mc(c + 1, r) == '<' || mc(c + 1, r) == '>' || mc(c + 1, r) == '[' || mc(c + 1, r) == 'K' || (is_gate_edge(mc(c + 1, r)) && part_of_gate(c + 1, r))) ends++;
    if (n >= 2 || (n == 1 && ends == 1)) { *on = lit; return 1; }
    return 0;
}
static Color WIRE_OFF = { 78, 86, 108, 255 }, WIRE_ON = { 255, 196, 80, 255 };
static void draw_wire(int c, int r) {
    int on;
    if (!wire_here(c, r, &on)) return;
    Rectangle t = tile(c, r);
    Vector2 m = { t.x + TS / 2.0f, t.y + TS / 2.0f };
    int dx[4] = { 1, -1, 0, 0 }, dy[4] = { 0, 0, 1, -1 }, links = 0;
    for (int k = 0; k < 4; k++) {
        int nc = c + dx[k], nr = r + dy[k], o;
        char nb = mc(nc, nr);
        int link = wire_here(nc, nr, &o) || (is_gate_edge(nb) && part_of_gate(nc, nr))
                || (k == 1 && nb == ']') || (k == 0 && (nb == '<' || nb == '>' || nb == '[' || nb == 'K'));
        if (!link) continue;
        links++;
        Vector2 e = { m.x + dx[k] * TS / 2.0f, m.y + dy[k] * TS / 2.0f };
        if (set.cb) {                                       /* colourblind: powered = thick bright bar with white ticks, unpowered = dotted */
            if (on) {
                DrawLineEx(m, e, 7, (Color){ 255, 214, 60, 255 });
                Vector2 q = { (m.x + e.x) / 2, (m.y + e.y) / 2 };
                DrawRectangle((int)q.x - 2, (int)q.y - 2, 4, 4, WHITE);
            } else for (int d = 1; d <= 3; d++) {
                Vector2 q = { m.x + (e.x - m.x) * d / 3.5f, m.y + (e.y - m.y) * d / 3.5f };
                DrawCircleV(q, 2, (Color){ 120, 140, 190, 255 });
            }
            continue;
        }
        if (on) DrawLineEx(m, e, 10, Fade(WIRE_ON, 0.18f));
        DrawLineEx(m, e, on ? 4 : 3, on ? WIRE_ON : WIRE_OFF);
    }
    if (set.cb) { if (on) DrawCircleV(m, 5, WHITE); else DrawRing(m, 3, 5, 0, 360, 12, (Color){ 120, 140, 190, 255 }); }
    else DrawCircleV(m, on ? 3.5f : 2.5f, on ? (Color){ 255, 236, 170, 255 } : WIRE_OFF);
    if (on && links) {                                     /* a spark running along powered wire */
        float ph = fmodf(T * 2 + (c + r) * 0.25f, 1.0f);
        if (ph < 0.25f) DrawCircleV(m, 5 * (1 - ph * 4), Fade(WHITE, 0.8f * (1 - ph * 4)));
    }
}
static void quad_curve(Vector2 a, Vector2 ctl, Vector2 b, float th, Color col, Vector2 *pts, int *np) {
    Vector2 prev = a;
    for (int i = 1; i <= 14; i++) {
        float t = i / 14.0f, u = 1 - t;
        Vector2 q = { u * u * a.x + 2 * u * t * ctl.x + t * t * b.x, u * u * a.y + 2 * u * t * ctl.y + t * t * b.y };
        if (th > 0) DrawLineEx(prev, q, th, col);
        if (pts) pts[(*np)++] = q;
        prev = q;
    }
}
static void fill_shape(Vector2 *p, int n, Vector2 ctr, Color col) {
    for (int i = 0; i < n; i++) {
        Vector2 a = p[i], b = p[(i + 1) % n];
        DrawTriangle(ctr, a, b, col); DrawTriangle(ctr, b, a, col);   /* both windings: one of them shows */
    }
}
static void draw_lantern(int c, int r);
static void draw_gate(int c, int r) {
    char g = mc(c, r);
    if (g == 'L') { draw_lantern(c, r); return; }
    int out = mc(c - 1, r - 1) == '$';
    /* which way it faces: inputs normally come from the left; boss rooms also use right, top and bottom */
    int ang = 0;
    if (is_wire(mc(c + 2, r - 1)) || is_wire(mc(c + 2, r + 1))) ang = 180;
    else if (is_wire(mc(c - 1, r - 2)) || is_wire(mc(c + 1, r - 2))) ang = 90;
    else if (is_wire(mc(c - 1, r + 2)) || is_wire(mc(c + 1, r + 2))) ang = -90;
    Rectangle B = { MAP_X + (c - 1) * TS, MAP_Y + (r - 1) * TS, 3 * TS, 3 * TS };
    Color line = out ? WIRE_ON : (Color){ 170, 178, 200, 255 }, fill = out ? Fade(WIRE_ON, 0.30f) : Fade((Color){ 120, 130, 160, 255 }, 0.10f);
    DrawRectangleRounded((Rectangle){ B.x + 3, B.y + 6, B.width - 6, B.height - 6 }, 0.18f, 8, Fade(BLACK, 0.45f));
    DrawRectangleRounded((Rectangle){ B.x + 3, B.y + 3, B.width - 6, B.height - 6 }, 0.18f, 8, (Color){ 30, 32, 44, 255 });
    DrawRectangleRoundedLinesEx((Rectangle){ B.x + 3, B.y + 3, B.width - 6, B.height - 6 }, 0.18f, 8, 2, out ? Fade(WIRE_ON, 0.8f) : (Color){ 64, 70, 90, 255 });
    if (out) DrawCircleGradient((int)(B.x + 48), (int)(B.y + 48), 70, Fade(WIRE_ON, 0.16f), BLANK);
    float sx = B.x + 26, sy = B.y + 28, w = 40, h = 40, cy = B.y + 48;
    rlPushMatrix();
    rlTranslatef(B.x + 48, B.y + 48, 0); rlRotatef((float)ang, 0, 0, 1); rlTranslatef(-(B.x + 48), -(B.y + 48), 0);
    int bubble = g == 'a' || g == 'v' || g == 'E' || g == 'N';
    float bw = bubble ? w - 9 : w;                         /* leave room for the inverting bubble */
    /* input stubs, coloured by what arrives: look at the wire just outside the block */
    int one_input = g == 'N';
    for (int k = 0; k < (one_input ? 1 : 2); k++) {
        int ly = one_input ? 0 : (k == 0 ? -1 : 1), on2 = 0;
        int scc = ang == 0 ? c - 2 : ang == 180 ? c + 2 : ang == 90 ? c - ly : c + ly;      /* the cell just outside this input */
        int srr = ang == 0 ? r + ly : ang == 180 ? r - ly : ang == 90 ? r - 2 : r + 2;
        char nb = mc(scc, srr);
        if (is_wire(nb)) on2 = wire_on(nb); else if (nb == ']') on2 = mc(scc - 1, srr) == '1'; else if (nb == '[') on2 = mc(scc + 1, srr) == '1'; else wire_here(scc, srr, &on2);
        float yy = B.y + (ly + 1) * TS + TS / 2.0f, ty = one_input ? cy : (k == 0 ? sy + 10 : sy + 30);
        Color sc = on2 ? WIRE_ON : WIRE_OFF;
        DrawLineEx((Vector2){ B.x, yy }, (Vector2){ B.x + 12, yy }, on2 ? 4 : 3, sc);
        DrawLineEx((Vector2){ B.x + 12, yy }, (Vector2){ sx + 4, ty }, on2 ? 4 : 3, sc);
    }
    DrawLineEx((Vector2){ sx + w, cy }, (Vector2){ B.x + B.width, cy }, out ? 4 : 3, out ? WIRE_ON : WIRE_OFF);   /* output */
    Vector2 pts[80]; int np = 0;
    const char *label = "";
    if (g == 'A' || g == 'a') {                            /* AND: a D shape */
        label = g == 'A' ? "AND" : "NAND";
        float rad = h / 2, ax = sx + bw - rad;
        pts[np++] = (Vector2){ sx, sy }; pts[np++] = (Vector2){ ax, sy };
        for (int i = 0; i <= 16; i++) { float an = -PI / 2 + PI * i / 16; pts[np++] = (Vector2){ ax + cosf(an) * rad, cy + sinf(an) * rad }; }
        pts[np++] = (Vector2){ sx, sy + h };
        fill_shape(pts, np, (Vector2){ sx + bw * 0.45f, cy }, fill);
        for (int i = 0; i < np; i++) DrawLineEx(pts[i], pts[(i + 1) % np], 3, line);
    } else if (g == 'V' || g == 'v' || g == 'X' || g == 'E') {   /* OR family: a shield shape */
        label = g == 'V' ? "OR" : g == 'v' ? "NOR" : g == 'X' ? "XOR" : "XNOR";
        Vector2 tl = { sx, sy }, bl = { sx, sy + h }, tip = { sx + bw, cy };
        pts[np++] = bl;
        quad_curve(bl, (Vector2){ sx + w * 0.28f, cy }, tl, 0, line, pts, &np);
        quad_curve(tl, (Vector2){ sx + bw * 0.62f, sy }, tip, 0, line, pts, &np);
        quad_curve(tip, (Vector2){ sx + bw * 0.62f, sy + h }, bl, 0, line, pts, &np);
        fill_shape(pts, np, (Vector2){ sx + bw * 0.5f, cy }, fill);
        for (int i = 0; i < np - 1; i++) DrawLineEx(pts[i], pts[i + 1], 3, line);
        if (g == 'X' || g == 'E') quad_curve((Vector2){ sx - 7, sy + h }, (Vector2){ sx - 7 + w * 0.28f, cy }, (Vector2){ sx - 7, sy }, 3, line, NULL, NULL);
    } else if (g == 'N') {                                 /* NOT: a triangle */
        label = "NOT";
        pts[np++] = (Vector2){ sx, sy + 4 }; pts[np++] = (Vector2){ sx + bw, cy }; pts[np++] = (Vector2){ sx, sy + h - 4 };
        fill_shape(pts, np, (Vector2){ sx + bw * 0.35f, cy }, fill);
        for (int i = 0; i < np; i++) DrawLineEx(pts[i], pts[(i + 1) % np], 3, line);
    } else {                                               /* the hidden gate */
        label = "???";
        Rectangle q = { sx, sy, w, h };
        DrawRectangleRounded(q, 0.25f, 6, fill);
        DrawRectangleRoundedLinesEx(q, 0.25f, 6, 3, line);
    }
    if (bubble) { DrawCircleV((Vector2){ sx + bw + 4.5f, cy }, 5, (Color){ 30, 32, 44, 255 }); DrawRing((Vector2){ sx + bw + 4.5f, cy }, 3.5f, 6, 0, 360, 20, line); }
    rlPopMatrix();
    if (g == '?') txt_c("?", sx + w / 2, sy + 3, 34, out ? WIRE_ON : C_PURPLE, 1);   /* (upright, whichever way the gate faces) */
    txt_c(label, B.x + 48, ang == -90 ? B.y + B.height - 22 : B.y + 7, 15, out ? WIRE_ON : C_DIM, 1);
    /* the value it outputs */
    Rectangle v = { B.x + B.width - 26, B.y + B.height - 26, 20, 20 };
    DrawRectangleRounded(v, 0.4f, 6, out ? WIRE_ON : (Color){ 60, 64, 80, 255 });
    txt_c(out ? "1" : "0", v.x + 10, v.y + 2, 15, out ? (Color){ 60, 30, 0, 255 } : C_TEXT, 1);
}

static Vector2 lerp2(Vector2 a, Vector2 b, float k) { return (Vector2){ a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k }; }
static void draw_bishops(void) {                           /* the Four Bishops: the square, its gates, the bishops */
    int bc[4], br[4], n = 0;
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++)
        if (mc(c, r) == 'P' && mc(c - 1, r) != 'P' && mc(c, r - 1) != 'P' && n < 4) { bc[n] = c; br[n] = r; n++; }
    if (!n) return;
    int nb = n, uform = unbound_mode_char() == 'q';           /* the Unbound's Bishop form: he is the fourth corner */
    Rectangle zb;
    if (uform && n < 4 && boss_rect("Zq", &zb)) { bc[n] = (int)((zb.x - MAP_X) / TS); br[n] = (int)((zb.y - MAP_Y) / TS); n++; }
    Vector2 ctr[4]; int corner[4] = { -1, -1, -1, -1 };     /* TL, TR, BR, BL */
    for (int i = 0; i < n; i++) {
        ctr[i] = (Vector2){ MAP_X + (bc[i] + 1) * TS, MAP_Y + (br[i] + 1) * TS };
        int right = bc[i] > MAP_W / 2, low = br[i] > MAP_H / 2;
        corner[right ? (low ? 2 : 1) : (low ? 3 : 0)] = i;
    }
    if (S.floor == 12 || uform) for (int k = 0; k < 4; k++) {          /* the yellow square */
        int a = corner[k], b = corner[(k + 1) % 4];
        if (a < 0 || b < 0) continue;
        DrawLineEx(ctr[a], ctr[b], 9, Fade(C_GOLD, 0.14f));
        DrawLineEx(ctr[a], ctr[b], 3, Fade(C_GOLD, 0.85f));
        for (int d = 0; d < 3; d++) { float f = fmodf(T * 0.4f + d / 3.0f, 1.0f); DrawCircleV(lerp2(ctr[a], ctr[b], f), 3.5f, C_GOLD); }
    }
    if (S.floor == 12 || uform) for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) {   /* the gates on the square */
        char g = mc(c, r);
        if (!gate_truth(g) || !strchr("AVXavE", g)) continue;
        Vector2 p = { MAP_X + c * TS + TS / 2.0f, MAP_Y + r * TS + TS / 2.0f };
        Rectangle pd = { p.x - 40, p.y - 24, 80, 48 };
        DrawRectangleRounded((Rectangle){ pd.x + 3, pd.y + 4, pd.width, pd.height }, 0, 0, Fade(BLACK, 0.5f));
        DrawRectangleRounded(pd, 0, 0, (Color){ 40, 34, 18, 245 });
        DrawRectangleRoundedLinesEx(pd, 0, 0, 2, C_GOLD);
        gate_icon(g, p.x - 18, p.y - 2, 22, (Color){ 255, 236, 180, 255 }, Fade(C_GOLD, 0.3f));
        txt_c(gate_name(g), p.x + 20, p.y - 9, 15, C_GOLD, 1);
    }
    for (int i = 0; i < nb; i++) {                          /* the bishops: all alike (those on the right face left) */
        float x = MAP_X + bc[i] * TS, y = MAP_Y + br[i] * TS, bob = sinf(T * 1.5f + i) * 1.5f;
        int fl = bc[i] > MAP_W / 2;
        #define BX(px) (fl ? 32 - (px) : (px))
        DrawEllipse((int)(x + TS), (int)(y + 2 * TS - 4), 34, 7, Fade(BLACK, 0.5f));
        float sc = 3, sx = x + TS - 16 * sc, sy = y + 2 * TS - 32 * sc + bob;     /* 96 px tall, standing on its two tiles */
        DrawCircleGradient((int)(x + TS), (int)(y + TS), 70, Fade((Color){ 120, 10, 30, 255 }, 0.22f + 0.06f * sinf(T * 2 + i)), BLANK);
        for (int k = 0; k < 8; k++) {                       /* smoke from the censer */
            float ph = fmodf(T * 0.45f + rnd(i * 20 + k), 1.0f);
            DrawCircle((int)(sx + BX(5) * sc + sinf(T * 1.5f + k) * 5 + (fl ? -ph : ph) * 8), (int)(sy + 25 * sc - ph * 60), 5 * (1 - ph) + 2, Fade((Color){ 150, 140, 150, 255 }, 0.35f * (1 - ph)));
        }
        DrawRing((Vector2){ sx + 16 * sc, sy + 1 * sc }, 16, 18, 0, 360, 28, Fade((Color){ 200, 225, 255, 255 }, 0.55f + 0.2f * sinf(T * 3 + i)));   /* a cold halo */
        if (fl) sprite_flip(SPR_BISHOP, 32, sx, sy, sc, WHITE); else sprite(SPR_BISHOP, 32, sx, sy, sc, WHITE, 0);
        for (int e = 0; e < 2; e++) DrawCircleGradient((int)(sx + BX(e ? 17.5f : 15.5f) * sc), (int)(sy + 9.5f * sc), 5, Fade(WHITE, 0.85f), BLANK);   /* the eyes */
        #undef BX
    }
}

static void draw_heads(void) {                             /* little icons over heads: the fighter's tricks, enemies' ailments */
    static const char LET[12] = { 0, 'b', 'z', 'H', 0, 0, 's', 'p', 0, 'B', 'v', 'f' };
    for (int i = 0; i < 6; i++) {
        EnemyHead *e = &nst[i];
        if (!e->alive || !e->bits) continue;
        int n = 0; for (int b = 1; b < 12; b++) if ((e->bits >> b & 1) && LET[b]) n++;
        if (!n) continue;
        float s = 18, cx = MAP_X + (e->x + 1 + e->w / 2.0f) * TS, y = MAP_Y + (e->y + 1) * TS - s - 4, x = cx - (n * (s + 3) - 3) / 2;
        for (int b = 1; b < 12; b++) if ((e->bits >> b & 1) && LET[b]) {
            DrawRectangleRec((Rectangle){ x - 1, y - 1, s + 2, s + 2 }, Fade(BLACK, 0.5f));
            status_icon(LET[b], x, y + sinf(T * 3 + b) * 1.2f, s); x += s + 3;
        }
    }
    if (!(fst.parry || fst.rally || fst.surge || fst.man) || S.cls[0] != 'F') return;
    Vector2 me = player_px(); if (me.x < 0) return;
    int n = (fst.parry > 0) + (fst.rally > 0) + (fst.surge > 0) + (fst.man > 0);
    float s = 18, x = me.x - (n * (s + 3) - 3) / 2, y = me.y - TS / 2.0f - s - 6 + sinf(T * 3) * 1.2f;
    #define HEADBOX(col) do { DrawRectangleRec((Rectangle){ x - 1, y - 1, s + 2, s + 2 }, Fade(BLACK, 0.5f)); DrawRectangleRounded((Rectangle){ x, y, s, s }, 0.3f, 6, col); } while (0)
    if (fst.parry) { HEADBOX(((Color){ 70, 90, 130, 255 }));               /* a shield */
        Vector2 a = { x + 4, y + 4 }, b = { x + s - 4, y + 4 }, c = { x + s / 2, y + s - 3 };
        DrawTriangle(a, c, b, (Color){ 220, 228, 240, 255 }); DrawRectangleRec((Rectangle){ x + 4, y + 3, s - 8, 4 }, (Color){ 220, 228, 240, 255 }); x += s + 3; }
    if (fst.rally) { HEADBOX(((Color){ 50, 130, 70, 255 }));               /* a green cross: temporary HP */
        DrawRectangleRec((Rectangle){ x + s / 2 - 2, y + 4, 4, s - 8 }, WHITE); DrawRectangleRec((Rectangle){ x + 4, y + s / 2 - 2, s - 8, 4 }, WHITE);
        char b[8]; snprintf(b, sizeof b, "%d", fst.rally); txtb(b, x + s - 4, y + s - 8, 11, (Color){ 170, 255, 170, 255 }); x += s + 3; }
    if (fst.surge) { HEADBOX(((Color){ 150, 100, 30, 255 }));              /* crossed swords */
        DrawLineEx((Vector2){ x + 3, y + 3 }, (Vector2){ x + s - 3, y + s - 3 }, 2.5f, (Color){ 255, 230, 160, 255 });
        DrawLineEx((Vector2){ x + s - 3, y + 3 }, (Vector2){ x + 3, y + s - 3 }, 2.5f, (Color){ 255, 230, 160, 255 }); x += s + 3; }
    if (fst.man) { HEADBOX(((Color){ 120, 70, 150, 255 }));                /* a die: a maneuver is ready */
        DrawPoly((Vector2){ x + s / 2, y + s / 2 }, 6, s * 0.4f, 0, (Color){ 240, 220, 255, 255 });
        txtb("8", x + s / 2 - 3, y + 3, 11, (Color){ 80, 40, 110, 255 }); x += s + 3; }
}

static void draw_map(void) {
    Rectangle frame = { MAP_X - 8, MAP_Y - 5, MAP_W * TS + 16, MAP_H * TS + 13 };   /* a carved stone frame */
    DrawRectangleRounded((Rectangle){ frame.x + 4, frame.y + 7, frame.width, frame.height }, 0, 0, Fade(BLACK, 0.6f));
    DrawRectangleRounded(frame, 0, 0, (Color){ 52, 54, 60, 255 });
    bevel(frame, 3, (Color){ 96, 100, 108, 255 }, C_SH);
    DrawRectangleRoundedLinesEx(frame, 0, 0, 1, C_SH);
    for (int r = 0; r < MAP_H; r++) for (int c = 0; c < MAP_W; c++) {
        Rectangle t = tile(c, r);
        if (mc(c, r) == '#') wall_tile(t.x, t.y, r * 7 + c); else floor_tile(t.x, t.y, r * 31 + c);
    }
    rivet(frame.x + 5, frame.y + 4); rivet(frame.x + frame.width - 5, frame.y + 4);
    rivet(frame.x + 5, frame.y + frame.height - 5); rivet(frame.x + frame.width - 5, frame.y + frame.height - 5);
    /* overlays: the walking path (footprints) and spell areas, from the game's notes */
    if (pv_kind == 1) {
        int pc = -1, pr = -1;
        for (int r = 1; r < MAP_H - 1 && pc < 0; r++) for (int c = 1; c < MAP_W - 1; c++) if (mc(c, r) == '@') { pc = c; pr = r; break; }
        int combat = S.mode == M_FIGHT_YOU || S.mode == M_TB_YOU;
        for (int i = 0; pc >= 0 && pv_path[i]; i++) {
            int d = pv_path[i] - '0';
            pc += (d == 3 || d == 6 || d == 9) - (d == 1 || d == 4 || d == 7);
            pr += (d == 1 || d == 2 || d == 3) - (d == 7 || d == 8 || d == 9);
            Rectangle t = tile(pc, pr);
            int far = combat && S.move >= 0 && i + 1 > S.move, last = !pv_path[i + 1];
            Color col = far ? C_RED : (Color){ 150, 200, 255, 255 };
            float ox = (i & 1) ? 5 : -5;                        /* left, right, left: footprints */
            if (last) {
                DrawRing((Vector2){ t.x + TS / 2, t.y + TS / 2 }, 9, 12, 0, 360, 24, Fade(col, 0.85f));
                DrawCircle((int)(t.x + TS / 2), (int)(t.y + TS / 2), 3, col);
            } else {
                DrawEllipse((int)(t.x + TS / 2 + ox), (int)(t.y + TS / 2 - 3), 3.2f, 4.6f, Fade(col, 0.8f));     /* sole */
                DrawEllipse((int)(t.x + TS / 2 + ox), (int)(t.y + TS / 2 + 6), 2.4f, 2.6f, Fade(col, 0.8f));     /* heel */
            }
        }
    }
    if (pv_kind == 2) {
        Color fill = pv_valid ? (Color){ 255, 140, 40, 255 } : C_RED;
        for (int i = 0; i < pv_aw * pv_ah; i++) if (pv_bits[i]) {
            Rectangle t = tile(pv_ax + i % pv_aw + 1, pv_ay + i / pv_aw + 1);
            DrawRectangleRec(t, Fade(fill, 0.26f + 0.08f * sinf(T * 5)));
        }
    }
    /* circuits: wires first, then the gates on top */
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) draw_wire(c, r);
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (is_gate_mid(c, r)) draw_gate(c, r);
    /* objects */
    for (int r = 0; r < MAP_H; r++) for (int c = 0; c < MAP_W; c++) {
        Rectangle t = tile(c, r); char ch = mc(c, r);
        float bob = sinf(T * 3 + c * 0.7f + r) * 1.5f;
        if ((ch == '0' || ch == '1') && mc(c - 1, r) == '[' && mc(c + 1, r) == ']') {          /* a torch: "[0]" or "[1]" */
            int lit = ch == '1';
            float bx = t.x - 8, by = t.y - 16;                                                  /* a 48x48 brazier, standing on its tile */
            DrawEllipse((int)(t.x + TS / 2), (int)(t.y + TS - 2), 16, 4, Fade(BLACK, 0.5f));
            if (lit) DrawCircleGradient((int)(t.x + TS / 2), (int)(t.y + 4), TS * 2.0f, Fade((Color){ 255, 160, 60, 255 }, 0.22f), BLANK);
            sprite(SPR_BRAZIER, 16, bx, by, 3, WHITE, 0);
            if (lit) flame(t.x + TS / 2, by + 26, 11, T + c);
            else for (int k = 0; k < 5; k++) DrawCircle((int)(bx + 12 + k * 6), (int)(by + 24), 3, (Color){ 64, 60, 58, 255 });
            Rectangle b = { t.x + TS - 2, t.y - 14, 22, 22 };                                    /* the 0 / 1 badge */
            DrawRectangleRounded(b, 0.4f, 6, lit ? C_GOLD : (Color){ 70, 74, 90, 255 });
            DrawRectangleRoundedLinesEx(b, 0.4f, 6, 1, Fade(BLACK, 0.6f));
            txt_c(lit ? "1" : "0", b.x + 11, b.y + 2, 17, lit ? (Color){ 60, 30, 0, 255 } : C_TEXT, 1);
        } else if ((ch == '<' || ch == '>') && mc(c, r - 1) != ch) {                             /* the door, drawn whole */
            int n = 1; while (mc(c, r + n) == ch) n++;
            tall_door(c, r, n, ch == '>');
        } else if ((ch == '&' || ch == '~') && (S.floor == 17 || S.floor == 30)) {
            draw_power_torch(t, ch == '&');
        } else if (ch == 'R' && c > 0 && c < MAP_W - 1) {
            sprite(SPR_PLAQUE, 16, t.x, t.y, 2, WHITE, 0);
            if (hover(t)) { DrawRectangleRoundedLinesEx(t, 0.3f, 6, 2, C_GOLD); }
        } else if (ch == '!' || ch == '/' || (ch == '?' && !part_of_gate(c, r)) || (ch == ']' && mc(c - 1, r) != '0' && mc(c - 1, r) != '1')) {
            const char **sp = ch == '!' ? SPR_POTION : ch == '/' ? SPR_SWORD : ch == '?' ? SPR_SCROLL : SPR_ARMOR;
            Color g = ch == '!' ? (Color){ 255, 80, 90, 255 } : ch == '?' ? C_PURPLE : (Color){ 210, 220, 240, 255 };
            DrawEllipse((int)(t.x + TS / 2), (int)(t.y + TS - 4), 9, 3, Fade(BLACK, 0.45f));
            DrawCircleGradient((int)(t.x + TS / 2), (int)(t.y + TS / 2 + bob), 18, Fade(g, 0.3f + 0.1f * sinf(T * 4 + c)), BLANK);
            sprite(sp, 16, t.x, t.y + bob, 2, WHITE, 0);
        } else if (ch == '@') {
            DrawEllipse((int)(t.x + TS / 2), (int)(t.y + TS - 3), 10, 3.5f, Fade(BLACK, 0.5f));
            DrawCircleGradient((int)(t.x + TS / 2), (int)(t.y + TS / 2), 22, Fade(C_BLUE, 0.18f), BLANK);
            if (S.hidden) sprite(class_sprite(), 16, t.x, t.y, 2, (Color){ 130, 140, 190, (unsigned char)(110 + 30 * sinf(T * 3)) }, 0);
            else sprite(class_sprite(), 16, t.x, t.y + sinf(T * 2.4f) * 0.8f, 2, WHITE, 0);
        } else if (ch == 'G' || ch == 'S' || ch == 'O') {
            DrawEllipse((int)(t.x + TS / 2), (int)(t.y + TS - 3), 10, 3.5f, Fade(BLACK, 0.5f));
            sprite(enemy_sprite(ch), 16, t.x, t.y + sinf(T * 2 + c) * 0.8f, 2, WHITE, 0);
        }
    }
    if (pv_kind == 2) {                                     /* the area's edge, over the enemies standing in it */
        Color edge = pv_valid ? (Color){ 255, 200, 120, 255 } : C_RED;
        for (int i = 0; i < pv_aw * pv_ah; i++) if (pv_bits[i]) {
            int x = i % pv_aw, y = i / pv_aw;
            Rectangle t = tile(pv_ax + x + 1, pv_ay + y + 1);
            #define PVB(xx, yy) ((xx) >= 0 && (yy) >= 0 && (xx) < pv_aw && (yy) < pv_ah && pv_bits[(yy) * pv_aw + (xx)])
            if (!PVB(x, y - 1)) DrawLineEx((Vector2){ t.x, t.y }, (Vector2){ t.x + TS, t.y }, 2, edge);
            if (!PVB(x, y + 1)) DrawLineEx((Vector2){ t.x, t.y + TS }, (Vector2){ t.x + TS, t.y + TS }, 2, edge);
            if (!PVB(x - 1, y)) DrawLineEx((Vector2){ t.x, t.y }, (Vector2){ t.x, t.y + TS }, 2, edge);
            if (!PVB(x + 1, y)) DrawLineEx((Vector2){ t.x + TS, t.y }, (Vector2){ t.x + TS, t.y + TS }, 2, edge);
            char ch = mc(pv_ax + x + 1, pv_ay + y + 1);
            if (isalpha((unsigned char)ch) && ch != 'R') DrawRectangleLinesEx((Rectangle){ t.x + 2, t.y + 2, TS - 4, TS - 4 }, 2, Fade(C_RED, 0.6f + 0.3f * sinf(T * 8)));
        }
    }
    if (room_is_dark()) draw_darkness();
    {   /* the Logic Keeper's blue links to its Wardens (floor 21) */
        int wc[4], wr[4], nw = warden_blocks(wc, wr, 4);
        Rectangle kb;
        int ukeep = unbound_mode_char() == 'W' || unbound_mode_char() == 'w';   /* or the Unbound's Keeper form */
        if (nw && (ukeep ? boss_rect("ZWw", &kb) : boss_rect("Jj", &kb))) {
            Vector2 kc = { kb.x + kb.width / 2, kb.y + kb.height / 2 };
            for (int i = 0; i < nw; i++) {
                if (!gate_truth(mc(wc[i] + 1, wr[i] + 1))) continue;          /* cut: no link */
                Vector2 wcp = { MAP_X + (wc[i] + 1.5f) * TS, MAP_Y + (wr[i] + 1.5f) * TS };
                DrawLineEx(wcp, kc, 10, Fade(C_BLUE, 0.16f));
                DrawLineEx(wcp, kc, 3, Fade((Color){ 120, 180, 255, 255 }, 0.9f));
                for (int k = 0; k < 4; k++) { float f = fmodf(T * 0.6f + k / 4.0f, 1.0f); DrawCircleV(lerp2(wcp, kc, f), 4, (Color){ 170, 210, 255, 255 }); }
            }
        }
        for (int i = 0; i < nw; i++) draw_boss_at(wc[i], wr[i], wc[i] + 2, wr[i] + 2, 0);
    }
    draw_bishops();
    draw_throne_and_king("K");
    draw_boss("Dd", 2);
    draw_unbound();
    draw_boss2("Y", 0);
    draw_boss2("Jj", 1);
    draw_boss2("UuH", 3);
    draw_boss2("TtF", 2);
    {   /* Altair and Smo: the NOT link and their bits */
        Rectangle a, b2;
        int ha = boss_rect("TF", &a), hb = boss_rect("UH", &b2);
        if (ha && hb) {
            Vector2 pa = { a.x + a.width / 2, a.y + a.height / 2 }, pb = { b2.x + b2.width / 2, b2.y + b2.height / 2 };
            DrawLineEx(pa, pb, 9, Fade(C_GOLD, 0.15f));
            DrawLineEx(pa, pb, 3, Fade(C_GOLD, 0.85f));
            for (int k = 0; k < 3; k++) { float f = fmodf(T * 0.7f + k / 3.0f, 1.0f); DrawCircleV((Vector2){ pa.x + (pb.x - pa.x) * f, pa.y + (pb.y - pa.y) * f }, 4, C_GOLD); }
            Vector2 mid = { (pa.x + pb.x) / 2, (pa.y + pb.y) / 2 };
            DrawRectangleRounded((Rectangle){ mid.x - 26, mid.y - 13, 52, 26 }, 0.5f, 6, (Color){ 40, 34, 14, 240 });
            DrawRectangleRoundedLinesEx((Rectangle){ mid.x - 26, mid.y - 13, 52, 26 }, 0.5f, 6, 2, C_GOLD);
            txt_c("NOT", mid.x, mid.y - 9, 17, C_GOLD, 1);
            int abit = map_has('T'), bbit = map_has('U');
            bit_badge(pa.x, a.y, abit); bit_badge(pb.x, b2.y, bbit);
            if (abit) shield_bubble(a, C_GOLD, 1); else exposed_mark(a);
            if (bbit) shield_bubble(b2, C_GOLD, 1); else exposed_mark(b2);
        }
    }
    /* the cell under the mouse */
    int hc = (int)((mouse.x - MAP_X) / TS), hr = (int)((mouse.y - MAP_Y) / TS);
    if (mouse.x >= MAP_X && mouse.y >= MAP_Y && hc > 0 && hc < MAP_W - 1 && hr > 0 && hr < MAP_H - 1)
        DrawRectangleRoundedLinesEx(tile(hc, hr), 0.2f, 4, 2, Fade(WHITE, 0.55f));
}

/* ================================================================== */
/* 5. the panels around the map                                        */
/* ================================================================== */
static const char *KEYS = "123456789abcd";

static void draw_top_bar(void) {
    /* portrait, name, floor */
    Rectangle pr = { 12, 10, 62, 62 };
    DrawRectangleRounded(pr, 0.25f, 8, C_CARD2);
    DrawRectangleRoundedLinesEx(pr, 0.25f, 8, 2, C_LINE);
    sprite(class_sprite(), 16, pr.x + 7, pr.y + 7, 3, S.hidden ? (Color){ 140, 150, 200, 150 } : WHITE, 0);
    txtb(S.cls, 88, 12, 26, C_TEXT);
    char b[64];
    if (S.level > 0) {                                      /* level badge and the XP bar */
        float lx = 88 + twb(S.cls, 26) + 10;
        snprintf(b, sizeof b, "Lv %d", S.level);
        Rectangle lb = { lx, 14, twb(b, 16) + 16, 24 };
        DrawRectangleRounded(lb, 0.5f, 6, Fade(C_GOLD, 0.18f));
        DrawRectangleRoundedLinesEx(lb, 0.5f, 6, 1, Fade(C_GOLD, 0.7f));
        txtb(b, lb.x + 8, lb.y + 3, 16, C_GOLD);
        static const int XPT[21] = { 0, 50, 150, 280, 430, 600, 800, 1000, 1250, 1500, 1800, 2150, 2550, 3000, 3500, 4050, 4650, 5300, 6000, 7000, 7000 };
        int lv = S.level < 1 ? 1 : S.level > 20 ? 20 : S.level, lo = XPT[lv - 1];
        float xf = S.xpnext > lo ? (float)(S.xp - lo) / (S.xpnext - lo) : 1;   /* progress inside this level */
        if (xf < 0) xf = 0;
        Rectangle xb = { 88, 70, 526, 6 };
        DrawRectangleRounded(xb, 1, 6, C_CARD2);
        DrawRectangleRounded((Rectangle){ xb.x, xb.y, xb.width * fminf(xf, 1), xb.height }, 1, 6, C_GOLD);
        if (hover((Rectangle){ xb.x, xb.y - 6, xb.width, 18 })) {
            snprintf(b, sizeof b, S.xpnext ? "XP %d / %d" : "XP %d (max level)", S.xp, S.xpnext);
            txtb(b, xb.x + xb.width + 8, 63, 14, C_GOLD);
        }
        if (xp_gain_t > 0) {
            snprintf(b, sizeof b, "+%d XP", xp_gain);
            txtb(b, xb.x + xb.width * fminf(xf, 1) - 20, 52 - (1.6f - xp_gain_t) * 18, 16, Fade(C_GOLD, fminf(1, xp_gain_t)));
        }
    }
    snprintf(b, sizeof b, "Floor %d", S.floor); txt(b, 88, 44, 18, C_DIM);
    {
        int f = S.floor; float bx2 = 88 + tw(b, 18) + 10;
        if (f == 4 || f == 8) txtb("WARDEN", bx2, 45, 16, C_PURPLE);
        else if (f == 15) txtb("DARK SHADE", bx2, 45, 16, (Color){ 190, 140, 255, 255 });
        else if (f == 17) txtb("GRAND WIZARD", bx2, 45, 16, C_ICE);
        else if (f == 21) txtb("LOGIC KEEPER", bx2, 45, 16, C_TEAL);
        else if (f == 26) txtb("ALTAIR & SMO", bx2, 45, 16, C_AMBER);
        else if (f >= 30) txtb("THE KING", bx2, 45, 16, C_GOLD);
        else if (f > 15) txtb("CIRCUIT", bx2, 45, 16, C_AMBER);
    }
    /* HP and the class resource */
    float bx = 300;
    float hf = S.hpmax > 0 ? (float)S.hp / S.hpmax : 0;
    snprintf(b, sizeof b, "%d / %d", S.hp, S.hpmax);
    txtb("HP", bx + 26 - twb("HP", 16), 14, 16, C_DIM); bar((Rectangle){ bx + 34, 12, 280, 22 }, hf, hp_color(hf), b);
    if (S.manamax > 0) {
        snprintf(b, sizeof b, "%d / %d", S.mana, S.manamax);
        txtb("MP", bx + 26 - twb("MP", 16), 46, 16, C_DIM); bar((Rectangle){ bx + 34, 44, 280, 22 }, (float)S.mana / S.manamax, C_BLUE, b);
    } else if (S.dicemax > 0) {
        txtb("DICE", bx + 26 - twb("DICE", 16), 46, 16, C_DIM);
        for (int i = 0; i < S.dicemax; i++) {
            Rectangle d = { bx + 34 + i * 30, 44, 24, 24 };
            DrawRectangleRounded(d, 0.3f, 6, i < S.dice ? C_GOLD : C_CARD2);
            DrawRectangleRoundedLinesEx(d, 0.3f, 6, 1, i < S.dice ? (Color){ 150, 100, 20, 255 } : C_LINE);
            const char *die = S.level >= 15 ? "12" : S.level >= 7 ? "10" : "8";
            if (i < S.dice) txt_c(die, d.x + 12, d.y + 3, 16, (Color){ 70, 40, 0, 255 }, 1);
        }
        if (S.next_man[0]) { txt("Next:", bx + 34 + S.dicemax * 30 + 8, 47, 16, C_DIM); txtb(S.next_man, bx + 34 + S.dicemax * 30 + 52, 47, 16, C_GOLD); }
    } else {
        txtb("STEALTH", bx + 26 - twb("STEALTH", 16), 46, 16, C_DIM);
        Rectangle pill = { bx + 34, 44, 120, 24 };
        DrawRectangleRounded(pill, 0.5f, 8, S.hidden ? (Color){ 60, 64, 110, 255 } : C_CARD2);
        txt_c(S.hidden ? "HIDDEN" : "Visible", pill.x + 60, pill.y + 4, 16, S.hidden ? (Color){ 190, 200, 255, 255 } : C_DIM, 1);
    }
    if (S.hasted) { Rectangle hp2 = { bx + 330, 44, 96, 24 }; DrawRectangleRounded(hp2, 0.5f, 8, Fade(C_GOLD, 0.25f)); txt_c("HASTED", hp2.x + 48, hp2.y + 4, 16, C_GOLD, 1); }
    /* AC, weapon, stats */
    float sx = 790;
    DrawPoly((Vector2){ sx + 20, 40 }, 6, 24, 30, C_CARD2);
    DrawPolyLinesEx((Vector2){ sx + 20, 40 }, 6, 24, 30, 2, (Color){ 120, 130, 150, 255 });
    snprintf(b, sizeof b, "%d", S.ac); txt_c(b, sx + 20, 30, 22, C_TEXT, 1);
    txt("AC", sx + 13, 6, 12, C_DIM);
    sprite(SPR_SWORD, 16, sx + 56, 14, 1.6f, WHITE, 0);
    txt("Weapon", sx + 86, 14, 14, C_DIM); txtb(S.weapon[0] ? S.weapon : "-", sx + 86, 32, 20, C_TEXT);
    const char *sn[4] = { "STR", "DEX", "CON", "INT" };
    for (int i = 0; i < 4; i++) {
        Rectangle ch = { sx + 260 + i * 66, 22, 58, 40 };
        int canup = S.points && S.stat[i] < 24;              /* 24 is the peak: no + on a maxed stat */
        int hv = canup && hover(ch);
        DrawRectangleRounded(ch, 0.3f, 6, hv ? Fade(C_GOLD, 0.3f) : C_CARD2);
        txt_c(sn[i], ch.x + 29, ch.y + 3, 12, C_DIM, 0);
        snprintf(b, sizeof b, "%d", S.stat[i]); txt_c(b, ch.x + 29, ch.y + 16, 20, C_TEXT, 1);
        if (S.points && !canup) txt_c("MAX", ch.x + 29, ch.y - 12, 11, C_DIM, 1);
        if (canup) {                                        /* a stat point waits: click a stat to raise it */
            DrawRectangleRoundedLinesEx(ch, 0.3f, 6, 2, Fade(C_GOLD, 0.6f + 0.4f * sinf(T * 5)));
            DrawCircle((int)(ch.x + ch.width - 4), (int)(ch.y + 4), 9, C_GOLD);
            txt_c("+", ch.x + ch.width - 4, ch.y - 5, 16, (Color){ 60, 30, 0, 255 }, 1);
            if (hv && click) { char k = (char)('1' + i); send_key('u'); send_key(k); click = 0; }
        }
    }
    if (S.points) txtb("LEVEL UP!  Click a stat to raise it", sx + 260, 66, 12, C_GOLD);
    /* mode, turn-based button, end turn */
    float rx = W - 12;
    const char *mt; Color mcol;
    switch (S.mode) {
    case M_FIGHT_YOU: mt = "COMBAT  -  YOUR TURN"; mcol = C_AMBER; break;
    case M_FIGHT_ENEMY: mt = "COMBAT  -  ENEMY TURN"; mcol = C_RED; break;
    case M_TB_YOU: mt = "TURN-BASED  -  YOUR TURN"; mcol = C_AMBER; break;
    case M_TB_OTHERS: mt = "TURN-BASED  -  OTHERS MOVE"; mcol = C_DIM; break;
    default: mt = "EXPLORING"; mcol = C_GREEN;
    }
    Rectangle et = { rx - 128, 40, 128, 32 };
    int your_turn = S.mode == M_FIGHT_YOU || S.mode == M_TB_YOU;
    if (button(et, "End turn", C_AMBER, your_turn)) send_key(' ');
    Rectangle tb = { rx - 128 - 10 - 176, 40, 176, 32 };
    if (button(tb, S.tb_on ? "Turn-based: ON" : "Turn-based: OFF", C_AMBER, 1)) send_key('t');
    if (S.tb_on) DrawRectangleRoundedLinesEx(tb, 0.35f, 8, 2, C_AMBER);
    float mw = twb(mt, 16) + 28;
    Rectangle mp = { rx - mw, 8, mw, 26 };
    DrawRectangleRounded(mp, 0.5f, 8, Fade(mcol, 0.16f));
    DrawRectangleRoundedLinesEx(mp, 0.5f, 8, 1, Fade(mcol, 0.7f));
    DrawCircle((int)(mp.x + 12), (int)(mp.y + 13), 4, mcol);
    txtb(mt, mp.x + 22, mp.y + 5, 16, mcol);
    if (S.move >= 0) { snprintf(b, sizeof b, "Movement %d", S.move); txt(b, mp.x - tw(b, 16) - 14, mp.y + 5, 16, C_DIM); }
}

static void draw_enemies_card(Rectangle r) {
    card(r); card_title("ENEMIES", r.x + 16, r.y + 12);
    int n = 0, count = 0;
    for (int i = 0; i < 6; i++) count += S.en[i].present;
    float rh = count > 4 ? 41 : 62;                            /* 5 or 6 enemies: slimmer rows */
    for (int i = 0; i < 6; i++) {
        Enemy *e = &S.en[i];
        if (!e->present) continue;
        if (count > 4) {                                       /* compact: icon, name, bar on one line */
            Rectangle row = { r.x + 10, r.y + 38 + n * rh, r.width - 20, rh - 5 };
            n++;
            DrawRectangleRounded(row, 0.2f, 6, e->flash > 0 ? ColorLerp(C_CARD2, C_RED, e->flash) : C_CARD2);
            sprite(enemy_sprite(e->letter), 16, row.x + 6, row.y + 2, 2, WHITE, 0);
            txtb(enemy_name(e->letter), row.x + 46, row.y + 9, 16, C_TEXT);
            float f = e->hpmax ? (float)e->hp / e->hpmax : 0;
            bar((Rectangle){ row.x + 160, row.y + 12, 150, 12 }, f, hp_color(f), NULL);
            char b[24]; snprintf(b, sizeof b, "%d/%d", e->hp, e->hpmax);
            txt(b, row.x + 318, row.y + 9, 14, C_DIM);
            if (e->st[0]) txtb(e->st, row.x + row.width - tw(e->st, 13) - 22, row.y + 10, 13, C_GOLD);
            continue;
        }
        Rectangle row = { r.x + 10, r.y + 38 + n * rh, r.width - 20, 56 };
        n++;
        DrawRectangleRounded(row, 0.2f, 6, e->flash > 0 ? ColorLerp(C_CARD2, C_RED, e->flash) : C_CARD2);
        Rectangle ic = { row.x + 8, row.y + 8, 40, 40 };
        DrawRectangleRounded(ic, 0.25f, 6, (Color){ 18, 19, 26, 255 });
        if (e->letter == 'M') sprite(SPR_WARDEN_HALF, 24, ic.x + 2, ic.y + 2, 1.5f, WHITE, 1);
        else if (e->letter == 'K') sprite(SPR_KING_HALF, 24, ic.x + 1, ic.y + 9, 0.95f, WHITE, 1);
        else if (e->letter == 'D') sprite(SPR_KING_HALF, 24, ic.x + 1, ic.y + 9, 0.95f, (Color){ 120, 80, 180, 230 }, 1);
        else if (e->letter == 'Y') sprite(SPR_YMIR, 32, ic.x + 4, ic.y + 4, 1, WHITE, 0);
        else if (e->letter == 'J') sprite(SPR_KEEPER, 32, ic.x + 4, ic.y + 4, 1, WHITE, 0);
        else if (e->letter == 'T') sprite(SPR_ALTAIR, 32, ic.x + 4, ic.y + 4, 1, WHITE, 0);
        else if (e->letter == 'U') sprite(SPR_SMO, 32, ic.x + 4, ic.y + 4, 1, WHITE, 0);
        else if (e->letter == 'Z') sprite(SPR_UNBOUND, 48, ic.x + 2, ic.y + 2, 0.75f, WHITE, 0);
        else if (e->letter == 'P') sprite(SPR_BISHOP, 32, ic.x + 4, ic.y + 4, 1, WHITE, 0);
        else sprite(enemy_sprite(e->letter), 16, ic.x + 4, ic.y + 4, 2, WHITE, 0);
        txtb(enemy_name(e->letter), row.x + 58, row.y + 7, 18, C_TEXT);
        {   /* boss state tags: the Keeper's ward, an empowered partner */
            const char *tag = NULL; Color tc = C_TEAL;
            if (e->letter == 'J' && map_has('J')) tag = S.floor == 21 ? "LINKED - IMMUNE" : "WARDED";
            if ((e->letter == 'J' || e->letter == 'j') && S.floor == 21 && map_has('j')) { tag = "OPEN"; tc = C_GOLD; }
            if ((e->letter == 'T' && map_has('t')) || (e->letter == 'U' && map_has('u'))) { tag = "EMPOWERED"; tc = C_EMBER; }
            if (e->letter == 'T' && map_has('T')) { tag = "1 SHIELDED"; tc = C_GOLD; }
            if (e->letter == 'T' && map_has('F')) { tag = "0 EXPOSED"; tc = C_RED; }
            if (e->letter == 'U' && map_has('U')) { tag = "1 SHIELDED"; tc = C_GOLD; }
            if (e->letter == 'U' && map_has('H')) { tag = "0 EXPOSED"; tc = C_RED; }
            if (e->letter == 'M') {                         /* each Warden reads the gate on its own shield */
                int k = 0, wc[4], wr[4], nw = warden_blocks(wc, wr, 4);
                for (int j = 0; j < 6 && &S.en[j] != e; j++) if (S.en[j].present && S.en[j].letter == 'M') k++;
                int broken = k < nw ? !gate_truth(mc(wc[k] + 1, wr[k] + 1)) : map_has('B');
                if (broken) { tag = "SHIELD BROKEN"; tc = C_RED; } else { tag = "GATE SHIELD"; tc = C_BLUE; }
            }
            if (e->letter == 'D') { if (map_has('d')) { tag = "IN DARKNESS"; tc = C_PURPLE; } else { tag = "IN THE LIGHT"; tc = C_EMBER; } }
            if (e->letter == 'K') {
                Rectangle kb; int open = 0;
                if (boss_rect("K", &kb)) { int c0 = (int)((kb.x - MAP_X) / TS), r0 = (int)((kb.y - MAP_Y) / TS); open = mc(c0 - 1, r0 + 1) == '='; }
                if (open) { tag = "VULNERABLE"; tc = C_GOLD; } else { tag = "IMMUNE"; tc = C_DIM; }
            }
            if (e->letter == 'Z') {
                int m = unbound_mode_char();
                if (gate_truth((char)m)) tag = "GATE SHIELD"; else if (m == 'f') { tag = "POWER TORCHES"; tc = C_EMBER; }
                else if (m == 'D' || m == 'd') { tag = m == 'D' ? "IN THE LIGHT" : "IN DARKNESS"; tc = C_PURPLE; }
                else if (m == '1') { tag = "1 SHIELDED"; tc = C_GOLD; } else if (m == '0') { tag = "0 EXPOSED"; tc = C_RED; }
                else if (m == 'q') { tag = "ONE OF FOUR"; tc = C_GOLD; }
                else if (m == 'W') { tag = "LINKED - IMMUNE"; tc = C_BLUE; } else if (m == 'w') { tag = "OPEN"; tc = C_GOLD; }
            }
            if (tag) {
                float tx = row.x + 58 + twb(enemy_name(e->letter), 18) + 10, tww = twb(tag, 13) + 14;
                DrawRectangleRounded((Rectangle){ tx, row.y + 8, tww, 20 }, 0.5f, 6, Fade(tc, 0.18f));
                DrawRectangleRoundedLinesEx((Rectangle){ tx, row.y + 8, tww, 20 }, 0.5f, 6, 1, Fade(tc, 0.8f));
                txtb(tag, tx + 7, row.y + 11, 13, tc);
            }
        }
        char b[32]; snprintf(b, sizeof b, "%d / %d", e->hp, e->hpmax);
        float f = e->hpmax ? (float)e->hp / e->hpmax : 0;
        bar((Rectangle){ row.x + 58, row.y + 32, 170, 14 }, f, hp_color(f), NULL);
        txt(b, row.x + 236, row.y + 30, 15, C_DIM);
        float sx = row.x + row.width - 8;
        for (int k = (int)strlen(e->st) - 1; k >= 0; k--) {
            sx -= 30; status_icon(e->st[k], sx, row.y + 14, 26);
            if (hover((Rectangle){ sx, row.y + 14, 26, 26 })) {
                const char *nm = status_name(e->st[k]);
                Rectangle tip = { sx - 10, row.y - 22, tw(nm, 15) + 16, 24 };
                DrawRectangleRounded(tip, 0.4f, 6, (Color){ 8, 8, 12, 240 }); txt(nm, tip.x + 8, tip.y + 4, 15, C_TEXT);
            }
        }
    }
    if (!n) {
        txt_c("No enemies in this room", r.x + r.width / 2, r.y + r.height / 2 - 10, 18, C_DIM, 0);
    }
}

static void wrap_text(const char *s, float x, float y, float w, float size, Color c, int bold, int maxlines);
static const char *hover_item; static Rectangle hover_rect;
static void draw_item_tooltip(void) {                       /* hovering a special item: what it does */
    if (!hover_item) return;
    const ItemInfo *ii = item_info(hover_item);
    if (!ii) { hover_item = NULL; return; }
    Color rc = ii->rarity == 2 ? (Color){ 150, 92, 10, 255 } : (Color){ 30, 70, 150, 255 };   /* ink colours on parchment */
    float w = 420, x = hover_rect.x + 20, y = hover_rect.y - 150;
    if (x + w > W - 10) x = W - 10 - w;
    Rectangle c = { x, y, w, 140 };
    DrawRectangleRounded((Rectangle){ c.x + 3, c.y + 5, c.width, c.height }, 0.08f, 8, Fade(BLACK, 0.5f));
    DrawRectangleRounded(c, 0, 0, C_PARCH);
    for (int i = 0; i < 40; i++) DrawCircle((int)(c.x + rnd(i * 3) * c.width), (int)(c.y + rnd(i * 3 + 1) * c.height), 1 + rnd(i * 3 + 2) * 3, Fade((Color){ 150, 120, 70, 255 }, 0.18f));
    DrawRectangleLinesEx((Rectangle){ c.x + 4, c.y + 4, c.width - 8, c.height - 8 }, 1, Fade(C_INK, 0.35f));
    DrawRectangleRoundedLinesEx(c, 0, 0, 2, (Color){ 120, 88, 46, 255 });
    sprite(icon_sprite(ii->icon), 16, c.x + 12, c.y + 12, 2.5f, WHITE, 0);
    txtb(ii->name, c.x + 64, c.y + 10, 22, rc);
    txtb(ii->rarity == 2 ? "LEGENDARY" : "RARE", c.x + 64, c.y + 36, 13, Fade(rc, 0.85f));
    txt(ii->who, c.x + 64 + twb(ii->rarity == 2 ? "LEGENDARY" : "RARE", 13) + 12, c.y + 36, 13, (Color){ 110, 86, 56, 255 });
    wrap_text(ii->stats, c.x + 14, c.y + 60, w - 28, 16, C_INK, 1, 2);
    wrap_text(ii->desc, c.x + 14, c.y + 100, w - 28, 15, (Color){ 110, 86, 56, 255 }, 0, 2);
    hover_item = NULL;
}
static void draw_slots_card(Rectangle r) {
    card(r);
    int wizard = !strcmp(S.cls, "WIZARD");
    if (wizard) {                                         /* tabs: Spells | Bag */
        Rectangle t1 = { r.x + 12, r.y + 8, 92, 26 }, t2 = { r.x + 110, r.y + 8, 70, 26 };
        Rectangle *act = S.bag ? &t2 : &t1, *oth = S.bag ? &t1 : &t2;
        DrawRectangleRounded(*act, 0.4f, 6, C_CARD2);
        if (hover(*oth)) DrawRectangleRounded(*oth, 0.4f, 6, Fade(C_CARD2, 0.6f));
        txt_c("SPELLS", t1.x + 46, t1.y + 5, 15, S.bag ? C_DIM : C_TEXT, 1);
        txt_c("BAG", t2.x + 35, t2.y + 5, 15, S.bag ? C_TEXT : C_DIM, 1);
        if (click && hover(*oth)) send_key('i');
        keycap("I", r.x + 188, r.y + 10);
    } else card_title("BAG", r.x + 16, r.y + 12);
    int discard = strstr(S.msg, "Discard which") != NULL;
    if (discard) txtb("Click an item to throw it away", r.x + r.width - 290, r.y + 12, 15, C_RED);
    else if (S.bag) txt("click to use or equip", r.x + r.width - 170, r.y + 12, 15, C_DIM);
    else txt("click, then pick a target", r.x + r.width - 196, r.y + 12, 15, C_DIM);
    int cols = 2, per = 7;
    float cw = (r.width - 30) / cols;
    for (int i = 0; i < (S.bag ? 12 : 13); i++) {           /* the bag has 12 slots */
        Slot *s = &S.slot[i];
        if (!S.bag && !s->present) continue;
        Rectangle row = { r.x + 10 + (i / per) * (cw + 10), r.y + 40 + (i % per) * 35, cw, 31 };
        int h = s->present && hover(row);
        Color bg = s->armed ? Fade(C_PURPLE, 0.25f) : h ? (Color){ 42, 46, 60, 255 } : C_CARD2;
        if (discard && s->present && h) bg = Fade(C_RED, 0.3f);
        DrawRectangleRounded(row, 0.3f, 6, bg);
        if (s->armed) DrawRectangleRoundedLinesEx(row, 0.3f, 6, 2, C_PURPLE);
        char k[2] = { KEYS[i], 0 };
        keycap(k, row.x + 6, row.y + 5);
        if (!s->present) { txt("empty", row.x + 40, row.y + 7, 15, Fade(C_DIM, 0.5f)); continue; }
        if (S.bag) {
            Color rc = s->rarity == 2 ? C_GOLD : s->rarity == 1 ? (Color){ 120, 180, 255, 255 } : C_TEXT;
            if (s->rarity) {
                DrawRectangleRounded((Rectangle){ row.x + 32, row.y + 2, 28, 27 }, 0.3f, 6, Fade(rc, s->rarity == 2 ? 0.22f + 0.08f * sinf(T * 3) : 0.16f));
                DrawRectangleRoundedLinesEx(row, 0.3f, 6, 1, Fade(rc, 0.55f));
            }
            sprite(item_sprite(s->name), 16, row.x + 34, row.y + 3, 1.6f, WHITE, 0);
            txt(s->name, row.x + 66, row.y + 6, 17, rc);
            if (h) hover_item = s->name, hover_rect = row;
            if (s->worn) {
                Rectangle p = { row.x + row.width - 84, row.y + 5, 78, 21 };
                DrawRectangleRounded(p, 0.5f, 6, Fade(C_GREEN, 0.2f)); txt_c("EQUIPPED", p.x + 39, p.y + 3, 13, C_GREEN, 1);
            }
        } else {
            Color sc = spell_color(s->name);
            DrawCircleGradient((int)(row.x + 46), (int)(row.y + 15), 11, sc, Fade(sc, 0.1f));
            DrawCircle((int)(row.x + 44), (int)(row.y + 13), 3, Fade(WHITE, 0.8f));
            txt(s->name, row.x + 64, row.y + 6, 17, C_TEXT);
            Rectangle p = { row.x + row.width - 62, row.y + 5, 56, 21 };
            char cost[16];
            if (s->cost == 0) snprintf(cost, sizeof cost, "free"); else snprintf(cost, sizeof cost, "%d MP", s->cost);
            int afford = S.mana < 0 || s->cost <= S.mana;
            DrawRectangleRounded(p, 0.5f, 6, Fade(s->cost ? C_BLUE : C_GREEN, 0.2f));
            txt_c(cost, p.x + 28, p.y + 3, 13, afford ? (s->cost ? (Color){ 150, 190, 255, 255 } : C_GREEN) : C_RED, 1);
        }
        if (h && click) send_key(KEYS[i]);
    }
}

static Color msg_color(const char *m) {
    if (strstr(m, "died")) return C_RED;
    if (strstr(m, "Keeper") || strstr(m, "Bishop") || strstr(m, "bishop") || strstr(m, "Unbound")) return C_PURPLE;
    if (strstr(m, "hits you") || strstr(m, "can't") || strstr(m, "Not enough") || strstr(m, "Invalid") || strstr(m, "sealed") || strstr(m, "won't")) return (Color){ 255, 130, 120, 255 };
    if (strstr(m, "cleared") || strstr(m, "opens") || strstr(m, "learn") || strstr(m, "falls")) return C_GREEN;
    if (strstr(m, "You hit") || strstr(m, " - hit ")) return C_GOLD;
    if (strstr(m, "Warden") || strstr(m, "King")) return C_PURPLE;
    return C_TEXT;
}

static void wrap_text(const char *s, float x, float y, float w, float size, Color c, int bold, int maxlines) {
    char line[240] = "", word[64];
    int n = 0;
    while (*s && n < maxlines) {
        int k = 0; while (*s == ' ') s++;
        while (*s && *s != ' ' && k < 63) word[k++] = *s++;
        word[k] = 0;
        if (!k) break;
        char test[230]; snprintf(test, sizeof test, "%s%s%s", line, line[0] ? " " : "", word);
        if ((bold ? twb(test, size) : tw(test, size)) > w && line[0]) {
            if (bold) txtb(line, x, y + n * (size + 6), size, c); else txt(line, x, y + n * (size + 6), size, c);
            n++; snprintf(line, sizeof line, "%s", word);
        } else snprintf(line, sizeof line, "%s", test);
    }
    if (line[0] && n < maxlines) { if (bold) txtb(line, x, y + n * (size + 6), size, c); else txt(line, x, y + n * (size + 6), size, c); }
}

static void draw_log_card(Rectangle r) {
    card(r); card_title("LOG", r.x + 16, r.y + 12);
    int maxl = 6;
    if (gate_floor == S.floor && gate_txt[0]) {               /* the door's riddle stays pinned here */
        int open = 0;
        for (int rr = 0; rr < MAP_H; rr++) if (mc(MAP_W - 2, rr) == '>') open = 1;
        Rectangle g = { r.x + 12, r.y + 36, r.width - 24, 84 };
        DrawRectangleRounded(g, 0, 0, C_PARCH);                 /* the riddle, on parchment */
        for (int i = 0; i < 30; i++) DrawCircle((int)(g.x + rnd(i * 5) * g.width), (int)(g.y + rnd(i * 5 + 1) * g.height), 1 + rnd(i * 5 + 2) * 3, Fade((Color){ 150, 120, 70, 255 }, 0.18f));
        DrawRectangleRoundedLinesEx(g, 0, 0, 2, open ? (Color){ 50, 120, 50, 255 } : (Color){ 120, 88, 46, 255 });
        char name[12] = {0}; const char *dash = strstr(gate_txt, " - ");
        if (dash && dash - gate_txt < 11) memcpy(name, gate_txt, dash - gate_txt);
        txtb(name, g.x + 14, g.y + 10, strlen(name) > 4 ? 22 : 30, open ? (Color){ 40, 110, 40, 255 } : (Color){ 130, 40, 20, 255 });
        txtb(open ? "DOOR OPEN" : "DOOR SEALED", g.x + 16, g.y + 52, 13, open ? (Color){ 40, 110, 40, 255 } : (Color){ 110, 86, 56, 255 });
        wrap_text(dash ? dash + 3 : gate_txt, g.x + 130, g.y + 8, g.width - 144, 16, C_INK, 0, 4);
        maxl = 2;
    }
    if (!log_n && maxl == 6) {
        txt("Click the floor to walk there.", r.x + 16, r.y + 44, 17, C_DIM);
        txt("Click an enemy to attack it.  Right-click cancels.", r.x + 16, r.y + 70, 17, C_DIM);
        txt("Read the plaque by the door to learn the gate.", r.x + 16, r.y + 96, 17, C_DIM);
    }
    {   /* every message wraps onto as many lines as it needs; the mouse wheel scrolls back */
        static char L[240][200]; static int Lmsg[240];
        static int last_log_n;
        int nl = 0;
        float size = 17, lh = TS_(size) + 6, w = r.width - 40;
        float top = maxl == 2 ? r.y + 130 : r.y + 40, bottom = r.y + r.height - 92;
        int fit = (int)((bottom - top) / lh);
        for (int i = (log_n > 60 ? log_n - 60 : 0); i < log_n && nl < 240; i++) {   /* oldest to newest */
            const char *m = log_txt[i % 60]; char line[200] = "";
            int first = 1;
            while (*m && nl < 240) {
                char word[64]; int k = 0;
                while (*m == ' ') m++;
                while (*m && *m != ' ' && k < 63) word[k++] = *m++;
                word[k] = 0;
                if (!k) break;
                char test[200]; snprintf(test, sizeof test, "%s%s%s", line, line[0] ? " " : "", word);
                if (tw(test, size) > w - (first ? 0 : 14) && line[0]) {
                    snprintf(L[nl], 200, "%s", line); Lmsg[nl++] = first ? i : -1 - i; first = 0;
                    snprintf(line, sizeof line, "%s", word);
                } else snprintf(line, sizeof line, "%s", test);
            }
            if (line[0] && nl < 240) { snprintf(L[nl], 200, "%s", line); Lmsg[nl++] = first ? i : -1 - i; }
        }
        if (log_n != last_log_n) { log_scroll = 0; last_log_n = log_n; }       /* something new: back to the newest */
        if (hover(r) && wheel != 0) { log_scroll += (int)(wheel > 0 ? 2 : -2); snd_full("ui_hover", NULL, 0, 0.4f, 1.2f, 0); }
        int maxs = nl - fit > 0 ? nl - fit : 0;
        if (log_scroll > maxs) log_scroll = maxs;
        if (log_scroll < 0) log_scroll = 0;
        int end = nl - log_scroll, start = end - fit > 0 ? end - fit : 0;
        for (int j = start; j < end; j++) {
            int mi = Lmsg[j] >= 0 ? Lmsg[j] : -1 - Lmsg[j], age = log_n - 1 - mi;
            Color c = msg_color(log_txt[mi % 60]);
            if (age) c = Fade(c, fmaxf(0.4f, 0.8f - age * 0.07f));
            float y = top + (fit - (end - j)) * lh;
            txt(L[j], r.x + 16 + (Lmsg[j] < 0 ? 14 : 0), y, size, c);
        }
        /* little arrows when there is more above or below */
        float ax = r.x + r.width - 24;
        if (start > 0) { DrawTriangle((Vector2){ ax, top - 2 }, (Vector2){ ax - 6, top + 8 }, (Vector2){ ax + 6, top + 8 }, Fade(C_GOLD, 0.8f));
                         txt("scroll", ax - 52, top - 1, 12, C_DIM); }
        if (log_scroll > 0) { float yb = bottom - 6; DrawTriangle((Vector2){ ax - 6, yb - 8 }, (Vector2){ ax, yb + 2 }, (Vector2){ ax + 6, yb - 8 }, C_GOLD);
                              txt("newest", ax - 58, yb - 10, 12, C_GOLD); }
    }
    /* action buttons from the game's own key help */
    float bx = r.x + 14, by = r.y + r.height - 78;
    DrawRectangleRec((Rectangle){ r.x + 12, by - 10, r.width - 24, 1 }, C_LINE);
    for (int h = 0; h < 2; h++) {
        const char *p = S.help[h];
        while ((p = strchr(p, '['))) {
            char key[8] = {0}, label[32] = {0};
            const char *e = strchr(p, ']'); if (!e || e - p > 7) break;
            memcpy(key, p + 1, e - p - 1);
            const char *q = e + 1; while (*q == ' ') q++;
            int n = 0; while (q[n] && q[n] != '[' && n < 30) n++;
            while (n > 0 && q[n - 1] == ' ') n--;
            memcpy(label, q, n);
            p = e + 1;
            if (strchr(key, '-') || !strcmp(key, "Q") || !strcmp(key, "I")) continue;   /* ranges, quit, bag tab: not buttons */
            char k = !strcmp(key, "Space") ? ' ' : (char)tolower((unsigned char)key[0]);
            float w = tw(label, 15) + tw(key, 13) + 30;
            if (bx + w > r.x + r.width - 12) { bx = r.x + 14; by += 36; }
            Rectangle br = { bx, by, w, 30 };
            int hv = hover(br);
            DrawRectangleRounded(br, 0.35f, 6, hv ? (Color){ 52, 56, 74, 255 } : C_CARD2);
            DrawRectangleRoundedLinesEx(br, 0.35f, 6, 1, hv ? C_GOLD : C_LINE);
            txtb(key, br.x + 9, br.y + 7, 13, C_GOLD);
            txt(label, br.x + 18 + tw(key, 13), br.y + 6, 15, C_TEXT);
            if (hv && click) send_key(k);
            bx += w + 8;
        }
    }
    {   /* not a game key: the window's own Options menu */
        float w = tw("Options", 15) + tw("Esc", 13) + 30;
        if (bx + w > r.x + r.width - 12) { bx = r.x + 14; by += 36; }
        Rectangle br = { bx, by, w, 30 };
        int hv = hover(br);
        DrawRectangleRounded(br, 0.35f, 6, hv ? (Color){ 52, 56, 74, 255 } : C_CARD2);
        DrawRectangleRoundedLinesEx(br, 0.35f, 6, 1, hv ? C_GOLD : C_LINE);
        txtb("Esc", br.x + 9, br.y + 7, 13, C_GOLD);
        txt("Options", br.x + 18 + tw("Esc", 13), br.y + 6, 15, C_TEXT);
        if (hv && click) { options_set_open(1); click = 0; }
    }
}

/* ================================================================== */
/* 6. the screens before and after the dungeon                         */
/* ================================================================== */
static void backdrop(void) {
    ClearBackground(C_BG);
    for (int i = 0; i < 40; i++) {                        /* drifting embers */
        float ph = fmodf(T * 0.05f + rnd(i), 1.0f);
        DrawCircle((int)(rnd(i + 7) * W + sinf(T + i) * 20), (int)(H - ph * H), 1.5f + rnd(i + 3) * 1.5f, Fade(C_AMBER, 0.35f * (1 - ph)));
    }
}
static int wants_exit;
static int how_open;                                         /* the How to Play page is showing */
static void brick_band(float y0, float h, float scroll, float bw, float bh, Color base, int seed) {   /* a scrolling wall of bricks */
    int rows = (int)(h / bh) + 1;
    for (int r = 0; r < rows; r++) {
        float off = fmodf(scroll + ((r & 1) ? bw / 2 : 0), bw);
        for (float x = -off - bw; x < W + bw; x += bw) {
            int id = (int)floorf((x + scroll) / bw) * 7 + r * 13 + seed;
            float v = 0.75f + 0.35f * rnd(id);
            Color c = { (unsigned char)(base.r * v), (unsigned char)(base.g * v), (unsigned char)(base.b * v), 255 };
            float yy = y0 + r * bh, hh = fminf(bh - 3, y0 + h - yy - 1);
            if (hh <= 0) continue;
            DrawRectangleRec((Rectangle){ x + 1, yy + 1, bw - 3, hh }, c);
            DrawRectangleRec((Rectangle){ x + 1, yy + 1, bw - 3, 2 }, Fade(WHITE, 0.05f));
        }
    }
}
static void corridor_bg(float speed, float dim) {           /* the scrolling dungeon corridor (title and class screens) */
    ClearBackground(C_BG);
    float wall = T * 26 * speed, near = T * 70 * speed, ground = T * 110 * speed;   /* parallax: the further, the slower */
    /* ceiling and back wall */
    brick_band(0, 120, wall * 0.8f, 72, 24, (Color){ 46, 40, 36, 255 }, 1);
    brick_band(120, 440, wall, 84, 28, (Color){ 92, 78, 64, 255 }, 2);
    DrawRectangleGradientV(0, 0, W, 200, Fade(BLACK, 0.85f), Fade(BLACK, 0.2f));
    /* pillars with torches, closer than the wall */
    float gap = 430;
    for (float x = -fmodf(near, gap) - 60; x < W + gap; x += gap) {
        int id = (int)floorf((x + near) / gap);
        DrawRectangleRec((Rectangle){ x, 90, 96, 480 }, (Color){ 58, 56, 56, 255 });
        DrawRectangleRec((Rectangle){ x + 6, 90, 18, 480 }, (Color){ 76, 74, 72, 255 });
        DrawRectangleRec((Rectangle){ x + 78, 90, 18, 480 }, (Color){ 40, 38, 38, 255 });
        DrawRectangleRec((Rectangle){ x - 10, 82, 116, 18 }, (Color){ 70, 68, 66, 255 });
        DrawRectangleRec((Rectangle){ x - 10, 552, 116, 22 }, (Color){ 70, 68, 66, 255 });
        float tx = x + 48, ty = 300;
        float fl = 0.75f + 0.15f * sinf(T * 11 + id * 3) + 0.10f * sinf(T * 23 + id);   /* flicker */
        DrawCircleGradient((int)tx, (int)ty - 20, 190 + 40 * fl, Fade((Color){ 255, 150, 60, 255 }, 0.16f + 0.10f * fl), BLANK);
        DrawCircleGradient((int)tx, (int)ty - 14, 46 * fl, Fade((Color){ 255, 220, 140, 255 }, 0.35f), BLANK);
        DrawRectangleRec((Rectangle){ tx - 5, ty - 6, 10, 34 }, (Color){ 90, 60, 34, 255 });
        DrawRectangleRec((Rectangle){ tx - 12, ty - 12, 24, 8 }, C_IRON);
        flame(tx + sinf(T * 7 + id) * 1.5f, ty - 12, 15 + 5 * fl, T * 1.6f + id);
        for (int k = 0; k < 4; k++) {                          /* sparks rising off the flame */
            float ph = fmodf(T * 0.9f + rnd(id * 9 + k), 1.0f);
            DrawCircle((int)(tx + sinf(ph * 9 + k) * 8), (int)(ty - 30 - ph * 70), 2 * (1 - ph) + 0.5f, Fade((Color){ 255, 190, 90, 255 }, 1 - ph));
        }
    }
    /* the floor: big stone slabs, fastest */
    DrawRectangle(0, 572, W, H - 572, (Color){ 30, 31, 35, 255 });
    for (int r = 0; r < 4; r++) {
        float y = 572 + r * 78, sw = 180 + r * 40, off = fmodf(ground * (0.7f + r * 0.2f) + r * 60, sw);
        for (float x = -off - sw; x < W + sw; x += sw) {
            int id = (int)floorf((x + ground) / sw) + r * 31;
            unsigned char v = (unsigned char)(40 + 14 * rnd(id));
            DrawRectangleRec((Rectangle){ x + 2, y + 2, sw - 4, 74 }, (Color){ v, v, (unsigned char)(v + 4), 255 });
            DrawRectangleRec((Rectangle){ x + 2, y + 2, sw - 4, 2 }, Fade(WHITE, 0.06f));
        }
    }
    DrawRectangleGradientV(0, 560, W, 60, Fade(BLACK, 0.6f), BLANK);
    DrawRectangleGradientV(0, H - 160, W, 160, BLANK, Fade(BLACK, 0.8f));
    DrawRectangleGradientH(0, 0, 260, H, Fade(BLACK, 0.75f), BLANK);
    DrawRectangleGradientH(W - 260, 0, 260, H, BLANK, Fade(BLACK, 0.75f));
    for (int i = 0; i < 50; i++) {                            /* dust in the torchlight */
        float ph = fmodf(T * 0.04f + rnd(i), 1.0f);
        float x = fmodf(rnd(i + 9) * W - T * (8 + rnd(i + 2) * 20) + W * 4, (float)W);
        DrawCircle((int)x, (int)(560 - ph * 460 + sinf(T + i) * 10), 1.2f + rnd(i + 3) * 1.6f, Fade((Color){ 255, 210, 150, 255 }, 0.30f * sinf(ph * PI)));
    }
    if (dim > 0) DrawRectangle(0, 0, W, H, Fade(BLACK, dim));
}
/* ================================================================== */
/* 5. what to play: from the game's messages, and from what changed    */
/* ================================================================== */
static int prev_hidden, discard_now, reset_now;
static float hit_avg; static int hit_n;
static int fallen_quiet; static float unbound_hold;        /* the King's fake death: music off, then the revival */
static int starts(const char *m, const char *p) { return !strncmp(m, p, strlen(p)); }
static int has(const char *m, const char *p) { return strstr(m, p) != NULL; }
static int weapon_ranged(void) {
    const ItemInfo *it = item_info(S.weapon);
    return has(S.weapon, "bow") || has(S.weapon, "Bow") || (it && (!strcmp(it->icon, "bow") || has(it->stats, "range ")));
}
static void world_event(void) { snd_cancel_world(); }        /* a boss moved the torches: no torch clicks for it */

static void snd_from_msg(const char *m) {
#ifdef RD_TEST
    { static FILE *ml; if (!ml && getenv("RD_MSGLOG")) ml = fopen(getenv("RD_MSGLOG"), "a"); if (ml) { fprintf(ml, "%s\n", m); fflush(ml); } }   /* tests: every log line */
#endif
    static const char *spell[][2] = {
        { "Firebolt", "firebolt" }, { "Fireball", "fireball" }, { "Magic Missile", "magic_missile" }, { "Scorching Ray", "scorching_ray" },
        { "Misty Step", "misty_step" }, { "Sleep", "sleep" }, { "Hold Monster", "hold" }, { "Haste", "haste" }, { "Ray of Frost", "ray_of_frost" },
        { "Vampiric Touch", "vampiric_touch" }, { "Sunbeam", "sunbeam" }, { "Ice Storm", "ice_storm" }, { "Cone of Cold", "cone_of_cold" } };
    for (int i = 0; i < 13; i++) {                         /* "Fireball - hit 3  dmg 14", "Misty Step - done" */
        size_t L = strlen(spell[i][0]);
        if (!strncmp(m, spell[i][0], L) && !strncmp(m + L, " - ", 3)) { snd_or(spell[i][1], "spell_cast"); return; }
    }
    /* your weapon */
    if (starts(m, "You hit for ")) {
        int d = atoi(m + 12);
        if (prev_hidden) snd("sneak_attack");
        else if (hit_n >= 3 && d >= 8 && d >= hit_avg * 1.7f) snd("crit");       /* a hit far above your usual = a crit */
        else if (weapon_ranged()) snd("bow_shot");
        else if (!S.weapon[0] || !strcmp(S.weapon, "Fists")) snd("enemy_hit");
        else snd("sword_hit");
        hit_avg = hit_n ? hit_avg * 0.8f + d * 0.2f : d; hit_n++;
        return;
    }
    /* enemies attacking you (one message can hold several: "Goblin hits you for 3, Orc misses") */
    if (has(m, "hits you for") || has(m, " misses") || starts(m, "Enemy misses")) {
        if (has(m, "Altair")) snd("altair_lightning");
        if (has(m, "Smo ") || has(m, "Smo,")) snd("smo_slam");
        if (has(m, "hits you for")) snd("player_hurt"); else snd("sword_miss");
        return;
    }
    if (has(m, "blue wave crashes into you")) { snd_at("player_hurt", 0.25f); return; }
    if (has(m, "Wizard Ymir") && has(m, " casts ")) { snd("ymir_spell"); if (has(m, ", then ")) snd_at("ymir_spell", 0.55f); if (has(m, "blinks away")) snd("misty_step"); return; }
    if (starts(m, "You died")) { snd("player_death"); return; }
    /* you and your things */
    if (starts(m, "LEVEL UP!")) { snd_or("@level_up", "level_up"); return; }
    if (has(m, " is now ") && (starts(m, "STR") || starts(m, "DEX") || starts(m, "CON") || starts(m, "INT"))) { snd("stat_point"); return; }
    if (starts(m, "You learn ")) { snd("pickup_rare"); return; }
    if (starts(m, "You pick up ")) { snd(has(m, "(LEGENDARY)") ? "pickup_legendary" : has(m, "(rare)") ? "pickup_rare" : "pickup"); return; }
    if (starts(m, "Item thrown away")) { snd("discard"); discard_now = 1; return; }
    if (starts(m, "You slip")) { snd("hide"); return; }
    if (starts(m, "You were spotted")) { snd("spotted"); return; }
    if (starts(m, "Room cleared")) { snd("@floor_clear"); return; }
    if (starts(m, "Arena reset")) { reset_now = 1; return; }
    /* doors and plaques */
    if (starts(m, "The guardian falls")) { snd("boss_death"); snd_at("door_open", 1.6f); return; }
    if (has(m, "door grinds open")) { snd_at("door_open", 0.3f); return; }
    if (has(m, "door is sealed") || has(m, "won't budge") || has(m, "leave mid-fight")) { snd("door_locked"); return; }
    {
        static const char *plq[] = { "AND - ", "OR - ", "XOR - ", "NAND - ", "NOR - ", "XNOR - ", "CIRCUIT - ", "WARDEN - ", "LANTERN - ", "POWER - ", "THRONE - ", "The plaque is blank" };
        for (int i = 0; i < 12; i++) if (starts(m, plq[i])) { snd("plaque_read"); return; }
    }
    /* bosses */
    if (starts(m, "A Warden blocks") || starts(m, "The Dark Shade rises") || starts(m, "Grand Wizard Ymir:") || starts(m, "The Logic Keeper raises")
        || starts(m, "Altair and Smo block") || starts(m, "The Forgotten King watches")) { snd("boss_intro"); return; }
    if (has(m, "shield breaks")) { snd("warden_shield_break"); return; }
    if (starts(m, "WARDEN: Burn anew")) { world_event(); snd("warden_laser"); snd_at("warden_teleport", 0.5f); return; }
    if (has(m, "lantern flares up")) { world_event(); snd("shade_snuff"); snd_at("lantern_blaze", 0.35f); return; }
    if (has(m, "snuffs out a torch")) { world_event(); snd("shade_snuff"); return; }
    if (has(m, "lantern blazes")) { snd("lantern_blaze"); return; }
    if (has(m, "shatters the lantern")) { world_event(); snd("ward_shatter"); return; }
    if (has(m, "ward shatters")) { snd("ward_shatter"); return; }
    if (has(m, "rewrites the gate")) { snd("gate_rotate"); return; }
    if (has(m, "power is spent")) { snd("ymir_stun"); return; }
    if (has(m, "releases a blue wave")) { world_event(); snd("ymir_wave"); return; }
    if (has(m, "rises again!")) { snd("duo_empower"); return; }
    if (has(m, "throne's wire blazes")) { snd("wire_power"); return; }
    if (has(m, "slams his throne")) { world_event(); snd("throne_slam"); return; }
    if (has(m, "has fallen...")) { snd("fake_death"); fallen_quiet = 1; return; }
    if (has(m, "UNBOUND!")) { snd_stop("fake_death"); snd("king_revive"); snd_at("unbound_roar", 2.75f); fallen_quiet = 0; unbound_hold = 3.0f; return; }
    if (starts(m, "The Four Bishops") || starts(m, "The Logic Keeper and its two")) { snd("boss_intro"); return; }
    if (starts(m, "The bishops cast Smite")) { snd("sunbeam"); snd_at("player_hurt", 0.3f); return; }
    if (starts(m, "The bishops cast Judgment")) { snd("ymir_wave"); snd_at("player_hurt", 0.3f); return; }
    if (starts(m, "The bishops' beams all miss")) { snd("sunbeam"); return; }
    if (starts(m, "Holy fire burns you")) { snd("torch_off"); snd("player_hurt"); return; }
    if (starts(m, "That bishop is a 0")) { snd("ui_error"); return; }
    if (starts(m, "Found the 1") || starts(m, "Found again")) { snd("bit_swap"); snd_at("stat_point", 0.2f); return; }
    if (starts(m, "A Warden's link is cut")) { snd("warden_shield_break"); return; }
    if (starts(m, "A Warden links to the Keeper")) { snd("wire_power"); return; }
    if (starts(m, "Both links are cut")) { snd("ward_shatter"); return; }
    if (starts(m, "BISHOPS - ") || starts(m, "WARDENS - ")) { snd("plaque_read"); return; }
    if (starts(m, "The Unbound shakes the room")) { world_event(); snd("unbound_mode"); snd_at("smo_slam", 0.1f); return; }
    /* things you can't do right now */
    static const char *err[] = { "Not enough mana", "Invalid target", "Not your turn", "You already acted", "Too far", "Your bag is full", "You can't",
        "You aren't trained", "Only ", "No superiority dice", "An enemy is too close", "Hiding costs", "Can't teleport", "That stat is already", "No stat points" };
    for (int i = 0; i < 15; i++) if (starts(m, err[i])) { snd("ui_error"); return; }
}

static int player_cell(int *c, int *r) {
    for (int rr = 1; rr < MAP_H - 1; rr++) for (int cc = 1; cc < MAP_W - 1; cc++) if (mc(cc, rr) == '@') { *c = cc; *r = rr; return 1; }
    return 0;
}
static void gate_sig(char *out, int max) {                 /* every gate's letter in reading order */
    int n = 0;
    for (int r = 1; r < MAP_H - 1; r++) for (int c = 1; c < MAP_W - 1; c++) if (n < max - 1 && is_gate_mid(c, r)) out[n++] = mc(c, r);
    out[n] = 0;
}
static void snd_watch(float dt) {
    static int pf = -1, php, pin, pbag, pc = -1, pr = -1, pwires = -1, ppot = -1, pworn = -1, pbits = -1, tn = -1;
    static Enemy pen[6]; static TorchPos pt[8]; static char pweap[24], pgates[40];
    static double last_step, last_wire;
    discard_now = reset_now = 0;
    for (int i = 0; i < msgq_n; i++) {
        const char *m = msgq[i];                           /* the message log: every line the game printed, in order */
        if (log_n == 0 || strcmp(log_txt[(log_n - 1) % 60], m)) { snprintf(log_txt[log_n++ % 60], 120, "%s", m); fx_from_msg(m); }
        snd_from_msg(m);
    }
    msgq_n = 0;
    if (unbound_hold > 0) unbound_hold -= dt;
    if (!S.in_game) { pin = 0; prev_hidden = 0; return; }
    if (pumped) return;                                    /* the game is mid-redraw: compare once it has finished */
    int same = pin && S.floor == pf;
    /* a new floor: down the stairs, and the rest at the door */
    if (pin && S.floor > pf && pf > 0) { snd("stairs"); if (S.hp > php) snd_at("rest", 0.8f); }
    if (S.floor != pf) { hit_n = 0; fallen_quiet = 0; }
    /* footsteps */
    int c, r;
    if (player_cell(&c, &r)) {
        int dc = abs(c - pc), dr = abs(r - pr);
        if (same && (dc || dr) && dc <= 1 && dr <= 1 && GetTime() - last_step > 0.08) {
            snd_full("footstep", NULL, 0, 0.45f, 0.92f + GetRandomValue(0, 16) / 100.0f, 0); last_step = GetTime();
        }
        pc = c; pr = r;
    }
    /* enemies hurt or killed */
    if (same && !reset_now) {
        int voiced[128] = { 0 };
        for (int i = 0; i < 6; i++) {
            Enemy *a = &pen[i], *b = &S.en[i];
            if (!a->present) continue;
            char l = a->letter;
            int died = !b->present || b->letter != l || b->hp <= 0;
            const char *kind = l == 'G' ? "goblin" : l == 'S' ? "skeleton" : l == 'O' ? "orc" : (strchr("TtUu", l) ? "enemy" : NULL);
            if (!kind) continue;                                 /* bosses have their own sounds */
            if (!strcmp(kind, "enemy") && !died) continue;       /* Altair and Smo: your weapon is enough */
            char nm[32];
            if (died && a->hp > 0) { snprintf(nm, sizeof nm, "%s_death", kind); snd(nm); }
            else if (!died && b->hp < a->hp && !voiced[(int)l]) { snprintf(nm, sizeof nm, "%s_hit", kind); snd_at(nm, 0.06f); voiced[(int)l] = 1; }
        }
    }
    memcpy(pen, S.en, sizeof pen);
    /* torches lit or put out by you */
    {
        TorchPos now[8]; int n = find_torches(now, 8), ons = 0, offs = 0, moved = n != tn;
        if (!moved) for (int i = 0; i < n; i++) if (now[i].c != pt[i].c || now[i].r != pt[i].r) moved = 1;
        if (same && !moved) for (int i = 0; i < n; i++) if (now[i].lit != pt[i].lit) { if (now[i].lit) ons++; else offs++; }
        if (ons) snd_full("torch_on", NULL, 0.06f, 1, 1, 1);  /* cancelled if a boss did it */
        if (offs) snd_full("torch_off", NULL, 0.06f, 1, 1, 1);
        memcpy(pt, now, sizeof now); tn = n;
    }
    /* wires coming alive, gates turning into other gates */
    {
        int w = 0;
        for (int rr = 1; rr < MAP_H - 1; rr++) for (int cc = 1; cc < MAP_W - 1; cc++) if (wire_on(mc(cc, rr))) w++;
        if (same && pwires >= 0 && w > pwires && GetTime() - last_wire > 0.3) { snd_at("wire_power", 0.12f); last_wire = GetTime(); }
        pwires = w;
        char g[40]; gate_sig(g, sizeof g);
        if (same && pgates[0] && g[0] && strcmp(g, pgates) && strlen(g) == strlen(pgates)) snd("gate_rotate");
        snprintf(pgates, sizeof pgates, "%s", g);
    }
    /* Altair and Smo trade the 1 and the 0 */
    {
        int both = (map_has('T') || map_has('t')) && (map_has('U') || map_has('u'));
        int bits = both ? map_has('T') * 2 + map_has('U') : -1;
        if (same && bits >= 0 && pbits >= 0 && bits != pbits) snd("bit_swap");
        pbits = bits;
    }
    /* the bag: a potion drunk, gear put on, the bag opened */
    {
        int pots = 0, worn = 0;
        if (S.bag) for (int i = 0; i < 13; i++) if (S.slot[i].present) { if (has(S.slot[i].name, "Potion")) pots++; if (S.slot[i].worn) worn++; }
        if (same && S.bag && pbag) {
            if (ppot >= 0 && pots < ppot && !discard_now) snd("potion");
            if (pworn >= 0 && worn > pworn) snd("equip");
        }
        if (same && pweap[0] && S.weapon[0] && strcmp(pweap, S.weapon)) snd("equip");
        if (pin && S.bag != pbag) snd("ui_open");
        ppot = S.bag ? pots : -1; pworn = S.bag ? worn : -1; pbag = S.bag;
        snprintf(pweap, sizeof pweap, "%s", S.weapon);
    }
    pf = S.floor; php = S.hp; pin = 1; prev_hidden = S.hidden;
}

/* which music fits what is on screen */
static int en_has(const char *letters) {
    for (int i = 0; i < 6; i++) if (S.en[i].present && strchr(letters, S.en[i].letter)) return 1;
    return 0;
}
static void music_pick(int screen, int died) {
    if (screen == 0) music_want("title");
    else if (screen == 1 || screen == 2) music_want("class_select|title");
    else if (screen == 4) music_want("victory");
    else if (screen == 5) { if (died) music_want("game_over"); else music_want(""); }
    else {
        if (fallen_quiet || unbound_hold > 0) { music_want(""); return; }
        if (en_has("Z") || map_has('Z')) music_want("boss_unbound|boss_king|boss_generic|explore");
        else if (en_has("K")) music_want("boss_king|boss_generic|explore");
        else if (en_has("M")) music_want("boss_warden|boss_generic|explore");
        else if (en_has("Dd")) music_want("boss_shade|boss_generic|explore");
        else if (en_has("Y")) music_want("boss_ymir|boss_generic|explore");
        else if (en_has("Jj")) music_want("boss_keeper|boss_generic|explore");
        else if (en_has("TtUu")) music_want("boss_duo|boss_generic|explore");
        else if (en_has("P")) music_want("boss_bishops|boss_generic|explore");
        else if (S.floor >= 16) music_want("circuits|explore");
        else music_want("explore");
    }
}

/* ================================================================== */
/* 5b. the Options menu                                                 */
/* ================================================================== */
static int opts_open, opts_paused, opts_quit;
static void return_to_title(void);
static float *drag_val;                                    /* the slider being dragged */
static void opt_label(const char *l, const char *sub, float x, float y) {
    txt(l, x, y, 19, C_TEXT);
    if (sub) txt(sub, x, y + 24, 13, C_DIM);
}
static void opt_slider(float x, float y, float w, float *v) {
    Rectangle tr = { x, y + 8, w, 12 }, hit = { x - 10, y - 4, w + 20, 36 };
    int h = hover(hit);
    if (h) ui_hovered(hit);
    if (h && click) { drag_val = v; }
    if (drag_val == v) {
        if (!IsMouseButtonDown(MOUSE_BUTTON_LEFT) && !click) drag_val = NULL;
        else { *v = (mouse.x - x) / w; if (*v < 0) *v = 0; if (*v > 1) *v = 1; }
    }
    bar(tr, *v, drag_val == v || h ? C_GOLD : C_BRONZE, NULL);
    float kx = x + w * *v;
    DrawRectangleRec((Rectangle){ kx - 7, y + 1, 14, 26 }, C_SH);
    DrawRectangleRec((Rectangle){ kx - 6, y, 12, 26 }, h || drag_val == v ? (Color){ 250, 206, 120, 255 } : C_IRON);
    bevel((Rectangle){ kx - 6, y, 12, 26 }, 2, C_HI, C_SH);
    char b[8]; snprintf(b, sizeof b, "%d%%", (int)roundf(*v * 100));
    txtb(b, x + w + 18, y + 3, 17, C_TEXT);
}
static int opt_toggle(float x, float y, int *v) {          /* an iron switch: ON / OFF */
    Rectangle r = { x, y, 112, 30 };
    int h = hover(r), changed = 0;
    if (h) ui_hovered(r);
    if (h && click) { *v = !*v; changed = 1; snd("ui_click"); }
    DrawRectangleRec(r, (Color){ 12, 12, 15, 255 });
    bevel(r, 2, C_SH, C_HI);
    Rectangle k = { *v ? x + 56 : x + 2, y + 2, 54, 26 };
    DrawRectangleRec(k, *v ? (Color){ 74, 120, 70, 255 } : C_CARD2);
    bevel(k, 2, C_HI, C_SH);
    txtb(*v ? "ON" : "OFF", k.x + 27 - twb(*v ? "ON" : "OFF", 14) / 2, k.y + 5, 14, *v ? C_TEXT : C_DIM);
    DrawRectangleLinesEx(r, 1, h ? C_GOLD : Fade(C_BRONZE, 0.7f));
    return changed;
}
static int opt_choice(float x, float y, int n, const char **names, int *v, int enabled) {   /* a row of tablets, one lit */
    int changed = 0;
    for (int i = 0; i < n; i++) {
        float w = twb(names[i], 14) + 26;
        Rectangle r = { x, y, w, 30 };
        int h = enabled && hover(r);
        if (h) ui_hovered(r);
        if (h && click && *v != i) { *v = i; changed = 1; snd("ui_click"); }
        int on = *v == i;
        DrawRectangleRec(r, on ? (Color){ 96, 66, 36, 255 } : h ? (Color){ 64, 66, 72, 255 } : C_CARD2);
        bevel(r, 2, on ? (Color){ 210, 160, 92, 255 } : C_HI, C_SH);
        txtb(names[i], r.x + 13, r.y + 7, 14, !enabled ? Fade(C_DIM, 0.5f) : on ? (Color){ 250, 220, 160, 255 } : C_TEXT);
        x += w + 6;
    }
    return changed;
}
static void apply_window(void) {
#ifndef RD_TEST
    int mon = GetCurrentMonitor(), mw = GetMonitorWidth(mon), mh = GetMonitorHeight(mon);
    int borderless = IsWindowState(FLAG_BORDERLESS_WINDOWED_MODE);
    if (set.fullscreen != borderless) ToggleBorderlessWindowed();
    if (set.fullscreen) return;
    static const int WS[3][2] = { { 1280, 655 }, { 1440, 737 }, { 1720, 880 } };
    int w, h;
    if (set.win < 3) { w = WS[set.win][0]; h = WS[set.win][1]; }
    else { w = (int)(mw * 0.94f); h = w * 880 / 1720; if (h > mh * 0.9f) { h = (int)(mh * 0.9f); w = h * 1720 / 880; } }
    if (w > mw) w = mw;
    if (h > mh) h = mh;
    SetWindowSize(w, h);
    SetWindowPosition(GetMonitorPosition(mon).x + (mw - w) / 2, GetMonitorPosition(mon).y + (mh - h) / 2);
#endif
}
static void options_set_open(int open) {
    if (open == opts_open) return;
    opts_open = open; drag_val = NULL;
    snd(open ? "ui_open" : "ui_click");
    if (open && S.in_game && !game_over && game_pid > 0) { kill(game_pid, SIGSTOP); opts_paused = 1; }   /* the dungeon waits */
    if (!open) { if (opts_paused && game_pid > 0) kill(game_pid, SIGCONT); opts_paused = 0; settings_save(); }
}
static void options_menu(void) {
    DrawRectangle(0, 0, W, H, Fade(BLACK, 0.7f));
    Rectangle c = { W / 2.0f - 720, 90, 1440, 640 };
    card(c);
    txtb("OPTIONS", c.x + 40, c.y + 26, 34, (Color){ 250, 206, 120, 255 });
    if (opts_paused) txt("The game is paused while this is open.", c.x + 250, c.y + 40, 16, C_DIM);
    DrawRectangleRec((Rectangle){ c.x + 700, c.y + 100, 1, c.height - 200 }, C_LINE);
    /* left: audio */
    float lx = c.x + 50, vx = c.x + 300, y = c.y + 100;
    txtb("AUDIO", lx - 10, y, 16, C_BRONZE); y += 40;
    opt_label("Master volume", NULL, lx, y); opt_slider(vx, y, 280, &set.master); y += 56;
    opt_label("Music", NULL, lx, y); opt_slider(vx, y, 280, &set.music); y += 56;
    opt_label("Sound effects", NULL, lx, y);
    {   float before = set.sfx; opt_slider(vx, y, 280, &set.sfx);
        static double last_t; if (set.sfx != before && GetTime() - last_t > 0.25) { snd("pickup"); last_t = GetTime(); } }   /* hear it as you drag */
    y += 70;
    opt_label("Interface sounds", "hover and click on buttons", lx, y); opt_toggle(vx, y + 2, &set.ui_snd); y += 66;
    opt_label("Mute in the background", "silent when the window isn't focused", lx, y); opt_toggle(vx, y + 2, &set.mute_unfocused); y += 66;
    txt("F9 / F10 mute sound / music at any time", lx, y + 10, 14, C_DIM);
    /* right: display and readability */
    lx = c.x + 740; vx = c.x + 1010; y = c.y + 100;
    txtb("DISPLAY", lx - 10, y, 16, C_BRONZE); y += 40;
    opt_label("Fullscreen", "also F11", lx, y);
    if (opt_toggle(vx, y + 2, &set.fullscreen)) apply_window();
    y += 62;
    {   const char *ws[4] = { "1280", "1440", "1720", "Fit screen" };
        opt_label("Window width", set.fullscreen ? "turn fullscreen off to pick" : "the height follows", lx, y);
        if (opt_choice(vx, y + 2, 4, ws, &set.win, !set.fullscreen)) apply_window();
        y += 62; }
    {   const char *ts[4] = { "90%", "100%", "110%", "120%" };
        opt_label("Text size", NULL, lx, y); opt_choice(vx, y + 2, 4, ts, &set.scale, 1); y += 56; }
    opt_label("Screen shake", "slams, roars and explosions", lx, y); opt_toggle(vx, y + 2, &set.shake); y += 62;
    opt_label("Reduce flashing", "softer white flashes and hurt flash", lx, y); opt_toggle(vx, y + 2, &set.calm); y += 76;
    txtb("READABILITY", lx - 10, y, 16, C_BRONZE); y += 40;
    opt_label("Colourblind-friendly puzzles", "wires: thick = powered, dotted = off", lx, y); opt_toggle(vx, y + 2, &set.cb);
    if (!opts_quit && button((Rectangle){ c.x + c.width - 230, c.y + c.height - 76, 190, 50 }, "Back  (Esc)", C_GOLD, 1)) options_set_open(0);
    if (!opts_quit && button((Rectangle){ c.x + 40, c.y + c.height - 76, 160, 50 }, "Quit", C_RED, 1)) opts_quit = 1;
    if (opts_quit) {                                         /* are you sure? */
        DrawRectangle(0, 0, W, H, Fade(BLACK, 0.55f));
        Rectangle q = { W / 2.0f - 330, H / 2.0f - 120, 660, 230 };
        card(q);
        txtb("Leave the dungeon?", q.x + 40, q.y + 30, 30, (Color){ 250, 206, 120, 255 });
        txt("Your current run will be lost.", q.x + 40, q.y + 74, 18, C_DIM);
        if (button((Rectangle){ q.x + 40, q.y + 140, 200, 52 }, "Return to title", C_GOLD, 1)) { opts_quit = 0; return_to_title(); }
        if (button((Rectangle){ q.x + 260, q.y + 140, 170, 52 }, "Quit game", C_RED, 1)) { opts_quit = 0; wants_exit = 1; }
        if (button((Rectangle){ q.x + 450, q.y + 140, 170, 52 }, "Cancel", C_GREEN, 1)) opts_quit = 0;
    }
}
static void return_to_title(void) {                         /* a fresh game process, back at the title screen */
    opts_open = 0; opts_paused = 0; drag_val = NULL; settings_save();
    stop_game(); memset(&S, 0, sizeof S); log_n = 0; chosen_class = 0; memset(nst, 0, sizeof nst); memset(&fst, 0, sizeof fst); pv_kind = 0;
    start_game();
}

static void title_screen(void) {
    corridor_bg(1.0f, 0);
    /* the title on a bronze plaque, bolted to the wall */
    Rectangle pl = { W / 2.0f - 470, 150, 940, 170 };
    DrawRectangleRounded((Rectangle){ pl.x + 8, pl.y + 10, pl.width, pl.height }, 0, 0, Fade(BLACK, 0.6f));
    DrawRectangleRounded(pl, 0, 0, (Color){ 96, 66, 36, 255 });
    bevel(pl, 4, (Color){ 210, 160, 92, 255 }, (Color){ 46, 28, 14, 255 });
    DrawRectangleRoundedLinesEx((Rectangle){ pl.x + 14, pl.y + 14, pl.width - 28, pl.height - 28 }, 0, 0, 2, (Color){ 60, 38, 18, 255 });
    for (int i = 0; i < 4; i++) rivet(i & 1 ? pl.x + pl.width - 22 : pl.x + 22, i & 2 ? pl.y + pl.height - 22 : pl.y + 22);
    txt_c("LOGIC IN DUNGEON", W / 2.0f + 3, pl.y + 30, 84, (Color){ 40, 24, 10, 255 }, 1);   /* engraved: dark cut, then the gold */
    txt_c("LOGIC IN DUNGEON", W / 2.0f, pl.y + 26, 84, (Color){ 250, 206, 120, 255 }, 1);
    txt_c("Thirty floors. Every door is locked by logic.", W / 2.0f, pl.y + 120, 22, (Color){ 240, 214, 170, 255 }, 0);
    /* the heroes walking toward the dark */
    const char **cl[3] = { SPR_FIGHTER, SPR_ROGUE, SPR_WIZARD };
    for (int i = 0; i < 3; i++) {                             /* they float gently, each in its own rhythm */
        float x = W / 2.0f - 230 + i * 160, lift = 10 + 8 * sinf(T * 2.2f + i * 2.1f);
        Color glow = i == 0 ? C_BLUE : i == 1 ? C_GREEN : C_PURPLE;
        DrawEllipse((int)(x + 48), 668, 40 - lift * 0.8f, 8, Fade(BLACK, 0.55f - lift * 0.015f));
        DrawCircleGradient((int)(x + 48), 664, 46, Fade(glow, 0.30f), BLANK);
        DrawCircleGradient((int)(x + 48), 610 - lift, 90, Fade(glow, 0.10f), BLANK);
        sprite(cl[i], 16, x, 560 - lift, 6, WHITE, 0);
    }
    /* the menu */
    if (!how_open) {
        float bw = 230, bx = W / 2.0f - (bw * 4 + 60) / 2;
        if (button((Rectangle){ bx, 720, bw, 58 }, "Start", C_GREEN, 1)) game_send("\r", 1);
        if (button((Rectangle){ bx + bw + 20, 720, bw, 58 }, "How to Play", C_GOLD, 1)) how_open = 1;
        if (button((Rectangle){ bx + 2 * (bw + 20), 720, bw, 58 }, "Options", C_GOLD, 1)) options_set_open(1);
        if (button((Rectangle){ bx + 3 * (bw + 20), 720, bw, 58 }, "Quit", C_RED, 1)) wants_exit = 1;
        float a = 0.45f + 0.35f * sinf(T * 3);
        txt_c("Enter: start", W / 2.0f, 800, 18, Fade(C_TEXT, a), 0);
        txt_c(snd_on ? (mus_on ? "F9: sound on    F10: music on" : "F9: sound on    F10: music off") : "F9: sound off", W / 2.0f, 836, 15, Fade(C_DIM, 0.8f), 0);
        return;
    }
    /* How to Play */
    if (IsKeyPressed(KEY_ESCAPE) || IsKeyPressed(KEY_BACKSPACE)) how_open = 0;
    DrawRectangle(0, 0, W, H, Fade(BLACK, 0.6f));
    Rectangle c = { 140, 50, W - 280, H - 100 };
    card(c);
    card_title("HOW TO PLAY", c.x + 24, c.y + 20);
    float lx = c.x + 40, y = c.y + 70;
    txtb("The goal", lx, y, 22, C_GOLD);
    txt("Go down thirty floors and defeat the Forgotten King. Every door is locked by a logic puzzle,", lx, y + 30, 18, C_TEXT);
    txt("and every boss has a logic weakness. Torches are inputs: lit = 1, dark = 0.", lx, y + 54, 18, C_TEXT);
    y += 100;
    txtb("The gates", lx, y, 22, C_GOLD);
    const char gl[6] = { 'A', 'V', 'X', 'a', 'v', 'E' };
    const char *rule[6] = { "1 only if BOTH are 1", "1 if AT LEAST ONE is 1", "1 if EXACTLY ONE is 1", "1 unless BOTH are 1", "1 only if NEITHER is 1", "1 if both are THE SAME" };
    for (int i = 0; i < 6; i++) {
        float gx = lx + (i % 3) * 470, gy = y + 36 + (i / 3) * 78;
        Rectangle tile2 = { gx, gy, 64, 64 };
        DrawRectangleRounded(tile2, 0, 0, C_CARD2);
        bevel(tile2, 2, C_HI, C_SH);
        gate_icon(gl[i], gx + 30, gy + 32, 34, C_GOLD, Fade(C_GOLD, 0.25f));
        txtb(gate_name(gl[i]), gx + 80, gy + 8, 22, C_TEXT);
        txt(rule[i], gx + 80, gy + 36, 17, C_DIM);
    }
    y += 210;
    txtb("Circuits", lx, y, 22, C_GOLD);
    txt("From floor 16, gates feed other gates. Powered wires glow gold. Get a 1 all the way to the door.", lx, y + 30, 18, C_TEXT);
    txt("A '?\?\?' gate is hidden: click the plaque by the door and it tells you that gate's riddle.", lx, y + 54, 18, C_TEXT);
    y += 100;
    txtb("Controls", lx, y, 22, C_GOLD);
    const char *k1[] = { "Click", "Right-click", "Space", "T", "I", "U", "X", "R", "Q" };
    const char *k2[] = { "walk, attack, use, cast", "cancel", "end your turn", "turn-based on/off", "bag (wizard)", "spend a stat point", "throw an item away", "restart the room", "quit" };
    for (int i = 0; i < 9; i++) {
        float kx = lx + (i % 3) * 470, ky = y + 34 + (i / 3) * 32;
        keycap(k1[i], kx, ky);
        txt(k2[i], kx + tw(k1[i], 14) + 22, ky, 17, C_TEXT);
    }
    txt("Fighter: M maneuver, P parry, L rally, G action surge.   Rogue: H hide (3 movement in a fight).   Wizard: 1-9 spells.", lx, y + 138, 17, C_DIM);
    if (button((Rectangle){ c.x + c.width - 230, c.y + c.height - 74, 200, 52 }, "Back", C_GOLD, 1)) how_open = 0;
}
static void banner(Rectangle r, Color cloth, Color trim, float sway) {   /* a hanging cloth banner, swaying from the top */
    int strips = 24;
    float sw = r.width / strips;
    for (int k = 0; k < 40; k++) {                             /* vertical slices, shifted more the lower they hang */
        float y0 = r.y + r.height * k / 40.0f, y1 = r.y + r.height * (k + 1) / 40.0f;
        float f = (float)k / 40.0f, off = sway * f * f;
        float shade = 1 - 0.12f * f;
        Color c = { (unsigned char)(cloth.r * shade), (unsigned char)(cloth.g * shade), (unsigned char)(cloth.b * shade), 255 };
        DrawRectangleRec((Rectangle){ r.x + off, y0, r.width, y1 - y0 + 1 }, c);
        DrawRectangleRec((Rectangle){ r.x + off, y0, 8, y1 - y0 + 1 }, trim);
        DrawRectangleRec((Rectangle){ r.x + off + r.width - 8, y0, 8, y1 - y0 + 1 }, trim);
        for (int s2 = 1; s2 < strips; s2 += 6) DrawRectangleRec((Rectangle){ r.x + off + s2 * sw, y0, 2, y1 - y0 + 1 }, Fade(BLACK, 0.08f));   /* folds */
    }
    float off = sway, by = r.y + r.height;                      /* the swallowtail */
    Vector2 tl = { r.x + off, by - 1 }, tr = { r.x + off + r.width, by - 1 }, mid = { r.x + off + r.width / 2, by + 60 },
            lp = { r.x + off, by + 70 }, rp = { r.x + off + r.width, by + 70 };
    Color dk = { (unsigned char)(cloth.r * 0.86f), (unsigned char)(cloth.g * 0.86f), (unsigned char)(cloth.b * 0.86f), 255 };
    Vector2 tri[3][3] = { { tl, mid, lp }, { tr, rp, mid }, { tl, tr, mid } };
    for (int k = 0; k < 3; k++) { DrawTriangle(tri[k][0], tri[k][1], tri[k][2], dk); DrawTriangle(tri[k][0], tri[k][2], tri[k][1], dk); }   /* both windings */
    DrawRectangleRec((Rectangle){ r.x + off, by - 2, 8, 72 }, trim);
    DrawRectangleRec((Rectangle){ r.x + off + r.width - 8, by - 2, 8, 72 }, trim);
    DrawLineEx((Vector2){ r.x + off, by + 70 }, (Vector2){ r.x + off + r.width / 2, by + 60 }, 6, trim);
    DrawLineEx((Vector2){ r.x + off + r.width / 2, by + 60 }, (Vector2){ r.x + off + r.width, by + 70 }, 6, trim);
    DrawRectangleRec((Rectangle){ r.x - 26, r.y - 14, r.width + 52, 14 }, (Color){ 60, 60, 66, 255 });   /* the iron rod */
    DrawRectangleRec((Rectangle){ r.x - 26, r.y - 14, r.width + 52, 4 }, (Color){ 120, 124, 132, 255 });
    DrawCircle((int)(r.x - 30), (int)(r.y - 7), 10, C_IRON); DrawCircle((int)(r.x + r.width + 30), (int)(r.y - 7), 10, C_IRON);
    for (int k = 0; k < 4; k++) DrawRectangleRec((Rectangle){ r.x + 20 + k * (r.width - 40) / 3 - 5, r.y - 6, 10, 14 }, C_IRON);   /* rings */
}
static void class_screen(void) {
    corridor_bg(0.35f, 0.45f);
    txt_c("Choose your hero", W / 2.0f + 3, 34, 52, BLACK, 1);
    txt_c("Choose your hero", W / 2.0f, 30, 52, (Color){ 250, 206, 120, 255 }, 1);
    const char **cl[3] = { SPR_FIGHTER, SPR_ROGUE, SPR_WIZARD };
    const char *nm[3] = { "FIGHTER", "ROGUE", "WIZARD" };
    const char *sub[3] = { "the Knight", "the Thief", "the Wizard" };
    const char *hp[3] = { "12 HP    AC 15", "11 HP    AC 14", "9 HP    AC 12" };
    const char *l1[3] = { "Two attacks every turn", "Hide and sneak attack", "Firebolt and Ray of Frost" };
    const char *l2[3] = { "Battle Master maneuvers", "Hiding costs movement", "Learns spells from scrolls" };
    const char *l3[3] = { "Heavy armor and shields", "Light armor and rapiers", "Mana refills over time" };
    const int st[3][4] = { { 16, 13, 16, 13 }, { 12, 16, 13, 15 }, { 10, 14, 10, 19 } };
    Color cloth[3] = { { 38, 60, 132, 255 }, { 34, 92, 52, 255 }, { 84, 44, 128, 255 } };
    Color glow[3] = { C_BLUE, C_GREEN, C_PURPLE };
    for (int i = 0; i < 3; i++) {
        Rectangle area = { W / 2.0f - 560 + i * 380, 110, 360, 690 };
        int h = hover(area);
        Rectangle r = { area.x + 20, 130, 320, 560 };
        float sway = h ? 16 * sinf(T * 2.6f) : 4 * sinf(T * 1.3f + i);
        if (h) DrawCircleGradient((int)(r.x + r.width / 2), 380, 340, Fade(glow[i], 0.22f), BLANK);
        banner(r, h ? (Color){ (unsigned char)fminf(255, cloth[i].r * 1.25f), (unsigned char)fminf(255, cloth[i].g * 1.25f), (unsigned char)fminf(255, cloth[i].b * 1.25f), 255 } : cloth[i],
               h ? C_GOLD : (Color){ 176, 136, 70, 255 }, sway);
        float cx = r.x + r.width / 2 + sway * 0.3f;
        txt_c(nm[i], cx + 2, r.y + 22, 40, BLACK, 1);
        txt_c(nm[i], cx, r.y + 20, 40, C_TEXT, 1);
        txt_c(sub[i], cx, r.y + 64, 18, (Color){ 230, 210, 170, 255 }, 0);
        float lift = (h ? 14 : 6) + 5 * sinf(T * 2.2f + i * 2.1f);       /* the hero floats in front of the banner */
        DrawCircleGradient((int)cx, (int)(r.y + 200 - lift), h ? 110 : 80, Fade(glow[i], h ? 0.35f : 0.18f), BLANK);
        sprite(cl[i], 16, cx - 64, r.y + 110 - lift, 8, WHITE, 0);
        txt_c(hp[i], cx, r.y + 262, 20, C_TEXT, 1);
        const char *sn[4] = { "STR", "DEX", "CON", "INT" };
        for (int k = 0; k < 4; k++) {                           /* stat bars */
            float by = r.y + 300 + k * 26;
            txtb(sn[k], r.x + 36, by, 15, (Color){ 230, 210, 170, 255 });
            Rectangle bb = { r.x + 84, by + 3, 170, 12 };
            DrawRectangleRec(bb, Fade(BLACK, 0.45f));
            DrawRectangleRec((Rectangle){ bb.x, bb.y, bb.width * (st[i][k] - 6) / 14.0f, bb.height }, h ? C_GOLD : (Color){ 200, 160, 90, 255 });
            char v[8]; snprintf(v, sizeof v, "%d", st[i][k]); txtb(v, bb.x + bb.width + 10, by, 15, C_TEXT);
        }
        const char *ls[3] = { l1[i], l2[i], l3[i] };
        for (int k = 0; k < 3; k++) {
            float ly = r.y + 420 + k * 30;
            DrawRectanglePro((Rectangle){ r.x + 42, ly + 9, 7, 7 }, (Vector2){ 3.5f, 3.5f }, 45, C_GOLD);
            txt(ls[k], r.x + 56, ly, 17, C_TEXT);
        }
        char kk[16]; snprintf(kk, sizeof kk, "%d", i + 1);
        keycap(kk, cx - 10, r.y + r.height + 80);
        if (h) ui_hovered(area);
        if (h && click) { char s2[3] = { (char)('1' + i), '\r', 0 }; game_send(s2, 2); chosen_class = i + 1; snd("equip"); }
    }
    txt_c("Click a banner, or press 1, 2 or 3 and Enter", W / 2.0f, 836, 20, (Color){ 220, 200, 160, 255 }, 0);
}
static void text_screen(void) {                            /* the character sheet and stat menus */
    backdrop();
    float need = 120;                                          /* measure first, so the card fits */
    for (int r = 0; r < ROWS; r++) {
        char t[COLS + 1]; row_text(r, 0, COLS, t);
        if (!t[0]) continue;
        need += t[0] == '=' ? 14 : (isdigit((unsigned char)t[0]) && t[1] == '.') ? 40 : 30;
    }
    if (need > 780) need = 780;
    if (need < 300) need = 300;
    Rectangle c = { W / 2.0f - 460, (H - need) / 2, 920, need };
    card(c);
    if (chosen_class) sprite(chosen_class == 2 ? SPR_ROGUE : chosen_class == 3 ? SPR_WIZARD : SPR_FIGHTER, 16, c.x + c.width - 120, c.y + 24, 6, WHITE, 0);
    float y = c.y + 30;
    int yn = 0;
    for (int r = 0; r < ROWS; r++) {
        char t[COLS + 1]; row_text(r, 0, COLS, t);
        if (!t[0]) { continue; }
        if (t[0] == '=') { DrawRectangleRec((Rectangle){ c.x + 30, y + 6, c.width - 180, 1 }, C_LINE); y += 14; continue; }
        if (strstr(t, "(y/n)") || strstr(t, "(Y/N)")) { yn = 1; txtb(t, c.x + 40, y, 22, C_GOLD); y += 34; continue; }
        if (isdigit((unsigned char)t[0]) && t[1] == '.') {    /* "1. Strength" -> a button */
            Rectangle b = { c.x + 40, y, 300, 34 };
            if (button(b, t + 3, C_GOLD, 1)) { char s[3] = { t[0], '\r', 0 }; game_send(s, 2); }
            keycap((char[2]){ t[0], 0 }, b.x + b.width + 10, y + 6);
            y += 40; continue;
        }
        int head = strstr(t, "Character Sheet") || strstr(t, "Extra Stats") || strstr(t, "complete");
        if (head) { txtb(t, c.x + 40, y, 32, C_TEXT); y += 44; }
        else { txt(t, c.x + 40, y, 20, C_TEXT); y += 28; }
        if (y > c.y + c.height - 80) break;
    }
    if (yn) {
        if (button((Rectangle){ c.x + 40, c.y + c.height - 70, 160, 44 }, "Yes  (Y)", C_GREEN, 1)) game_send("y\r", 2);
        if (button((Rectangle){ c.x + 220, c.y + c.height - 70, 160, 44 }, "No  (N)", C_RED, 1)) game_send("n\r", 2);
    }
}
static void victory_screen(void) {
    backdrop();
    DrawCircleGradient(W / 2, 300, 300, Fade(C_GOLD, 0.15f + 0.05f * sinf(T * 2)), BLANK);
    DrawCircleGradient(W / 2, 200, 200, Fade((Color){ 120, 20, 30, 255 }, 0.25f), BLANK);
    sprite(SPR_UNBOUND, 48, W / 2.0f - 120, 60 + sinf(T * 0.8f) * 3, 5, (Color){ 150, 140, 150, 255 }, 0);   /* the Unbound, fallen still */
    txt_c("The Forgotten King falls silent.", W / 2.0f, 380, 44, C_GOLD, 1);
    txt_c("The last gate is solved. You have won!", W / 2.0f, 440, 26, C_TEXT, 0);
    if (button((Rectangle){ W / 2.0f - 220, 540, 200, 52 }, "Play again", C_GREEN, 1)) game_send("y", 1);
    if (button((Rectangle){ W / 2.0f + 20, 540, 200, 52 }, "Quit", C_RED, 1)) game_send("n", 1);
}

/* ================================================================== */
/* 7. putting it together                                              */
/* ================================================================== */
static int map_click_cell(int *col, int *row) {          /* canvas mouse -> the game's terminal cell */
    int c = (int)floorf((mouse.x - MAP_X) / TS), r = (int)floorf((mouse.y - MAP_Y) / TS);
    if (c < 0 || c >= MAP_W || r < 0 || r >= MAP_H) return 0;
    *col = c + 1; *row = r + MAP_R0 + 1; return 1;
}

static int last_hover_c = -1, last_hover_r = -1;
static void game_screen(void) {
    ClearBackground(C_BG);
    int col, row;
    if (!game_over && !opts_open && map_click_cell(&col, &row)) {           /* the map talks to the game directly */
        if (col != last_hover_c || row != last_hover_r) send_mouse(35, col, row);
        if (click) { send_mouse(0, col, row); click = 0; }
        last_hover_c = col; last_hover_r = row;
    } else if (last_hover_c != -1) { if (!game_over) send_mouse(35, 90, 1); last_hover_c = last_hover_r = -1; }
    if (rclick && !game_over) send_mouse(2, 20, 10);
    draw_top_bar();
    int shaking = shake_t > 0 && set.shake;
    if (shaking) { rlPushMatrix(); rlTranslatef((rnd((int)(T * 60)) - 0.5f) * 14 * shake_t, (rnd((int)(T * 60) + 7) - 0.5f) * 14 * shake_t, 0); }
    draw_map();
    draw_fx(GetFrameTime());
    draw_heads();
    draw_spell_fx(GetFrameTime());
    if (shaking) rlPopMatrix();
    float y = MAP_Y + MAP_H * TS + 16, h = H - y - 10;
    draw_enemies_card((Rectangle){ 12, y, 420, h });
    draw_slots_card((Rectangle){ 444, y, 660, h });
    draw_log_card((Rectangle){ 1116, y, W - 12 - 1116, h });
    if (hurt_t > 0) {                                          /* red flash at the edges when you're hit */
        float a = hurt_t / 0.6f * (set.calm ? 0.4f : 1);
        DrawRectangleGradientV(0, 0, W, 90, Fade(C_RED, 0.35f * a), BLANK);
        DrawRectangleGradientV(0, H - 90, W, 90, BLANK, Fade(C_RED, 0.35f * a));
        DrawRectangleGradientH(0, 0, 90, H, Fade(C_RED, 0.35f * a), BLANK);
        DrawRectangleGradientH(W - 90, 0, 90, H, BLANK, Fade(C_RED, 0.35f * a));
    }
    draw_item_tooltip();
    if (xp_gain_t > 0) xp_gain_t -= GetFrameTime();
    draw_fx_overlay(GetFrameTime());
}

static void game_over_overlay(void) {
    DrawRectangle(0, 0, W, H, Fade(BLACK, 0.65f));
    int died = log_n > 0 && strstr(log_txt[(log_n - 1) % 60], "died");
    Rectangle c = { W / 2.0f - 300, H / 2.0f - 150, 600, 300 };
    card(c);
    txt_c(died ? "You died" : "Game closed", W / 2.0f, c.y + 40, 52, died ? C_RED : C_TEXT, 1);
    if (died && S.floor) { char b[48]; snprintf(b, sizeof b, "You reached floor %d", S.floor); txt_c(b, W / 2.0f, c.y + 110, 22, C_DIM, 0); }
    if (button((Rectangle){ c.x + 80, c.y + 190, 200, 52 }, "Play again", C_GREEN, 1)) {
        stop_game(); memset(&S, 0, sizeof S); log_n = 0; chosen_class = 0; memset(nst, 0, sizeof nst); memset(&fst, 0, sizeof fst); pv_kind = 0; start_game();
    }
    if (button((Rectangle){ c.x + 320, c.y + 190, 200, 52 }, "Quit", C_RED, 1)) wants_exit = 1;
}

/* test mode (compile with -DRD_TEST): read scripted input from $RD_SCRIPT */
#ifdef RD_TEST
static float test_wheel;
static FILE *script; static double wait_until; static Vector2 test_mouse = { -1, -1 }; static int test_click, test_rclick;
static int test_step(void) {
    if (!script || GetTime() < wait_until) return 0;
    char line[256];
    while (GetTime() >= wait_until && fgets(line, sizeof line, script)) {
        int a, b; char path[200];
        if (sscanf(line, "wait %d", &a) == 1) { wait_until = GetTime() + a / 1000.0; break; }
        else if (!strncmp(line, "key ", 4)) for (char *p = line + 4; *p && *p != '\n'; p++) { if (*p == '\\' && p[1] == 'n') { game_send("\r", 1); p++; } else game_send(p, 1); }
        else if (sscanf(line, "uiclick %d %d", &a, &b) == 2) { test_mouse = (Vector2){ a, b }; test_click = 1; break; }
        else if (sscanf(line, "uirclick %d %d", &a, &b) == 2) { test_mouse = (Vector2){ a, b }; test_rclick = 1; break; }
        else if (sscanf(line, "uihover %d %d", &a, &b) == 2) { test_mouse = (Vector2){ a, b }; break; }
        else if (sscanf(line, "shot %199s", path) == 1) { TakeScreenshot(path); }
        else if (sscanf(line, "dump %199s", path) == 1) { pump_game(); FILE *f = fopen(path, "w"); for (int r = 0; r < ROWS; r++) fprintf(f, "%.*s\n", COLS, scr[r]); fclose(f); }
        else if (sscanf(line, "wheel %d", &a) == 1) { test_wheel = (float)a; }
        else if (!strncmp(line, "osc ", 4)) { line[strcspn(line, "\n")] = 0; handle_osc(line + 4); }
        else if (!strncmp(line, "esc", 3)) { if (opts_open) options_set_open(0); else options_set_open(1); }
        else if (!strncmp(line, "fakemsg ", 8)) { line[strcspn(line, "\n")] = 0; if (snd_log) fprintf(snd_log, "== %s\n", line + 8); snd_from_msg(line + 8); }
        else if (!strncmp(line, "quit", 4)) return 1;
    }
    if (feof(script)) clearerr(script);
    return 0;
}
#endif

static Font load_font(const char **paths, int bold) {
    for (int i = 0; paths[i]; i++) if (FileExists(paths[i])) {
        Font f = LoadFontEx(paths[i], 64, NULL, 0);
        if (f.texture.id) { GenTextureMipmaps(&f.texture); SetTextureFilter(f.texture, TEXTURE_FILTER_TRILINEAR); return f; }
    }
    (void)bold;
    return GetFontDefault();
}

int main(int argc, char **argv) {
    if (argc > 1) game_path = argv[1];
    if (access(game_path, X_OK) != 0) { fprintf(stderr, "Can't find the game program '%s'. Build it first (sh build.sh).\n", game_path); return 1; }
    signal(SIGPIPE, SIG_IGN);
    start_game();
#ifdef RD_TEST
    SetConfigFlags(FLAG_MSAA_4X_HINT);
    InitWindow(W, H, "Logic In Dungeon");
#else
    SetConfigFlags(FLAG_MSAA_4X_HINT | FLAG_VSYNC_HINT | FLAG_WINDOW_RESIZABLE);
    InitWindow(1440, 737, "Logic In Dungeon");
    SetWindowMinSize(860, 440);
#endif
    SetTargetFPS(60);
    SetExitKey(0);
    const char *reg[] = { "assets/font.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                          "/usr/share/fonts/google-noto/NotoSans-Regular.ttf", "/usr/share/fonts/liberation-sans/LiberationSans-Regular.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf", NULL };
    const char *bld[] = { "assets/font_bold.ttf", "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                          "/usr/share/fonts/google-noto/NotoSans-Bold.ttf", "/usr/share/fonts/liberation-sans/LiberationSans-Bold.ttf",
                          "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf", NULL };
    F = load_font(reg, 0); FB = load_font(bld, 1);
    audio_init();
    settings_load();
    apply_window();
#ifdef RD_TEST
    const char *sp = getenv("RD_SCRIPT"); if (sp) script = fopen(sp, "r");
#endif
    while (!WindowShouldClose() && !wants_exit) {
        float dt = GetFrameTime();
        T += dt;
        if (hurt_t > 0) hurt_t -= dt;
        for (int i = 0; i < 6; i++) if (S.en[i].flash > 0) S.en[i].flash -= dt;
        pump_game();
        parse_state();
        snd_watch(dt);
        /* fit the 1720x880 layout into the window */
        float zoom = fminf(GetScreenWidth() / (float)W, GetScreenHeight() / (float)H);
        Vector2 off = { (GetScreenWidth() - W * zoom) / 2, (GetScreenHeight() - H * zoom) / 2 };
        Camera2D cam = { off, { 0, 0 }, 0, zoom };
        mouse = GetScreenToWorld2D(GetMousePosition(), cam);
        click = IsMouseButtonPressed(MOUSE_BUTTON_LEFT);
        wheel = GetMouseWheelMove();
        rclick = IsMouseButtonPressed(MOUSE_BUTTON_RIGHT);
#ifdef RD_TEST
        if (test_step()) break;
        if (test_mouse.x >= 0) mouse = test_mouse;
        click = test_click; rclick = test_rclick; test_click = test_rclick = 0;
        wheel = test_wheel; test_wheel = 0;
#endif
        if (IsKeyPressed(KEY_F9)) snd_on = !snd_on;
        if (IsKeyPressed(KEY_F10)) mus_on = !mus_on;
        if (IsKeyPressed(KEY_F11)) { set.fullscreen = !set.fullscreen; apply_window(); settings_save(); }
        if (IsKeyPressed(KEY_ESCAPE)) { if (opts_quit) opts_quit = 0; else if (opts_open) options_set_open(0); else if (!how_open) options_set_open(1); }
        if (audio_ok) SetMasterVolume(set.master * (set.mute_unfocused && !IsWindowFocused() ? 0 : 1));
        if (opts_open) { while (GetCharPressed() > 0) {} }   /* the menu is open: keys don't reach the game */
        else if (!game_over) {                              /* keyboard straight to the game */
            int ch;
            while ((ch = GetCharPressed()) > 0) if (ch < 128) send_key((char)ch);
            if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_KP_ENTER)) game_send("\r", 1);
            if (IsKeyPressed(KEY_BACKSPACE)) game_send("\x7f", 1);
        }
        BeginDrawing();
        ClearBackground(BLACK);
        BeginMode2D(cam);
        BeginScissorMode((int)off.x, (int)off.y, (int)(W * zoom), (int)(H * zoom));
        int over = game_over, frame_click = click, menu_click = click;
        if (over || opts_open) click = 0;                   /* the dead game underneath ignores clicks */
        if (opts_open) rclick = 0;
        int screen;
        if (S.in_game || (over && have_last)) { game_screen(); screen = 3; }
        else if (screen_has("You have won")) { victory_screen(); screen = 4; }
        else if (screen_has("Press Enter to Continue")) { title_screen(); screen = 0; }
        else if (screen_has("Select a class")) { class_screen(); screen = 1; }
        else { text_screen(); screen = 2; }
        if (over && !opts_open) { click = frame_click; game_over_overlay(); screen = 5; }
        else if (over) screen = 5;
        if (opts_open) { click = menu_click; options_menu(); click = 0; }
        {   /* sounds for changing screens, and the music for this one */
            static int prev_screen = -1, prev_how;
            int died = log_n > 0 && strstr(log_txt[(log_n - 1) % 60], "died");
            if (prev_screen == 0 && screen == 1) snd("menu_start");
            if (prev_screen == 3 && screen == 2) snd("ui_open");            /* the character sheet */
            if (prev_screen != 4 && screen == 4) snd("boss_death");
            if (how_open && !prev_how) snd("ui_open");
            if (screen == 0 && prev_screen > 0) hit_n = 0;
            prev_screen = screen; prev_how = how_open;
            music_pick(screen, died);
            static int last_hover;
            if (hover_key && hover_key != last_hover) snd_full("ui_hover", NULL, 0, 0.7f, 1, 0);
            last_hover = hover_key; hover_key = 0;
        }
        snd_update(dt);
        music_update(dt);
        EndScissorMode();
        EndMode2D();
        EndDrawing();
    }
    stop_game();
    if (audio_ok) CloseAudioDevice();
    CloseWindow();
    return 0;
}
