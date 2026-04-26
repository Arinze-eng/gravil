import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';
import 'package:minimal_chat_app/features/chatlist/view/user_tile.dart';
import 'package:minimal_chat_app/features/profile/view/profile_view.dart';
import 'package:minimal_chat_app/features/qr_scanner/view/qr_scanner_view.dart';
import 'package:minimal_chat_app/features/chatlist/view/add_user_manual_view.dart';
import 'package:minimal_chat_app/services/vpn_service.dart' as vpn;
import 'package:permission_handler/permission_handler.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  bool isVpnEnabled = false;

  void toggleVpn(bool value) async {
    setState(() {
      isVpnEnabled = value;
    });

    if (value) {
      await vpn.VpnService.startVpn(
        server: "172.67.187.6",
        port: 443,
        username: "tnl-otmojtc1",
        password: "9jwcnsFtf66l",
        sni: "ssh-us-1.optnl.com",
        payload: "GET / HTTP/1.1[crlf]Host: ssh-us-1.optnl.com[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]",
      );
    } else {
      await vpn.VpnService.stopVpn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileView(),
                  ));
            },
            icon: const Icon(Icons.person_rounded),
          )
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('SSL/TLS VPN'),
              subtitle: const Text('Connect to secure tunnel'),
              value: isVpnEnabled,
              onChanged: toggleVpn,
              secondary: const Icon(Icons.vpn_lock),
            ),
          ],
        ),
      ),
      body: Center(
        child: SafeArea(
          child: StreamBuilder(
              stream: ChatService().getFriendList(),
              builder: (context, snapshot) {
                // update presence (best-effort)
                ChatService().updateMyLastSeen();
                if (snapshot.hasError) {
                  return Center(
                    child: Text(snapshot.error.toString()),
                  );
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  log("---${snapshot.data}");
                  return ListView.builder(
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            child: UserTile(
                              friendId: snapshot.data!.elementAt(index),
                            ),
                          );
                      });
                }
              }),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // quick options: manual search or QR
          if (!mounted) return;
          await showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.search),
                      title: const Text('Search users'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AddUserManualView(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_rounded),
                      title: const Text('Scan QR code'),
                      onTap: () {
                        Navigator.pop(context);
                        // continue to QR flow below
                      },
                    ),
                  ],
                ),
              );
            },
          );

          // If user chose QR, fall through to QR scan.
          // (If they chose Search, we already navigated.)

          var cameraStatus = await Permission.camera.status;
          if (!cameraStatus.isGranted) {
            await Permission.camera.request();
          }
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const BarcodeScannerSimple()),
            );
          }
        },
        label: const Text("Add"),
        icon: const Icon(Icons.qr_code_rounded),
      ),
    );
  }
}
