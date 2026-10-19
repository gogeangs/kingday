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
    # 몬스터 (1줄 이동 4 / 2줄 공격 4 / 3줄 피격 2, 왼쪽을 봄)
    python3 tools/extract_sprites.py art/source/slime_plague_motion.png slime_plague --monster
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
MON_ROWS = [("walk", 4), ("attack", 4), ("hit", 2)]
MON_SCALE = 0.62


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


def own_mask(loose_lab, box):
    """이 프레임 상자 안에 중심이 있는 조각만 남기는 마스크 (옆 프레임에서 넘어온 작살 끝 등을 지움)."""
    x0, y0, x1, y1 = box
    keep = np.zeros(loose_lab.shape, bool)
    for lab_id, sl in enumerate(ndimage.find_objects(loose_lab), start=1):
        if sl is None:
            continue
        cy = (sl[0].start + sl[0].stop) / 2
        cx = (sl[1].start + sl[1].stop) / 2
        if x0 <= cx <= x1 and y0 <= cy <= y1:
            keep[sl] |= loose_lab[sl] == lab_id
    return keep


def main(src, cid, monster=False):
    rows_def = MON_ROWS if monster else ROWS
    scale = MON_SCALE if monster else SCALE
    outdir = "assets/monsters" if monster else "assets/characters"
    img = np.array(Image.open(src).convert("RGBA"))
    alpha = img[..., 3]
    loose_lab, _ = ndimage.label(ndimage.binary_dilation(alpha >= ALPHA_CUT, iterations=2))
    rows = group_rows(blobs(alpha), len(rows_def))
    for (name, n), row in zip(rows_def, rows):
        big = max((b[2] - b[0]) * (b[3] - b[1]) for b in row)
        if len(row) <= n:  # 불씨 같은 작은 조각은 프레임으로 세지 않음 (붙은 프레임을 나누기 전에)
            row = [b for b in row if (b[2] - b[0]) * (b[3] - b[1]) > big * 0.2]
        row = merge_to(row, n)
        while len(row) < n:  # 이펙트로 붙은 프레임: 가장 넓은 조각을 가장 얇은 세로줄에서 나눔
            i = max(range(len(row)), key=lambda k: row[k][2] - row[k][0])
            x0, y0, x1, y1 = row[i]
            col = (alpha[y0:y1, x0:x1] > 200).sum(0)
            q = (x1 - x0) // 4
            m = x0 + q + int(np.argmin(col[q: (x1 - x0) - q]))
            row[i:i + 1] = [[x0, y0, m, y1, 1], [m, y0, x1, y1, 1]]  # 5번째 값 1 = 나눈 프레임
        if len(row) != n:
            raise SystemExit(f"{name}: 프레임 {len(row)}개 (필요 {n}개)")
        sheet = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
        for i, box in enumerate(row):
            x0, y0, x1, y1 = box[:4]
            was_split = len(box) > 4
            hx = head_x(alpha, (x0, y0, x1, y1))
            mine = np.ones_like(alpha, bool) if was_split else own_mask(loose_lab, (x0, y0, x1, y1))
            inside = alpha[y0:y1, x0:x1] > 200
            if inside.sum() and (inside & mine[y0:y1, x0:x1]).sum() < inside.sum() * 0.5:
                mine = np.ones_like(alpha, bool)  # 옆 프레임과 붙어 있어 자기 그림까지 지워지면 정리를 건너뜀
            px = 0 if was_split else 6
            crop = img[max(0, y0 - 6): y1 + 4, max(0, x0 - px): x1 + px].copy()
            a = crop[..., 3]
            m = mine[max(0, y0 - 6): y1 + 4, max(0, x0 - px): x1 + px]
            crop[..., 3] = np.where((a < ALPHA_CUT) | ~m, 0, a)
            pic = Image.fromarray(crop)
            pic = pic.resize((max(1, round(pic.width * scale)), max(1, round(pic.height * scale))), Image.LANCZOS)
            ox = i * FRAME + round(FRAME / 2 - (hx - max(0, x0 - px)) * scale)
            oy = FOOT_Y - round((y1 - max(0, y0 - 6)) * scale)
            frame = Image.new("RGBA", (FRAME * n, FRAME), (0, 0, 0, 0))
            frame.paste(pic, (ox, oy), pic)
            # 다른 프레임 칸으로 넘친 부분은 잘라 냄
            cell = frame.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME))
            sheet.alpha_composite(cell, (i * FRAME, 0))
        out = f"{outdir}/{cid}_{name}.png"
        sheet.save(out, optimize=True)
        print(out, sheet.size)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], "--monster" in sys.argv[3:])
