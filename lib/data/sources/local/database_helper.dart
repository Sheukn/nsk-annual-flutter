import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

class SavedBoard {
  final int id;
  final String name;
  final double height;
  final double width;
  final String? previewPath;
  final String? lastUpdate;

  SavedBoard({
    required this.id,
    required this.name,
    required this.height,
    required this.width,
    this.previewPath,
    this.lastUpdate,
  });
}

class DatabaseService {
  // Pattern Singleton pour n'avoir qu'une seule instance de DB
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
    // Récupère le chemin par défaut des bases de données sur l'appareil
    String path = join(await getDatabasesPath(), 'mon_projet.db');

    return await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Table Board
        await db.execute('''
          CREATE TABLE Board (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            height REAL NOT NULL,
            width REAL NOT NULL,
            preview_path TEXT,
            last_update TEXT,
            created_at TEXT
          )
        ''');

        // Table Board_Asset liée à Board
        await db.execute('''
          CREATE TABLE Board_Asset (
            board_id INTEGER NOT NULL,
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
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE Board ADD COLUMN preview_path TEXT');
          } catch (_) {
            // Ignore if column already exists.
          }
        }
      },
    );
  }

  Future<int> createBoard({
    required String name,
    required double height,
    required double width,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    return db.insert('Board', {
      'name': name,
      'height': height,
      'width': width,
      'last_update': now,
      'created_at': now,
    });
  }

  Future<List<SavedBoard>> getBoards() async {
    final db = await database;
    final rows = await db.query('Board', orderBy: 'COALESCE(last_update, created_at) DESC');

    return rows
        .map(
          (row) => SavedBoard(
            id: row['id'] as int,
            name: row['name'] as String,
            height: (row['height'] as num).toDouble(),
            width: (row['width'] as num).toDouble(),
            previewPath: row['preview_path'] as String?,
            lastUpdate: row['last_update'] as String?,
          ),
        )
        .toList();
  }

  Future<List<BoardItem>> loadBoardItems(int boardId) async {
    final db = await database;
    final rows = await db.query(
      'Board_Asset',
      where: 'board_id = ?',
      whereArgs: [boardId],
      orderBy: 'rowid ASC',
    );

    return rows.map((row) {
      final src = row['src'] as String?;
      final isImage = src == null;

      return BoardItem(
        id: row['asset_name'] as String,
        position: Position(
          x: ((row['x_position'] as num?) ?? 0).toDouble(),
          y: ((row['y_position'] as num?) ?? 0).toDouble(),
        ),
        size: Size(width: isImage ? 200 : 150, height: isImage ? 150 : 150),
        color: isImage ? const Color(0xFF9E9E9E) : const Color(0xFFFFFF00),
        rotation: ((row['rotation'] as num?) ?? 0).toDouble(),
        isImage: isImage,
        imagePath: src,
      );
    }).toList();
  }

  Future<void> saveBoard({
    required int boardId,
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
          'scale': 1.0,
          'rotation': item.rotation,
          'x_position': item.position.x,
          'y_position': item.position.y,
          'src': item.imagePath,
          'last_update': now,
        });
      }
    });
  }
} 