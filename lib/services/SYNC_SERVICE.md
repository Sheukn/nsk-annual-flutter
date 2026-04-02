# SyncService Documentation

## Overview

`SyncService` is a comprehensive synchronization service for managing photo uploads and downloads between the Flutter app and a remote server. It performs an initial health check at startup, then relies on actual API calls (sync/upload) to detect connection status.

## Features

- **Startup Health Check**: Verifies server connectivity once when app starts
- **Smart Status Detection**: Updates connection status based on actual sync/upload success/failure
- **Background Sync**: Attempts to sync photos periodically (every 2 minutes)
- **Smart Upload Filtering**: Only uploads photos newer than the last sync date
- **Offline Support**: Caches downloaded photos for offline access
- **Reactive Updates**: Uses `ValueNotifier` for real-time UI updates
- **Resilient Error Handling**: Continues syncing even if individual operations fail

## API Endpoints

All endpoints are configured in [ApiConfig](../core/config/api_config.dart):

| Constant | Method | Endpoint | Purpose |
|----------|--------|----------|---------|
| `ApiConfig.syncHealth` | GET | `/api/sync/health` | Check server connectivity |
| `ApiConfig.syncLast` | GET | `/api/sync/last` | Get timestamp of last sync |
| `ApiConfig.photosList` | GET | `/api/photos` | Fetch list of available photos with URLs |
| `ApiConfig.photosBatch` | POST | `/api/photos/batch` | Upload multiple photos (multipart form-data) |

## Public Properties

### `connectionStatus` (ValueNotifier<bool>)
- **Type**: `ValueNotifier<bool>`
- **Default**: `false`
- **Description**: Indicates if the server is currently reachable
- **Usage**: 
  ```dart
  if (syncService.connectionStatus.value) {
    // Server is connected
  }
  ```

### `isSyncing` (ValueNotifier<bool>)
- **Type**: `ValueNotifier<bool>`
- **Default**: `false`
- **Description**: Indicates if a sync operation is in progress
- **Usage**: Show loading indicators while syncing

### `syncCounter` (ValueNotifier<int>)
- **Type**: `ValueNotifier<int>`
- **Default**: `0`
- **Description**: Increments when sync completes, triggers UI refresh
- **Usage**: Listen to know when to refresh gallery

### `isConnected` (bool getter)
- **Type**: `bool`
- **Description**: Shorthand for `connectionStatus.value`

## Public Methods

### `checkServerHealth()`
```dart
Future<void> checkServerHealth()
```
Performs a single health check at app startup to verify server is reachable.

**Usage** (in initState):
```dart
await _syncService.checkServerHealth();
```

### `startAutoSync()`
```dart
void startAutoSync()
```
Starts periodic sync attempts every 2 minutes. Uses actual API calls to detect connection status.

**Updates `connectionStatus`**:
- Sets to `true` if sync succeeds
- Sets to `false` if sync fails

**Usage** (in initState):
```dart
_syncService.startAutoSync();
```

### `stopAutoSync()`
```dart
void stopAutoSync()
```
Stops the periodic sync timer.

**Usage**:
```dart
_syncService.stopAutoSync();
```

### `reconnect()`
```dart
Future<void> reconnect()
```
Manually trigger an immediate sync attempt (when user taps retry button).

**Usage**:
```dart
await _syncService.reconnect(); // Called when user taps retry button
```

### `syncPhotos()`
```dart
Future<void> syncPhotos()
```
Fetches the list of photos from the server and downloads any new ones to local storage.

- Updates `connectionStatus` based on success/failure
- Queries `/api/photos` endpoint for URLs
- Downloads photos to app documents directory (`/server/`)
- Skips files that already exist locally
- Increments `syncCounter` when complete

**Usage**:
```dart
awUpdates `connectionStatus`**:
- Sets to `true` if upload succeeds
- Sets to `false` if upload fails

**ait _syncService.syncPhotos();
```

### `uploadPhotos()`
```dart
Future<bool> uploadPhotos(List<AssetEntity> assets)
```
Uploads selected device photos to the server (only those newer than last sync).

**Parameters**:
- `assets`: List of photos to upload (from device gallery)

**Returns**:
- `true` if upload successful
- `false` if failed or no new assets to upload

**Behavior**:
1. Checks server connection
2. Fetches last sync date from server
3. Filters assets to only include those created after last sync
4. Creates multipart form request with all new assets
5. Sends to `/api/photos/batch` endpoint

**Usage**:
```dart
final success = await syncService.uploadPhotos(selectedPhotos);
if (success) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Upload successful')),
  );
}
```

### `dispose()`
```dart
void dispose()
```
Cleans up resources: stops health check, disposes ValueNotifiers.

**Usage** (in State.dispose()):
```dart
@override
void dispose() {
  syncService.dispose();
  super.dispose();
}
```

## Private Methods

### `_checkHealth()`
Performs a single health check by pinging `/api/sync/health`.

### `_syncPhotos()`
Downloads photos from the server.

### `_downloadPhoto(String url, Directory serverDir)`
Downloads a single photo from the given URL.

### `_getLastSyncDate()`
Fetches the timestamp of the last successful sync from the server.

### `_filterNewAssets(List<AssetEntity> assets, DateTime? lastSyncDate)`
Filters assets to only return those created after `lastSyncDate`.

### `_normalizeUrl(String url)`
Converts localhost URLs to the actual server IP (for WiFi/LAN connectivity).

## Configuration

### API Endpoints
All endpoints are configured in `lib/core/config/api_config.dart`:

```dart
class ApiConfig {
  static const String baseUrl = 'http://192.168.0.29:8081/api';
  
  // Sync endpoints
  static const String syncHealth = '$baseUrl/sync/health';
  static const String syncLast = '$baseUrl/sync/last';
  
  // Photo endpoints
  static const String photosList = '$baseUrl/photos';
  static const String photosBatch = '$baseUrl/photos/batch';
}
```

To change API endpoints, modify the constants in `ApiConfig`.

### Server IP
The base URL uses `192.168.0.29:8081`. Change this in `ApiConfig.baseUrl` for your server address.

### Sync Interval
Update `_healthCheckInterval`:
```dart
static const Duration _healthCheckInterval = Duration(minutes: 2);
```

### Request Timeout
Update `_requestTimeout`:
```dart
static const Duration _requestTimeout = Duration(seconds: 10);
```

## Usage Example

### Basic Setup (in main.dart)
```dart
class _MyHomePageState extends State<MyHomePage> {
  late SyncService _syncService;

  @overridecheckServerHealth(); // One-time check at startup
    _syncService.startAutoSync();     // Start 2-minute sync attempts
  void initState() {
    super.initState();
    _syncService = SyncService();
    _syncService.startHealthCheck();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }
}
```

### Show Connection Status
```dart
ValueListenableBuilder<bool>(
  valueListenable: _syncService.connectionStatus,
  builder: (context, isConnected, child) {
    return Text(
      isConnected ? 'Online' : 'Offline',
      style: TextStyle(color: isConnected ? Colors.green : Colors.red),
    );
  },
)
```

### Handle Sync State
```dart
ValueListenableBuilder<bool>(
  valueListenable: _syncService.isSyncing,
  builder: (context, isSyncing, child) {
    if (isSyncing) {
      return const CircularProgressIndicator();
    }
    return const Icon(Icons.check_circle);
  },
)
```

### Upload Photos
```dart
final success = await _syncService.uploadPhotos(selectedAssets);
if (success) {
  print('Photos uploaded!');
  // UI will automatically refresh via syncCounter listener
}Connection Status Detection
```
App starts
    ↓
checkServerHealth() - Once
    ↓
Ping /api/sync/health
    ↓
Set connectionStatus = (response code 200)

startAutoSync()
    ↓
[Every 2 minutes]
    ↓
syncPhotos() OR uploadPhotos() (actual API calls)
    ↓
Success? → connectionStatus = true
Failure? → connectionStatus = false
```

### Download Sync Flow
```
startAutoSync()
    ↓
[Every 2 minutes] syncPhotos()
    ↓
GET /api/photos
    ↓
Success:
  - Set connectionStatus = true
  - Parse URL list
  - For each URL: _downloadPhoto()
  - Increment syncCounter (triggers UI refresh)

Failure:
  - Set connectionStatus = false
```

### Upload Flow
```
uploadPhotos(assets)
    ↓
CheHow Connection Status Works

Instead of periodic health checks, the service intelligently detects connection status:

**Startup**:
- `checkServerHealth()` - Single health check when app starts
- Sets `connectionStatus` based on response

**Ongoing**:
- `syncPhotos()` and `uploadPhotos()` update `connectionStatus` based on their success/failure
- `connectionStatus = true` if any API call succeeds
- `connectionStatus = false` if any API call fails

**Benefits**:
- ✓ More accurate (real API calls, not just pings)
- ✓ Less bandwidth (no periodic health checks)
- ✓ Faster detection of server issues (failures are detected immediately)
- ✓ Automatic recovery attempts (2-minute sync retries)
    ↓
POST /api/photos/batch
    ↓
Success? → connectionStatus = true
Failure? → connectionStatus = false
Create multipart request
    ↓
POST /api/photos/batch
    ↓
Update isSyncing flag
```

## Error Handling

- **Network errors**: Silently caught, retried on next health check
- **Download fails**: Individual photos are skipped, sync continues
- **Upload fails**: Returns `false`, user can retry manually
- **Invalid response**: Gracefully handled, service continues
- **Missing endpoint**: Service attempts to continue with cached data

## Performance Considerations

- **Incremental Sync**: Only uploads files newer than last sync
- **Resume Support**: Downloaded photos are cached and persist offline
- **Skip Existing**: Doesn't re-download already cached photos
- **Parallel Downloads**: Could be enhanced to download multiple photos concurrently
- **Efficient Filtering**: Only filters assets once per upload operation

## Dependencies

- `dart:async`: Timer management
- `dart:convert`: JSON parsing
- `dart:io`: File I/O
- `package:flutter/foundation.dart`: ValueNotifier
- `package:http`: HTTP requests
- `package:photo_manager`: Photo asset management
- `package:path_provider`: App documents directory

## See Also

- [GalleryView](../gallery/gallery_view.dart) - Uses SyncService for photo downloads
- [ApiConfig](../../core/config/api_config.dart) - Server configuration
