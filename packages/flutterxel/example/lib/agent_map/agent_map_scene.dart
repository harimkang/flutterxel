import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'agent_map_controller.dart';

class AgentMapScene extends StatefulWidget {
  const AgentMapScene({
    super.key,
    this.controller,
    this.tickInterval = const Duration(milliseconds: 16),
  });

  final AgentMapController? controller;
  final Duration tickInterval;

  @override
  State<AgentMapScene> createState() => _AgentMapSceneState();
}

class _AgentMapSceneState extends State<AgentMapScene> {
  late final AgentMapController _controller;
  Timer? _timer;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AgentMapController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      if (flutterxel.width <= 0 || flutterxel.height <= 0) {
        flutterxel.init(160, 120, title: 'flutterxel agent map', fps: 60);
      }
      await _controller.initialize();
      _controller.tick();
      _timer = Timer.periodic(widget.tickInterval, (_) {
        if (!mounted) {
          return;
        }
        _controller.tick();
        setState(() {});
      });
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = flutterxel.Flutterxel.backendMode.name;
    final status =
        _error ??
        'characters=${_controller.characterCount} '
            'ticks=${_controller.renderTickCount} '
            'backend=$backend';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const flutterxel.FlutterxelView(pixelScale: 3),
        const SizedBox(height: 12),
        Text(status, textAlign: TextAlign.center),
      ],
    );
  }
}
