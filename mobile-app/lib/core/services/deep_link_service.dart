import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:mobile_app/core/diagnostics/app_logger.dart';

class PaymentResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? refId;
  final String? rawStatus;

  PaymentResult({
    required this.isSuccess,
    required this.isCancelled,
    this.refId,
    this.rawStatus,
  });

  @override
  String toString() => 'PaymentResult(isSuccess: $isSuccess, isCancelled: $isCancelled, refId: $refId, rawStatus: $rawStatus)';
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  final StreamController<PaymentResult> _paymentResultController = StreamController<PaymentResult>.broadcast();

  Stream<PaymentResult> get paymentResults => _paymentResultController.stream;

  Future<void> init() async {
    try {
      // Check initial deep link on application cold start
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        AppLogger().info('DeepLinkService: Received initial cold-start deep link: $initialUri');
        _handleUri(initialUri);
      }

      // Listen for incoming deep links while app is running in background or foreground
      _sub = _appLinks.uriLinkStream.listen(
        (uri) {
          AppLogger().info('DeepLinkService: Received incoming runtime deep link: $uri');
          _handleUri(uri);
        },
        onError: (err, stack) {
          AppLogger().error('DeepLinkService: Error in deep link stream: $err', err, stack);
        },
      );
    } catch (e, stack) {
      AppLogger().error('DeepLinkService: Initialization error: $e', e, stack);
    }
  }

  void _handleUri(Uri uri) {
    if (uri.scheme == 'leitnerapp') {
      final host = uri.host; // 'payment-result'
      final path = uri.path; // or '/payment-result'

      if (host == 'payment-result' || path.contains('payment-result')) {
        final status = uri.queryParameters['status']?.toLowerCase();
        final refId = uri.queryParameters['ref_id'] ?? uri.queryParameters['refId'];

        final isSuccess = status == 'success' || status == 'ok';
        final isCancelled = status == 'cancelled' || status == 'cancel';

        final result = PaymentResult(
          isSuccess: isSuccess,
          isCancelled: isCancelled,
          refId: refId,
          rawStatus: status,
        );

        AppLogger().info('DeepLinkService: Dispatched PaymentResult: $result');
        _paymentResultController.add(result);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _paymentResultController.close();
  }
}
