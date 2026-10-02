import 'package:flutter/material.dart';

import '../../../core/services/timetable_service.dart';
import '../../../models/timetable_entry.dart';
import '../../../models/user_profile.dart';

class TimetablePage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const TimetablePage({super.key, required this.locale, required this.profile});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late Future<List<TimetableEntry>> _future;

  bool get fr => widget.locale.languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = TimetableService().listForStudent(widget.profile.id);
  }

  String _dayName(int day) {
    const frNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const enNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final names = fr ? frNames : enNames;
    return day >= 1 && day <= 7 ? names[day - 1] : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fr ? 'Mon emploi du temps' : 'My timetable'),
        actions: [
          IconButton(
            tooltip: fr ? 'Actualiser' : 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<TimetableEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  fr ? 'Impossible de charger l’emploi du temps.' : 'Unable to load the timetable.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final entries = snapshot.data ?? const <TimetableEntry>[];
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  fr ? 'Aucun cours planifié pour votre salle.' : 'No classes are scheduled for your classroom.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final byDay = <int, List<TimetableEntry>>{};
          for (final entry in entries) {
            byDay.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
          }

          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                for (final day in byDay.keys.toList()..sort()) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
                    child: Text(
                      _dayName(day),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                    ),
                  ),
                  ...byDay[day]!.map((entry) => _SlotCard(entry: entry, french: fr)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  final TimetableEntry entry;
  final bool french;

  const _SlotCard({required this.entry, required this.french});

  @override
  Widget build(BuildContext context) {
    final subject = french ? entry.subject : (entry.subjectEn?.trim().isNotEmpty == true ? entry.subjectEn! : entry.subject);
    final details = <String>[];
    if (entry.teacherName?.trim().isNotEmpty == true) details.add(entry.teacherName!);
    if (entry.room?.trim().isNotEmpty == true) details.add(entry.room!);
    if (entry.notes?.trim().isNotEmpty == true) details.add(entry.notes!);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            entry.startTime,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF166534)),
          ),
        ),
        title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('${entry.startTime} – ${entry.endTime}${details.isEmpty ? '' : '\n${details.join(' · ')}'}'),
      ),
    );
  }
}
