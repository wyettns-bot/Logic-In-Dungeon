import re
from canvas import C, render
def mk(f):
    c = C(16, 16); f(c); c.outline(); return c.rows()

# ---------------- Fighter options ----------------
def knight(c):                       # A: Knight - full helm, red plume, blue tabard, kite shield, raised sword
    c.rect(7, 0, 8, 0, 'r'); c.px(9, 1, 'R')
    c.rect(5, 1, 10, 6, 'm'); c.rect(9, 1, 10, 6, 'M'); c.rect(6, 3, 9, 3, 'k'); c.px(7, 5, 'M'); c.px(8, 5, 'M')
    c.rect(4, 7, 11, 7, 'M'); c.rect(5, 8, 10, 11, 'm'); c.rect(6, 8, 9, 12, 'b'); c.rect(7, 9, 8, 11, 'y'); c.rect(6, 10, 9, 10, 'y')
    c.rect(5, 12, 6, 14, 'M'); c.rect(9, 12, 10, 14, 'M'); c.rect(5, 14, 6, 14, 'N'); c.rect(9, 14, 10, 14, 'N')
    c.rect(1, 7, 4, 10, 'r'); c.rect(2, 11, 3, 12, 'r'); c.rect(1, 7, 1, 10, 'R'); c.line(2.5, 8, 2.5, 11, 'y'); c.rect(1, 9, 4, 9, 'y')
    c.line(13, 1, 13, 8, 'm'); c.px(13, 0, 'w'); c.rect(12, 9, 14, 9, 'y'); c.px(13, 10, 'n'); c.px(12, 10, 's')

def warrior(c):                      # B: Warrior - bronze helm, red beard, chainmail, round shield, axe on the shoulder
    c.rect(5, 1, 10, 4, 'u'); c.rect(9, 1, 10, 4, 'U'); c.rect(7, 4, 8, 5, 'U')
    c.rect(5, 5, 10, 6, 's'); c.px(6, 5, 'k'); c.px(9, 5, 'k'); c.rect(5, 6, 10, 8, 'O'); c.rect(6, 8, 9, 8, 'O')
    c.rect(4, 7, 11, 11, 'M'); c.rect(5, 8, 10, 11, 'e')
    for y in (8, 10):
        for x in (5, 7, 9): c.px(x, y, 'M')
    c.rect(4, 11, 11, 11, 'N'); c.px(7, 11, 'y')
    c.rect(5, 12, 6, 14, 'l'); c.rect(9, 12, 10, 14, 'l'); c.rect(5, 14, 6, 14, 'N'); c.rect(9, 14, 10, 14, 'N')
    c.ell(2.5, 9.5, 2.6, 3.0, 'N'); c.ell(2.5, 9.5, 1.8, 2.2, 'l'); c.rect(2, 9, 3, 10, 'M'); c.px(2, 9, 'm')
    c.line(13, 13, 12, 3, 'n'); c.rect(13, 1, 15, 4, 'm'); c.rect(15, 1, 15, 4, 'M'); c.px(12, 9, 's')

def paladin(c):                      # C: Paladin - open helm with a gold band, white and gold plate, blue cape, greatsword planted
    c.rect(2, 7, 13, 14, 'B'); c.rect(2, 7, 3, 14, 'b')
    c.rect(5, 1, 10, 3, 'm'); c.rect(5, 2, 10, 2, 'y'); c.px(7, 0, 'y'); c.px(8, 0, 'y')
    c.rect(5, 4, 10, 6, 's'); c.rect(9, 4, 10, 6, 'S'); c.px(6, 5, 'k'); c.px(9, 5, 'k'); c.rect(5, 3, 5, 6, 'm'); c.rect(10, 3, 10, 6, 'm')
    c.rect(4, 7, 11, 7, 'y'); c.rect(4, 8, 11, 11, 'w'); c.rect(9, 8, 11, 11, 'W'); c.rect(7, 8, 8, 11, 'y')
    c.rect(5, 12, 6, 14, 'm'); c.rect(9, 12, 10, 14, 'm'); c.rect(5, 14, 6, 14, 'Y'); c.rect(9, 14, 10, 14, 'Y')
    c.line(7.5, 6, 7.5, 15, 'm'); c.rect(5, 10, 10, 10, 'y'); c.rect(6, 11, 9, 11, 's')

# ---------------- Rogue options ----------------
def assassin(c):                     # A: Assassin - deep hood, glowing eyes, red scarf, dark teal cloak, two daggers
    c.poly([(7.5, 0), (12, 4), (12, 8), (3, 8), (3, 4)], 'h'); c.poly([(7.5, 0), (12, 4), (12, 8), (9, 8), (9, 3)], 'E')
    c.rect(5, 4, 10, 6, 'k'); c.px(6, 5, 'g'); c.px(9, 5, 'g')
    c.rect(4, 7, 11, 8, 'r'); c.px(11, 9, 'R'); c.px(12, 10, 'R')
    c.poly([(4, 8), (11, 8), (13, 15), (2, 15)], 'T'); c.poly([(8, 8), (11, 8), (13, 15), (9, 15)], 'h')
    c.line(6, 9, 9, 12, 'N'); c.rect(5, 11, 10, 11, 'N'); c.px(7, 11, 'm')
    c.px(2, 10, 's'); c.line(1, 9, 0, 7, 'm'); c.px(13, 10, 's'); c.line(14, 9, 15, 7, 'm')

def duelist(c):                      # B: Duelist - wide feathered hat, black mask, red half-cape, rapier
    c.rect(3, 3, 12, 3, 'N'); c.rect(5, 1, 10, 2, 'N'); c.rect(5, 2, 10, 2, 'r'); c.line(10, 1, 13, 0, 'R')
    c.rect(5, 4, 10, 6, 's'); c.rect(5, 5, 10, 5, 'k'); c.px(6, 5, 'w'); c.px(9, 5, 'w'); c.rect(9, 4, 10, 6, 'S')
    c.rect(4, 7, 6, 12, 'r'); c.rect(4, 7, 4, 12, 'R')
    c.rect(6, 7, 10, 11, 'l'); c.rect(7, 7, 8, 11, 'W'); c.rect(6, 11, 10, 11, 'N'); c.px(8, 11, 'y')
    c.rect(6, 12, 7, 14, 'N'); c.rect(9, 12, 10, 14, 'N'); c.rect(6, 14, 7, 14, 'k'); c.rect(9, 14, 10, 14, 'k')
    c.px(11, 9, 's'); c.line(12, 9, 15, 6, 'm'); c.px(12, 10, 'y'); c.px(11, 8, 'y')

def thief(c):                        # C: Thief - red bandana, masked mouth, green leathers, coin pouch, reversed dagger
    c.rect(5, 1, 10, 3, 'r'); c.rect(9, 1, 10, 3, 'R'); c.px(11, 2, 'r'); c.px(12, 3, 'r')
    c.rect(5, 4, 10, 6, 's'); c.px(6, 4, 'k'); c.px(9, 4, 'k'); c.rect(5, 5, 10, 6, 'E')
    c.rect(4, 7, 11, 11, 'G'); c.rect(5, 8, 10, 11, 'g'); c.rect(4, 10, 11, 10, 'N'); c.px(7, 10, 'y')
    c.ell(11.5, 11.5, 1.6, 1.6, 'l'); c.px(11, 11, 'y')
    c.rect(5, 12, 6, 14, 'G'); c.rect(9, 12, 10, 14, 'G'); c.rect(4, 14, 6, 14, 'N'); c.rect(9, 14, 11, 14, 'N')
    c.px(3, 9, 's'); c.line(3, 10, 2, 13, 'm'); c.px(3, 8, 'n')

def cur(name):
    src = open('../sprites.h').read()
    m = re.search(r'SPR_%s\[16\] = \{(.*?)\};' % name, src, re.S)
    return re.findall(r'"([^"]*)"', m.group(1))

FIGHTERS = [("knight", knight), ("warrior", warrior), ("paladin", paladin)]
ROGUES = [("assassin", assassin), ("duelist", duelist), ("thief", thief)]
if __name__ == "__main__":
    wiz = cur("WIZARD")
    render([mk(f) for _, f in FIGHTERS] + [wiz], 'fighters.png', sc=10)
    render([mk(f) for _, f in ROGUES] + [wiz], 'rogues.png', sc=10)
