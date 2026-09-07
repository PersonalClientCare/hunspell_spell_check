import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hunspell_spell_check/hunspell_spell_check.dart';

void main() {
  group('hunspellPathFor', () {
    test('leaves paths untouched off Windows', () {
      expect(hunspellPathFor('/tmp/de_DE.dic'), '/tmp/de_DE.dic');
    }, skip: Platform.isWindows);

    group('on Windows', () {
      test('prefixes a local path so Hunspell decodes it as UTF-8', () {
        expect(
          hunspellPathFor(r'C:\Users\Mueller\AppData\Roaming\de_DE.dic'),
          r'\\?\C:\Users\Mueller\AppData\Roaming\de_DE.dic',
        );
      });

      test('normalizes separators and dot segments', () {
        expect(
          hunspellPathFor('C:/Users/x/./sub/../de_DE.dic'),
          r'\\?\C:\Users\x\de_DE.dic',
        );
      });

      test('keeps a path that already carries the prefix', () {
        expect(hunspellPathFor(r'\\?\C:\x\de_DE.dic'), r'\\?\C:\x\de_DE.dic');
      });

      test('uses the UNC form for network shares', () {
        expect(
          hunspellPathFor(r'\\server\share\de_DE.dic'),
          r'\\?\UNC\server\share\de_DE.dic',
        );
      });
    }, skip: !Platform.isWindows);
  });
}
