// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';
import 'package:minimal_chat_app/model/message_model.dart';
import 'package:minimal_chat_app/services/supabase_client.dart';

class ChatView extends StatelessWidget {
  String friendId;
  String username;
  ChatView({
    super.key,
    required this.friendId,
    required this.username,
  });

  final TextEditingController messageController = TextEditingController();

  final ScrollController scrollController = ScrollController();
  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500), curve: Curves.bounceIn);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(
      (timeStamp) => _scrollToBottom(),
    );
    String timeChange(DateTime timestamp) {
      var outputFormat = DateFormat('hh:mm');
      var outputDate = outputFormat.format(timestamp);
      return outputDate;
    }

    sendMessage() {
      if (messageController.text != '') {
        ChatService()
            .sendMessage(friendId: friendId, message: messageController.text);
        messageController.clear();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              child: Text(username[0].toUpperCase()),
            ),
            const SizedBox(
              width: 5,
            ),
            Expanded(child: Text(username)),
          ],
        ),
        actions: [
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: StreamBuilder(
                  stream: ChatService().getMessage(friendId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    } else if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    } else {
                      // reversed list
                      final reversedList = snapshot.data!.reversed.toList();

                      return ListView.builder(
                        reverse: true,
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          return chatBubble(
                              context, reversedList, index, timeChange);
                        },
                      );
                    }
                  }),
            ),
          ),

          // chat textfield
          Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(1.0),
                      child: TextField(
                        enableSuggestions: true,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (value) {
                          sendMessage();
                        },
                        onTapOutside: (event) {
                          FocusScope.of(context).unfocus();
                        },
                        controller: messageController,
                        decoration: const InputDecoration(
                          hintText: "Message",
                          border: OutlineInputBorder(
                            borderSide: BorderSide.none,
                            borderRadius: BorderRadius.all(
                              Radius.circular(100),
                            ),
                          ),
                        ),
                      )),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: IconButton(
                    onPressed: () {
                      sendMessage();
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget chatBubble(BuildContext context, List<MessageModel> messageModel,
      int index, String Function(DateTime timestamp) timeChange) {
    final me = supabase.auth.currentUser!.id;
    bool isSentbyUser = messageModel.elementAt(index).senderId == me;
    return Align(
      alignment: isSentbyUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10.0),
        child: Container(
          width: MediaQuery.of(context).size.width / 2,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messageModel.elementAt(index).message,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeChange(messageModel.elementAt(index).timestamp),
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withAlpha(190)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
