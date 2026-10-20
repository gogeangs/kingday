// 자동 생성 파일 — 직접 고치지 마세요.
// 원본: index.html (웹 버전). 다시 만들기: node tools/parity/gen_dart_data.js
// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars, unnecessary_const

const wSlots = [
  {'k': 'weapon', 'n': '검 장식', 'a': 1, 'h': 0},
  {'k': 'helm', 'n': '모자', 'a': 0, 'h': 1},
  {'k': 'armor', 'n': '작업복', 'a': 0, 'h': 1.6},
  {'k': 'gloves', 'n': '장갑', 'a': 0.6, 'h': 0.3},
  {'k': 'boots', 'n': '장화', 'a': 0.3, 'h': 0.6},
  {'k': 'ring', 'n': '반지', 'a': 0.5, 'h': 0.4},
];

const wGrades = [
  {'n': '일반', 'c': '#b9c0cf', 'm': 1},
  {'n': '고급', 'c': '#6fd17a', 'm': 1.6},
  {'n': '희귀', 'c': '#5aa9ff', 'm': 2.5},
  {'n': '영웅', 'c': '#b77cff', 'm': 4},
  {'n': '전설', 'c': '#ffb03b', 'm': 6.5},
  {'n': '신화', 'c': '#ff5d73', 'm': 11},
];

const wBaseOdds = [70, 22, 6, 1.6, 0.35, 0.05];

const wFrames = ['normal', 'uncommon', 'rare', 'epic', 'legendary', 'mythic'];

const wRelicT = [1, 2, 3];

const wRegions = [
  {
    'n': '에르단 평원',
    'sky': ['#3d5f94', '#9ab8cf'],
    'hill': '#36624a',
    'hill2': '#4f7d55',
    'ground': '#4f7a3a',
    'kind': 'slime',
    'col': '#8fbf4f',
    'mn': '역병 점액',
    'boss': '역병의 군단장 모르바스',
    'terr': ['개울 마을', '풍차 언덕', '밀밭 길', '갈대 강변', '옛 장터', '방앗간', '늪지 초소', '썩은 우물', '양조장 터', '역병의 둥지'],
    'lore': [
      '왕국의 곡창지대였던 평원을 역병의 군단장 모르바스가 차지했다. 그가 지나간 땅은 썩고, 썩은 이슬은 점액이 되어 마을을 덮친다.',
      'k:…밭을 썩게 만든다고? 그건 좀 용서가 안 되는데.',
    ],
  },
  {
    'n': '어스름 숲',
    'sky': ['#1f2448', '#5c4d80'],
    'hill': '#1c362f',
    'hill2': '#2a4a40',
    'ground': '#34502d',
    'kind': 'bat',
    'col': '#9a72d6',
    'mn': '밤그늘 박쥐',
    'boss': '밤의 군단장 세릴',
    'terr': [
      '숲 어귀',
      '이끼 오솔길',
      '버섯 골짜기',
      '꺼진 등불 터',
      '거미 덤불',
      '요정의 샘',
      '고목 다리',
      '달 없는 호수',
      '가시 성채',
      '밤의 둥지',
    ],
    'lore': ['밤의 군단장 세릴이 요정들의 빛을 빼앗아 숲을 영원한 밤에 가뒀다.', 'q:이 숲 어딘가에 아직 빛을 지킨 요정이 살아 있다. 서둘러라, 주인.'],
  },
  {
    'n': '드워프 협곡',
    'sky': ['#6a3a2e', '#d99468'],
    'hill': '#5e4234',
    'hill2': '#83624e',
    'ground': '#7a5c40',
    'kind': 'golem',
    'col': '#9c9ba8',
    'mn': '강철 골렘',
    'boss': '강철의 군단장 그로마크',
    'terr': [
      '협곡 입구',
      '녹슨 레일',
      '광부 쉼터',
      '무너진 갱도',
      '용광로 터',
      '망치 다리',
      '강철 계단',
      '검은 광맥',
      '드워프 성문',
      '강철의 대장간',
    ],
    'lore': ['강철의 군단장 그로마크가 드워프 대장간을 빼앗아 밤낮없이 마족의 무기를 찍어 내고 있다.', 'k:곡괭이질은 괭이질이랑 비슷하겠지? …아마도.'],
  },
  {
    'n': '서리 무덤',
    'sky': ['#14283e', '#4f87ad'],
    'hill': '#36597a',
    'hill2': '#5d88a6',
    'ground': '#c3d9e6',
    'kind': 'ghost',
    'col': '#bfe6ff',
    'mn': '서리 망령',
    'boss': '망령의 군단장 알도르',
    'terr': [
      '얼어붙은 길',
      '기사의 묘비',
      '서리 예배당',
      '눈보라 고개',
      '잠든 막사',
      '얼음 회랑',
      '은빛 깃발 터',
      '망령의 정원',
      '서리 성벽',
      '망령의 무덤',
    ],
    'lore': [
      '은빛 기사단이 잠든 얼음 무덤. 망령의 군단장 알도르가 형제들의 무덤을 지키고 있다.',
      'q@moved:…알도르. 내 두 번째 주인이었던 자다. 주인, 이번만큼은 진지하게 싸워 다오.',
    ],
  },
  {
    'n': '잿불 심연',
    'sky': ['#220b0b', '#922f1a'],
    'hill': '#3a1812',
    'hill2': '#58261a',
    'ground': '#33241f',
    'kind': 'slime',
    'col': '#ff6a3a',
    'mn': '잿불 점액',
    'boss': '화염의 군단장 이그니스',
    'terr': [
      '잿빛 들판',
      '불타는 숲',
      '용암 강',
      '마족 야영지',
      '검은 탑',
      '재의 다리',
      '불꽃 제단',
      '유황 계곡',
      '심연의 계단',
      '마계의 문',
    ],
    'lore': [
      '마계의 문이 열린 곳. 화염의 군단장 이그니스가 문을 지키며 끝없이 증원을 들여보내고 있다.',
      'q:이 문을 닫으면 왕도로 가는 길이 열린다. 왕좌가 코앞이다, 주인!',
      'k:왕좌 말고 은퇴가 코앞이었으면 좋겠는데.',
    ],
  },
];

const wMaxland = 50;

const wBossid = ['morbas', 'seril', 'gromak', 'aldor', 'ignis'];

const wComp = {
  'kael': {'n': '카엘', 'role': '농부 용사', 'desc': '은퇴만 꿈꾸는 농부. 성검 루미나르를 뽑아 버렸다.'},
  'bron': {
    'n': '브론',
    'role': '광부 · 방어',
    'desc': '드워프 광부. 곡괭이를 들고 앞줄에서 공격을 받아낸다.',
    'join': '드워프 협곡에서 합류',
    'base': {'atk': 6, 'hp': 240, 'aps': 0.8},
    'per': {'atk': 2, 'hp': 48},
  },
  'haral': {
    'n': '하랄',
    'role': '어부 · 원거리',
    'desc': '허풍쟁이 늙은 어부. 작살을 던져 멀리서 공격한다.',
    'join': '갈대 강변에서 합류',
    'base': {'atk': 11, 'hp': 90, 'aps': 0.9},
    'per': {'atk': 3.4, 'hp': 18},
  },
  'riel': {
    'n': '리엘',
    'role': '양봉가 · 광역',
    'desc': '400살 요정 양봉가. 벌 떼로 모든 적을 공격한다.',
    'join': '어스름 숲에서 합류',
    'base': {'atk': 9, 'hp': 70, 'aps': 0.7},
    'per': {'atk': 3.2, 'hp': 14},
  },
  'margo': {
    'n': '마고',
    'role': '요리사 · 회복',
    'desc': '식당 아주머니. 수프를 던져 가장 다친 동료를 치유한다.',
    'join': '풍차 언덕에서 합류',
    'base': {'atk': 4, 'hp': 95, 'aps': 0.8},
    'per': {'atk': 1.5, 'hp': 19},
  },
  'gordon': {
    'n': '고든',
    'role': '광부 · 방어',
    'desc': '무너진 성벽을 혼자 다시 쌓는 과묵한 거구의 석공. 맞으면 맞을수록 정 망치로 되받아친다.',
    'join': '동료 카드 30장을 모으면 합류',
    'base': {'atk': 7, 'hp': 225, 'aps': 0.75},
    'per': {'atk': 2.2, 'hp': 45},
  },
  'daisy': {
    'n': '데이지',
    'role': '양봉가 · 광역',
    'desc': '어스름 숲 어귀에서 꽃밭을 가꾸는 명랑한 정원사 소녀. 리엘의 벌들과 친구다. 꽃가루 씨앗을 뿌려 모든 적을 중독시킨다.',
    'join': '동료 카드 30장을 모으면 합류',
    'base': {'atk': 8, 'hp': 74, 'aps': 0.8},
    'per': {'atk': 2.9, 'hp': 15},
  },
  'brida': {
    'n': '브리다',
    'role': '광부 · 방어',
    'desc': '300살 드워프 대장장이 여왕이자 브론의 할머니. 산맥을 통째로 깎아 성을 지었다는 전설의 주인공. 거대한 모루 망치로 마물을 내리친다.',
    'join': '동료 카드 30장을 모으면 합류',
    'base': {'atk': 9, 'hp': 300, 'aps': 0.75},
    'per': {'atk': 2.6, 'hp': 60},
  },
  'nella': {
    'n': '넬라',
    'role': '어부 · 원거리',
    'desc': '갈대 강변의 씩씩한 그물 어부 소녀. 하랄을 "할배"라 부르며 따라다닌다. 그물을 던져 마물을 느리게 만든다.',
    'join': '동료 카드 30장을 모으면 합류',
    'base': {'atk': 9, 'hp': 96, 'aps': 1},
    'per': {'atk': 3, 'hp': 19},
  },
  'luka': {
    'n': '루카',
    'role': '요리사 · 회복',
    'desc': '새벽마다 빵을 굽는 수줍은 제빵사. 카엘의 밀로 빵을 굽는 게 꿈이다. 갓 구운 빵을 던져 동료를 치유한다.',
    'join': '동료 카드 30장을 모으면 합류',
    'base': {'atk': 5, 'hp': 82, 'aps': 0.9},
    'per': {'atk': 1.7, 'hp': 16},
  },
};

const wJob = {
  'bron': 'miner',
  'haral': 'fisher',
  'riel': 'keeper',
  'margo': 'cook',
  'luka': 'cook',
  'nella': 'fisher',
  'brida': 'miner',
  'daisy': 'keeper',
  'gordon': 'miner',
};

const wJobn = {'miner': '광부', 'fisher': '어부', 'keeper': '양봉가', 'cook': '요리사'};

const wJslot = ['miner', 'kael', 'fisher', 'keeper', 'cook'];

const wStory = {'miner': 'bron', 'fisher': 'haral', 'keeper': 'riel', 'cook': 'margo'};

const wOrder = ['bron', 'kael', 'haral', 'riel', 'margo'];

const wHeight = {
  'kael': 66,
  'bron': 54,
  'haral': 66,
  'riel': 66,
  'margo': 64,
  'luka': 66,
  'nella': 62,
  'brida': 56,
  'daisy': 62,
  'gordon': 60,
};

const wRecruits = {
  'luka': {
    'job': 'cook',
    'title': '제빵사 루카',
    'lines': [
      'm:루카|저, 저기… 카엘 씨 밭의 밀로 빵을 구워 보고 싶어서 따라왔어요.',
      'k@surprised:내 밀로? …은퇴하면 빵집 옆에 밭 하나 더 일궈야겠네.',
      'q@proud:흥, 또 식객이 늘었군. 뭐, 빵 냄새는 나쁘지 않다.',
      'sys:원정대 탭의 요리사 자리에서 마고 대신 출전시킬 수 있어요.',
    ],
    'ok': '잘 부탁해, 루카',
  },
  'gordon': {
    'job': 'miner',
    'title': '석공 고든',
    'lines': [
      '무너진 성벽 앞에서 거구의 사내가 묵묵히 돌을 쌓고 있었다. 마물이 덤비자, 정 망치 한 번에 날려 버렸다.',
      'm:고든|…성벽은 다시 쌓으면 된다. 사람은 다시 못 쌓지.',
      'm:브론|말수 적은 놈이 마음에 드는군. 같이 가자.',
      'k@smile:든든하다… 은퇴하면 우리 집 담장도 부탁해도 될까?',
      'sys:원정대 탭의 광부 자리에서 브론 대신 출전시킬 수 있어요.',
    ],
    'ok': '잘 부탁해, 고든',
  },
  'daisy': {
    'job': 'keeper',
    'title': '정원사 데이지',
    'lines': [
      'm:데이지|안녕! 리엘 언니 벌들이 우리 꽃밭에 놀러 오거든. 그래서 따라와 봤어!',
      'm:리엘|이 아이 꽃밭 꿀이 제일 달아. 400년 동안 먹어 본 것 중에.',
      'k@smile:꽃밭이라… 은퇴하면 우리 밭 옆에도 좀 심어 줄래?',
      'sys:원정대 탭의 양봉가 자리에서 리엘 대신 출전시킬 수 있어요.',
    ],
    'ok': '환영해, 데이지',
  },
  'brida': {
    'job': 'miner',
    'title': '전설의 대장장이 여왕 브리다',
    'lines': [
      '협곡이 울렸다. 바위 문이 열리고, 은빛 수염을 땋은 늙은 드워프가 모루 망치를 끌며 걸어 나왔다.',
      'm:브리다|브론! 이 할미를 두고 원정을 떠나? 망치질 삼백 년, 아직 손목은 멀쩡하다.',
      'm:브론|…할머니. 갱도에 계시라고 했잖아요.',
      'q@moved:브리다 여왕… 내가 첫 주인을 모시던 시절에 이미 전설이었지.',
      'k@surprised:성검이 존댓말 쓰는 거 처음 봐.',
      'sys:전설 등급 동료! 원정대 탭의 광부 자리에서 출전시킬 수 있어요.',
      'sys:마을 스킬 「여왕의 대장간」: 광산 광석 생산 +50%. 출전하지 않아도 늘 적용되고, 별이 오를수록 강해져요(★5에서 +100%).',
    ],
    'ok': '모시겠습니다, 여왕님',
  },
  'nella': {
    'job': 'fisher',
    'title': '그물 어부 넬라',
    'lines': [
      'm:넬라|하랄 할배! 또 혼자 허풍 떨면서 다니지? 이번엔 나도 같이 간다!',
      'm:하랄@laugh|허허, 이 녀석 그물 솜씨는 나보다 낫지. 고래만 빼고.',
      'k@flustered:…원정대가 점점 마을 잔치가 되어 가네.',
      'sys:원정대 탭의 어부 자리에서 하랄 대신 출전시킬 수 있어요.',
    ],
    'ok': '잘 부탁해, 넬라',
  },
};

const wStarNeed = [30, 20, 40, 80, 150];

const wStarMul = [1, 1, 1.2, 1.4, 1.6, 2];

const wGrade = {
  'bron': 'common',
  'haral': 'common',
  'riel': 'common',
  'margo': 'common',
  'luka': 'epic',
  'nella': 'epic',
  'brida': 'legend',
  'daisy': 'rare',
  'gordon': 'common',
};

const wGr = {
  'common': {
    'n': '일반',
    'c': '#b8c0cc',
    'max': 3,
    'mul': 1,
    'w': 55,
    'need': [0, 15, 30],
    'fr': 'normal',
  },
  'rare': {
    'n': '희귀',
    'c': '#5aa8ff',
    'max': 4,
    'mul': 1.1,
    'w': 30,
    'need': [30, 20, 40, 80],
    'fr': 'rare',
  },
  'epic': {
    'n': '영웅',
    'c': '#b07bff',
    'max': 5,
    'mul': 1.2,
    'w': 12,
    'need': [30, 30, 60, 120, 200],
    'fr': 'epic',
  },
  'legend': {
    'n': '전설',
    'c': '#ffc23a',
    'max': 5,
    'mul': 1.35,
    'w': 3,
    'need': [30, 40, 80, 160, 300],
    'fr': 'legendary',
  },
};

const wVpas = {'brida': {'n': '여왕의 대장간'}};

const wSkills = {
  'kael': {
    'n': '추수의 일격',
    'd': '밀을 베듯 성검을 크게 휘둘러 모든 적에게 공격력 3배 피해',
    'line': '올해 추수는 이걸로 끝이다!',
    'need': 20,
    'face': 'smile',
  },
  'bron': {
    'n': '갱도 버팀목',
    'd': '5초 동안 원정대가 받는 피해 50% 감소',
    'line': '갱도는 내가 받친다.',
    'need': 22,
    'face': 'laugh',
  },
  'haral': {
    'n': '고래잡이 작살',
    'd': '모든 적을 꿰뚫는 거대 작살, 공격력 3배 (보스에게 2배)',
    'line': '이건 내가 잡은 고래보다 작군!',
    'need': 20,
    'face': 'laugh',
  },
  'riel': {
    'n': '벌통 엎기',
    'd': '6초 동안 모든 적에게 지속 피해, 적의 공격이 느려짐',
    'line': '붕붕이들, 가자!',
    'need': 22,
    'face': 'laugh',
  },
  'margo': {
    'n': '가마솥 한 그릇',
    'd': '원정대 체력 30% 회복, 8초 동안 공격력 20% 증가',
    'line': '다들 한 그릇씩 먹고 힘내!',
    'need': 20,
    'face': 'laugh',
  },
  'gordon': {
    'n': '성벽 쌓기',
    'd': '앞의 적에게 공격력 2.5배 피해, 2초 기절. 6초 동안 맞을 때마다 반드시 되받아침 (★3에서 강화)',
    'line': '…쌓는다.',
    'need': 20,
    'face': 'laugh',
  },
  'daisy': {
    'n': '꽃가루 폭풍',
    'd': '모든 적을 8초 동안 중독시켜 0.5초마다 공격력 40% 피해 (★3·★5에서 강화)',
    'line': '에취! 다들 꽃가루 조심해~!',
    'need': 20,
    'face': 'laugh',
  },
  'brida': {
    'n': '산맥의 수호',
    'd': '6초 동안 원정대가 받는 피해 70% 감소, 막은 피해의 절반을 되돌려 줌 (★3·★5에서 강화)',
    'line': '이 산맥은 삼백 년 동안 무너진 적이 없다!',
    'need': 24,
    'face': 'laugh',
  },
  'nella': {
    'n': '만선의 그물',
    'd': '모든 적에게 공격력 2배 피해, 4초 동안 묶어서 공격을 못 하게 함 (보스는 2초, ★3·★5에서 강화)',
    'line': '다 걸렸다! 오늘은 만선이야!',
    'need': 20,
    'face': 'laugh',
  },
  'luka': {
    'n': '아침 빵 배달',
    'd': '원정대 체력 20% 회복, 8초 동안 공격 속도 30% 증가 (★3·★5에서 강화)',
    'line': '가, 갓 구운 빵 왔어요!',
    'need': 18,
    'face': 'laugh',
  },
};

const wBal = {
  'hpG': 1.2,
  'atkG': 1.17,
  'goldG': 1.16,
  'boxG': 1.17,
  'bossHp': 6,
  'lordHp': 12,
  'bossAtk': 2.5,
  'lordAtk': 3,
};

const wCompGrow = 1.1;

const wBless = 0.2;

const wEnMax = 20;

const wCw = {'bron': '곡괭이', 'haral': '작살', 'riel': '벌통', 'margo': '국자'};

const wCwMax = 20;

const wUpg = [
  {'k': 'atk', 'n': '검 휘두르기', 'max': 99999},
  {'k': 'hp', 'n': '밭일 체력', 'max': 99999},
  {'k': 'spd', 'n': '빠른 손놀림', 'max': 40},
  {'k': 'crit', 'n': '급소 찌르기', 'max': 55},
];

const wCrops = [
  {'k': 'wheat', 'n': '밀', 't': 60, 'c': '#e8c35a', 'sell': 2, 'drop': 0.15},
  {'k': 'carrot', 'n': '은빛 당근', 't': 300, 'c': '#cfe0f0', 'sell': 12, 'drop': 0.045},
  {'k': 'pumpkin', 'n': '달빛 호박', 't': 1200, 'c': '#ffa94a', 'sell': 60, 'drop': 0.012},
];

const wGoods = [
  {'k': 'fish', 'n': '생선', 'c': '#7fb7e0', 'sell': 8, 'b': 'dock'},
  {'k': 'honey', 'n': '꿀', 'c': '#f2b630', 'sell': 10, 'b': 'apiary'},
  {'k': 'ore', 'n': '광석', 'c': '#a9a9b8', 'sell': 14, 'b': 'mine'},
];

const wRecipes = [
  {
    'k': 'bread',
    'n': '마르타의 밀빵',
    'need': {'wheat': 5},
    'buff': 'atk',
    'desc': '원정대 공격력 +20%',
  },
  {
    'k': 'stew',
    'n': '생선 당근 스튜',
    'need': {'carrot': 2, 'fish': 2},
    'buff': 'spd',
    'desc': '원정대 공격 속도 +20%',
  },
  {
    'k': 'pie',
    'n': '꿀 호박 파이',
    'need': {'pumpkin': 2, 'honey': 2},
    'buff': 'gold',
    'desc': '획득 골드 +50%',
  },
  {
    'k': 'grill',
    'n': '드워프 돌판 구이',
    'need': {'ore': 3, 'wheat': 2},
    'buff': 'crit',
    'desc': '원정대 치명타 +10%',
  },
];

const wBuffn = {'atk': '공격력', 'spd': '공속', 'gold': '골드', 'crit': '치명타'};

const wBld = [
  {'k': 'inn', 'n': '여관', 'who': '', 'max': 10, 'base': 150, 'lock': ''},
  {'k': 'farm', 'n': '밭', 'who': '카엘', 'max': 6, 'base': 120, 'lock': '개울 마을을 되찾으면 열려요'},
  {'k': 'diner', 'n': '식당', 'who': '마고', 'max': 10, 'base': 220, 'lock': '마고가 합류하면 열려요'},
  {'k': 'dock', 'n': '낚시터', 'who': '하랄', 'max': 10, 'base': 350, 'lock': '하랄이 합류하면 열려요'},
  {'k': 'apiary', 'n': '양봉장', 'who': '리엘', 'max': 10, 'base': 600, 'lock': '리엘이 합류하면 열려요'},
  {'k': 'mine', 'n': '광산', 'who': '브론', 'max': 10, 'base': 2000, 'lock': '브론이 합류하면 열려요'},
];

const wBqMax = 2;

const wTutGem = 10;

const wGemPlots = [50, 100, 150, 200];

const wRanks = [
  {'at': 0, 'n': '농부'},
  {'at': 3, 'n': '마을 지킴이', 'k': '지킴이라니… 그냥 이웃 돕는 거예요.'},
  {'at': 10, 'n': '기사', 'k': '기사 아니고 농부라니까요…'},
  {'at': 20, 'n': '영주', 'k': '영주요? 세금 계산 같은 거 못 하는데.'},
  {'at': 30, 'n': '백작', 'k': '백작… 은퇴가 점점 멀어진다.'},
  {'at': 40, 'n': '공작', 'k': '다음은 설마… 아니겠지.'},
  {'at': 50, 'n': '왕도 진격대장', 'k': '왕도만 되찾으면 정말 은퇴한다.'},
];

const wEvents = [
  {
    'at': 2,
    'id': 'marta',
    'eb': '새로운 주민',
    't': '농부 마르타',
    'p': [
      '개울 마을을 되찾자, 이웃집 마르타 할머니가 가장 먼저 돌아왔다.',
      'm:마르타|용사? 웃기지 마라. 밭일이나 거들어. 씨앗 가져오면 밭은 내가 봐 주마.',
      'k:…네. 사실 그게 제일 하고 싶은 일이에요.',
      'sys:마을에 밭이 열렸어요. 마물이 떨어뜨리는 씨앗을 심어 보세요. 밀 씨앗 5개를 받았어요.',
    ],
    'btn': '밭으로 간다',
  },
  {
    'at': 3,
    'id': 'margo',
    'eb': '동료 합류',
    't': '요리사 마고',
    'p': [
      '풍차 언덕 식당 주방에서, 국자 하나로 마물을 막아 내던 아주머니가 있었다.',
      'm:마고@laugh|배고픈 원정대는 못 이겨. 상처엔 수프가 최고야. 대신 그 밭 작물, 나한테 먼저 팔아.',
      'sys:마고가 합류했어요. 수프를 던져 가장 다친 동료를 치유해요. 마을에 식당을 열 수 있어요.',
    ],
    'btn': '함께 간다',
  },
  {
    'at': 5,
    'id': 'toby',
    'eb': '새로운 주민',
    't': '꼬마 토비',
    'p': [
      '마을에 아이들이 돌아오기 시작했다. 그중 한 꼬마가 나무 막대를 들고 카엘을 졸졸 따라다녔다.',
      'm:토비|형이 그 성검 용사죠?! 저도 커서 형처럼 마물 무찌를 거예요!',
      'k@flustered:형은 농부야. 너도 커서 농부 해. 농부는 마물이랑 안 싸워도 돼.',
      'm:토비|에이, 농부는 멋없어요!',
      'q@proud:훌륭한 안목을 가진 아이로군.',
    ],
    'btn': '…농부도 멋있는데',
  },
  {
    'at': 7,
    'id': 'haral',
    'eb': '동료 합류',
    't': '어부 하랄',
    'p': [
      '갈대 강변, 마물에게 둘러싸인 낡은 배 위에서 작살을 든 노인이 버티고 있었다.',
      'm:하랄@laugh|이 정도는 별것 아니야. 내가 젊을 때 잡은 고래는 말이지…',
      'q:주인, 저 이야기 길어질 것 같다. 일단 데려가자.',
      'sys:하랄이 합류했어요. 작살을 던져 멀리서 공격해요. 마을에 낚시터를 열 수 있어요.',
    ],
    'btn': '함께 간다',
  },
  {
    'at': 11,
    'id': 'riel',
    'eb': '동료 합류',
    't': '양봉가 리엘',
    'p': [
      '모르바스가 쓰러지자 숲 어귀로 벌 떼가 몰려들었다. 그 한가운데, 꽃 모자를 쓴 요정이 앉아 있었다.',
      'm:리엘|우리 벌들이 네 밭의 꽃을 좋아하더라. 같이 가 줄게. 아, 저 애 이름은 붕붕이 3호야.',
      'sys:리엘이 합류했어요. 벌 떼로 모든 적을 공격해요. 마을에 양봉장을 열 수 있어요.',
    ],
    'btn': '함께 간다',
  },
  {
    'at': 21,
    'id': 'bron',
    'eb': '동료 합류',
    't': '광부 브론',
    'p': [
      '협곡 입구의 무너진 갱도에서 곡괭이 소리가 들려왔다. 백 년 동안 갱도를 지킨 드워프였다.',
      'm:브론|…이 바위 좋군. 앞은 내가 막지.',
      'sys:브론이 합류했어요. 앞줄에서 적의 공격을 대신 받아내요. 마을에 광산을 열 수 있어요.',
    ],
    'btn': '함께 간다',
  },
  {
    'at': 21,
    'id': 'toby2',
    'eb': '영주님 만세',
    't': '토비의 깃발',
    'p': [
      '토비가 "카엘 영주님 만세" 깃발을 만들어 마을 입구에 걸었다.',
      'm:토비|형, 아니 영주님! 저 제자로 받아 주세요!',
      'k:…제자면 밭부터 매자.',
      'm:토비|…그것도 수련이에요?',
      'q:수련이다. 아마도.',
    ],
    'btn': '괭이를 건넨다',
  },
];

const wQuips = [
  ['k', '이번 영지만 되찾고 은퇴할 거야.'],
  ['k', '여긴 흙이 좋네…'],
  ['k', '농부입니다. 용사 아니고요.'],
  ['k', '빨리 끝내고 밭에 물 줘야 해.'],
  ['k', '호박이 잘 자라고 있으려나.'],
  ['q', '주인, 자세가 그게 뭐냐!'],
  ['q', '나는 성검이다. 괭이가 아니야!'],
  ['q', '왕이 될 상이다. 확실하다.'],
  ['q', '300년 기다린 보람이… 있겠지.'],
  ['q', '방금 그 베기, 나쁘지 않았다.'],
];

const wMissions = [
  {'k': 'kill', 'n': '마물 100마리 처치', 'goal': 100, 'r': 10},
  {'k': 'box', 'n': '성유물 상자 10번 열기', 'goal': 10, 'r': 10},
  {'k': 'harv', 'n': '작물 10개 수확', 'goal': 10, 'r': 10},
];

const wMisAll = 20;

const wRankGem = 30;

const wLordGem = 50;

const wAds = {
  'card': {'n': 1, 't': '동료 카드 3장'},
  'box': {'n': 3, 't': '성유물 상자 1회 무료'},
  'gem': {'n': 3, 't': '황금 이삭 +5'},
  'farm': {'n': 2, 't': '자라는 작물 바로 키우기'},
  'offline': {'n': 2, 't': '방치 보상 2배'},
};

const wPacks = [
  {'k': 'p1', 'gem': 60, 'won': 1200},
  {'k': 'p2', 'gem': 330, 'won': 5500},
  {'k': 'p3', 'gem': 680, 'won': 11000},
  {'k': 'p4', 'gem': 1280, 'won': 22000},
  {'k': 'p5', 'gem': 3280, 'won': 55000},
  {'k': 'p6', 'gem': 6480, 'won': 99000},
];

const wSub = {'k': 'sub', 'n': '피트의 정기 배송', 'won': 5500, 'now': 300, 'day': 100, 'days': 30};

const wStarter = {'k': 'starter', 'n': '첫 거래 특가', 'won': 1200, 'gem': 100};

const wCardpk = [{'n': 3, 'gem': 30}, {'n': 30, 'gem': 270}];

const wGoldx = [
  {'k': 'g1', 'n': '골드 주머니', 'gem': 30, 'h': 2},
  {'k': 'g2', 'n': '골드 자루', 'gem': 100, 'h': 8},
  {'k': 'g3', 'n': '골드 금고', 'gem': 250, 'h': 24},
];

const wGem10 = 100;

const wGemPlot = 5;

const wGemOffline = 20;

const wLumq = [
  '흥, 내 격에는 한참 못 미친다.',
  '그럭저럭… 봐줄 만하군.',
  '오호, 제법이다!',
  '이건 왕의 물건이다. 당장 걸쳐라!',
  '300년 만에 보는 물건이군…!',
  '신화… 주인, 이건 운명이다.',
];

const wSaveKey = 'acorn-idle-v1';

const wSprites = {
  'kael': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 70},
  'bron': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 74},
  'haral': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 72},
  'riel': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 76},
  'margo': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 72},
  'luka': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 72},
  'nella': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 68},
  'brida': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 74},
  'daisy': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 70},
  'gordon': {'idle': 4, 'walk': 6, 'attack': 4, 'hit': 2, 'h': 74},
};

const wSprConst = {'frame': 256, 'foot': 250, 'fig': 171};

const wMonSprites = {
  '0': {
    'id': 'slime_plague',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 54,
    'boss': {'id': 'boss_morbas', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 200, 'h': 76},
  },
  '1': {
    'id': 'bat_shadow',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 180,
    'h': 44,
    'lift': 30,
    'boss': {'id': 'boss_seril', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 195, 'h': 72},
  },
  '2': {
    'id': 'golem_steel',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 190,
    'h': 58,
    'boss': {'id': 'boss_gromak', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 200, 'h': 74},
  },
  '3': {
    'id': 'wraith_frost',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 185,
    'h': 50,
    'lift': 18,
    'boss': {'id': 'boss_aldor', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 195, 'h': 74},
  },
  '4': {
    'id': 'slime_ash',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 52,
    'boss': {'id': 'boss_ignis', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 200, 'h': 78},
  },
};

const wMonAlt = {
  '0': {
    'id': 'scarecrow_cursed',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 46,
    'trait': 'tank',
  },
  '1': {
    'id': 'wolf_shadow',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 40,
    'trait': 'swift',
  },
  '2': {
    'id': 'goblin_pick',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 40,
    'trait': 'swarm',
  },
  '3': {
    'id': 'skeleton_frost',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 46,
    'trait': 'guard',
  },
  '4': {
    'id': 'imp_flame',
    'walk': 4,
    'attack': 4,
    'hit': 2,
    'fig': 150,
    'h': 40,
    'lift': 26,
    'trait': 'flier',
  },
};

const wTraits = {
  'tank': {'hp': 1.6, 'atk': 0.9, 'mv': 0.6, 'cd': 1.15, 'n': '단단함'},
  'swift': {'hp': 0.7, 'atk': 1.1, 'mv': 1.7, 'cd': 0.8, 'n': '빠름'},
  'swarm': {'hp': 0.55, 'atk': 0.6, 'mv': 1.2, 'cd': 1, 'n': '떼'},
  'guard': {'hp': 1.4, 'atk': 0.85, 'mv': 0.8, 'cd': 1.1, 'n': '방패'},
  'flier': {'hp': 0.8, 'atk': 1.05, 'mv': 1.5, 'cd': 0.9, 'n': '비행'},
};

const wGob = {'id': 'goblin_gold', 'walk': 4, 'attack': 4, 'hit': 2, 'fig': 150, 'h': 46};

const wFxdef = {
  'hit': 4,
  'crit': 5,
  'bees': 4,
  'heal': 5,
  'coin': 4,
  'harpoon': 1,
  'soup': 1,
  'skill_kael': 4,
  'skill_bron': 4,
  'skill_haral': 4,
  'skill_riel': 4,
  'skill_margo': 4,
  'skill_luka': 4,
  'skill_nella': 4,
  'skill_brida': 4,
  'skill_daisy': 4,
  'skill_gordon': 4,
};

const wForm = {
  'kael': [0.46, 0.34],
  'bron': [0.58, 0.72],
  'haral': [0.31, 1],
  'riel': [0.17, 0.16],
  'margo': [0.1, 0.58],
  'luka': [0.1, 0.58],
  'nella': [0.31, 1],
  'brida': [0.58, 0.72],
  'daisy': [0.17, 0.16],
  'gordon': [0.58, 0.72],
};

const wGobRare = {'badge': 0.005, 'frame': 0.002};

const wBgImg = {'0': 'erdan', '1': 'dusk', '2': 'canyon', '3': 'frost', '4': 'ash'};

const wBgFull = {'dusk': true, 'canyon': true, 'frost': true, 'ash': true};

const wDeco = ['windmill', 'trees', 'spires', 'graves', 'volcano'];

