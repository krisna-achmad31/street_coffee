import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Street Pass purchase via Google Play Billing / Apple IAP.
///
/// The app never grants membership itself: every purchase token goes to the
/// `verifyPassPurchase` Cloud Function, which checks it with the store and
/// writes memberships/{uid}. The UI reacts to that document.
class StreetPassBilling {
  static const monthlyId = 'street_pass_monthly';
  static const yearlyId = 'street_pass_yearly';

  final InAppPurchase _iap;
  final FirebaseFunctions _functions;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  final _status = StreamController<BillingStatus>.broadcast();
  Stream<BillingStatus> get status => _status.stream;

  StreetPassBilling({InAppPurchase? iap, required FirebaseFunctions functions})
      : _iap = iap ?? InAppPurchase.instance,
        _functions = functions;

  void start() {
    _sub ??= _iap.purchaseStream.listen(_onPurchases,
        onError: (e) => _status.add(BillingStatus.error('$e')));
  }

  Future<Map<String, ProductDetails>> products() async {
    if (!await _iap.isAvailable()) return {};
    final res = await _iap.queryProductDetails({monthlyId, yearlyId});
    return {for (final p in res.productDetails) p.id: p};
  }

  Future<void> buy(ProductDetails product) async {
    _status.add(const BillingStatus.pending());
    await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _status.add(const BillingStatus.pending());
        case PurchaseStatus.error:
          _status.add(BillingStatus.error(p.error?.message ?? 'Gagal'));
        case PurchaseStatus.canceled:
          _status.add(const BillingStatus.idle());
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await _functions.httpsCallable('verifyPassPurchase').call({
              'platform': Platform.isIOS ? 'ios' : 'android',
              'productId': p.productID,
              'token': p.verificationData.serverVerificationData,
            });
            _status.add(const BillingStatus.success());
          } catch (e) {
            _status.add(BillingStatus.error('Verifikasi gagal: $e'));
          }
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  void dispose() {
    _sub?.cancel();
    _status.close();
  }
}

class BillingStatus {
  final String state; // idle | pending | success | error
  final String? message;
  const BillingStatus._(this.state, [this.message]);
  const BillingStatus.idle() : this._('idle');
  const BillingStatus.pending() : this._('pending');
  const BillingStatus.success() : this._('success');
  const BillingStatus.error(String m) : this._('error', m);
}
