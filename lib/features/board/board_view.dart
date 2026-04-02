import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_pa_snk/data/sources/local/database_helper.dart';
import 'package:flutter_pa_snk/features/postit/postit_edit_view.dart';
import 'package:flutter_pa_snk/models/board_item.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_pa_snk/services/board_service.dart';
import 'widgets/board_item_widget.dart';
import 'widgets/control_sliders.dart';
import 'widgets/board_action_menu.dart';
import 'package:uuid/uuid.dart';

class BoardView extends StatefulWidget {
  final String boardId;
  final String boardName;

  const BoardView({
    super.key,
    required this.boardId,
    required this.boardName,
  });

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  static const double _boardWidth = 1000;
  static const double _boardHeight = 1000;
  final GlobalKey _boardRepaintKey = GlobalKey();
  late TransformationController _transformationController;

  final List<BoardItem> _items = [];
  final List<BoardItem> _selectedItem = [];
  final DatabaseService _databaseService = DatabaseService();
  final BoardService _networkService = BoardService();

  BoardItem? get activeItem =>
      _selectedItem.length == 1 ? _selectedItem.first : null;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _loadBoardItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerBoard();
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _centerBoard() {
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = AppBar().preferredSize.height;
    final viewportWidth = screenSize.width;
    final viewportHeight = screenSize.height - appBarHeight;

    final scaleX = viewportWidth / _boardWidth;
    final scaleY = viewportHeight / _boardHeight;
    final scale = (scaleX < scaleY ? scaleY : scaleY) * 0.9;

    final boardScaledWidth = _boardWidth * scale;
    final boardScaledHeight = _boardHeight * scale;
    final translateX = (viewportWidth - boardScaledWidth) / 2;
    final translateY = (viewportHeight - boardScaledHeight) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.boardName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        elevation: 8,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveBoard,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade400,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.cloud_upload, color: Colors.white),
              onPressed: _uploadBoard,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            constrained: false,
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.1,
            maxScale: 2.5,
            child: Container(
              color: Colors.transparent,
              child: RepaintBoundary(
                key: _boardRepaintKey,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFE8D4B8),
                        const Color(0xFFF5E6D3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  width: _boardWidth,
                  height: _boardHeight,
                  child: Stack(
                    children:
                        _items
                            .map(
                              (item) => BoardItemWidget(
                                item: item,
                                isSelected: _selectedItem.contains(item),
                                onTap: () => _handleItemTap(item),
                                onLongPress: () => _handleItemLongPress(item),
                                onScaleStart:
                                    (details) =>
                                        _handleItemScaleStart(item, details),
                                onScaleUpdate:
                                    (details) =>
                                        _handleItemScaleUpdate(item, details),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ),
            ),
          if (_selectedItem.length == 1 && activeItem != null) ...[
            RotationSlider(
              rotation: activeItem!.rotation,
              onChanged: (value) async {
                setState(() => activeItem!.rotation = value);
                await _databaseService.updateBoardAssetPosition(
                  boardId: widget.boardId,
                  assetName: activeItem!.id,
                  x: activeItem!.position.x,
                  y: activeItem!.position.y,
                  rotation: value,
                );
              },
            ),
            SizeSlider(
              width: activeItem!.size.width,
              onChanged:
                  (value) => setState(() {
                    activeItem!.size = Size(
                      width: value,
                      height:
                          value *
                          (activeItem!.size.height / activeItem!.size.width),
                    );
                  }),
            ),
          ],
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: IgnorePointer(
                ignoring: false,
                child: Material(
                  color: Colors.transparent,
                  child: BoardActionMenu(
                    selectedItems: _selectedItem,
                    onAddImage: _addImage,
                    onAddPostIt: _addPostIt,
                    onDelete: _deleteSelected,
                    onBringToFront: _bringToFront,
                    onSendToBack: _sendToBack,
                    onEdit:
                        _selectedItem.length == 1
                            ? (_selectedItem.first.isImage ? () => _pickGalleryImageForItem(_selectedItem.first) : _editPostIt)
                            : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleItemTap(BoardItem item) {
    setState(() {
      if (_selectedItem.length == 1 && !_selectedItem.contains(item)) {
        _selectedItem.clear();
        _selectedItem.add(item);
      } else {
        if (_selectedItem.contains(item)) {
          _selectedItem.remove(item);
        } else {
          _selectedItem.add(item);
        }
      }
    });
  }

  void _handleItemLongPress(BoardItem item) {
    if (item.isImage) {
      _pickGalleryImageForItem(item);
    } else {
      setState(() {
        if (_selectedItem.contains(item)) {
          _selectedItem.remove(item);
        } else {
          _selectedItem.add(item);
        }
      });
    }
  }

  void _handleItemScaleStart(BoardItem item, ScaleStartDetails details) {
    if (_selectedItem.contains(item) && _selectedItem.length == 1) {
      item.size = Size(width: item.size.width, height: item.size.height);
      item.position = Position(x: item.position.x, y: item.position.y);
    }
  }

  void _handleItemScaleUpdate(BoardItem item, ScaleUpdateDetails details) {
    setState(() {
      item.position.x += details.focalPointDelta.dx;
      item.position.y += details.focalPointDelta.dy;
    });
    _databaseService.updateBoardAssetPosition(
      boardId: widget.boardId,
      assetName: item.id,
      x: item.position.x,
      y: item.position.y,
      rotation: item.rotation,
    );
  }
  final _uuid = const Uuid();

  /// Opens a bottom-sheet gallery picker and returns the chosen asset.
  Future<AssetEntity?> _showGalleryPicker() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery permission denied')),
        );
      }
      return null;
    }

    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isEmpty) return null;

    List<AssetEntity> images = await albums.first.getAssetListPaged(
      page: 0,
      size: 100,
    );

    if (!mounted) return null;

    final AssetEntity? picked = await showModalBottomSheet<AssetEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: images.length,
                    itemBuilder: (_, i) {
                      final asset = images[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(ctx).pop(asset),
                        child: FutureBuilder<Uint8List?>(
                          future: asset.thumbnailDataWithSize(
                            const ThumbnailSize.square(200),
                          ),
                          builder: (_, snap) {
                            if (snap.hasData && snap.data != null) {
                              return Image.memory(
                                snap.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return Container(color: Colors.white10);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return picked;
  }

  void _addImage() async {
    final asset = await _showGalleryPicker();
    if (asset == null) return;

    final file = await asset.file;
    if (file == null) return;
    final filePath = file.path;

    final id = _uuid.v4();
    final aspect = asset.width > 0 && asset.height > 0 ? (asset.width / asset.height) : (4.0 / 3.0);
    final width = 200.0;
    final height = width / aspect;

    final item = BoardItem(
      id: id,
      position: Position(x: 400, y: 400),
      size: Size(width: width, height: height),
      color: Colors.transparent, // transparent for images so no background
      rotation: 0,
      isImage: true,
      imagePath: filePath,
    );

    // Immediately insert into DB so the link is persisted.
    await _databaseService.insertBoardAsset(
      boardId: widget.boardId,
      assetName: id,
      x: item.position.x,
      y: item.position.y,
      rotation: item.rotation,
      src: filePath,
    );

    if (!mounted) return;
    setState(() {
      _items.add(item);
    });
  }

  /// Opens gallery picker for an existing image item and updates DB + state.
  void _pickGalleryImageForItem(BoardItem item) async {
    final asset = await _showGalleryPicker();
    if (asset == null) return;

    final file = await asset.file;
    if (file == null) return;
    final filePath = file.path;

    await _databaseService.updateBoardAssetSrc(
      boardId: widget.boardId,
      assetName: item.id,
      src: filePath,
    );

    if (!mounted) return;
    setState(() {
      item.imagePath = filePath;
      item.color = Colors.transparent;
      if (asset.width > 0 && asset.height > 0) {
        final aspect = asset.width / asset.height;
        item.size = Size(width: item.size.width, height: item.size.width / aspect);
      }
    });
  }

  void _addPostIt() {
    final id = _uuid.v4();
    setState(() {
      _items.add(
        BoardItem(
          id: id,
          position: Position(x: 400, y: 400),
          size: Size(width: 150, height: 150),
          color: Colors.yellow,
          rotation: 0,
          isImage: false,
          imagePath: "postit_$id.png",
        ),
      );
    });
  }

  void _deleteSelected() {
    setState(() {
      _items.removeWhere((item) => _selectedItem.contains(item));
      _selectedItem.clear();
    });
  }

  void _changeColor() {
    setState(() {
      for (var item in _selectedItem) {
        item.color =
            Colors.primaries[DateTime.now().millisecondsSinceEpoch %
                Colors.primaries.length];
      }
    });
  }

  void _bringToFront() {
    setState(() {
      for (var item in _selectedItem) {
        _items.remove(item);
        _items.add(item);
      }
    });
  }

  void _sendToBack() {
    setState(() {
      for (var item in _selectedItem) {
        _items.remove(item);
        _items.insert(0, item);
      }
    });
  }

  void _editPostIt() async {
    final Map<String, dynamic>? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostItEditView(id: _selectedItem.first.id),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        final item = _selectedItem.first;
        item.imagePath = result['imagePath'];
        item.color = result['canvasColor'];
      });
    }
  }

  Future<void> _loadBoardItems() async {
    try {
      final items = await _databaseService.loadBoardItems(widget.boardId);
      if (!mounted) return;

      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _selectedItem.clear();
      });
    } catch (_) {
      // Keep screen usable even if loading fails.
    }
  }

  Future<String?> _captureBoardPreviewPath() async {
    await Future<void>.delayed(const Duration(milliseconds: 16));

    final boundary =
        _boardRepaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;

    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) return null;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final Directory dir = await getApplicationDocumentsDirectory();
    final String previewsDir = p.join(dir.path, 'board_previews');
    await Directory(previewsDir).create(recursive: true);
    final String filePath = p.join(previewsDir, 'board_${widget.boardId}.png');
    await File(filePath).writeAsBytes(pngBytes, flush: true);

    return filePath;
  }

  Future<void> _saveBoard() async {
    try {
      final previewPath = await _captureBoardPreviewPath();

      debugPrint('Saving board ${widget.boardId}');
      await _databaseService.saveBoard(
        boardId: widget.boardId,
        name: widget.boardName,
        height: _boardHeight,
        width: _boardWidth,
        items: _items,
        previewPath: previewPath,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Board saved locally')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save board locally: $e')),
      );
    }
  }

  Future<void> _uploadBoard() async {
    try {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Text('Uploading board...'),
            ],
          ),
        ),
      );

      final previewPath = await _captureBoardPreviewPath();

      await _networkService.uploadBoard(
        boardId: widget.boardId,
        name: widget.boardName,
        height: _boardHeight,
        width: _boardWidth,
        items: _items,
        previewSrc: previewPath,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board uploaded successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload board: $e')),
      );
    }
  }
}
