import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'dart:io';
import 'package:flutter_pa_snk/features/gallery/models/gallery_models.dart';
import 'package:flutter_pa_snk/features/gallery/widgets/video_player_widget.dart';

class GalleryPreviewPage extends StatefulWidget {
  const GalleryPreviewPage({
    required this.images,
    required this.initialIndex,
  });

  final List<GalleryItem> images;
  final int initialIndex;

  @override
  State<GalleryPreviewPage> createState() => _GalleryPreviewPageState();
}

class _GalleryPreviewPageState extends State<GalleryPreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoFile(GalleryItem item) {
    String path = '';
    
    if (item.isFile) {
      path = (item.image as File).path;
    } else {
      // For AssetEntity, use the name
      final asset = item.image as AssetEntity;
      path = asset.title ?? '';
    }
    
    final ext = path.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.flv') ||
        ext.endsWith('.wmv') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.3gp') ||
        ext.endsWith('.m4v');
  }

  Future<File?> _getVideoFile(GalleryItem item) async {
    if (item.isFile) {
      return item.image as File;
    } else {
      // For AssetEntity, get the file
      final asset = item.image as AssetEntity;
      return await asset.file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 2,
      ),
      body: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: widget.images.length,
        scrollPhysics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        builder: (context, index) {
          final item = widget.images[index];
          final isVideo = _isVideoFile(item);
          
          if (isVideo) {
            // Show video player for both File and AssetEntity videos
            return PhotoViewGalleryPageOptions.customChild(
              child: FutureBuilder<File?>(
                future: _getVideoFile(item),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                    return VideoPlayerWidget(
                      videoFile: snapshot.data!,
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.white.withOpacity(0.7),
                            size: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load video',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.7),
                        ),
                      ),
                    );
                  }
                },
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
            );
          }
          
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
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
      ),
    );
  }
}
