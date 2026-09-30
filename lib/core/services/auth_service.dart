import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;
  final ProfileService _profileService = ProfileService();

  /// Met le numéro au format international attendu par Supabase (E.164).
  /// Un numéro camerounais saisi sans indicatif (ex. 6XXXXXXXX) devient +237...
  static String normalizePhone(String raw) {
    var value = raw.replaceAll(RegExp(r'[\s().-]'), '');
    if (value.startsWith('00')) value = '+${value.substring(2)}';
    if (!value.startsWith('+')) value = '+237$value';
    return value;
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    final isEmail = identifier.contains('@');

    final response = isEmail
        ? await _client.auth.signInWithPassword(
            email: identifier.trim(),
            password: password,
          )
        : await _client.auth.signInWithPassword(
            phone: normalizePhone(identifier),
            password: password,
          );

    await _ensureProfile(response.user);
  }

  /// Retourne true si l'utilisateur est connecté immédiatement après l'inscription
  /// (false si une vérification du téléphone est requise).
  Future<bool> signUp({
    required String phone,
    String? email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? subsystem,
    String? sector,
    String? examLevelId,
    String? examId,
    String? seriesId,
    String? specialtyId,
    String? examLevel,
    String? exam,
    String? track,
    String? className,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    final cleanEmail = email?.trim().isEmpty == true ? null : email?.trim();

    // Le compte est créé avec le téléphone (identifiant principal). Fournir aussi
    // « email » à signUp() ferait ignorer le téléphone : l'e-mail est donc transmis
    // dans les métadonnées et repris dans le profil.
    final response = await _client.auth.signUp(
      phone: normalizedPhone,
      password: password,
      data: {
        'email': cleanEmail,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': role,
        'subsystem': subsystem,
        'sector': sector,
        'exam_level_id': examLevelId,
        'exam_id': examId,
        'series_id': seriesId,
        'specialty_id': specialtyId,
        'exam_level': examLevel,
        'exam': exam,
        'track': track,
        'class_name': className,
      },
    );

    final user = response.user;
    if (user != null && response.session != null) {
      await _profileService.saveCurrentProfile(
        firstName: firstName,
        lastName: lastName,
        phone: normalizedPhone,
        email: cleanEmail,
        role: role,
        subsystem: subsystem,
        sector: sector,
        examLevelId: examLevelId,
        examId: examId,
        seriesId: seriesId,
        specialtyId: specialtyId,
        examLevel: examLevel,
        exam: exam,
        track: track,
        className: className,
      );
    }
    return response.session != null;
  }

  Future<void> _ensureProfile(User? user) async {
    if (user == null) return;

    final existing = await _profileService.getCurrentProfile();
    if (existing != null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    await _profileService.saveCurrentProfile(
      firstName: metadata['first_name'] as String? ?? '',
      lastName: metadata['last_name'] as String? ?? '',
      phone: user.phone,
      email: user.email ?? metadata['email'] as String?,
      role: metadata['role'] as String? ?? 'student',
      subsystem: metadata['subsystem'] as String?,
      sector: metadata['sector'] as String?,
      examLevelId: metadata['exam_level_id'] as String?,
      examId: metadata['exam_id'] as String?,
      seriesId: metadata['series_id'] as String?,
      specialtyId: metadata['specialty_id'] as String?,
      examLevel: metadata['exam_level'] as String?,
      exam: metadata['exam'] as String?,
      track: metadata['track'] as String?,
      className: metadata['class_name'] as String?,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
