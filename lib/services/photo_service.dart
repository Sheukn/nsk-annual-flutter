import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_pa_snk/core/config/api_config.dart';

class PhotoService {
  static const String _uploadEndpoint = ApiConfig.photosBatch;
  static const String _lastSyncEndpoint = ApiConfig.syncLast;
  static const Duration _requestTimeout = Duration(seconds: 10);

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<int> syncCounter = ValueNotifier<int>(0);

  String _normalizeUrl(String url) {
    return url.replaceFirst(
      'http://localhost:8081',
      'http://192.168.0.29:8081',
    );
  }

  /// Get the last sync date from server
  Future<DateTime?> getLastSyncDate() async {
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
      debugPrint('[PhotoService] Failed to get last sync date: $e');
    }
    return null;
  }

  /// Filter assets to only include those newer than last sync date
  Future<List<AssetEntity>> filterNewAssets(
    List<AssetEntity> assets,
    DateTime? lastSyncDate,
  ) async {
    if (lastSyncDate == null) {
      return assets; // No last sync, return all
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

  /// Count how many assets are new (eligible for upload)
  Future<int> countNewAssets(List<AssetEntity> assets) async {
    final lastSyncDate = await getLastSyncDate();
    final newAssets = await filterNewAssets(assets, lastSyncDate);
    return newAssets.length;
  }

  /// Upload photos to the server
  Future<bool> uploadPhotos(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return false;
    }

    // Get last sync date and filter new assets
    final lastSyncDate = await getLastSyncDate();
    final newAssets = await filterNewAssets(assets, lastSyncDate);

    if (newAssets.isEmpty) {
      debugPrint('[PhotoService] No new photos to upload');
      return true;
    }

    isSyncing.value = true;
    debugPrint('[PhotoService] Uploading ${newAssets.length} photos...');

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
        syncCounter.value++;
        debugPrint('[PhotoService] Upload successful');
      } else {
        debugPrint('[PhotoService] Upload failed: ${response.statusCode}');
      }
      return success;
    } catch (e) {
      debugPrint('[PhotoService] Upload error: $e');
      return false;
    } finally {
      isSyncing.value = false;
    }
  }

  /// Download a photo from server to local directory (overwrites if exists)
  Future<void> downloadPhoto(String url, Directory targetDir) async {
    try {
      final fileName = url.split('/').last;
      final filePath = '${targetDir.path}/$fileName';
      final file = File(filePath);
      
      final normalizedUrl = _normalizeUrl(url);
      final response = await http.get(Uri.parse(normalizedUrl)).timeout(_requestTimeout);
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      }
    } catch (e) {
      debugPrint('[PhotoService] Failed to download photo: $e');
    }
  }

  /// Get list of photo URLs from server
  Future<List<String>> getServerPhotoList() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.photosList)).timeout(_requestTimeout);
      if (response.statusCode != 200) return [];
      
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList
          .map((item) => _normalizeUrl(item['url'] as String))
          .toList();
    } catch (e) {
      debugPrint('[PhotoService] Failed to get server photo list: $e');
      return [];
    }
  }

  /// Get the server cache directory
  Future<Directory> getServerDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final serverDir = Directory('${appDir.path}/server');
    if (!await serverDir.exists()) {
      await serverDir.create(recursive: true);
    }
    return serverDir;
  }

  void dispose() {
    isSyncing.dispose();
    syncCounter.dispose();
  }
}
