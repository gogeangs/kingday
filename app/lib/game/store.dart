/// 인앱결제 (Google Play 결제 · Apple 인앱 구매).
///
/// 흐름: 상점에서 누름 → 스토어 결제 창 → 결제되면 영수증을 서버(Edge Function kd-iap)로 보냄
///   → 서버가 구글/애플에 확인하고 「구매 완료」 우편을 넣음 → 앱이 그 우편을 바로 받아 지급 → 스토어에 처리 완료 알림.
/// 결제가 됐는데 앱이 꺼져도, 다음에 켤 때 스토어가 다시 알려 주므로 빠지지 않음.
///
/// [enabled] 가 false 인 동안(스토어에 상품을 등록하기 전)은 웹처럼 시험용 바로 지급을 쓴다 (GameActions.testPay).
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';

import 'controller.dart';

class IapStore {
  /// 실제 스토어 결제를 쓰는지. 안드로이드(Play Console 상품 9개)·아이폰(App Store Connect 상품 9개) 모두
  /// 서버 함수 kd-iap 로 확인 (2026-10-25 · 애플 인앱 구매 키는 Supabase Secret)
  static bool get enabled => Platform.isAndroid || Platform.isIOS;

  /// 게임 상품 키 → 스토어 상품 ID (Play Console·App Store Connect 에 이 ID 로 등록)
  static const ids = {
    'p1': 'kd_gem_60',
    'p2': 'kd_gem_330',
    'p3': 'kd_gem_680',
    'p4': 'kd_gem_1280',
    'p5': 'kd_gem_3280',
    'p6': 'kd_gem_6480',
    'starter': 'kd_starter',
    'chief': 'kd_chief',
    'ttuk': 'kd_ttukttak',
    'lucian': 'kd_lucian',
    'goldie': 'kd_goldie',
    'sub': 'kd_sub_monthly',
    // 상점·패스 (docs/content/SHOP.md): 원정 일지(소모성, 시즌마다) · 영주의 첫걸음(비소모성, 계정당 1번)
    'pass': 'kd_pass',
    'growth': 'kd_growth',
  };

  /// 비소모성(한 번 사면 끝) 상품 — 스토어에 「소비됨」으로 알리지 않음
  static const nonConsumable = {'sub', 'growth'};

  IapStore(this.g);
  final GameController g;
  final Map<String, ProductDetails> products = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool available = false;

  /// 아이폰인지 (App Store 「구매 복원」 버튼)
  bool get isIos => Platform.isIOS;

  /// 스토어 가격 표시 (예: ₩1,200). 없으면 null → 화면은 웹 가격표를 씀
  String? price(String key) => products[ids[key]]?.price;

  Future<void> init() async {
    if (!enabled) return;
    try {
      final iap = InAppPurchase.instance;
      available = await iap.isAvailable();
      if (!available) return;
      _sub = iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      final r = await iap.queryProductDetails(ids.values.toSet());
      for (final p in r.productDetails) {
        products[p.id] = p;
      }
      g.refresh();
    } catch (_) {
      available = false;
    }
  }

  void dispose() => _sub?.cancel();

  /// 결제 시작
  Future<void> buy(String key) async {
    final p = products[ids[key]];
    if (!available || p == null) {
      g.toast('지금은 결제할 수 없어요. 잠시 뒤에 다시 해 주세요');
      return;
    }
    // 우편으로 받으려면 계정이 있어야 함
    if (g.online.nick == null) await g.online.ensure();
    if (g.online.nick == null) {
      g.toast('인터넷에 연결된 뒤 구매할 수 있어요');
      return;
    }
    final param = PurchaseParam(productDetails: p);
    try {
      if (nonConsumable.contains(key)) {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      }
    } catch (_) {
      g.toast('결제를 시작하지 못했어요');
    }
  }

  /// 구매 복원 (App Store 규칙: 비소모성 상품 「영주의 첫걸음」이 있으면 복원 버튼 필요).
  /// 복원된 영수증도 서버(kd-iap)가 확인 — 이미 받은 계정이면 다시 주지 않음
  Future<void> restore() async {
    if (!available) {
      g.toast('지금은 스토어에 연결할 수 없어요');
      return;
    }
    try {
      await InAppPurchase.instance.restorePurchases();
      g.toast('구매 기록을 확인하고 있어요');
    } catch (_) {
      g.toast('구매 기록을 불러오지 못했어요');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          g.toast('결제를 확인하고 있어요…');
        case PurchaseStatus.error:
          g.toast('결제가 되지 않았어요');
          if (pd.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(pd);
        case PurchaseStatus.canceled:
          if (pd.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(pd);
        case PurchaseStatus.purchased || PurchaseStatus.restored:
          final ok = await _verify(pd);
          // 서버가 확인(또는 이미 지급)했을 때만 스토어에 끝났다고 알림. 실패하면 다음 실행 때 다시 시도
          if (ok && pd.pendingCompletePurchase) await InAppPurchase.instance.completePurchase(pd);
      }
    }
  }

  Future<bool> _verify(PurchaseDetails pd) async {
    final sv = g.online.sv;
    if (sv == null) return false;
    final token = Platform.isAndroid ? pd.verificationData.serverVerificationData : (pd.purchaseID ?? '');
    try {
      final (code, j) = await sv.function('kd-iap', {'platform': Platform.isAndroid ? 'android' : 'ios', 'productId': pd.productID, 'token': token});
      final r = j is Map ? j['result'] : null;
      if (code == 200 && (r == 'ok' || r == 'dup')) {
        // 「구매 완료」 우편을 바로 받아 지급
        await g.online.claimShopMails();
        return true;
      }
      if (code == 402) {
        g.toast('결제를 확인하지 못했어요. 문제가 계속되면 문의해 주세요');
        return true; // 가짜·취소된 결제는 다시 시도하지 않음
      }
    } catch (_) {}
    g.toast('결제는 됐어요. 인터넷이 연결되면 우편으로 받아요');
    return false;
  }
}
