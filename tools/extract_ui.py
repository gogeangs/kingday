"""ui_icons_concept.png (ChatGPT UI 시트, 진짜 투명 배경)에서 개별 UI 아이콘을 잘라 냅니다.
아이콘 아래에 그려진 한글 라벨은 잘라 내고, 정사각형 투명 PNG로 저장합니다.
    python3 tools/extract_ui.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

SRC = "art/source/ui_icons_concept.png"
# 조각 번호(위→아래, 왼→오른 순) : (저장 이름, 위에서부터 남길 비율, 출력 크기)
PLAN = {
    0: ("logo", 1.0, 512),
    3: ("tab_equipment", .66, 128), 2: ("tab_party", .66, 128), 4: ("tab_training", .66, 128),
    5: ("tab_village", .66, 128), 6: ("tab_map", .66, 128),
    9: ("slot_weapon", .80, 128), 10: ("slot_hat", .80, 128), 11: ("slot_armor", .80, 128),
    12: ("slot_gloves", .80, 128), 13: ("slot_boots", .80, 128), 14: ("slot_ring", .80, 128),
    15: ("frame_normal", .80, 128), 16: ("frame_uncommon", .80, 128), 17: ("frame_rare", .80, 128),
    18: ("frame_epic", .80, 128), 19: ("frame_legendary", .82, 128), 20: ("frame_mythic", .84, 128),
    22: ("relic_chest", .74, 160), 23: ("item_wheat", .74, 128), 24: ("item_carrot", .74, 128),
    25: ("item_pumpkin", .74, 128), 26: ("item_fish", .74, 128), 27: ("item_honey", .74, 128),
    28: ("item_ore", .74, 128),
}

img = np.array(Image.open(SRC).convert("RGBA"))
mask = ndimage.binary_closing(img[..., 3] > 200, iterations=3)
lab, _ = ndimage.label(mask)
boxes = []
for s in ndimage.find_objects(lab):
    y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
    if (y1 - y0) * (x1 - x0) > 3000:
        boxes.append((x0, y0, x1, y1))
boxes.sort(key=lambda b: (b[1] // 60, b[0]))

for i, (name, keep, size) in PLAN.items():
    x0, y0, x1, y1 = boxes[i]
    y1 = y0 + round((y1 - y0) * keep)
    if name.startswith("tab_"):  # 탭 아이콘은 좌우 장식을 덜어 내고 가운데 그림만
        w = x1 - x0
        x0, x1 = x0 + round(w * .17), x1 - round(w * .17)
    crop = img[y0:y1, x0:x1].copy()
    a = crop[..., 3]
    crop[..., 3] = np.where(a < 24, 0, a)
    ys, xs = np.nonzero(crop[..., 3])
    crop = crop[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]
    pic = Image.fromarray(crop)
    side = max(pic.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(pic, ((side - pic.width) // 2, (side - pic.height) // 2), pic)
    if name == "logo":
        out = pic.resize((size, round(pic.height * size / pic.width)), Image.LANCZOS)
    else:
        out = sq.resize((size, size), Image.LANCZOS)
    out.save(f"assets/ui/{name}.png", optimize=True)
    print(name, out.size)


# ---------- 전투 UI (ChatGPT가 잘라 준 개별 PNG를 규격 크기로 다듬기) ----------
BATTLE = {"ui_gold": 256, "ui_boss_mark": 256, "buff_atk": 256, "buff_spd": 256, "buff_gold": 256, "banner_capture": (1024, 256)}


def tidy(name, size):
    img = np.array(Image.open(f"art/source/{name}.png").convert("RGBA"))
    a = img[..., 3]
    img[..., 3] = np.where(a < 24, 0, a)
    lab, n = ndimage.label(ndimage.binary_dilation(img[..., 3] > 0, iterations=4))
    if n > 1:  # 가장 큰 덩어리만 남김 (옆 그림에서 넘어온 조각 제거)
        big = 1 + int(np.argmax(ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))))
        img[..., 3] = np.where(lab == big, img[..., 3], 0)
    ys, xs = np.nonzero(img[..., 3])
    pic = Image.fromarray(img[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1])
    W, H = (size, size) if isinstance(size, int) else size
    k = min((W - 8) / pic.width, (H - 8) / pic.height)
    pic = pic.resize((round(pic.width * k), round(pic.height * k)), Image.LANCZOS)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(pic, ((W - pic.width) // 2, (H - pic.height) // 2))
    out.save(f"assets/ui/{name}.png", optimize=True)
    print(name, out.size)


for k, v in BATTLE.items():
    tidy(k, v)
