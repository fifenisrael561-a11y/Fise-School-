import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';

class GeminiService {
  GeminiService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<String> ask({
    required String message,
    required UserProfile profile,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final response = await _client.functions.invoke(
      'gemini-chat',
      body: {
        'message': message.trim(),
        'language': profile.preferredLanguage,
        'profile': {
          'subsystem': profile.subsystem,
          'sector': profile.sector,
          'className': profile.className,
          'examLevel': profile.examLevel,
          'exam': profile.exam,
        },
        if (imageBytes != null)
          'image': {
            'mimeType': imageMimeType ?? 'image/jpeg',
            'base64': base64Encode(imageBytes),
          },
      },
    );
    if (response.data is! Map) {
      throw Exception('Réponse IA invalide.');
    }
    final text = (response.data as Map)['text'];
    if (text is! String || text.trim().isEmpty) {
      throw Exception('L’assistant IA n’a retourné aucune réponse.');
    }
    return text.trim();
  }
}
