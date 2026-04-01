import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/data/sources/local/database_helper.dart';
import 'package:flutter_pa_snk/features/board/board_view.dart';

class BoardListView extends StatefulWidget {
  const BoardListView({super.key});

  @override
  State<BoardListView> createState() => _BoardListViewState();
}

class _BoardListViewState extends State<BoardListView> {
  static const double _boardWidth = 1000;
  static const double _boardHeight = 1000;

  final DatabaseService _databaseService = DatabaseService();
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
    final boardName = 'Board ${DateTime.now().millisecondsSinceEpoch}';
    final boardId = await _databaseService.createBoard(
      name: boardName,
      height: _boardHeight,
      width: _boardWidth,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoardView(boardId: boardId, boardName: boardName),
      ),
    );

    await _refreshBoards();
  }

  Future<void> _openBoard(SavedBoard board) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoardView(boardId: board.id, boardName: board.name),
      ),
    );

    await _refreshBoards();
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

    return Image.file(file, fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
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
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Text('No saved boards yet. Tap + to create one.'),
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
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openBoard(board),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade700,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: SizedBox.expand(
                                    child: _buildPreview(board),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        board.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            onPressed: _createBoard,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
