"""ChatGPT 전투 효과 시트를 게임용 프레임 시트로 바꿉니다.
- 가로로 늘어선 효과 그림을 빈 세로줄 기준으로 나누고, 붙어 있는 프레임은 가장 얇은 곳에서 자릅니다.
- 모든 프레임을 같은 배율로 줄여 256x256 칸 가운데에 놓고 가로로 이어 붙입니다.
- 한 장짜리(작살, 수프)는 그대로 다듬어 한 칸에 넣습니다.
    python3 tools/extract_fx.py
"""
import numpy as np
from PIL import Image
from scipy import ndimage

CELL = 256
# 파일 : (프레임 수, 칸 가로, 칸 세로)
PLAN = {"fx_hit": (4, 256, 256), "fx_crit": (5, 256, 256), "fx_bees": (4, 256, 256), "fx_heal": (5, 256, 256),
        "fx_coin": (4, 256, 256), "fx_harpoon": (1, 512, 256), "fx_soup": (1, 256, 256)}


def frames(alpha, n):
    col = (alpha > 40).sum(0)
    lab, _ = ndimage.label(ndimage.binary_closing(col > 0, iterations=6))
    runs = [[s[0].start, s[0].stop] for s in ndimage.find_objects(lab) if s[0].stop - s[0].start > 40]
    while len(runs) < n:  # 붙은 프레임 나누기: 가장 넓은 구간을 가장 얇은 세로줄에서 자름
        i = max(range(len(runs)), key=lambda k: runs[k][1] - runs[k][0])
        a, b = runs[i]
        m = a + (b - a) // 4 + int(np.argmin(col[a + (b - a) // 4: b - (b - a) // 4]))
        runs[i:i + 1] = [[a, m], [m, b]]
    while len(runs) > n:  # 작은 조각은 옆 프레임에 붙임
        i = min(range(len(runs)), key=lambda k: runs[k][1] - runs[k][0])
        j = i - 1 if i > 0 else i + 1
        runs[min(i, j)] = [min(runs[i][0], runs[j][0]), max(runs[i][1], runs[j][1])]
        del runs[max(i, j)]
    return runs


def main():
    for name, (n, cw, ch) in PLAN.items():
        img = np.array(Image.open(f"art/source/fx/{name}.png").convert("RGBA"))
        a = img[..., 3]
        img[..., 3] = np.where(a < 70, 0, a)  # 뿌연 붉은 테두리 번짐 제거
        pics = []
        for x0, x1 in frames(img[..., 3], n):
            part = img[:, x0:x1]
            ys = np.nonzero(part[..., 3].max(1))[0]
            pics.append(Image.fromarray(part[ys.min(): ys.max() + 1]))
        k = min((cw - 8) / max(p.width for p in pics), (ch - 8) / max(p.height for p in pics))
        sheet = Image.new("RGBA", (cw * n, ch), (0, 0, 0, 0))
        for i, p in enumerate(pics):
            p = p.resize((max(1, round(p.width * k)), max(1, round(p.height * k))), Image.LANCZOS)
            sheet.alpha_composite(p, (i * cw + (cw - p.width) // 2, (ch - p.height) // 2))
        sheet.save(f"assets/fx/{name}.png", optimize=True)
        print(f"assets/fx/{name}.png", sheet.size, n, "프레임")


if __name__ == "__main__":
    main()
