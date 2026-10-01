import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/notification_service.dart';
import '../../../models/notification.dart';

class NotificationsPage extends StatefulWidget {
  final Locale locale;
  final String userId;
  final NotificationService? notificationService;

  const NotificationsPage({
    super.key,
    required this.locale,
    required this.userId,
    this.notificationService,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final NotificationService _service =
      widget.notificationService ?? NotificationService();

  late Future<List<AppNotification>> _future = _service.listForUser(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(widget.locale);

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(onPressed: _markAll, child: Text(texts.markAllRead)),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(texts.notificationsError));
          }

          final items = snapshot.data ?? const <AppNotification>[];

          if (items.isEmpty) {
            return Center(child: Text(texts.noNotifications));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) => ListTile(
              tileColor: items[index].isRead ? null : const Color(0xFFEAF5ED),
              title: Text(items[index].title),
              subtitle: Text(items[index].body),
              onTap: () async {
                await _service.markRead(items[index].id);

                setState(() => _future = _service.listForUser(widget.userId));
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAll() async {
    await _service.markAllRead(widget.userId);

    if (mounted) {
      setState(() => _future = _service.listForUser(widget.userId));
    }
  }
}
