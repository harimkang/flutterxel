import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final healthcheck = Flutterxel.ffiHealthcheck();

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutterxel example')),
        body: Center(
          child: Text(
            'FFI healthcheck: $healthcheck',
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
