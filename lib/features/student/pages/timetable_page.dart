import 'package:flutter/material.dart';

import '../../../core/services/timetable_service.dart';
import '../../../models/timetable_entry.dart';
import '../../../models/user_profile.dart';

class TimetablePage extends StatelessWidget {
  final Locale locale;
  final UserProfile profile;

  const TimetablePage({super.key, required this.locale, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isFrench = locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFrench ? 'Mon emploi du temps' : 'My timetable'),
      ),
      body: FutureBuilder<List<TimetableEntry>>(
        future: TimetableService().listForStudent(profile.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                isFrench
                    ? 'Impossible de charger l’emploi du temps.'
                    : 'Unable to load the timetable.',
              ),
            );
          }

          final entries = snapshot.data ?? const <TimetableEntry>[];
          if (entries.isEmpty) {
            return Center(
              child: Text(
                isFrench
                    ? 'Aucun cours planifié pour le moment.'
                    : 'No classes are scheduled yet.',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${entry.dayOfWeek}')),
                  title: Text(
                    '${_dayName(entry.dayOfWeek, isFrench)} · ${entry.subject}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${entry.startTime} - ${entry.endTime}'
                    '${entry.teacherName == null ? '' : '\n${entry.teacherName}'}'
                    '${entry.room == null ? '' : ' · ${entry.room}'}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _dayName(int day, bool isFrench) {
    const french = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    const english = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final names = isFrench ? french : english;
    return day >= 1 && day <= 7 ? names[day - 1] : '';
  }
}
