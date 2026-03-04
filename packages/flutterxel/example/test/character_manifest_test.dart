import 'package:flutter_test/flutter_test.dart';
import 'package:flutterxel_example/agent_map/character_manifest.dart';

void main() {
  test('parses *_sheet.meta.json fields for id/frame/rows/fps', () {
    final manifest = CharacterManifest.fromMetaJsonString('''
{
  "id": "dude",
  "sheet": "dude_sheet.png",
  "frame": {"width": 32, "height": 32},
  "rows": {"idle": 0, "work": 1, "error": 2},
  "fps": {"idle": 4, "work": 8, "error": 5}
}
''', assetDirectory: 'assets/characters/dude');

    expect(manifest.id, 'dude');
    expect(manifest.sheetAssetPath, 'assets/characters/dude/dude_sheet.png');
    expect(manifest.frameWidth, 32);
    expect(manifest.frameHeight, 32);
    expect(manifest.rows['idle'], 0);
    expect(manifest.rows['work'], 1);
    expect(manifest.rows['error'], 2);
    expect(manifest.fps['idle'], 4);
    expect(manifest.fps['work'], 8);
    expect(manifest.fps['error'], 5);
  });
}
