import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pa_snk/core/config/api_config.dart';

class SyncService {
  static const String _healthEndpoint = ApiConfig.syncHealth;
  static const String _photosEndpoint = ApiConfig.photosList;
  static const String _uploadEndpoint = ApiConfig.photosBatch;
  static const String _lastSyncEndpoint = ApiConfig.syncLast;
  static const Duration _requestTimeout = Duration(seconds: 10);

  Timer? _healthCheckTimer;
  final ValueNotifier<bool> connectionStatus = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> syncCounter = ValueNotifier<int>(0);

  String _normalizeUrl(String url) {
    return url.replaceFirst(
      'http://localhost:8081',
      'http://192.168.0.29:8081',
    );
  }

  Future<void> checkServerHealth() async {
    try {
      final response = await http
          .get(Uri.parse(_healthEndpoint))
          .timeout(_requestTimeout);

      connectionStatus.value = response.statusCode == 200;
    } catch (e) {
      connectionStatus.value = false;
    }
  }

  void startAutoSync() {
    if (_healthCheckTimer != null && _healthCheckTimer!.isActive) {
      return;
    }
    syncPhotos();
    _healthCheckTimer = Timer.periodic(Duration(minutes: 2), (_) {
      syncPhotos();
    });
  }

  void stopAutoSync() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> reconnect() async {
    final response = await http
        .get(Uri.parse(_healthEndpoint))
        .timeout(_requestTimeout);
    
    if (response.statusCode == 200) {
      connectionStatus.value = true;
    } else {
      connectionStatus.value = false;
    }
  }

  Future<void> syncPhotos() async {
    if (isSyncing.value) {
      return;
    }

    isSyncing.value = true;

    try {
      final response = await http
          .get(Uri.parse(_photosEndpoint))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final List<String> photoUrls = jsonList
            .map((item) {
              String url = item['url'] as String;
              return _normalizeUrl(url);
            })
            .toList();

        if (photoUrls.isEmpty) {
          isSyncing.value = false;
          return;
        }

        final serverDir = await _getServerDirectory();
        for (final url in photoUrls) {
          try {
            await _downloadPhoto(url, serverDir);
          } catch (e) {
            continue;
          }
        }
        
        // Delete cached files that no longer exist on server
        await _cleanupStaleCache(photoUrls, serverDir);
        
        connectionStatus.value = true;
        syncCounter.value++;
      } else {
        connectionStatus.value = false;
      }
    } catch (e) {
      connectionStatus.value = false;
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> _downloadPhoto(String url, Directory serverDir) async {
    final fileName = url.split('/').last;
    final filePath = '${serverDir.path}/$fileName';

    final file = File(filePath);
    
    final response = await http.get(Uri.parse(url)).timeout(_requestTimeout);

    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Failed to download: ${response.statusCode}');
    }
  }

  Future<Directory> _getServerDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final serverDir = Directory('${appDir.path}/server');
    if (!await serverDir.exists()) {
      await serverDir.create(recursive: true);
    }
    return serverDir;
  }

  /// Delete cached files that no longer exist on server
  Future<void> _cleanupStaleCache(List<String> serverUrls, Directory serverDir) async {
    try {
      // Extract filenames from server URLs
      final serverFileNames = serverUrls
          .map((url) => url.split('/').last)
          .toSet();

      // Get all cached files
      final cachedFiles = serverDir
          .listSync()
          .whereType<File>()
          .toList();

      // Delete files that are not on server anymore
      for (final file in cachedFiles) {
        final fileName = file.path.split('/').last;
        if (!serverFileNames.contains(fileName)) {
          try {
            await file.delete();
          } catch (e) {
            continue;
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  Future<DateTime?> _getLastSyncDate() async {
    try {
      final response = await http
          .get(Uri.parse(_normalizeUrl(_lastSyncEndpoint)))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final lastSync = json['lastSync'];
        if (lastSync != null) {
          return DateTime.fromMillisecondsSinceEpoch(lastSync as int);
        }
      }
    } catch (e) {
      // Failed to get last sync date, upload all
    }
    return null;
  }

  /// Filter assets to only include those newer than last sync
  Future<List<AssetEntity>> _filterNewAssets(
    List<AssetEntity> assets,
    DateTime? lastSyncDate,
  ) async {
    if (lastSyncDate == null) {
      return assets; // No last sync, upload all
    }

    final newAssets = <AssetEntity>[];
    for (final asset in assets) {
      final createTime = asset.createDateTime;
      if (createTime.isAfter(lastSyncDate)) {
        newAssets.add(asset);
      }
    }
    return newAssets;
  }

  /// Check how many assets are new (eligible for upload)
  Future<int> countNewAssets(List<AssetEntity> assets) async {
    final lastSyncDate = await _getLastSyncDate();
    final newAssets = await _filterNewAssets(assets, lastSyncDate);
    return newAssets.length;
  }

  /// Upload photos to the server
  Future<bool> uploadPhotos(List<AssetEntity> assets) async {
    if (!connectionStatus.value) {
      return false;
    }

    if (assets.isEmpty) {
      return false;
    }

    // Get last sync date and filter new assets
    final lastSyncDate = await _getLastSyncDate();
    final newAssets = await _filterNewAssets(assets, lastSyncDate);

    if (newAssets.isEmpty) {
      return true; // No new assets to upload
    }

    isSyncing.value = true;

    try {
      // Create multipart request
      final uploadUrl = _normalizeUrl(_uploadEndpoint);
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Add each new photo as a file
      for (int i = 0; i < newAssets.length; i++) {
        final asset = newAssets[i];
        final file = await asset.originFile;
        
        if (file != null) {
          request.files.add(
            http.MultipartFile(
              'photos',
              file.readAsBytes().asStream(),
              await file.length(),
              filename: asset.title ?? 'photo_$i',
            ),
          );
        }
      }

      // Send request
      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      final success = response.statusCode == 200 || response.statusCode == 201;
      if (success) {
        // Mark as connected since upload succeeded
        connectionStatus.value = true;
      } else {
        connectionStatus.value = false;
      }
      return success;
    } catch (e) {
      // Mark as disconnected on failure
      connectionStatus.value = false;
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  void dispose() {
    syncCounter.dispose();
    stopAutoSync();
    connectionStatus.dispose();
    isSyncing.dispose();
  }
}
