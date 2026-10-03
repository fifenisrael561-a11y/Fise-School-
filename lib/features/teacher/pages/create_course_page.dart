import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/pedagogy_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../models/pedagogy.dart';
import '../../../models/school_class.dart';
import '../../../models/user_profile.dart';
import '../widgets/class_subject_picker.dart';

class _CourseAttachment {
  final String name;
  final Uint8List bytes;
  final String resourceType;

  const _CourseAttachment({
    required this.name,
    required this.bytes,
    required this.resourceType,
  });
}

/// Création d'un cours : l'enseignant choisit la ou les classes, la matière,
/// écrit son cours et joint un PDF, une photo ou des images.
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
  final ResourceService _resources = ResourceService();
  final PhotoService _photos = PhotoService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _smartLessonEnabled = false;
  double _minimumScore = 70.0;

  final _title = TextEditingController();
  final _content = TextEditingController();

  List<SchoolClass> _classes = const [];
  Subject? _subject;
  final List<_CourseAttachment> _attachments = [];
  bool _saving = false;

  bool get _fr => widget.locale.languageCode == 'fr';

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _typeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'pdf';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
        return 'image';
      case 'mp4':
        return 'video';
      case 'mp3':
      case 'm4a':
      case 'aac':
        return 'audio';
      case 'doc':
      case 'docx':
      case 'ppt':
      case 'pptx':
      case 'xls':
      case 'xlsx':
      case 'txt':
        return 'document';
      default:
        return 'other';
    }
  }

  Future<void> _takePhoto() async {
    final file = await _photos.takePhoto();
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      _attachments.add(
        _CourseAttachment(
          name: 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg',
          bytes: bytes,
          resourceType: 'image',
        ),
      );
    });
  }

  Future<void> _pickImages() async {
    final files = await _imagePicker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) {
      return;
    }
    final added = <_CourseAttachment>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final name = file.name.isEmpty
          ? 'image-${DateTime.now().millisecondsSinceEpoch}.jpg'
          : file.name;
      added.add(
        _CourseAttachment(name: name, bytes: bytes, resourceType: 'image'),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _attachments.addAll(added));
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
      allowMultiple: true,
    );
    if (result == null) {
      return;
    }
    final added = <_CourseAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        continue;
      }
      added.add(
        _CourseAttachment(name: file.name, bytes: bytes, resourceType: 'pdf'),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() => _attachments.addAll(added));
  }

  Future<void> _pickOtherFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt', 'mp4', 'mp3', 'm4a',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _attachments.add(
        _CourseAttachment(
          name: file.name,
          bytes: bytes,
          resourceType: _typeFromExtension(file.extension ?? ''),
        ),
      );
    });
  }

  Future<void> _save(String status) async {
    final title = _title.text.trim();
    final content = _content.text.trim();

    if (_classes.isEmpty) {
      _snack(_fr ? 'Choisissez au moins une classe.' : 'Choose at least one class.');
      return;
    }
    if (_subject == null) {
      _snack(_fr ? 'Choisissez la matière.' : 'Choose the subject.');
      return;
    }
    if (title.isEmpty) {
      _snack(_fr ? 'Donnez un titre au cours.' : 'Give the course a title.');
      return;
    }
    if (content.isEmpty && _attachments.isEmpty) {
      _snack(_fr
          ? 'Écrivez le cours ou joignez un PDF, une photo ou des images.'
          : 'Write the course or attach a PDF, a photo or images.');
      return;
    }

    setState(() => _saving = true);

    var published = 0;
    final errors = <String>[];

    for (final schoolClass in _classes) {
      try {
        final course = await _service.saveCourse(
          subjectId: _subject!.id,
          teacherId: widget.profile.id,
          classId: schoolClass.id,
          titleFr: title,
          titleEn: title,
          contentFr: content.isEmpty ? null : content,
          contentEn: content.isEmpty ? null : content,
          smartLessonEnabled: _smartLessonEnabled,
          minimumExerciseScore: _minimumScore.round(),
          status: status,
        );

        for (var i = 0; i < _attachments.length; i++) {
          final attachment = _attachments[i];
          await _resources.uploadResource(
            courseId: course.id,
            file: PlatformFile(
              name: attachment.name,
              size: attachment.bytes.length,
              bytes: attachment.bytes,
            ),
            resourceType: attachment.resourceType,
            position: i,
            titleFr: attachment.name,
            titleEn: attachment.name,
          );
        }
        published++;
      } catch (error) {
        errors.add('${schoolClass.displayName}: $error');
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (errors.isNotEmpty) {
      _snack(
        '${_fr ? 'Erreur' : 'Error'} (${errors.length}/${_classes.length})\n${errors.first}',
      );
      if (published == 0) {
        return;
      }
    } else {
      _snack(status == 'published'
          ? (_fr ? 'Cours publié dans $published classe(s).' : 'Course published in $published class(es).')
          : (_fr ? 'Brouillon enregistré.' : 'Draft saved.'));
    }

    Navigator.pop(context, true);
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'video':
        return Icons.videocam_rounded;
      case 'audio':
        return Icons.audiotrack_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_fr ? 'Créer un cours' : 'Create a course')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClassSubjectPicker(
            locale: widget.locale,
            teacherId: widget.profile.id,
            onChanged: (classes, subject) {
              setState(() {
                _classes = classes;
                _subject = subject;
              });
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _fr ? 'Titre du cours' : 'Course title',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _content,
            minLines: 5,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _fr ? 'Contenu du cours (facultatif)' : 'Course content (optional)',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_fr ? 'Autoriser la leçon intelligente' : 'Allow smart lessons', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(_fr ? 'L’IA reformulera uniquement le contenu indexé et validé.' : 'AI will only reformulate indexed and approved course content.'),
                    value: _smartLessonEnabled,
                    onChanged: _saving ? null : (value) => setState(() => _smartLessonEnabled = value),
                  ),
                  if (_smartLessonEnabled) ...[
                    const SizedBox(height: 8),
                    Text(_fr ? 'Score minimum pour débloquer la suite : ${_minimumScore.round()} %' : 'Minimum score to unlock the next lesson: ${_minimumScore.round()}%'),
                    Slider(
                      value: _minimumScore,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_minimumScore.round()}%',
                      onChanged: _saving ? null : (value) => setState(() => _minimumScore = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fr ? 'Joindre au cours' : 'Attach to the course',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(_fr ? 'Envoyer un PDF' : 'Send a PDF'),
                onPressed: _saving ? null : _pickPdf,
              ),
              ActionChip(
                avatar: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(_fr ? 'Prendre une photo' : 'Take a photo'),
                onPressed: _saving ? null : _takePhoto,
              ),
              ActionChip(
                avatar: const Icon(Icons.image_rounded, size: 18),
                label: Text(_fr ? 'Images' : 'Images'),
                onPressed: _saving ? null : _pickImages,
              ),
              ActionChip(
                avatar: const Icon(Icons.attach_file_rounded, size: 18),
                label: Text(_fr ? 'Autre fichier' : 'Other file'),
                onPressed: _saving ? null : _pickOtherFile,
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _attachments.length; i++)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: _attachments[i].resourceType == 'image'
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.memory(
                          _attachments[i].bytes,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(_iconFor(_attachments[i].resourceType)),
                title: Text(_attachments[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _saving ? null : () => setState(() => _attachments.removeAt(i)),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => _save('draft'),
                  child: Text(_fr ? 'Brouillon' : 'Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : () => _save('published'),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_fr ? 'Publier' : 'Publish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
