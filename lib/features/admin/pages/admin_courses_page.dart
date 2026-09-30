import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCoursesPage extends StatefulWidget {
  final Locale locale;

  const AdminCoursesPage({super.key, required this.locale});

  @override
  State<AdminCoursesPage> createState() => _AdminCoursesPageState();
}

class _AdminCoursesPageState extends State<AdminCoursesPage> {
  final SupabaseClient _client = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> _coursesFuture;

  bool get _isFrench => widget.locale.languageCode == 'fr';

  @override
  void initState() {
    super.initState();
    _coursesFuture = _fetchCourses();
  }

  Future<List<Map<String, dynamic>>> _fetchCourses() async {
    final response = await _client
        .from('courses')
        .select(
          'id,title_fr,title_en,description_fr,description_en,status,created_at',
        )
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _coursesFuture = _fetchCourses();
    });

    await _coursesFuture;
  }

  String _title(Map<String, dynamic> course) {
    final titleFr = course['title_fr']?.toString().trim() ?? '';
    final titleEn = course['title_en']?.toString().trim() ?? '';

    if (_isFrench) {
      return titleFr.isNotEmpty ? titleFr : titleEn;
    }

    return titleEn.isNotEmpty ? titleEn : titleFr;
  }

  String _description(Map<String, dynamic> course) {
    final descriptionFr = course['description_fr']?.toString().trim() ?? '';
    final descriptionEn = course['description_en']?.toString().trim() ?? '';

    if (_isFrench) {
      return descriptionFr.isNotEmpty ? descriptionFr : descriptionEn;
    }

    return descriptionEn.isNotEmpty ? descriptionEn : descriptionFr;
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'published':
        return _isFrench ? 'Publié' : 'Published';
      case 'draft':
        return _isFrench ? 'Brouillon' : 'Draft';
      case 'archived':
        return _isFrench ? 'Archivé' : 'Archived';
      case 'closed':
        return _isFrench ? 'Fermé' : 'Closed';
      default:
        return status?.isNotEmpty == true
            ? status!
            : (_isFrench ? 'Inconnu' : 'Unknown');
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'published':
        return Colors.green;
      case 'archived':
        return Colors.grey;
      case 'closed':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  void _showCourseDetails(Map<String, dynamic> course) {
    final title = _title(course);
    final description = _description(course);
    final status = course['status']?.toString();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty
                      ? title
                      : (_isFrench ? 'Cours sans titre' : 'Untitled course'),
                  style: Theme.of(sheetContext).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Chip(
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: _statusColor(status),
                      ),
                      label: Text(_statusLabel(status)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        course['id']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description.isNotEmpty
                      ? description
                      : (_isFrench ? 'Aucune description.' : 'No description.'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFrench
              ? 'La création et la modification des cours seront ajoutées à cette gestion.'
              : 'Course creation and editing will be added to this management.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFrench ? 'Gestion des cours' : 'Course management'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: _isFrench ? 'Actualiser' : 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showComingSoon,
        icon: const Icon(Icons.add),
        label: Text(_isFrench ? 'Nouveau cours' : 'New course'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _coursesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _isFrench
                      ? 'Impossible de charger les cours.'
                      : 'Unable to load courses.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final courses = snapshot.data ?? [];

          if (courses.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 220),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _isFrench
                            ? 'Aucun cours disponible.'
                            : 'No courses available.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: courses.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final course = courses[index];
                final courseTitle = _title(course);
                final description = _description(course);
                final status = course['status']?.toString();

                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF166534),
                      child: const Icon(
                        Icons.menu_book_outlined,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      courseTitle.isNotEmpty
                          ? courseTitle
                          : (_isFrench
                                ? 'Cours sans titre'
                                : 'Untitled course'),
                    ),
                    subtitle: Text(
                      description.isNotEmpty
                          ? description
                          : _statusLabel(status),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showCourseDetails(course),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
