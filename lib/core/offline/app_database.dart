import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CachedCourses extends Table {
  TextColumn get id => text()();

  TextColumn get title => text()();

  TextColumn get description => text().nullable()();

  TextColumn get subjectId => text().nullable()();

  TextColumn get classId => text().nullable()();

  TextColumn get dataJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedLessons extends Table {
  TextColumn get id => text()();

  TextColumn get courseId => text()();

  TextColumn get title => text()();

  TextColumn get content => text()();

  IntColumn get durationMinutes => integer().nullable()();

  TextColumn get dataJson => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalProgress extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text()();

  TextColumn get courseId => text().nullable()();

  TextColumn get lessonId => text().nullable()();

  IntColumn get progressPercent => integer()();

  BoolColumn get completed => boolean()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedCourses, CachedLessons, LocalProgress])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<List<CachedCourse>> getAllCourses() {
    return select(cachedCourses).get();
  }

  Future<List<CachedLesson>> getAllLessons() {
    return select(cachedLessons).get();
  }

  Future<List<LocalProgressData>> getAllProgress() {
    return select(localProgress).get();
  }

  Future<void> saveCourse(CachedCoursesCompanion course) async {
    await into(cachedCourses).insertOnConflictUpdate(course);
  }

  Future<void> saveLesson(CachedLessonsCompanion lesson) async {
    await into(cachedLessons).insertOnConflictUpdate(lesson);
  }

  Future<void> saveProgress(LocalProgressCompanion progress) async {
    await into(localProgress).insertOnConflictUpdate(progress);
  }

  Future<void> deleteAllCourses() async {
    await delete(cachedCourses).go();
  }

  Future<void> deleteAllLessons() async {
    await delete(cachedLessons).go();
  }

  Future<void> deleteAllProgress() async {
    await delete(localProgress).go();
  }

  Future<void> closeDatabase() async {
    await close();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File(p.join(directory.path, 'fise_school.sqlite'));

    return NativeDatabase.createInBackground(file);
  });
}
