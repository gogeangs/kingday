"""appstore_swap.py 이어서: 인앱·구독을 버전보다 먼저 제출 묶음에 넣고 심사 제출 (2026-11-12, 첫 시도에서 「pending version 없음」 409)."""
import sys
from appstore_metadata import BUNDLE, call
from appstore_swap import versions, submissions, products

def main(mode):
    aid = call('GET', '/apps', params={'filter[bundleId]': BUNDLE})['data'][0]['id']
    vs = versions(aid)
    v = [x for x in vs if x['attributes']['versionString'] == '0.0.8'][0]
    vid = v['id']
    print('버전 0.0.8', v['attributes']['appStoreState'])
    b = call('GET', f'/appStoreVersions/{vid}/build').get('data')
    print('빌드', b and b['attributes']['version'])
    ss = [s for s in submissions(aid) if s['attributes'].get('state') == 'READY_FOR_REVIEW']
    iaps, subs = products(aid)
    todo = [x for x in iaps + subs if x['attributes'].get('state') == 'READY_TO_SUBMIT']
    print('함께 낼 인앱·구독', len(todo))
    if mode != 'go':
        return
    # 1) 준비 중 제출에서 버전 빼기 (버전이 다시 「제출 기다림」이 되게)
    for s in ss:
        for it in call('GET', f"/reviewSubmissions/{s['id']}/items")['data']:
            call('DELETE', f"/reviewSubmissionItems/{it['id']}")
            print('  제출 묶음에서 뺌', it['id'])
    # 2) 인앱·구독 먼저
    for x in todo:
        if x['type'] == 'subscriptions':
            call('POST', '/subscriptionSubmissions', {'data': {'type': 'subscriptionSubmissions', 'relationships': {'subscription': {'data': {'type': 'subscriptions', 'id': x['id']}}}}})
        else:
            call('POST', '/inAppPurchaseSubmissions', {'data': {'type': 'inAppPurchaseSubmissions', 'relationships': {'inAppPurchaseV2': {'data': {'type': 'inAppPurchases', 'id': x['id']}}}}})
        print('  함께 제출 준비', x['attributes']['productId'])
    # 3) 버전 넣고 제출
    ss = [s for s in submissions(aid) if s['attributes'].get('state') == 'READY_FOR_REVIEW']
    sid = ss[0]['id'] if ss else call('POST', '/reviewSubmissions', {'data': {'type': 'reviewSubmissions', 'attributes': {'platform': 'IOS'}, 'relationships': {'app': {'data': {'type': 'apps', 'id': aid}}}}})['data']['id']
    call('POST', '/reviewSubmissionItems', {'data': {'type': 'reviewSubmissionItems', 'relationships': {
        'reviewSubmission': {'data': {'type': 'reviewSubmissions', 'id': sid}}, 'appStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}}}}})
    print('  제출 묶음에 버전 넣음', sid)
    call('PATCH', f'/reviewSubmissions/{sid}', {'data': {'type': 'reviewSubmissions', 'id': sid, 'attributes': {'submitted': True}}})
    print('  심사 제출 완료', sid)
    print('[제출 뒤 상태]'); versions(aid); submissions(aid); products(aid)

if __name__ == '__main__':
    main(sys.argv[1])
