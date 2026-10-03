import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../models/user_profile.dart';
import '../../ai/pages/ai_page.dart';
import '../../forum/pages/forum_page.dart';
import '../../messages/pages/private_messages_page.dart';
import '../../notifications/pages/notifications_page.dart';
import '../../search/pages/search_page.dart';
import '../../settings/pages/profile_page.dart';
import '../../settings/pages/settings_page.dart';
import 'assignments_page.dart';
import 'courses_page.dart';
import 'daily_lesson_page.dart';
import 'pages/payment_page.dart';
import 'pages/premium_page.dart';
import 'progress_page.dart';
import 'timetable_page.dart';

class StudentDashboardPage extends StatelessWidget {
  final Locale locale;
  final UserProfile profile;
  final Future<void> Function() onSignOut;

  const StudentDashboardPage({
    super.key,
    required this.locale,
    required this.profile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(locale);
    final isFrench = locale.languageCode == 'fr';

    return _DashboardScaffold(
      title: texts.studentSpace,
      locale: locale,
      profile: profile,
      texts: texts,
      onSignOut: onSignOut,
      children: [
        _Welcome(profile: profile, texts: texts),

        Card(
          margin: const EdgeInsets.only(bottom: 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyLessonPage(locale: locale, profile: profile),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF166534), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isFrench ? 'Leçon du jour' : 'Lesson of the day', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(isFrench ? 'Ta prochaine leçon et son exercice selon ton planning.' : 'Your next lesson and exercise based on your timetable.'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),

        // ============================================================
        // PREMIUM
        // ============================================================
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PremiumPage(locale: locale, profile: profile),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF166534), Color(0xFF15803D)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fise School Premium',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isFrench
                              ? 'Débloque les fonctionnalités et contenus Premium.'
                              : 'Unlock Premium features and content.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          isFrench
                              ? '1000 FCFA / 30 jours'
                              : '1000 XAF / 30 days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ============================================================
        // ASSISTANT IA
        // ============================================================
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiPage(locale: locale, profile: profile),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF166534),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFrench
                              ? 'Assistant IA Fise School'
                              : 'Fise School AI Assistant',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFrench
                              ? 'Pose une question sur tes cours et tes révisions.'
                              : 'Ask a question about your courses and revision.',
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),

        // ============================================================
        // PAIEMENT
        // ============================================================
        Card(
          margin: const EdgeInsets.only(bottom: 18),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentPage(locale: locale, profile: profile),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.payment_rounded,
                      color: Color(0xFF166534),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isFrench
                              ? 'Paiements Fise School'
                              : 'Fise School payments',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFrench
                              ? 'Gérer tes paiements et ton abonnement.'
                              : 'Manage your payments and subscription.',
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),

        // ============================================================
        // MENU PRINCIPAL
        // ============================================================
        _DashboardGrid(
          items: [
            _DashboardItem(
              Icons.menu_book_rounded,
              texts.courses,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CoursesPage(locale: locale, profile: profile),
                ),
              ),
            ),
            _DashboardItem(
              Icons.assignment_rounded,
              texts.assignments,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AssignmentsPage(locale: locale, profile: profile),
                ),
              ),
            ),
            _DashboardItem(
              Icons.forum_rounded,
              texts.forum,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ForumPage(locale: locale, profile: profile),
                ),
              ),
            ),
            _DashboardItem(
              Icons.mail_outline_rounded,
              texts.messages,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PrivateMessagesPage(locale: locale, profile: profile),
                ),
              ),
            ),
            _DashboardItem(
              Icons.notifications_rounded,
              texts.notifications,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      NotificationsPage(locale: locale, userId: profile.id),
                ),
              ),
            ),
            _DashboardItem(
              Icons.insights_rounded,
              texts.progress,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProgressPage(locale: locale, profile: profile),
                ),
              ),
            ),
            _DashboardItem(
              Icons.calendar_month_rounded,
              texts.timetable,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TimetablePage(locale: locale, profile: profile),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

      ],
    );
  }
}

// ============================================================================
// SCAFFOLD DU DASHBOARD
// ============================================================================

class _DashboardScaffold extends StatelessWidget {
  final String title;
  final Locale locale;
  final UserProfile profile;
  final AppTexts texts;
  final Future<void> Function() onSignOut;
  final List<Widget> children;

  const _DashboardScaffold({
    required this.title,
    required this.locale,
    required this.profile,
    required this.texts,
    required this.onSignOut,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: texts.notifications,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsPage(locale: locale, userId: profile.id),
              ),
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          IconButton(
            tooltip: texts.search,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SearchPage(locale: locale)),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: texts.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(locale: locale, profile: profile),
              ),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: texts.profile,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(locale: locale, profile: profile),
              ),
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1000,
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// MESSAGE DE BIENVENUE
// ============================================================================

class _Welcome extends StatelessWidget {
  final UserProfile profile;
  final AppTexts texts;

  const _Welcome({required this.profile, required this.texts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${texts.hello}, ${profile.firstName}',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(texts.welcomeBack),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// GRILLE DU DASHBOARD
// ============================================================================

class _DashboardGrid extends StatelessWidget {
  final List<_DashboardItem> items;

  const _DashboardGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 130,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: item.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: const Color(0xFF166534), size: 30),
                const SizedBox(height: 10),
                Text(item.title, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// ÉLÉMENT DU DASHBOARD
// ============================================================================

class _DashboardItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _DashboardItem(this.icon, this.title, [this.onTap]);
}
