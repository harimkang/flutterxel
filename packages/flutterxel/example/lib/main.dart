import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

void main() {
  flutterxel.init(160, 120, title: 'flutterxel example', fps: 30);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final version =
        '${flutterxel.Flutterxel.versionMajor()}.'
        '${flutterxel.Flutterxel.versionMinor()}.'
        '${flutterxel.Flutterxel.versionPatch()}';

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutterxel example')),
        body: Center(
          child: Text(
            'flutterxel core ABI v$version\n'
            'screen: ${flutterxel.width}x${flutterxel.height}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
