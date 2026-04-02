import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class GalleryView extends StatefulWidget {
  const GalleryView({super.key});

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  List<AssetEntity> _images = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;

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
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );
    setState(() {
      _albums = albums;
    });
  }

  Future<void> _fetchImages(AssetPathEntity album) async {
    List<AssetEntity> images = await album.getAssetListPaged(
      page: 0,
      size: 100,
    );
    setState(() {
      _selectedAlbum = album;
      _images = images;
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ma Galerie Locale")),
      drawer: Drawer(
        child: ListView.builder(
          itemCount: _albums.length,
          itemBuilder: (context, index) {
            final album = _albums[index];
            return ListTile(
              title: Text(album.name),
              selected: album == _selectedAlbum,
              onTap: () async {
                List<AssetEntity> images = await album.getAssetListPaged(
                  page: 0,
                  size: 100,
                );
                setState(() {
                  _selectedAlbum = album;
                  _images = images;
                });
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
        ),
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final asset = _images[index];
          return GestureDetector(
            onTap: () => _openGallery(index),
            child: AssetEntityImage(
              asset,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(200),
              fit: BoxFit.cover,
            ),
          );
        },
      ),
    );
  }
}

class _GalleryPreviewPage extends StatelessWidget {
  const _GalleryPreviewPage({
    required this.images,
    required this.initialIndex,
  });

  final List<AssetEntity> images;
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
          final asset = images[index];
          return PhotoViewGalleryPageOptions(
            imageProvider: AssetEntityImageProvider(
              asset,
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

