import 'package:flutter/services.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_poolakey/flutter_poolakey.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/constants.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/purchase.dart';
import 'package:myket_iap/util/inventory.dart';


abstract class PaymentProvider {
  String get providerName;
  Future<bool> purchaseCourse(String courseId, {String? sku});
  Future<bool> purchasePackage(String packageId, {String? sku});
  Future<int> restorePurchases();
}

class GooglePlayPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  GooglePlayPaymentProvider(this.dioClient);

  @override
  String get providerName => 'GOOGLE_PLAY';

  @override
  Future<bool> purchaseCourse(String courseId, {String? sku}) async {
    // Requires real Google Play Billing verification token
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId, {String? sku}) async {
    // Requires real Google Play Billing verification token
    return false;
  }

  @override
  Future<int> restorePurchases() async => 0;
}

class BazaarPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  final String? rsaKey;
  bool _isConnected = false;

  bool lastPurchaseWasCancelled = false;
  bool lastErrorWasBazaarNotInstalled = false;

  BazaarPaymentProvider(this.dioClient, {this.rsaKey});

  @override
  String get providerName => 'BAZAAR';

  Future<bool> _ensureConnected() async {
    if (_isConnected) return true;
    try {
      final key = (rsaKey != null && rsaKey!.isNotEmpty) ? rsaKey : null;
      await FlutterPoolakey.connect(key);
      _isConnected = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolveSku(String itemId) async {
    final candidates = <String>[
      itemId,
      itemId.replaceAll('-', ''),
      itemId.replaceAll('-', '_'),
    ];
    try {
      final details = await FlutterPoolakey.getInAppSkuDetails(candidates);
      for (final skuDetail in details) {
        if (candidates.contains(skuDetail.sku)) {
          return skuDetail.sku;
        }
      }
    } catch (_) {
      // If querying SKU details fails or is not supported in sandbox, use original itemId
    }
    return itemId;
  }

  /// Submits a verified purchase token to the backend server
  Future<bool> verifyAndCompletePurchase({
    String? courseId,
    String? packageId,
    required String purchaseToken,
  }) async {
    final token = purchaseToken.trim();
    if (token.isEmpty ||
        token.toLowerCase().contains('mock') ||
        token.toLowerCase().contains('fake') ||
        token.toLowerCase().contains('simulated')) {
      return false;
    }

    try {
      if (packageId != null && packageId.isNotEmpty) {
        final response = await dioClient.dio.post('/purchases/package', data: {
          'package_id': packageId,
          'payment_provider': 'BAZAAR',
          'transaction_id': token,
        });
        return response.statusCode == 200 || response.statusCode == 201;
      } else if (courseId != null && courseId.isNotEmpty) {
        final response = await dioClient.dio.post('/purchases', data: {
          'course_id': courseId,
          'payment_provider': 'BAZAAR',
          'transaction_id': token,
        });
        return response.statusCode == 200 || response.statusCode == 201;
      }
      return false;
    } catch (_) {
      // Secondary fallback check: verify if the transaction was recorded in the database
      try {
        if (packageId != null && packageId.isNotEmpty) {
          final checkRes = await dioClient.dio.get('/packages/$packageId');
          if (checkRes.statusCode == 200 && checkRes.data != null) {
            final isPurchased = checkRes.data['is_purchased'] == true;
            if (isPurchased) return true;
          }
        } else if (courseId != null && courseId.isNotEmpty) {
          final checkRes = await dioClient.dio.get('/courses/$courseId');
          if (checkRes.statusCode == 200 && checkRes.data != null) {
            final isPurchased = checkRes.data['is_purchased'] == true;
            if (isPurchased) return true;
          }
        }
      } catch (_) {}
      return false;
    }
  }

  @override
  Future<bool> purchaseCourse(String courseId, {String? sku}) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasBazaarNotInstalled = false;

    final connected = await _ensureConnected();
    if (!connected) {
      lastErrorWasBazaarNotInstalled = true;
      return false;
    }

    try {
      final targetId = (sku != null && sku.trim().isNotEmpty) ? sku.trim() : courseId;
      final skuToUse = await _resolveSku(targetId);
      final purchaseInfo = await FlutterPoolakey.purchase(skuToUse, payload: "course:$courseId");
      if (purchaseInfo.purchaseToken.isNotEmpty) {
        return await verifyAndCompletePurchase(
          courseId: courseId,
          purchaseToken: purchaseInfo.purchaseToken,
        );
      }
    } on PlatformException catch (pe) {
      if (pe.code == 'PURCHASE_CANCELLED') {
        lastPurchaseWasCancelled = true;
      } else if (pe.code == 'CONNECTION_FAILED' || pe.code.contains('NOT_CONNECTED')) {
        lastErrorWasBazaarNotInstalled = true;
      }
    } catch (_) {
      // Clean fallback if Bazaar is not installed or cancelled
    }
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId, {String? sku}) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasBazaarNotInstalled = false;

    final connected = await _ensureConnected();
    if (!connected) {
      lastErrorWasBazaarNotInstalled = true;
      return false;
    }

    try {
      final targetId = (sku != null && sku.trim().isNotEmpty) ? sku.trim() : packageId;
      final skuToUse = await _resolveSku(targetId);
      final purchaseInfo = await FlutterPoolakey.purchase(skuToUse, payload: "package:$packageId");
      if (purchaseInfo.purchaseToken.isNotEmpty) {
        return await verifyAndCompletePurchase(
          packageId: packageId,
          purchaseToken: purchaseInfo.purchaseToken,
        );
      }
    } on PlatformException catch (pe) {
      if (pe.code == 'PURCHASE_CANCELLED') {
        lastPurchaseWasCancelled = true;
      } else if (pe.code == 'CONNECTION_FAILED' || pe.code.contains('NOT_CONNECTED')) {
        lastErrorWasBazaarNotInstalled = true;
      }
    } catch (_) {
      // Clean fallback
    }
    return false;
  }

  @override
  Future<int> restorePurchases() async {
    final connected = await _ensureConnected();
    if (!connected) return 0;

    try {
      final purchases = await FlutterPoolakey.getAllPurchasedProducts();
      int restored = 0;
      for (final p in purchases) {
        if (p.productId.isNotEmpty && p.purchaseToken.isNotEmpty) {
          final payload = p.payload;
          final isExplicitPackage = payload.startsWith('package:') || p.productId.contains('pkg') || p.productId.contains('package');

          bool ok = false;
          if (isExplicitPackage) {
            ok = await verifyAndCompletePurchase(
              packageId: p.productId,
              purchaseToken: p.purchaseToken,
            );
            if (!ok) {
              ok = await verifyAndCompletePurchase(
                courseId: p.productId,
                purchaseToken: p.purchaseToken,
              );
            }
          } else {
            ok = await verifyAndCompletePurchase(
              courseId: p.productId,
              purchaseToken: p.purchaseToken,
            );
            if (!ok) {
              ok = await verifyAndCompletePurchase(
                packageId: p.productId,
                purchaseToken: p.purchaseToken,
              );
            }
          }

          if (ok) restored++;
        }
      }
      return restored;
    } catch (_) {
      return 0;
    }
  }
}

class MyketPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  final String? rsaKey;
  bool _isInitialized = false;
  bool lastPurchaseWasCancelled = false;
  bool lastErrorWasMyketNotInstalled = false;

  MyketPaymentProvider(this.dioClient, {this.rsaKey});

  @override
  String get providerName => 'MYKET';

  Future<bool> _ensureInitialized() async {
    if (_isInitialized) return true;
    try {
      final key = rsaKey ?? '';
      final IabResult? result = await MyketIAP.init(rsaKey: key);
      _isInitialized = result?.isSuccess() ?? false;
      return _isInitialized;
    } catch (_) {
      return false;
    }
  }

  /// Resolves the candidate SKU that matches Myket Console registration
  Future<String> _resolveSku(String itemId, {String? customSku}) async {
    final candidateSkus = <String>[
      if (customSku != null && customSku.trim().isNotEmpty) customSku.trim(),
      itemId,
      itemId.replaceAll('-', ''),
      itemId.replaceAll('-', '_'),
    ];

    try {
      final inventoryRes = await MyketIAP.queryInventory(
        querySkuDetails: true,
        skus: candidateSkus,
      );
      final inventory = inventoryRes[MyketIAP.INVENTORY] as Inventory?;
      if (inventory != null && inventory.mSkuMap.isNotEmpty) {
        for (final candidate in candidateSkus) {
          if (inventory.mSkuMap.containsKey(candidate)) {
            return candidate;
          }
        }
      }
    } catch (_) {
      // Graceful fallback to default candidate
    }

    return candidateSkus.first;
  }

  /// Submits a verified Myket purchase token to the backend server
  Future<bool> verifyAndCompletePurchase({
    String? courseId,
    String? packageId,
    required String purchaseToken,
  }) async {
    final token = purchaseToken.trim();
    if (token.isEmpty ||
        token.toLowerCase().contains('mock') ||
        token.toLowerCase().contains('fake') ||
        token.toLowerCase().contains('simulated')) {
      return false;
    }

    try {
      if (packageId != null && packageId.isNotEmpty) {
        final response = await dioClient.dio.post('/purchases/package', data: {
          'package_id': packageId,
          'payment_provider': 'MYKET',
          'transaction_id': token,
        });
        return response.statusCode == 200 || response.statusCode == 201;
      } else if (courseId != null && courseId.isNotEmpty) {
        final response = await dioClient.dio.post('/purchases', data: {
          'course_id': courseId,
          'payment_provider': 'MYKET',
          'transaction_id': token,
        });
        return response.statusCode == 200 || response.statusCode == 201;
      }
      return false;
    } catch (_) {
      // Secondary fallback check: verify if the transaction was recorded in the database
      try {
        if (packageId != null && packageId.isNotEmpty) {
          final checkRes = await dioClient.dio.get('/packages/$packageId');
          if (checkRes.statusCode == 200 && checkRes.data != null) {
            final isPurchased = checkRes.data['is_purchased'] == true;
            if (isPurchased) return true;
          }
        } else if (courseId != null && courseId.isNotEmpty) {
          final checkRes = await dioClient.dio.get('/courses/$courseId');
          if (checkRes.statusCode == 200 && checkRes.data != null) {
            final isPurchased = checkRes.data['is_purchased'] == true;
            if (isPurchased) return true;
          }
        }
      } catch (_) {}
      return false;
    }
  }

  @override
  Future<bool> purchaseCourse(String courseId, {String? sku}) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasMyketNotInstalled = false;

    try {
      final connected = await _ensureInitialized();
      if (!connected) {
        lastErrorWasMyketNotInstalled = true;
        return false;
      }

      final skuToUse = await _resolveSku(courseId, customSku: sku);
      final flowResult = await MyketIAP.launchPurchaseFlow(
        sku: skuToUse,
        payload: "course:$courseId",
      );
      final IabResult? iabResult = flowResult[MyketIAP.RESULT] as IabResult?;
      Purchase? purchase = flowResult[MyketIAP.PURCHASE] as Purchase?;

      if (iabResult != null) {
        if (iabResult.isSuccess() && purchase != null && purchase.mToken.isNotEmpty) {
          return await verifyAndCompletePurchase(
            courseId: courseId,
            purchaseToken: purchase.mToken,
          );
        }

        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_USER_CANCELED ||
            iabResult.mResponse == Constants.IABHELPER_USER_CANCELLED) {
          lastPurchaseWasCancelled = true;
          return false;
        }

        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE ||
            iabResult.mMessage.toLowerCase().contains('not installed')) {
          lastErrorWasMyketNotInstalled = true;
          return false;
        }

        // If already owned in Myket, retrieve existing purchase token and verify
        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED) {
          final queryResult = await MyketIAP.getPurchase(sku: skuToUse);
          purchase = queryResult[MyketIAP.PURCHASE] as Purchase?;
          if (purchase != null && purchase.mToken.isNotEmpty) {
            return await verifyAndCompletePurchase(
              courseId: courseId,
              purchaseToken: purchase.mToken,
            );
          }
        }
      }
    } catch (_) {
      // Graceful fallback on non-Android or cancellation
    }
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId, {String? sku}) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasMyketNotInstalled = false;

    try {
      final connected = await _ensureInitialized();
      if (!connected) {
        lastErrorWasMyketNotInstalled = true;
        return false;
      }

      final skuToUse = await _resolveSku(packageId, customSku: sku);
      final flowResult = await MyketIAP.launchPurchaseFlow(
        sku: skuToUse,
        payload: "package:$packageId",
      );
      final IabResult? iabResult = flowResult[MyketIAP.RESULT] as IabResult?;
      Purchase? purchase = flowResult[MyketIAP.PURCHASE] as Purchase?;

      if (iabResult != null) {
        if (iabResult.isSuccess() && purchase != null && purchase.mToken.isNotEmpty) {
          return await verifyAndCompletePurchase(
            packageId: packageId,
            purchaseToken: purchase.mToken,
          );
        }

        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_USER_CANCELED ||
            iabResult.mResponse == Constants.IABHELPER_USER_CANCELLED) {
          lastPurchaseWasCancelled = true;
          return false;
        }

        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_BILLING_UNAVAILABLE ||
            iabResult.mMessage.toLowerCase().contains('not installed')) {
          lastErrorWasMyketNotInstalled = true;
          return false;
        }

        // If already owned in Myket, retrieve existing purchase token and verify
        if (iabResult.mResponse == Constants.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED) {
          final queryResult = await MyketIAP.getPurchase(sku: skuToUse);
          purchase = queryResult[MyketIAP.PURCHASE] as Purchase?;
          if (purchase != null && purchase.mToken.isNotEmpty) {
            return await verifyAndCompletePurchase(
              packageId: packageId,
              purchaseToken: purchase.mToken,
            );
          }
        }
      }
    } catch (_) {
      // Graceful fallback
    }
    return false;
  }

  @override
  Future<int> restorePurchases() async {
    try {
      final connected = await _ensureInitialized();
      if (!connected) return 0;

      final inventoryRes = await MyketIAP.queryInventory(querySkuDetails: false);
      final inventory = inventoryRes[MyketIAP.INVENTORY] as Inventory?;
      if (inventory == null || inventory.mPurchaseMap.isEmpty) {
        return 0;
      }

      int restoredCount = 0;
      for (final entry in inventory.mPurchaseMap.entries) {
        final purchase = entry.value;
        if (purchase.mToken.isNotEmpty && purchase.mSku.isNotEmpty) {
          final payload = purchase.mDeveloperPayload ?? '';
          final isExplicitPackage = payload.startsWith('package:') || purchase.mSku.contains('pkg') || purchase.mSku.contains('package');

          bool ok = false;
          if (isExplicitPackage) {
            ok = await verifyAndCompletePurchase(
              packageId: purchase.mSku,
              purchaseToken: purchase.mToken,
            );
            if (!ok) {
              ok = await verifyAndCompletePurchase(
                courseId: purchase.mSku,
                purchaseToken: purchase.mToken,
              );
            }
          } else {
            ok = await verifyAndCompletePurchase(
              courseId: purchase.mSku,
              purchaseToken: purchase.mToken,
            );
            if (!ok) {
              ok = await verifyAndCompletePurchase(
                packageId: purchase.mSku,
                purchaseToken: purchase.mToken,
              );
            }
          }

          if (ok) restoredCount++;
        }
      }
      return restoredCount;
    } catch (_) {
      return 0;
    }
  }
}

class DirectPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  DirectPaymentProvider(this.dioClient);

  @override
  String get providerName => 'ZARINPAL';

  String _resolvePaymentUrl(String rawUrl) {
    if (rawUrl.contains('zarinpal.com/pg/StartPay/')) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final authority = uri.pathSegments.last;
        if (authority.isNotEmpty && authority != 'StartPay') {
          final baseUrl = dioClient.dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
          return '$baseUrl/purchases/zarinpal/gateway?authority=$authority';
        }
      }
    }
    return rawUrl;
  }

  @override
  Future<bool> purchaseCourse(String courseId, {String? sku}) async {
    try {
      final response = await dioClient.dio.post('/purchases/zarinpal/request', data: {
        'course_id': courseId,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['already_purchased'] == true) {
          return true;
        }

        final rawPaymentUrl = data['payment_url'] as String?;
        if (rawPaymentUrl != null && rawPaymentUrl.isNotEmpty) {
          final targetUrl = _resolvePaymentUrl(rawPaymentUrl);
          final uri = Uri.parse(targetUrl);
          bool launched = false;
          try {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          if (!launched) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          return launched;
        }
      }
      return false;
    } catch (e) {
      print('ZarinPal purchase exception: $e');
      return false;
    }
  }

  @override
  Future<bool> purchasePackage(String packageId, {String? sku}) async {
    try {
      final response = await dioClient.dio.post('/purchases/zarinpal/package-request', data: {
        'package_id': packageId,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['already_purchased'] == true) {
          return true;
        }

        final rawPaymentUrl = data['payment_url'] as String?;
        if (rawPaymentUrl != null && rawPaymentUrl.isNotEmpty) {
          final targetUrl = _resolvePaymentUrl(rawPaymentUrl);
          final uri = Uri.parse(targetUrl);
          bool launched = false;
          try {
            launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          if (!launched) {
            launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
          return launched;
        }
      }
      return false;
    } catch (e) {
      print('ZarinPal package purchase exception: $e');
      return false;
    }
  }

  @override
  Future<int> restorePurchases() async => 0;
}


