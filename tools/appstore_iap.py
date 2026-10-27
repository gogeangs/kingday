"""App Store 인앱 상품 심사용 스크린샷 넣기 (App Store Connect API) — GitHub Actions 「appstore-iap」에서 실행.

모든 인앱 구입·구독에 심사용 스크린샷(store/appstore/iap_review.png, 상점 화면)이 없으면 넣고, 상품마다 상태를 출력한다.
심사 제출은 하지 않는다 — 제출 초안에 넣기·「심사를 위해 제출」은 App Store Connect 화면에서.
키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.
"""
import hashlib
import os
import time

from appstore_metadata import BUNDLE, S, call

SHOT = 'store/appstore/iap_review.png'


def upload(kind, rel, rtype, oid):
    b = open(SHOT, 'rb').read()
    r = call('POST', f'/{kind}', {'data': {'type': kind, 'attributes': {'fileName': os.path.basename(SHOT), 'fileSize': len(b)},
                                          'relationships': {rel: {'data': {'type': rtype, 'id': oid}}}}})['data']
    for op in r['attributes']['uploadOperations']:
        part = b[op['offset']:op['offset'] + op['length']]
        S.request(op['method'], op['url'], data=part, headers={h['name']: h['value'] for h in op['requestHeaders']}).raise_for_status()
    for i in range(4):  # Apple 쪽 500 이 가끔 나서 몇 번 더 해 봄
        try:
            call('PATCH', f"/{kind}/{r['id']}", {'data': {'type': kind, 'id': r['id'],
                                                          'attributes': {'uploaded': True, 'sourceFileChecksum': hashlib.md5(b).hexdigest()}}})
            return
        except Exception:
            time.sleep(5 * (i + 1))
    raise SystemExit('::error::스크린샷 확정 실패')


def has_shot(path, kind):
    """다 올라간 스크린샷이 있으면 True. 반쯤 올라간 것은 지우고 False."""
    try:
        d = call('GET', path).get('data')
    except Exception:
        return False
    if not d:
        return False
    st = ((d['attributes'].get('assetDeliveryState') or {}).get('state'))
    if st in ('COMPLETE', 'UPLOAD_COMPLETE'):
        return True
    call('DELETE', f"/{kind}/{d['id']}")
    print('반쯤 올라간 스크린샷 지움', st)
    return False


def main():
    aid = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    iaps = call('GET', f'/apps/{aid}/inAppPurchasesV2', params={'limit': 50})['data']
    for p in iaps:
        a = p['attributes']
        if not has_shot(f"https://api.appstoreconnect.apple.com/v2/inAppPurchases/{p['id']}/appStoreReviewScreenshot", 'inAppPurchaseAppStoreReviewScreenshots'):
            upload('inAppPurchaseAppStoreReviewScreenshots', 'inAppPurchaseV2', 'inAppPurchases', p['id'])
            print('스크린샷 넣음', a['productId'])
        print('인앱', p['id'], a['productId'], a.get('state'))
    for g in call('GET', f'/apps/{aid}/subscriptionGroups')['data']:
        gl = call('GET', f"/subscriptionGroups/{g['id']}/subscriptionGroupLocalizations")['data']
        print('구독 그룹', g['id'], g['attributes'].get('referenceName'), '현지화', [l['attributes']['locale'] for l in gl])
        for s in call('GET', f"/subscriptionGroups/{g['id']}/subscriptions")['data']:
            a = s['attributes']
            if not has_shot(f"/subscriptions/{s['id']}/appStoreReviewScreenshot", 'subscriptionAppStoreReviewScreenshots'):
                upload('subscriptionAppStoreReviewScreenshots', 'subscription', 'subscriptions', s['id'])
                print('스크린샷 넣음', a['productId'])
            print('구독', s['id'], a['productId'], a.get('state'))
    print('완료')


if __name__ == '__main__':
    main()
