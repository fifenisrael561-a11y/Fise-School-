import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pedagogy.dart';
import '../../models/school_class.dart';
import '../../models/user_profile.dart';
import '../offline/json_cache.dart';
import '../offline/offline_repository.dart';
import '../offline/pending_progress.dart';

class SubjectService {
  final SupabaseClient _client;

  SubjectService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<Subject>> listForProfile(UserProfile profile) async {
    if (profile.subsystem == null || profile.sector == null) {
      return const [];
    }

    final rows = await _client
        .from('subjects')
        .select()
        .eq('subsystem', profile.subsystem!)
        .eq('sector', profile.sector!)
        .eq('is_active', true)
        .order('name_fr');

    return rows
        .map((row) => Subject.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }
}

class CourseService {
  final SupabaseClient _client;

  CourseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<ClassSubjectEntry>> listClassSubjects(UserProfile profile) async {
    if (profile.subsystem == null || profile.sector == null) return const [];

    return JsonCache.instance.cachedRead<List<ClassSubjectEntry>>(
      key: 'class_subjects_${profile.id}',
      fetch: () => _fetchClassSubjectRows(profile),
      decode: (raw) => _decodeClassSubjects(profile, raw),
    );
  }

  Future<List<dynamic>> _fetchClassSubjectRows(UserProfile profile) async {
    // The student's active class is the source of truth. This prevents a
    // Francophone student from seeing Anglophone classes/subjects and vice versa.
    final memberships = await _client
        .from('class_students')
        .select('class_id, school_classes(subsystem, sector)')
        .eq('student_id', profile.id)
        .eq('is_active', true);

    final classIds = <String>[];
    for (final row in memberships) {
      final context = row['school_classes'];
      if (context is Map &&
          context['subsystem']?.toString() == profile.subsystem &&
          context['sector']?.toString() == profile.sector) {
        classIds.add(row['class_id'] as String);
      }
    }
    if (classIds.isEmpty) return const <dynamic>[];

    return await _client
        .from('class_subjects')
        .select('subject_id, is_compulsory, option_group, position, subjects(*)')
        .inFilter('class_id', classIds)
        .eq('is_active', true)
        .order('position');
  }

  List<ClassSubjectEntry> _decodeClassSubjects(
    UserProfile profile,
    Object? raw,
  ) {
    final seen = <String>{};
    final result = <ClassSubjectEntry>[];
    for (final row in (raw as List)) {
      final entry = ClassSubjectEntry.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
      if (entry.subject.subsystem.name != profile.subsystem ||
          entry.subject.sector.name != profile.sector) {
        continue;
      }
      if (seen.add(entry.subject.id)) result.add(entry);
    }
    return result;
  }

  Future<List<Subject>> listSubjects(UserProfile profile) async {
    final entries = await listClassSubjects(profile);
    if (entries.isNotEmpty) return entries.map((e) => e.subject).toList(growable: false);
    return SubjectService(client: _client).listForProfile(profile);
  }

  /// Subjects explicitly assigned to one classroom. Teachers use this when
  /// creating content so a subject can never silently come from another room.
  Future<List<Subject>> listSubjectsForClass(String classId) async {
    final rows = await _client
        .from('class_subjects')
        .select('subject_id, is_compulsory, option_group, position, subjects(*)')
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('position');

    return rows
        .map((row) => ClassSubjectEntry.fromMap(Map<String, dynamic>.from(row)).subject)
        .toList(growable: false);
  }

  Future<List<Curriculum>> listCurricula(String subjectId) async {
    final rows = await _client
        .from('curricula')
        .select()
        .eq('subject_id', subjectId)
        .eq('is_active', true)
        .order('title_fr');

    return rows
        .map((row) => Curriculum.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<CourseChapter>> listChapters(String curriculumId) async {
    final rows = await _client
        .from('course_chapters')
        .select()
        .eq('curriculum_id', curriculumId)
        .eq('is_active', true)
        .order('position');

    return rows
        .map((row) => CourseChapter.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<Course>> listStudentCourses(
    String studentId, {
    String? subjectId,
  }) async {
    try {
      final memberships = await _client
          .from('class_students')
          .select('class_id')
          .eq('student_id', studentId)
          .eq('is_active', true)
          .timeout(JsonCache.networkTimeout);

      final classIds = memberships
          .map((row) => row['class_id'] as String)
          .toList(growable: false);

      if (classIds.isEmpty) return const [];

      dynamic request = _client
          .from('courses')
          .select()
          .eq('status', 'published')
          .inFilter('class_id', classIds);

      if (subjectId != null) request = request.eq('subject_id', subjectId);

      final rows = await request
          .order('updated_at', ascending: false)
          .timeout(JsonCache.networkTimeout);
      final courses = rows
          .map((row) => Course.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);

      if (subjectId == null) {
        await OfflineRepository().replaceCourses(courses);
      } else {
        await OfflineRepository().saveCourses(courses);
      }
      return courses;
    } catch (_) {
      final cached = await OfflineRepository().getCoursesForStudent(studentId);
      if (subjectId == null) return cached;
      return cached.where((course) => course.subjectId == subjectId).toList(growable: false);
    }
  }

  Future<Course> getCourse(String id) async {
    try {
      final row = await _client
          .from('courses')
          .select()
          .eq('id', id)
          .single()
          .timeout(JsonCache.networkTimeout);
      final course = Course.fromMap(Map<String, dynamic>.from(row));
      await OfflineRepository().saveCourse(course);
      return course;
    } catch (_) {
      final cached = await OfflineRepository().getCourse(id);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<Lesson>> listLessons(String courseId) async {
    try {
      final rows = await _client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .eq('is_published', true)
          .order('position')
          .timeout(JsonCache.networkTimeout);
      final lessons = rows
          .map((row) => Lesson.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      await OfflineRepository().saveLessons(lessons);
      return lessons;
    } catch (_) {
      return OfflineRepository().getLessonsForCourse(courseId);
    }
  }

  Future<List<Course>> listTeacherCourses(
    String teacherId, {
    String? status,
  }) async {
    dynamic request = _client
        .from('courses')
        .select()
        .eq('teacher_id', teacherId);

    if (status != null) {
      request = request.eq('status', status);
    }

    final rows = await request.order('updated_at', ascending: false);

    return rows
        .map((row) => Course.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<List<SchoolClass>> listTeacherClasses(String teacherId) async {
    final rows = await _client
        .from('class_teachers')
        .select('school_classes!inner(*)')
        .eq('teacher_id', teacherId)
        .eq('is_active', true);

    return rows
        .map(
          (row) => SchoolClass.fromMap(
            Map<String, dynamic>.from(row['school_classes'] as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<Course> saveCourse({
    String? id,
    required String curriculumId,
    required String chapterId,
    required String subjectId,
    required String teacherId,
    required String classId,
    required String titleFr,
    required String titleEn,
    String? descriptionFr,
    String? descriptionEn,
    String? contentFr,
    String? contentEn,
    required String status,
  }) async {
    final values = <String, dynamic>{
      'curriculum_id': curriculumId,
      'chapter_id': chapterId,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'class_id': classId,
      'title_fr': titleFr.trim(),
      'title_en': titleEn.trim(),
      'description_fr': descriptionFr?.trim(),
      'description_en': descriptionEn?.trim(),
      'content_fr': contentFr?.trim(),
      'content_en': contentEn?.trim(),
      'status': status,
      'published_at': status == 'published'
          ? DateTime.now().toIso8601String()
          : null,
    };

    final row = id == null
        ? await _client.from('courses').insert(values).select().single()
        : await _client
              .from('courses')
              .update(values)
              .eq('id', id)
              .select()
              .single();

    return Course.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> archiveCourse(String id) async {
    await _client.from('courses').update({'status': 'archived'}).eq('id', id);
  }
}

class LessonService {
  final SupabaseClient _client;

  LessonService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<Lesson> getLesson(String id) async {
    try {
      final row = await _client
          .from('lessons')
          .select()
          .eq('id', id)
          .single()
          .timeout(JsonCache.networkTimeout);
      final lesson = Lesson.fromMap(Map<String, dynamic>.from(row));
      await OfflineRepository().saveLesson(lesson);
      return lesson;
    } catch (_) {
      final cached = await OfflineRepository().getLesson(id);
      if (cached == null) rethrow;
      return cached;
    }
  }

  Future<List<Lesson>> listLessons(String courseId) async {
    try {
      final rows = await _client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .eq('is_published', true)
          .order('position')
          .timeout(JsonCache.networkTimeout);
      final lessons = rows
          .map((row) => Lesson.fromMap(Map<String, dynamic>.from(row)))
          .toList(growable: false);
      await OfflineRepository().saveLessons(lessons);
      return lessons;
    } catch (_) {
      return OfflineRepository().getLessonsForCourse(courseId);
    }
  }

  Future<List<Lesson>> listCourseLessons(String courseId) {
    return listLessons(courseId);
  }

  Future<List<Lesson>> listAllLessons(String courseId) async {
    final rows = await _client
        .from('lessons')
        .select()
        .eq('course_id', courseId)
        .order('position');

    return rows
        .map((row) => Lesson.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Lesson> saveLesson({
    String? id,
    required String courseId,
    required String titleFr,
    required String titleEn,
    String? contentFr,
    String? contentEn,
    required int position,
    required int durationMinutes,
    String? objectivesFr,
    String? objectivesEn,
    String? examplesFr,
    String? examplesEn,
    String? summaryFr,
    String? summaryEn,
    int? estimatedMinutes,
    required bool isPublished,
  }) async {
    final values = <String, dynamic>{
      'course_id': courseId,
      'title_fr': titleFr.trim(),
      'title_en': titleEn.trim(),
      'content_fr': contentFr?.trim(),
      'content_en': contentEn?.trim(),
      'position': position,
      'duration_minutes': durationMinutes,
      'objectives_fr': objectivesFr?.trim(),
      'objectives_en': objectivesEn?.trim(),
      'examples_fr': examplesFr?.trim(),
      'examples_en': examplesEn?.trim(),
      'summary_fr': summaryFr?.trim(),
      'summary_en': summaryEn?.trim(),
      'estimated_minutes': estimatedMinutes,
      'is_published': isPublished,
    };

    final row = id == null
        ? await _client.from('lessons').insert(values).select().single()
        : await _client
              .from('lessons')
              .update(values)
              .eq('id', id)
              .select()
              .single();

    return Lesson.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteLesson(String id) async {
    await _client.from('lessons').delete().eq('id', id);
  }
}

class ProgressService {
  final SupabaseClient _client;

  ProgressService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  String _cacheKey(String studentId, String lessonId) =>
      'progress_${studentId}_$lessonId';

  /// Lecture de la progression : serveur d'abord, copie locale sinon.
  Future<LessonProgress?> get(String studentId, String lessonId) async {
    try {
      final row = await _client
          .from('lesson_progress')
          .select()
          .eq('student_id', studentId)
          .eq('lesson_id', lessonId)
          .maybeSingle()
          .timeout(JsonCache.networkTimeout);

      if (row == null) {
        return await _local(studentId, lessonId);
      }

      final map = Map<String, dynamic>.from(row);
      try {
        await JsonCache.instance.write(_cacheKey(studentId, lessonId), map);
      } catch (_) {}
      return LessonProgress.fromMap(map);
    } catch (_) {
      return _local(studentId, lessonId);
    }
  }

  Future<LessonProgress?> _local(String studentId, String lessonId) async {
    final raw = await JsonCache.instance.read(_cacheKey(studentId, lessonId));
    if (raw is! Map) return null;
    try {
      return LessonProgress.fromMap(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// Enregistre l'état localement et le met en file d'attente d'envoi.
  Future<LessonProgress> _saveOffline(Map<String, dynamic> values) async {
    final studentId = values['student_id'] as String;
    final lessonId = values['lesson_id'] as String;
    final local = <String, dynamic>{
      'id': 'local:$studentId:$lessonId',
      ...values,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await JsonCache.instance.write(_cacheKey(studentId, lessonId), local);
    await PendingProgress.instance.enqueue(values);
    return LessonProgress.fromMap(local);
  }

  Future<LessonProgress> open({
    required String studentId,
    required String lessonId,
  }) async {
    final existing = await get(studentId, lessonId);
    final now = DateTime.now().toIso8601String();

    final values = <String, dynamic>{
      'student_id': studentId,
      'lesson_id': lessonId,
      'status': existing?.status == 'completed' ? 'completed' : 'in_progress',
      'progress_percent': existing?.progressPercent ?? 0,
      'started_at': existing?.startedAt?.toIso8601String() ?? now,
      'last_opened_at': now,
      'completed_at': existing?.completedAt?.toIso8601String(),
    };

    try {
      final row = await _client
          .from('lesson_progress')
          .upsert(values, onConflict: 'student_id,lesson_id')
          .select()
          .single()
          .timeout(JsonCache.networkTimeout);

      final map = Map<String, dynamic>.from(row);
      try {
        await JsonCache.instance.write(_cacheKey(studentId, lessonId), map);
      } catch (_) {}
      return LessonProgress.fromMap(map);
    } catch (_) {
      // Hors ligne : la leçon s'ouvre quand même, la progression sera
      // envoyée plus tard.
      return _saveOffline(values);
    }
  }

  Future<LessonProgress> complete({
    required String studentId,
    required String lessonId,
  }) async {
    final existing = await get(studentId, lessonId);
    final now = DateTime.now().toIso8601String();

    final values = <String, dynamic>{
      'student_id': studentId,
      'lesson_id': lessonId,
      'status': 'completed',
      'progress_percent': 100,
      'started_at': existing?.startedAt?.toIso8601String() ?? now,
      'last_opened_at': now,
      'completed_at': now,
    };

    try {
      final row = await _client
          .from('lesson_progress')
          .upsert(values, onConflict: 'student_id,lesson_id')
          .select()
          .single()
          .timeout(JsonCache.networkTimeout);

      final map = Map<String, dynamic>.from(row);
      try {
        await JsonCache.instance.write(_cacheKey(studentId, lessonId), map);
      } catch (_) {}
      return LessonProgress.fromMap(map);
    } catch (_) {
      return _saveOffline(values);
    }
  }
}

class ResourceService {
  final SupabaseClient _client;

  ResourceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String bucket = 'course-resources';

  Future<List<CourseResource>> listForCourse(String courseId) {
    return JsonCache.instance.cachedRead<List<CourseResource>>(
      key: 'resources_course_$courseId',
      fetch: () => _client
          .from('course_resources')
          .select()
          .eq('course_id', courseId)
          .order('position'),
      decode: _decodeResources,
    );
  }

  Future<List<CourseResource>> listForLesson(String lessonId) {
    return JsonCache.instance.cachedRead<List<CourseResource>>(
      key: 'resources_lesson_$lessonId',
      fetch: () => _client
          .from('course_resources')
          .select()
          .eq('lesson_id', lessonId)
          .order('position'),
      decode: _decodeResources,
    );
  }

  List<CourseResource> _decodeResources(Object? raw) {
    return (raw as List)
        .map((row) => CourseResource.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<String> createSignedUrl(String storagePath, {int expiresIn = 3600}) {
    return _client.storage.from(bucket).createSignedUrl(storagePath, expiresIn);
  }

  Future<CourseResource> uploadResource({
    required String courseId,
    String? lessonId,
    required PlatformFile file,
    required String resourceType,
    required int position,
    String? titleFr,
    String? titleEn,
  }) async {
    Uint8List? bytes = file.bytes;

    if (bytes == null) {
      throw Exception('Le fichier sélectionné ne contient aucune donnée.');
    }

    final extension = file.extension?.toLowerCase() ?? '';
    final safeFileName = file.name.isEmpty ? 'resource' : file.name;

    final fileId = DateTime.now().microsecondsSinceEpoch;

    final storagePath = [
      courseId,
      ?lessonId,
      '$fileId-$safeFileName',
    ].join('/');

    await _client.storage
        .from(bucket)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    final values = <String, dynamic>{
      'course_id': courseId,
      'lesson_id': lessonId,
      'storage_path': storagePath,
      'file_name': safeFileName,
      'resource_type': resourceType,
      'position': position,
      'title_fr': titleFr?.trim(),
      'title_en': titleEn?.trim(),
      if (extension.isNotEmpty) 'file_extension': extension,
    };

    try {
      final row = await _client
          .from('course_resources')
          .insert(values)
          .select()
          .single();

      return CourseResource.fromMap(Map<String, dynamic>.from(row));
    } catch (_) {
      try {
        await _client.storage.from(bucket).remove([storagePath]);
      } catch (_) {
        // On ignore l'erreur de nettoyage.
      }

      rethrow;
    }
  }

  Future<void> deleteResource(CourseResource resource) async {
    try {
      await _client.storage.from(bucket).remove([resource.storagePath]);
    } finally {
      await _client.from('course_resources').delete().eq('id', resource.id);
    }
  }
}
