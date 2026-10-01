import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/timetable_entry.dart';

class TimetableService {
  TimetableService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<TimetableEntry>> listForStudent(String studentId) async {
    final rows = await _client
        .from('student_timetable_entries')
        .select(
          'id, day_of_week, start_time, end_time, subject, teacher_name, room, notes',
        )
        .eq('student_id', studentId)
        .order('day_of_week')
        .order('start_time');

    return (rows as List)
        .map((row) => TimetableEntry.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}
