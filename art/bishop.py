from canvas import C
def bishop():
    c=C()
    c.poly([(9,14),(23,14),(26,31),(6,31)],'W')                       # robe
    c.poly([(16,14),(23,14),(26,31),(17,31)],'q')                      # robe shade
    c.rect(14,14,18,31,'r'); c.rect(17,14,18,31,'R')                   # red stole down the front
    for y in (18,24,30): c.rect(14,y,18,y,'y')                         # gold bands on the stole
    c.rect(15,20,17,20,'y'); c.rect(16,19,16,22,'y')                   # cross on the stole
    c.rect(6,30,26,31,'Y')                                             # gold hem
    c.poly([(9,14),(12,14),(7,24),(5,22)],'W'); c.poly([(20,14),(23,14),(27,22),(25,24)],'q')   # sleeves
    c.ell(6,24,2,2,'s'); c.ell(26,23,2,2,'S')                          # hands
    c.ell(16,11,4,3.5,'s'); c.rect(13,11,19,13,'s'); c.rect(17,10,19,13,'S')   # face
    c.px(14,11,'k'); c.px(18,11,'k')                                   # eyes
    c.rect(13,13,19,14,'W')                                            # beard / collar
    c.poly([(11,9),(21,9),(19,0.5),(16,-1),(13,0.5)],'w')              # mitre
    c.poly([(16,-1),(19,0.5),(21,9),(16,9)],'W')
    c.rect(11,8,21,9,'y'); c.rect(15,1,17,8,'y'); c.rect(13,4,19,5,'y')   # gold trim and cross
    c.line(28,31,28,5,'n',1)                                           # crozier staff
    c.line(28,5,28,3,'y'); c.line(28,3,30,1,'y'); c.line(30,1,31,3,'y'); c.line(31,3,30,5,'y')   # its crook
    c.ell(28,8,1.4,1.4,'c')                                            # holy glow on the staff
    c.line(4,25,4,30,'Y')                                              # censer chain
    c.ell(4,30,1.6,1.4,'y')
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; render([bishop()],'b.png',sc=6)
