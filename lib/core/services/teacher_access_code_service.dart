import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/teacher_access_code.dart';

class TeacherAccessCodeService {
  final SupabaseClient _client;

  TeacherAccessCodeService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Récupère le code d'accès de l'enseignant pour une classe
  Future<TeacherAccessCode?> getAccessCodeForClass(
    String teacherId,
    String classId,
  ) async {
    try {
      final response = await _client
          .from('teacher_access_codes')
          .select()
          .eq('teacher_id', teacherId)
          .eq('class_id', classId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return TeacherAccessCode.fromMap(response);
    } catch (_) {
      return null;
    }
  }

  /// Crée ou récupère le code d'accès pour une classe
  Future<TeacherAccessCode> getOrCreateAccessCode(
    String teacherId,
    String classId,
    String? suggestedCode,
  ) async {
    var existing = await getAccessCodeForClass(teacherId, classId);

    if (existing != null) {
      return existing;
    }

    // Générer un code si non fourni
    final code = (suggestedCode ?? _generateCode()).replaceAll('fise', '').trim();

    if (code.isEmpty) {
      throw ArgumentError('Code cannot be empty');
    }

    // Valider le format
    _validateCode(code);

    final now = DateTime.now();
    final newCode = TeacherAccessCode(
      id: '${teacherId}_${classId}_${now.millisecondsSinceEpoch}',
      teacherId: teacherId,
      code: code,
      classId: classId,
      createdAt: now,
      isActive: true,
    );

    await _client.from('teacher_access_codes').insert(newCode.toMap());

    return newCode;
  }

  /// Met à jour le code d'accès
  Future<TeacherAccessCode> updateAccessCode(
    String accessCodeId,
    String newCode,
  ) async {
    _validateCode(newCode);

    final cleanCode = newCode.replaceAll('fise', '').trim();

    final response = await _client
        .from('teacher_access_codes')
        .update({
          'code': cleanCode,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', accessCodeId)
        .select()
        .single();

    return TeacherAccessCode.fromMap(response);
  }

  /// Valide un code d'accès
  Future<bool> validateAccessCode(
    String code,
    String studentClassId,
  ) async {
    try {
      final cleanCode = code.replaceAll('fise', '').trim();

      final response = await _client
          .from('teacher_access_codes')
          .select()
          .eq('code', cleanCode)
          .eq('class_id', studentClassId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (_) {
      return false;
    }
  }

  /// Récupère tous les codes d'accès de l'enseignant
  Future<List<TeacherAccessCode>> getTeacherAccessCodes(String teacherId) async {
    try {
      final response = await _client
          .from('teacher_access_codes')
          .select()
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => TeacherAccessCode.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Désactive un code d'accès
  Future<void> deactivateAccessCode(String accessCodeId) async {
    await _client
        .from('teacher_access_codes')
        .update({'is_active': false})
        .eq('id', accessCodeId);
  }

  /// Génère un code aléatoire
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().microsecond;
    final part1 = random.toString().padLeft(6, '0').substring(0, 6);
    return 'fise$part1';
  }

  /// Valide le format du code
  void _validateCode(String code) {
    final cleanCode = code.replaceAll('fise', '').trim();
    if (cleanCode.isEmpty || cleanCode.length < 3) {
      throw ArgumentError('Code must be at least 3 characters long');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]*$').hasMatch(cleanCode)) {
      throw ArgumentError('Code can only contain letters, numbers, underscore and hyphen');
    }
  }
}
