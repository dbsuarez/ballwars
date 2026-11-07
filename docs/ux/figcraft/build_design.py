"""Editable Ball Wars concept; local FigCraft only, original assets preserved."""
import hashlib
import json
import math
import os
import re
from pathlib import Path
import struct
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
CLI = os.environ.get("FIGCRAFT_CLI", r"C:\Program Files\FigCraft\figcraft-cli.exe")
NATIVE = HERE / "Ball-Wars-Arcade-Concept.figcraft"
INK = "#0B111B"
PANEL = "#152230"
HIGH = "#203345"
LINE = "#35495B"
TEXT = "#F5F2E8"
MUTED = "#ACBDCC"
GOLD = "#FFD078"
CYAN = "#73E4E1"
RED = "#FF7467"
VIOLET = "#BC94FF"
BLUE = "#72B5FF"
GREEN = "#88DCA5"
TOKENS = {INK:"Ink", PANEL:"Panel", HIGH:"Raised panel", LINE:"Border", TEXT:"Text",
          MUTED:"Secondary text", GOLD:"Primary gold", CYAN:"Accent cyan", RED:"Ball red",
          VIOLET:"Epic violet", BLUE:"Rare blue", GREEN:"Positive green"}
steps, frames, skins = [], [], []
serial = 0


def call(*args):
    run = subprocess.run([CLI, "--no-system-fonts", *map(str, args)],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    if run.returncode:
        raise RuntimeError(f"FigCraft failed: {run.stderr}\n{run.stdout[-3000:]}")
    return run.stdout


def command(cmd, params=None, alias=None):
    item = {"command": cmd, "params": params or {}}
    if alias:
        item["as"] = alias
    steps.append(item)
    return {"$ref": alias} if alias else None


def node(parent, kind, x, y, w, h, name="", **props):
    global serial
    serial += 1
    alias = f"n{serial}"
    for key in ("fill", "stroke"):
        if isinstance(props.get(key), str) and props[key] in TOKENS:
            props[key] = {"$var": "BW/" + TOKENS[props[key]]}
    params = dict(type=kind, x=x, y=y, width=w, height=h,
                  name=name or f"{kind} {serial}", props=props)
    if parent:
        params["parent"] = parent
    return command("node.create", params, alias)


def rect(p, x, y, w, h, fill=PANEL, radius=0, stroke=None, name="", **props):
    if stroke:
        props.update(stroke=stroke, strokeWeight=1)
    return node(p, "rectangle", x, y, w, h, name, fill=fill, cornerRadius=radius, **props)


def text(p, label, x, y, w, h=24, size=14, color=TEXT, weight=500, align="left", **props):
    # Explicit vertical placement also works with FigCraft 0.16 text exports.
    line_height = size * 1.2
    y += max(0, (h-line_height)/2)
    return node(p, "text", x, y, w, line_height, label[:60], characters=label,
                fontFamily="Inter", fontStyle="Bold" if weight >= 600 else "Regular",
                fontVariations={"wght": weight}, fontSize=size, fill=color,
                textAlign=align, textAlignVertical="top", lineHeight=line_height, textAutoResize="none",
                features={"tnum": True}, **props)


def vector(p, path, x, y, w, h, fill="none", stroke=None, weight=1.5, name="Vector"):
    props = dict(fill=fill, path=path)
    if stroke:
        props.update(stroke=stroke, strokeWeight=weight, strokeCap="round", strokeJoin="round")
    return node(p, "vector", x, y, w, h, name, **props)


def ellipse(p, x, y, w, h, fill, stroke=None, weight=1, **props):
    if stroke:
        props.update(stroke=stroke, strokeWeight=weight)
    return node(p, "ellipse", x, y, w, h, fill=fill, **props)


def rule(p, x, y, w, color=LINE):
    rect(p, x, y, w, 1, color)


def ticket(p, x, y, w, h, fill=PANEL, stroke=LINE, cut=12, name="Ticket panel"):
    path = f"M0 0 H{w-cut} L{w} {cut} V{h-6} L{w-6} {h} H0 Z"
    return vector(p, path, x, y, w, h, fill, stroke, 1, name)


ICONS = {
    "back": "M16 2 L6 12 L16 22 M6 12 H23",
    "close": "M3 3 L21 21 M21 3 L3 21",
    "plus": "M12 2 V22 M2 12 H22",
    "minus": "M2 12 H22",
    "check": "M2 12 L9 19 L23 3",
    "play": "M5 2 L22 12 L5 22 Z",
    "pause": "M6 2 V22 M18 2 V22",
    "more": "M3 12 H5 M11 12 H13 M19 12 H21",
    "down": "M2 7 L12 17 L22 7",
    "search": "M16 16 L23 23 M19 10 A9 9 0 1 1 1 10 A9 9 0 1 1 19 10",
    "settings": "M1 6 H23 M1 18 H23 M7 1 V11 M17 13 V23",
    "replay": "M5 7 A10 10 0 1 1 2 16 M5 1 V8 H12",
    "skip": "M3 3 L17 12 L3 21 Z M22 3 V21",
    "sound": "M2 9 H7 L13 3 V21 L7 15 H2 Z M17 6 Q25 12 17 18",
    "music": "M9 18 V3 L22 1 V16 M9 3 L22 1 M1 18 A4 3 0 1 0 9 18 A4 3 0 1 0 1 18 M14 16 A4 3 0 1 0 22 16 A4 3 0 1 0 14 16",
    "random": "M1 4 H5 L19 20 H23 M1 20 H5 L19 4 H23 M19 0 L23 4 L19 8 M19 16 L23 20 L19 24",
    "move": "M7 4 L11 1 L15 4 M11 1 V23 M4 9 L1 12 L4 15 M1 12 H23 M20 9 L23 12 L20 15",
    "share": "M8 3 H2 V23 H22 V17 M9 14 L23 1 M15 1 H23 V9",
    "download": "M12 1 V17 M5 10 L12 17 L19 10 M2 20 V24 H22 V20",
    "save": "M2 1 H18 L23 6 V23 H1 V1 Z M6 1 V9 H17 V1 M6 23 V14 H18 V23",
    "star": "M12 0 L15 8 L24 9 L17 15 L20 24 L12 19 L4 24 L7 15 L0 9 L9 8 Z",
    "bolt": "M13 0 L2 14 H11 L9 24 L23 9 H13 Z",
    "filter": "M1 1 H23 L15 11 V22 L9 18 V11 Z",
    "info": "M12 9 V21 M12 2 V4",
}


def icon(p, kind, x, y, size=18, color=TEXT):
    fill = color if kind in ("play", "star", "bolt") else "none"
    return vector(p, ICONS[kind], x, y, size, size, fill, None if fill != "none" else color,
                  1.7, f"Icon {kind}")


def icon_button(p, kind, x, y, size=44, color=TEXT, selected=False):
    ticket(p, x, y, size, size, HIGH if selected else PANEL, color if selected else LINE, 6,
           f"44px control {kind}")
    icon(p, kind, x+(size-18)/2, y+(size-18)/2, 18, color)


def button(p, label, x, y, w, h=56, primary=True, leading=None, state="normal"):
    disabled = state == "disabled"
    bg = HIGH if disabled else GOLD if primary else PANEL
    fg = MUTED if disabled else INK if primary else TEXT
    if primary:
        ticket(p, x, y+4, w, h, "#7E5B28", "#7E5B28", 14, "Button depth")
    ticket(p, x, y, w, h, bg, "#FFE3A8" if primary and not disabled else LINE, 14,
           f"Button {label or 'skin'} {state}")
    if leading:
        icon(p, leading, x+18, y+(h-18)/2, 18, fg)
    if label:
        text(p, label, x+8+(24 if leading else 0), y, w-16-(24 if leading else 0), h,
             17 if primary else 13, fg, 800 if primary else 650, "center")


def pill(p, label, x, y, w, color=CYAN, selected=True):
    rect(p, x, y, w, 26, color if selected else PANEL, 5, color if selected else LINE)
    text(p, label, x+5, y+1, w-10, 24, 10, INK if selected else MUTED, 750, "center")


def image(p, asset, x, y, w, h, name="Sprite", fit="fit", opacity=1):
    layer = command("image.place", dict(path=str(asset), parent=p, x=x, y=y, width=w, height=h,
                               mode=fit, name=name), "image"+str(len(steps)))
    if opacity != 1:
        command("node.set",dict(ids=[layer],props=dict(opacity=opacity)))
    return layer


def sprite(p, name, x, y, size=48, opacity=1):
    image(p, HERE/"assets"/f"{name}.png", x, y, size, size, f"Existing sprite: {name}", opacity=opacity)


def header(p, title, back=True, right="settings", width=390):
    if back:
        icon_button(p, "back", 16, 14)
    text(p, title, 72 if back else 16, 12, width-144 if back else width-90, 48, 19, weight=800)
    if right:
        icon_button(p, right, width-60, 14)
    rule(p, 16, 70, width-32)


def screen(name, index, w=390, h=844, x=None, y=None):
    if x is None:
        x, y = (index % 3)*462, (index//3)*964
    frame = node(None, "frame", x, y, w, h, name, fill=INK, clip=True)
    frames.append(dict(name=name, width=w, height=h, alias=frame["$ref"]))
    rect(frame, 0, 0, w, 4, GOLD)
    # A quiet, static edge motif; no blur, backdrop filter or baked UI labels.
    for i in range(7):
        rect(frame, w-58+i*8, 0, 3, 76, LINE, opacity=.35)
    return frame


def ball(p, x, y, size, color, name=None, hp=None):
    if hp is not None:
        rect(p, x-2, y-10, size+4, 5, LINE, 1, TEXT)
        rect(p, x-1, y-9, (size+2)*hp/100, 3, GREEN)
    ellipse(p, x, y+4, size, size, "#050A10")
    ellipse(p, x, y, size, size, color, TEXT, 1.5)
    ellipse(p, x+size*.17, y+size*.12, size*.29, size*.12, TEXT, opacity=.2)
    for ex in (.28, .59):
        ellipse(p, x+size*ex, y+size*.29, size*.16, size*.21, TEXT, INK, .8)
        ellipse(p, x+size*(ex+.055), y+size*.36, size*.065, size*.10, INK)
    vector(p, "M0 0 Q12 15 24 0", x+size*.32, y+size*.58, size*.36, size*.16,
           stroke=INK, weight=max(1.5,size*.035), name="Editable smile")
    for ex in (-.055, .9):
        ellipse(p, x+size*ex, y+size*.66, size*.15, size*.15, TEXT, INK, 1)
    if name:
        tw = max(60, size+14)
        rect(p, x+size/2-tw/2, y+size+7, tw, 20, INK, 4, color)
        text(p, name, x+size/2-tw/2+2, y+size+7, tw-4, 20, 10, TEXT, 700, "center")


def arena(p, x, y, side, six=False, lab=False):
    layer = node(p, "frame", x, y, side, side, "Arena - full available width", fill=INK, clip=True)
    # Native vector arena mock. The shipped app keeps its ArenaCanvas renderer.
    for pos in range(0, int(side)+1, 24):
        rect(layer, pos, 0, 1, side, "#162633")
        rect(layer, 0, pos, side, 1, "#162633")
    ellipse(layer, 3, 3, side-6, side-6, "#101E2B", TEXT, 2)
    for pos in range(24, int(side)-24, 24):
        # Editable lattice stays inside a circular mask in Flutter.
        half = math.sqrt(max(0, (side/2-5)**2-(pos-side/2)**2))
        rect(layer, pos, side/2-half, 1, half*2, "#1B303E")
        rect(layer, side/2-half, pos, half*2, 1, "#1B303E")
    text(layer, "cha0s' Balls", side*.2, side*.40, side*.6, 36, side*.062, MUTED, 800, "center", opacity=.16)
    text(layer, "Bakbakan na!", side*.25, side*.49, side*.5, 24, 12, MUTED, 650, "center", opacity=.16)
    if six:
        for fx, fy, color, label, hp in [
            (.18,.21,RED,"Crimson",86),(.64,.17,BLUE,"Volt",64),(.41,.48,VIOLET,"Phantom",100),
            (.15,.66,GOLD,"Blaze",43),(.72,.60,GREEN,"Jade",72),(.47,.77,CYAN,"Frost",91)]:
            ball(layer, side*fx, side*fy, side*.105, color, label, hp)
        sprite(layer, "pistol", side*.27, side*.28, 30)
        sprite(layer, "speed", side*.72, side*.43, 32)
        sprite(layer, "shield", side*.48, side*.12, 30)
    else:
        ball(layer, side*.24, side*.33, 54, RED, "A" if lab else "Crimson", 100)
        ball(layer, side*.66, side*.60, 54, BLUE, "B" if lab else "Volt", 74)
        sprite(layer, "rocket", side*.33, side*.35, 48)
        sprite(layer, "shield", side*.64, side*.61, 40)
    return layer


def mode_card(p, label, sub, glyph, x, y, w, selected=False, accent=CYAN):
    ticket(p, x, y, w, 80, HIGH if selected else PANEL, GOLD if selected else LINE, 10)
    icon(p, glyph, x+12, y+12, 20, accent)
    if selected:
        icon(p, "check", x+w-27, y+12, 14, GOLD)
    text(p, label, x+12, y+38, w-24, 20, 14, TEXT, 800)
    text(p, sub, x+12, y+60, w-20, 15, 10, MUTED)


def home(index, width=390, height=844, name="01 Home"):
    p = screen(name,index,width,height)
    text(p, "THE BATTLE GARAGE",16,22,220,20,10,CYAN,800,letterSpacing=1.8)
    icon_button(p,"music",width-112,14)
    icon_button(p,"settings",width-60,14)
    text(p,"BALL",16,67,width-32,62,54,TEXT,900,letterSpacing=-2)
    text(p,"WARS",156,67,width-172,62,54,GOLD,900,letterSpacing=-2)
    text(p,"YOUR BALLS. THEIR PROBLEM.",18,132,width-36,20,10,MUTED,800,letterSpacing=1)
    image(p,ROOT/"assets/ui/lobby-hero.webp",0,165,width,210,"User-owned battle illustration","fill")
    # The hero remains image artwork; all titles and controls are live layers.
    button(p,"LET'S BATTLE",16,385,width-32,58,leading="play")
    text(p,"CHOOSE YOUR CHAOS",16,469,width-32,20,11,MUTED,800,letterSpacing=1.4)
    gap=8; w=(width-48)/3
    for i,(label,sub,glyph,accent) in enumerate([
        ("Arsenal","Weapon battles","bolt",CYAN),("Mayhem","6-8 balls","random",VIOLET),("All-Out","Threads + arms","star",RED)]):
        mode_card(p,label,sub,glyph,16+i*(w+gap),500,w,label=="Mayhem",accent)
    w2=(width-40)/2
    mode_card(p,"Threads","The original","random",16,590,w2,accent=BLUE)
    mode_card(p,"Neo Threads","Grow. Cut. Survive.","bolt",24+w2,590,w2,accent=GREEN)
    for i,(label,detail,glyph) in enumerate([("My groups","Build your crew","plus"),("Replays","Watch it again","replay")]):
        x=16+i*(w2+8)
        ticket(p,x,696,w2,64,PANEL,LINE,8)
        icon(p,glyph,x+12,716,18,CYAN)
        text(p,label,x+40,706,w2-46,20,13,TEXT,750)
        text(p,detail,x+40,730,w2-46,16,10,MUTED)
    text(p,"CREDITS & LICENSES",16,min(height-35,800),width-32,20,10,MUTED,650,"center")
    return p


def setup():
    p=screen("02 Match Setup",1)
    header(p,"Match setup")
    text(p,"MAYHEM",16,90,270,44,32,TEXT,900)
    pill(p,"TIMED SCORE",266,99,108,VIOLET)
    text(p,"6 fighters  /  2:00  /  Arsenal rules",16,141,358,24,13,MUTED)
    for i,(label,selected) in enumerate([("Gameplay",True),("Appearance",False),("Audio",False)]):
        pill(p,label,16+i*121,183,113,GOLD,selected)
    text(p,"YOUR LINEUP",16,229,240,20,11,MUTED,800,letterSpacing=1.3)
    text(p,"6 / 8",310,229,64,20,11,CYAN,750,"right")
    for i,(name,color) in enumerate([("Crimson",RED),("Volt",BLUE),("Phantom",VIOLET),("Blaze",GOLD),("Jade",GREEN),("Frost",CYAN)]):
        x=16+(i%2)*183; y=265+(i//2)*76
        ticket(p,x,y,175,66,PANEL,LINE,8)
        ball(p,x+12,y+13,32,color)
        text(p,name,x+54,y+12,104,24,13,TEXT,750)
        text(p,"Ready",x+54,y+35,88,18,10,GREEN)
        icon(p,"check",x+151,y+13,12,GREEN)
    text(p,"ARENA",16,514,280,20,11,MUTED,800,letterSpacing=1.3)
    ticket(p,16,547,358,90,PANEL,LINE,10)
    ellipse(p,30,561,60,60,"#112A42",CYAN,1)
    ellipse(p,41,572,38,38,"none",VIOLET,1)
    text(p,"Space",108,560,190,26,18,TEXT,800)
    text(p,"Circle  /  center wall off",108,590,190,22,11,MUTED)
    icon_button(p,"down",316,568)
    text(p,"PICKUP PRESETS",16,659,240,20,11,MUTED,800,letterSpacing=1.3)
    ticket(p,16,692,358,52,PANEL,LINE,8)
    sprite(p,"pistol",24,695,44)
    text(p,"Military + Unique",78,698,218,22,14,TEXT,750)
    text(p,"Mix presets or choose items",78,721,228,16,10,MUTED)
    icon(p,"info",326,709,16,CYAN)
    button(p,"START MAYHEM",16,774,358,54,leading="play")


def battle():
    p=screen("03 Live Battle",2)
    icon_button(p,"close",16,14)
    text(p,"MAYHEM",72,12,245,28,18,TEXT,850,"center")
    text(p,"01:42 LEFT",72,40,245,20,11,CYAN,750,"center")
    icon_button(p,"pause",330,14)
    arena(p,0,82,390,True)
    text(p,"LIVE STANDINGS",16,494,300,20,11,MUTED,800,letterSpacing=1.2)
    for i,(name,color,stat) in enumerate([("Crimson",RED,"4 W   1 L"),("Volt",BLUE,"3 W   2 L"),("Phantom",VIOLET,"2 W   1 L"),("Blaze",GOLD,"2 W   3 L"),("Jade",GREEN,"1 W   2 L"),("Frost",CYAN,"0 W   3 L")]):
        x=16+(i%3)*122; y=528+(i//3)*73
        ticket(p,x,y,114,64,PANEL,color,7)
        text(p,name,x+8,y+7,98,20,12,TEXT,750)
        text(p,stat,x+8,y+29,98,18,11,MUTED,650)
        rect(p,x+8,y+53,98,3,LINE)
        rect(p,x+8,y+53,98*(1-i*.09),3,color)
    text(p,"WINS  >  FEWER LOSSES  >  REMAINING HP",16,689,358,20,9,MUTED,650,"center")
    for i,k in enumerate(["move","music","sound","settings"]):
        icon_button(p,k,16+i*52,734,44,CYAN if i else TEXT)
    button(p,"Mayhem match",232,734,142,44,False)
    text(p,"Spectate. Let the chaos happen.",16,801,358,20,11,MUTED,500,"center")


def results():
    p=screen("04 Winner",3)
    # This panel's geometric center is exactly the 390x844 viewport center.
    ticket(p,16,76,358,692,PANEL,GOLD,16,"Centered winner panel")
    text(p,"MATCH COMPLETE",32,94,326,22,10,GOLD,800,"center",letterSpacing=1.5)
    ball(p,155,130,80,RED)
    text(p,"CRIMSON",32,225,326,40,30,TEXT,900,"center")
    text(p,"wins!",32,267,326,24,18,GOLD,750,"center")
    ticket(p,32,308,326,48,HIGH,LINE,8)
    sprite(p,"rocket",40,308,48)
    text(p,"WINNING MOVE",98,313,245,16,9,MUTED,750)
    text(p,"Rocket Launcher",98,331,245,22,14,TEXT,800)
    text(p,"FINAL TALLY",32,373,220,20,10,MUTED,800)
    text(p,"W     L     HP",245,373,113,20,10,MUTED,650,"right")
    for i,(name,col,wins,loss,hp) in enumerate([("Crimson",RED,7,1,86),("Volt",BLUE,5,2,64),("Phantom",VIOLET,4,2,71),("Blaze",GOLD,3,4,43),("Jade",GREEN,2,4,72),("Frost",CYAN,1,5,91)]):
        y=400+i*20
        ellipse(p,34,y+7,5,5,col)
        text(p,name,48,y,175,20,11,TEXT,700)
        text(p,f"{wins}     {loss}     {hp}",230,y,126,20,11,MUTED,650,"right")
    button(p,"PLAY AGAIN",32,544,326,50,leading="play")
    button(p,"Replay",32,608,159,42,False,leading="replay")
    button(p,"Finisher",199,608,159,42,False,leading="bolt")
    for i,(label,glyph) in enumerate([("Save replay","save"),("Save video","download"),("Share","share")]):
        x=32+i*111
        ticket(p,x,665,104,48,INK,LINE,7)
        icon(p,glyph,x+8,681,15,CYAN)
        text(p,label,x+28,668,72,42,10,TEXT,650,"center")
    text(p,"EXIT TO LOBBY",32,725,326,24,11,MUTED,750,"center")


def skill_card(p,x,y,label,asset,tier,desc,source="BUILT-IN"):
    color={"Normal":TEXT,"Rare":BLUE,"Epic":VIOLET,"Special":GOLD}[tier]
    ticket(p,x,y,175,142,PANEL,color,10,f"{tier} skill card")
    text(p,source,x+12,y+8,90,16,8,MUTED,700,letterSpacing=.6)
    pill(p,tier.upper(),x+95,y+8,68,color,False)
    sprite(p,asset,x+14,y+32,58)
    text(p,label,x+12,y+94,151,20,13,TEXT,800)
    text(p,desc,x+12,y+116,151,18,10,MUTED)


def library():
    p=screen("05 Skill Library",4)
    header(p,"Skill Library",right="more")
    icon_button(p,"plus",278,14)
    text(p,"CRAFT THE CHAOS.",16,91,358,33,24,TEXT,900)
    ticket(p,16,143,302,46,PANEL,LINE,8)
    icon(p,"search",29,157,17,MUTED)
    text(p,"Search skills",58,146,244,40,13,MUTED)
    icon_button(p,"filter",330,144)
    x=16
    for label,w in [("All",48),("Weapons",100),("Power-ups",111),("Traps",75)]:
        pill(p,label,x,206,w,GOLD,label=="All"); x+=w+8
    for i,args in enumerate([
        ("Pistol","pistol","Normal","One clean shot."),
        ("Rocket Launcher","rocket","Special","One homing missile."),
        ("Boomerang","boomerang","Rare","Out. Back. Ouch."),
        ("Sword","sword","Normal","Close-range damage."),
        ("Speed","speed","Normal","Move faster for a while."),
        ("Ghost","ghost","Normal","Pass through danger."),
    ]):
        skill_card(p,16+(i%2)*183,254+(i//2)*155,*args)
    text(p,"Source, status and rarity live in Filters.",16,734,358,20,10,MUTED,500,"center")
    button(p,"Global defaults",16,777,175,50,False)
    button(p,"Save library",199,777,175,50,True)


def stepper(p,label,y,value):
    text(p,label,16,y,193,44,13,TEXT,650)
    ticket(p,224,y,150,44,PANEL,LINE,7)
    icon(p,"minus",238,y+16,14,MUTED)
    text(p,value,266,y,66,44,14,TEXT,800,"center")
    icon(p,"plus",345,y+16,14,CYAN)


def editor():
    p=screen("06 Skill Editor",5)
    header(p,"Edit skill",right=None)
    button(p,"SAVE",294,16,80,40,True)
    sprite(p,"rocket",16,92,54)
    text(p,"Rocket Launcher",82,90,292,29,21,TEXT,850)
    text(p,"Built-in  /  Weapon  /  Two-handed",82,122,292,22,10,MUTED)
    labels=["Identity","Mechanics","Timing","Visuals","Audio","Preview"]
    for i,label in enumerate(labels):
        text(p,label,8+i*64,162,64,32,10,GOLD if label=="Visuals" else MUTED,750,"center")
    rect(p,200,196,64,3,GOLD)
    text(p,"Artwork & placement",16,216,358,28,22,TEXT,850)
    for i,label in enumerate(["Artwork","Grip","Projectile","Effects","Area","Shells"]):
        text(p,label,10+i*64,252,64,28,10,CYAN if i==0 else MUTED,700,"center")
    for i,(label,asset) in enumerate([("Equipped artwork","rocket"),("Projectile artwork","missile")]):
        x=16+i*183
        ticket(p,x,299,175,144,PANEL,LINE,10)
        sprite(p,asset,x+51,316,72)
        text(p,label,x+8,396,159,25,11,TEXT,700,"center")
        icon(p,"down",x+147,424,12,MUTED)
    for i,label in enumerate(["Casting effect","Impact effect"]):
        x=16+i*183
        ticket(p,x,457,175,69,PANEL,LINE,8)
        ellipse(p,x+14,475,30,30,"none",CYAN if i==0 else GOLD,2)
        ellipse(p,x+22,483,14,14,"none",CYAN if i==0 else GOLD,1)
        text(p,label,x+54,466,109,22,11,TEXT,700)
        text(p,"Choose artwork",x+54,490,109,20,9,MUTED)
    stepper(p,"Equipped scale",548,"1.0x")
    stepper(p,"Projectile scale",607,"1.4x")
    text(p,"Sprite tint",16,666,193,44,13,TEXT,650)
    ticket(p,224,666,150,44,PANEL,LINE,7)
    ellipse(p,238,679,18,18,GOLD)
    text(p,"Original",269,666,83,44,12,TEXT,700)
    icon(p,"down",354,682,12,MUTED)
    text(p,"Keep every artwork slot separate.",16,728,358,20,10,MUTED,500,"center")
    for i,(label,glyph) in enumerate([("Preview","play"),("Demo","eye" if "eye" in ICONS else "bolt"),("Live","move"),("Finisher","star")]):
        x=16+i*91
        ticket(p,x,774,83,54,PANEL,LINE,8)
        icon(p,glyph,x+33,781,16,CYAN)
        text(p,label,x+2,801,79,22,10,TEXT,700,"center")


def lab():
    p=screen("07 Power-up Test",6)
    header(p,"Power-up Test",right="settings")
    icon_button(p,"sound",278,14)
    text(p,"DRAG BALLS TO PLACE THEM",16,104,358,20,10,MUTED,700,"center",letterSpacing=1)
    arena(p,0,147,390,False,True)
    for right,color,letter in [(False,RED,"A"),(True,BLUE,"B")]:
        x=350 if right else 4
        icon_button(p,"down",x,159,36,color)
        for i,glyph in enumerate(["move","pause","random"]):
            icon_button(p,glyph,x,201+i*38,36,color if i==0 else MUTED,i==0)
        for i,asset in enumerate(["pistol","sword","speed"] if not right else ["shield",None,None]):
            y=337+i*38
            ticket(p,x,y,36,36,INK,color,5)
            if asset: sprite(p,asset,x+1,y+1,34)
            else: icon(p,"plus",x+10,y+10,16,TEXT)
        text(p,letter,x,456,36,20,11,color,800,"center")
    for i,asset in enumerate(["mine","portal",None]):
        x=137+i*39
        ticket(p,x,493,36,36,INK,LINE,5)
        if asset: sprite(p,asset,x+1,494,34)
        else: icon(p,"plus",x+10,503,16,TEXT)
    text(p,"Paused  /  12.4 s",16,567,358,24,15,TEXT,700,"center")
    text(p,"Ball A: 100 HP     Ball B: 74 HP",16,596,358,22,12,MUTED,650,"center")
    for side in range(2):
        for i,asset in enumerate(["pistol","sword","speed"] if side==0 else ["shield",None,None]):
            x=(16 if side==0 else 261)+i*38
            ticket(p,x,654,34,34,PANEL,LINE,5)
            if asset:
                sprite(p,asset,x+1,655,32,opacity=1 if asset in ("pistol","sword") else .3)
            else:
                icon(p,"minus",x+10,665,14,MUTED)
    text(p,"FINISHERS",140,661,110,20,9,MUTED,700,"center")
    for i,glyph in enumerate(["replay","skip"]):
        icon_button(p,glyph,33+i*45,734,36,MUTED)
    button(p,"",159,716,72,72,True)
    icon(p,"play",184,740,25,INK)
    ticket(p,267,734,36,36,PANEL,LINE,6)
    text(p,"1x",267,734,36,36,11,TEXT,800,"center")
    icon_button(p,"settings",312,734,36,MUTED)
    text(p,"Tap item: rearm  /  Hold: choose",16,807,358,18,10,MUTED,500,"center")


def wide():
    p=screen("08 Battle - landscape",0,800,360,1430,0)
    rect(p,0,0,800,360,"#05080D")
    rect(p,180,0,440,360,INK)
    rect(p,180,0,440,4,GOLD)
    arena(p,180,70,219,True)
    rect(p,400,0,1,360,LINE)
    icon_button(p,"close",412,12,36)
    text(p,"MAYHEM",456,12,112,24,15,TEXT,850)
    text(p,"01:42 LEFT",456,39,112,20,11,CYAN,750)
    icon_button(p,"pause",576,12,36)
    for i,(label,color) in enumerate([("Crimson",RED),("Volt",BLUE),("Phantom",VIOLET),("Blaze",GOLD),("Jade",GREEN),("Frost",CYAN)]):
        y=88+i*30
        ellipse(p,416,y+8,6,6,color)
        text(p,label,432,y,100,24,11,TEXT,750)
        text(p,f"{4-i//2} W  {i%3} L",535,y,65,24,10,MUTED,650,"right")
    button(p,"Mayhem match",416,300,188,40,False)
    icon_button(p,"move",192,304,36,MUTED)
    icon_button(p,"sound",351,304,36,CYAN)
    text(p,"800 x 360",16,144,144,24,12,MUTED,700)
    text(p,"440px app frame",16,172,144,22,10,MUTED)
    text(p,"Centered, as today",16,198,144,22,10,MUTED)


def component_board():
    p=screen("10 Component kit",0,1200,1020,0,2892)
    text(p,"THE BATTLE GARAGE / FLUTTER KIT",32,28,1136,54,32,TEXT,900)
    text(p,"Live text + editable paths. No paid UI kit. No baked labels. No gameplay changes.",32,88,1136,28,15,MUTED)
    for i,(label,color) in enumerate([("Ink",INK),("Panel",PANEL),("Primary",GOLD),("Accent",CYAN),("Rare",BLUE),("Epic",VIOLET),("Special",GOLD)]):
        x=32+i*162
        rect(p,x,142,146,44,color,6,LINE)
        text(p,f"{label}  {color}",x,196,146,22,10,MUTED,700)
    text(p,"BUTTON SKINS / 256x64 / TEXT-FREE",32,245,1136,24,13,TEXT,800)
    for i,(state,label) in enumerate([("normal","Normal"),("pressed","Pressed"),("disabled","Disabled")]):
        x=32+i*300
        master=node(p,"component",x,288,256,64,f"skin-primary-{state}",fill="none",clip=True)
        offset=4 if state=="pressed" else 0
        ticket(master,0,4,256,58,"#6E5027" if state!="disabled" else "#19232E",
               "#6E5027" if state!="disabled" else LINE,14)
        ticket(master,0,offset,256,58,HIGH if state=="disabled" else GOLD,
               LINE if state=="disabled" else "#FFE8B8",14)
        if state!="disabled": rect(master,16,offset+3,220,1,"#FFF1CF")
        text(p,label,x,363,256,22,12,MUTED,700,"center")
        skins.append(dict(name=f"skin-primary-{state}",width=256,height=64,
                          centerSlice=[24,24,208,16],textColor=MUTED if state=="disabled" else INK))
    text(p,"RARITY CARD SKINS / 256x192",32,418,1136,24,13,TEXT,800)
    for i,(tier,color) in enumerate([("normal",TEXT),("rare",BLUE),("epic",VIOLET),("special",GOLD)]):
        x=32+i*288
        master=node(p,"component",x,462,256,192,f"skin-card-{tier}",fill="none",clip=True)
        ticket(master,0,0,256,192,PANEL,color,14)
        rect(master,16,1,76,2,color)
        text(p,tier.upper(),x,668,256,22,12,color,800,"center")
        skins.append(dict(name=f"skin-card-{tier}",width=256,height=192,centerSlice=[24,24,208,144],textColor=TEXT))
    text(p,"STATES & SPACING",32,728,520,24,13,TEXT,800)
    button(p,"START MATCH",32,778,256,56,True,leading="play")
    button(p,"Secondary",320,778,210,56,False)
    icon_button(p,"settings",562,784)
    icon_button(p,"plus",622,784,color=CYAN,selected=True)
    text(p,"44px controls / 8px gaps / 16px gutters / 72px test Play",32,862,1136,28,16,MUTED)
    text(p,"Native path or PNG nine-slice. Labels, icons, focus rings and hit targets stay in Flutter.",32,910,1136,30,15,TEXT,650)
    text(p,"Normal / Rare / Epic / Special. Existing fonts and assets remain licensed independently.",32,963,1136,24,12,MUTED)


def main():
    command("file.new",dict(name="Ball Wars - Battle Garage concept"))
    command("page.setBackground",dict(color="#27323E"))
    collection = command("variable.createCollection", dict(name="Ball Wars / Battle Garage", modes=["Dark"]), "theme")
    for color, name in TOKENS.items():
        command("variable.create", dict(collection=collection, name="BW/"+name, type="color", value=color))
    home(0)
    setup()
    battle()
    results()
    library()
    editor()
    lab()
    wide()
    home(0,360,800,"09 Home - narrow phone")
    # Move the responsive duplicate away from the primary Home board.
    command("node.set",dict(ids=[{"$ref":frames[-1]["alias"]}],props=dict(x=1430,y=600)))
    component_board()
    command("select.set",dict(ids=[{"$ref":frames[0]["alias"]}]))
    command("view.zoomSelection")
    build=ROOT/"build/figcraft-design";build.mkdir(parents=True,exist_ok=True)
    script=build/"ball-wars-design.steps.json"
    script.write_text(json.dumps(steps,indent=2),encoding="utf-8")
    output=call("run",script,"--out",NATIVE)
    command_results=[json.loads(line) for line in output.splitlines() if line.strip()]
    if len(command_results)!=len(steps) or any(not item.get("ok") for item in command_results):
        raise RuntimeError("A design command failed or did not report a result")
    info=json.loads(call("info",NATIVE,"--json"))
    if info.get("missingFonts") or info.get("notes"):
        raise RuntimeError(f"Design has font/import warnings: {info}")
    (HERE/"DESIGN-INFO.json").write_text(json.dumps(info,indent=2)+"\n",encoding="utf-8")
    exports=[]
    for frame in frames:
        stem=re.sub(r"[^a-z0-9]+", "-", frame["name"].lower()).strip("-")
        destination=HERE/"previews"/f"{stem}.png"
        call("export",NATIVE,"-o",destination,"--node",frame["name"],"--scale",1)
        data=destination.read_bytes()
        assert struct.unpack(">II",data[16:24])==(frame["width"],frame["height"])
        exports.append(dict(name=frame["name"],file=destination.relative_to(HERE).as_posix(),
                            width=frame["width"],height=frame["height"],
                            sha256=hashlib.sha256(data).hexdigest()))
    for skin in skins:
        path=HERE/"skins"/f"{skin['name']}.png"
        call("export",NATIVE,"-o",path,"--node",skin["name"],"--scale",1)
        call("export",NATIVE,"-o",path.with_suffix(".svg"),"--node",skin["name"])
        data=path.read_bytes()
        assert struct.unpack(">II",data[16:24])==(skin["width"],skin["height"])
        skin.update(file=path.relative_to(HERE).as_posix(),sha256=hashlib.sha256(data).hexdigest())
    call("render",NATIVE,"-o",HERE/"previews/overview.png","--scale",.5)
    (HERE/"DESIGN-MANIFEST.json").write_text(json.dumps(dict(
        figcraftVersion=call("--version").strip(),commandCount=len(steps),
        screens=exports,skins=skins,native=NATIVE.name,
        native_sha256=hashlib.sha256(NATIVE.read_bytes()).hexdigest()),indent=2)+"\n",encoding="utf-8")
    print(f"Saved {NATIVE}; {len(frames)} frames, {len(skins)} text-free skins, {len(steps)} successful commands.")


if __name__=="__main__":
    main()
