from canvas import C
def unbound():
    c=C(48,48)
    c.poly([(13,13),(35,13),(46,47),(2,47)],'R')                     # torn cape
    c.poly([(13,13),(20,13),(10,47),(2,47)],'r')
    for x in (5,11,37,43): c.poly([(x,47),(x+2,42),(x+4,47)],'.')    # tattered hem
    c.rect(17,35,21,45,'h'); c.rect(27,35,31,45,'h')                 # legs
    c.rect(16,44,22,47,'E'); c.rect(26,44,32,47,'E')
    c.poly([(14,14),(34,14),(32,36),(16,36)],'h')                    # dark armour
    c.poly([(26,14),(34,14),(32,36),(26,36)],'E')
    c.line(14,14,34,14,'Y'); c.line(16,36,32,36,'Y')
    for (a,b) in (((18,18),(18,24)),((18,24),(22,24)),((22,24),(22,30)),((30,17),(30,22)),((30,22),(26,22)),((26,22),(26,33)),((20,30),(20,34))):
        c.line(a[0],a[1],b[0],b[1],'y')                              # glowing circuit traces
    for (x,y) in ((18,18),(22,30),(30,17),(26,33),(20,34)): c.px(x,y,'w')
    c.ell(12,15,4.5,3.5,'Y'); c.ell(36,15,4.5,3.5,'Y'); c.ell(12,14,3,2,'y'); c.ell(36,14,3,2,'y')   # pauldrons
    c.line(11,17,6,29,'h',w=3); c.line(37,17,42,27,'h',w=3)          # arms
    c.rect(4,28,8,31,'Y'); c.rect(40,26,44,29,'Y')                   # gauntlets
    c.rect(5,31,7,46,'m'); c.rect(7,31,7,46,'M'); c.px(6,47,'m')     # great sword, point down
    c.rect(2,30,10,30,'y'); c.rect(5,27,7,27,'y')                    # its hilt
    c.ell(42.5,23,3,3,'o'); c.ell(42.5,23,1.6,1.6,'y'); c.px(42,22,'w')   # gold fire in the other hand
    c.poly([(19,11),(29,11),(28,19),(24,24),(20,19)],'m')            # long silver beard
    c.line(22,13,23,21,'M'); c.line(26,13,25,21,'M')
    c.rect(20,5,28,11,'W'); c.rect(27,5,28,11,'S')                   # ashen face
    c.rect(21,8,22,8,'o'); c.rect(26,8,27,8,'o')                     # burning eyes
    c.px(24,10,'S')
    c.rect(19,3,29,5,'y'); c.rect(19,5,29,5,'Y')                     # the broken crown
    c.poly([(19,3),(20,0),(21,3)],'y'); c.poly([(23,3),(24,-0.5),(25,3)],'y'); c.poly([(28,3),(30,1),(29,3)],'y')
    c.px(22,4,'r'); c.px(26,4,'r'); c.px(27,3,'k'); c.px(27,4,'k')   # gems, a crack
    c.outline()
    return c.rows()
def throne():
    c=C(48,32)
    c.rect(10,2,37,22,'Q'); c.rect(12,4,35,20,'q')                   # tall stone back
    c.poly([(10,2),(14,-1),(18,2)],'Q'); c.poly([(21,2),(24,-2),(27,2)],'Q'); c.poly([(30,2),(34,-1),(38,2)],'Q')   # spires
    c.rect(15,6,32,20,'R'); c.rect(15,6,32,7,'r')                    # red back cushion
    c.rect(10,2,37,2,'y'); c.rect(10,22,37,22,'y'); c.line(10,2,10,22,'Y'); c.line(37,2,37,22,'Y')   # gold trim
    c.rect(4,16,12,28,'Q'); c.rect(35,16,43,28,'Q')                  # armrests
    c.rect(4,16,12,17,'y'); c.rect(35,16,43,17,'y')
    c.rect(8,22,39,28,'q'); c.rect(8,22,39,23,'R')                   # seat
    c.rect(2,28,45,31,'Q'); c.rect(2,28,45,28,'y')                   # step
    c.px(24,3,'o'); c.px(14,1,'y'); c.px(34,1,'y')
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; render([unbound(), throne()],'unbound.png',sc=7)
