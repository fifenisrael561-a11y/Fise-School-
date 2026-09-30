import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/pedagogy_service.dart';
import '../../../models/pedagogy.dart';
import '../../../models/user_profile.dart';
import 'course_detail_page.dart';

class CoursesPage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const CoursesPage({super.key, required this.locale, required this.profile});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final CourseService _service = CourseService();
  late Future<List<ClassSubjectEntry>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _subjectsFuture = _service.listClassSubjects(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(widget.locale);

    return Scaffold(
      appBar: AppBar(title: Text(texts.courses)),
      body: FutureBuilder<List<ClassSubjectEntry>>(
        future: _subjectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _Message(texts.pedagogyLoadError);
          }

          final subjects = snapshot.data ?? const <ClassSubjectEntry>[];

          if (subjects.isEmpty) {
            return _Message(texts.noCoursesYet);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: subjects.length + 1,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              if (index == 0) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.school_rounded, color: Color(0xFF166534)),
                    title: Text(widget.profile.className ?? (widget.locale.languageCode == 'fr' ? 'Ma classe' : 'My class')),
                    subtitle: Text(widget.locale.languageCode == 'fr'
                        ? 'Matières et options correspondant à ton sous-système et à ta classe.'
                        : 'Subjects and options matching your subsystem and class.'),
                  ),
                );
              }
              final entry = subjects[index - 1];
              return _SubjectTile(
                entry: entry,
                subject: entry.subject,
                locale: widget.locale,
                service: _service,
                studentId: widget.profile.id,
              );
            },
          );
        },
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final ClassSubjectEntry entry;
  final Subject subject;
  final Locale locale;
  final CourseService service;
  final String studentId;

  const _SubjectTile({
    required this.entry,
    required this.subject,
    required this.locale,
    required this.service,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(locale);

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_rounded, color: Color(0xFF166534)),
        title: Text(
          subject.labelFor(locale.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          entry.isCompulsory
              ? (locale.languageCode == 'fr' ? 'Matière obligatoire • ${subject.code}' : 'Compulsory • ${subject.code}')
              : '${entry.optionGroup ?? (locale.languageCode == 'fr' ? 'Option' : 'Option')} • ${subject.code}',
        ),
        children: [
          FutureBuilder<List<Curriculum>>(
            future: service.listCurricula(subject.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _InlineMessage(texts.pedagogyLoadError);
              }

              final curricula = snapshot.data ?? const <Curriculum>[];

              if (curricula.isEmpty) {
                return _InlineMessage(texts.noCurriculumYet);
              }

              return Column(
                children: curricula
                    .map(
                      (curriculum) => _CurriculumTile(
                        curriculum: curriculum,
                        locale: locale,
                        service: service,
                        studentId: studentId,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CurriculumTile extends StatelessWidget {
  final Curriculum curriculum;
  final Locale locale;
  final CourseService service;
  final String studentId;

  const _CurriculumTile({
    required this.curriculum,
    required this.locale,
    required this.service,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(locale);

    return FutureBuilder<List<Course>>(
      future: service.listStudentCourses(
        studentId,
        subjectId: curriculum.subjectId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }

        if (snapshot.hasError) {
          return _InlineMessage(texts.pedagogyLoadError);
        }

        final courses = (snapshot.data ?? const <Course>[])
            .where((course) => course.curriculumId == curriculum.id)
            .toList();

        return ExpansionTile(
          title: Text(curriculum.labelFor(locale.languageCode)),
          subtitle: Text(curriculum.descriptionFor(locale.languageCode) ?? ''),
          children: courses.isEmpty
              ? [_InlineMessage(texts.noPublishedCourses)]
              : courses
                    .map(
                      (course) => ListTile(
                        leading: const Icon(Icons.play_lesson_outlined),
                        title: Text(course.labelFor(locale.languageCode)),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseDetailPage(
                              locale: locale,
                              profile: _getProfile(context),
                              course: course,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
        );
      },
    );
  }

  UserProfile _getProfile(BuildContext context) {
    final coursesPage = context.findAncestorWidgetOfExactType<CoursesPage>();

    if (coursesPage == null) {
      throw StateError('CoursesPage introuvable dans l’arbre des widgets.');
    }

    return coursesPage.profile;
  }
}

class _Message extends StatelessWidget {
  final String message;

  const _Message(this.message);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  final String message;

  const _InlineMessage(this.message);

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(16), child: Text(message));
}

extension on Curriculum {
  String? descriptionFor(String languageCode) =>
      languageCode == 'en' ? descriptionEn : descriptionFr;
}
