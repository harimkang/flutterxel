import 'package:flutter_test/flutter_test.dart';
import 'package:star_patrol/src/star_patrol_font.dart';

void main() {
  group('StarPatrolFont', () {
    test('supports HUD and overlay character set', () {
      const sample =
          'STAR PATROL DODGE + SHOOT PRESS FIRE TO START SCORE BEST L 0123456789';
      for (final rune in sample.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          continue;
        }
        expect(
          StarPatrolFont.isSupported(ch),
          isTrue,
          reason: 'missing glyph: $ch',
        );
      }
    });

    test('glyph for S is not a solid rectangle', () {
      final glyph = StarPatrolFont.glyphFor('S');
      final flat = glyph.join();
      expect(flat.contains('0'), isTrue);
      expect(flat.contains('1'), isTrue);
    });

    test('text width respects glyph width and spacing', () {
      expect(StarPatrolFont.textWidth('AB'), StarPatrolFont.glyphWidth * 2 + 1);
      expect(StarPatrolFont.textWidth(''), 0);
    });
  });
}
