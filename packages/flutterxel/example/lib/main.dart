import 'package:flutter/material.dart';

import 'agent_map/agent_map_scene.dart';

void main() {
  runApp(const AgentMapApp());
}

class AgentMapApp extends StatelessWidget {
  const AgentMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('flutterxel agent map')),
        body: const Center(child: AgentMapScene()),
      ),
    );
  }
}
