import 'dart:convert';

class CharacterManifest {
  const CharacterManifest({
    required this.id,
    required this.sheetAssetPath,
    required this.frameWidth,
    required this.frameHeight,
    required this.rows,
    required this.fps,
  });

  final String id;
  final String sheetAssetPath;
  final int frameWidth;
  final int frameHeight;
  final Map<String, int> rows;
  final Map<String, int> fps;

  static CharacterManifest fromMetaJsonString(
    String jsonText, {
    required String assetDirectory,
  }) {
    final decoded = json.decode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Character manifest must be a JSON object.');
    }
    return fromJson(decoded, assetDirectory: assetDirectory);
  }

  static CharacterManifest fromJson(
    Map<String, dynamic> jsonMap, {
    required String assetDirectory,
  }) {
    final id = _readString(jsonMap, 'id');
    final sheet = _readString(jsonMap, 'sheet');
    final frame = _readMap(jsonMap, 'frame');
    final rows = _readIntMap(jsonMap, 'rows');
    final fps = _readIntMap(jsonMap, 'fps');
    final frameWidth = _readPositiveInt(frame, 'width', 'frame');
    final frameHeight = _readPositiveInt(frame, 'height', 'frame');

    final normalizedDir = assetDirectory.endsWith('/')
        ? assetDirectory.substring(0, assetDirectory.length - 1)
        : assetDirectory;

    return CharacterManifest(
      id: id,
      sheetAssetPath: '$normalizedDir/$sheet',
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      rows: Map<String, int>.unmodifiable(rows),
      fps: Map<String, int>.unmodifiable(fps),
    );
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw FormatException(
        'Character manifest "$key" must be a non-empty string.',
      );
    }
    return value;
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Map<String, dynamic>) {
      throw FormatException('Character manifest "$key" must be an object.');
    }
    return value;
  }

  static Map<String, int> _readIntMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! Map<String, dynamic> || value.isEmpty) {
      throw FormatException(
        'Character manifest "$key" must be a non-empty object.',
      );
    }
    final result = <String, int>{};
    for (final entry in value.entries) {
      final state = entry.key;
      final raw = entry.value;
      if (state.isEmpty || raw is! num || raw % 1 != 0) {
        throw FormatException(
          'Character manifest "$key" must map non-empty strings to integers.',
        );
      }
      result[state] = raw.toInt();
    }
    return result;
  }

  static int _readPositiveInt(
    Map<String, dynamic> map,
    String key,
    String parentKey,
  ) {
    final value = map[key];
    if (value is! num || value % 1 != 0 || value.toInt() <= 0) {
      throw FormatException(
        'Character manifest "$parentKey.$key" must be a positive integer.',
      );
    }
    return value.toInt();
  }
}
