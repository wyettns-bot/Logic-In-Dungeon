import pty, os, time, select, pyte, sys, re
screen = pyte.Screen(80, 30); stream = pyte.ByteStream(screen)
pid, fd = pty.fork()
if pid == 0:
    g=os.environ.get("GAME","./game"); os.execv(g,[g])
ESC="\x1b"
def pump(t=0.3):
    end=time.time()+t
    while time.time()<end:
        r,_,_=select.select([fd],[],[],0.02)
        if r:
            try: stream.feed(os.read(fd,4096))
            except OSError: return
def send(s,t=0.15): os.write(fd,s.encode()); pump(t)
def row(r): return screen.display[r-1]
def ents():
    E={};P=None
    for r in range(7,20):
        line=row(r)
        for c,ch in enumerate(line[:53]):
            if ch in 'GSODKMBYJjTtUuFHdZ' and c>0 and c<52: E.setdefault(ch,[]).append((c+1,r))
            if ch=='@': P=(c+1,r)
    return P,E
def enemy_cells():
    P,E=ents(); out=[]
    for ch,l in E.items(): out+=l
    return P,sorted(out)
def mode(): return row(23).strip()
def msg(): return row(24).strip()
def mana(): return row(21).strip()
def click(x,y,t=0.2): send(f"{ESC}[<0;{x};{y}M{ESC}[<0;{x};{y}m",t)
def rclick(x,y,t=0.2): send(f"{ESC}[<2;{x};{y}M{ESC}[<2;{x};{y}m",t)
def hover(x,y,t=0.2): send(f"{ESC}[<35;{x};{y}M",t)
def show(a=1,b=24):
    for i in range(a,b+1):
        l=row(i).rstrip()
        if l: print(f"{i:2}|{l}")
def start(cls="3"):
    pump(0.5); send("\n"); send(cls+"\n"); send("y\n")
    for k in "444": send(k+"\n",0.2)
    pump(0.6)

def cheb(a,b): return max(abs(a[0]-b[0]),abs(a[1]-b[1]))
def nearest_enemy():
    P,E=enemy_cells()
    return P,(min(E,key=lambda e:cheb(P,e)) if E else None)
def aim_click(x,y,t=0.35):
    """hover then click in one write so the target can't wander off in between"""
    send(f"{ESC}[<35;{x};{y}M{ESC}[<0;{x};{y}M{ESC}[<0;{x};{y}m",t)
def hover_only(x,y,t=0.3): send(f"{ESC}[<35;{x};{y}M",t)
def panel():
    return [row(r)[55:80].rstrip() for r in range(2,6)]
def wait_turn(maxt=3.0):
    end=time.time()+maxt
    while time.time()<end:
        pump(0.15)
        if "COMBAT - your turn" in mode() or "Exploring" in mode(): return
def endturn():
    send(" ",0.2); wait_turn()

def approach(d=10):
    """walk (explore mode) until the nearest enemy is within d cells, without waking them"""
    for _ in range(12):
        P,n=nearest_enemy()
        if n is None or cheb(P,n)<=d: return
        tx=max(2,min(52,n[0]-(d-1))) if n[0]>P[0] else n[0]+(d-1)
        click(tx,P[1] if abs(P[1]-n[1])<2 else n[1],0.6)
def cast(key,target=None,wait=0.35):
    send(key,0.12)
    P,E=enemy_cells()
    t=target or min(E,key=lambda e:cheb(P,e))
    aim_click(*t,wait)
    return t
