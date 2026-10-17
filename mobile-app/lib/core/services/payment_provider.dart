import 'package:flutter/services.dart';
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_poolakey/flutter_poolakey.dart';
import 'package:myket_iap/myket_iap.dart';
import 'package:myket_iap/util/constants.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/purchase.dart';


abstract class PaymentProvider {
  String get providerName;
  Future<bool> purchaseCourse(String courseId);
  Future<bool> purchasePackage(String packageId);
}

class GooglePlayPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  GooglePlayPaymentProvider(this.dioClient);

  @override
  String get providerName => 'GOOGLE_PLAY';

  @override
  Future<bool> purchaseCourse(String courseId) async {
    // Requires real Google Play Billing verification token
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    // Requires real Google Play Billing verification token
    return false;
  }
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
      return false;
    }
  }

  @override
  Future<bool> purchaseCourse(String courseId) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasBazaarNotInstalled = false;

    final connected = await _ensureConnected();
    if (!connected) {
      lastErrorWasBazaarNotInstalled = true;
      return false;
    }

    try {
      final skuToUse = await _resolveSku(courseId);
      final purchaseInfo = await FlutterPoolakey.purchase(skuToUse);
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
  Future<bool> purchasePackage(String packageId) async {
    lastPurchaseWasCancelled = false;
    lastErrorWasBazaarNotInstalled = false;

    final connected = await _ensureConnected();
    if (!connected) {
      lastErrorWasBazaarNotInstalled = true;
      return false;
    }

    try {
      final skuToUse = await _resolveSku(packageId);
      final purchaseInfo = await FlutterPoolakey.purchase(skuToUse);
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
}

class MyketPaymentProvider implements PaymentProvider {
  final DioClient dioClient;
  final String? rsaKey;
  bool _isInitialized = false;

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
      return false;
    }
  }

  @override
  Future<bool> purchaseCourse(String courseId) async {
    try {
      await _ensureInitialized();
      final flowResult = await MyketIAP.launchPurchaseFlow(sku: courseId);
      final IabResult? iabResult = flowResult[MyketIAP.RESULT] as IabResult?;
      Purchase? purchase = flowResult[MyketIAP.PURCHASE] as Purchase?;

      if (iabResult != null && iabResult.isSuccess() && purchase != null && purchase.mToken.isNotEmpty) {
        return await verifyAndCompletePurchase(
          courseId: courseId,
          purchaseToken: purchase.mToken,
        );
      }

      // If already owned in Myket, retrieve existing purchase token and verify
      if (iabResult?.mResponse == Constants.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED) {
        final queryResult = await MyketIAP.getPurchase(sku: courseId);
        purchase = queryResult[MyketIAP.PURCHASE] as Purchase?;
        if (purchase != null && purchase.mToken.isNotEmpty) {
          return await verifyAndCompletePurchase(
            courseId: courseId,
            purchaseToken: purchase.mToken,
          );
        }
      }
    } catch (_) {
      // Graceful fallback on non-Android or cancellation
    }
    return false;
  }

  @override
  Future<bool> purchasePackage(String packageId) async {
    try {
      await _ensureInitialized();
      final flowResult = await MyketIAP.launchPurchaseFlow(sku: packageId);
      final IabResult? iabResult = flowResult[MyketIAP.RESULT] as IabResult?;
      Purchase? purchase = flowResult[MyketIAP.PURCHASE] as Purchase?;

      if (iabResult != null && iabResult.isSuccess() && purchase != null && purchase.mToken.isNotEmpty) {
        return await verifyAndCompletePurchase(
          packageId: packageId,
          purchaseToken: purchase.mToken,
        );
      }

      // If already owned in Myket, retrieve existing purchase token and verify
      if (iabResult?.mResponse == Constants.BILLING_RESPONSE_RESULT_ITEM_ALREADY_OWNED) {
        final queryResult = await MyketIAP.getPurchase(sku: packageId);
        purchase = queryResult[MyketIAP.PURCHASE] as Purchase?;
        if (purchase != null && purchase.mToken.isNotEmpty) {
          return await verifyAndCompletePurchase(
            packageId: packageId,
            purchaseToken: purchase.mToken,
          );
        }
      }
    } catch (_) {
      // Graceful fallback
    }
    return false;
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
  Future<bool> purchaseCourse(String courseId) async {
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
  Future<bool> purchasePackage(String packageId) async {
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
}


