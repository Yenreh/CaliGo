import '../../domain/entities/stop_entity.dart';
import 'app_database.dart';

/// Local storage for the stops the user saved
class StopsLocalDatasource {
  static const String _tableName = 'favorite_stops';

  Future<List<FavoriteStop>> getFavorites() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(_tableName, orderBy: 'position ASC, name ASC');
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<void> insert(FavoriteStop stop) async {
    final db = await AppDatabase.instance;
    await db.insert(_tableName, _toRow(stop));
  }

  Future<void> update(FavoriteStop stop) async {
    final db = await AppDatabase.instance;
    await db.update(
      _tableName,
      _toRow(stop),
      where: 'stop_id = ?',
      whereArgs: [stop.id],
    );
  }

  Future<void> delete(String stopId) async {
    final db = await AppDatabase.instance;
    await db.delete(_tableName, where: 'stop_id = ?', whereArgs: [stopId]);
  }

  Future<bool> exists(String stopId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      _tableName,
      where: 'stop_id = ?',
      whereArgs: [stopId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<int> nextPosition() async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM $_tableName',
    );
    return (rows.first['next'] as num?)?.toInt() ?? 0;
  }

  FavoriteStop _fromRow(Map<String, dynamic> row) {
    return FavoriteStop(
      id: row['stop_id'] as String,
      name: row['name'] as String,
      anchorLatitude: (row['anchor_latitude'] as num).toDouble(),
      anchorLongitude: (row['anchor_longitude'] as num).toDouble(),
      position: (row['position'] as num?)?.toInt() ?? 0,
      stopId: row['stop_ref'] as String?,
      customName: row['custom_name'] as String?,
      missingCount: (row['missing_count'] as num?)?.toInt() ?? 0,
      showOnHome: (row['show_on_home'] as num?)?.toInt() != 0,
      // Line short names never hold a comma
      lines: (row['lines'] as String?)
              ?.split(',')
              .where((l) => l.isNotEmpty)
              .toList(growable: false) ??
          const [],
    );
  }

  Map<String, Object?> _toRow(FavoriteStop stop) {
    return {
      'stop_id': stop.id,
      'name': stop.name,
      'anchor_latitude': stop.anchorLatitude,
      'anchor_longitude': stop.anchorLongitude,
      'position': stop.position,
      'stop_ref': stop.stopId,
      'custom_name': stop.customName,
      'missing_count': stop.missingCount,
      'show_on_home': stop.showOnHome ? 1 : 0,
      'lines': stop.lines.isEmpty ? null : stop.lines.join(','),
    };
  }
}
