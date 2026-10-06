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

  const SessionState.loading()
      : this._(SessionStatus.loading);

  const SessionState.signedOut()
      : this._(SessionStatus.signedOut);

  const SessionState.authenticated(UserProfile profile)
      : this._(
          SessionStatus.authenticated,
          profile: profile,
        );

  const SessionState.profileMissing()
      : this._(SessionStatus.profileMissing);

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
  Future<SessionState> load() async {
    return const SessionState.signedOut();
  }

  @override
  Stream<SessionState> get changes {
    return const Stream<SessionState>.empty();
  }

  @override
  Future<void> signOut() async {}
}

class SupabaseSessionService implements SessionService {
  final ProfileService _profileService;

  SupabaseSessionService({
    ProfileService? profileService,
  }) : _profileService =
            profileService ?? ProfileService();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<SessionState> load() async {
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

      try {
        final refreshed = await _client.auth.refreshSession();

        if (refreshed.session == null &&
            _client.auth.currentSession == null) {
          return const SessionState.error(
            'Votre session a expiré. Veuillez vous reconnecter.',
          );
        }
      } on AuthException catch (error) {
        final currentSession = _client.auth.currentSession;

        if (currentSession == null) {
          return SessionState.error(
            'Votre session a expiré. $error.message',
          );
        }
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
          const Duration(milliseconds: 500),
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

      if (currentGeneration == generation &&
          !controller.isClosed) {
        controller.add(state);
      }
    }

    controller = StreamController<SessionState>(
      onListen: () {
        subscription =
            _client.auth.onAuthStateChange.listen(
          (_) {
            refresh();
          },
          onError: (_) {
            refresh();
          },
        );

        // Émet immédiatement l'état courant. Cela évite qu'un retour depuis
        // l'écran de connexion reste temporairement sur l'accueil public
        // lorsque l'événement AuthStateChange a déjà été émis.
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
        await CourseOfflineService()
            .deleteUserFiles(userId);
        await OfflineRepository().clearIdentity(userId);
      }

      await OfflineRepository().clearCourses();
      await OfflineRepository().clearLessons();
      await OfflineRepository().clearProgress();
    } catch (_) {}

    await _client.auth.signOut();
  }
}
