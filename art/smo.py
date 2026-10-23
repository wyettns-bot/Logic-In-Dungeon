from canvas import C
def smo():
    c=C()
    c.rect(9,25,14,29,'H'); c.rect(18,25,23,29,'H')                 # thick legs
    c.rect(8,29,14,31,'h'); c.rect(18,29,24,31,'h')                 # iron boots
    c.ell(16,18,10.5,8,'H'); c.ell(19,19.5,7.5,6.5,'h')               # iron body
    c.ell(13,15,3,2,'e')                                            # shine
    for (x,y) in ((9,17),(12,22),(16,23),(20,22),(23,17)): c.px(x,y,'m')   # rivets
    c.line(9,14,23,14,'U'); c.line(8,15,9,14,'U'); c.line(23,14,24,15,'U')  # bronze collar trim
    for x in range(7,26): c.px(x,25,'M' if x%2 else 'm')            # chain belt
    c.px(16,26,'m'); c.px(16,27,'M')
    c.line(25,13,28,3,'N',w=2)                                      # maul haft resting on the shoulder
    c.ell(6,12,4.6,4,'u'); c.ell(7,13,3,2.5,'U')                    # huge pauldrons
    c.ell(26,12,4.6,4,'u'); c.ell(27,13,3,2.5,'U')
    c.px(3,9,'W'); c.px(4,8,'W'); c.px(28,8,'W') if False else None
    c.rect(3,15,7,22,'H'); c.rect(3,15,4,22,'e')                    # left arm hanging
    c.rect(2,22,7,26,'U'); c.rect(2,22,3,26,'u')                    # big bronze fist
    c.rect(12,6,20,13,'U'); c.ell(16,6.5,4.2,2.6,'U'); c.rect(12,6,13,13,'u')   # bucket helm
    c.rect(13,9,19,10,'k'); c.px(14,9,'r'); c.px(15,9,'o'); c.px(17,9,'o'); c.px(18,9,'r')   # eye slit
    for y in (11,12): c.px(15,y,'N'); c.px(17,y,'N')                # breathing slots
    c.line(12,6,9,2,'W'); c.line(9,2,9,1,'w'); c.line(20,6,23,2,'W'); c.line(23,2,23,1,'w')   # horns
    c.rect(24,14,28,17,'U'); c.px(24,14,'u')                        # fist on the haft
    c.poly([(21,4),(26,-1),(32,3.5),(27,9)],'q')                    # big stone maul head
    c.poly([(26.5,-0.5),(32,3.5),(29.5,7),(27,3)],'Q')
    c.line(23,2,29,8,'M'); c.line(25.5,0,31,5.5,'M')                # iron bands
    c.px(23,5,'Q'); c.px(25,7,'Q')
    c.outline()
    return c.rows()
if __name__=='__main__':
    from canvas import render; from altair import altair; from ymir import ymir; from keeper import keeper
    render([ymir(),keeper(),altair(),smo()],'all.png',sc=7)
