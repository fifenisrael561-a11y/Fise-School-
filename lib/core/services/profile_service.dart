import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../offline/offline_repository.dart';

class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        final profile = UserProfile.fromMap(data);
        await OfflineRepository().saveProfileCache(profile);
        return profile;
      }

      return OfflineRepository().getProfileCache(user.id);
    } catch (_) {
      return OfflineRepository().getProfileCache(user.id);
    }
  }

  Future<UserProfile?> _createMissingProfile(User user) async {
    try {
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final appMetadata = user.appMetadata;

      final requestedRole = appMetadata['role'] == 'admin'
          ? 'admin'
          : metadata['role'] == 'teacher'
              ? 'teacher'
              : 'student';

      final profile = UserProfile(
        id: user.id,
        firstName: (metadata['first_name'] as String?)?.trim().isNotEmpty == true
            ? (metadata['first_name'] as String).trim()
            : ((user.email ?? '').split('@').first.isNotEmpty
                ? (user.email ?? '').split('@').first
                : 'Utilisateur'),
        lastName: (metadata['last_name'] as String?)?.trim().isNotEmpty == true
            ? (metadata['last_name'] as String).trim()
            : 'Fise',
        email: user.email,
        role: requestedRole,
        preferredLanguage:
            metadata['preferred_language'] == 'en' ? 'en' : 'fr',
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

      final data = await _client
          .from('profiles')
          .upsert(profile.toMap())
          .select()
          .single();

      return UserProfile.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile> updateEditableProfile({
    required String firstName,
    required String lastName,
    required String preferredLanguage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Aucune session utilisateur active.');
    }

    final data = await _client
        .from('profiles')
        .update({
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'preferred_language': preferredLanguage,
        })
        .eq('id', user.id)
        .select()
        .single();

    final profile = UserProfile.fromMap(data);
    await OfflineRepository().saveProfileCache(profile);
    return profile;
  }

  Future<UserProfile> saveCurrentProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    String preferredLanguage = 'fr',
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
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Aucune session utilisateur active.');
    }

    final profile = UserProfile(
      id: user.id,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      email: email.trim(),
      role: role,
      preferredLanguage: preferredLanguage,
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

    final data = await _client
        .from('profiles')
        .upsert(profile.toMap())
        .select()
        .single();

    final savedProfile = UserProfile.fromMap(data);
    await OfflineRepository().saveProfileCache(savedProfile);
    return savedProfile;
  }
}
