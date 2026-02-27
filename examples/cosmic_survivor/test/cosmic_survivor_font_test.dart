import 'package:cosmic_survivor/src/cosmic_survivor_font.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CosmicSurvivorFont', () {
    test('supports hud and overlay character set', () {
      const sample =
          'COSMIC SURVIVOR MOVE FIRE SURVIVE PRESS FIRE TO START MISSION FAILED SCORE BEST L 0123456789';
      for (final rune in sample.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          continue;
        }
        expect(
          CosmicSurvivorFont.isSupported(ch),
          isTrue,
          reason: 'missing glyph: $ch',
        );
      }
    });

    test('glyph for C has both on and off pixels', () {
      final glyph = CosmicSurvivorFont.glyphFor('C');
      final flat = glyph.join();
      expect(flat.contains('0'), isTrue);
      expect(flat.contains('1'), isTrue);
    });

    test('text width applies spacing correctly', () {
      expect(
        CosmicSurvivorFont.textWidth('AB'),
        CosmicSurvivorFont.glyphWidth * 2 + 1,
      );
      expect(CosmicSurvivorFont.textWidth(''), 0);
    });
  });
}
