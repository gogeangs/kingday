"""마을 에셋 정리: 배경 → 1536x512 JPG, 건물 → 512x512 투명 PNG(바닥 정렬).

    python3 tools/extract_village.py art/source/village
건물 원본 이름: building_<key>_<ruin|built>.png  (key: inn, farm, diner, dock, apiary, mine)
"""
import sys, glob, os
import numpy as np
from PIL import Image

src = sys.argv[1]
os.makedirs("assets/village", exist_ok=True)
bg = os.path.join(src, "village_bg.png")
if os.path.exists(bg):
    im = Image.open(bg).convert("RGB")
    w, h = im.size
    if w / h > 3:  # 가로가 넓으면 양옆을 잘라 3:1
        nw = h * 3; im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = w // 3; im = im.crop((0, h - nh, w, h))
    im.resize((1536, 512), Image.LANCZOS).save("assets/village/village_bg.jpg", quality=85, optimize=True)
    print("village_bg.jpg")
for f in sorted(glob.glob(os.path.join(src, "building_*.png"))):
    im = Image.open(f).convert("RGBA")
    a = np.array(im)
    a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3])
    im = Image.fromarray(a)
    x0, y0, x1, y1 = im.getbbox()
    im = im.crop((x0, y0, x1, y1))
    s = min(492 / im.width, 492 / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.paste(im, ((512 - im.width) // 2, 506 - im.height), im)
    name = os.path.basename(f)[len("building_"):]
    out.save(f"assets/village/{name}", optimize=True)
    print(name, im.size)
