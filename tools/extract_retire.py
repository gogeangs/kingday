"""은퇴 일기 그림(art/source/retire/)을 게임용 크기로 자릅니다.
    python3 tools/extract_retire.py
"""
import numpy as np, imagequant
from PIL import Image
from scipy import ndimage

SRC = "art/source/retire/"


def clean(im):
    a = np.array(im.convert("RGBA"))
    a[..., 3] = np.where(a[..., 3] < 24, 0, a[..., 3])
    return Image.fromarray(a)


def trim(im):
    return im.crop(im.getchannel("A").getbbox())


def main_part(im):
    """칸 안에서 가장 큰 덩어리만 남김 (이웃 칸 장식 조각 제거)"""
    a = np.array(im)
    lab, n = ndimage.label(ndimage.binary_closing(a[..., 3] > 40, iterations=2))
    if n > 1:
        big = 1 + int(np.argmax(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))))
        a[..., 3] = np.where(lab == big, a[..., 3], 0)
    return trim(Image.fromarray(a))


def save(im, path):
    imagequant.quantize_pil_image(im, dithering_level=1.0, max_colors=256).save(path, optimize=True)
    print(path, im.size)


def square(pic, size, pad=0):
    side = max(pic.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(pic, ((side - pic.width) // 2, (side - pic.height) // 2), pic)
    inner = size - pad * 2
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(sq.resize((inner, inner), Image.LANCZOS), (pad, pad))
    return out


def pieces(path, n):
    im = clean(Image.open(path))
    mask = ndimage.binary_closing(np.array(im)[..., 3] > 40, iterations=4)
    lab, _ = ndimage.label(mask)
    boxes = []
    for s in ndimage.find_objects(lab):
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        if (y1 - y0) * (x1 - x0) > 20000:
            boxes.append((x0, y0, x1, y1))
    assert len(boxes) == n, (path, len(boxes))
    h = max(b[3] - b[1] for b in boxes)
    boxes.sort(key=lambda b: (b[1] // (h // 2), b[0]))
    return [trim(im.crop(b)) for b in boxes]


# 배너: 기존 머리 장식(720×208) 안에 맞춤
b = trim(clean(Image.open(SRC + "hd_retire.png")))
sc = min(720 / b.width, 208 / b.height)
r = b.resize((round(b.width * sc), round(b.height * sc)), Image.LANCZOS)
out = Image.new("RGBA", (720, 208), (0, 0, 0, 0))
out.paste(r, ((720 - r.width) // 2, (208 - r.height) // 2), r)
save(out, "assets/ui/hd_retire.png")

# 갈래 문장 3개
for name, p in zip(["sword", "farm", "travel"], pieces(SRC + "trait_branches.png", 3)):
    save(square(p, 256, 2), f"assets/ui/trait_branch_{name}.png")

# 특성 아이콘 18개 (3열 × 2행씩)
SHEETS = {
    "traits_sword": ["sharp", "hat", "critd", "stubborn", "stretch", "climb"],
    "traits_farm": ["soil", "hands", "carpenter", "seedbag", "stew", "bumper"],
    "traits_travel": ["purse", "shortcut", "inn", "knack", "memoir", "goblin"],
}
for sheet, names in SHEETS.items():
    im = clean(Image.open(SRC + sheet + ".png"))
    cw, H = im.width // 3, im.height  # 별 장식이 위아래로 닿아 있어 격자로 자름
    al = np.array(im)[..., 3] > 40
    mid = H * 2 // 5 + int(np.argmin(al[H * 2 // 5: H * 3 // 5].sum(1)))  # 두 줄 사이 가장 비어 있는 높이
    rows = [(0, mid), (mid, H)]
    cells = [main_part(im.crop((c * cw, y0, (c + 1) * cw, y1))) for y0, y1 in rows for c in range(3)]
    for name, p in zip(names, cells):
        save(square(p, 192, 2), f"assets/ui/trait_{name}.png")

# 테두리: frame_tower 와 같은 자리(256×296, 폭 249, 아래 288에 맞춤)
f = trim(clean(Image.open(SRC + "frame_retire.png")))
fr = f.resize((249, round(f.height * 249 / f.width)), Image.LANCZOS)
out = Image.new("RGBA", (256, 296), (0, 0, 0, 0))
out.paste(fr, (4, 288 - fr.height), fr)
save(out, "assets/profile/frame_retire.png")

# 배지
for n in ["badge_retire5", "badge_retire20"]:
    save(square(trim(clean(Image.open(SRC + n + ".png"))), 160, 2), f"assets/profile/{n}.png")
