import 'package:photo_manager/photo_manager.dart';

class GalleryItem {
  final String name;
  final dynamic image; // AssetEntity or File
  final bool isFile;
  final DateTime createDate;

  GalleryItem({
    required this.name,
    required this.image,
    required this.isFile,
    required this.createDate,
  });
}

class Album {
  final String name;
  final AssetPathEntity? assetPath;

  Album({required this.name, this.assetPath});

  bool isServerAlbum() => assetPath == null;
}
