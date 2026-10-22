"""Génère le logo de Pécule : un « p » dont la panse est un donut de budget, avec un accent vert qui monte."""
import math
import sys
from pathlib import Path

import cairosvg

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)

CX, CY = 540, 500        # centre de la panse
R = 186                  # rayon (ligne médiane de l'anneau)
W = 96                   # épaisseur du trait
WHITE = "#FFFFFF"
GREEN = "#3EE0A1"


def pt(deg, r=R):
    a = math.radians(deg)
    return CX + r * math.cos(a), CY - r * math.sin(a)


def arc(a0, a1, color):
    """Arc anti-horaire de a0 à a1 degrés (repère mathématique)."""
    x0, y0 = pt(a0)
    x1, y1 = pt(a1)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    return (f'<path d="M{x0:.1f},{y0:.1f} A{R},{R} 0 {large} 0 {x1:.1f},{y1:.1f}" '
            f'fill="none" stroke="{color}" stroke-width="{W}" stroke-linecap="butt"/>')


def content(mono=False):
    green = WHITE if mono else GREEN
    stem_x = CX - R - W / 2
    parts = [
        # panse blanche (la majeure partie du donut)
        arc(16, 300, WHITE),
        # part verte du donut : ce qui est remboursé / économisé
        arc(306, 370, green),
        # jambage du « p »
        f'<rect x="{stem_x:.1f}" y="{CY - 40}" width="{W}" height="{420}" rx="{W / 2}" fill="{WHITE}"/>',
        # accent du « é » : un trait vert qui monte, comme une courbe d'épargne
        f'<path d="M566,206 L656,118" stroke="{green}" stroke-width="58" stroke-linecap="round"/>',
    ]
    return "\n".join(parts)


def group(scale, mono=False):
    # recentre le dessin (boîte englobante ~ x 258..822, y 150..920) puis met à l'échelle
    bx, by = 540, 486
    return (f'<g transform="translate(512,512) scale({scale}) translate({-bx},{-by})">'
            f'{content(mono)}</g>')


GRAD = ('<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        '<stop offset="0" stop-color="#6D6AF8"/><stop offset="1" stop-color="#4338CA"/>'
        '</linearGradient></defs>')


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">{body}</svg>'


files = {
    # icône complète (lanceurs sans icône adaptative, et logo dans l'app)
    "icon.svg": svg(GRAD + '<rect width="1024" height="1024" rx="230" fill="url(#g)"/>' + group(0.82)),
    # icône adaptative Android : fond + premier plan dans la zone sûre (~61 %)
    "background.svg": svg(GRAD + '<rect width="1024" height="1024" fill="url(#g)"/>'),
    "foreground.svg": svg(group(0.60)),
    # icône thématique Android 13+ (silhouette)
    "monochrome.svg": svg(group(0.60, mono=True)),
}
for name, data in files.items():
    (OUT / name).write_text(data)
    cairosvg.svg2png(bytestring=data.encode(), write_to=str(OUT / name.replace(".svg", ".png")),
                     output_width=1024, output_height=1024)
print("ok", sorted(p.name for p in OUT.iterdir()))
