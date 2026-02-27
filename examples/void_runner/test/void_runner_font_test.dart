import 'package:flutter_test/flutter_test.dart';
import 'package:void_runner/src/void_runner_font.dart';

void main() {
  group('VoidRunnerFont', () {
    test('supports runner hud and overlay characters', () {
      const sample =
          'VOID RUNNER JUMP OVER OBSTACLES PRESS JUMP TO START DIST BEST SCORE RETRY 0123456789';
      for (final rune in sample.runes) {
        final ch = String.fromCharCode(rune);
        if (ch == ' ') {
          continue;
        }
        expect(
          VoidRunnerFont.isSupported(ch),
          isTrue,
          reason: 'missing glyph: $ch',
        );
      }
    });

    test('glyph for R has both on and off pixels', () {
      final glyph = VoidRunnerFont.glyphFor('R');
      final flat = glyph.join();
      expect(flat.contains('0'), isTrue);
      expect(flat.contains('1'), isTrue);
    });

    test('text width applies spacing correctly', () {
      expect(VoidRunnerFont.textWidth('AB'), VoidRunnerFont.glyphWidth * 2 + 1);
      expect(VoidRunnerFont.textWidth(''), 0);
    });
  });
}
