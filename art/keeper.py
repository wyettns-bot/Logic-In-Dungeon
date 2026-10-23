from canvas import C
def keeper():
    c=C()
    c.rect(11,24,14,30,'Q'); c.rect(17,24,20,30,'Q')                 # legs
    c.rect(10,29,14,31,'U'); c.rect(17,29,21,31,'U')                 # bronze boots
    c.poly([(9,19),(22,19),(24,27),(7,27)],'q')                      # stone tassets
    c.poly([(16,19),(22,19),(24,27),(16,27)],'Q')
    for x in range(9,24,2): c.px(x,24,'t')                           # rune line
    c.rect(9,10,22,19,'q'); c.rect(17,10,22,19,'Q')                  # stone breastplate
    c.line(15.5,12,15.5,18,'T'); c.line(11,15,20,15,'T'); c.px(15,15,'t'); c.px(16,15,'t')
    c.rect(9,19,22,20,'U'); c.rect(14,19,17,20,'u')                  # belt
    c.rect(5,12,8,20,'Q'); c.rect(5,12,6,20,'q')                     # the arm with no hand ...
    c.ell(6.5,21,2.2,1.6,'U'); c.px(6,21,'u')                        # ... capped in bronze
    for i,y in enumerate(range(23,29)): c.px(6+(i%2),y,'m' if i%2 else 'M')   # a hanging chain
    c.ell(8,11,3.5,2.5,'u'); c.ell(8.5,11.5,2.5,1.5,'U')             # pauldrons
    c.ell(23,11,3.5,2.5,'u'); c.ell(23.5,11.5,2.5,1.5,'U')
    c.ell(15.5,6,4.6,4.6,'u'); c.rect(11,6,20,9,'u')                 # helm
    c.ell(17,5,2.8,3.2,'U')
    c.rect(13,6,18,8,'h'); c.rect(15,4,16,6,'U')                     # face opening and nasal
    c.px(14,7,'t'); c.px(17,7,'t')                                   # eyes
    c.rect(15,0,16,2,'r'); c.px(16,0,'R'); c.px(16,1,'R')            # crest
    c.poly([(12,9),(20,9),(19,13),(16.5,16),(15,16),(12.5,13)],'O')  # braided auburn beard
    c.line(14,10,15,15,'R'); c.line(17,10,16.5,15,'R'); c.px(13,10,'o'); c.px(18,10,'o'); c.px(15,16,'y'); c.px(16,16,'y')
    c.ell(24.5,18,7,8.6,'U'); c.ell(24.5,18,5.8,7.4,'q')             # the round shield ...
    # ... with an AND gate carved in it, glowing
    c.line(22,14,22,22,'t'); c.line(22,14,24,14,'t'); c.line(22,22,24,22,'t')
    import math
    for a in range(-90,91,6):
        r=math.radians(a); c.px(24+4*math.cos(r),18+4*math.sin(r),'t')
    c.line(19,16,21,16,'T'); c.line(19,20,21,20,'T'); c.line(28,18,29,18,'T')
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; from ymir import ymir; render([ymir(),keeper()],'k.png')
