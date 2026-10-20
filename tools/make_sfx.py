#!/usr/bin/env python3
"""효과음 만들기 — 외부 음원 없이 파이썬으로 직접 합성한다 (저작권 걱정 없음).

    python3 tools/make_sfx.py   → app/assets/audio/sfx_*.wav

나중에 전문 효과음으로 바꾸려면 같은 이름의 파일만 바꿔 넣으면 된다.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'app', 'assets', 'audio')


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, a=0.005, r=None, curve=4.0):
    """빠르게 올라가 지수로 줄어드는 소리 크기"""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dur = n / SR
    dec = np.exp(-curve * x / (r or dur))
    return att * dec


def tone(f, sec, kind='sine', curve=4.0, a=0.004):
    x = t(sec)
    ph = 2 * np.pi * f * x
    if kind == 'sine':
        w = np.sin(ph)
    elif kind == 'square':
        w = np.sign(np.sin(ph)) * .55
    elif kind == 'tri':
        w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == 'bell':  # 금속 종소리: 배음이 정수배가 아님
        w = np.sin(ph) + .5 * np.sin(ph * 2.76) * np.exp(-6 * x) + .25 * np.sin(ph * 5.4) * np.exp(-9 * x)
    else:
        raise ValueError(kind)
    return w * env(len(x), a=a, curve=curve)


def noise(sec, curve=6.0, lp=0.0):
    n = np.random.default_rng(7).standard_normal(int(SR * sec))
    if lp > 0:  # 아주 단순한 저역 통과
        for _ in range(int(lp)):
            n = (n + np.roll(n, 1)) / 2
    return n * env(len(n), curve=curve)


def seq(parts):
    """(시작 초, 소리) 목록을 겹쳐 하나로"""
    end = max(s + len(p) / SR for s, p in parts)
    out = np.zeros(int(SR * end) + 1)
    for s, p in parts:
        i = int(SR * s)
        out[i:i + len(p)] += p
    return out


def note(n):
    """음 이름 → 주파수 (A4=440)"""
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    k = names[n[0]] + (1 if '#' in n else 0)
    o = int(n[-1])
    return 440 * 2 ** ((k + (o - 4) * 12) / 12)


def save(name, x, vol=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * vol
    # 끝을 부드럽게
    fade = min(len(x), int(SR * .01))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    p = os.path.join(OUT, f'sfx_{name}.wav')
    with wave.open(p, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f'{p}  {len(data) / SR:.2f}s  {os.path.getsize(p) // 1024}KB')


def main():
    # 버튼 누름: 짧은 나무 똑
    save('tap', tone(1400, .05, 'tri', curve=12), vol=.35)
    # 골드: 동전 두 번
    save('coin', seq([(0, tone(note('B5'), .09, 'bell', 8)), (.07, tone(note('E6'), .25, 'bell', 6))]), vol=.5)
    # 상자 열기: 쉭 + 반짝
    save('box', seq([(0, noise(.18, curve=5, lp=2) * .5), (.08, tone(note('G5'), .2, 'bell', 6)), (.14, tone(note('D6'), .3, 'bell', 5))]), vol=.6)
    # 장착: 칼 뽑는 쇳소리
    sh = seq([(0, noise(.25, curve=7) * np.sin(2 * np.pi * 3200 * t(.25)) * .6), (0, tone(2100, .3, 'bell', 7))])
    save('equip', sh, vol=.5)
    # 단련: 올라가는 세 음
    save('up', seq([(0, tone(note('C5'), .08, 'square', 9)), (.06, tone(note('E5'), .08, 'square', 9)), (.12, tone(note('G5'), .16, 'square', 7))]), vol=.35)
    # 영지 탈환: 짧은 팡파르
    fan = [(0, 'C5', .12), (.12, 'E5', .12), (.24, 'G5', .12), (.36, 'C6', .45)]
    save('clear', seq([(s, tone(note(n), d, 'square', 5) + .5 * tone(note(n) / 2, d, 'tri', 5)) for s, n, d in fan]), vol=.4)
    # 칭호 상승: 조금 더 긴 팡파르
    fan2 = [(0, 'G4', .14), (.14, 'C5', .14), (.28, 'E5', .14), (.42, 'G5', .2), (.62, 'E5', .12), (.74, 'G5', .5)]
    save('fanfare', seq([(s, tone(note(n), d, 'square', 4) + .5 * tone(note(n) / 2, d, 'tri', 4)) for s, n, d in fan2]), vol=.4)
    # 보스 등장: 낮은 북 + 울림
    drum = lambda f: tone(f, .5, 'sine', 6) * (1 + .3 * noise(.5, curve=10, lp=4))
    save('boss', seq([(0, drum(70)), (.28, drum(60)), (.56, tone(55, 1.0, 'tri', 3))]), vol=.8)
    # 특수 스킬: 휙 올라가는 소리 + 반짝
    x = t(.35)
    sweep = np.sin(2 * np.pi * (300 + 2400 * x / .35) * x) * env(len(x), curve=3)
    save('skill', seq([(0, sweep * .6), (.2, tone(note('A6'), .3, 'bell', 6))]), vol=.45)
    # 황금 고블린 전리품: 동전 우르르
    rng = np.random.default_rng(3)
    save('goblin', seq([(i * .06 + rng.random() * .02, tone(note(rng.choice(['C6', 'E6', 'G6', 'B5', 'D6'])), .2, 'bell', 8)) for i in range(9)]), vol=.5)
    # 황금 이삭·우편 보상: 맑은 종 두 번
    save('gem', seq([(0, tone(note('E6'), .3, 'bell', 5)), (.1, tone(note('B6'), .45, 'bell', 4))]), vol=.45)


if __name__ == '__main__':
    main()
