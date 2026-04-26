import 'package:minimal_chat_app/model/message_model.dart';
import 'package:minimal_chat_app/model/user_model.dart';
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
    final me = myId;

    // Create mutual friendship (idempotent)
    await supabase.from('friendships').upsert({
      'user_id': me,
      'friend_id': friendId,
    });


    // Optional: seed a hello message (matches previous behavior)
    await sendMessage(friendId: friendId, message: 'Hii👋');
  }

  Future<void> sendMessage({required String friendId, required String message}) async {
    final me = myId;
    final ids = [me, friendId]..sort();
    final roomId = ids.join('_');

    await supabase.from('messages').insert({
      'room_id': roomId,
      'sender_id': me,
      'receiver_id': friendId,
      // keep column name compatible with your existing schema
      'content': message,
      'type': 'text',
    });
  }

  Stream<List<MessageModel>> getMessage(String friendId) {
    final me = myId;
    final ids = [me, friendId]..sort();
    final roomId = ids.join('_');

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
          message: r['content'] as String,
          timestamp: DateTime.parse(r['created_at'] as String).toLocal(),
        );
      }).toList();
    });
  }
}
