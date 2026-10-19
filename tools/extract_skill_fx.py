"""스킬 효과 시트(4프레임 가로 한 줄) → 게임용 프레임 시트.
    python3 tools/extract_skill_fx.py
리엘·마고는 한 장에 두 줄(위 리엘, 아래 마고)로 들어온 것을 나눕니다.
"""
import numpy as np
from PIL import Image
from scipy import ndimage

def load(path):
    a = np.array(Image.open(path).convert("RGBA")); a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3]); return a

def split_cols(a, n):
    col = (a[..., 3] > 40).sum(0)
    lab, _ = ndimage.label(ndimage.binary_closing(col > 0, iterations=4))
    runs = sorted([[s[0].start, s[0].stop] for s in ndimage.find_objects(lab) if s[0].stop - s[0].start > 60])
    while len(runs) > n:  # 가장 가까운 두 구간 합치기
        i = min(range(len(runs) - 1), key=lambda k: runs[k + 1][0] - runs[k][1]); runs[i:i + 2] = [[runs[i][0], runs[i + 1][1]]]
    while len(runs) < n:
        i = max(range(len(runs)), key=lambda k: runs[k][1] - runs[k][0]); a0, b0 = runs[i]
        m = a0 + (b0 - a0) // 4 + int(np.argmin(col[a0 + (b0 - a0) // 4: b0 - (b0 - a0) // 4])); runs[i:i + 1] = [[a0, m], [m, b0]]
    return runs

def build(a, name, cw, ch, bottom=False):
    runs = split_cols(a, 4); crops = []
    for x0, x1 in runs:
        c = a[:, x0:x1]; ys = np.nonzero(c[..., 3].any(1))[0]; crops.append(c[ys.min():ys.max() + 1])
    k = min(min((cw - 8) / c.shape[1], (ch - 8) / c.shape[0]) for c in crops)
    sheet = Image.new("RGBA", (cw * 4, ch), (0, 0, 0, 0))
    for i, c in enumerate(crops):
        im = Image.fromarray(c); im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        y = ch - 4 - im.height if bottom else (ch - im.height) // 2
        sheet.alpha_composite(im, (i * cw + (cw - im.width) // 2, y))
    sheet.save(f"assets/fx/{name}.png", optimize=True); print(name, sheet.size, [r[1] - r[0] for r in runs])

build(load("art/source/fx/fx_skill_kael.png"), "fx_skill_kael", 384, 256)
build(load("art/source/fx/fx_skill_bron.png"), "fx_skill_bron", 256, 256, bottom=True)
build(load("art/source/fx/fx_skill_haral.png"), "fx_skill_haral", 512, 192)
rm = load("art/source/fx/fx_skill_riel_margo.png"); H = rm.shape[0]
row = (rm[..., 3] > 40).sum(1); mid = H // 3 + int(np.argmin(row[H // 3: 2 * H // 3]))
build(rm[:mid], "fx_skill_riel", 384, 256)
build(rm[mid:], "fx_skill_margo", 256, 288, bottom=True)
build(load("art/source/fx/fx_skill_luka.png"), "fx_skill_luka", 256, 288, bottom=True)
build(load("art/source/fx/fx_skill_nella.png"), "fx_skill_nella", 384, 256)
build(load("art/source/fx/fx_skill_brida.png"), "fx_skill_brida", 320, 256, bottom=True)
