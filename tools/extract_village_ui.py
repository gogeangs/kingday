"""마을 확장 아이콘·배지·테두리(art/source/village/)를 게임용 크기로 자릅니다.
    python3 tools/extract_village_ui.py
"""
import numpy as np, imagequant
from PIL import Image
from scipy import ndimage

S = "art/source/village/"


def clean(im):
    a = np.array(im.convert("RGBA")); a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3]); return Image.fromarray(a)


def trim(im): return im.crop(im.getchannel("A").getbbox())


def main_part(im):
    a = np.array(im)
    lab, n = ndimage.label(ndimage.binary_closing(a[..., 3] > 40, iterations=2))
    if n > 1:
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        keep = [i + 1 for i, v in enumerate(sizes) if v >= sizes.max() * 0.02]  # 큰 덩어리 + 붙은 장식은 남기고 이웃 조각 제거
        a[..., 3] = np.where(np.isin(lab, keep) | (a[..., 3] < 41), a[..., 3], 0)
        big = 1 + int(np.argmax(sizes))
        far = ~ndimage.binary_dilation(lab == big, iterations=60)
        a[..., 3] = np.where(far, 0, a[..., 3])
    return trim(Image.fromarray(a))


def square(p, size, pad=2):
    side = max(p.size); sq = Image.new("RGBA", (side, side), (0, 0, 0, 0)); sq.paste(p, ((side - p.width) // 2, (side - p.height) // 2), p)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0)); out.paste(sq.resize((size - pad * 2,) * 2, Image.LANCZOS), (pad, pad)); return out


def save(im, path):
    imagequant.quantize_pil_image(im, dithering_level=1.0, max_colors=256).save(path, optimize=True); print(path, im.size)


def grid(path, cols, rows):
    im = clean(Image.open(path)); cw, ch = im.width // cols, im.height // rows
    return [main_part(im.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))) for r in range(rows) for c in range(cols)]


for (name, size), p in zip([("item_egg", 128), ("item_milk", 128), ("dish_soup", 160), ("dish_pancake", 160)], grid(S + "items_new.png", 2, 2)):
    save(square(p, size), f"assets/ui/{name}.png")
for name, p in zip(["buff_hp", "buff_sk"], grid(S + "buffs_new.png", 2, 1)):
    save(square(p, 256), f"assets/ui/{name}.png")
for name, p in zip(["gold", "brave", "work", "earth", "luck"], grid(S + "bless.png", 5, 1)):
    save(square(p, 256), f"assets/ui/bless_{name}.png")
save(square(trim(clean(Image.open(S + "badge_village.png"))), 160), "assets/profile/badge_village.png")
f = trim(clean(Image.open(S + "frame_village.png"))); fr = f.resize((249, round(f.height * 249 / f.width)), Image.LANCZOS)
out = Image.new("RGBA", (256, 296), (0, 0, 0, 0)); out.paste(fr, (4, 288 - fr.height), fr); save(out, "assets/profile/frame_village.png")
