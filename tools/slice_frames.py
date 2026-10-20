"""프레임끼리 빛무리로 붙어 있는 동작 시트용 자르기 도구.
줄 사이는 그림을 피해 가는 경계선(seam)으로, 줄 안은 주어진 x 위치로 잘라 게임 시트를 만듭니다.
    python3 tools/slice_frames.py art/source/daisy_motion.png daisy
"""
import sys, numpy as np
from PIL import Image
CUTS = {"daisy": {"bands": [(235, 285), (465, 515), (680, 740)],
                  "rows": [("idle", [42, 294, 566, 844, 1115], 320), ("walk", [25, 307, 590, 884, 1167, 1455, 1739], 320),
                           ("attack", [34, 323, 793, 1418, 1751], 640), ("hit", [58, 335, 686], 384)]},
        "gordon": {"bands": [(220, 250), (455, 490), (680, 705)],
                   "rows": [("idle", [40, 300, 600, 890, 1160], 256), ("walk", [20, 312, 606, 896, 1175, 1464, 1774], 320),
                            ("attack", [20, 368, 865, 1384, 1774], 640), ("hit", [40, 340, 660], 320)]},
        # 덕배: 공격 1프레임의 치켜든 국자가 윗줄에 닿아 자동 줄 나누기가 안 됨
        "deokbae": {"bands": [(225, 265), (470, 510), (715, 760)], "scale": 0.808,
                    "rows": [("idle", [108, 341, 638, 945, 1198], 256), ("walk", [43, 273, 547, 814, 1095, 1378, 1602], 256),
                             ("attack", [76, 391, 812, 1180, 1521], 384), ("hit", [42, 311, 595], 256)]},
        # 베릴: 줄 사이가 붙어 있고 공격 3프레임에 수정 파편이 넓게 퍼져 자동 나누기가 안 됨
        "beryl": {"bands": [(232, 255), (475, 499), (718, 742)],
                  "rows": [("idle", [428, 624, 831, 1033, 1229], 256), ("walk", [36, 285, 546, 820, 1087, 1366, 1615], 256),
                           ("attack", [166, 475, 808, 1268, 1473], 384), ("hit", [558, 819, 1081], 256)]}}
SCALE, FOOT, FR = 0.795, 250, 256


def seam(A, ya, yb):
    """ya~yb 사이에서 그림(불투명 픽셀)을 가장 적게 지나는 가로 경계선. x마다 y를 돌려줌."""
    c = (A[ya:yb] > 60).astype(float).T  # (W, h)
    W, h = c.shape; cost = c.copy(); back = np.zeros((W, h), int)
    for x in range(1, W):
        p = cost[x - 1]; cand = np.stack([np.r_[np.inf, p[:-1]], p, np.r_[p[1:], np.inf]])
        k = cand.argmin(0); cost[x] += cand.min(0); back[x] = np.arange(h) + k - 1
    y = np.zeros(W, int); y[-1] = cost[-1].argmin()
    for x in range(W - 1, 0, -1): y[x - 1] = back[x][y[x]]
    return y + ya


src, cid = sys.argv[1], sys.argv[2]; cfg = CUTS[cid]
SCALE = cfg.get("scale", SCALE)
arr = np.array(Image.open(src).convert("RGBA")); A = arr[..., 3]; H, W = A.shape
lines = [np.zeros(W, int)] + [seam(A, a, b) for a, b in cfg["bands"]] + [np.full(W, H)]
yy = np.arange(H)[:, None]
for r, (name, b, cw) in enumerate(cfg["rows"]):
    band = (yy >= lines[r][None, :]) & (yy < lines[r + 1][None, :])
    sheet = Image.new("RGBA", (cw * (len(b) - 1), FR))
    for i in range(len(b) - 1):
        keep = band.copy(); keep[:, :b[i]] = False; keep[:, b[i + 1]:] = False; keep &= A >= 140
        ys, xs = np.nonzero(keep); pc = arr.copy(); pc[..., 3] = np.where(keep, A, 0)
        top = keep[ys.min(): ys.min() + int((ys.max() - ys.min()) * .45)]; hx = np.nonzero(top)[1].mean()
        pic = Image.fromarray(pc).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        pic = pic.resize((round(pic.width * SCALE), round(pic.height * SCALE)), Image.LANCZOS)
        cell = Image.new("RGBA", (cw, FR)); cell.alpha_composite(pic, (round(cw / 2 - (hx - xs.min()) * SCALE), FOOT - pic.height))
        sheet.alpha_composite(cell, (i * cw, 0))
    sheet.save(f"assets/characters/{cid}_{name}.png", optimize=True); print(name, sheet.size)
