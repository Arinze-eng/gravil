import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:minimal_chat_app/features/chatlist/service/chat_service.dart';
import 'package:minimal_chat_app/features/chatview/view/chat_view.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerSimple extends StatefulWidget {
  const BarcodeScannerSimple({super.key});

  @override
  State<BarcodeScannerSimple> createState() => _BarcodeScannerSimpleState();
}

class _BarcodeScannerSimpleState extends State<BarcodeScannerSimple> {
  @override
  void initState() {
    super.initState();
  }

  Barcode? _barcode;

  Widget _buildBarcode(Barcode? value) {
    if (value == null) {
      return const Text(
        'Scan something!',
        overflow: TextOverflow.fade,
        style: TextStyle(color: Colors.white),
      );
    }

    return Visibility(
      visible: value.displayValue != null,
      child: FilledButton.tonal(
        onPressed: () async {
          log(value.displayValue!);
          ChatService().addFriend(value.displayValue!);
          var userInfo = await ChatService().getUserInfo(value.displayValue!);
          if (mounted) {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatView(
                      friendId: value.displayValue!, username: userInfo.email),
                ));
          }
        },
        child: const Text("Add Friend"),
      ),
    );
  }

  void _handleBarcode(BarcodeCapture barcodes) {
    if (mounted) {
      setState(() {
        _barcode = barcodes.barcodes.firstOrNull;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Friends')),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _handleBarcode,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              alignment: Alignment.bottomCenter,
              height: 100,
              color: Colors.black.withOpacity(0.4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(child: Center(child: _buildBarcode(_barcode))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
