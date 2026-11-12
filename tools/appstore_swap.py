"""아이폰 심사 바꿔 내기 (App Store Connect API) — GitHub Actions 「appstore-swap」에서 실행.

대표님 「전송해」(2026-11-12) 뒤에만 쓴다. 심사 대기 중인 버전(0.0.5)을 심사에서 빼고,
같은 버전 칸의 번호를 새 버전(0.0.8)으로 바꾼 뒤 새 빌드(386)를 넣고, 인앱 상품·구독과 함께 다시 제출한다.
0.0.5 가 그사이 통과했으면 빼지 않고 새 버전 칸을 만들어 업데이트로 낸다.
글·스크린샷·심사 메모는 같은 버전 칸이라 그대로 남는다.

    python3 tools/appstore_swap.py check 0.0.8 386   # 읽기만: 지금 상태와 할 일 출력
    python3 tools/appstore_swap.py go 0.0.8 386      # 실제로 바꿈

키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.
"""
import sys
import time

from appstore_metadata import BUNDLE, call

OPEN_REVIEW = ('WAITING_FOR_REVIEW', 'IN_REVIEW', 'UNRESOLVED_ISSUES')
EDITABLE = ('PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY')
LIVE = ('READY_FOR_SALE', 'PENDING_DEVELOPER_RELEASE', 'PROCESSING_FOR_APP_STORE', 'PENDING_APPLE_RELEASE', 'READY_FOR_DISTRIBUTION')


def versions(aid):
    vs = call('GET', f'/apps/{aid}/appStoreVersions', params={'filter[platform]': 'IOS', 'limit': 20})['data']
    for v in vs:
        a = v['attributes']
        print('  버전', a['versionString'], a.get('appStoreState'), v['id'])
    return vs


def submissions(aid):
    out = call('GET', '/reviewSubmissions', params={'filter[app]': aid, 'filter[platform]': 'IOS', 'limit': 20})['data']
    for s in out:
        a = s['attributes']
        print('  심사 제출', s['id'], a.get('state'), a.get('submittedDate'))
    return out


def products(aid):
    iaps = call('GET', f'/apps/{aid}/inAppPurchasesV2', params={'limit': 50})['data']
    subs = []
    for g in call('GET', f'/apps/{aid}/subscriptionGroups')['data']:
        subs += call('GET', f"/subscriptionGroups/{g['id']}/subscriptions")['data']
    for p in iaps:
        print('  인앱', p['attributes']['productId'], p['attributes'].get('state'))
    for s in subs:
        print('  구독', s['attributes']['productId'], s['attributes'].get('state'))
    return iaps, subs


def find_build(aid, ver, num):
    bs = call('GET', '/builds', params={'filter[app]': aid, 'filter[version]': num, 'filter[preReleaseVersion.version]': ver, 'limit': 5})['data']
    for b in bs:
        a = b['attributes']
        print('  빌드', ver, a['version'], a.get('processingState'), '만료' if a.get('expired') else '', b['id'])
    ok = [b for b in bs if b['attributes'].get('processingState') == 'VALID' and not b['attributes'].get('expired')]
    return ok[0] if ok else None


def wait(what, fn, tries=40, gap=15):
    for i in range(tries):
        r = fn()
        if r:
            return r
        print(f'  … {what} 기다리는 중 ({(i + 1) * gap}초)')
        time.sleep(gap)
    sys.exit(f'::error::{what} — 시간 안에 안 됨')


def main(mode, ver, num):
    go = mode == 'go'
    app = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]
    aid = app['id']
    print('앱', aid, app['attributes']['name'], '· 할 일:', '실제로 바꿈' if go else '확인만')

    print('[지금 상태]')
    vs = versions(aid)
    subs_all = submissions(aid)
    iaps, subs = products(aid)
    build = find_build(aid, ver, num)
    if not build:
        sys.exit(f'::error::빌드 {ver}({num})가 아직 처리 중이거나 없어요')

    live = [v for v in vs if v['attributes']['appStoreState'] in LIVE]
    pending = [v for v in vs if v['attributes']['appStoreState'] in OPEN_REVIEW]
    editable = [v for v in vs if v['attributes']['appStoreState'] in EDITABLE]
    open_sub = [s for s in subs_all if s['attributes'].get('state') in ('WAITING_FOR_REVIEW', 'IN_REVIEW', 'UNRESOLVED_ISSUES')]

    print('[할 일]')
    if pending:
        st = pending[0]['attributes']['appStoreState']
        if st == 'IN_REVIEW':
            sys.exit('::error::지금 애플이 심사하는 중(IN_REVIEW)이에요 — 빼지 않고 멈춤. 대표님께 다시 여쭙기')
        print(f"  1. 심사 대기 {pending[0]['attributes']['versionString']} 를 심사에서 빼기 (제출 {[s['id'] for s in open_sub]})")
        target = pending[0]
    elif editable:
        print(f"  1. (뺄 것 없음) 편집 중인 {editable[0]['attributes']['versionString']} 칸을 씀")
        target = editable[0]
    elif live:
        print(f"  1. {live[0]['attributes']['versionString']} 는 이미 통과 → 새 버전 칸 {ver} 만들기 (업데이트)")
        target = None
    else:
        sys.exit('::error::쓸 버전 칸을 못 찾음')
    print(f'  2. 버전 번호 → {ver} · 빌드 {num} 넣기')
    print('  3. 인앱·구독 중 아직 승인 안 된 것을 이 버전과 함께 제출 · 심사 제출')
    if not go:
        print('확인만 끝 — 바꾼 것 없음')
        return

    # 1. 심사에서 빼기
    if pending:
        for s in open_sub:
            call('PATCH', f"/reviewSubmissions/{s['id']}", {'data': {'type': 'reviewSubmissions', 'id': s['id'], 'attributes': {'canceled': True}}})
            print('  심사 제출 취소 요청', s['id'])
        vid = target['id']

        def back():
            st = call('GET', f'/appStoreVersions/{vid}')['data']['attributes']['appStoreState']
            return st if st in EDITABLE else None
        print('  버전 상태 →', wait('심사에서 빠지기', back))
        # 취소한 제출이 끝날 때까지 (새 제출을 만들 수 있게)
        def done():
            ss = call('GET', '/reviewSubmissions', params={'filter[app]': aid, 'filter[platform]': 'IOS', 'limit': 20})['data']
            return all(s['attributes'].get('state') not in ('WAITING_FOR_REVIEW', 'IN_REVIEW', 'CANCELING', 'UNRESOLVED_ISSUES') for s in ss)
        wait('제출 취소 끝나기', done)
    elif target is None:
        r = call('POST', '/appStoreVersions', {'data': {'type': 'appStoreVersions', 'attributes': {'platform': 'IOS', 'versionString': ver},
                                                       'relationships': {'app': {'data': {'type': 'apps', 'id': aid}}}}})
        target = r['data']
        print('  새 버전 칸', target['id'])
    vid = target['id']

    # 2. 번호·빌드
    if call('GET', f'/appStoreVersions/{vid}')['data']['attributes']['versionString'] != ver:
        call('PATCH', f'/appStoreVersions/{vid}', {'data': {'type': 'appStoreVersions', 'id': vid, 'attributes': {'versionString': ver}}})
        print('  버전 번호 →', ver)
    call('PATCH', f'/appStoreVersions/{vid}/relationships/build', {'data': {'type': 'builds', 'id': build['id']}})
    print('  빌드 넣음', num)

    # 3. 제출 (열려 있는 준비 중 제출이 있으면 그것을 씀)
    ss = call('GET', '/reviewSubmissions', params={'filter[app]': aid, 'filter[platform]': 'IOS', 'filter[state]': 'READY_FOR_REVIEW', 'limit': 5})['data']
    if ss:
        sid = ss[0]['id']
        print('  준비 중 제출 다시 씀', sid)
    else:
        sid = call('POST', '/reviewSubmissions', {'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'},
                                                           'relationships': {'app': {'data': {'type': 'apps', 'id': aid}}}}})['data']['id']
        print('  새 제출', sid)
    items = call('GET', f'/reviewSubmissions/{sid}/items')['data']
    has_ver = False
    for it in items:
        rel = call('GET', f"/reviewSubmissionItems/{it['id']}/appStoreVersion").get('data')
        if rel and rel['id'] == vid:
            has_ver = True
    if not has_ver:
        call('POST', '/reviewSubmissionItems', {'data': {'type': 'reviewSubmissionItems', 'relationships': {
            'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sid}},
            'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})
        print('  제출에 버전 넣음')

    iaps, subs = products(aid)
    for p in iaps:
        if p['attributes'].get('state') == 'READY_TO_SUBMIT':
            call('POST', '/inAppPurchaseSubmissions', {'data': {'type': 'inAppPurchaseSubmissions', 'relationships': {
                'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': p['id']}}}}})
            print('  인앱 함께 제출', p['attributes']['productId'])
    for s in subs:
        if s['attributes'].get('state') == 'READY_TO_SUBMIT':
            call('POST', '/subscriptionSubmissions', {'data': {'type': 'subscriptionSubmissions', 'relationships': {
                'subscription': {'data': {'type': 'subscriptions', 'id': s['id']}}}}})
            print('  구독 함께 제출', s['attributes']['productId'])

    call('PATCH', f'/reviewSubmissions/{sid}', {'data': {'type': 'reviewSubmissions', 'id': sid, 'attributes': {'submitted': True}}})
    print('  심사 제출 완료', sid)
    print('[제출 뒤 상태]')
    versions(aid)
    submissions(aid)
    products(aid)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
