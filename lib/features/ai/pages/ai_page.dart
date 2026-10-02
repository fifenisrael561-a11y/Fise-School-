import 'dart:typed_data';

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

  final List<_AiMessage> _messages = [];
  PickedAttachment? _attachment;
  PickedAttachment? _conversationAttachment;
  bool _sending = false;

  bool get _isFrench => widget.locale.languageCode != 'en';

  @override
  void initState() {
    super.initState();
    _messages.add(_AiMessage(
      text: _isFrench
          ? 'Bonjour ${widget.profile.firstName} 👋\n\nJe suis l’assistant IA de Fise School. Pose-moi une question sur tes cours, envoie un document, une photo ou prends une photo directement avec ton téléphone.'
          : 'Hello ${widget.profile.firstName} 👋\n\nI am the Fise School AI assistant. Ask about your lessons, attach a document or photo, or take a photo directly with your phone.',
      fromUser: false,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final selectedAttachment = _attachment;
    final contextAttachment = selectedAttachment ?? _conversationAttachment;
    if ((text.isEmpty && contextAttachment == null) || _sending) return;

    _messageController.clear();
    final history = _messages
        .where((message) => message.text.trim().isNotEmpty || message.attachmentName != null)
        .takeLast(20)
        .map((message) => AiHistoryMessage(
              role: message.fromUser ? 'user' : 'model',
              text: message.attachmentName == null
                  ? message.text
                  : '${message.text.isEmpty ? '' : '${message.text}\n'}[Fichier joint : ${message.attachmentName}]',
            ))
        .toList();

    setState(() {
      _messages.add(_AiMessage(
        text: text,
        fromUser: true,
        attachmentName: selectedAttachment?.name,
        attachmentMimeType: selectedAttachment?.mimeType,
        attachmentBytes: selectedAttachment?.bytes,
      ));
      _attachment = null;
      if (selectedAttachment != null) {
        _conversationAttachment = selectedAttachment;
      }
      _sending = true;
    });
    _scrollToBottom();

    try {
      final answer = await _geminiService.ask(
        message: text,
        profile: widget.profile,
        history: history,
        attachmentBytes: contextAttachment?.bytes,
        attachmentMimeType: contextAttachment?.mimeType,
        attachmentName: contextAttachment?.name,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_AiMessage(text: answer, fromUser: false));
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(_AiMessage(
          text: _friendlyError(error),
          fromUser: false,
        ));
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.contains('too large') || raw.contains('Taille')) return raw;
    if (raw.length <= 220) return raw;
    return _isFrench
        ? 'Impossible de traiter cette demande. Vérifie ta connexion ou essaie un fichier plus petit.'
        : 'I could not process this request. Check your connection or try a smaller file.';
  }

  Future<void> _showAttachmentMenu() async {
    if (_sending) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.camera_alt_rounded)),
                title: Text(_isFrench ? 'Prendre une photo' : 'Take a photo'),
                subtitle: Text(_isFrench ? 'Utiliser la caméra maintenant' : 'Use the camera now'),
                onTap: () async { Navigator.pop(context); await _takePhoto(); },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.photo_library_rounded)),
                title: Text(_isFrench ? 'Photos et images' : 'Photos and images'),
                onTap: () async { Navigator.pop(context); await _pickImage(); },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.attach_file_rounded)),
                title: Text(_isFrench ? 'Document ou fichier' : 'Document or file'),
                subtitle: Text(_isFrench ? 'PDF et fichiers texte' : 'PDF and text files'),
                onTap: () async { Navigator.pop(context); await _pickDocument(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    final file = await _photoService.takePhoto();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _setAttachment(PickedAttachment(
      bytes: bytes,
      name: 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg',
      mimeType: file.mimeType ?? 'image/jpeg',
    ));
  }

  Future<void> _pickImage() async {
    final file = await _photoService.pickFromGallery();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    _setAttachment(PickedAttachment(
      bytes: bytes,
      name: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
    ));
  }

  Future<void> _pickDocument() async {
    final file = await _photoService.pickFile(
      allowedExtensions: const [
        'pdf', 'txt', 'md', 'csv',
      ],
    );
    if (!mounted || file == null) return;
    _setAttachment(file);
  }

  void _setAttachment(PickedAttachment attachment) {
    const maxBytes = 8 * 1024 * 1024;
    if (attachment.bytes.length > maxBytes) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFrench
            ? 'Le fichier est trop volumineux. Limite : 8 Mo.'
            : 'The file is too large. Limit: 8 MB.'),
      ));
      return;
    }
    setState(() => _attachment = attachment);
  }

  void _removeAttachment() => setState(() => _attachment = null);

  void _clearConversation() {
    setState(() {
      _messages
        ..clear()
        ..add(_AiMessage(
          text: _isFrench ? 'Conversation effacée. Comment puis-je t’aider ?' : 'Conversation cleared. How can I help?',
          fromUser: false,
        ));
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isFrench ? 'Assistant IA Fise School' : 'Fise School AI'),
        actions: [
          IconButton(
            tooltip: _isFrench ? 'Nouvelle conversation' : 'New conversation',
            onPressed: _sending ? null : _clearConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildContextBanner(),
            Expanded(child: _buildConversation()),
            if (_sending) const LinearProgressIndicator(minHeight: 2),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildContextBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFF166534)),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _isFrench
                ? 'Tu peux écrire, joindre un document, choisir une photo ou utiliser la caméra.'
                : 'You can type, attach a document, choose a photo, or use the camera.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          )),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _buildMessage(_messages[index]),
    );
  }

  Widget _buildMessage(_AiMessage message) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF166534) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.attachmentName != null) ...[
              _attachmentPreview(message, compact: true),
              if (message.text.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.text.isNotEmpty)
              SelectableText(
                message.text,
                style: TextStyle(
                  color: user ? Colors.white : const Color(0xFF0F172A),
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentPreview(_AiMessage message, {bool compact = false}) {
    final image = message.attachmentMimeType?.startsWith('image/') == true && message.attachmentBytes != null;
    if (image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          message.attachmentBytes!,
          width: compact ? 220 : double.infinity,
          height: compact ? 150 : 190,
          fit: BoxFit.cover,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_fileIcon(message.attachmentMimeType), color: message.fromUser ? Colors.white : const Color(0xFF166534)),
        const SizedBox(width: 8),
        Flexible(child: Text(
          message.attachmentName ?? 'File',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: message.fromUser ? Colors.white : Colors.black87, fontWeight: FontWeight.w700),
        )),
      ],
    );
  }

  IconData _fileIcon(String? mime) {
    if (mime == 'application/pdf') return Icons.picture_as_pdf_rounded;
    if (mime?.startsWith('audio/') == true) return Icons.audio_file_rounded;
    if (mime?.startsWith('video/') == true) return Icons.video_file_rounded;
    return Icons.description_rounded;
  }

  Widget _buildComposer() {
    return Material(
      elevation: 8,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_attachment != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5EC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(_fileIcon(_attachment!.mimeType), color: const Color(0xFF166534)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_attachment!.name, overflow: TextOverflow.ellipsis)),
                    IconButton(onPressed: _removeAttachment, icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: _isFrench ? 'Joindre' : 'Attach',
                  onPressed: _sending ? null : _showAttachmentMenu,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _isFrench ? 'Message...' : 'Message...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AiMessage {
  final String text;
  final bool fromUser;
  final String? attachmentName;
  final String? attachmentMimeType;
  final Uint8List? attachmentBytes;

  const _AiMessage({
    required this.text,
    required this.fromUser,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentBytes,
  });
}

extension<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    if (count <= 0) return const <T>[];
    final list = toList(growable: false);
    return list.length <= count ? list : list.sublist(list.length - count);
  }
}
