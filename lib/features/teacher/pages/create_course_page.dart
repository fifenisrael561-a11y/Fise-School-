import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/pedagogy_service.dart';
import '../../../models/pedagogy.dart';
import '../../../models/school_class.dart';
import '../../../models/user_profile.dart';
import 'create_lesson_page.dart';

class CreateCoursePage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const CreateCoursePage({
    super.key,
    required this.locale,
    required this.profile,
  });

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final CourseService _service = CourseService();
  final _formKey = GlobalKey<FormState>();

  final _titleFr = TextEditingController();
  final _titleEn = TextEditingController();
  final _descriptionFr = TextEditingController();
  final _descriptionEn = TextEditingController();
  final _contentFr = TextEditingController();
  final _contentEn = TextEditingController();

  late Future<List<SchoolClass>> _classesFuture;
  late Future<List<Subject>> _subjectsFuture;

  Curriculum? _curriculum;
  CourseChapter? _chapter;
  SchoolClass? _schoolClass;
  Subject? _subject;

  List<Curriculum> _curricula = const [];
  List<CourseChapter> _chapters = const [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _classesFuture = _service.listTeacherClasses(widget.profile.id);
    _subjectsFuture = _service.listSubjects(widget.profile);
  }

  @override
  void dispose() {
    for (final controller in [
      _titleFr,
      _titleEn,
      _descriptionFr,
      _descriptionEn,
      _contentFr,
      _contentEn,
    ]) {
      controller.dispose();
    }

    super.dispose();
  }

  Future<void> _selectSubject(Subject? subject) async {
    setState(() {
      _subject = subject;
      _curriculum = null;
      _chapter = null;
      _curricula = const [];
      _chapters = const [];
    });

    if (subject == null) {
      return;
    }

    try {
      final curricula = await _service.listCurricula(subject.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _curricula = curricula;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppTexts(widget.locale).pedagogyLoadError}\n$error'),
        ),
      );
    }
  }

  Future<void> _selectCurriculum(Curriculum? curriculum) async {
    setState(() {
      _curriculum = curriculum;
      _chapter = null;
      _chapters = const [];
    });

    if (curriculum == null) {
      return;
    }

    try {
      final chapters = await _service.listChapters(curriculum.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _chapters = chapters;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppTexts(widget.locale).pedagogyLoadError}\n$error'),
        ),
      );
    }
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate() ||
        _schoolClass == null ||
        _subject == null ||
        _curriculum == null ||
        _chapter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTexts(widget.locale).completeCourseFields)),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final course = await _service.saveCourse(
        curriculumId: _curriculum!.id,
        chapterId: _chapter!.id,
        subjectId: _subject!.id,
        teacherId: widget.profile.id,
        classId: _schoolClass!.id,
        titleFr: _titleFr.text,
        titleEn: _titleEn.text,
        descriptionFr: _descriptionFr.text,
        descriptionEn: _descriptionEn.text,
        contentFr: _contentFr.text,
        contentEn: _contentEn.text,
        status: status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateLessonPage(
            locale: widget.locale,
            profile: widget.profile,
            course: course,
          ),
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppTexts(widget.locale).courseSaveError}\n$error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(widget.locale);

    return Scaffold(
      appBar: AppBar(title: Text(texts.createCourse)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FutureBuilder<List<SchoolClass>>(
              future: _classesFuture,
              builder: (_, snapshot) {
                return _dropdown<SchoolClass>(
                  label: texts.schoolClass,
                  value: _schoolClass,
                  items: snapshot.data ?? const [],
                  labelOf: (item) => item.displayName,
                  onChanged: (value) {
                    setState(() {
                      _schoolClass = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Subject>>(
              future: _subjectsFuture,
              builder: (_, snapshot) {
                return _dropdown<Subject>(
                  label: texts.subjects,
                  value: _subject,
                  items: snapshot.data ?? const [],
                  labelOf: (item) => item.labelFor(widget.locale.languageCode),
                  onChanged: _selectSubject,
                );
              },
            ),
            const SizedBox(height: 12),
            _dropdown<Curriculum>(
              label: texts.curriculum,
              value: _curriculum,
              items: _curricula,
              labelOf: (item) => item.labelFor(widget.locale.languageCode),
              onChanged: _selectCurriculum,
            ),
            const SizedBox(height: 12),
            _dropdown<CourseChapter>(
              label: texts.chapter,
              value: _chapter,
              items: _chapters,
              labelOf: (item) => item.labelFor(widget.locale.languageCode),
              onChanged: (value) {
                setState(() {
                  _chapter = value;
                });
              },
            ),
            const SizedBox(height: 20),
            _field(_titleFr, texts.titleFrench),
            _field(_titleEn, texts.titleEnglish),
            _field(_descriptionFr, texts.descriptionFrench, required: false),
            _field(_descriptionEn, texts.descriptionEnglish, required: false),
            _field(
              _contentFr,
              texts.contentFrench,
              required: false,
              maxLines: 6,
            ),
            _field(
              _contentEn,
              texts.contentEnglish,
              required: false,
              maxLines: 6,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save('draft'),
                    child: Text(texts.saveDraft),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _save('published'),
                    child: Text(texts.publish),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppTexts(widget.locale).requiredField;
                }

                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
          )
          .toList(),
      onChanged: onChanged,
      validator: (selected) {
        if (selected == null) {
          return AppTexts(widget.locale).requiredField;
        }

        return null;
      },
    );
  }
}
