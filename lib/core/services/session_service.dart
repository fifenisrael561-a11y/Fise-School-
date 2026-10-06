import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../offline/connectivity_service.dart';
import '../offline/course_offline_service.dart';
import '../offline/offline_repository.dart';
import 'profile_service.dart';
import 'push_service.dart';

enum SessionStatus {
  loading,
  signedOut,
  authenticated,
  profileMissing,
  error,
}

class SessionState {
  final SessionStatus status;
  final UserProfile? profile;
  final String? message;

  const SessionState._(
    this.status, {
    this.profile,
    this.message,
  });

  const SessionState.loading() : this._(SessionStatus.loading);

  const SessionState.signedOut() : this._(SessionStatus.signedOut);

  const SessionState.authenticated(UserProfile profile)
      : this._(
          SessionStatus.authenticated,
          profile: profile,
        );

  const SessionState.profileMissing() : this._(SessionStatus.profileMissing);

  const SessionState.error(String message)
      : this._(
          SessionStatus.error,
          message: message,
        );
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
  Future<SessionState>? _loadInFlight;

  SupabaseSessionService({
    ProfileService? profileService,
  }) : _profileService = profileService ?? ProfileService();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<SessionState> load() {
    final inFlight = _loadInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadInternal();
    _loadInFlight = future;
    future.whenComplete(() {
      if (identical(_loadInFlight, future)) {
        _loadInFlight = null;
      }
    });
    return future;
  }

  Future<SessionState> _loadInternal() async {
    try {
      final session = await _restoreSession();

      if (session == null) {
        final online = await ConnectivityService().isOnline();

        if (!online) {
          return const SessionState.error(
            'Pas de connexion internet. Aucune session locale active n’a pu être restaurée.',
          );
        }

        return const SessionState.signedOut();
      }

      // Supabase Flutter renouvelle automatiquement les sessions.
      // Il ne faut pas appeler refreshSession() à chaque chargement :
      // plusieurs refreshs concurrents peuvent faire tourner les refresh
      // tokens et provoquer des token_revoked juste après la connexion.
      if (session.isExpired) {
        return const SessionState.error(
          'La session est en cours de renouvellement. Veuillez patienter un instant.',
        );
      }

      final profile = await _fetchProfile();

      if (profile != null) {
        return SessionState.authenticated(profile);
      }

      final online = await ConnectivityService().isOnline();

      if (!online) {
        return const SessionState.error(
          'Pas de connexion internet et aucun profil local disponible.',
        );
      }

      return const SessionState.profileMissing();
    } on AuthException catch (error) {
      return SessionState.error(
        'Votre session a expiré. ${error.message}',
      );
    } catch (error) {
      return SessionState.error(
        'Erreur de démarrage : $error',
      );
    }
  }

  Future<Session?> _restoreSession() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      final session = _client.auth.currentSession;

      if (session != null) {
        return session;
      }

      if (attempt < 5) {
        await Future<void>.delayed(
          const Duration(milliseconds: 300),
        );
      }
    }

    return _client.auth.currentSession;
  }

  Future<UserProfile?> _fetchProfile() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final profile = await _profileService.getCurrentProfile();

      if (profile != null) {
        return profile;
      }

      if (attempt < 4) {
        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );
      }
    }

    return null;
  }

  @override
  Stream<SessionState> get changes {
    late final StreamController<SessionState> controller;
    StreamSubscription<AuthState>? subscription;
    var generation = 0;

    Future<void> refresh() async {
      final currentGeneration = ++generation;
      final state = await load();

      if (currentGeneration == generation && !controller.isClosed) {
        controller.add(state);
      }
    }

    controller = StreamController<SessionState>(
      onListen: () {
        subscription = _client.auth.onAuthStateChange.listen(
          (authState) {
            // Un TOKEN_REFRESHED ne change pas l'identité courante.
            // On évite donc un nouveau chargement du profil à chaque refresh.
            switch (authState.event) {
              case AuthChangeEvent.tokenRefreshed:
                return;
              case AuthChangeEvent.signedOut:
              case AuthChangeEvent.signedIn:
              case AuthChangeEvent.initialSession:
              case AuthChangeEvent.userUpdated:
              case AuthChangeEvent.userDeleted:
              case AuthChangeEvent.passwordRecovery:
              case AuthChangeEvent.mfaChallengeVerified:
                refresh();
            }
          },
          onError: (_) {
            refresh();
          },
        );

        // État initial immédiat. Si initialSession arrive aussi, le chargement
        // est dédoublonné par _loadInFlight.
        refresh();
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