import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_puzzle/src/pixel_puzzle_font.dart';

void main() {
  group('PixelPuzzleFont', () {
    test('supports puzzle hud and overlay characters', () {
      const sample =
          'PIXEL PUZZLE TOGGLE CENTER + SIDES PRESS ACT TO START MOVES BEST 0123456789';
      for (final rune in sample.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          continue;
        }
        expect(
          PixelPuzzleFont.isSupported(ch),
          isTrue,
          reason: 'missing glyph: $ch',
        );
      }
    });

    test('glyph for P has both on and off pixels', () {
      final glyph = PixelPuzzleFont.glyphFor('P');
      final flat = glyph.join();
      expect(flat.contains('0'), isTrue);
      expect(flat.contains('1'), isTrue);
    });

    test('text width applies spacing correctly', () {
      expect(
        PixelPuzzleFont.textWidth('AB'),
        PixelPuzzleFont.glyphWidth * 2 + 1,
      );
      expect(PixelPuzzleFont.textWidth(''), 0);
    });
  });
}
