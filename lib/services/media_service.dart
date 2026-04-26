import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';

class MediaService {
  static const _bucket = 'chat_media';

  /// Upload a file to Supabase Storage and return the storage path.
  static Future<String> uploadChatMedia({
    required String roomId,
    required File file,
    required String extension,
    String? contentType,
  }) async {
    final id = const Uuid().v4();
    final path = '$roomId/$id.$extension';

    final bytes = await file.readAsBytes();

    await supabase.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: contentType,
          ),
        );

    return path;
  }

  static String publicUrl(String path) {
    return supabase.storage.from(_bucket).getPublicUrl(path);
  }
}
