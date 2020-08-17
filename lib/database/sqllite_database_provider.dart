import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../main.dart';

final String dbTableSyncPlayer = "syncPlayer";
final String dbTableSyncTeam = "syncTeam";
final String dbTableSyncChallenge = "syncChallenge";
final String dbTableSyncCategory = "syncCategory";
final String dbTableSyncChallengeState = "syncChallengeState";
final String dbTableSyncJournal = "syncJournal";
final String dbTableSyncChallengeImageService = "syncChallengeImageService";

/// SQLite Database singleton class
class SQLiteDBProvider {
  SQLiteDBProvider._();

  static final SQLiteDBProvider instance = SQLiteDBProvider._();

  static Database _database;

  /// To get database (Future option) of type Future<Database>
  Future<Database> get database async {
    if (_database != null) return _database;
    _database = await initDB();
    return _database;
  }

  /// init DB
  initDB() async {
    return openDatabase(
      join(await getDatabasesPath(), 'doggie_database.db'),
      //on create database, create table also
      onCreate: populateDb,
      // Set the version to perform database upgrades and downgrades.
      version: 1,
    );
  }

  void populateDb(Database database, int version) async {
    await createdogTable(database, version);
  }

  Future createdogTable(Database database, int version) async {
    await database.execute("CREATE TABLE dogs(id INTEGER PRIMARY KEY, name TEXT, age INTEGER)");
  }
  
  Future<String> getDBPath() async {
    String str = join(await getDatabasesPath(), 'doggie_database.db');
    return str;
  }

  Future<void> insertDog(Dog dog) async {
  // Get a reference to the database.
  final Database db = await database;

  // Insert the Dog into the correct table. You might also specify the
  // `conflictAlgorithm` to use in case the same dog is inserted twice.
  //
  // In this case, replace any previous data.
  await db.insert(
    'dogs',
    dog.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

  /// To insert all records in database table
  Future<void> insertAll(String tableName, dynamic entity) async {
    entity.forEach((element) {
      insertRecord(tableName, element);
    });
  }

  /// To insert single record in database table
  Future<void> insertRecord(String tableName, dynamic entity) async {
    // Get a reference to the database.
    final Database db = await database;

    // You might also specify the
    // `conflictAlgorithm` to use in case the same entity is inserted twice.
    // In this case, replace any previous data.

    db.transaction((txn) async {
      await txn.insert(tableName, entity.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// To get all records from database table
  Future<List<Map>> getAllRecords(String tableName) async {
    final db = await database;
//    List<Map> results = await db.query(tableName, orderBy: "id ASC");
    List<Map> results = await db.query(tableName);
    return results;
  }

  /// To get single record from database table
  Future<List<Map>> getRecord(
      String tableName, String columnName, int id) async {
    final db = await database;
    List<Map> results = await db
        .rawQuery('SELECT * FROM $tableName WHERE $columnName = ?', ['$id']);
    return results;
  }

  /// To update record in database table
  Future<int> updateRecord(
      String tableName, dynamic entity, String columnName, int id) async {
    // Get a reference to the database.
    final db = await database;

    // Update the given entity
    var result = await db.update(
      tableName,
      entity.toJson(),
      where: "$columnName = ?",
      // Pass the entity's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );
    return result;
  }

  /// To delete record from database table
  Future<int> deleteRecord(String tableName, String columnName, int id) async {
    // Get a reference to the database.
    final db = await database;

    var result = await db.delete(
      tableName,
      where: "$columnName = ?",
      // Pass the entity's id as a whereArg to prevent SQL injection.
      whereArgs: [id],
    );
    return result;
  }

  /// To delete all records from database table
  Future<int> deleteAll(String tableName) async {
    // Get a reference to the database.
    final db = await database;

    var result = await db.delete(tableName);
    return result;
  }
}
