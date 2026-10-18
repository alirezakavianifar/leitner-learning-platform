import 'dart:convert';
import 'dart:core';

import 'package:flutter/services.dart';
import 'package:myket_iap/util/iab_result.dart';
import 'package:myket_iap/util/inventory.dart';
import 'package:myket_iap/util/purchase.dart';

class MyketIAP {
  static const String PURCHASE = "purchase";
  static const String INVENTORY = "inventory";
  static const String RESULT = "result";
  static const MethodChannel _channel = const MethodChannel('myket');

  static Future<IabResult?> init(
      {required String rsaKey, bool enableDebugLogging = false}) async {
    try {
      final dynamic raw = await _channel.invokeMethod("init", <String, dynamic>{
        'rsa': rsaKey,
        'enableDebugLogging': enableDebugLogging,
      });
      if (raw == null || raw is! String || raw.isEmpty || raw == "null") {
        return null;
      }
      final decoded = json.decode(raw);
      return decoded != null ? IabResult.fromJson(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map> launchPurchaseFlow(
      {required String sku, String? payload}) async {
    try {
      final dynamic map =
          await _channel.invokeMethod("launchPurchaseFlow", <String, dynamic>{
        'sku': sku,
        'payload': payload,
      });
      if (map is! Map) {
        return {RESULT: null, PURCHASE: null};
      }
      final rawPurchase = map["purchase"];
      final rawResult = map["result"];
      final purchaseJson = rawPurchase != null && rawPurchase is String && rawPurchase.isNotEmpty && rawPurchase != "null"
          ? json.decode(rawPurchase)
          : null;
      final resultJson = rawResult != null && rawResult is String && rawResult.isNotEmpty && rawResult != "null"
          ? json.decode(rawResult)
          : null;
      return {
        RESULT: resultJson != null ? IabResult.fromJson(resultJson) : null,
        PURCHASE: purchaseJson != null ? Purchase.fromJson(purchaseJson) : null,
      };
    } catch (_) {
      return {RESULT: null, PURCHASE: null};
    }
  }

  static Future<Map> consume({required Purchase purchase}) async {
    try {
      final dynamic map = await _channel.invokeMethod("consume", <String, dynamic>{
        'purchase': json.encode(purchase.toJson()),
      });
      if (map is! Map) {
        return {RESULT: null, PURCHASE: null};
      }
      final rawPurchase = map["purchase"];
      final rawResult = map["result"];
      final purchaseJson = rawPurchase != null && rawPurchase is String && rawPurchase.isNotEmpty && rawPurchase != "null"
          ? json.decode(rawPurchase)
          : null;
      final resultJson = rawResult != null && rawResult is String && rawResult.isNotEmpty && rawResult != "null"
          ? json.decode(rawResult)
          : null;
      return {
        RESULT: resultJson != null ? IabResult.fromJson(resultJson) : null,
        PURCHASE: purchaseJson != null ? Purchase.fromJson(purchaseJson) : null,
      };
    } catch (_) {
      return {RESULT: null, PURCHASE: null};
    }
  }

  static Future<Map> getPurchase(
      {required String sku, bool querySkuDetails = false}) async {
    try {
      final dynamic map = await _channel.invokeMethod("getPurchase", <String, dynamic>{
        'sku': sku,
        'querySkuDetails': querySkuDetails,
      });
      if (map is! Map) {
        return {RESULT: null, PURCHASE: null};
      }
      final rawPurchase = map["purchase"];
      final rawResult = map["result"];
      final purchaseJson = rawPurchase != null && rawPurchase is String && rawPurchase.isNotEmpty && rawPurchase != "null"
          ? json.decode(rawPurchase)
          : null;
      final resultJson = rawResult != null && rawResult is String && rawResult.isNotEmpty && rawResult != "null"
          ? json.decode(rawResult)
          : null;
      return {
        RESULT: resultJson != null ? IabResult.fromJson(resultJson) : null,
        PURCHASE: purchaseJson != null ? Purchase.fromJson(purchaseJson) : null,
      };
    } catch (_) {
      return {RESULT: null, PURCHASE: null};
    }
  }

  static Future dispose() async {
    try {
      return await _channel.invokeMethod("dispose");
    } catch (_) {
      return null;
    }
  }

  static Future<Map> queryInventory(
      {bool querySkuDetails = false, List<String>? skus}) async {
    try {
      final dynamic map = await _channel.invokeMethod("queryInventory",
          <String, dynamic>{'querySkuDetails': querySkuDetails, 'skus': skus});
      if (map is! Map) {
        return {RESULT: null, INVENTORY: null};
      }
      final rawInventory = map["inventory"];
      final rawResult = map["result"];
      final inventoryJson = rawInventory != null && rawInventory is String && rawInventory.isNotEmpty && rawInventory != "null"
          ? json.decode(rawInventory)
          : null;
      final resultJson = rawResult != null && rawResult is String && rawResult.isNotEmpty && rawResult != "null"
          ? json.decode(rawResult)
          : null;
      return {
        RESULT: resultJson != null ? IabResult.fromJson(resultJson) : null,
        INVENTORY: inventoryJson != null ? Inventory.fromJson(inventoryJson) : null,
      };
    } catch (_) {
      return {RESULT: null, INVENTORY: null};
    }
  }
}
