import 'package:minimal_chat_app/model/message_model.dart';
import 'package:minimal_chat_app/model/user_model.dart';
import 'package:minimal_chat_app/services/media_service.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  String get myId {
    final user = supabase.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    return user.id;
  }

  // FRIEND LIST (ids)
  Stream<List<String>> getFriendList() {
    final me = myId;
    return supabase
        .from('friendships')
        .stream(primaryKey: ['user_id', 'friend_id'])
        .eq('user_id', me)
        .map((rows) => rows.map((r) => r['friend_id'] as String).toList());
  }

  Future<void> updateMyLastSeen() async {
    final me = supabase.auth.currentUser;
    if (me == null) return;
    await supabase.from('profiles').upsert({
      'id': me.id,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'id');
  }

  Future<List<Map<String, dynamic>>> searchUsers(String term) async {
    final me = myId;
    final q = term.trim();
    if (q.isEmpty) return [];

    final res = await supabase
        .from('profiles')
        .select('id,email,name,code,username,last_seen')
        .or('email.ilike.%$q%,name.ilike.%$q%,code.eq.$q,username.ilike.%$q%')
        .neq('id', me)
        .limit(30);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<UserModel> getUserInfo(String userId) async {
    final res = await supabase
        .from('profiles')
        .select('id,email')
        .eq('id', userId)
        .maybeSingle();

    if (res == null) {
      return UserModel(email: 'Unknown', id: userId, friendsList: const []);
    }

    return UserModel(
      email: (res['email'] as String?) ?? 'unknown@example.com',
      id: res['id'] as String,
      friendsList: const [],
    );
  }

  Future<void> addFriend(String friendId) async {
    if (friendId == myId) return;
    final me = myId;

    // Create mutual friendship (idempotent)
    await supabase.from('friendships').upsert({
      'user_id': me,
      'friend_id': friendId,
    });


    // Optional: seed a hello message (matches previous behavior)
    await sendMessage(friendId: friendId, message: 'Hii👋');
  }

  String _roomIdFor(String friendId) {
    final me = myId;
    final ids = [me, friendId]..sort();
    return ids.join('_');
  }

  Future<void> sendMessage({required String friendId, required String message}) async {
    final me = myId;
    final roomId = _roomIdFor(friendId);

    await supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': me,
      'receiver_id': friendId,
      'content': message,
      'type': 'text',
    });
  }

  Future<void> sendMediaMessage({
    required String friendId,
    required String type,
    required String mediaPath,
    required String mediaMime,
    int? mediaDurationMs,
    String? caption,
  }) async {
    final me = myId;
    final roomId = _roomIdFor(friendId);

    await supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': me,
      'receiver_id': friendId,
      'content': caption,
      'type': type,
      'media_path': mediaPath,
      'media_mime': mediaMime,
      'media_duration_ms': mediaDurationMs,
    });
  }

  Stream<List<MessageModel>> getMessage(String friendId) {
    final roomId = _roomIdFor(friendId);

    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) {
      return rows.map((r) {
        return MessageModel(
          senderId: r['sender_id'] as String,
          senderEmail: '',
          receiverId: r['receiver_id'] as String,
          message: (() {
            final type = (r['type'] as String?) ?? 'text';
            if (type == 'text') {
              return (r['content'] as String?) ?? (r['message'] as String?) ?? '';
            }
            final path = r['media_path'] as String?;
            if (path == null) return '[media]';
            return MediaService.publicUrl(path);
          })(),
          timestamp: DateTime.parse(r['created_at'] as String).toLocal(),
        );
      }).toList();
    });
  }
}
