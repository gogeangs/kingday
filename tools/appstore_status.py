"""App Store 심사 상태 보기 (읽기만) — GitHub Actions 「appstore-status」에서 실행.

아무것도 바꾸지 않는다. iOS 버전·심사 제출·인앱 상품·구독 상태를 출력한다.
키는 환경 변수(APPSTORE_KEY_ID · APPSTORE_ISSUER_ID · APPSTORE_KEY_P8)로만 받는다.
"""
from appstore_metadata import BUNDLE, call


def main():
    aid = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    for v in call('GET', f'/apps/{aid}/appStoreVersions', params={'filter[platform]': 'IOS', 'limit': 5})['data']:
        a = v['attributes']
        print('버전', a['versionString'], a.get('appStoreState'), a.get('appVersionState'), a.get('releaseType'))
    for s in call('GET', '/reviewSubmissions', params={'filter[app]': aid, 'limit': 5})['data']:
        a = s['attributes']
        print('심사 제출', a.get('submittedDate'), a.get('state'), a.get('platform'))
    for p in call('GET', f'/apps/{aid}/inAppPurchasesV2', params={'limit': 50})['data']:
        print('인앱', p['attributes']['productId'], p['attributes'].get('state'))
    for g in call('GET', f'/apps/{aid}/subscriptionGroups')['data']:
        for s in call('GET', f"/subscriptionGroups/{g['id']}/subscriptions")['data']:
            print('구독', s['attributes']['productId'], s['attributes'].get('state'))


if __name__ == '__main__':
    main()
