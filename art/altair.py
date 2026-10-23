from canvas import C
def altair():
    c=C()
    c.poly([(11,10),(15,10),(14,27),(6,30),(8,19)],'B')              # cape
    c.poly([(11,10),(12,10),(9,22),(6,30),(8,19)],'X')
    c.rect(13,22,14,29,'M'); c.rect(17,22,18,29,'M')                 # legs
    c.rect(12,29,14,31,'h'); c.rect(17,29,19,31,'h')                 # boots
    c.poly([(12,10),(20,10),(19.5,23),(12.5,23)],'m')                # silver cuirass
    c.poly([(17,10),(20,10),(19.5,23),(17,23)],'M')
    c.rect(14,12,18,25,'b'); c.rect(17,12,18,25,'B')                 # blue tabard
    for (x,y) in ((16,14),(15,15),(16,16),(17,16),(16,17),(15,18)): c.px(x,y,'y')   # bolt emblem
    c.rect(13,20,19,20,'N')                                          # belt
    c.ell(12,11,2.6,2,'m'); c.ell(20.5,11,2.6,2,'M')                 # pauldrons
    c.px(11,12,'c'); c.px(21,12,'c')
    c.ell(16,6,4,4,'m'); c.rect(12,6,20,9,'m'); c.rect(17,3,19,9,'M')   # helm
    c.rect(14,6,18,6,'c'); c.rect(16,7,16,8,'c')                     # T-shaped visor, glowing
    c.poly([(13,3),(18,2.5),(16,0.5),(11,0.5),(7,3),(5,7),(9,5),(12,4)],'x')   # swept-back crest
    c.poly([(11,0.5),(7,3),(5,7),(8,4),(11,2)],'X')
    c.line(3,30,26,5,'n')                                            # spear shaft (in front)
    c.poly([(24.5,6.5),(27.5,1.5),(31,0),(30,3.5),(25.5,8.5)],'c')   # lightning spearhead
    c.line(26.5,5.5,29.5,1.5,'w')
    c.rect(11,19,12,21,'M'); c.rect(18,12,19,14,'M')                 # gauntlets on the shaft
    c.px(23,1,'y'); c.px(31,6,'y'); c.px(29,7,'y')                   # sparks
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; render([altair()],'a.png',sc=6)
