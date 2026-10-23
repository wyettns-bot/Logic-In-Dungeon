from canvas import C
def bishop2():
    c=C()
    # tall tattered robe, deep crimson over black, hunched and gaunt
    c.poly([(11,9),(21,9),(24,26),(26,31),(6,31),(8,26)],'R')
    c.poly([(16,9),(21,9),(24,26),(26,31),(16,31)],'k')                 # the shadow side is black
    c.poly([(13,12),(19,12),(20,31),(12,31)],'h')                       # dark under-robe
    for x in (7,10,13,17,20,24): c.line(x,29,x+1,31,'.')                # torn hem
    c.line(12,12,12,30,'Y'); c.line(20,12,20,30,'U')                    # frayed gold trim
    c.rect(13,20,19,20,'U')
    # hunched shoulders and a hood with no face
    c.poly([(9,11),(23,11),(21,8),(11,8)],'R'); c.poly([(16,8),(21,8),(23,11),(16,11)],'k')
    c.ell(16,8.5,3.6,3,'h'); c.ell(16,9,2.4,2,'k')
    c.px(15,9,'w'); c.px(17,9,'w')                                      # pinpoint eyes
    # tall cracked mitre
    c.poly([(12.5,6.5),(19.5,6.5),(18.5,1.5),(16,0),(13.5,1.5)],'q')
    c.poly([(16,0),(18.5,1.5),(19.5,6.5),(16,6.5)],'Q')
    c.rect(12,6,20,7,'U'); c.line(15,1,17,4,'k')                        # band, crack
    # long bony hands: a spiked iron crozier, an iron censer on a chain
    c.line(26,31,27,2,'M',1)
    c.poly([(25.5,4),(28.5,4),(29.5,1),(27,-1),(24.5,1)],'m')           # the crook, spiked
    c.px(30,2,'m'); c.px(24,2,'m'); c.px(27,6,'m')
    c.line(22,12,26,14,'R'); c.ell(26,14,1.4,1.2,'W')                   # arm and hand on the staff
    c.line(10,12,6,17,'R'); c.ell(6,17,1.3,1.2,'W')                     # the other arm
    c.line(6,18,5,24,'e')                                               # chain
    c.ell(5,25.5,2,1.8,'e'); c.rect(4,24,6,24,'Y'); c.px(5,26,'o')      # censer with an ember
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render
    from bishop import bishop
    render([bishop(), bishop2()],'b2.png',sc=6)
