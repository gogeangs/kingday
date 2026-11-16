"""아이폰 새 버전 준비 (App Store Connect API) — GitHub Actions 「appstore-release」에서 실행.

1) (cancel=yes) 심사 대기 중인 제출을 취소한다 → 버전이 다시 편집 가능해질 때까지 기다림
2) appstore_metadata.main(version): 버전 번호·글·스크린샷 넣기
3) 같은 버전 번호의 가장 최근 처리 완료 빌드를 버전에 붙이기
심사 제출은 하지 않는다(앱 개인정보·제출은 App Store Connect 화면에서).
키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.

    python3 tools/appstore_release.py 0.0.10 yes
"""
import sys
import time

import appstore_metadata as md
from appstore_metadata import BUNDLE, call

EDITABLE = ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED')


def versions(aid):
    return call('GET', f'/apps/{aid}/appStoreVersions', params={'filter[platform]': 'IOS', 'limit': 5})['data']


def main(version, cancel):
    aid = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    if cancel == 'yes':
        for s in call('GET', '/reviewSubmissions', params={'filter[app]': aid, 'filter[platform]': 'IOS', 'limit': 10})['data']:
            if s['attributes'].get('state') in ('WAITING_FOR_REVIEW', 'IN_REVIEW', 'UNRESOLVED_ISSUES', 'READY_FOR_REVIEW'):
                call('PATCH', f"/reviewSubmissions/{s['id']}", {'data': {'type': 'reviewSubmissions', 'id': s['id'], 'attributes': {'canceled': True}}})
                print('심사 제출 취소 요청', s['id'], s['attributes'].get('state'))
        for _ in range(40):
            vs = versions(aid)
            if any(v['attributes']['appStoreState'] in EDITABLE for v in vs):
                break
            print('기다리는 중', [(v['attributes']['versionString'], v['attributes']['appStoreState']) for v in vs[:2]])
            time.sleep(15)
    md.main(version)

    ver = next(v for v in versions(aid) if v['attributes']['appStoreState'] in EDITABLE)
    builds = call('GET', '/builds', params={'filter[app]': aid, 'filter[preReleaseVersion.version]': version,
                                             'filter[processingState]': 'VALID', 'sort': '-uploadedDate', 'limit': 1})['data']
    if not builds:
        print('::warning::처리 끝난', version, '빌드가 없어 빌드는 화면에서 고르기')
        return
    b = builds[0]
    call('PATCH', f"/appStoreVersions/{ver['id']}/relationships/build", {'data': {'type': 'builds', 'id': b['id']}})
    print('빌드 붙임', b['attributes']['version'], b['attributes'].get('uploadedDate'))
    for v in versions(aid)[:2]:
        print('버전', v['attributes']['versionString'], v['attributes']['appStoreState'])


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else 'no')
