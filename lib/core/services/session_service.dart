import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import 'profile_service.dart';

enum SessionStatus { loading, signedOut, authenticated, profileMissing, error }

class SessionState {
  final SessionStatus status;
  final UserProfile? profile;
  final String? message;

  const SessionState._(this.status, {this.profile, this.message});

  const SessionState.loading() : this._(SessionStatus.loading);

  const SessionState.signedOut() : this._(SessionStatus.signedOut);

  const SessionState.authenticated(UserProfile profile)
    : this._(SessionStatus.authenticated, profile: profile);

  const SessionState.profileMissing() : this._(SessionStatus.profileMissing);

  const SessionState.error(String message)
    : this._(SessionStatus.error, message: message);
}

abstract interface class SessionService {
  Future<SessionState> load();

  Stream<SessionState> get changes;

  Future<void> signOut();
}

class UnavailableSessionService implements SessionService {
  const UnavailableSessionService();

  @override
  Future<SessionState> load() async => const SessionState.signedOut();

  @override
  Stream<SessionState> get changes => const Stream<SessionState>.empty();

  @override
  Future<void> signOut() async {}
}

class SupabaseSessionService implements SessionService {
  final ProfileService _profileService;

  SupabaseSessionService({ProfileService? profileService})
    : _profileService = profileService ?? ProfileService();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<SessionState> load() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return const SessionState.signedOut();

      final profile = await _profileService.getCurrentProfile();
      if (profile == null) return const SessionState.profileMissing();
      return SessionState.authenticated(profile);
    } on AuthException catch (error) {
      return SessionState.error(error.message);
    } catch (error) {
      return SessionState.error(error.toString());
    }
  }

  @override
  Stream<SessionState> get changes async* {
    await for (final _ in _client.auth.onAuthStateChange) {
      yield await load();
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
