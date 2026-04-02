import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_pa_snk/core/config/api_config.dart';

class ConnectionService {
  static const String _healthEndpoint = ApiConfig.syncHealth;
  static const Duration _requestTimeout = Duration(seconds: 10);

  Timer? _healthCheckTimer;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);

  String _normalizeUrl(String url) {
    return url.replaceFirst(
      'http://localhost:8081',
      'http://192.168.0.29:8081',
    );
  }

  /// Check server health once
  Future<void> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse(_normalizeUrl(_healthEndpoint)))
          .timeout(_requestTimeout);

      connectionStatus.value = response.statusCode == 200;
      debugPrint('[ConnectionService] Health check: ${response.statusCode}');
    } catch (e) {
      connectionStatus.value = false;
      debugPrint('[ConnectionService] Health check failed: $e');
    }
  }

  /// Start periodic health checks
  void startHealthCheck() {
    if (_healthCheckTimer != null && _healthCheckTimer!.isActive) {
      return;
    }
    checkServerHealth();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 2), (_) {
      checkServerHealth();
    });
  }

  /// Stop periodic health checks
  void stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Manually reconnect and update status
  Future<void> reconnect() async {
    debugPrint('[ConnectionService] Attempting reconnect...');
    await checkServerHealth();
  }

  void dispose() {
    stopHealthCheck();
    connectionStatus.dispose();
  }
}
