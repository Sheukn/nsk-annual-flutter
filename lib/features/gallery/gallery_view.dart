import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'dart:io';
import 'package:flutter_pa_snk/services/photo_service.dart';
import 'package:flutter_pa_snk/features/gallery/models/gallery_models.dart';
import 'package:flutter_pa_snk/features/gallery/pages/gallery_preview_page.dart';

class GalleryView extends StatefulWidget {
  final PhotoService? photoService;

  const GalleryView({super.key, this.photoService});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  static const List<String> _imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static const List<String> _videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.flv', '.wmv', '.webm', '.3gp', '.m4v'];

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
    if (!ps.isAuth) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access gallery')),
      );
      return;
    }

    await _fetchAlbums();
    if (_albums.isNotEmpty) {
      final firstDeviceAlbum = _albums.firstWhere(
        (album) => !album.isServerAlbum(),
        orElse: () => _albums.first,
      );
      await _fetchImages(firstDeviceAlbum);
    }
  }

  Future<void> _fetchAlbums() async {
    final deviceAlbums = await PhotoManager.getAssetPathList(type: RequestType.all);
    final albums = [
      Album(name: 'Server', assetPath: null),
      ...deviceAlbums.map((a) => Album(name: a.name, assetPath: a)),
    ];
    setState(() => _albums = albums);
  }

  Future<void> _fetchImages(Album album) async {
    List<GalleryItem> images = [];
    try {
      if (album.isServerAlbum()) {
        final serverDir = await widget.photoService!.getServerDirectory();
        
        final serverPhotoUrls = await widget.photoService!.getServerPhotoList();
        final serverFileNames = serverPhotoUrls.map((url) => url.split('/').last).toSet();
        
        // Delete stale files from cache
        final cachedFiles = await _loadImagesFromDirectory(serverDir);
        for (final item in cachedFiles.where((i) => i.isFile)) {
          final fileName = (item.image as File).path.split('/').last;
          if (!serverFileNames.contains(fileName)) {
            await (item.image as File).delete().catchError((_) => item.image as File);
          }
        }
        
        // Download new photos from server ONLY if server album is still selected
        if (widget.photoService != null && _selectedAlbum?.isServerAlbum() == true) {
          for (final url in serverPhotoUrls) {
            await widget.photoService!.downloadPhoto(url, serverDir);
          }
        }
        
        // Load all photos from cache
        images = await _loadImagesFromDirectory(serverDir);
        final assets = await album.assetPath!.getAssetListPaged(page: 0, size: 100);
        images = assets
            .map((a) => GalleryItem(name: a.title ?? 'Media', image: a, isFile: false, createDate: a.createDateTime))
            .toList();
      }
    } catch (e) {
      print('[GalleryView] ERROR fetching images: $e');
      if (album.isServerAlbum() && widget.photoService != null) {
        images = await _loadImagesFromDirectory(await widget.photoService!.getServerDirectory());
      }
    }

    setState(() {
      _selectedAlbum = album;
      _images = images.reversed.toList();
    });
  }

  Future<List<GalleryItem>> _loadImagesFromDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) return [];
      
      return dir
          .listSync()
          .whereType<File>()
          .where((f) => _isMediaFile(f.path))
          .map((f) => GalleryItem(
            name: f.path.split('/').last,
            image: f,
            isFile: true,
            createDate: f.lastModifiedSync(),
          ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  bool _isMediaFile(String path) {
    final ext = path.toLowerCase();
    return _imageExtensions.any(ext.endsWith) || _videoExtensions.any(ext.endsWith);
  }

  bool _isVideoFile(GalleryItem item) {
    final ext = item.isFile ? (item.image as File).path.toLowerCase() : '';
    return _videoExtensions.any(ext.endsWith);
  }

  @override
  void initState() {
    super.initState();
    _init();
    if (widget.photoService != null) {
      widget.photoService!.syncCounter.addListener(_onSyncComplete);
    }
  }

  @override
  void dispose() {
    if (widget.photoService != null) {
      widget.photoService!.syncCounter.removeListener(_onSyncComplete);
    }
    super.dispose();
  }

  void _onSyncComplete() {
    if (_selectedAlbum?.isServerAlbum() ?? false) {
      _fetchImages(_selectedAlbum!);
    }
  }

  Future<void> _uploadCurrentAlbum() async {
    if (widget.photoService == null || _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.photoService == null ? 'Photo service not available' : 'No photos to upload')),
      );
      return;
    }

    final assets = _images.where((i) => !i.isFile).map((i) => i.image as AssetEntity).toList();
    if (assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No device photos to upload')));
      return;
    }

    final count = await widget.photoService!.countNewAssets(assets);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All photos already synced'), backgroundColor: Colors.blue),
      );
      return;
    }

    final success = await widget.photoService!.uploadPhotos(assets);
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Uploaded $count photos' : 'Upload failed'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Map<String, List<GalleryItem>> _groupImagesByMonthDay() {
    final groups = <String, List<GalleryItem>>{};
    for (final item in _images) {
      final d = item.createDate;
      final key = _groupByMonth
          ? '${d.year}-${d.month.toString().padLeft(2, '0')}'
          : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      (groups[key] ??= []).add(item);
    }
    return groups;
  }

  String _formatDateHeader(String dateStr) {
    final parts = dateStr.split('-');
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = monthNames[int.parse(parts[1]) - 1];
    final year = parts[0];
    
    if (_groupByMonth) return '$month $year';
    return '$month ${parts[2]}, $year';
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
            onPressed: () => setState(() => _groupByMonth = !_groupByMonth),
          ),
          if (!(_selectedAlbum?.isServerAlbum() ?? false))
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: _uploadCurrentAlbum,
            ),
          if (_selectedAlbum?.isServerAlbum() ?? false)
            IconButton(
              icon: const Icon(Icons.refresh),
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
                    if (_selectedAlbum?.isServerAlbum() ?? false)
                      Text('Check server connection at 192.168.0.29:8081', style: TextStyle(fontSize: 12, color: Colors.orange[700]))
                    else
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

