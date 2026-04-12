import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_service.dart';

class GooglePlayBillingService {
  GooglePlayBillingService._();

  static final GooglePlayBillingService instance = GooglePlayBillingService._();

  static const String coins10ProductId = 'coins_10';
  static const String coins30ProductId = 'coins_30';
  static const String coins60ProductId = 'coins_60';
  static const String fastMatchProductId = 'fast_match_unlock';

  static const Set<String> _productIds = {
    coins10ProductId,
    coins30ProductId,
    coins60ProductId,
    fastMatchProductId,
  };

  final InAppPurchase _iap = InAppPurchase.instance;
  final Map<String, ProductDetails> _productsById = {};
  final Map<String, Completer<bool>> _pendingPurchases = {};
  final Map<String, Future<void> Function()> _deliveryHandlers = {};

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;
  bool _available = false;

  bool get isAvailable => _available;

  ProductDetails? productForId(String productId) => _productsById[productId];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (kIsWeb) {
      _available = false;
      return;
    }

    try {
      _available = await _iap.isAvailable();
      if (!_available) return;

      final response = await _iap.queryProductDetails(_productIds);
      for (final product in response.productDetails) {
        _productsById[product.id] = product;
      }

      _subscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (Object error) {
          debugPrint('Google Play billing stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Google Play billing init error: $e');
      _available = false;
    }
  }

  Future<bool> buyCoins(int coins) async {
    final productId = _productIdForCoins(coins);
    if (productId == null) {
      return false;
    }

    return _buyConsumable(
      productId: productId,
      onDelivered: () async {
        await WalletService.addCoins(coins);
      },
    );
  }

  Future<bool> buyFastMatch() async {
    return _buyNonConsumable(
      productId: fastMatchProductId,
      onDelivered: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('fast_match_paid', true);
      },
    );
  }

  Future<bool> restoreFastMatch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('fast_match_paid') ?? false;
  }

  Future<bool> _buyConsumable({
    required String productId,
    required Future<void> Function() onDelivered,
  }) async {
    await init();
    if (!_available) {
      return false;
    }

    final product = _productsById[productId];
    if (product == null) {
      return false;
    }

    if (_pendingPurchases.containsKey(productId)) {
      return false;
    }

    final completer = Completer<bool>();
    _pendingPurchases[productId] = completer;
    _deliveryHandlers[productId] = onDelivered;

    try {
      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _pendingPurchases.remove(productId);
      _deliveryHandlers.remove(productId);
      return false;
    }

    return _awaitPurchaseResult(productId, completer);
  }

  Future<bool> _buyNonConsumable({
    required String productId,
    required Future<void> Function() onDelivered,
  }) async {
    await init();
    if (!_available) {
      return false;
    }

    final product = _productsById[productId];
    if (product == null) {
      return false;
    }

    if (_pendingPurchases.containsKey(productId)) {
      return false;
    }

    final completer = Completer<bool>();
    _pendingPurchases[productId] = completer;
    _deliveryHandlers[productId] = onDelivered;

    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      _pendingPurchases.remove(productId);
      _deliveryHandlers.remove(productId);
      return false;
    }

    return _awaitPurchaseResult(productId, completer);
  }

  Future<bool> _awaitPurchaseResult(
    String productId,
    Completer<bool> completer,
  ) async {
    final result = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pendingPurchases.remove(productId);
        _deliveryHandlers.remove(productId);
        return false;
      },
    );

    return result;
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        continue;
      }

      final completer = _pendingPurchases[purchase.productID];
      final deliveryHandler = _deliveryHandlers[purchase.productID];

      bool success = false;
      try {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (deliveryHandler != null) {
            await deliveryHandler();
          }
          success = true;
        }
      } catch (e) {
        debugPrint('Google Play billing delivery error: $e');
        success = false;
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('Google Play billing completePurchase error: $e');
        }
      }

      if (completer != null && !completer.isCompleted) {
        completer.complete(success);
      }

      _pendingPurchases.remove(purchase.productID);
      _deliveryHandlers.remove(purchase.productID);
    }
  }

  String? _productIdForCoins(int coins) {
    switch (coins) {
      case 10:
        return coins10ProductId;
      case 30:
        return coins30ProductId;
      case 60:
        return coins60ProductId;
      default:
        return null;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _available = false;
    _productsById.clear();
    _pendingPurchases.clear();
    _deliveryHandlers.clear();
  }
}
