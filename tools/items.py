"""items.py - every special weapon, armor piece and trinket in Logic In Dungeon.

Run it (python3 items.py) after changing anything here. It writes:
  items_rec.inc   the weapon / armor records          (included by game_assets.asm)
  items_cat.inc   their catalog entries               (included by features.inc)
  items_loot.inc  which legendary each boss drops, per class
  gui_items.h     names, rarity, icon and a description for the raylib window's tooltips
"""

import os as _os
_os.chdir(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), ".."))   # run from anywhere: work in the game folder
F, R, W = 0b100, 0b010, 0b001             # class bits
ALL = F | R | W
STR, DEX, CON, INT = 0b1000, 0b0100, 0b0010, 0b0001
HEAVY, MEDIUM, LIGHT, CLOTH = 0b1000, 0b0100, 0b0010, 0b0001
ANYWEAR = 0b1111
BODY, SHIELD, HELM, BOOTS, TRINKET = 0b10000, 0b01000, 0b00100, 0b00001, 0b100000
EFF = {"": 0, "burn": 1, "sleep": 2, "hold": 3, "slow": 6, "poison": 7, "blind": 9, "prone": 10, "fright": 11}
RARE, LEGEND = 1, 2

# specials: (asm name, number, what it does - shown in the tooltip)
SPECIALS = {
    "":           (0,  ""),
    "lifesteal":  (1,  "Heals you for a third of the damage it deals"),
    "pierce":     (2,  "Cuts through gate shields and the 1-bit (no halving)"),
    "spellpow":   (3,  "Spells deal +{v} damage"),
    "stealth":    (4,  "Moving never gets you spotted while hidden"),
    "thorns":     (5,  "Enemies that hit you take {v} damage"),
    "reflect":    (6,  "Ranged attacks and spells hit you for half"),
    "firsthit":   (7,  "The first hit you take in each fight is halved"),
    "move":       (8,  "+{v} movement"),
    "sneak":      (9,  "Sneak attacks roll +{v}d6"),
    "xp":         (10, "+{v}0% experience"),
    "reveal":     (11, "Hidden ??? gates show what they are"),
    "manaregen":  (12, "Mana comes back twice as fast"),
    "regen":      (13, "Heals {v} HP at the end of every round"),
    "extra":      (14, "One more attack every turn"),
    "cheap":      (15, "Spells cost 1 less mana"),
    "reach":      (16, "Flip torches from 2 cells away"),
    "light":      (17, "You shine: shadows near you can be hurt"),
}

def weapon(id, name, classes, lo, hi, scale, rng=1, eff="", two=False, ranged=False, **kw):
    return dict(id=id, name=name, kind="W", classes=classes, lo=lo, hi=hi, scale=scale, rng=rng, eff=eff, two=two, ranged=ranged, **kw)

def armor(id, name, slot, weight, ac, dexmax=99, mv=0, **kw):
    return dict(id=id, name=name, kind="A", slot=slot, weight=weight, ac=ac, dexmax=dexmax, mv=mv, **kw)

ITEMS = [
    # ---------------- rare drops (anyone who can use them, from the given floor on) ----------------
    weapon("embersword", "Ember Blade", F | R, 1, 6, STR | DEX, eff="burn", rarity=RARE, floor=3, w=5, s=1,
           icon="sword", desc="A blade that never cools. Sets enemies burning."),
    weapon("frostbite", "Frostbite", ALL, 1, 4, STR | DEX, eff="slow", rarity=RARE, floor=3, w=5, d=2,
           icon="dagger", desc="A dagger of blue ice. Slows what it cuts."),
    weapon("venomrapier", "Venom Rapier", F | R, 1, 8, STR | DEX, eff="poison", rarity=RARE, floor=6, w=4, d=1,
           icon="sword", desc="Its tip weeps green. Poisons on every hit."),
    weapon("thundermaul", "Thunder Maul", F, 2, 12, STR, eff="prone", two=True, rarity=RARE, floor=10, w=3, s=2,
           icon="maul", desc="Each blow lands like a thunderclap. Can knock enemies down."),
    weapon("emberwand", "Wand of Embers", W, 1, 6, INT, rng=2, rarity=RARE, floor=5, w=5, i=2, sp="spellpow", spv=1,
           icon="staff", desc="A short wand with a coal at its tip."),
    armor("shadowweave", "Shadowweave", BODY, LIGHT, 2, rarity=RARE, floor=6, w=4, d=2, sp="stealth",
          icon="robe", desc="Cloth woven from dusk itself."),
    armor("archrobe", "Archmage Robe", BODY, CLOTH, 1, rarity=RARE, floor=6, w=4, i=2, mana=1,
          icon="robe", desc="Embroidered with every gate's truth table."),
    armor("drakemail", "Drakescale Mail", BODY, MEDIUM, 5, dexmax=2, rarity=RARE, floor=9, w=3, c=1, sp="thorns", spv=2,
          icon="armor", desc="Scales sharp enough to cut whoever strikes you."),
    armor("spikebuckler", "Spiked Buckler", SHIELD, MEDIUM, 1, rarity=RARE, floor=5, w=4, sp="thorns", spv=2,
          icon="shield", desc="A small shield bristling with spikes."),
    armor("mirrorshield", "Mirror Shield", SHIELD, MEDIUM, 2, rarity=RARE, floor=12, w=3, sp="reflect",
          icon="shield", desc="Polished so bright that bolts glance off it."),
    armor("hornedhelm", "Horned Helm", HELM, HEAVY, 1, rarity=RARE, floor=4, w=5, s=1,
          icon="helm", desc="Heavy iron with two curling horns."),
    armor("whisperhood", "Whisper Hood", HELM, LIGHT, 0, rarity=RARE, floor=7, w=4, d=1, sp="sneak", spv=1,
          icon="hood", desc="It hushes your footsteps and your breath."),
    armor("stridingboots", "Striding Boots", BOOTS, ANYWEAR, 0, rarity=RARE, floor=4, w=5, sp="move", spv=2,
          icon="boots", desc="Every step carries you a little further."),
    armor("scholarring", "Scholar's Ring", TRINKET, ANYWEAR, 0, rarity=RARE, floor=2, w=5, i=1, sp="xp", spv=3,
          icon="ring", desc="Learn faster from every fight and every puzzle."),
    armor("lanterncharm", "Lantern Charm", TRINKET, ANYWEAR, 0, rarity=RARE, floor=12, w=3, c=1, sp="light",
          icon="amulet", desc="A tiny lantern on a chain that never goes out."),
    armor("gatekey", "Gatekey Charm", TRINKET, ANYWEAR, 0, rarity=RARE, floor=8, w=4, sp="reach",
          icon="amulet", desc="A key shaped like an AND gate. Torches answer it from afar."),
    armor("vigoramulet", "Amulet of Vigor", TRINKET, ANYWEAR, 0, rarity=RARE, floor=10, w=4, c=2,
          icon="amulet", desc="A red stone that beats like a heart."),

    # ---------------- boss legendaries: each boss drops the one made for YOUR class ----------------
    # the Warden, floor 4
    weapon("gatebreaker", "Gatebreaker", F, 1, 10, STR, rng=3, two=True, rarity=LEGEND, boss=(0, F), s=2, sp="pierce",
           icon="halberd", desc="The Warden's halberd. Reach 3."),
    weapon("keyknife", "Keyknife", F | R, 1, 6, DEX, rarity=LEGEND, boss=(0, R), d=2, sp="reach",
           icon="dagger", desc="The Warden's key, filed to a point."),
    weapon("gatestaff", "Staff of Gates", W, 1, 6, INT, rng=2, rarity=LEGEND, boss=(0, W), i=2, sp="reach",
           icon="staff", desc="Topped with a little brass gate. Torches obey it."),
    # the Warden, floor 8
    weapon("xoredge", "XOR Edge", F | R, 1, 10, STR | DEX, eff="blind", rarity=LEGEND, boss=(1, F), s=1, c=1,
           icon="sword", desc="One edge or the other, never both. Can blind."),
    weapon("twinfang", "Twinfang", F | R, 1, 8, DEX, eff="poison", rarity=LEGEND, boss=(1, R), d=2, sp="extra",
           icon="dagger", desc="Two fangs on one hilt."),
    weapon("circuitrod", "Circuit Rod", W, 1, 6, INT, rng=2, rarity=LEGEND, boss=(1, W), i=2, sp="manaregen",
           icon="staff", desc="Its runes light up like a powered wire."),
    # the Dark Shade, floor 15
    armor("duskplate", "Duskplate", BODY, HEAVY, 7, dexmax=0, mv=2, rarity=LEGEND, boss=(2, F), c=2, sp="light",
          icon="armor", desc="Black plate with a faint glow inside."),
    weapon("shadefang", "Shade Fang", F | R, 1, 6, DEX, rarity=LEGEND, boss=(2, R), d=2, sp="lifesteal",
           icon="dagger", desc="It drinks what it cuts."),
    armor("umbralrobe", "Umbral Robe", BODY, CLOTH, 1, rarity=LEGEND, boss=(2, W), i=2, mana=1, sp="spellpow", spv=2,
          icon="robe", desc="Made of the Shade's own darkness."),
    # Grand Wizard Ymir, floor 17
    weapon("frostbrand", "Frostbrand", F, 2, 12, STR, eff="slow", two=True, rarity=LEGEND, boss=(3, F), s=2,
           icon="greatsword", desc="A greatsword rimed in ice."),
    weapon("iciclebow", "Icicle Crossbow", F | R, 1, 8, DEX, rng=12, eff="slow", ranged=True, rarity=LEGEND, boss=(3, R), d=2,
           icon="bow", desc="Fires bolts of ice."),
    weapon("rimestaff", "Rimefrost Staff", W, 1, 6, INT, rng=2, eff="slow", rarity=LEGEND, boss=(3, W), i=3, mana=2, sp="cheap",
           icon="staff", desc="Ymir's own staff. The crystal still hums."),
    # the Logic Keeper, floor 21
    armor("aegis", "Keeper's Aegis", SHIELD, MEDIUM, 3, rarity=LEGEND, boss=(4, F), c=2, sp="firsthit",
          icon="shield", desc="The AND gate on it still glows."),
    armor("keepercloak", "Keeper's Cloak", BODY, LIGHT, 2, rarity=LEGEND, boss=(4, R), d=2, sp="reflect",
          icon="robe", desc="Bolts and spells slide off it."),
    armor("truthamulet", "Truth Amulet", TRINKET, ANYWEAR, 0, rarity=LEGEND, boss=(4, W), i=2, mana=1, sp="reveal",
          icon="amulet", desc="Shows the truth behind every hidden gate."),
    # Altair, floor 26
    weapon("stormspear", "Stormspear", F | R, 1, 10, STR | DEX, rng=3, eff="prone", two=True, rarity=LEGEND, boss=(5, F), s=1, d=2,
           icon="spear", desc="Altair's spear. Reach 3, and lightning that knocks you flat."),
    armor("stormboots", "Stormstep Boots", BOOTS, ANYWEAR, 0, rarity=LEGEND, boss=(5, R), d=2, sp="move", spv=3,
          icon="boots", desc="Altair's speed, in a pair of boots."),
    weapon("stormstaff", "Stormstaff", W, 1, 6, INT, rng=2, rarity=LEGEND, boss=(5, W), i=3, sp="spellpow", spv=2,
           icon="staff", desc="Crackles with Altair's lightning."),
    # Smo, floor 26
    weapon("smomaul", "Smo's Maul", F, 2, 14, STR, eff="prone", two=True, rarity=LEGEND, boss=(6, F), s=3,
           icon="maul", desc="A block of stone on a pole. Knocks enemies down."),
    armor("ironheart", "Ironheart", TRINKET, ANYWEAR, 0, rarity=LEGEND, boss=(6, R), c=3, sp="regen", spv=1,
          icon="amulet", desc="Smo's iron heart, still beating."),
    armor("heartstone", "Heartstone", TRINKET, ANYWEAR, 0, rarity=LEGEND, boss=(6, W), c=2, i=2, sp="regen", spv=1,
          icon="amulet", desc="A warm stone from inside Smo."),
]

BOSS_SLOTS = 7          # 0 Warden (4), 1 Warden (8), 2 Shade, 3 Ymir, 4 Keeper, 5 Altair, 6 Smo

def check():
    ids = set()
    for it in ITEMS:
        assert it["id"] not in ids, it["id"]; ids.add(it["id"])
        assert len(it["name"]) <= 15, it["name"]
        assert it.get("sp", "") in SPECIALS, it["id"]
    for slot in range(BOSS_SLOTS):
        for cls in (F, R, W):
            got = [it for it in ITEMS if it.get("boss") == (slot, cls)]
            assert len(got) == 1, (slot, cls)
    print(len(ITEMS), "items OK:", sum(1 for i in ITEMS if i.get("rarity") == RARE), "rare,",
          sum(1 for i in ITEMS if i.get("rarity") == LEGEND), "legendary")

def stat_text(it):
    parts = []
    if it["kind"] == "W":
        parts.append("%d-%d damage" % (it["lo"], it["hi"]))
        if it["rng"] > 1 and not it["ranged"]: parts.append("reach %d" % it["rng"])
        if it["ranged"]: parts.append("range %d" % it["rng"])
        if it["two"]: parts.append("two-handed")
    else:
        if it["ac"]: parts.append("AC +%d" % it["ac"])
    for k, nm in (("s", "STR"), ("d", "DEX"), ("c", "CON"), ("i", "INT")):
        if it.get(k): parts.append("%s +%d" % (nm, it[k]))
    if it.get("mana"): parts.append("max mana +%d" % it["mana"])
    if it.get("eff"): parts.append({"burn": "burns", "slow": "slows", "poison": "poisons", "prone": "can knock down",
                                    "blind": "can blind", "fright": "can frighten", "hold": "can hold"}[it["eff"]])
    sp = it.get("sp", "")
    if sp: parts.append(SPECIALS[sp][1].format(v=it.get("spv", 0)))
    return ", ".join(parts)

def who(it):
    if it["kind"] == "W":
        c = it["classes"]
    else:
        c = ALL if it["weight"] in (ANYWEAR, CLOTH) else {LIGHT: F | R, MEDIUM: F, HEAVY: F}[it["weight"]]
        if it["slot"] == SHIELD: c = F
    names = [n for b, n in ((F, "Fighter"), (R, "Rogue"), (W, "Wizard")) if c & b]
    return "Any class" if len(names) == 3 else " / ".join(names)

def write():
    rec = ["; items_rec.inc - generated by items.py (special weapon and armor records)"]
    cat = ["; items_cat.inc - generated by items.py (catalog entries of the special items)",
           ";          label, name, record, kind, weight, rarity, floor, STR, DEX, CON, INT, AC, mana, special, value"]
    for it in ITEMS:
        lab = "it_" + it["id"]
        if it["kind"] == "W":
            rec.append("%s db 0b%s, 0b%s, %d, %d, 0b%s, %d, %d, %d" % (
                lab, "01" if it["ranged"] else "10", format(it["classes"], "03b"), it["lo"], it["hi"],
                format(it["scale"], "04b"), it["rng"], EFF[it["eff"]], 1 if it["two"] else 0))
            kind = "ITEM_WEAPON"
        else:
            rec.append("%s db 0b%s, 0b%s, %d, %d, %d, 0, 0, 0, 0" % (
                lab, format(it["slot"], "06b"), format(it["weight"], "04b"), it["ac"], it["dexmax"], it["mv"]))
            kind = "ITEM_ARMOR"
        sp = SPECIALS[it.get("sp", "")][0]
        cat.append("    catalogx cat_%s, \"%s\", %s, %s, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d" % (
            it["id"], it["name"], lab, kind, it.get("w", 0), it["rarity"], it.get("floor", 0),
            it.get("s", 0), it.get("d", 0), it.get("c", 0), it.get("i", 0), it.get("ac2", 0), it.get("mana", 0), sp, it.get("spv", 0)))
    loot = ["; items_loot.inc - generated by items.py: the legendary each boss drops, for Fighter, Rogue, Wizard",
            "bossLoot:"]
    names = ["Warden (4)", "Warden (8)", "Dark Shade", "Ymir", "Logic Keeper", "Altair", "Smo"]
    for slot in range(BOSS_SLOTS):
        row = [next(it for it in ITEMS if it.get("boss") == (slot, cls)) for cls in (F, R, W)]
        loot.append("    dd %s   ; %s" % (", ".join("cat_" + it["id"] for it in row), names[slot]))
    gui = ["/* gui_items.h - generated by items.py: what the window knows about each special item */",
           "typedef struct { const char *name; int rarity; const char *icon; const char *who; const char *stats; const char *desc; } ItemInfo;",
           "static const ItemInfo ITEM_INFO[] = {"]
    for it in ITEMS:
        gui.append('    { "%s", %d, "%s", "%s", "%s", "%s" },' % (it["name"], it["rarity"], it["icon"], who(it), stat_text(it), it["desc"]))
    gui.append("};")
    gui.append("#define ITEM_INFO_N (int)(sizeof ITEM_INFO / sizeof ITEM_INFO[0])")
    open("items_rec.inc", "w").write("\n".join(rec) + "\n")
    open("items_cat.inc", "w").write("\n".join(cat) + "\n")
    open("items_loot.inc", "w").write("\n".join(loot) + "\n")
    open("gui_items.h", "w").write("\n".join(gui) + "\n")
    print("wrote items_rec.inc, items_cat.inc, items_loot.inc, gui_items.h")

if __name__ == "__main__":
    check()
    write()
