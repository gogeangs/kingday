"""App Store 인앱 상품·구독 모두 삭제 (App Store Connect API) — GitHub Actions 「appstore-iap-delete」에서 실행.

2026-11 완전 무료 전환: 한 번도 승인되지 않은 인앱 상품 13개·구독 kd_sub_monthly·구독 그룹을 지운다.
되돌릴 수 없고, 지운 상품 ID 는 다시 못 쓴다. 키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.
"""
import requests

from appstore_metadata import BUNDLE, call

V2 = 'https://api.appstoreconnect.apple.com/v2'


def main():
    aid = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    bad = 0
    for p in call('GET', f'/apps/{aid}/inAppPurchasesV2', params={'limit': 50})['data']:
        pid = p['attributes']['productId']
        try:
            call('DELETE', f"{V2}/inAppPurchases/{p['id']}")
            print('삭제 인앱', pid)
        except requests.HTTPError:
            bad += 1
            print('실패 인앱', pid, p['attributes'].get('state'))
    for g in call('GET', f'/apps/{aid}/subscriptionGroups')['data']:
        for s in call('GET', f"/subscriptionGroups/{g['id']}/subscriptions")['data']:
            try:
                call('DELETE', f"/subscriptions/{s['id']}")
                print('삭제 구독', s['attributes']['productId'])
            except requests.HTTPError:
                bad += 1
                print('실패 구독', s['attributes']['productId'], s['attributes'].get('state'))
        try:
            call('DELETE', f"/subscriptionGroups/{g['id']}")
            print('삭제 구독 그룹', g['attributes'].get('referenceName'))
        except requests.HTTPError:
            print('구독 그룹은 남음', g['attributes'].get('referenceName'))
    left = call('GET', f'/apps/{aid}/inAppPurchasesV2', params={'limit': 50})['data']
    print('남은 인앱', [p['attributes']['productId'] for p in left])
    if bad:
        raise SystemExit(f'::error::{bad}개를 지우지 못했어요')


if __name__ == '__main__':
    main()
