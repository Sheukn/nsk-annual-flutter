import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_pa_snk/services/sync_service.dart';

class GalleryView extends StatefulWidget {
  final SyncService? syncService;

  const GalleryView({super.key, this.syncService});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryItem {
  final String name;
  final dynamic image; // AssetEntity or File
  final bool isFile;

  _GalleryItem({required this.name, required this.image, required this.isFile});
}

class _Album {
  final String name;
  final AssetPathEntity? assetPath;

  _Album({required this.name, this.assetPath});

  bool isServerAlbum() => assetPath == null;
}

class _GalleryViewState extends State<GalleryView> {
  List<_GalleryItem> _images = [];
  List<_Album> _albums = [];
  _Album? _selectedAlbum;

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GalleryPreviewPage(
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
        await _fetchImages(_albums.first);
      }
    } else {
      if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission refusée pour accéder à la galerie'),
          ),
        );
    }
  }

  Future<void> _fetchAlbums() async {
    // Add server album
    List<_Album> albums = [
      _Album(name: 'Server', assetPath: null),
    ];

    // Add device albums
    List<AssetPathEntity> deviceAlbums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    albums.addAll(
      deviceAlbums.map((album) => _Album(name: album.name, assetPath: album)),
    );

    setState(() {
      _albums = albums;
    });
  }

  Future<void> _fetchImages(_Album album) async {
    List<_GalleryItem> images;

    if (album.isServerAlbum()) {
      // Load images from server directory
      final serverDir = await _getServerDirectory();
      images = await _loadImagesFromDirectory(serverDir);
    } else {
      // Load images from device album
      final assetImages = await album.assetPath!.getAssetListPaged(
        page: 0,
        size: 100,
      );
      images = assetImages
          .map((asset) => _GalleryItem(
                name: asset.title ?? 'Image',
                image: asset,
                isFile: false,
              ))
          .toList();
    }

    setState(() {
      _selectedAlbum = album;
      _images = images;
    });
  }

  Future<Directory> _getServerDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final serverDir = Directory('${appDir.path}/server');
    if (!await serverDir.exists()) {
      await serverDir.create(recursive: true);
    }
    return serverDir;
  }

  Future<List<_GalleryItem>> _loadImagesFromDirectory(Directory dir) async {
    final files = dir.listSync();
    final imageFiles = files
        .where((file) =>
            file is File && _isImageFile(file.path))
        .cast<File>()
        .toList();

    return imageFiles
        .map((file) => _GalleryItem(
              name: file.path.split('/').last,
              image: file,
              isFile: true,
            ))
        .toList();
  }

  bool _isImageFile(String path) {
    final ext = path.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif') ||
        ext.endsWith('.webp');
  }

  @override
  void initState() {
    super.initState();
    _init();
    
    // Listen to sync events and refresh server album when sync completes
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
    // If currently viewing server album, refresh it
    if (_selectedAlbum?.isServerAlbum() ?? false) {
      _fetchImages(_selectedAlbum!);
    }
  }

  Future<void> _uploadCurrentAlbum() async {
    if (widget.syncService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sync service not available')),
      );
      return;
    }

    if (!widget.syncService!.connectionStatus.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Server not connected')),
      );
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos to upload')),
      );
      return;
    }

    // Extract AssetEntity objects from device photos
    final assetsToUpload = _images
        .where((item) => !item.isFile)
        .map((item) => item.image as AssetEntity)
        .toList();

    if (assetsToUpload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No device photos to upload')),
      );
      return;
    }

    // Check how many files are eligible for upload
    final newAssetsCount = await widget.syncService!.countNewAssets(assetsToUpload);
    
    if (newAssetsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No need to upload, all already synced'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    final success = await widget.syncService!.uploadPhotos(assetsToUpload);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Uploaded $newAssetsCount photos successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ma Galerie Locale"),
        actions: [
          // Show upload button for device albums
          if (!(_selectedAlbum?.isServerAlbum() ?? false))
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              tooltip: 'Upload album',
              onPressed: _uploadCurrentAlbum,
            ),
          // Show refresh button for Server album
          if (_selectedAlbum?.isServerAlbum() ?? false)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchImages(_selectedAlbum!);
              },
            ),
        ],
      ),
      drawer: Drawer(
        child: ListView.builder(
          itemCount: _albums.length,
          itemBuilder: (context, index) {
            final album = _albums[index];
            return ListTile(
              title: Text(album.name),
              subtitle: album.isServerAlbum() 
                  ? const Text('Cached on device', style: TextStyle(fontSize: 12))
                  : null,
              selected: album == _selectedAlbum,
              onTap: () async {
                await _fetchImages(album);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      body: Column(
        children: [
          // Show offline indicator for cached photos
          if ((_selectedAlbum?.isServerAlbum() ?? false) && _images.isNotEmpty)
            Container(
              color: Colors.blue[100],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.cloud_done, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Cached - Available offline (${_images.length} photos)',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemCount: _images.length,
              itemBuilder: (context, index) {
                final item = _images[index];
                return GestureDetector(
                  onTap: () => _openGallery(index),
                  child: item.isFile
                      ? Image.file(
                          item.image as File,
                          fit: BoxFit.cover,
                        )
                      : AssetEntityImage(
                          item.image as AssetEntity,
                          isOriginal: false,
                          thumbnailSize: const ThumbnailSize.square(200),
                          fit: BoxFit.cover,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryPreviewPage extends StatelessWidget {
  const _GalleryPreviewPage({
    required this.images,
    required this.initialIndex,
  });

  final List<_GalleryItem> images;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: PhotoViewGallery.builder(
        pageController: PageController(initialPage: initialIndex),
        itemCount: images.length,
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (context, index) {
          final item = images[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: item.isFile
                ? FileImage(item.image as File)
                : AssetEntityImageProvider(
                    item.image as AssetEntity,
                    isOriginal: true,
                  ),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 3,
          );
        },
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
      ),
    );
  }
}

