import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/session_service.dart';
import '../../admin/pages/admin_dashboard_page.dart';
import '../../public/pages/public_home_page.dart';
import '../../student/pages/student_dashboard_page.dart';
import '../../teacher/pages/teacher_dashboard_page.dart';

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
  int _eventCount = 0;

  @override
  void initState() {
    super.initState();

    _subscription = widget.sessionService.changes.listen((state) {
      _eventCount++;
      _updateState(state);
    });
    _load();
  }

  Future<void> _load() async {
    final eventsBefore = _eventCount;
    final state = await widget.sessionService.load();
    // Un événement d'authentification plus récent a déjà mis l'état à jour :
    // on ignore ce résultat ancien pour ne pas revenir à l'accueil.
    if (_eventCount != eventsBefore) return;
    _updateState(state);
  }

  void _updateState(SessionState state) {
    if (!mounted) return;

    setState(() {
      _state = state;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
        return _messagePage(texts.profileUnavailable, texts);

      case SessionStatus.error:
        return _messagePage(texts.sessionError, texts, detail: _state.message);
    }
  }

  Widget _authenticatedPage(SessionState state, AppTexts texts) {
    final profile = state.profile!;

    switch (profile.role.toLowerCase()) {
      case 'student':
        return StudentDashboardPage(
          locale: widget.locale,
          profile: profile,
          onSignOut: () async {
            await widget.sessionService.signOut();
          },
        );

      case 'teacher':
        return TeacherDashboardPage(
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
