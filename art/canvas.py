import math
from PIL import Image
from pal import PAL
class C:
    def __init__(s,w=32,h=32): s.w,s.h=w,h; s.g=[['.']*w for _ in range(h)]
    def px(s,x,y,c):
        x,y=int(round(x)),int(round(y))
        if 0<=x<s.w and 0<=y<s.h: s.g[y][x]=c
    def rect(s,x0,y0,x1,y1,c):
        for y in range(y0,y1+1):
            for x in range(x0,x1+1): s.px(x,y,c)
    def ell(s,cx,cy,rx,ry,c):
        for y in range(s.h):
            for x in range(s.w):
                if ((x-cx)/rx)**2+((y-cy)/ry)**2<=1.0: s.px(x,y,c)
    def poly(s,pts,c):
        for y in range(s.h):
            for x in range(s.w):
                X,Y=x+0.5,y+0.5; ins=False; n=len(pts)
                for i in range(n):
                    (x1,y1),(x2,y2)=pts[i],pts[(i+1)%n]
                    if (y1>Y)!=(y2>Y) and X < (x2-x1)*(Y-y1)/(y2-y1)+x1: ins=not ins
                if ins: s.px(x,y,c)
    def line(s,x0,y0,x1,y1,c,w=1):
        n=int(max(abs(x1-x0),abs(y1-y0))*2)+1
        for i in range(n+1):
            t=i/n; x=x0+(x1-x0)*t; y=y0+(y1-y0)*t
            for dx in range(w):
                for dy in range(w): s.px(x+dx-(w-1)/2,y+dy-(w-1)/2,c)
    def get(s,x,y): return s.g[y][x] if 0<=x<s.w and 0<=y<s.h else '.'
    def outline(s,c='k'):
        add=[]
        for y in range(s.h):
            for x in range(s.w):
                if s.g[y][x]=='.' and any(s.get(x+dx,y+dy) not in '.k' for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))): add.append((x,y))
        for x,y in add: s.g[y][x]=c
    def rows(s): return [''.join(r) for r in s.g]
def render(sprites, path, sc=8, bg=(34,36,46)):
    W=sum(len(r[0])*sc+24 for r in sprites)+24; H=max(len(r) for r in sprites)*sc+48
    im=Image.new('RGB',(W,H),bg); x0=24
    for rows in sprites:
        for y,row in enumerate(rows):
            for x,ch in enumerate(row):
                if ch=='.': continue
                for yy in range(sc):
                    for xx in range(sc): im.putpixel((x0+x*sc+xx,24+y*sc+yy),PAL[ch])
        x0+=len(rows[0])*sc+24
    im.save(path)
