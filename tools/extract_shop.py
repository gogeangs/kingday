"""상점·패스 그림(art/source/shop/)을 게임용으로 자르고, 시즌 테두리 색 6가지를 만듭니다.
    python3 tools/extract_shop.py
"""
import numpy as np, imagequant, colorsys
from PIL import Image

S = "art/source/shop/"


def clean(im):
    a = np.array(im.convert("RGBA")); a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3]); return Image.fromarray(a)


def trim(im): return im.crop(im.getchannel("A").getbbox())


def save(im, path):
    imagequant.quantize_pil_image(im, dithering_level=1.0, max_colors=256).save(path, optimize=True); print(path, im.size)


# 배너 720×208
b = trim(clean(Image.open(S + "hd_pass.png"))); sc = min(720 / b.width, 208 / b.height)
r = b.resize((round(b.width * sc), round(b.height * sc)), Image.LANCZOS)
out = Image.new("RGBA", (720, 208), (0, 0, 0, 0)); out.paste(r, ((720 - r.width) // 2, (208 - r.height) // 2), r); save(out, "assets/ui/hd_pass.png")

# 성장 패키지 256
p = trim(clean(Image.open(S + "pack_growth.png"))); side = max(p.size)
sq = Image.new("RGBA", (side, side), (0, 0, 0, 0)); sq.paste(p, ((side - p.width) // 2, (side - p.height) // 2), p)
save(sq.resize((256, 256), Image.LANCZOS), "assets/ui/pack_growth.png")

# 시즌 테두리: 파란 부분(색조 190~250°)만 색을 바꿔 6가지 → frame_pass_0..5 (0 = 원래 파랑)
f = trim(clean(Image.open(S + "frame_pass.png"))); fr = f.resize((249, round(f.height * 249 / f.width)), Image.LANCZOS)
base = Image.new("RGBA", (256, 296), (0, 0, 0, 0)); base.paste(fr, (4, 288 - fr.height), fr)
a = np.array(base).astype(float) / 255
rgb = a[..., :3]; mx = rgb.max(-1); mn = rgb.min(-1); d = mx - mn + 1e-9
h = np.where(mx == rgb[..., 0], ((rgb[..., 1] - rgb[..., 2]) / d) % 6, np.where(mx == rgb[..., 1], (rgb[..., 2] - rgb[..., 0]) / d + 2, (rgb[..., 0] - rgb[..., 1]) / d + 4)) * 60
sat = np.where(mx > 0, d / (mx + 1e-9), 0)
blue = (h > 185) & (h < 255) & (sat > 0.25)
TARGET = [None, 0, 135, 280, 30, 175]  # 파랑(원래) · 빨강 · 초록 · 보라 · 주황 · 청록
for i, t in enumerate(TARGET):
    o = a.copy()
    if t is not None:
        ys, xs = np.nonzero(blue)
        for y, x in zip(ys, xs):
            hh, ll, ss = colorsys.rgb_to_hls(*o[y, x, :3])
            nh = (hh * 360 + (t - 222)) % 360 / 360
            o[y, x, :3] = colorsys.hls_to_rgb(nh, ll, ss)
    save(Image.fromarray((o * 255).astype("uint8")), f"assets/profile/frame_pass_{i}.png")
