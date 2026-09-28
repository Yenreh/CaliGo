import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single SQLite database shared by every local data source.
class AppDatabase {
  static const int _version = 7;
  static Database? _database;

  static Future<Database> get instance async {
    return _database ??= await _open();
  }

  static Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'caligo.db');

    return openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await _createCards(db);
        await _createFavoriteStops(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createFavoriteStops(db);
        if (oldVersion < 3) await _addStopRef(db);
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE favorite_stops ADD COLUMN custom_name TEXT',
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE favorite_stops ADD COLUMN missing_count INTEGER '
            'DEFAULT 0',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE favorite_stops ADD COLUMN show_on_home INTEGER '
            'DEFAULT 1',
          );
        }
        if (oldVersion < 7) {
          await db.execute(
            'ALTER TABLE favorite_stops ADD COLUMN lines TEXT',
          );
        }
      },
    );
  }

  static Future<void> _createCards(Database db) {
    return db.execute('''
      CREATE TABLE cards (
        internal_id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        prefix TEXT,
        suffix TEXT,
        name TEXT NOT NULL,
        position INTEGER DEFAULT 0,
        balance REAL,
        last_update INTEGER
      )
    ''');
  }

  static Future<void> _createFavoriteStops(Database db) {
    return db.execute('''
      CREATE TABLE favorite_stops (
        stop_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        anchor_latitude REAL NOT NULL,
        anchor_longitude REAL NOT NULL,
        position INTEGER DEFAULT 0,
        stop_ref TEXT,
        custom_name TEXT,
        missing_count INTEGER DEFAULT 0,
        show_on_home INTEGER DEFAULT 1,
        lines TEXT
      )
    ''');
  }

  /// Favorites used to always track a single stop id. Stations span
  /// several platforms and never matched one, so they become area
  /// favorites: stop_ref stays null and every nearby stop is gathered.
  static Future<void> _addStopRef(Database db) async {
    await db.execute('ALTER TABLE favorite_stops ADD COLUMN stop_ref TEXT');
    await db.execute(
      "UPDATE favorite_stops SET stop_ref = stop_id "
      "WHERE stop_id NOT LIKE 'station-%' AND stop_id NOT LIKE 'area:%'",
    );
  }
}
