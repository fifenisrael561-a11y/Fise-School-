import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';

class ProfileService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<UserProfile?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data == null ? null : UserProfile.fromMap(data);
  }

  Future<UserProfile> updateEditableProfile({
    required String firstName,
    required String lastName,
    required String preferredLanguage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('No active user session.');
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
    return UserProfile.fromMap(data);
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

    return UserProfile.fromMap(data);
  }
}
