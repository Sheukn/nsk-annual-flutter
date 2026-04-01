import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_pa_snk/models/board_item.dart';

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
      version: 1,
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
    );
  }

  Future<void> saveBoard({
    required int boardId,
    required String name,
    required double height,
    required double width,
    required List<BoardItem> items,
  }) async {
    print('Connect to database to save board $boardId');
    final db = await database;
    print ('Connected to database, starting transaction for board $boardId');
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final updated = await txn.update(
        'Board',
        {
          'name': name,
          'height': height,
          'width': width,
          'last_update': now,
        },
        where: 'id = ?',
        whereArgs: [boardId],
      );

      if (updated == 0) {
        await txn.insert('Board', {
          'id': boardId,
          'name': name,
          'height': height,
          'width': width,
          'last_update': now,
          'created_at': now,
        });
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