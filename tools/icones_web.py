# Icônes du site (écran d'accueil du téléphone, favicon) : rond rose « PB » sur fond violet.
# python3 tools/icones_web.py  (depuis la racine du dépôt)
from PIL import Image, ImageDraw, ImageFont
import glob

FONT = sorted(glob.glob('app/assets/fonts/Fredoka*'))[0]
BG1, BG2, PINK = (36, 21, 72), (23, 16, 43), (255, 79, 163)

def icon(size, circle):
    im = Image.new('RGB', (size, size))
    d = ImageDraw.Draw(im)
    for y in range(size):  # dégradé du haut vers le bas
        t = y / size
        d.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(BG1, BG2)))
    r = size * circle / 2
    c = size / 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=PINK)
    f = ImageFont.truetype(FONT, round(r * .95))
    try:
        f.set_variation_by_axes([700])
    except Exception:
        pass
    d.text((c, c), 'PB', font=f, fill='white', anchor='mm')
    return im

for s in (192, 512):
    icon(s, .82).save(f'app/web/icons/Icon-{s}.png')
    icon(s, .62).save(f'app/web/icons/Icon-maskable-{s}.png')  # zone sûre des icônes rondes
icon(180, .82).save('app/web/icons/apple-touch-icon.png')
icon(64, .9).save('app/web/favicon.png')
