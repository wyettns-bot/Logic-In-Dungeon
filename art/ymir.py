from canvas import C
def ymir():
    c=C()
    c.line(5,8,5,31,'n'); c.line(6,9,6,31,'N')                      # staff
    c.poly([(13,13),(20,13),(28,31),(6,31)],'b')                     # robe
    c.poly([(17,13),(20,13),(28,31),(18,31)],'B')
    c.rect(8,28,26,29,'X')                                           # rune hem
    for x in range(9,27,3): c.px(x,28,'c')
    c.rect(11,21,23,21,'y')                                          # belt
    c.poly([(12,14),(15,16),(8,20),(6,18)],'b')                      # arm to the staff
    c.poly([(20,14),(18,17),(25,12),(27,10),(26,9)],'B')             # raised arm
    c.rect(4,17,7,19,'I'); c.px(4,17,'i')                            # hand on staff
    c.rect(25,8,27,10,'I'); c.px(25,8,'i')                           # casting hand
    c.poly([(12,13),(21,13),(22,17),(19,24),(16,28),(13,24),(11,17)],'w')   # beard
    c.poly([(17,13),(21,13),(22,17),(19,24),(16,28)],'W')
    for (x,y) in ((13,17),(14,20),(15,23),(18,18),(19,21)): c.px(x,y,'i')
    c.rect(13,11,20,13,'I'); c.rect(13,11,20,12,'X')                 # face in the brim's shadow
    c.rect(14,12,15,12,'c'); c.rect(18,12,19,12,'c'); c.px(16,13,'i'); c.px(17,13,'i')
    c.rect(13,14,20,14,'W'); c.px(16,14,'w')                         # moustache
    c.poly([(10,10),(23,10),(20,4),(23,0),(17,2)],'B')               # hat
    c.poly([(10,10),(15,10),(17,3),(18,2)],'b')
    c.rect(9,9,24,10,'X'); c.rect(9,9,24,9,'i')                      # brim with frost
    c.px(16,6,'c'); c.px(19,5,'c'); c.px(14,8,'c')
    c.poly([(5,0),(8.5,4),(5,8),(1.5,4)],'I')                        # ice crystal
    c.poly([(5,1),(7,4),(5,6.5),(3,4)],'i'); c.px(5,3,'w'); c.px(4,3,'w')
    c.ell(27.5,5,2.6,2.6,'c'); c.ell(27.5,5,1.4,1.4,'i'); c.px(27,4,'w')   # frost orb
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; render([ymir()],'ymir.png')
