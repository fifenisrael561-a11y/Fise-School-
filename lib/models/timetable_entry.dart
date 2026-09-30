class TimetableEntry {
  final String id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String subject;
  final String? teacherName;
  final String? room;
  final String? notes;

  const TimetableEntry({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.teacherName,
    this.room,
    this.notes,
  });

  factory TimetableEntry.fromMap(Map<String, dynamic> map) {
    return TimetableEntry(
      id: map['id'] as String,
      dayOfWeek: (map['day_of_week'] as num).toInt(),
      startTime: map['start_time'].toString().substring(0, 5),
      endTime: map['end_time'].toString().substring(0, 5),
      subject: map['subject'] as String,
      teacherName: map['teacher_name'] as String?,
      room: map['room'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
