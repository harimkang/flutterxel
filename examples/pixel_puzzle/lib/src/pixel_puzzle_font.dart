typedef PixelPlotter = void Function(int x, int y, int col);

class PixelPuzzleFont {
  PixelPuzzleFont._();

  static const int glyphWidth = 3;
  static const int glyphHeight = 5;

  static const Map<String, List<String>> _glyphs = <String, List<String>>{
    ' ': <String>['000', '000', '000', '000', '000'],
    '+': <String>['000', '010', '111', '010', '000'],
    '-': <String>['000', '000', '111', '000', '000'],
    ':': <String>['000', '010', '000', '010', '000'],
    '?': <String>['111', '001', '010', '000', '010'],
    '0': <String>['111', '101', '101', '101', '111'],
    '1': <String>['010', '110', '010', '010', '111'],
    '2': <String>['111', '001', '111', '100', '111'],
    '3': <String>['111', '001', '111', '001', '111'],
    '4': <String>['101', '101', '111', '001', '001'],
    '5': <String>['111', '100', '111', '001', '111'],
    '6': <String>['111', '100', '111', '101', '111'],
    '7': <String>['111', '001', '010', '010', '010'],
    '8': <String>['111', '101', '111', '101', '111'],
    '9': <String>['111', '101', '111', '001', '111'],
    'A': <String>['010', '101', '111', '101', '101'],
    'B': <String>['110', '101', '110', '101', '110'],
    'C': <String>['011', '100', '100', '100', '011'],
    'D': <String>['110', '101', '101', '101', '110'],
    'E': <String>['111', '100', '110', '100', '111'],
    'F': <String>['111', '100', '110', '100', '100'],
    'G': <String>['011', '100', '101', '101', '011'],
    'H': <String>['101', '101', '111', '101', '101'],
    'I': <String>['111', '010', '010', '010', '111'],
    'J': <String>['001', '001', '001', '101', '010'],
    'K': <String>['101', '101', '110', '101', '101'],
    'L': <String>['100', '100', '100', '100', '111'],
    'M': <String>['101', '111', '111', '101', '101'],
    'N': <String>['101', '111', '111', '111', '101'],
    'O': <String>['010', '101', '101', '101', '010'],
    'P': <String>['110', '101', '110', '100', '100'],
    'Q': <String>['010', '101', '101', '010', '001'],
    'R': <String>['110', '101', '110', '101', '101'],
    'S': <String>['011', '100', '010', '001', '110'],
    'T': <String>['111', '010', '010', '010', '010'],
    'U': <String>['101', '101', '101', '101', '111'],
    'V': <String>['101', '101', '101', '101', '010'],
    'W': <String>['101', '101', '111', '111', '101'],
    'X': <String>['101', '101', '010', '101', '101'],
    'Y': <String>['101', '101', '010', '010', '010'],
    'Z': <String>['111', '001', '010', '100', '111'],
  };

  static bool isSupported(String ch) => _glyphs.containsKey(ch.toUpperCase());

  static List<String> glyphFor(String ch) {
    final upper = ch.toUpperCase();
    return _glyphs[upper] ?? _glyphs['?']!;
  }

  static int textWidth(String text, {int spacing = 1, int scale = 1}) {
    if (text.isEmpty) {
      return 0;
    }
    final glyphSpace = (glyphWidth * scale) + spacing;
    return (text.length * glyphSpace) - spacing;
  }

  static void draw(
    PixelPlotter plot,
    int x,
    int y,
    String text,
    int color, {
    int spacing = 1,
    int scale = 1,
  }) {
    var cursorX = x;
    var cursorY = y;
    final lineStartX = x;

    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '\n') {
        cursorX = lineStartX;
        cursorY += glyphHeight * scale + spacing;
        continue;
      }

      final glyph = glyphFor(ch);
      for (var row = 0; row < glyphHeight; row++) {
        for (var col = 0; col < glyphWidth; col++) {
          if (glyph[row].codeUnitAt(col) != 0x31) {
            continue;
          }
          for (var sy = 0; sy < scale; sy++) {
            for (var sx = 0; sx < scale; sx++) {
              plot(
                cursorX + col * scale + sx,
                cursorY + row * scale + sy,
                color,
              );
            }
          }
        }
      }

      cursorX += glyphWidth * scale + spacing;
    }
  }
}
