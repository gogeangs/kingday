"""대화 초상화 원본(art/source/portraits/*.png)을 게임용 512x512 투명 PNG로 다듬습니다.
가장자리의 흐린 번짐을 지우고, 그림을 정사각형 칸에 맞춥니다.
    python3 tools/extract_portraits.py
"""
import glob, os
import numpy as np
from PIL import Image

for src in sorted(glob.glob("art/source/portraits/*.png")):
    img = np.array(Image.open(src).convert("RGBA"))
    a = img[..., 3]
    img[..., 3] = np.where(a < 30, 0, a)
    ys, xs = np.nonzero(img[..., 3])
    pic = Image.fromarray(img[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1])
    k = min(500 / pic.width, 500 / pic.height)
    pic = pic.resize((round(pic.width * k), round(pic.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    out.alpha_composite(pic, ((512 - pic.width) // 2, 512 - pic.height))  # 아래쪽(가슴)에 붙임
    dst = "assets/portraits/" + os.path.basename(src)
    out.save(dst, optimize=True)
    print(dst)
