import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/assignment.dart';
import '../offline/json_cache.dart';

class AssignmentService {
  final SupabaseClient _client;

  AssignmentService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  Future<List<Assignment>> listStudentAssignments({
    required String studentId,
    String? courseId,
    String? lessonId,
  }) {
    return JsonCache.instance.cachedRead<List<Assignment>>(
      key: 'assignments_${studentId}_${courseId ?? 'all'}_${lessonId ?? 'all'}',
      fetch: () => _fetchStudentAssignmentRows(
        studentId: studentId,
        courseId: courseId,
        lessonId: lessonId,
      ),
      decode: (raw) => (raw as List)
          .map((row) => Assignment.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
    );
  }

  Future<List<dynamic>> _fetchStudentAssignmentRows({
    required String studentId,
    String? courseId,
    String? lessonId,
  }) async {
    final memberships = await _client
        .from('class_students')
        .select('class_id')
        .eq('student_id', studentId)
        .eq('is_active', true);

    final classIds = memberships
        .map((row) => row['class_id'])
        .whereType<String>()
        .toList(growable: false);

    if (classIds.isEmpty) {
      return const <dynamic>[];
    }

    var request = _client
        .from('assignments')
        .select()
        .inFilter('class_id', classIds)
        .inFilter('status', ['published', 'closed']);

    if (courseId != null) {
      request = request.eq('course_id', courseId);
    }

    if (lessonId != null) {
      request = request.eq('lesson_id', lessonId);
    }

    return await request.order('due_at', ascending: true);
  }

  Future<Assignment> getAssignment(String id) {
    return JsonCache.instance.cachedRead<Assignment>(
      key: 'assignment_$id',
      fetch: () => _client.from('assignments').select().eq('id', id).single(),
      decode: (raw) =>
          Assignment.fromMap(Map<String, dynamic>.from(raw as Map)),
    );
  }

  Future<List<AssignmentQuestion>> listQuestions(String assignmentId) {
    return JsonCache.instance.cachedRead<List<AssignmentQuestion>>(
      key: 'assignment_questions_$assignmentId',
      fetch: () => _client
          .from('assignment_questions')
          .select()
          .eq('assignment_id', assignmentId)
          .order('position', ascending: true),
      decode: (raw) => (raw as List)
          .map(
            (row) => AssignmentQuestion.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<AssignmentSubmission?> getStudentSubmission({
    required String assignmentId,
    required String studentId,
  }) async {
    final row = await _client
        .from('assignment_submissions')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return AssignmentSubmission.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AssignmentSubmission> createOrGetStudentSubmission({
    required String assignmentId,
    required String studentId,
  }) async {
    final existing = await getStudentSubmission(
      assignmentId: assignmentId,
      studentId: studentId,
    );

    if (existing != null) {
      return existing;
    }

    final row = await _client
        .from('assignment_submissions')
        .insert({
          'assignment_id': assignmentId,
          'student_id': studentId,
          'status': 'draft',
        })
        .select()
        .single();

    return AssignmentSubmission.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<AssignmentAnswer>> listAnswers(String submissionId) async {
    final rows = await _client
        .from('assignment_answers')
        .select()
        .eq('submission_id', submissionId)
        .order('created_at', ascending: true);

    return rows
        .map((row) => AssignmentAnswer.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<AssignmentAnswer?> getAnswer({
    required String submissionId,
    required String questionId,
  }) async {
    final row = await _client
        .from('assignment_answers')
        .select()
        .eq('submission_id', submissionId)
        .eq('question_id', questionId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return AssignmentAnswer.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AssignmentAnswer> saveAnswer({
    required String submissionId,
    required String questionId,
    String? answerText,
    String? selectedOption,
  }) async {
    final row = await _client
        .from('assignment_answers')
        .upsert({
          'submission_id': submissionId,
          'question_id': questionId,
          'answer_text': answerText,
          'selected_option': selectedOption,
        }, onConflict: 'submission_id,question_id')
        .select()
        .single();

    return AssignmentAnswer.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AssignmentSubmission> submitAssignment({
    required String submissionId,
  }) async {
    final now = DateTime.now().toIso8601String();

    final row = await _client
        .from('assignment_submissions')
        .update({'status': 'submitted', 'submitted_at': now, 'updated_at': now})
        .eq('id', submissionId)
        .select()
        .single();

    return AssignmentSubmission.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<Assignment>> listTeacherAssignments({
    required String teacherId,
    String? courseId,
    String? classId,
    String? status,
  }) async {
    var request = _client
        .from('assignments')
        .select()
        .eq('teacher_id', teacherId);

    if (courseId != null) {
      request = request.eq('course_id', courseId);
    }

    if (classId != null) {
      request = request.eq('class_id', classId);
    }

    if (status != null) {
      request = request.eq('status', status);
    }

    final rows = await request.order('updated_at', ascending: false);

    return rows
        .map((row) => Assignment.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<Assignment> saveAssignment({
    String? id,
    required String courseId,
    String? lessonId,
    required String teacherId,
    required String classId,
    required String titleFr,
    required String titleEn,
    String? instructionsFr,
    String? instructionsEn,
    DateTime? dueAt,
    required String status,
    double maxScore = 20,
  }) async {
    final values = {
      'course_id': courseId,
      'lesson_id': lessonId,
      'teacher_id': teacherId,
      'class_id': classId,
      'title_fr': titleFr.trim(),
      'title_en': titleEn.trim(),
      'instructions_fr': instructionsFr?.trim(),
      'instructions_en': instructionsEn?.trim(),
      'due_at': dueAt?.toIso8601String(),
      'status': status,
      'max_score': maxScore,
      'published_at': status == 'published'
          ? DateTime.now().toIso8601String()
          : null,
    };

    final row = id == null
        ? await _client.from('assignments').insert(values).select().single()
        : await _client
              .from('assignments')
              .update(values)
              .eq('id', id)
              .select()
              .single();

    return Assignment.fromMap(Map<String, dynamic>.from(row));
  }

  Future<AssignmentQuestion> saveQuestion({
    String? id,
    required String assignmentId,
    required int position,
    required String questionFr,
    required String questionEn,
    required String questionType,
    double points = 1,
    List<String> options = const [],
    String? correctAnswer,
  }) async {
    final values = {
      'assignment_id': assignmentId,
      'position': position,
      'question_fr': questionFr.trim(),
      'question_en': questionEn.trim(),
      'question_type': questionType,
      'points': points,
      'options': options,
      'correct_answer': correctAnswer,
    };

    final row = id == null
        ? await _client
              .from('assignment_questions')
              .insert(values)
              .select()
              .single()
        : await _client
              .from('assignment_questions')
              .update(values)
              .eq('id', id)
              .select()
              .single();

    return AssignmentQuestion.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> deleteQuestion(String questionId) async {
    await _client.from('assignment_questions').delete().eq('id', questionId);
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _client.from('assignments').delete().eq('id', assignmentId);
  }

  Future<void> publishAssignment(String assignmentId) async {
    await _client
        .from('assignments')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toIso8601String(),
        })
        .eq('id', assignmentId);
  }

  Future<void> closeAssignment(String assignmentId) async {
    await _client
        .from('assignments')
        .update({'status': 'closed'})
        .eq('id', assignmentId);
  }
}
