"""Front-view anatomy figure, one SVG per body system with that system lit."""
import sys, os
OUT = sys.argv[1]

# The body is built from symmetric shapes. They are drawn twice: first with a
# wide edge-coloured stroke, then filled on top, so only the outer edge shows.
TORSO = 'M33 54c8-5 18-7 27-7s19 2 27 7l3 28c0 22-4 44-8 60l2 8c-7 6-15 9-24 9s-17-3-24-9l2-8c-4-16-8-38-8-60z'
LIMBS = ['M37 60L29 78 23 128', 'M83 60L91 78 97 128', 'M51 148L49 198 49 242', 'M69 148L71 198 71 242']

def body():
    edge, fill = '#D9CBC6', '#F6EFEC'
    layers = []
    for colour, extra in ((edge, 3), (fill, 0)):
        layers.append(f'<ellipse cx="60" cy="23" rx="{13 + extra / 2}" ry="{15 + extra / 2}" fill="{colour}"/>')
        layers.append(f'<rect x="{54 - extra / 2}" y="34" width="{12 + extra}" height="16" rx="4" fill="{colour}"/>')
        for d in LIMBS[:2]:
            layers.append(f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{11 + extra}" stroke-linecap="round" stroke-linejoin="round"/>')
        for d in LIMBS[2:]:
            layers.append(f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{15 + extra}" stroke-linecap="round" stroke-linejoin="round"/>')
        layers.append(f'<path d="{TORSO}" fill="{colour}" stroke="{colour}" stroke-width="{extra or 0.01}" stroke-linejoin="round"/>')
    return ''.join(layers)

# name: list of (kind, attrs) drawn in the figure; organs never overlap the outline
ORGANS = {
  'thyroid': [('path', 'M53 42c0-3 3-4 5-2l2 2 2-2c2-2 5-1 5 2s-2 6-5 6l-2-1-2 1c-3 0-5-3-5-6z')],
  'lungs': [('path', 'M57 62c-6 0-14 4-15 14l-1 20c0 4 3 6 7 5l9-3z'),
            ('path', 'M63 62c6 0 14 4 15 14l1 20c0 4-3 6-7 5l-9-3z')],
  'heart': [('path', 'M60 76c-2-4-9-4-10 1-1 5 4 10 11 15 6-5 11-10 10-15-1-5-8-5-11-1z')],
  'liver': [('path', 'M40 101c0-4 4-6 9-6h17c4 0 5 3 3 6-4 5-12 11-22 12-5 1-7-3-7-12z')],
  'stomach': [('path', 'M68 100c5-2 11 0 11 6 0 7-6 12-13 12-3 0-4-2-2-4 3-2 4-5 3-8z')],
  'pancreas': [('path', 'M48 120c6-3 16-3 24-2 4 1 4 4 0 5-8 2-17 2-24 1-3 0-3-3 0-4z')],
  'kidneys': [('path', 'M44 124c0-5 6-7 8-3 1 2-1 4 0 6s3 4 1 7c-3 3-9 1-9-10z'),
              ('path', 'M76 124c0-5-6-7-8-3-1 2 1 4 0 6s-3 4-1 7c3 3 9 1 9-10z')],
  'bladder': [('path', 'M53 148c0-4 3-6 7-6s7 2 7 6-3 8-7 8-7-4-7-8z'),
              ('path', 'M50 134l5 10M70 134l-5 10', 'line')],
  'vessels': [('path', 'M60 52V144M60 60C50 58 41 58 37 62L29 79 24 124M60 60C70 58 79 58 83 62L91 79 96 124M60 144L51 150 49 198 49 236M60 144L69 150 71 198 71 236', 'line')],
  'bones': [('path', 'M60 50V140M44 57H76M37 62L29 79 24 124M83 62L91 79 96 124M51 152L49 198 49 236M69 152L71 198 71 236', 'line'),
            ('path', 'M45 138c5-5 25-5 30 0l-3 10H48z')],
}

SYSTEMS = {
  'kidneys': ['kidneys'], 'urine': ['kidneys', 'bladder'], 'liver': ['liver'],
  'heart': ['heart', 'vessels'], 'blood': ['vessels'], 'sugar': ['pancreas'],
  'thyroid': ['thyroid'], 'vitamins': ['bones'], 'salts': ['vessels', 'kidneys'],
  'lungs': ['lungs'], 'general': [],
}

def draw(lit):
    out = [body()]
    order = ['vessels', 'bones', 'lungs', 'heart', 'liver', 'stomach', 'pancreas', 'kidneys', 'bladder', 'thyroid']
    for name in order:
        on = name in lit
        for item in ORGANS[name]:
            d = item[1]
            if len(item) > 2:  # a line drawing
                colour = '#8B1A1A' if on else '#E2D2CD'
                out.append(f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{2.2 if on else 1.4}" stroke-linecap="round" stroke-linejoin="round"/>')
            else:
                fill, stroke = ('#C2524C', '#8B1A1A') if on else ('#EDE1DD', '#DCCAC4')
                out.append(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{1.4 if on else 1}" stroke-linejoin="round"/>')
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 252" width="120" height="252">'
            + ''.join(out) + '</svg>\n')

os.makedirs(OUT, exist_ok=True)
for system, lit in SYSTEMS.items():
    open(os.path.join(OUT, f'anatomy-{system}.svg'), 'w').write(draw(lit))
print('wrote', len(SYSTEMS))
