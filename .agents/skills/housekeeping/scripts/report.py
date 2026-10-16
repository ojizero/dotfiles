"""Render one housekeeping run and its history as a self-contained HTML page.

It uses T3 Code's theme variables when inlined there, and its own light/dark palette when opened alone.
"""
import json
import math
import re
from datetime import datetime
from html import escape

GIB = 1024 ** 3
MAX_ITEMS = 30
CATEGORIES = {'docker': 'Docker', 'caches': 'Package caches', 'worktrees': 'Worktrees', 'xcode': 'Xcode', 'other': 'Other'}
STATUS = {'healthy': ('Healthy', 'ok'), 'warning': ('Low space', 'warn'), 'urgent': ('Urgent', 'bad')}
OUTCOMES = {'done': 'Done', 'planned': 'Would do', 'failed': 'Failed', 'kept': 'Kept', 'skipped': 'Skipped'}
ICONS = {
    'done': '<path d="M3.5 8.5l3 3 6-7"/>', 'planned': '<path d="M3.5 8.5l3 3 6-7"/>',
    'failed': '<path d="M4.5 4.5l7 7M11.5 4.5l-7 7"/>', 'skipped': '<path d="M4 8h8"/>',
    'kept': '<rect x="4" y="7" width="8" height="6" rx="1.5"/><path d="M6 7V5.5a2 2 0 014 0V7"/>',
}

STYLE = """
:root{color-scheme:light dark;
--hk-fg:var(--foreground,#18181b);--hk-muted:var(--muted-foreground,#6b6b70);--hk-line:var(--border,#e4e4e7);
--hk-card:var(--card,#ffffff);--hk-bg:var(--background,#fafaf9);
--hk-ok:var(--success,#1f9d55);--hk-warn:var(--warning,#c98500);--hk-bad:var(--destructive,#d93636);
--c-docker:var(--chart-1,#2a78d6);--c-caches:var(--chart-2,#eb6834);--c-worktrees:var(--chart-3,#6250d6);
--c-xcode:var(--chart-4,#eda100);--c-other:var(--chart-5,#e87ba4);
--hk-r:var(--radius,10px);--hk-sans:var(--font-sans,ui-sans-serif,-apple-system,"SF Pro Text",system-ui,sans-serif);
--hk-mono:var(--font-mono,ui-monospace,"SF Mono",Menlo,monospace)}
@media (prefers-color-scheme:dark){:root{
--hk-fg:var(--foreground,#ededee);--hk-muted:var(--muted-foreground,#a1a1a6);--hk-line:var(--border,#2c2c30);
--hk-card:var(--card,#1c1c1f);--hk-bg:var(--background,#121214);
--hk-ok:var(--success,#3fb871);--hk-warn:var(--warning,#e0a526);--hk-bad:var(--destructive,#e66767);
--c-docker:var(--chart-1,#3987e5);--c-caches:var(--chart-2,#d95926);--c-worktrees:var(--chart-3,#9085e9);
--c-xcode:var(--chart-4,#c98500);--c-other:var(--chart-5,#d55181)}}
html{color:var(--hk-fg);font:14px/1.5 var(--hk-sans);-webkit-font-smoothing:antialiased}
body{margin:0}
html.alone{background:var(--hk-bg)}html.alone body{padding:40px 20px 56px}
.hk{max-width:780px;margin:0 auto;display:grid;gap:18px}
.ok{--tone:var(--hk-ok)}.warn{--tone:var(--hk-warn)}.bad{--tone:var(--hk-bad)}
.eyebrow{font-size:12px;color:var(--hk-muted);letter-spacing:.02em}
.hero{display:flex;flex-wrap:wrap;align-items:flex-end;gap:6px 16px}
.big{font-size:40px;line-height:1;font-weight:680;letter-spacing:-.03em;font-variant-numeric:tabular-nums}
.big small{font-size:17px;font-weight:550;letter-spacing:0;color:var(--hk-muted);margin-left:6px}
.pills{margin-left:auto;display:flex;gap:6px;flex-wrap:wrap}
.pill{display:inline-flex;align-items:center;gap:6px;padding:3px 10px;border-radius:999px;font-size:12px;font-weight:600;
color:var(--tone);background:color-mix(in srgb,var(--tone) 14%,transparent)}
.pill i{width:7px;height:7px;border-radius:50%;background:var(--tone)}
.pill.quiet{color:var(--hk-muted);background:color-mix(in srgb,var(--hk-muted) 12%,transparent)}
.sub{color:var(--hk-muted);font-size:13px;font-variant-numeric:tabular-nums}.sub b{color:var(--hk-fg);font-weight:600}
.bar{position:relative;height:12px;margin-top:2px;border-radius:6px;display:flex;gap:2px}
.bar span{height:100%}.bar span:first-child{border-radius:6px 0 0 6px}.bar span:last-child{border-radius:0 6px 6px 0}
.used{background:color-mix(in srgb,var(--hk-fg) 16%,transparent)}
.gain{background:var(--hk-ok)}.rest{background:color-mix(in srgb,var(--hk-ok) 40%,transparent)}
.tick{position:absolute;top:-4px;bottom:-4px;width:2px;margin-left:-1px;border-radius:1px;background:var(--tone)}
.keys{display:flex;flex-wrap:wrap;gap:4px 16px;font-size:12px;color:var(--hk-muted);font-variant-numeric:tabular-nums}
.keys span{display:inline-flex;align-items:center;gap:6px}
.sw{width:9px;height:9px;border-radius:3px;flex:none;background:var(--c)}
.sw.line{width:2px;height:11px;border-radius:1px;background:var(--tone)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:14px}
.card{background:var(--hk-card);border:1px solid var(--hk-line);border-radius:var(--hk-r);padding:16px;min-width:0}
h2{margin:0 0 12px;font-size:12px;font-weight:600;color:var(--hk-muted);letter-spacing:.05em;text-transform:uppercase;
display:flex;justify-content:space-between;gap:8px}h2 em{font-style:normal;text-transform:none;letter-spacing:0;font-weight:500}
.donut{display:flex;align-items:center;gap:18px;flex-wrap:wrap}.donut svg{flex:none}
.donut text{fill:var(--hk-fg);font-variant-numeric:tabular-nums}
.legend{flex:1;min-width:150px;display:grid;grid-template-columns:auto 1fr auto auto;gap:6px 10px;align-items:center;font-size:13px}
.num{font-family:var(--hk-mono);font-size:12px;text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
.dim{color:var(--hk-muted)}
.empty{color:var(--hk-muted);font-size:13px;padding:24px 0;text-align:center}
#hist{position:relative;height:170px}#hist svg{display:block;overflow:visible}
#hist text{fill:var(--hk-muted);font-size:11px;font-variant-numeric:tabular-nums}
.tip{position:absolute;pointer-events:none;background:var(--popover,var(--hk-card));color:var(--popover-foreground,var(--hk-fg));
border:1px solid var(--hk-line);border-radius:8px;padding:6px 9px;font-size:12px;white-space:nowrap;
box-shadow:0 4px 16px rgb(0 0 0/.12);transform:translate(-50%,-100%);opacity:0;transition:opacity .1s}
.caption{margin-top:8px;font-size:12.5px;color:var(--hk-muted)}.caption b{color:var(--hk-fg);font-weight:600}
.rows{display:grid}.row{display:grid;grid-template-columns:18px minmax(0,1fr) auto;gap:2px 10px;padding:9px 0;
border-top:1px solid var(--hk-line);align-items:start}.row:first-child{border-top:0;padding-top:0}
.row svg{margin-top:2px;fill:none;stroke:var(--tone);stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.row.done,.row.planned{--tone:var(--hk-ok)}.row.failed{--tone:var(--hk-bad)}.row.kept{--tone:var(--hk-warn)}.row.skipped{--tone:var(--hk-muted)}
.what{display:flex;align-items:center;gap:8px;min-width:0;font-weight:550}.what span{overflow:hidden;text-overflow:ellipsis}
.why{grid-column:2/-1;font-size:12.5px;color:var(--hk-muted);overflow-wrap:anywhere}
details{grid-column:2/-1;font-size:12px}summary{cursor:pointer;color:var(--hk-muted);width:max-content}
.items{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:3px 12px;margin-top:6px}
.items .p{font-family:var(--hk-mono);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;direction:rtl;text-align:left}
.mem{display:flex;flex-wrap:wrap;gap:4px 18px;font-size:12.5px;color:var(--hk-muted)}.mem b{color:var(--hk-fg);font-weight:600}
.tally{display:flex;flex-wrap:wrap;gap:6px 18px;font-size:13px;color:var(--hk-muted)}
.tally span{display:inline-flex;align-items:center;gap:5px}.tally b{color:var(--hk-fg);font-weight:650}
.tally svg{fill:none;stroke:var(--tone,var(--hk-muted));stroke-width:1.8;stroke-linecap:round;stroke-linejoin:round}
.tally .bad b{color:var(--hk-bad)}
"""

SCRIPT = """
(function(){
var root=document.documentElement,css=getComputedStyle(root);
if(!css.getPropertyValue('--background').trim())root.classList.add('alone');
var box=document.getElementById('hist');if(!box)return;
var runs=JSON.parse(document.getElementById('hist-data').textContent),G=1073741824;
function gib(n){return (n/G).toFixed(n<10*G?1:0)+' GiB'}
function day(t){return new Date(t).toLocaleDateString(undefined,{day:'numeric',month:'short'})}
function draw(){
  var W=box.clientWidth,H=170,L=40,R=10,T=12,B=22,w=W-L-R,h=H-T-B;
  var t0=runs[0].t,t1=runs[runs.length-1].t,span=Math.max(t1-t0,864e5*7);
  if(t1===t0)t0=t1-span;
  var top=Math.max.apply(null,runs.map(function(r){return Math.max(r.a,r.b)}).concat([runs[0].warn]))*1.15;
  var x=function(t){return L+(t-t0)/(t1-t0||1)*w},y=function(v){return T+h-v/top*h};
  var s='',step=Math.pow(10,Math.floor(Math.log10(top/G/3))),k=Math.ceil(top/G/3/step)*step;
  for(var v=0;v<=top/G;v+=k){s+='<line x1="'+L+'" x2="'+(W-R)+'" y1="'+y(v*G)+'" y2="'+y(v*G)+'" stroke="var(--hk-line)"/>'+
    '<text x="'+(L-6)+'" y="'+(y(v*G)+4)+'" text-anchor="end">'+v+'</text>'}
  s+='<line x1="'+L+'" x2="'+(W-R)+'" y1="'+y(runs[0].warn)+'" y2="'+y(runs[0].warn)+'" stroke="var(--hk-warn)" stroke-width="1.5" stroke-dasharray="4 4"/>';
  var d='',up='';
  runs.forEach(function(r,i){var X=x(r.t);d+=(i?'L':'M')+X+' '+y(r.b)+'L'+X+' '+y(r.a);
    if(r.a>r.b)up+='<line x1="'+X+'" x2="'+X+'" y1="'+y(r.b)+'" y2="'+y(r.a)+'" stroke="var(--hk-ok)" stroke-width="3" stroke-linecap="round"/>'});
  s+='<path d="'+d+'" fill="none" stroke="var(--hk-fg)" stroke-opacity=".55" stroke-width="2" stroke-linejoin="round"/>'+up;
  runs.forEach(function(r){s+='<circle cx="'+x(r.t)+'" cy="'+y(r.a)+'" r="4" fill="var(--hk-ok)" stroke="var(--hk-card)" stroke-width="2"/>'});
  s+='<text x="'+L+'" y="'+(H-4)+'">'+day(t0)+'</text><text x="'+(W-R)+'" y="'+(H-4)+'" text-anchor="end">'+day(t1)+'</text>';
  s+='<rect x="'+L+'" y="0" width="'+w+'" height="'+(H-B)+'" fill="transparent" id="hit"/>';
  box.innerHTML='<svg width="'+W+'" height="'+H+'">'+s+'</svg><div class="tip"></div>';
  var tip=box.querySelector('.tip');
  box.querySelector('#hit').addEventListener('mousemove',function(e){
    var mx=e.offsetX,best=runs[0];runs.forEach(function(r){if(Math.abs(x(r.t)-mx)<Math.abs(x(best.t)-mx))best=r});
    tip.innerHTML='<b>'+day(best.t)+'</b> &middot; freed '+gib(best.f)+'<br>'+gib(best.b)+' &rarr; '+gib(best.a)+' free';
    tip.style.left=Math.min(Math.max(x(best.t),70),W-70)+'px';tip.style.top=(y(best.a)-10)+'px';tip.style.opacity=1});
  box.querySelector('#hit').addEventListener('mouseleave',function(){tip.style.opacity=0});
}
draw();var last=box.clientWidth;new ResizeObserver(function(){if(box.clientWidth!==last){last=box.clientWidth;draw()}}).observe(box);
})();
"""


def size(n):
    if n is None:
        return '—'
    if n >= GIB:
        return f'{n / GIB:.1f} GiB'
    if n >= 1024 ** 2:
        return f'{n / 1024 ** 2:.0f} MiB'
    return f'{n / 1024:.0f} KiB' if n else '0'


def when(iso):
    d = datetime.fromisoformat(iso).astimezone()
    return f'{d.day} {d:%b %Y}, {d:%H:%M}'


def icon(outcome):
    return f'<svg width="16" height="16" aria-hidden="true"><use href="#hk-{outcome}"/></svg>'


SYMBOLS = ('<svg width="0" height="0" style="position:absolute">' + ''.join(
    f'<symbol id="hk-{k}" viewBox="0 0 16 16">{v}</symbol>' for k, v in ICONS.items()) + '</svg>')


def header(r):
    label, tone = STATUS[r['status_after']]
    was = STATUS[r['status_before']][0]
    pills = f'<span class="pill {tone}"><i></i>{label}</span>'
    if r['status_before'] != r['status_after']:
        pills += f'<span class="pill quiet">was {escape(was)}</span>'
    if r['dry_run']:
        pills += '<span class="pill quiet">Dry run</span>'
    if r['dry_run']:
        big = f'{sum(x["outcome"] == "planned" for x in r["results"])}<small>actions planned</small>'
    else:
        big = f'{size(r["freed_bytes"])}<small>freed</small>'
    minutes, seconds = divmod(r.get('seconds', 0), 60)
    took = f'{minutes}m {seconds}s' if minutes else f'{seconds}s'
    return (f'<div class="eyebrow">Housekeeping · {escape(r["host"])} · {when(r["date"])}</div>'
            f'<div class="hero"><div class="big">{big}</div><div class="pills">{pills}</div></div>'
            f'<div class="sub">Free space <b>{size(r["free_before"])}</b> → <b>{size(r["free_after"])}</b> '
            f'of {size(r["capacity"])} · took {took}</div>{tally(r)}')


def tally(r):
    counts = r['counts']
    parts = [('done', 'done' if not r['dry_run'] else 'planned', 'ok'), ('kept', 'kept for you', 'warn'),
             ('skipped', 'skipped', 'quiet'), ('failed', 'failed', 'bad')]
    if r['dry_run']:
        parts[0] = ('planned', 'planned', 'ok')
    return '<div class="tally">' + ''.join(
        f'<span class="{tone}">{icon(key)}<b>{counts.get(key, 0)}</b> {label}</span>'
        for key, label, tone in parts if counts.get(key) or key != 'failed') + '</div>'


def disk(r):
    cap = r['capacity']
    gain = max(0, r['free_after'] - r['free_before'])
    rest = r['free_after'] - gain
    used = cap - r['free_after']
    warn = cap * r['thresholds']['warning_percent'] / 100
    urgent = r['thresholds']['urgent_gib'] * GIB
    pct = lambda n: f'{max(0, n) / cap * 100:.3f}%'
    segs = f'<span class="used" style="width:{pct(used)}" title="Used {size(used)}"></span>'
    if gain:
        segs += f'<span class="gain" style="width:{pct(gain)}" title="Freed this run {size(gain)}"></span>'
    segs += f'<span class="rest" style="width:{pct(rest)}" title="Already free {size(rest)}"></span>'
    ticks = (f'<i class="tick warn" style="left:{pct(cap - warn)}" title="Low-space line: {size(warn)} free"></i>'
             f'<i class="tick bad" style="left:{pct(cap - urgent)}" title="Urgent line: {size(urgent)} free"></i>')
    keys = (f'<span><i class="sw" style="--c:color-mix(in srgb,var(--hk-fg) 16%,transparent)"></i>Used {size(used)}</span>'
            + (f'<span><i class="sw" style="--c:var(--hk-ok)"></i>Freed now {size(gain)}</span>' if gain else '')
            + f'<span><i class="sw" style="--c:color-mix(in srgb,var(--hk-ok) 40%,transparent)"></i>Was free {size(rest)}</span>'
            f'<span class="warn"><i class="sw line"></i>Low below {size(warn)}</span>'
            f'<span class="bad"><i class="sw line"></i>Urgent below {size(urgent)}</span>')
    return f'<div><div class="bar">{segs}{ticks}</div></div><div class="keys">{keys}</div>'


def donut(r):
    parts = [(k, r['freed'].get(k, 0)) for k in CATEGORIES if r['freed'].get(k, 0) > 0]
    total = sum(v for _, v in parts)
    head = f'<h2>Freed by category<em>{size(total) if total else ""}</em></h2>'
    if not total:
        text = 'Dry run: nothing was removed.' if r['dry_run'] else 'Nothing needed cleaning this time.'
        return f'<div class="card">{head}<div class="empty">{text}</div></div>'
    radius, width = 52, 16
    circ = 2 * math.pi * radius
    gap = 2.5 if len(parts) > 1 else 0
    arcs, offset = '', 0.0
    for key, value in parts:
        length = value / total * circ
        arcs += (f'<circle r="{radius}" cx="66" cy="66" fill="none" stroke="var(--c-{key})" stroke-width="{width}" '
                 f'stroke-dasharray="{max(length - gap, 0.5):.2f} {circ:.2f}" stroke-dashoffset="{-offset:.2f}" '
                 f'transform="rotate(-90 66 66)"><title>{CATEGORIES[key]}: {size(value)}</title></circle>')
        offset += length
    centre = (f'<text x="66" y="64" text-anchor="middle" font-size="18" font-weight="650">{size(total).split()[0]}</text>'
              f'<text x="66" y="82" text-anchor="middle" font-size="11" fill="var(--hk-muted)" style="fill:var(--hk-muted)">'
              f'{size(total).split()[1]} freed</text>')
    legend = ''.join(f'<i class="sw" style="--c:var(--c-{k})"></i><span>{CATEGORIES[k]}</span>'
                     f'<span class="num">{size(v)}</span><span class="num dim">{v / total * 100:.0f}%</span>' for k, v in parts)
    return (f'<div class="card">{head}<div class="donut"><svg width="132" height="132" viewBox="0 0 132 132" role="img" '
            f'aria-label="Freed space by category">{arcs}{centre}</svg><div class="legend">{legend}</div></div></div>')


def history(r, runs):
    head = '<h2>Free space over time<em>GiB</em></h2>'
    points = []
    for x in runs[-52:]:
        try:
            t = datetime.fromisoformat(x['date']).timestamp() * 1000
            points.append({'t': t, 'b': int(x['free_before']), 'a': int(x['free_after']),
                           'f': int(sum(x.get('freed', {}).values())),
                           'warn': int(x['capacity'] * r['thresholds']['warning_percent'] / 100)})
        except (KeyError, TypeError, ValueError):
            continue
    if not points:
        return f'<div class="card">{head}<div class="empty">History starts with the first real run.</div></div>'
    total = sum(p['f'] for p in points)
    previous = [p for p in points[:-1] if p['f'] > 0]
    if r['dry_run'] or len(points) < 2:
        since = 'History starts with this run.' if len(points) < 2 else ''
    else:
        days = (points[-1]['t'] - points[-2]['t']) / 864e5
        growth = points[-2]['a'] - points[-1]['b']
        since = (f'Since the previous run {days:.0f} days ago, <b>{size(abs(growth))}</b> was '
                 f'{"used" if growth >= 0 else "freed"} outside housekeeping. ')
    last = f' Last run that freed space: {when(datetime.fromtimestamp(previous[-1]["t"] / 1000).isoformat())}.' \
        if previous and not since.startswith('History') else ''
    data = json.dumps(points).replace('</', '<\\/')
    caption = (f'{since}<b>{size(total)}</b> freed across {len(points)} run{"s" if len(points) != 1 else ""}.{last} '
               '<span class="keys" style="display:inline-flex;margin-left:4px"><span class="warn"><i class="sw line"></i>'
               'low-space line</span><span class="ok"><i class="sw line"></i>cleanup</span></span>')
    return (f'<div class="card">{head}<div id="hist"></div><script type="application/json" id="hist-data">{data}</script>'
            f'<div class="caption">{caption}</div></div>')


def row(x):
    swatch = f'<i class="sw" style="--c:var(--c-{x["category"]})" title="{CATEGORIES[x["category"]]}"></i>'
    amount = size(x['bytes']) if x.get('bytes') is not None else ''
    if amount and x.get('partial'):
        amount += '+'
    items = x.get('items') or []
    details = ''
    if items:
        lines = ''.join(f'<span class="p" title="{escape(i["path"])}">{escape(i["path"])}</span>'
                        f'<span class="num dim">{size(i["bytes"]) if i.get("bytes") is not None else escape(i.get("note", ""))}</span>'
                        for i in items[:MAX_ITEMS])
        more = f'<span class="dim">and {len(items) - MAX_ITEMS} more</span><span></span>' if len(items) > MAX_ITEMS else ''
        details = f'<details><summary>Show {len(items)}</summary><div class="items">{lines}{more}</div></details>'
    return (f'<div class="row {x["outcome"]}">{icon(x["outcome"])}<div class="what">{swatch}<span>{escape(x["label"])}</span></div>'
            f'<span class="num">{amount}</span><div class="why">{escape(x.get("reason") or "")}</div>{details}</div>')


def lists(r):
    res = r['results']
    did = [x for x in res if x['outcome'] in ('done', 'planned')]
    did.sort(key=lambda x: -(x.get('bytes') or 0))
    order = {'failed': 0, 'kept': 1, 'skipped': 2}
    left = sorted((x for x in res if x['outcome'] in order), key=lambda x: (order[x['outcome']], -(x.get('bytes') or 0)))
    title = 'What it would do' if r['dry_run'] else 'What it did'
    did_html = ''.join(map(row, did)) or '<div class="empty">Nothing to clean.</div>'
    kept = sum(x.get('bytes') or 0 for x in left if x['outcome'] == 'kept')
    return (f'<div class="card"><h2>{title}<em>{len(did)}</em></h2><div class="rows">{did_html}</div></div>'
            f'<div class="card"><h2>What it left alone<em>{size(kept)} kept for you</em></h2>'
            f'<div class="rows">{"".join(map(row, left))}</div></div>')


def memory(r):
    m = r['memory']
    tone = {'normal': 'ok', 'warning': 'warn', 'critical': 'bad'}.get(m['pressure'], '')
    top = ', '.join(f'{escape(p["name"])} {size(p["rss_bytes"])}' for p in m['top_processes'][:4])
    return (f'<div class="card"><h2>Memory right now<em>processes are never stopped</em></h2><div class="mem">'
            f'<span class="{tone}">Pressure <b style="color:var(--tone,inherit)">{m["pressure"]}</b></span>'
            f'<span>Swap used <b>{size(m["swap_bytes"])}</b></span><span>Largest: {top}</span></div></div>')


def minify(text):
    return re.sub(r'\n\s*', '', text)


def render(r, runs):
    body = (header(r) + disk(r) + f'<div class="grid">{donut(r)}{history(r, runs)}</div>' + lists(r) + memory(r))
    return (f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,'
            f'initial-scale=1"><title>Housekeeping · {when(r["date"])}</title><style>{minify(STYLE)}</style></head>'
            f'<body>{SYMBOLS}<main class="hk">{body}</main><script>{minify(SCRIPT)}</script></body></html>')
