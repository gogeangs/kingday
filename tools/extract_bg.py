"""ChatGPT 배경 레이어 시트(4줄 합성 이미지)를 게임용 배경 레이어 4장으로 나눕니다.
- 흰 구분선으로 줄을 나눕니다: 하늘 / 먼 풍경 / 중간 풍경 / 바닥
- 하늘을 뺀 3장은 그림에 박힌 체크무늬(회백색 격자)를 위쪽부터 지워 진짜 투명으로 만듭니다.
- 왼쪽 끝과 오른쪽 끝을 섞어서 가로로 반복해도 이음새가 보이지 않게 만듭니다.
    python3 tools/extract_bg.py art/source/erdan_layer_concept_a.png erdan
따로 받은 레이어 4장(<지역>_sky/far/mid/ground.png, 진짜 투명)은 --layers 로 처리합니다:
    python3 tools/extract_bg.py art/source/dusk --layers
위쪽 투명 부분을 잘라 내고 좌우 반복만 맞춥니다.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

NAMES = ["sky", "far", "mid", "ground"]
TRIM = 4           # 구분선 번짐을 없애려고 각 줄 위아래에서 잘라 내는 줄 수
GROUND_KEEP = 0.60  # 바닥 줄에서 위쪽 60%(밀밭과 흙길)만 띠로 쓰고, 아래 큰 울타리는 뺌
BLEND = 0.12  # 반복 이음새를 섞는 폭 (가로 길이 대비)


def strips(rgb):
    white = (rgb.min(-1) > 240).mean(1) > 0.97
    cuts, y = [], 0
    while y < len(white):
        if white[y]:
            s = y
            while y < len(white) and white[y]:
                y += 1
            cuts.append((s, y))
        y += 1
    edges = [0] + [c for run in cuts for c in run] + [len(white)]
    return [(edges[i], edges[i + 1]) for i in range(0, len(edges), 2)]


def key_checker(rgba):
    rgb = rgba[..., :3].astype(int)
    grayish = (rgb.max(-1) - rgb.min(-1) < 14) & (rgb.min(-1) > 190)
    lab, _ = ndimage.label(grayish)
    top_ids = set(np.unique(lab[:3])) - {0}  # 위 가장자리와 이어진 격자만 지움
    bg = np.isin(lab, list(top_ids))
    bg = ndimage.binary_closing(bg, iterations=1)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    # 가장자리 1px 부드럽게
    soft = ndimage.uniform_filter(alpha.astype(float), 3)
    rgba[..., 3] = np.minimum(alpha, soft.astype(np.uint8) + (alpha == 255) * 0).astype(np.uint8)
    rgba[..., 3] = np.where(alpha == 0, 0, np.maximum(soft, 0)).astype(np.uint8)
    return rgba


def make_tileable(rgba):
    h, w, _ = rgba.shape
    b = int(w * BLEND)
    out = rgba[:, : w - b].astype(float).copy()
    tail = rgba[:, w - b:].astype(float)
    head = out[:, :b]
    t = np.linspace(0, 1, b)[None, :, None]
    # 오른쪽 끝(tail)이 왼쪽 시작(head)으로 서서히 넘어가도록 왼쪽 시작 부분에 섞음
    a_t, a_h = tail[..., 3:4] / 255, head[..., 3:4] / 255
    col = (tail[..., :3] * a_t * (1 - t) + head[..., :3] * a_h * t)
    al = a_t * (1 - t) + a_h * t
    rgb = np.where(al > 0, col / np.maximum(al, 1e-6), head[..., :3])
    out[:, :b, :3] = rgb
    out[:, :b, 3:4] = al * 255
    return out.clip(0, 255).astype(np.uint8)


def main(src, region):
    rgb = np.array(Image.open(src).convert("RGB"))
    parts = strips(rgb)
    if len(parts) != 4:
        raise SystemExit(f"줄 {len(parts)}개 (필요 4개)")
    for name, (y0, y1) in zip(NAMES, parts):
        y0, y1 = y0 + TRIM, y1 - TRIM
        if name == "ground":
            y1 = y0 + int((y1 - y0) * GROUND_KEEP)
        rgba = np.dstack([rgb[y0:y1], np.full((y1 - y0, rgb.shape[1]), 255, np.uint8)])
        if name != "sky":
            rgba = key_checker(rgba)
        rgba = make_tileable(rgba)
        if name != "sky":  # 투명 줄의 맨 아래는 다음 레이어에 가려지도록 그대로, 맨 위 1줄은 투명
            rgba[:1, :, 3] = 0
        out = f"assets/bg/{region}_{name}.png"
        Image.fromarray(rgba).save(out, optimize=True)
        print(out, rgba.shape[1], "x", rgba.shape[0])


def layers(prefix):
    region = prefix.rsplit("/", 1)[-1]
    for name in NAMES:
        rgba = np.array(Image.open(f"{prefix}_{name}.png").convert("RGBA"))
        if name != "sky":
            a = rgba[..., 3]
            rgba[..., 3] = np.where(a < 12, 0, a)
            rows = np.nonzero((rgba[..., 3] > 0).mean(1) > 0.002)[0]
            rgba = rgba[max(0, rows.min() - 2):]
        rgba = make_tileable(rgba)
        out = f"assets/bg/{region}_{name}.png"
        Image.fromarray(rgba).save(out, optimize=True)
        print(out, rgba.shape[1], "x", rgba.shape[0])


if __name__ == "__main__":
    if "--layers" in sys.argv:
        layers(sys.argv[1])
    else:
        main(sys.argv[1], sys.argv[2])
