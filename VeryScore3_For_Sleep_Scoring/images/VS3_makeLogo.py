"""VeryScore3 icon and banner (proposal A of three; B thermal mouse and C rings kept below).
Writes VS3_icon.svg and VS3_banner.svg; render the PNGs with a browser, e.g. headless Edge --screenshot."""
import math, random, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else '.'
WAKE, NREM, REM = '#ffb547', '#4fc3f7', '#c792ff'
GREEN = '#5ff08a'
COL = {'W': WAKE, 'N': NREM, 'R': REM}
FONT = "'Segoe UI', 'Helvetica Neue', Arial, sans-serif"
INFERNO = [(0, '#3b0f70'), (.35, '#b5367a'), (.65, '#fb8761'), (1, '#fcfdbf')]

SEG = [('W', 0, .175), ('N', .175, .475), ('R', .475, .625), ('W', .625, .725), ('N', .725, 1)]
SEG_LONG = [('W', 0, .06), ('N', .06, .2), ('R', .2, .24), ('W', .24, .28), ('N', .28, .42), ('R', .42, .47),
            ('N', .47, .58), ('W', .58, .7), ('N', .7, .82), ('R', .82, .87), ('W', .87, .92), ('N', .92, 1)]


def state_at(segs, t):
    for s, a, b in segs:
        if a <= t < b:
            return s
    return segs[-1][0]


def signals(segs, n=600, seed=7, T0=.9):
    """t, state, eeg (about -1..1), temperature (0..1), photometry (0..1)."""
    rnd = random.Random(seed)
    t = [i / (n - 1) for i in range(n)]
    st = [state_at(segs, x) for x in t]
    eeg, temp, ph = [], [], []
    T, F = T0, 0.
    for i, (x, s) in enumerate(zip(t, st)):
        u = x * 400
        if s == 'W':
            e = .25 * math.sin(u * 1.9) + .2 * math.sin(u * 3.3 + 1) + rnd.uniform(-.15, .15)
        elif s == 'N':
            e = math.sin(u * .22) + .3 * math.sin(u * .9) + rnd.uniform(-.1, .1)
        else:
            e = .45 * math.sin(u * .75) + rnd.uniform(-.08, .08)
        eeg.append(e)
        T += ({'W': 1, 'N': .05, 'R': .75}[s] - T) * 12 / n
        temp.append(T + rnd.uniform(-.01, .01))
        F *= .9
        if rnd.random() < {'W': .035, 'N': .006, 'R': .06}[s] * 600 / n:
            F += rnd.uniform(.5, 1)
        ph.append(F + rnd.uniform(-.03, .03))
    m = max(ph)
    ph = [p / m for p in ph]
    return t, st, eeg, temp, ph


def inferno(v):
    v = min(max(v, 0), 1)
    for (o0, c0), (o1, c1) in zip(INFERNO, INFERNO[1:]):
        if v <= o1:
            f = (v - o0) / (o1 - o0)
            a, b = [int(c0[i:i + 2], 16) for i in (1, 3, 5)], [int(c1[i:i + 2], 16) for i in (1, 3, 5)]
            return '#' + ''.join(f'{round(x + (y - x) * f):02x}' for x, y in zip(a, b))
    return INFERNO[-1][1]


def path(xs, ys):
    return 'M' + ' L'.join(f'{x:.1f},{y:.1f}' for x, y in zip(xs, ys))


def stops(lst):
    return ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in lst)


def hypno(x0, x1, levels, w, segs=SEG):
    out, prev = [], None
    for s, a, b in segs:
        xa, xb, y = x0 + a * (x1 - x0), x0 + b * (x1 - x0), levels[s]
        if prev is not None:
            out.append(f'<line x1="{xa:.1f}" y1="{prev:.1f}" x2="{xa:.1f}" y2="{y:.1f}" stroke="#fff" '
                       f'stroke-opacity=".35" stroke-width="{w/3:.1f}"/>')
        out.append(f'<line x1="{xa:.1f}" y1="{y:.1f}" x2="{xb:.1f}" y2="{y:.1f}" stroke="{COL[s]}" '
                   f'stroke-width="{w}" stroke-linecap="round"/>')
        prev = y
    return ''.join(out)


def moon(cx, cy, r, mid):
    return (f'<mask id="{mid}"><circle cx="{cx}" cy="{cy}" r="{r}" fill="#fff"/>'
            f'<circle cx="{cx+r*.42:.1f}" cy="{cy-r*.38:.1f}" r="{r*.9:.1f}" fill="#000"/></mask>'
            f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#moonG)" mask="url(#{mid})"/>')


def stars(lst):
    return ''.join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#fff" fill-opacity="{o}"/>' for x, y, r, o in lst)


def defs(extra=''):
    return f'''<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1a1f4e"/><stop offset="1" stop-color="#3a1f6e"/></linearGradient>
  <linearGradient id="moonG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffe7a8"/><stop offset="1" stop-color="#ffb547"/></linearGradient>
  <linearGradient id="three" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fb8761"/><stop offset=".5" stop-color="{GREEN}"/><stop offset="1" stop-color="{NREM}"/></linearGradient>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  {extra}
</defs>'''


def svg(w, h, body, extra=''):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">\n'
            f'<title>VeryScore3</title>\n{defs(extra)}\n{body}\n</svg>\n')


# ---------------- A: panels, like the VS3 window ----------------
def icon_A():
    t, st, eeg, temp, ph = signals(SEG)
    x0, x1 = 56, 456
    xs = [x0 + v * (x1 - x0) for v in t]
    # temperature: y 196..244, coloured by height with an inferno gradient
    tg = (f'<linearGradient id="tempG" gradientUnits="userSpaceOnUse" x1="0" y1="250" x2="0" y2="190">'
          f'{stops(INFERNO)}</linearGradient>')
    body = f'''<rect width="512" height="512" rx="112" fill="url(#bg)"/>
{stars([(80,62,3,.8),(150,40,2,.6),(250,70,2.5,.6),(300,34,2,.5),(470,180,2,.5)])}
{moon(400, 100, 50, 'mA')}
<text x="50" y="168" font-family="{FONT}" font-weight="800" font-size="126" letter-spacing="-6" fill="#fff">VS<tspan fill="url(#three)">3</tspan></text>
<path d="{path(xs, [248 - 52 * v for v in temp])}" fill="none" stroke="url(#tempG)" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
<path d="{path(xs, [312 - 46 * v for v in ph])}" fill="none" stroke="{GREEN}" stroke-width="4" stroke-linejoin="round" filter="url(#glow)"/>
<path d="{path(xs, [350 + 14 * v for v in eeg])}" fill="none" stroke="#fff" stroke-opacity=".7" stroke-width="3" stroke-linejoin="round"/>
{hypno(x0, x1, {'W': 398, 'N': 428, 'R': 458}, 14)}'''
    return svg(512, 512, body, tg)


# ---------------- B: thermal sleeping mouse with a photometry fibre ----------------
def mouse(scale=1, tx=0, ty=0, gid='heat'):
    return f'''<g transform="translate({tx},{ty}) scale({scale})">
  <path d="M120,380 C70,440 210,470 330,430" fill="none" stroke="#b5367a" stroke-width="9" stroke-linecap="round"/>
  <ellipse cx="236" cy="322" rx="150" ry="104" transform="rotate(-6 236 322)" fill="url(#{gid})"/>
  <ellipse cx="362" cy="340" rx="84" ry="64" transform="rotate(24 362 340)" fill="url(#{gid})"/>
  <ellipse cx="428" cy="378" rx="12" ry="10" fill="#fb8761"/>
  <circle cx="328" cy="262" r="38" fill="url(#{gid})"/>
  <circle cx="330" cy="266" r="22" fill="#b5367a" fill-opacity=".55"/>
  <path d="M372,344 q14,10 28,4" fill="none" stroke="#3b0f70" stroke-width="5" stroke-linecap="round"/>
  <rect x="368" y="262" width="22" height="22" rx="4" fill="#d9dbe8"/>
  <line x1="379" y1="262" x2="379" y2="148" stroke="#d9dbe8" stroke-width="5"/>
  <line x1="379" y1="262" x2="379" y2="150" stroke="{GREEN}" stroke-width="3" filter="url(#glow)"/>
</g>'''


def heat_grad(gid, cx, cy, r):
    return (f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{r}">'
            f'{stops(list(reversed([(round(1 - o, 2), c) for o, c in INFERNO])))}</radialGradient>')


def icon_B():
    t, st, eeg, temp, ph = signals(SEG, seed=3)
    fx, fy = 379 * .8 + 42, 148 * .8 + 64   # fibre tip after the mouse transform
    xs = [56 + v * (fx - 56) for v in t]
    body = f'''<rect width="512" height="512" rx="112" fill="url(#bg)"/>
{stars([(70,200,2,.5),(460,210,2,.6),(440,40,2,.5),(250,200,1.5,.5)])}
{moon(440, 112, 34, 'mB')}
<text x="50" y="118" font-family="{FONT}" font-weight="800" font-size="96" letter-spacing="-5" fill="#fff">VS<tspan fill="url(#three)">3</tspan></text>
<path d="{path(xs, [fy - 40 * v for v in ph[:-1]] + [fy])}" fill="none" stroke="{GREEN}" stroke-width="3.5" stroke-linejoin="round" filter="url(#glow)"/>
{mouse(.8, 42, 64)}
{hypno(70, 442, {'W': 452, 'N': 470, 'R': 488}, 9)}'''
    return svg(512, 512, body, heat_grad('heat', 330, 330, 220))


# ---------------- C: rings, a polar recording ----------------
def polar(cx, cy, r, a):
    a = math.radians(a - 90)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc(cx, cy, r, a0, a1):
    (x0, y0), (x1, y1) = polar(cx, cy, r, a0), polar(cx, cy, r, a1)
    return f'M{x0:.1f},{y0:.1f} A{r},{r} 0 {int(a1 - a0 > 180)} 1 {x1:.1f},{y1:.1f}'


def rings(cx, cy, R, gid, gap=1.6):
    t, st, eeg, temp, ph = signals(SEG_LONG, n=900, seed=11, T0=.35)
    out = []
    for s, a, b in SEG_LONG:  # hypnogram ring
        out.append(f'<path d="{arc(cx, cy, R, a * 360 + gap, b * 360 - gap)}" fill="none" stroke="{COL[s]}" '
                   f'stroke-width="{R*.12:.1f}" stroke-linecap="round"/>')
    nb = 240
    for k in range(nb):
        v = temp[int(k / nb * len(temp))]
        out.append(f'<path d="{arc(cx, cy, R * .8, k * 360 / nb, (k + 1.15) * 360 / nb)}" fill="none" '
                   f'stroke="{inferno(v)}" stroke-width="{R*.1:.1f}"/>')
    pp = [polar(cx, cy, R * (.56 + .1 * v), x * 359) for x, v in zip(t, ph)]
    out.append(f'<path d="{path(*zip(*pp))}" fill="none" stroke="{GREEN}" stroke-width="{R*.02:.1f}" stroke-linejoin="round" filter="url(#glow)"/>')
    return ''.join(out)


def ring_grad(gid, cx, cy, R):
    sto = [(round(.66 + .16 * o, 3), c) for o, c in INFERNO]
    return (f'<radialGradient id="{gid}" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="{R}">'
            f'<stop offset="0" stop-color="{INFERNO[0][1]}"/>{stops(sto)}</radialGradient>')


def icon_C():
    body = f'''<rect width="512" height="512" rx="112" fill="url(#bg)"/>
{stars([(60,60,2.5,.7),(460,70,2,.6),(450,450,2,.5),(70,440,2,.5)])}
{rings(256, 256, 196, 'ringG')}
{moon(256, 200, 26, 'mC')}
<text x="256" y="314" text-anchor="middle" font-family="{FONT}" font-weight="800" font-size="80" letter-spacing="-4" fill="#fff">VS<tspan fill="url(#three)">3</tspan></text>'''
    return svg(512, 512, body, ring_grad('ringG', 256, 256, 196))


# ---------------- banners ----------------
LEGEND = [('Wake', WAKE), ('NREM', NREM), ('REM', REM), ('Temperature', '#fb8761'), ('Photometry dF/F', GREEN)]


def banner(letter, icon_svg):
    inner = icon_svg.split('</defs>', 1)[1].rsplit('</svg>', 1)[0]
    extra = icon_svg.split('<defs>', 1)[1].split('</defs>', 1)[0]
    extra = extra.split('<filter', 1)[1].split('</filter>', 1)[1]  # keep the icon-specific gradients only
    leg, x = [], 68
    for name, c in LEGEND:
        leg.append(f'<circle cx="{x}" cy="268" r="6" fill="{c}"/><text x="{x+12}" y="274" fill="{c}">{name}</text>')
        x += 44 + len(name) * 10
    body = f'''<rect width="1280" height="320" rx="36" fill="url(#bg)"/>
{stars([(40,40,2,.6),(330,34,2,.5),(560,60,1.8,.5),(700,28,2.2,.6),(820,290,1.6,.4)])}
<text x="64" y="138" font-family="{FONT}" font-weight="800" font-size="96" letter-spacing="-2" fill="#fff">VeryScore<tspan fill="url(#three)">3</tspan></text>
<text x="68" y="190" font-family="{FONT}" font-weight="500" font-size="30" fill="#fff" fill-opacity=".85">Mouse sleep scoring in MATLAB</text>
<text x="68" y="230" font-family="{FONT}" font-weight="500" font-size="22" fill="#fff" fill-opacity=".6">EEG/EMG · auto-scoring · thermal video · fibre photometry · Open Ephys</text>
<g font-family="{FONT}" font-weight="700" font-size="17">{''.join(leg)}</g>
<g transform="translate(940,24) scale(.531)"><rect width="512" height="512" rx="112" fill="#000" fill-opacity=".25"/>{inner.replace('<rect width="512" height="512" rx="112" fill="url(#bg)"/>', '')}</g>'''
    return svg(1280, 320, body, extra)


ic = icon_A()
for name, txt in (('VS3_icon.svg', ic), ('VS3_banner.svg', banner('A', ic))):
    with open(os.path.join(OUT, name), 'w', encoding='utf-8', newline='\n') as f:
        f.write(txt)
print('ok')
