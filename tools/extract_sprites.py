"""콘셉트 동작 시트에서 게임용 스프라이트 시트를 뽑아 내는 도구.

입력 시트 규칙 (kael_motion_concept.png와 같은 형식)
- 진짜 투명 배경 PNG
- 1줄 대기 4 / 2줄 걷기 6 / 3줄 공격 4 / 4줄 피격 2, 오른쪽을 보는 측면

출력
- assets/characters/<id>_idle.png   1024x256  (256x256 프레임 4개)
- assets/characters/<id>_walk.png   1536x256  (6개)
- assets/characters/<id>_attack.png 1024x256  (4개)
- assets/characters/<id>_hit.png     512x256  (2개)
- 모든 프레임의 발끝은 y=250, 머리 중심은 x=128 에 맞춥니다.

사용법
    python3 tools/extract_sprites.py art/source/kael_motion_concept.png kael
    python3 tools/extract_sprites.py art/source/bron_motion_concept.png bron
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

FRAME = 256
FOOT_Y = 250          # 프레임 안에서 발끝이 닿는 높이
SCALE = 0.795         # 원본 시트 → 게임 프레임 배율 (모든 캐릭터 공통, 상대 크기 유지)
ALPHA_CUT = 140       # 이보다 흐린 픽셀(콘셉트의 뿌연 후광)은 지움
ROWS = [("idle", 4), ("walk", 6), ("attack", 4), ("hit", 2)]


def blobs(alpha):
    mask = ndimage.binary_closing(alpha > 200, iterations=3)
    lab, _ = ndimage.label(mask)
    out = []
    for s in ndimage.find_objects(lab):
        y0, y1, x0, x1 = s[0].start, s[0].stop, s[1].start, s[1].stop
        if (y1 - y0) * (x1 - x0) > 3000:
            out.append([x0, y0, x1, y1])
    return out


def group_rows(boxes, n_rows):
    """세로 위치로 줄을 나눕니다."""
    boxes.sort(key=lambda b: (b[1] + b[3]) / 2)
    cy = np.array([(b[1] + b[3]) / 2 for b in boxes])
    gaps = np.argsort(np.diff(cy))[::-1][: n_rows - 1]
    cuts = sorted(gaps + 1)
    rows, start = [], 0
    for c in cuts + [len(boxes)]:
        rows.append(sorted(boxes[start:c], key=lambda b: b[0]))
        start = c
    return rows


def merge_to(row, want):
    """가로로 겹치거나 가장 가까운 조각을 합쳐 프레임 수를 맞춥니다 (떨어진 공격 이펙트 등)."""
    row = [list(b) for b in row]
    while len(row) > want:
        best, bi = None, 0
        for i in range(len(row) - 1):
            gap = row[i + 1][0] - row[i][2]
            if best is None or gap < best:
                best, bi = gap, i
        a, b = row[bi], row[bi + 1]
        row[bi] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3])]
        del row[bi + 1]
    return row


def head_x(alpha, box):
    """머리 부분(위쪽 35%)의 무게중심 x. 칼이나 이펙트 길이와 상관없이 몸이 흔들리지 않게 맞추는 기준."""
    x0, y0, x1, y1 = box
    a = alpha[y0:y1, x0:x1] > 200
    top = a[: max(1, int((y1 - y0) * 0.35))]
    xs = np.nonzero(top)[1]
    return x0 + (xs.mean() if len(xs) else (x1 - x0) / 2)


def main(src, cid):
    img = np.array(Image.open(src).convert("RGBA"))
    alpha = img[..., 3]
    rows = group_rows(blobs(alpha), len(ROWS))
    for (name, n), row in zip(ROWS, rows):
        row = merge_to(row, n)
        if len(row) != n:
            raise SystemExit(f"{name}: 프레임 {len(row)}개 (필요 {n}개)")
        sheet = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
        for i, (x0, y0, x1, y1) in enumerate(row):
            hx = head_x(alpha, (x0, y0, x1, y1))
            crop = img[max(0, y0 - 6): y1 + 4, max(0, x0 - 6): x1 + 6].copy()
            a = crop[..., 3]
            crop[..., 3] = np.where(a < ALPHA_CUT, 0, a)
            pic = Image.fromarray(crop)
            pic = pic.resize((max(1, round(pic.width * SCALE)), max(1, round(pic.height * SCALE))), Image.LANCZOS)
            ox = i * FRAME + round(FRAME / 2 - (hx - max(0, x0 - 6)) * SCALE)
            oy = FOOT_Y - round((y1 - max(0, y0 - 6)) * SCALE)
            frame = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
            frame.paste(pic, (ox, oy), pic)
            # 다른 프레임 칸으로 넘친 부분은 잘라 냄
            cell = frame.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
            sheet.alpha_composite(cell, (i * FRAME, 0))
        out = f"assets/characters/{cid}_{name}.png"
        sheet.save(out, optimize=True)
        print(out, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
