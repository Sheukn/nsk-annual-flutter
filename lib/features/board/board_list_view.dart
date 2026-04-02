import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/data/sources/local/database_helper.dart';
import 'package:flutter_pa_snk/features/board/board_view.dart';
import 'package:flutter_pa_snk/services/board_service.dart';

class BoardListView extends StatefulWidget {
  const BoardListView({super.key});

  @override
  State<BoardListView> createState() => _BoardListViewState();
}

class _BoardListViewState extends State<BoardListView> {
  static const double _boardWidth = 1000;
  static const double _boardHeight = 1000;

  final DatabaseService _databaseService = DatabaseService();
  final BoardService _networkService = BoardService();
  late Future<List<SavedBoard>> _boardsFuture;

  @override
  void initState() {
    super.initState();
    _boardsFuture = _databaseService.getBoards();
  }

  Future<void> _refreshBoards() async {
    final boards = await _databaseService.getBoards();
    if (!mounted) return;

    setState(() {
      _boardsFuture = Future.value(boards);
    });
  }

  Future<void> _createBoard() async {
    final nameController = TextEditingController();
    
    final boardName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Board'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Enter board name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (boardName == null || boardName.isEmpty) return;

    final boardId = await _databaseService.createBoard(
      name: boardName,
      height: _boardHeight,
      width: _boardWidth,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoardView(
          boardId: boardId,
          boardName: boardName,
        ),
      ),
    );

    await _refreshBoards();
  }

  Future<void> _openBoard(SavedBoard board) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoardView(
          boardId: board.id,
          boardName: board.name,
        ),
      ),
    );

    await _refreshBoards();
  }

  Future<void> _deleteBoard(SavedBoard board) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text('Are you sure you want to delete "${board.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _databaseService.deleteBoard(board.id);
              await _refreshBoards();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameBoard(SavedBoard board) async {
    final nameController = TextEditingController(text: board.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Board'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;

    await _databaseService.updateBoardName(board.id, newName);
    await _refreshBoards();
  }

  void _showBoardOptions(SavedBoard board) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        color: Colors.grey.shade900,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  board.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Rename', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _renameBoard(board);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteBoard(board);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: Colors.green),
                title: const Text('Upload to Server', style: TextStyle(color: Colors.green)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadBoardToServer(board);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadBoardToServer(SavedBoard board) async {
    try {
      // Load board items
      final items = await _databaseService.loadBoardItems(board.id);

      if (!mounted) return;

      // Show loading dialog
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

      // Upload the board using the board ID (UUID)
      await _networkService.uploadBoard(
        boardId: board.id,
        name: board.name,
        height: board.height,
        width: board.width,
        items: items,
        previewSrc: board.previewSrc,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board uploaded successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload board: $e')),
      );
    }
  }

  Future<void> _fetchBoardsFromServer() async {
    try {
      if (!mounted) return;

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              const Text('Fetching boards...'),
            ],
          ),
        ),
      );

      // Fetch all boards from server
      final serverBoards = await _networkService.fetchAllBoards();

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Sync with local database
      int syncedCount = 0;
      for (final boardDto in serverBoards) {
        // Try to find matching local board by ID (both are now UUIDs)
        final localBoards = await _databaseService.getBoards();
        SavedBoard? matchingBoard;

        for (final localBoard in localBoards) {
          if (localBoard.id == boardDto.id) {
            matchingBoard = localBoard;
            break;
          }
        }

        if (matchingBoard != null) {
          // Update existing board metadata
          await _databaseService.updateBoardName(matchingBoard.id, boardDto.name);
          
          // Update preview if provided
          if (boardDto.previewSrc != null) {
            await _databaseService.updateBoardPreviewSrc(
              boardId: matchingBoard.id,
              previewSrc: boardDto.previewSrc!,
            );
          }
          syncedCount++;
        } else {
          // Create new board from server with same UUID as server
          final newBoardId = await _databaseService.createBoard(
            name: boardDto.name,
            height: boardDto.height,
            width: boardDto.width,
          );

          // Update preview if provided
          if (boardDto.previewSrc != null) {
            await _databaseService.updateBoardPreviewSrc(
              boardId: newBoardId,
              previewSrc: boardDto.previewSrc!,
            );
          }

          // Save assets from server
          for (final assetDto in boardDto.assets) {
            await _databaseService.insertBoardAsset(
              boardId: newBoardId,
              assetName: assetDto.assetName,
              x: assetDto.xPosition,
              y: assetDto.yPosition,
              rotation: assetDto.rotation,
              src: assetDto.src,
            );
          }

          syncedCount++;
        }
      }

      if (!mounted) return;

      // Refresh the board list
      await _refreshBoards();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synced $syncedCount board(s) from server')),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Try to close loading dialog safely
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch boards: $e')),
      );
    }
  }

  Widget _buildPreview(SavedBoard board) {
    final previewPath = board.previewPath;
    if (previewPath == null || previewPath.isEmpty) {
      return const Center(
        child: Icon(Icons.dashboard_customize, size: 48, color: Colors.white70),
      );
    }

    final file = File(previewPath);
    if (!file.existsSync()) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 48, color: Colors.white70),
      );
    }

    final provider = FileImage(file);
    provider.evict(); // Evict cache to ensure it reloads the latest saved preview

    return Image(
      image: provider,
      key: ValueKey(file.lastModifiedSync().millisecondsSinceEpoch),
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Boards',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: 'Sync from Server',
            onPressed: _fetchBoardsFromServer,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshBoards,
        child: FutureBuilder<List<SavedBoard>>(
            future: _boardsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Failed to load boards: ${snapshot.error}'),
                      ),
                    ),
                  ],
                );
              }

              final boards = snapshot.data ?? const [];
              if (boards.isEmpty) {
                return ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height - 100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No saved boards yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to create one',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      (constraints.maxWidth / 220).floor().clamp(2, 6);

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: boards.length,
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      return Material(
                        color: Colors.transparent,
                        child: GestureDetector(
                          onTap: () => _openBoard(board),
                          onLongPress: () => _showBoardOptions(board),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade700,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: SizedBox.expand(
                                      child: _buildPreview(board),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          board.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        color: Colors.white70,
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        elevation: 6,
        onPressed: _createBoard,
        child: const Icon(Icons.add, size: 28),
      ),
      );
    
  }
}
