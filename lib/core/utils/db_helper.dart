
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  Future<Database> initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sportoteka.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE players (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            fullName TEXT,
            age TEXT,
            birthDate TEXT,
            position TEXT,
            club TEXT,
            number TEXT,
            height TEXT,
            weight TEXT,
            achievements TEXT,
            photo TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            image TEXT,
            author TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertTestPosts() async {
    final db = await database;

    await db.insert('posts', {
      'title': 'Победа Динамо-Минск',
      'content': 'Команда одержала уверенную победу в последнем матче.',
      'image': 'https://dinamo-minsk.by/upload/iblock/95b/zsjuu95vt8b2ljz5z0ek7bl0suv7rohe.jpg',
      'author': 'ФК Динамо-Минск'
    });

    await db.insert('posts', {
      'title': 'Новый тренер в команде',
      'content': 'Представлен новый главный тренер Динамо.',
      'image': 'https://dinamo-minsk.by/upload/iblock/b6e/4e7pii41f75xnjxwtgvnsm95eh7j2sz2.jpg',
      'author': 'ФК Динамо-Минск'
    });
  }
}
