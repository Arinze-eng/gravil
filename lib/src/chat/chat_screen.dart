import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../utils/supabase_client.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerPublicId;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerPublicId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  final _picker = ImagePicker();
  final _record = AudioRecorder();
  bool _sending = false;
  bool _recording = false;

  String get _me => supabase.auth.currentUser!.id;

  String _roomId(String a, String b) {
    final s = [a, b]..sort();
    return '${s[0]}_${s[1]}';
  }

  Future<void> _ensurePeerExists() async {
    // No-op: used to validate peer id in DB if needed.
  }

  Future<void> _sendText() async {
    final msg = _text.text.trim();
    if (msg.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      _text.clear();
      await supabase.from('messages').insert({
        'room_id': _roomId(_me, widget.peerId),
        'sender_id': _me,
        'receiver_id': widget.peerId,
        'type': 'text',
        'content': msg,
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<String> _uploadToStorage(File file, {required String bucket, required String folder}) async {
    final bytes = await file.length();
    if (bucket == 'images' && bytes > 4 * 1024 * 1024) {
      throw Exception('Image too large (max 4MB)');
    }
    if (bucket == 'voice' && bytes > 5 * 1024 * 1024) {
      throw Exception('Voice note too large (max 5MB)');
    }

    final filename = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
    final path = '$folder/$filename';

    await supabase.storage.from(bucket).upload(path, file);
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  Future<void> _sendImage() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (x == null) return;
    final file = File(x.path);

    setState(() => _sending = true);
    try {
      final url = await _uploadToStorage(file, bucket: 'images', folder: _roomId(_me, widget.peerId));
      await supabase.from('messages').insert({
        'room_id': _roomId(_me, widget.peerId),
        'sender_id': _me,
        'receiver_id': widget.peerId,
        'type': 'image',
        'content': url,
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendFile() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    if (res == null || res.files.single.path == null) return;
    final file = File(res.files.single.path!);

    setState(() => _sending = true);
    try {
      final url = await _uploadToStorage(file, bucket: 'files', folder: _roomId(_me, widget.peerId));
      await supabase.from('messages').insert({
        'room_id': _roomId(_me, widget.peerId),
        'sender_id': _me,
        'receiver_id': widget.peerId,
        'type': 'file',
        'content': url,
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _record.stop();
      setState(() => _recording = false);
      if (path == null) return;

      final file = File(path);
      setState(() => _sending = true);
      try {
        final url = await _uploadToStorage(file, bucket: 'voice', folder: _roomId(_me, widget.peerId));
        await supabase.from('messages').insert({
          'room_id': _roomId(_me, widget.peerId),
          'sender_id': _me,
          'receiver_id': widget.peerId,
          'type': 'voice',
          'content': url,
        });
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    final can = await _record.hasPermission();
    if (!can) throw Exception('No microphone permission');

    final dir = await getTemporaryDirectory();
    final out = p.join(dir.path, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

    await _record.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
      path: out,
    );
    setState(() => _recording = true);
  }

  Future<void> _markRead(List<Map<String, dynamic>> msgs) async {
    // Mark any message sent to me as read.
    final unreadIds = msgs
        .where((m) => m['receiver_id'] == _me && m['read_at'] == null)
        .map((m) => m['id'])
        .toList();
    if (unreadIds.isEmpty) return;

    await supabase
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .inFilter('id', unreadIds);
  }

  @override
  void initState() {
    super.initState();
    _ensurePeerExists();
  }

  @override
  void dispose() {
    _text.dispose();
    _record.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _roomId(_me, widget.peerId);
    final timeFmt = DateFormat('HH:mm');

    final msgStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', room)
        .order('created_at');

    final peerStream = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.peerId)
        .limit(1);

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Map<String, dynamic>>>(
          stream: peerStream,
          builder: (context, snap) {
            final p = (snap.data?.isNotEmpty ?? false) ? snap.data!.first : null;
            final lastSeen = p?['last_seen'];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.peerName}  (#${widget.peerPublicId})'),
                Text(
                  'Last seen: ${lastSeen ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: msgStream,
              builder: (context, snap) {
                final msgs = (snap.data ?? const []).map((e) => e).toList();
                if (msgs.isNotEmpty) {
                  // best-effort
                  _markRead(msgs);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    final mine = m['sender_id'] == _me;
                    final createdAt = DateTime.tryParse(m['created_at'] ?? '')?.toLocal();
                    final t = createdAt == null ? '' : timeFmt.format(createdAt);
                    final readAt = m['read_at'];

                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: mine ? Theme.of(context).colorScheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MessageBody(type: m['type'] as String, content: m['content'] as String, mine: mine),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mine ? Colors.white70 : Colors.black54),
                                ),
                                if (mine) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    readAt == null ? Icons.done : Icons.done_all,
                                    size: 16,
                                    color: readAt == null ? Colors.white70 : Colors.lightBlueAccent,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Row(
                children: [
                  IconButton(onPressed: _sending ? null : _sendImage, icon: const Icon(Icons.image_outlined)),
                  IconButton(onPressed: _sending ? null : _sendFile, icon: const Icon(Icons.attach_file)),
                  IconButton(
                    onPressed: _sending ? null : () async {
                      try {
                        await _toggleRecord();
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
                    icon: Icon(_recording ? Icons.stop_circle_outlined : Icons.mic_none),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Message…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendText,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final String type;
  final String content;
  final bool mine;

  const _MessageBody({required this.type, required this.content, required this.mine});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: mine ? Colors.white : Colors.black87);

    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(content, height: 180, width: 240, fit: BoxFit.cover),
        );
      case 'voice':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.graphic_eq, color: mine ? Colors.white70 : Colors.black54),
            const SizedBox(width: 8),
            Flexible(child: Text('Voice note (tap to open)', style: textStyle)),
          ],
        );
      case 'file':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: mine ? Colors.white70 : Colors.black54),
            const SizedBox(width: 8),
            Flexible(child: Text('File (tap to open)', style: textStyle)),
          ],
        );
      default:
        return Text(content, style: textStyle);
    }
  }
}
