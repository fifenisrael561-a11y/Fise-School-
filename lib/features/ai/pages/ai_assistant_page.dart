import 'package:flutter/material.dart';

import '../../../core/localization/app_texts.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../models/user_profile.dart';

class AIAssistantPage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const AIAssistantPage({
    super.key,
    required this.locale,
    required this.profile,
  });

  @override
  State<AIAssistantPage> createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final GeminiService _geminiService = GeminiService();
  final PhotoService _photoService = PhotoService();
  PickedAttachment? _imageAttachment;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];

  bool _loading = false;

  bool get _isEnglish => widget.locale.languageCode == 'en';

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();

    if (message.isEmpty && _imageAttachment == null || _loading) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add(
        _ChatMessage(
          text: message,
          isUser: true,
        ),
      );
      _loading = true;
    });

    _scrollToBottom();

    try {
      final answer = await _geminiService.ask(
        message: message,
        profile: widget.profile,
        imageBytes: _imageAttachment?.bytes,
        imageMimeType: _imageAttachment?.mimeType,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: answer,
            isUser: false,
          ),
        );
        _imageAttachment = null;
        _loading = false;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: _isEnglish
                ? 'Unable to contact the AI assistant.'
                : 'Impossible de contacter l’assistant IA.',
            isUser: false,
          ),
        );
        _imageAttachment = null;
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _takeAiPhoto() async {
    final file = await _photoService.takePhoto();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageAttachment = PickedAttachment(
        bytes: bytes,
        name: 'question.jpg',
        mimeType: file.mimeType ?? 'image/jpeg',
      );
    });
  }

  Future<void> _pickAiImage() async {
    final file = await _photoService.pickFromGallery();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageAttachment = PickedAttachment(
        bytes: bytes,
        name: file.name,
        mimeType: file.mimeType ?? 'image/jpeg',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppTexts(widget.locale);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF166534),
        foregroundColor: Colors.white,
        title: Text(
          _isEnglish ? 'Fise School AI' : 'IA Fise School',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState(texts)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessage(_messages[index]);
                      },
                    ),
            ),
            if (_loading) _buildLoading(),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF166534),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isEnglish
                  ? 'Assistant restricted to your school profile and program.'
                  : 'Assistant limité à votre profil scolaire et à votre programme.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppTexts texts) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.school_rounded,
              size: 64,
              color: Color(0xFF166534),
            ),
            const SizedBox(height: 16),
            Text(
              _isEnglish
                  ? 'Ask a question about your lessons.'
                  : 'Pose une question sur tes cours.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isEnglish
                  ? 'The assistant will use your registered school profile.'
                  : 'L’assistant utilisera le profil scolaire enregistré pour ce compte.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatMessage message) {
    final alignment =
        message.isUser ? Alignment.centerRight : Alignment.centerLeft;

    final backgroundColor =
        message.isUser ? const Color(0xFF166534) : Colors.white;

    final textColor =
        message.isUser ? Colors.white : Colors.black87;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(17),
          boxShadow: message.isUser
              ? null
              : const [
                  BoxShadow(
                    blurRadius: 4,
                    offset: Offset(0, 1),
                    color: Colors.black12,
                  ),
                ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: textColor,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _isEnglish ? 'AI is thinking...' : 'L’IA réfléchit...',
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _isEnglish
                    ? 'Ask your question...'
                    : 'Pose ta question...',
                filled: true,
                fillColor: const Color(0xFFF5F8F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: _isEnglish ? 'Take a photo' : 'Prendre une photo',
            onPressed: _loading ? null : _takeAiPhoto,
            icon: const Icon(Icons.camera_alt_rounded),
          ),
          IconButton(
            tooltip: _isEnglish ? 'Choose an image' : 'Choisir une image',
            onPressed: _loading ? null : _pickAiImage,
            icon: const Icon(Icons.photo_library_rounded),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _loading ? null : _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black12,
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({
    required this.text,
    required this.isUser,
  });
}