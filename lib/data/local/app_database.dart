import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart'; // NativeDatabase için gerekli
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get description =>
      text().named("desc").withDefault(const Constant(""))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [Projects])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  Future<List<Project>> getAllProjects() => select(projects).get();

  Future<int> deleteProject(int id) =>
      (delete(projects)..where((tbl) => tbl.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'santiyepro.db'));
    return NativeDatabase(file);
  });
}
