import 'dart:convert';

import 'activity_feed.dart';
import 'agent_state.dart';

class JsonlActivityFeed implements ActivityFeed {
  JsonlActivityFeed.fromText(
    String jsonlText, {
    this.initialZone = AgentZone.idle,
  }) : _jsonlText = jsonlText,
       _readJsonl = null,
       pollInterval = const Duration(seconds: 1);

  JsonlActivityFeed.polling({
    required Future<String> Function() readJsonl,
    this.initialZone = AgentZone.idle,
    this.pollInterval = const Duration(seconds: 1),
  }) : _readJsonl = readJsonl,
       _jsonlText = null;

  final String? _jsonlText;
  final Future<String> Function()? _readJsonl;
  final AgentZone initialZone;
  final Duration pollInterval;

  static List<AgentZone> parseToolZones(
    String jsonlText, {
    AgentZone initialZone = AgentZone.idle,
  }) {
    var current = initialZone;
    final zones = <AgentZone>[];

    for (final rawLine in jsonlText.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final decoded = json.decode(line);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSONL line must decode to a JSON object.');
      }

      final status = _readStatus(decoded);
      final mapped = status == null ? null : _mapStatus(status);
      if (mapped != null) {
        current = mapped;
      }
      zones.add(current);
    }

    return zones;
  }

  @override
  Stream<AgentZone> zones() async* {
    final textSource = _jsonlText;
    if (textSource != null) {
      yield* Stream<AgentZone>.fromIterable(
        parseToolZones(textSource, initialZone: initialZone),
      );
      return;
    }

    final readJsonl = _readJsonl;
    if (readJsonl == null) {
      return;
    }

    var previous = initialZone;
    while (true) {
      final text = await readJsonl();
      final parsed = parseToolZones(text, initialZone: previous);
      for (final zone in parsed) {
        previous = zone;
        yield zone;
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  static String? _readStatus(Map<String, dynamic> jsonMap) {
    final candidates = <Object?>[
      jsonMap['status'],
      jsonMap['tool_status'],
      jsonMap['state'],
      jsonMap['phase'],
    ];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return null;
  }

  static AgentZone? _mapStatus(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'idle':
      case 'queued':
      case 'pending':
      case 'waiting':
      case 'sleeping':
        return AgentZone.idle;
      case 'running':
      case 'working':
      case 'in_progress':
      case 'completed':
      case 'success':
      case 'ok':
        return AgentZone.work;
      case 'error':
      case 'failed':
      case 'failure':
      case 'cancelled':
      case 'timeout':
      case 'crash':
        return AgentZone.error;
      default:
        return null;
    }
  }
}
