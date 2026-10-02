import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/past_paper.dart';
import '../offline/json_cache.dart';

class PastPaperService {
  PastPaperService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const bucket = 'past-papers';

  Future<List<PastPaper>> list({bool includeUnpublished = false}) {
    return JsonCache.instance.cachedRead<List<PastPaper>>(
      key: 'past_papers_${includeUnpublished ? 'all' : 'published'}',
      fetch: () {
        var query = _client.from('past_papers').select();
        if (!includeUnpublished) {
          query = query.eq('is_published', true);
        }
        return query.order('exam_year', ascending: false).order('subject_fr');
      },
      decode: (raw) => (raw as List)
          .map((row) => PastPaper.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false),
    );
  }

  Future<String> signedUrl(String path) =>
      _client.storage.from(bucket).createSignedUrl(path, 3600);

  String _safeName(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  String _contentType(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> create({
    required PlatformFile file,
    required int year,
    required String subjectFr,
    required String subjectEn,
    required String kind,
    String? examId,
    String? subsystem,
    String? session,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Session utilisateur absente.');
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Fichier illisible ou vide.');
    }
    final path =
        '${DateTime.now().millisecondsSinceEpoch}/${_safeName(file.name)}';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(file.extension),
            upsert: false,
          ),
        );
    try {
      await _client.from('past_papers').insert({
        'exam_id': examId,
        'subsystem': subsystem,
        'exam_year': year,
        'session_label': (session == null || session.trim().isEmpty)
            ? null
            : session.trim(),
        'subject_fr': subjectFr.trim(),
        'subject_en': subjectEn.trim().isEmpty ? subjectFr.trim() : subjectEn.trim(),
        'kind': kind,
        'file_path': path,
        'file_name': file.name,
        'created_by': user.id,
      });
    } catch (_) {
      // Nettoyage : ne pas laisser un fichier orphelin si l'insertion échoue.
      try {
        await _client.storage.from(bucket).remove([path]);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> setPublished(String id, bool published) async {
    await _client
        .from('past_papers')
        .update({'is_published': published, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> delete(PastPaper paper) async {
    await _client.from('past_papers').delete().eq('id', paper.id);
    try {
      await _client.storage.from(bucket).remove([paper.filePath]);
    } catch (_) {}
  }
}
