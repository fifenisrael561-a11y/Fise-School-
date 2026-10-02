import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/assignment_service.dart';
import '../../core/services/exam_catalog_service.dart';
import '../../core/services/forum_service.dart';
import '../../core/services/grade_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/past_paper_service.dart';
import '../../core/services/pedagogy_service.dart';
import '../../core/services/timetable_service.dart';
import '../../models/pedagogy.dart';
import '../../models/user_profile.dart';
import 'offline_repository.dart';
import 'pending_progress.dart';

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
      try {
        final List<Lesson> lessons = await courseService.listLessons(course.id);
        await _offline.saveLessons(lessons);
      } catch (_) {
        // Keep the rest of the offline cache usable if one course fails.
      }
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

  // ============================================================
  // PROGRESSION FAITE HORS LIGNE
  // ============================================================

  /// Envoie au serveur les leçons ouvertes/terminées sans connexion.
  Future<int> flushPending() => PendingProgress.instance.flush(_client);

  // ============================================================
  // PRÉCHARGEMENT DES AUTRES ÉCRANS DE L'ÉLÈVE
  // ============================================================

  /// Remplit le cache de tous les écrans de consultation : chaque service
  /// enregistre lui-même sa réponse. Une erreur sur un élément n'empêche
  /// jamais les suivants.
  Future<void> syncStudentExtras(UserProfile profile) async {
    final id = profile.id;

    Future<void> safe(Future<void> Function() job) async {
      try {
        await job();
      } catch (_) {}
    }

    await safe(() async {
      await CourseService(client: _client).listClassSubjects(profile);
    });
    await safe(() async {
      await TimetableService(client: _client).listForStudent(id);
    });
    await safe(() async {
      await NotificationService(client: _client).listForUser(id);
    });
    await safe(() async {
      await PastPaperService(client: _client).list();
    });
    await safe(() async {
      await ExamCatalogService(client: _client).getExams();
    });
    await safe(() async {
      final classes = await ForumService(client: _client).listClasses(profile);
      final forum = ForumService(client: _client);
      for (final schoolClass in classes) {
        await safe(() async {
          final topics = await forum.listTopics(schoolClass.id);
          for (final topic in topics) {
            await safe(() async {
              await forum.listPosts(topic.id);
            });
          }
        });
      }
    });
    await safe(() async {
      final service = AssignmentService(client: _client);
      final assignments = await service.listStudentAssignments(studentId: id);
      for (final assignment in assignments) {
        await safe(() async {
          await service.getAssignment(assignment.id);
          await service.listQuestions(assignment.id);
        });
      }
    });
    await safe(() async {
      final grades = GradeService(client: _client);
      final periods = await grades.listPeriods(onlyPublished: true);
      for (final period in periods) {
        await safe(() async {
          await grades.bulletin(id, period.id);
        });
      }
    });
  }
}
