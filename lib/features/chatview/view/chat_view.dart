// ignore_for_file: public_member_api_docs

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';
import 'package:minimal_chat_app/model/message_model.dart';
import 'package:minimal_chat_app/services/media_service.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatView extends StatefulWidget {
  final String friendId;
  final String username;

  const ChatView({
    super.key,
    required this.friendId,
    required this.username,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final _recorder = AudioRecorder();
  bool _recording = false;

  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _time(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }

  Future<void> _sendText() async {
    final txt = messageController.text.trim();
    if (txt.isEmpty) return;
    await ChatService().sendMessage(friendId: widget.friendId, message: txt);
    messageController.clear();
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null) return;

    final me = supabase.auth.currentUser!.id;
    final roomId = ([me, widget.friendId]..sort()).join('_');

    final parts = xfile.name.split('.');
    final ext = parts.length >= 2 ? parts.last : 'jpg';

    final mediaPath = await MediaService.uploadChatMedia(
      roomId: roomId,
      file: File(xfile.path),
      extension: ext,
      contentType: xfile.mimeType ?? 'image/jpeg',
    );

    await ChatService().sendMediaMessage(
      friendId: widget.friendId,
      type: 'image',
      mediaPath: mediaPath,
      mediaMime: xfile.mimeType ?? 'image/jpeg',
    );
  }

  Future<void> _toggleVoiceNote() async {
    if (!_recording) {
      final hasPerm = await _recorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      HapticFeedback.mediumImpact();
      setState(() => _recording = true);
      return;
    }

    final path = await _recorder.stop();
    setState(() => _recording = false);

    if (path == null) return;

    final me = supabase.auth.currentUser!.id;
    final roomId = ([me, widget.friendId]..sort()).join('_');

    final mediaPath = await MediaService.uploadChatMedia(
      roomId: roomId,
      file: File(path),
      extension: 'm4a',
      contentType: 'audio/mp4',
    );

    await ChatService().sendMediaMessage(
      friendId: widget.friendId,
      type: 'voice',
      mediaPath: mediaPath,
      mediaMime: 'audio/mp4',
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    scrollController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(child: Text(widget.username[0].toUpperCase())),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.username)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: StreamBuilder<List<MessageModel>>(
                stream: ChatService().getMessage(widget.friendId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text(snapshot.error.toString()));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reversed = snapshot.data!.reversed.toList();
                  return ListView.builder(
                    reverse: true,
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: reversed.length,
                    itemBuilder: (context, index) {
                      return _bubble(context, reversed[index]);
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Send image',
                  onPressed: _pickAndSendImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  tooltip: _recording ? 'Stop recording' : 'Record voice note',
                  onPressed: _toggleVoiceNote,
                  icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none),
                ),
                Expanded(
                  child: TextField(
                    controller: messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(100)),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sendText,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(BuildContext context, MessageModel m) {
    final me = supabase.auth.currentUser!.id;
    final isSentByMe = m.senderId == me;

    final msg = m.message;
    final isUrl = msg.startsWith('http://') || msg.startsWith('https://');
    final isImageUrl = isUrl && (msg.contains('/chat_media/') || msg.endsWith('.jpg') || msg.endsWith('.png') || msg.endsWith('.jpeg') || msg.endsWith('.webp'));

    return Align(
      alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImageUrl)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(msg, fit: BoxFit.cover),
                )
              else
                Text(msg.isEmpty ? '[empty]' : msg),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _time(m.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSecondaryContainer.withAlpha(190),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
