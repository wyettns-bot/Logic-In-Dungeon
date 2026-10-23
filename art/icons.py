from canvas import C, render
def mk(f):
    c=C(16,16); f(c); c.outline(); return c.rows()
def staff(c):
    c.line(4,15,11,4,'n'); c.line(5,15,12,4,'N'); c.ell(12.5,3,2.2,2.2,'c'); c.px(12,2,'w')
def dagger(c):
    c.line(5,10,11,4,'m',w=2); c.line(11,4,12,3,'w'); c.line(3,9,7,13,'Y'); c.line(4,12,2,14,'n',w=2)
def bow(c):
    for y in range(2,15): x=4+int(4*(1-((y-8.5)/6.5)**2)); c.px(x,y,'n'); c.px(x+1,y,'N')
    c.line(4,2,4,14,'w'); c.line(4,8,12,8,'m'); c.px(13,8,'w'); c.px(12,7,'m'); c.px(12,9,'m')
def maul(c):
    c.line(4,14,9,7,'n',w=2); c.poly([(6,3),(11,1),(14,6),(9,8)],'q'); c.poly([(10,1.5),(14,6),(12,7),(10,4)],'Q')
def halberd(c):
    c.line(3,15,12,3,'n'); c.poly([(10,2),(14,3),(13,7),(11,6)],'m'); c.px(12,1,'m'); c.px(13,0,'w')
def spear(c):
    c.line(2,15,11,5,'n'); c.poly([(10,6),(13,1),(15,0),(14,3),(11,7)],'c'); c.px(13,2,'w')
def greatsword(c):
    c.line(4,12,13,2,'m',w=2); c.line(12,2,14,1,'w'); c.line(2,9,7,14,'Y'); c.line(3,13,1,15,'N',w=2)
def shield(c):
    c.poly([(3,2),(13,2),(13,8),(8,14),(3,8)],'B'); c.poly([(4,3),(12,3),(12,8),(8,12.5),(4,8)],'b'); c.line(8,3,8,12,'y'); c.line(4,6,12,6,'y')
def robe(c):
    c.poly([(5,2),(11,2),(14,15),(2,15)],'p'); c.poly([(8,2),(11,2),(14,15),(9,15)],'P'); c.line(8,3,8,14,'y'); c.ell(8,2,2,1.2,'P')
def helm(c):
    c.ell(8,8,5,5,'M'); c.rect(3,8,13,12,'M'); c.ell(7,6,3,3,'m'); c.rect(5,9,11,10,'k'); c.line(3,6,1,2,'W'); c.line(13,6,15,2,'W')
def hood(c):
    c.poly([(8,1),(14,10),(13,15),(3,15),(2,10)],'E'); c.poly([(8,1),(14,10),(13,15),(9,15),(10,8)],'h'); c.ell(8,10,3,3.5,'k'); c.px(7,10,'c'); c.px(9,10,'c')
def boots(c):
    c.rect(3,3,7,12,'n'); c.rect(3,11,9,14,'n'); c.rect(9,4,12,12,'N'); c.rect(9,11,14,14,'N'); c.line(3,3,7,3,'Y'); c.line(9,4,12,4,'Y')
def ring(c):
    for a in range(0,360,12):
        import math; r=math.radians(a); c.px(8+4.5*math.cos(r),9+4.5*math.sin(r),'y')
    c.ell(8,4,2.2,2,'c'); c.px(8,3,'w')
def amulet(c):
    c.line(3,1,8,8,'Y'); c.line(13,1,8,8,'Y'); c.poly([(8,7),(12,11),(8,15),(4,11)],'r'); c.poly([(8,8),(10.5,11),(8,13.5),(5.5,11)],'R'); c.px(7,10,'w')
ICONS=[("STAFF",staff),("DAGGER",dagger),("BOW",bow),("MAUL",maul),("HALBERD",halberd),("SPEAR",spear),("GREATSWORD",greatsword),
       ("SHIELD",shield),("ROBE",robe),("HELM",helm),("HOOD",hood),("BOOTS",boots),("RING",ring),("AMULET",amulet)]
if __name__=='__main__':
    rows=[mk(f) for _,f in ICONS]
    render(rows,'icons.png',sc=6)
    out=["","/* v9: item icons (16x16), drawn by art/icons.py */"]
    for (n,f),r in zip(ICONS,rows):
        out.append("static const char *SPR_I_%s[16] = {"%n); out+=['"%s",'%x for x in r]; out.append("};")
    open('icons.h','w').write("\n".join(out)+"\n")
