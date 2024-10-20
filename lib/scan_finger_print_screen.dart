import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zkfinger10/finger_status.dart';
import 'package:zkfinger10/finger_status_type.dart';
import 'package:zkfinger10/zk_finger.dart';

class ScanFingerPrintScreen extends StatefulWidget {
  const ScanFingerPrintScreen({super.key});

  @override
  State<ScanFingerPrintScreen> createState() => _ScanFingerPrintScreenState();
}

class _ScanFingerPrintScreenState extends State<ScanFingerPrintScreen> {
  Uint8List? fingerBytesImage; // Stores raw fingerprint image data
  String base64Image = 'base64isNotGenerated'; // Base64 representation of image
  File? fingerPrintImage; // File reference to saved fingerprint image
  FingerStatus? fingerStatus; // Current status of fingerprint scanning
  FingerStatusType? tempStatusType; // Temporary status type for comparison
  String statusText = ''; // Text representation of current status
  bool? isDeviceSupported; // Flag for device compatibility

  Future<void> initPlatformState() async {
    ZkFinger.imageStream
        .receiveBroadcastStream()
        .listen(mapFingerImage); // Listen to fingerprint image stream
    ZkFinger.statusChangeStream
        .receiveBroadcastStream()
        .listen(updateStatus); // Listen to fingerprint status stream

    if (!mounted) return;
  }

  void mapFingerImage(dynamic imageBytes) {
    try {
      print('imageBytes: $imageBytes');
      fingerBytesImage = imageBytes;
      base64Image = uint8ListTob64(fingerBytesImage!);
      updateFingerImage(fingerBytesImage!);
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  String uint8ListTob64(Uint8List uint8list) {
    String base64String = base64Encode(uint8list);
    String header = "data:image/png;base64,";
    return header + base64String;
  }

  updateFingerImage(Uint8List bytes) async {
    fingerPrintImage = await convertBase64ToFile(bytes);
    setState(() {});
  }

  Future<File> convertBase64ToFile(Uint8List bytes) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    File file = File('$dir/$timestamp.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  void updateStatus(dynamic value) {
    print('status: $value');
    Map<dynamic, dynamic> statusMap = value as Map<dynamic, dynamic>;
    FingerStatusType statusType =
        FingerStatusType.values[statusMap['fingerStatus']];
    fingerStatus = FingerStatus(
        statusMap['message'], statusType, statusMap['id'], statusMap['data']);

    if (statusType == tempStatusType &&
        tempStatusType == FingerStatusType.CAPTURE_ERROR) {
      //ignore capture error when finger device get stuck
      statusText = 'CAPTURE ERROR';
    } else {
      tempStatusType = statusType;
      setState(() {
        statusText = statusType.toString();
      });
    }
  }

  scanFinger() async {
    try {
      isDeviceSupported = await ZkFinger.openConnection();
      setState(() {});
    } catch (error) {
      if (mounted) {
        showSnackBar(context, message: 'Error: $error', isWarning: true);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  @override
  void dispose() {
    ZkFinger.onDestroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Finger Print'),
      ),
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () {
            scanFinger();
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              fingerPrintImage != null
                  ? Image.file(fingerPrintImage!)
                  : const Icon(Icons.fingerprint, size: 100),
              const SizedBox(height: 20),
              const Text('Scan Finger Print'),
            ],
          ),
        ),
      )),
    );
  }
}

showSnackBar(BuildContext context,
    {required String message, isWarning = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: isWarning
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).primaryColor,
      content: Text(message),
    ),
  );
}
