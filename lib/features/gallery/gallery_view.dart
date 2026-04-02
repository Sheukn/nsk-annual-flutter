import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_pa_snk/services/sync_service.dart';
import 'package:flutter_pa_snk/core/config/api_config.dart';
import 'package:flutter_pa_snk/features/gallery/models/gallery_models.dart';
import 'package:flutter_pa_snk/features/gallery/pages/gallery_preview_page.dart';

class GalleryView extends StatefulWidget {
  final SyncService? syncService;

  const GalleryView({super.key, this.syncService});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  List<GalleryItem> _images = [];
  List<Album> _albums = [];
  Album? _selectedAlbum;
  bool _groupByMonth = false;

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryPreviewPage(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _init() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      await _fetchAlbums();
      if (_albums.isNotEmpty) {
        final deviceAlbumIndex = _albums.indexWhere((album) => !album.isServerAlbum());
        final albumToLoad = deviceAlbumIndex > -1 ? _albums[deviceAlbumIndex] : _albums.first;
        await _fetchImages(albumToLoad);
      }
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery')),
      );
    }
  }

  Future<void> _fetchAlbums() async {
    List<Album> albums = [Album(name: 'Server', assetPath: null)];
    List<AssetPathEntity> deviceAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.all,
    );
    albums.addAll(
      deviceAlbums.map((album) => Album(name: album.name, assetPath: album)),
    );
    setState(() => _albums = albums);
  }

  Future<void> _fetchImages(Album album) async {
    List<GalleryItem> images;

    if (album.isServerAlbum()) {
      final serverDir = await _getServerDirectory();
      final serverPhotoUrls = await _getServerPhotoList();
      final serverFileNames = serverPhotoUrls.map((url) => url.split('/').last).toSet();

      images = await _loadImagesFromDirectory(serverDir);

      for (final item in images) {
        if (item.isFile) {
          final fileName = (item.image as File).path.split('/').last;
          if (!serverFileNames.contains(fileName)) {
            try {
              await (item.image as File).delete();
            } catch (e) {
              debugPrint('[Gallery] Failed to delete stale file: $e');
            }
          }
        }
      }

      images = await _loadImagesFromDirectory(serverDir);
    } else {
      final assetImages = await album.assetPath!.getAssetListPaged(page: 0, size: 100);
      images = assetImages.map((asset) => GalleryItem(
            name: asset.title ?? 'Media',
            image: asset,
            isFile: false,
            createDate: asset.createDateTime,
          )).toList();
    }

    setState(() {
      _selectedAlbum = album;
      _images = images.reversed.toList();
    });
  }

  Future<List<String>> _getServerPhotoList() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.photosList)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        return jsonList.map((item) {
          String url = item['url'] as String;
          return url.replaceFirst('http://localhost:8081', 'http://192.168.0.29:8081');
        }).toList();
      }
    } catch (e) {
      debugPrint('[Gallery] Error fetching server photo list: $e');
    }
    return [];
  }

  Future<Directory> _getServerDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final serverDir = Directory('${appDir.path}/server');
    if (!await serverDir.exists()) {
      await serverDir.create(recursive: true);
    }
    return serverDir;
  }

  Future<List<GalleryItem>> _loadImagesFromDirectory(Directory dir) async {
    final files = dir.listSync();
    final mediaFiles = files.where((file) => file is File && _isMediaFile(file.path)).cast<File>().toList();

    return mediaFiles.map((file) => GalleryItem(
          name: file.path.split('/').last,
          image: file,
          isFile: true,
          createDate: file.lastModifiedSync(),
        )).toList();
  }

  bool _isMediaFile(String path) {
    final ext = path.toLowerCase();
    final isImage = ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || 
                    ext.endsWith('.gif') || ext.endsWith('.webp');
    final isVideo = ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || 
                    ext.endsWith('.mkv') || ext.endsWith('.flv') || ext.endsWith('.wmv') || 
                    ext.endsWith('.webm') || ext.endsWith('.3gp') || ext.endsWith('.m4v');
    return isImage || isVideo;
  }

  bool _isVideoFile(GalleryItem item) {
    final path = item.isFile ? (item.image as File).path : '';
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') || ext.endsWith('.mov') || ext.endsWith('.avi') || 
           ext.endsWith('.mkv') || ext.endsWith('.flv') || ext.endsWith('.wmv') || 
           ext.endsWith('.webm') || ext.endsWith('.3gp') || ext.endsWith('.m4v');
  }

  @override
  void initState() {
    super.initState();
    _init();
    if (widget.syncService != null) {
      widget.syncService!.syncCounter.addListener(_onSyncComplete);
    }
  }

  @override
  void dispose() {
    if (widget.syncService != null) {
      widget.syncService!.syncCounter.removeListener(_onSyncComplete);
    }
    super.dispose();
  }

  void _onSyncComplete() {
    if (_selectedAlbum?.isServerAlbum() ?? false) {
      _fetchImages(_selectedAlbum!);
    }
  }

  Future<void> _uploadCurrentAlbum() async {
    if (widget.syncService == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync service not available')));
      return;
    }

    if (!widget.syncService!.connectionStatus.value) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Server not connected')));
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No photos to upload')));
      return;
    }

    final assetsToUpload = _images.where((item) => !item.isFile).map((item) => item.image as AssetEntity).toList();

    if (assetsToUpload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No device photos to upload')));
      return;
    }

    final newAssetsCount = await widget.syncService!.countNewAssets(assetsToUpload);

    if (newAssetsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No need to upload, all already synced'), backgroundColor: Colors.blue),
      );
      return;
    }

    final success = await widget.syncService!.uploadPhotos(assetsToUpload);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $newAssetsCount photos successfully'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed'), backgroundColor: Colors.red),
      );
    }
  }

  Map<String, List<GalleryItem>> _groupImagesByMonthDay() {
    final groupedMap = <String, List<GalleryItem>>{};
    for (final item in _images) {
      final date = item.createDate;
      final key = _groupByMonth
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}'
          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!groupedMap.containsKey(key)) {
        groupedMap[key] = [];
      }
      groupedMap[key]!.add(item);
    }
    return groupedMap;
  }

  String _formatDateHeader(String dateStr) {
    final parts = dateStr.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthNames = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'];
    if (_groupByMonth) {
      return '${monthNames[month]} $year';
    } else {
      final day = int.parse(parts[2]);
      return '${monthNames[month]} $day, $year';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(_groupByMonth ? Icons.calendar_month : Icons.calendar_today),
            tooltip: _groupByMonth ? 'Group by day' : 'Group by month',
            onPressed: () => setState(() => _groupByMonth = !_groupByMonth),
          ),
          if (!(_selectedAlbum?.isServerAlbum() ?? false))
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: 'Upload album',
              onPressed: _uploadCurrentAlbum,
            ),
          if (_selectedAlbum?.isServerAlbum() ?? false)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _fetchImages(_selectedAlbum!),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.image, size: 40),
                    SizedBox(height: 12),
                    Text('Albums', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _albums.length,
                  itemBuilder: (context, index) {
                    final album = _albums[index];
                    final isSelected = album == _selectedAlbum;
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      title: Text(album.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      subtitle: album.isServerAlbum() ? const Text('Cached on device', style: TextStyle(fontSize: 12)) : null,
                      selected: isSelected,
                      selectedTileColor: Colors.deepPurple.withAlpha(30),
                      leading: Icon(album.isServerAlbum() ? Icons.cloud_done : Icons.photo_album, color: isSelected ? Colors.deepPurple : null),
                      onTap: () async {
                        await _fetchImages(album);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if ((_selectedAlbum?.isServerAlbum() ?? false) && _images.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                border: Border.all(color: Colors.blue[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.blue[700], size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cached Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('${_images.length} photos available offline', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (_images.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text('No photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text('Photos will appear here', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: () {
                  final sorted = _groupImagesByMonthDay().entries.toList();
                  sorted.sort((a, b) => b.key.compareTo(a.key));
                  return sorted.map((entry) {
                    final dateStr = entry.key;
                    final items = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                          child: Text(_formatDateHeader(dateStr), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final globalIndex = _images.indexOf(item);
                            return GestureDetector(
                              onTap: () => _openGallery(globalIndex),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: const Offset(0, 2))],
                                  ),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      item.isFile
                                          ? Image.file(item.image as File, fit: BoxFit.cover)
                                          : AssetEntityImage(item.image as AssetEntity, isOriginal: false, thumbnailSize: const ThumbnailSize.square(200), fit: BoxFit.cover),
                                      if (_isVideoFile(item))
                                        Container(
                                          color: Colors.black.withOpacity(0.3),
                                          child: Center(child: Icon(Icons.play_circle_outline, color: Colors.white.withOpacity(0.8), size: 40)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  }).toList();
                }(),
              ),
            ),
        ],
      ),
    );
  }
}

