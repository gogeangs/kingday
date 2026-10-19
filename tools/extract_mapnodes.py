"""지도 노드 원본 → 256x256 투명 PNG (받침 바닥을 y=250에 맞춤).

    python3 tools/extract_mapnodes.py art/source/map
원본 이름: mapnode_<region>_<enemy|boss>.png  (region: erdan, dusk, canyon, frost, ash)
"""
import sys, glob, os
import numpy as np
from PIL import Image
os.makedirs("assets/map", exist_ok=True)
for f in sorted(glob.glob(os.path.join(sys.argv[1], "mapnode_*.png"))):
    im = Image.open(f).convert("RGBA"); a = np.array(im)
    a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3]); im = Image.fromarray(a).crop(Image.fromarray(a).getbbox())
    s = min(244 / im.width, 244 / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0)); out.paste(im, ((256 - im.width) // 2, 250 - im.height), im)
    out.save("assets/map/" + os.path.basename(f)[len("mapnode_"):], optimize=True); print(os.path.basename(f), im.size)
