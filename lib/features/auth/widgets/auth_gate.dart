import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/session_service.dart';
import '../../../core/offline/connectivity_service.dart';
import '../../../core/offline/sync_service.dart';
import '../../admin/pages/admin_dashboard_page.dart';
import '../../public/pages/public_home_page.dart';
import '../../student/pages/student_main_page.dart';
import '../../../core/services/push_service.dart';
import '../../../core/services/pedagogy_service.dart';
import '../../../models/user_profile.dart';
import '../../teacher/pages/teacher_main_page.dart';

class AuthGate extends StatefulWidget {
  final Locale locale;
  final ValueChanged<Locale> onLanguageChanged;
  final SessionService sessionService;

  const AuthGate({
    super.key,
    required this.locale,
    required this.onLanguageChanged,
    required this.sessionService,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SessionState _state = const SessionState.loading();
  StreamSubscription<SessionState>? _subscription;
  StreamSubscription<bool>? _connectivitySubscription;
  String? _syncedStudentId;

  @override
  void initState() {
    super.initState();

    // SessionService émet immédiatement l'état courant.
    // Un second load() ici créerait une course inutile.
    _subscription = widget.sessionService.changes.listen(_updateState);
    _connectivitySubscription = ConnectivityService().connectionStream.listen((online) {
      if (online && _state.status == SessionStatus.authenticated) {
        _syncStudentOfflineCache(_state.profile!);
      }
    });
  }

  void _updateState(SessionState state) {
    if (!mounted) {
      return;
    }

    setState(() {
      _state = state;
    });

    if (state.status == SessionStatus.authenticated && state.profile != null) {
      PushService.registerForUser(state.profile!.id);
    }

    if (state.status == SessionStatus.authenticated &&
        state.profile?.role.toLowerCase() == 'student') {
      _syncStudentOfflineCache(state.profile!);
    } else if (state.status == SessionStatus.signedOut) {
      _syncedStudentId = null;
    }
  }

  Future<void> _syncStudentOfflineCache(UserProfile profile) async {
    try {
      if (!await ConnectivityService().isOnline()) {
        return;
      }
      final sync = SyncService();
      await sync.syncPendingAssignments(profile.id);
      await sync.syncPendingSmartExercises(profile.id);
      if (_syncedStudentId == profile.id) {
        return;
      }
      _syncedStudentId = profile.id;
      await CourseService().listClassSubjects(profile);
      await sync.syncStudentCourses(profile.id);
    } catch (_) {
      // The app remains usable with whatever cache is already available.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(widget.locale);

    switch (_state.status) {
      case SessionStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));

      case SessionStatus.signedOut:
        return PublicHomePage(
          locale: widget.locale,
          onLanguageChanged: widget.onLanguageChanged,
        );

      case SessionStatus.authenticated:
        return _authenticatedPage(_state, texts);

      case SessionStatus.profileMissing:
        return _messagePage(texts.profileNotFound, texts);

      case SessionStatus.error:
        return _messagePage(texts.sessionError, texts, detail: _state.message);
    }
  }

  Widget _authenticatedPage(SessionState state, AppTexts texts) {
    final profile = state.profile!;

    switch (profile.role.toLowerCase()) {
      case 'student':
        return StudentMainPage(
          locale: widget.locale,
          profile: profile,
          onSignOut: () async {
            await widget.sessionService.signOut();
          },
        );

      case 'teacher':
        return TeacherMainPage(
          locale: widget.locale,
          profile: profile,
          onSignOut: () async {
            await widget.sessionService.signOut();
          },
        );

      case 'admin':
        return AdminDashboardPage(
          locale: widget.locale,
          onSignOut: () async {
            await widget.sessionService.signOut();
          },
        );

      default:
        return _messagePage(texts.accessDenied, texts);
    }
  }

  Widget _messagePage(String message, AppTexts texts, {String? detail}) {
    return Scaffold(
      appBar: AppBar(title: Text(texts.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline_rounded, size: 54),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(detail, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await widget.sessionService.signOut();
                },
                child: Text(texts.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
