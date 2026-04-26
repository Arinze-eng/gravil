import 'package:flutter/material.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';
import 'package:minimal_chat_app/features/chatview/view/chat_view.dart';

class UserTile extends StatefulWidget {
  final String friendId;
  const UserTile({
    super.key,
    required this.friendId,
  });

  @override
  State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  var username = '';
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatView(
              username: username,
              friendId: widget.friendId,
            ),
          ),
        );
      },
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      title: FutureBuilder(
          future: ChatService().getUserInfo(widget.friendId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            } else {
              username = snapshot.data!.email;
              return Text(
                  snapshot.data!.email.split('@').first[0].toUpperCase() +
                      username.split('@').first.substring(1));
            }
          }),
      leading: const Icon(Icons.person_rounded),
      tileColor: Theme.of(context).colorScheme.secondaryContainer,
    );
  }
}
