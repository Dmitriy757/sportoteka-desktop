
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;

  DBHelper._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB("sportoteka.db");
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      "CREATE TABLE players ("
      "id INTEGER PRIMARY KEY AUTOINCREMENT,"
      "fullName TEXT,"
      "age TEXT,"
      "birthDate TEXT,"
      "position TEXT,"
      "club TEXT,"
      "number TEXT,"
      "height TEXT,"
      "weight TEXT,"
      "achievements TEXT,"
      "photo TEXT"
      ")"
    );
  }

  Future<int> insertPlayer(Map<String, dynamic> player) async {
    final db = await database;
    return await db.insert('players', player);
  }

  Future<List<Map<String, dynamic>>> getPlayers() async {
    final db = await database;
    return await db.query('players');
  }

  Future<int> updatePlayer(int id, Map<String, dynamic> player) async {
    final db = await database;
    return await db.update('players', player, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deletePlayer(int id) async {
    final db = await database;
    return await db.delete('players', where: 'id = ?', whereArgs: [id]);
  }
}
