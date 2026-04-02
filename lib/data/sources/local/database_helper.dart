import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'dart:ui' as ui;

class SavedBoard {
  final String id;
  final String name;
  final double height;
  final double width;
  final String? previewPath;
  final String? previewSrc;
  final String? lastUpdate;

  SavedBoard({
    required this.id,
    required this.name,
    required this.height,
    required this.width,
    this.previewPath,
    this.previewSrc,
    this.lastUpdate,
  });
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  DatabaseService._internal();

  factory DatabaseService() => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'mon_projet.db');

    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE Board (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            height REAL NOT NULL,
            width REAL NOT NULL,
            preview_path TEXT,
            preview_src TEXT,
            last_update TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE Board_Asset (
            board_id TEXT NOT NULL,
            asset_name TEXT NOT NULL,
            scale REAL,
            rotation REAL,
            x_position REAL,
            y_position REAL,
            src TEXT,
            last_update TEXT,
            FOREIGN KEY (board_id) REFERENCES Board(id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  Future<String> createBoard({
    required String name,
    required double height,
    required double width,
    String? id,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final boardUuid = id ?? const Uuid().v4();

    await db.insert('Board', {
      'id': boardUuid,
      'name': name,
      'height': height,
      'width': width,
      'last_update': now,
      'created_at': now,
    });
    return boardUuid;
  }

  Future<List<SavedBoard>> getBoards() async {
    final db = await database;
    final rows = await db.query('Board', orderBy: 'COALESCE(last_update, created_at) DESC');

    return rows
        .map(
          (row) => SavedBoard(
            id: row['id'] as String,
            name: row['name'] as String,
            height: (row['height'] as num).toDouble(),
            width: (row['width'] as num).toDouble(),
            previewPath: row['preview_path'] as String?,
            previewSrc: row['preview_src'] as String?,
            lastUpdate: row['last_update'] as String?,
          ),
        )
        .toList();
  }

  Future<List<BoardItem>> loadBoardItems(String boardId) async {
    final db = await database;
    final rows = await db.query(
      'Board_Asset',
      where: 'board_id = ?',
      whereArgs: [boardId],
      orderBy: 'rowid ASC',
    );

    final items = <BoardItem>[];

    for (final row in rows) {
      final src = row['src'] as String?;
      // Post-its are identified by the 'postit_' keyword in their filename/path
      final isPostIt = src != null && src.contains('postit_');
      final isImage = !isPostIt;
      
      var width = isImage ? 200.0 : 150.0;
      var height = 150.0;
      var color = isImage ? const Color(0xFF9E9E9E) : const Color(0xFFFFFF00);

      if (isImage && src != null) {
        color = Colors.transparent;
        try {
          final file = File(src);
          if (file.existsSync()) {
            final bytes = file.readAsBytesSync();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            if (frame.image.width > 0 && frame.image.height > 0) {
              final aspect = frame.image.width / frame.image.height;
              height = width / aspect;
            }
          }
        } catch (_) {
          // Fallback height if image can't be decoded
          height = 150.0;
        }
      }

      items.add(BoardItem(
        id: row['asset_name'] as String,
        position: Position(
          x: ((row['x_position'] as num?) ?? 0).toDouble(),
          y: ((row['y_position'] as num?) ?? 0).toDouble(),
        ),
        size: Size(width: width, height: height),
        color: color,
        rotation: ((row['rotation'] as num?) ?? 0).toDouble(),
        scale: ((row['scale'] as num?) ?? 1.0).toDouble(),
        isImage: isImage,
        imagePath: src,
      ));
    }

    return items;
  }

  Future<void> saveBoard({
    required String boardId,
    required String name,
    required double height,
    required double width,
    required List<BoardItem> items,
    String? previewPath,
  }) async {
    debugPrint('Connect to database to save board $boardId');
    final db = await database;
    debugPrint('Connected to database, starting transaction for board $boardId');
    final now = DateTime.now().toIso8601String();
    final hasPreviewPath = previewPath != null && previewPath.isNotEmpty;

    await db.transaction((txn) async {
      final boardValues = <String, Object?>{
        'name': name,
        'height': height,
        'width': width,
        'last_update': now,
      };

      if (hasPreviewPath) {
        boardValues['preview_path'] = previewPath;
      }

      final updated = await txn.update(
        'Board',
        boardValues,
        where: 'id = ?',
        whereArgs: [boardId],
      );

      if (updated == 0) {
        final insertValues = <String, Object?>{
          'id': boardId,
          'name': name,
          'height': height,
          'width': width,
          'last_update': now,
          'created_at': now,
        };

        if (hasPreviewPath) {
          insertValues['preview_path'] = previewPath;
        }

        await txn.insert('Board', insertValues);
      }

      await txn.delete(
        'Board_Asset',
        where: 'board_id = ?',
        whereArgs: [boardId],
      );

      for (final item in items) {
        await txn.insert('Board_Asset', {
          'board_id': boardId,
          'asset_name': item.id,
          'scale': item.scale,
          'rotation': item.rotation,
          'x_position': item.position.x,
          'y_position': item.position.y,
          'src': item.imagePath,
          'last_update': now,
        });
      }
    });
  }

  /// Inserts a single Board_Asset row immediately (used when adding an image
  /// to the board so the link is persisted without a full save).
  Future<void> insertBoardAsset({
    required String boardId,
    required String assetName,
    required double x,
    required double y,
    required double rotation,
    double scale = 1.0,
    String? src,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.insert('Board_Asset', {
      'board_id': boardId,
      'asset_name': assetName,
      'scale': scale,
      'rotation': rotation,
      'x_position': x,
      'y_position': y,
      'src': src,
      'last_update': now,
    });
  }

  /// Updates the src (file path) of an existing Board_Asset row.
  Future<void> updateBoardAssetSrc({
    required String boardId,
    required String assetName,
    required String src,
  }) async {
    final db = await database;
    await db.update(
      'Board_Asset',
      {'src': src, 'last_update': DateTime.now().toIso8601String()},
      where: 'board_id = ? AND asset_name = ?',
      whereArgs: [boardId, assetName],
    );
  }

  /// Deletes a board and all its associated assets.
  Future<void> deleteBoard(String boardId) async {
    final db = await database;
    await db.delete(
      'Board',
      where: 'id = ?',
      whereArgs: [boardId],
    );
  }

  Future<void> updateBoardName(String boardId, String newName) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    
    await db.update(
      'Board',
      {
        'name': newName,
        'last_update': now,
      },
      where: 'id = ?',
      whereArgs: [boardId],
    );
  }

  Future<void> updateBoardPreviewSrc({
    required String boardId,
    required String previewSrc,
  }) async {
    final db = await database;
    await db.update(
      'Board',
      {'preview_src': previewSrc},
      where: 'id = ?',
      whereArgs: [boardId],
    );
  }

  /// Updates position, rotation, and scale of a board asset.
  Future<void> updateBoardAssetPosition({
    required String boardId,
    required String assetName,
    required double x,
    required double y,
    required double rotation,
    double? scale,
  }) async {
    final db = await database;
    final updates = <String, Object?>{
      'x_position': x,
      'y_position': y,
      'rotation': rotation,
      'last_update': DateTime.now().toIso8601String(),
    };
    
    if (scale != null) {
      updates['scale'] = scale;
    }
    
    await db.update(
      'Board_Asset',
      updates,
      where: 'board_id = ? AND asset_name = ?',
      whereArgs: [boardId, assetName],
    );
  }
} 