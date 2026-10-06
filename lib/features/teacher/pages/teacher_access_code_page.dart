import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/pedagogy_service.dart';
import '../../../core/services/teacher_access_code_service.dart';
import '../../../models/school_class.dart';
import '../../../models/teacher_access_code.dart';
import '../../../models/user_profile.dart';

class TeacherAccessCodePage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const TeacherAccessCodePage({
    super.key,
    required this.locale,
    required this.profile,
  });

  @override
  State<TeacherAccessCodePage> createState() => _TeacherAccessCodePageState();
}

class _TeacherAccessCodePageState extends State<TeacherAccessCodePage> {
  final TeacherAccessCodeService _service = TeacherAccessCodeService();
  final TextEditingController _codeController = TextEditingController();

  List<SchoolClass> _classes = const [];
  List<TeacherAccessCode> _codes = const [];
  String? _selectedClassId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _fr => widget.locale.languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await CourseService().listTeacherClasses(widget.profile.id);
      final codes = await _service.getTeacherAccessCodes(widget.profile.id);
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _codes = codes;
        _selectedClassId = _selectedClassId != null &&
                classes.any((c) => c.id == _selectedClassId)
            ? _selectedClassId
            : (classes.isNotEmpty ? classes.first.id : null);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _fr
            ? 'Impossible de charger vos salles et vos codes.'
            : 'Unable to load your classrooms and codes.';
      });
    }
  }

  TeacherAccessCode? _codeFor(String classId) {
    for (final code in _codes) {
      if (code.classId == classId) return code;
    }
    return null;
  }

  void _selectClass(String? classId) {
    if (classId == null) return;
    final existing = _codeFor(classId);
    setState(() {
      _selectedClassId = classId;
      _codeController.text = existing?.displayCode ?? '';
    });
  }

  Future<void> _save() async {
    final classId = _selectedClassId;
    final code = _codeController.text.trim();
    if (classId == null) return;
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fr ? 'Entrez votre code.' : 'Enter your code.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await _service.createOrUpdateCustomCode(
        teacherId: widget.profile.id,
        classId: classId,
        code: code,
      );
      if (!mounted) return;
      setState(() {
        _codes = [
          ..._codes.where((item) => item.classId != classId),
          saved,
        ];
        _codeController.text = saved.displayCode;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _fr
                ? 'Code enregistré. Donnez-le aux élèves de cette salle.'
                : 'Code saved. Give it to students in this classroom.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_fr ? 'Code copié.' : 'Code copied.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fr ? 'Code forum et messagerie' : 'Forum and messaging code',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _classes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _fr
                              ? 'Aucune salle ne vous est attribuée.'
                              : 'No classroom is assigned to you.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _fr
                                      ? 'Votre espace enseignant'
                                      : 'Your teacher space',
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fr
                                      ? 'Créez librement un code unique pour chaque salle. Un élève qui saisit ce code obtient l’accès à votre forum et à votre messagerie privée avec vous.'
                                      : 'Create a unique code for each classroom. A student who enters the code gets access to your forum and private chat with you.',
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedClassId,
                                  decoration: InputDecoration(
                                    labelText: _fr ? 'Salle de classe' : 'Classroom',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: _classes
                                      .map(
                                        (room) => DropdownMenuItem<String>(
                                          value: room.id,
                                          child: Text(room.displayName),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _selectClass,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _codeController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    labelText: _fr
                                        ? 'Votre code unique'
                                        : 'Your unique code',
                                    hintText: 'Ex. CLASSE3A-2026',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.key_rounded),
                                  label: Text(
                                    _fr ? 'Enregistrer le code' : 'Save code',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _fr ? 'Codes de vos salles' : 'Codes for your classrooms',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._classes.map((room) {
                          final code = _codeFor(room.id);
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFDCFCE7),
                                child: Icon(
                                  Icons.vpn_key_rounded,
                                  color: Color(0xFF166534),
                                ),
                              ),
                              title: Text(
                                room.displayName,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              subtitle: Text(
                                code?.displayCode ??
                                    (_fr ? 'Aucun code créé' : 'No code created'),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              trailing: code == null
                                  ? null
                                  : IconButton(
                                      tooltip: _fr ? 'Copier' : 'Copy',
                                      onPressed: () => _copy(code.displayCode),
                                      icon: const Icon(Icons.copy_rounded),
                                    ),
                              onTap: () => _selectClass(room.id),
                            ),
                          );
                        }),
                      ],
                    ),
    );
  }
}
