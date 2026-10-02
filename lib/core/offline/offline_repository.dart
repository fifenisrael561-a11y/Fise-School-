import 'dart:convert';

import 'package:drift/drift.dart';

import '../../models/pedagogy.dart';
import 'app_database.dart';

class OfflineRepository {
  OfflineRepository({AppDatabase? database})
      : _database = database ?? _sharedDatabase;

  /// Une seule connexion SQLite pour toute l'application : ouvrir plusieurs
  /// instances Drift sur le même fichier provoque des conflits d'accès.
  static final AppDatabase _sharedDatabase = AppDatabase();

  final AppDatabase _database;

  // ============================================================
  // COURSES
  // ============================================================

  Future<void> saveCourse(Course course) async {
    await _database.saveCourse(
      CachedCoursesCompanion(
        id: Value(course.id),
        title: Value(course.titleFr),
        description: Value(course.descriptionFr),
        subjectId: Value(course.subjectId),
        classId: Value(course.classId),
        dataJson: Value(jsonEncode(_courseToJson(course))),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> saveCourses(List<Course> courses) async {
    for (final course in courses) {
      await saveCourse(course);
    }
  }

  /// Remplace tout le cache des cours par la liste serveur : un cours retiré
  /// ou dépublié par l'enseignant disparaît aussi hors ligne.
  Future<void> replaceCourses(List<Course> courses) async {
    await _database.deleteAllCourses();
    await saveCourses(courses);
  }

  Future<List<Course>> getCourses() async {
    final rows = await _database.getAllCourses();

    return rows.map((row) {
      final json =
          jsonDecode(row.dataJson) as Map<String, dynamic>;

      return Course.fromMap(json);
    }).toList(growable: false);
  }

  Future<List<Course>> getCoursesForStudent(String studentId) async {
    final courses = await getCourses();
    return courses.where((course) => course.status == 'published').toList(growable: false);
  }

  Future<Course?> getCourse(String id) async {
    final rows = await _database.getAllCourses();

    for (final row in rows) {
      if (row.id == id) {
        final json =
            jsonDecode(row.dataJson) as Map<String, dynamic>;

        return Course.fromMap(json);
      }
    }

    return null;
  }

  // ============================================================
  // LESSONS
  // ============================================================

  Future<void> saveLesson(Lesson lesson) async {
    await _database.saveLesson(
      CachedLessonsCompanion(
        id: Value(lesson.id),
        courseId: Value(lesson.courseId),
        title: Value(lesson.titleFr),
        content: Value(lesson.contentFr ?? ''),
        durationMinutes: Value(lesson.estimatedMinutes),
        dataJson: Value(jsonEncode(_lessonToJson(lesson))),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> saveLessons(List<Lesson> lessons) async {
    for (final lesson in lessons) {
      await saveLesson(lesson);
    }
  }

  Future<List<Lesson>> getLessons() async {
    final rows = await _database.getAllLessons();

    return rows.map((row) {
      final json =
          jsonDecode(row.dataJson) as Map<String, dynamic>;

      return Lesson.fromMap(json);
    }).toList(growable: false);
  }

  Future<List<Lesson>> getLessonsForCourse(String courseId) async {
    final rows = await _database.getAllLessons();

    return rows
        .where((row) => row.courseId == courseId)
        .map((row) {
          final json =
              jsonDecode(row.dataJson) as Map<String, dynamic>;

          return Lesson.fromMap(json);
        })
        .toList(growable: false);
  }

  Future<Lesson?> getLesson(String id) async {
    final rows = await _database.getAllLessons();

    for (final row in rows) {
      if (row.id == id) {
        final json =
            jsonDecode(row.dataJson) as Map<String, dynamic>;

        return Lesson.fromMap(json);
      }
    }

    return null;
  }

  // ============================================================
  // PROGRESSION LOCALE
  // ============================================================

  Future<void> saveProgress({
    required LessonProgress progress,
  }) async {
    await _database.saveProgress(
      LocalProgressCompanion(
        // Local progress has a stable key even before Supabase creates a row.
        id: Value('${progress.studentId}:${progress.lessonId}'),
        userId: Value(progress.studentId),
        courseId: const Value(null),
        lessonId: Value(progress.lessonId),
        progressPercent: Value(progress.progressPercent),
        completed: Value(progress.status == 'completed'),
        updatedAt: Value(
          progress.updatedAt ?? DateTime.now(),
        ),
      ),
    );
  }

  Future<List<LocalProgressData>> getProgress() {
    return _database.getAllProgress();
  }

  Future<LocalProgressData?> getLocalProgress(String id) async {
    final rows = await _database.getAllProgress();

    for (final row in rows) {
      if (row.id == id) {
        return row;
      }
    }

    return null;
  }

  // ============================================================
  // NETTOYAGE DU CACHE
  // ============================================================

  Future<void> clearCourses() async {
    await _database.deleteAllCourses();
  }

  Future<void> clearLessons() async {
    await _database.deleteAllLessons();
  }

  Future<void> clearProgress() async {
    await _database.deleteAllProgress();
  }

  // ============================================================
  // FERMETURE
  // ============================================================

  Future<void> close() async {
    await _database.closeDatabase();
  }

  // ============================================================
  // CONVERSION COURSE -> JSON
  // ============================================================

  Map<String, dynamic> _courseToJson(Course course) {
    return {
      'id': course.id,
      'curriculum_id': course.curriculumId,
      'chapter_id': course.chapterId,
      'subject_id': course.subjectId,
      'teacher_id': course.teacherId,
      'class_id': course.classId,
      'title_fr': course.titleFr,
      'title_en': course.titleEn,
      'description_fr': course.descriptionFr,
      'description_en': course.descriptionEn,
      'content_fr': course.contentFr,
      'content_en': course.contentEn,
      'status': course.status,
      'published_at':
          course.publishedAt?.toIso8601String(),
    };
  }

  // ============================================================
  // CONVERSION LESSON -> JSON
  // ============================================================

  Map<String, dynamic> _lessonToJson(Lesson lesson) {
    return {
      'id': lesson.id,
      'course_id': lesson.courseId,
      'title_fr': lesson.titleFr,
      'title_en': lesson.titleEn,
      'content_fr': lesson.contentFr,
      'content_en': lesson.contentEn,
      'objectives_fr': lesson.objectivesFr,
      'objectives_en': lesson.objectivesEn,
      'examples_fr': lesson.examplesFr,
      'examples_en': lesson.examplesEn,
      'summary_fr': lesson.summaryFr,
      'summary_en': lesson.summaryEn,
      'position': lesson.position,
      'estimated_minutes': lesson.estimatedMinutes,
      'is_published': lesson.isPublished,
    };
  }
}