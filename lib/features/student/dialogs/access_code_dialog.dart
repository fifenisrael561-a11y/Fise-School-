import 'package:flutter/material.dart';

import '../../../core/services/teacher_access_code_service.dart';
import '../../../models/user_profile.dart';

class AccessCodeDialog extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;
  final VoidCallback onSuccess;

  const AccessCodeDialog({
    super.key,
    required this.locale,
    required this.profile,
    required this.onSuccess,
  });

  @override
  State<AccessCodeDialog> createState() => _AccessCodeDialogState();
}

class _AccessCodeDialogState extends State<AccessCodeDialog> {
  final TeacherAccessCodeService _service = TeacherAccessCodeService();
  final TextEditingController _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get _isFrench => widget.locale.languageCode == 'fr';

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = _isFrench ? 'Veuillez entrer le code.' : 'Please enter the code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _service.joinTeacherSpace(code);
      if (!mounted) return;
      widget.onSuccess();
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFrench
                ? 'Espace de l’enseignant rejoint : forum et messagerie privée activés.'
                : 'Teacher space joined: forum and private messaging enabled.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = _isFrench
              ? 'Code invalide ou vous n’êtes pas inscrit dans cette salle.'
              : 'Invalid code or you are not enrolled in this classroom.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isFrench ? 'Rejoindre un enseignant' : 'Join a teacher'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isFrench
                ? 'Entrez le code unique donné par l’enseignant. Il active son forum et votre messagerie privée avec lui.'
                : 'Enter the unique code given by the teacher. It enables the teacher’s forum and your private chat with them.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            enabled: !_loading,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: _isFrench ? 'Code unique' : 'Unique code',
              hintText: 'fise...',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: Text(_isFrench ? 'Annuler' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _join,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isFrench ? 'Rejoindre' : 'Join'),
        ),
      ],
    );
  }
}
