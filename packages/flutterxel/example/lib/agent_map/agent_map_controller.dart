import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutterxel/flutterxel.dart' as flutterxel;

import 'activity_feed.dart';
import 'agent_state.dart';
import 'agent_state_machine.dart';
import 'character_manifest.dart';

typedef AgentManifestProvider = Future<List<CharacterManifest>> Function();

class AgentMapController {
  AgentMapController({
    AgentStateMachine? stateMachine,
    ActivityFeed? activityFeed,
    AgentManifestProvider? manifestProvider,
    this.syncedAssetRoot = 'assets/characters',
  }) : _stateMachine = stateMachine ?? AgentStateMachine(),
       _activityFeed = activityFeed,
       _manifestProvider = manifestProvider;

  final AgentStateMachine _stateMachine;
  final ActivityFeed? _activityFeed;
  final AgentManifestProvider? _manifestProvider;
  final String syncedAssetRoot;
  final List<CharacterManifest> _manifests = <CharacterManifest>[];
  StreamSubscription<AgentZone>? _activitySubscription;
  AgentZone? _latestFeedZone;

  bool _initialized = false;
  int _renderTickCount = 0;

  bool get isInitialized => _initialized;
  int get characterCount => _manifests.length;
  int get renderTickCount => _renderTickCount;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final manifests =
        await (_manifestProvider?.call() ?? _loadDefaultManifests());
    if (manifests.length < 3) {
      throw StateError(
        'Agent map requires at least 3 character manifests. '
        'Run tool/sync_reference_characters.sh or provide a manifest provider.',
      );
    }

    _manifests
      ..clear()
      ..addAll(manifests.take(3));

    _activitySubscription?.cancel();
    _activitySubscription = _activityFeed?.zones().listen((zone) {
      _latestFeedZone = zone;
    });

    for (var i = 0; i < _manifests.length; i++) {
      final manifest = _manifests[i];
      final sheetFile = File(manifest.sheetAssetPath);
      if (!sheetFile.existsSync()) {
        throw StateError(
          'Character sheet not found: ${manifest.sheetAssetPath}',
        );
      }
      flutterxel.images[i].load(
        0,
        0,
        manifest.sheetAssetPath,
        preserve_transparent: true,
        transparent_index: flutterxel.COLOR_BLACK,
        alpha_threshold: 0,
      );
    }

    _initialized = true;
  }

  AgentState tick() {
    if (!_initialized) {
      throw StateError('AgentMapController.initialize() must be called first.');
    }
    final zone = _latestFeedZone ?? _syntheticZoneForTick(_renderTickCount);
    final state = _stateMachine.advance(zone);
    _render(state);
    _renderTickCount += 1;
    return state;
  }

  void dispose() {
    _activitySubscription?.cancel();
    _activitySubscription = null;
  }

  Future<List<CharacterManifest>> _loadDefaultManifests() async {
    final root = Directory(syncedAssetRoot);
    if (!root.existsSync()) {
      return const <CharacterManifest>[];
    }

    final manifests = <CharacterManifest>[];
    final dirs = root.listSync().whereType<Directory>().toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final dir in dirs) {
      final name = dir.path.split(Platform.pathSeparator).last;
      final metaFile = File(
        '${dir.path}${Platform.pathSeparator}${name}_sheet.meta.json',
      );
      if (!metaFile.existsSync()) {
        continue;
      }
      manifests.add(
        CharacterManifest.fromMetaJsonString(
          metaFile.readAsStringSync(),
          assetDirectory: dir.path,
        ),
      );
    }

    return manifests;
  }

  AgentZone _syntheticZoneForTick(int tick) {
    final bucket = (tick ~/ 120) % 3;
    return switch (bucket) {
      0 => AgentZone.idle,
      1 => AgentZone.work,
      _ => AgentZone.error,
    };
  }

  void _render(AgentState state) {
    flutterxel.cls(flutterxel.COLOR_NAVY);

    for (var i = 0; i < _manifests.length; i++) {
      final manifest = _manifests[i];
      final zoneKey = _zoneKey(state.zone);
      final row = manifest.rows[zoneKey] ?? 0;
      final fps = manifest.fps[zoneKey] ?? 4;
      final ticksPerFrame = math.max(1, (60 / math.max(1, fps)).round());
      final frame = (_renderTickCount ~/ ticksPerFrame) % 4;

      final u = frame * manifest.frameWidth;
      final v = row * manifest.frameHeight;
      final x = 8 + i * (manifest.frameWidth + 8);
      const y = 44;

      flutterxel.blt(
        x.toDouble(),
        y.toDouble(),
        i,
        u.toDouble(),
        v.toDouble(),
        manifest.frameWidth.toDouble(),
        manifest.frameHeight.toDouble(),
        colkey: flutterxel.COLOR_BLACK,
      );
    }
  }

  String _zoneKey(AgentZone zone) {
    return switch (zone) {
      AgentZone.idle => 'idle',
      AgentZone.work => 'work',
      AgentZone.error => 'error',
    };
  }
}
