import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/timetable_entry.dart';
import '../offline/json_cache.dart';

class TimetableService {
  TimetableService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  List<TimetableEntry> _decode(Object? raw) {
    return (raw as List)
        .map((r) => TimetableEntry.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList(growable: false);
  }

  Future<List<TimetableEntry>> listForStudent(String studentId) {
    return JsonCache.instance.cachedRead<List<TimetableEntry>>(
      key: 'timetable_student_$studentId',
      fetch: () => _fetchStudentRows(studentId),
      decode: _decode,
    );
  }

  Future<List<dynamic>> _fetchStudentRows(String studentId) async {
    final memberships = await _client
        .from('class_students')
        .select('class_id')
        .eq('student_id', studentId)
        .eq('is_active', true);
    final classIds = memberships
        .map((r) => r['class_id']?.toString())
        .whereType<String>()
        .toList();
    if (classIds.isNotEmpty) {
      // Élève affecté à une salle : seul l'emploi du temps de la salle fait foi.
      return await _client
          .from('class_timetable_entries')
          .select()
          .inFilter('class_id', classIds)
          .eq('is_active', true)
          .order('day_of_week')
          .order('start_time');
    }
    // Ancien emploi du temps individuel : uniquement pour un élève sans salle.
    return await _client
        .from('student_timetable_entries')
        .select('id, day_of_week, start_time, end_time, subject, teacher_name, room, notes')
        .eq('student_id', studentId)
        .order('day_of_week')
        .order('start_time');
  }

  Future<List<TimetableEntry>> listForTeacher(String teacherId) {
    return JsonCache.instance.cachedRead<List<TimetableEntry>>(
      key: 'timetable_teacher_$teacherId',
      fetch: () => _client
          .from('class_timetable_entries')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_active', true)
          .order('day_of_week')
          .order('start_time'),
      decode: _decode,
    );
  }

  Future<List<TimetableEntry>> listForClass(String classId) async {
    final rows = await _client
        .from('class_timetable_entries')
        .select()
        .eq('class_id', classId)
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return rows.map((r) => TimetableEntry.fromMap(Map<String, dynamic>.from(r))).toList();
  }

  Future<void> create({
    required String classId,
    String? subjectId,
    required String subjectFr,
    required String subjectEn,
    String? teacherId,
    String? teacherName,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? room,
    String? notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Session utilisateur absente.');
    await _client.from('class_timetable_entries').insert({
      'class_id': classId,
      'subject_id': subjectId,
      'subject_fr': subjectFr.trim(),
      'subject_en': subjectEn.trim(),
      'teacher_id': teacherId,
      'teacher_name': teacherName?.trim(),
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'room': room?.trim(),
      'notes': notes?.trim(),
      'created_by': user.id,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('class_timetable_entries').delete().eq('id', id);
  }
}
