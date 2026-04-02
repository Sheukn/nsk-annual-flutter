/// Data Transfer Objects for Board API communication
/// Used for serializing/deserializing board data from server

class BoardDto {
  final String id;
  final String name;
  final double height;
  final double width;
  final List<AssetDto> assets;
  final String? previewSrc;

  BoardDto({
    required this.id,
    required this.name,
    required this.height,
    required this.width,
    required this.assets,
    this.previewSrc,
  });

  factory BoardDto.fromJson(Map<String, dynamic> json) {
    return BoardDto(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      height: (json['height'] ?? 0).toDouble(),
      width: (json['width'] ?? 0).toDouble(),
      assets: ((json['assets'] ?? []) as List)
          .map((a) => AssetDto.fromJson(a))
          .toList(),
      previewSrc: json['previewsrc'] ?? json['previewSrc'],
    );
  }
}

class AssetDto {
  final String assetName;
  final String src;
  final double scale;
  final double rotation;
  final double xPosition;
  final double yPosition;

  AssetDto({
    required this.assetName,
    required this.src,
    required this.scale,
    required this.rotation,
    required this.xPosition,
    required this.yPosition,
  });

  factory AssetDto.fromJson(Map<String, dynamic> json) {
    return AssetDto(
      assetName: json['asset_name'] ?? '',
      src: json['src'] ?? '',
      scale: (json['scale'] ?? 1.0).toDouble(),
      rotation: (json['rotation'] ?? 0).toDouble(),
      xPosition: (json['x_position'] ?? 0).toDouble(),
      yPosition: (json['y_position'] ?? 0).toDouble(),
    );
  }
}
