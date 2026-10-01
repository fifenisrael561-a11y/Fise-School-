import 'package:flutter/material.dart';

import '../../../core/services/gemini_service.dart';
import '../../../core/services/photo_service.dart';
import '../../../models/user_profile.dart';

class AiPage extends StatefulWidget {
  final Locale locale;
  final UserProfile profile;

  const AiPage({super.key, required this.locale, required this.profile});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GeminiService _geminiService = GeminiService();
  final PhotoService _photoService = PhotoService();
  PickedAttachment? _imageAttachment;

  final List<_AiMessage> _messages = [];

  bool _sending = false;

  bool get _isFrench => widget.locale.languageCode == 'fr';

  @override
  void initState() {
    super.initState();

    _messages.add(
      _AiMessage(
        text: _isFrench
            ? 'Bonjour ${widget.profile.firstName} 👋\n\n'
                  'Je suis l’assistant IA de Fise School. '
                  'Je réponds uniquement selon ton parcours scolaire, '
                  'ta classe et ton programme. '
                  'Tu peux me poser une question sur tes cours, '
                  'tes exercices ou tes révisions.'
            : 'Hello ${widget.profile.firstName} 👋\n\n'
                  'I am the Fise School AI assistant. '
                  'I answer only according to your school path, '
                  'class and program. '
                  'You can ask me about your courses, '
                  'exercises or revision.',
        fromUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? predefinedMessage]) async {
    final message = (predefinedMessage ?? _messageController.text).trim();

    if ((message.isEmpty && _imageAttachment == null) || _sending) {
      return;
    }

    _messageController.clear();

    setState(() {
      _messages.add(_AiMessage(text: message, fromUser: true));

      _sending = true;
    });

    _scrollToBottom();

    try {
      final response = await _geminiService.ask(
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
          _AiMessage(
            text: response.trim().isEmpty
                ? (_isFrench
                      ? 'Aucune réponse n’a été reçue.'
                      : 'No response was received.')
                : response.trim(),
            fromUser: false,
          ),
        );

        _imageAttachment = null;
        _sending = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _AiMessage(
            text: _isFrench
                ? 'Une erreur est survenue pendant la communication '
                      'avec Gemini.\n\n${_friendlyError(error)}'
                : 'An error occurred while communicating '
                      'with Gemini.\n\n${_friendlyError(error)}',
            fromUser: false,
          ),
        );

        _imageAttachment = null;
        _sending = false;
      });
    }

    _scrollToBottom();
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.length > 250) {
      return _isFrench
          ? 'Vérifie la configuration de la clé Gemini.'
          : 'Check the Gemini API key configuration.';
    }

    return message;
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

  void _clearConversation() {
    setState(() {
      _messages.clear();

      _messages.add(
        _AiMessage(
          text: _isFrench
              ? 'Conversation effacée.\n\n'
                    'Comment puis-je t’aider ?'
              : 'Conversation cleared.\n\n'
                    'How can I help you?',
          fromUser: false,
        ),
      );
    });

    _scrollToBottom();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isFrench ? 'Assistant IA Fise School' : 'Fise School AI Assistant',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: _isFrench ? 'Effacer' : 'Clear',
            onPressed: _sending ? null : _clearConversation,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildWelcomeCard(),
            _buildQuickQuestions(),
            Expanded(child: _buildConversation()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF166534),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isFrench
                      ? 'Pose-moi une question sur tes cours, '
                            'tes exercices ou tes révisions.'
                      : 'Ask me a question about your courses, '
                            'exercises or revision.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final questions = _isFrench
        ? <String>[
            'Explique-moi cette leçon',
            'Aide-moi à réviser',
            'Donne-moi une méthode',
          ]
        : <String>[
            'Explain this lesson',
            'Help me revise',
            'Give me a study method',
          ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: questions.length,
        separatorBuilder: (context, index) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(questions[index]),
            onPressed: _sending ? null : () => _sendMessage(questions[index]),
          );
        },
      ),
    );
  }

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        return Align(
          alignment: message.fromUser
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: message.fromUser
                  ? const Color(0xFF166534)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: message.fromUser
                    ? Colors.white
                    : const Color(0xFF0F172A),
                height: 1.4,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _isFrench
                    ? 'Écris ta question...'
                    : 'Write your question...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
              ),
              onSubmitted: (_) {
                _sendMessage();
              },
            ),
          ),
          IconButton(
            tooltip: _isFrench ? 'Prendre une photo' : 'Take a photo',
            onPressed: _sending ? null : _takeAiPhoto,
            icon: const Icon(Icons.camera_alt_rounded),
          ),
          IconButton(
            tooltip: _isFrench ? 'Choisir une image' : 'Choose an image',
            onPressed: _sending ? null : _pickAiImage,
            icon: const Icon(Icons.photo_library_rounded),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 52,
            width: 52,
            child: FilledButton(
              onPressed: _sending
                  ? null
                  : () {
                      _sendMessage();
                    },
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool fromUser;

  const _AiMessage({required this.text, required this.fromUser});
}
