import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../offline/course_offline_service.dart';
import '../offline/offline_repository.dart';
import 'profile_service.dart';
import 'push_service.dart';

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
      // Supabase may still be restoring the persisted Android session when
      // AuthGate performs its first load. Never interpret that short window
      // as a real sign-out, otherwise the app can jump back to the public home.
      var session = await _restoreSession();

      if (session == null) {
        return const SessionState.signedOut();
      }

      // Refresh the restored session when possible, but keep the valid session
      // if a refresh is temporarily unavailable.
      try {
        final refreshed = await _client.auth.refreshSession();
        session = refreshed.session ?? _client.auth.currentSession ?? session;
      } on AuthException {
        session = _client.auth.currentSession ?? session;
      }

      final profile = await _fetchProfile();
      if (profile == null) {
        return const SessionState.profileMissing();
      }
      return SessionState.authenticated(profile);
    } on AuthException catch (error) {
      return SessionState.error(error.message);
    } catch (error) {
      return SessionState.error(error.toString());
    }
  }

  /// Gives Supabase a short window to finish restoring the persisted session.
  /// This is especially important on Android, where currentSession can be null
  /// for a moment during application startup.
  Future<Session?> _restoreSession() async {
    for (var attempt = 0; attempt < 4; attempt++) {
      final session = _client.auth.currentSession;
      if (session != null) {
        return session;
      }

      if (_client.auth.currentUser != null) {
        final restored = _client.auth.currentSession;
        if (restored != null) {
          return restored;
        }
      }

      if (attempt < 3) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    return _client.auth.currentSession;
  }

  /// Le profil est créé par un trigger côté Supabase : juste après une
  /// connexion ou une inscription il peut apparaître avec un léger retard.
  /// On réessaie plusieurs fois avant de conclure qu'il est absent.
  Future<UserProfile?> _fetchProfile() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final profile = await _profileService.getCurrentProfile();
      if (profile != null) {
        return profile;
      }
      if (attempt < 2) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return null;
  }

  /// Chaque événement d'authentification (connexion, déconnexion, jeton
  /// rafraîchi...) recalcule l'état. Un résultat ancien ne doit jamais
  /// écraser un résultat plus récent.
  @override
  Stream<SessionState> get changes {
    late final StreamController<SessionState> controller;
    StreamSubscription<AuthState>? subscription;
    var generation = 0;

    Future<void> refresh() async {
      final current = ++generation;
      final state = await load();
      if (current == generation && !controller.isClosed) {
        controller.add(state);
      }
    }

    controller = StreamController<SessionState>(
      onListen: () {
        subscription = _client.auth.onAuthStateChange.listen(
          (_) => refresh(),
          onError: (Object _) => refresh(),
        );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> signOut() async {
    await PushService.unregister();
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await CourseOfflineService().deleteUserFiles(userId);
        await OfflineRepository().clearIdentity(userId);
      }
      await OfflineRepository().clearCourses();
      await OfflineRepository().clearLessons();
      await OfflineRepository().clearProgress();
    } catch (_) {}
    await _client.auth.signOut();
  }
}
