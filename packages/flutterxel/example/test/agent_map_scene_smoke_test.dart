import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel/flutterxel.dart' as flutterxel;
import 'package:flutterxel_example/agent_map/agent_map_controller.dart';
import 'package:flutterxel_example/agent_map/agent_map_scene.dart';
import 'package:flutterxel_example/agent_map/character_manifest.dart';

String _writeSheetAsHexText(
  Directory dir, {
  required String id,
  required String colorHex,
  int width = 32,
  int height = 24,
}) {
  final file = File('${dir.path}${Platform.pathSeparator}${id}_sheet.png');
  final line = colorHex * width;
  final content = List<String>.filled(height, line, growable: false).join('\n');
  file.writeAsStringSync(content, flush: true);
  return file.path;
}

void main() {
  testWidgets(
    'agent map scene initializes manifests and produces render ticks',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'flutterxel_agent_map_smoke_',
      );
      addTearDown(() {
        flutterxel.stopRunLoop();
        try {
          flutterxel.quit();
        } catch (_) {}
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final manifests = <CharacterManifest>[
        CharacterManifest(
          id: 'c0',
          sheetAssetPath: _writeSheetAsHexText(
            tempDir,
            id: 'c0',
            colorHex: '1',
          ),
          frameWidth: 8,
          frameHeight: 8,
          rows: const <String, int>{'idle': 0, 'work': 1, 'error': 2},
          fps: const <String, int>{'idle': 4, 'work': 8, 'error': 5},
        ),
        CharacterManifest(
          id: 'c1',
          sheetAssetPath: _writeSheetAsHexText(
            tempDir,
            id: 'c1',
            colorHex: '2',
          ),
          frameWidth: 8,
          frameHeight: 8,
          rows: const <String, int>{'idle': 0, 'work': 1, 'error': 2},
          fps: const <String, int>{'idle': 4, 'work': 8, 'error': 5},
        ),
        CharacterManifest(
          id: 'c2',
          sheetAssetPath: _writeSheetAsHexText(
            tempDir,
            id: 'c2',
            colorHex: '3',
          ),
          frameWidth: 8,
          frameHeight: 8,
          rows: const <String, int>{'idle': 0, 'work': 1, 'error': 2},
          fps: const <String, int>{'idle': 4, 'work': 8, 'error': 5},
        ),
      ];

      final controller = AgentMapController(
        manifestProvider: () async => manifests,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AgentMapScene(
                controller: controller,
                tickInterval: const Duration(milliseconds: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));

      expect(controller.isInitialized, isTrue);
      expect(controller.characterCount, 3);
      expect(controller.renderTickCount, greaterThan(0));
    },
  );
}
