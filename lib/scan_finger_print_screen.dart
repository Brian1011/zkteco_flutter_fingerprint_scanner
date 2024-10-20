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
  String? _platformVersion = 'Unknown';
  Uint8List? fingerImages;
  String base64Image = 'base64isNotGenerated';
  File? leftFingerImage;
  FingerStatus? fingerStatus;
  FingerStatusType? tempStatusType;
  String statusText = '';
  bool? isDeviceSupported;

  Future<void> initPlatformState() async {
    String? platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      await ZkFinger.closeConnection();
      await ZkFinger.openConnection();
      platformVersion = await ZkFinger.platformVersion;
      print(platformVersion);
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
      showSnackBar(context, message: "Failed to get platform version.");
    }
    ZkFinger.imageStream.receiveBroadcastStream().listen(mapFingerImage);
    ZkFinger.statusChangeStream.receiveBroadcastStream().listen(updateStatus);

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void mapFingerImage(dynamic imageBytes) {
    try {
      fingerImages = imageBytes;
      base64Image = uint8ListTob64(fingerImages!);
      updateFingerImage(fingerImages!);
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  updateFingerImage(Uint8List bytes) async {
    setState(() {});
  }

  Future<File> convertBase64ToFile(Uint8List bytes) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    File file = File('$dir/$timestamp.png');
    await file.writeAsBytes(bytes);
    return file;
  }

  String uint8ListTob64(Uint8List uint8list) {
    String base64String = base64Encode(uint8list);
    String header = "data:image/png;base64,";
    return header + base64String;
  }

  void updateStatus(dynamic value) {
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
        //setBiometricBase64TextField();
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
              leftFingerImage != null
                  ? Image.file(leftFingerImage!)
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
