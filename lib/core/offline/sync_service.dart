import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/pedagogy_service.dart';
import '../../models/pedagogy.dart';
import 'offline_repository.dart';

class SyncService {
  SyncService({SupabaseClient? client, OfflineRepository? offlineRepository})
    : _client = client ?? Supabase.instance.client,
      _offline = offlineRepository ?? OfflineRepository();

  final SupabaseClient _client;
  final OfflineRepository _offline;

  // ============================================================
  // SYNCHRONISATION DES COURS D'UN ÉLÈVE
  // ============================================================

  Future<void> syncStudentCourses(String studentId) async {
    final courseService = CourseService(client: _client);

    final List<Course> courses = await courseService.listStudentCourses(
      studentId,
    );

    await _offline.saveCourses(courses);

    for (final Course course in courses) {
      final List<Lesson> lessons = await courseService.listLessons(course.id);

      await _offline.saveLessons(lessons);
    }
  }

  // ============================================================
  // SYNCHRONISATION D'UN COURS
  // ============================================================

  Future<void> syncCourse(String courseId) async {
    final courseService = CourseService(client: _client);

    final Course course = await courseService.getCourse(courseId);

    await _offline.saveCourse(course);

    final List<Lesson> lessons = await courseService.listLessons(courseId);

    await _offline.saveLessons(lessons);
  }

  // ============================================================
  // SYNCHRONISATION D'UNE LEÇON
  // ============================================================

  Future<void> syncLesson(String lessonId) async {
    final lessonService = LessonService(client: _client);

    final Lesson lesson = await lessonService.getLesson(lessonId);

    await _offline.saveLesson(lesson);
  }
}
