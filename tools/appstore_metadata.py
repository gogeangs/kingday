"""App Store 글·스크린샷 올리기 (App Store Connect API) — GitHub Actions 「appstore-metadata」에서 실행.

편집 중인 iOS 버전(제출 준비 중)에 fastlane/metadata 의 글과 fastlane/screenshots/ko 의 6.9인치 스크린샷을 넣는다.
빌드 선택·심사 제출은 하지 않는다. 키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.

    python3 tools/appstore_metadata.py 0.0.4
"""
import glob
import hashlib
import json
import os
import sys
import time

import jwt
import requests

BUNDLE = 'kr.co.project30s.kingday'
API = 'https://api.appstoreconnect.apple.com/v1'
LOCALE = 'ko'
MD = 'fastlane/metadata'
SHOTS = sorted(glob.glob('fastlane/screenshots/ko/*.png'))
DISPLAY = 'APP_IPHONE_67'  # 6.9인치(1320×2868)는 API 에서 IPHONE_67 칸으로 들어감


def token():
    now = int(time.time())
    return jwt.encode({'iss': os.environ['APPSTORE_ISSUER_ID'], 'iat': now, 'exp': now + 1100, 'aud': 'appstoreconnect-v1'},
                      os.environ['APPSTORE_KEY_P8'], algorithm='ES256', headers={'kid': os.environ['APPSTORE_KEY_ID'], 'typ': 'JWT'})


S = requests.Session()


def call(method, path, body=None, params=None):
    url = path if path.startswith('http') else API + path
    r = S.request(method, url, json=body, params=params, headers={'Authorization': 'Bearer ' + token()})
    if r.status_code >= 400:
        print(f'::error::{method} {path} → {r.status_code} {r.text[:800]}')
        r.raise_for_status()
    return r.json() if r.text else {}


def read(name):
    p = os.path.join(MD, LOCALE, name)
    return open(p, encoding='utf-8').read().strip() if os.path.exists(p) else None


def main(version):
    app = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]
    aid = app['id']
    print('앱', aid, app['attributes']['name'])

    vs = call('GET', f'/apps/{aid}/appStoreVersions', params={'filter[platform]': 'IOS', 'limit': 20})['data']
    for v in vs:
        print('버전', v['id'], v['attributes']['versionString'], v['attributes']['appStoreState'])
    edit = [v for v in vs if v['attributes']['appStoreState'] in ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED')]
    if not edit:
        sys.exit('::error::편집할 수 있는 버전이 없어요')
    ver = edit[0]
    vid = ver['id']
    if ver['attributes']['versionString'] != version:
        call('PATCH', f'/appStoreVersions/{vid}', {'data': {'type': 'appStoreVersions', 'id': vid, 'attributes': {'versionString': version}}})
        print('버전 번호 →', version)
    cp = open(os.path.join(MD, 'copyright.txt'), encoding='utf-8').read().strip()
    call('PATCH', f'/appStoreVersions/{vid}', {'data': {'type': 'appStoreVersions', 'id': vid, 'attributes': {'copyright': cp}}})
    print('저작권', cp)

    # 버전 글 (설명·키워드·프로모션·지원/마케팅 URL)
    locs = call('GET', f'/appStoreVersions/{vid}/appStoreVersionLocalizations')['data']
    loc = next((l for l in locs if l['attributes']['locale'].startswith('ko')), None)
    attrs = {'description': read('description.txt'), 'keywords': read('keywords.txt'), 'promotionalText': read('promotional_text.txt'),
             'supportUrl': read('support_url.txt'), 'marketingUrl': read('marketing_url.txt')}
    attrs = {k: v for k, v in attrs.items() if v}
    if loc:
        call('PATCH', f"/appStoreVersionLocalizations/{loc['id']}", {'data': {'type': 'appStoreVersionLocalizations', 'id': loc['id'], 'attributes': attrs}})
    else:
        loc = call('POST', '/appStoreVersionLocalizations', {'data': {'type': 'appStoreVersionLocalizations', 'attributes': dict(attrs, locale='ko'),
                                                                        'relationships': {'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})['data']
    print('버전 글', list(attrs))

    # 앱 정보 글 (부제·개인정보처리방침 URL) — 편집 중인 appInfo
    infos = call('GET', f'/apps/{aid}/appInfos')['data']
    info = next((i for i in infos if i['attributes'].get('appStoreState') != 'READY_FOR_SALE'), infos[0])
    ilocs = call('GET', f"/appInfos/{info['id']}/appInfoLocalizations")['data']
    il = next((l for l in ilocs if l['attributes']['locale'].startswith('ko')), None)
    ia = {'subtitle': read('subtitle.txt'), 'privacyPolicyUrl': read('privacy_url.txt')}
    if il:
        call('PATCH', f"/appInfoLocalizations/{il['id']}", {'data': {'type': 'appInfoLocalizations', 'id': il['id'], 'attributes': ia}})
        print('앱 정보 글', list(ia))
    else:
        print('::warning::한국어 앱 정보가 없어 부제를 못 넣음')
    # 카테고리: 게임 › 롤플레잉
    try:
        call('PATCH', f"/appInfos/{info['id']}", {'data': {'type': 'appInfos', 'id': info['id'], 'relationships': {
            'primaryCategory': {'data': {'type': 'appCategories', 'id': 'GAMES'}},
            'primarySubcategoryOne': {'data': {'type': 'appCategories', 'id': 'GAMES_ROLE_PLAYING'}}}}})
        print('카테고리 GAMES › GAMES_ROLE_PLAYING')
    except requests.HTTPError:
        print('::warning::카테고리는 화면에서 확인')

    # 스크린샷: 6.9인치 칸을 비우고 8장 다시
    sets = call('GET', f"/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")['data']
    sset = next((s for s in sets if s['attributes']['screenshotDisplayType'] == DISPLAY), None)
    if not sset:
        sset = call('POST', '/appScreenshotSets', {'data': {'type': 'appScreenshotSets', 'attributes': {'screenshotDisplayType': DISPLAY},
                                                          'relationships': {'appStoreVersionLocalization': {'data': {'type': 'appStoreVersionLocalizations', 'id': loc['id']}}}}})['data']
    for old in call('GET', f"/appScreenshotSets/{sset['id']}/appScreenshots")['data']:
        call('DELETE', f"/appScreenshots/{old['id']}")
    for f in SHOTS:
        b = open(f, 'rb').read()
        r = call('POST', '/appScreenshots', {'data': {'type': 'appScreenshots', 'attributes': {'fileName': os.path.basename(f), 'fileSize': len(b)},
                                                     'relationships': {'appScreenshotSet': {'data': {'type': 'appScreenshotSets', 'id': sset['id']}}}}})['data']
        for op in r['attributes']['uploadOperations']:
            part = b[op['offset']:op['offset'] + op['length']]
            S.request(op['method'], op['url'], data=part, headers={h['name']: h['value'] for h in op['requestHeaders']}).raise_for_status()
        call('PATCH', f"/appScreenshots/{r['id']}", {'data': {'type': 'appScreenshots', 'id': r['id'],
                                                             'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(b).hexdigest()}}})
        print('스크린샷', os.path.basename(f))
    print('완료')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '0.0.4')
