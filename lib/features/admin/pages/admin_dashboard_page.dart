import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  final Locale locale;
  final Future<void> Function() onSignOut;

  const AdminDashboardPage({
    super.key,
    required this.locale,
    required this.onSignOut,
  });

  bool get _isFrench => locale.languageCode == 'fr';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isFrench
              ? 'Espace administrateur'
              : 'Administrator space',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isFrench
                ? 'Déconnexion'
                : 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Fise School'),
            ],
          ),
        ),
      ),
    );
  }
}