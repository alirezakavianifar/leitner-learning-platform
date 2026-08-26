import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_app/core/network/dio_client.dart';
import 'package:mobile_app/injection_container.dart' as di;

/// Resolves a course, package, or banner image URL against the current base URL,
/// translating relative paths and environment-specific hostnames (like Android emulator localhost).
String? resolveImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  // Local assets, file URIs, or base64 data URIs
  if (trimmed.startsWith('assets/') || trimmed.startsWith('file://') || trimmed.startsWith('data:')) {
    return trimmed;
  }

  String resolved = trimmed;

  // If it's a relative path (e.g. /uploads/..., /images/..., or relative without protocol)
  if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
    String serverBase = '';
    try {
      if (di.sl.isRegistered<DioClient>()) {
        final dioClient = di.sl<DioClient>();
        serverBase = dioClient.dio.options.baseUrl;
      }
    } catch (_) {}

    if (serverBase.isEmpty) {
      if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
        serverBase = 'http://localhost:5217';
      } else {
        serverBase = 'https://api.rightlearn.ir';
      }
    }

    // Strip trailing /api/v1 or /api/v1/
    serverBase = serverBase.replaceAll(RegExp(r'/api/v1/?$'), '').replaceAll(RegExp(r'/$'), '');
    final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    resolved = '$serverBase$cleanPath';
  }

  // Handle Android emulator localhost translation
  if (!kIsWeb && Platform.isAndroid && resolved.contains('localhost')) {
    resolved = resolved.replaceAll('localhost', '10.0.2.2');
  } else if (!kIsWeb && Platform.isWindows && resolved.contains('10.0.2.2')) {
    resolved = resolved.replaceAll('10.0.2.2', 'localhost');
  }

  return resolved;
}
