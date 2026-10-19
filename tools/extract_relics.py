"""성유물 아이콘 원본 → 256x256 투명 PNG (가운데 정렬).

    python3 tools/extract_relics.py art/source/relic
원본 이름: relic_<slot>_<tier>.png  (slot: weapon, helm, armor, gloves, boots, ring / tier: 1 기본, 2 정예, 3 전설)
"""
import sys, glob, os
import numpy as np
from PIL import Image
from scipy import ndimage
os.makedirs("assets/relic", exist_ok=True)
for f in sorted(glob.glob(os.path.join(sys.argv[1], "relic_*.png"))):
    a = np.array(Image.open(f).convert("RGBA"))
    a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3])
    lab, n = ndimage.label(ndimage.binary_dilation(a[..., 3] > 24, iterations=2))
    if n > 1:  # 큰 덩어리의 0.5% 미만인 부스러기는 지움
        sz = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1)); keep = np.isin(lab, np.nonzero(sz >= sz.max() * .005)[0] + 1)
        a[..., 3] = np.where(keep, a[..., 3], 0)
    im = Image.fromarray(a); im = im.crop(im.getbbox())
    s = min(236 / im.width, 236 / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0)); out.paste(im, ((256 - im.width) // 2, (256 - im.height) // 2), im)
    out.save("assets/relic/" + os.path.basename(f), optimize=True); print(os.path.basename(f), im.size)
