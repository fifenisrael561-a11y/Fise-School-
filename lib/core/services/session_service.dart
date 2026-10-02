import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../offline/json_cache.dart';
import '../offline/local_cleanup.dart';
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

  static const String _profileCacheKey = 'session_profile';

  @override
  Future<SessionState> load() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return const SessionState.signedOut();

      try {
        final profile = await _fetchProfile().timeout(
          JsonCache.networkTimeout * 2,
        );
        if (profile == null) return const SessionState.profileMissing();
        await _cacheProfile(profile);
        return SessionState.authenticated(profile);
      } catch (_) {
        // Hors ligne (ou serveur injoignable) : la session locale reste
        // valable, on reprend le dernier profil connu pour ouvrir l'app.
        final cached = await _cachedProfile(session.user.id);
        if (cached != null) return SessionState.authenticated(cached);
        rethrow;
      }
    } on AuthException catch (error) {
      return SessionState.error(error.message);
    } catch (error) {
      return SessionState.error(error.toString());
    }
  }

  Future<void> _cacheProfile(UserProfile profile) async {
    try {
      await JsonCache.instance.write(_profileCacheKey, profile.toMap());
    } catch (_) {}
  }

  Future<UserProfile?> _cachedProfile(String userId) async {
    final raw = await JsonCache.instance.read(_profileCacheKey);
    if (raw is! Map) return null;
    try {
      final profile = UserProfile.fromMap(Map<String, dynamic>.from(raw));
      // Ne jamais reprendre le profil d'un autre compte.
      return profile.id == userId ? profile : null;
    } catch (_) {
      return null;
    }
  }

  /// Le profil est créé par un trigger côté Supabase : juste après une
  /// connexion ou une inscription il peut apparaître avec un léger retard.
  /// On réessaie donc une fois avant de conclure qu'il est absent.
  Future<UserProfile?> _fetchProfile() async {
    var profile = await _profileService.getCurrentProfile();
    if (profile == null) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      profile = await _profileService.getCurrentProfile();
    }
    return profile;
  }

  /// Chaque événement d'authentification (connexion, déconnexion, jeton
  /// rafraîchi...) recalcule l'état. Une erreur du flux ne doit jamais le
  /// couper (sinon l'écran reste figé sur l'accueil après la connexion), et un
  /// résultat ancien ne doit jamais écraser un résultat plus récent.
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
    // Envoie d'abord la progression faite hors ligne (si possible), puis
    // efface toutes les données locales du compte.
    await clearLocalUserData();
    await _client.auth.signOut();
  }
}
