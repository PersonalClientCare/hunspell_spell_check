import 'dart:async';

import 'package:flutter/services.dart'
    show SpellCheckService, SuggestionSpan;
import 'package:flutter/widgets.dart';

import 'spell_check_options.dart';
import 'spell_checker.dart';

/// A [SpellCheckService] backed by the native Hunspell engine.
///
/// Drop-in replacement for the platform-provided [DefaultSpellCheckService],
/// which is only available on Android and iOS. This service works on desktop
/// (Windows, Linux, macOS) as well.
///
/// The [locale] passed to [fetchSpellCheckSuggestions] is ignored; the
/// language is determined by the dictionary files configured via
/// [HunspellSpellCheckOptions.affPath] and [HunspellSpellCheckOptions.dicPath].
class HunspellSpellCheckService implements SpellCheckService {
  HunspellSpellCheckService({
    required this.options,
    this.maxSuggestions = 5,
  });

  /// Dictionary paths and word-filtering rules for the underlying engine.
  final HunspellSpellCheckOptions options;

  /// Maximum number of suggestions returned per misspelled word.
  final int maxSuggestions;

  // Word/non-word tokenization, unicode-aware so non-ASCII letters
  // (ü, ß, é, ...) and combining marks stay part of the word token.
  static final RegExp _wordReg = RegExp(
    r'[\p{L}\p{M}\p{N}_]+',
    unicode: true,
  );

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    await SpellChecker.instance.initialize(config: options);
    if (!SpellChecker.instance.isInitialized) {
      // Engine failed to initialize; report spell check as unavailable.
      return null;
    }

    final spans = <SuggestionSpan>[];
    for (final match in _wordReg.allMatches(text)) {
      final word = match.group(0)!;

      // Skip the word still being typed at the end of the text.
      if (options.checkOnlyCompletedWords && match.end == text.length) {
        continue;
      }

      final isCorrect = await SpellChecker.instance.checkWord(word);
      if (isCorrect) continue;

      spans.add(
        SuggestionSpan(
          TextRange(start: match.start, end: match.end),
          SpellChecker.instance.suggest(word, maxSuggestions: maxSuggestions),
        ),
      );
    }
    return spans;
  }
}

/// A [SpellCheckConfiguration] wired to the Hunspell engine, for use with
/// standard Flutter text fields:
///
/// ```dart
/// TextField(
///   spellCheckConfiguration: HunspellSpellCheckConfiguration(
///     options: HunspellSpellCheckOptions(
///       affPath: 'assets/hunspell/de_DE.aff',
///       dicPath: 'assets/hunspell/de_DE.dic',
///     ),
///   ),
/// )
/// ```
///
/// [TextField] and [CupertinoTextField] fill in a platform-default
/// [SpellCheckConfiguration.misspelledTextStyle] when none is given. When
/// passing this configuration directly to [EditableText], set
/// [misspelledTextStyle] explicitly — EditableText requires it.
class HunspellSpellCheckConfiguration extends SpellCheckConfiguration {
  HunspellSpellCheckConfiguration({
    required HunspellSpellCheckOptions options,
    int maxSuggestions = 5,
    super.misspelledSelectionColor,
    super.misspelledTextStyle,
    super.spellCheckSuggestionsToolbarBuilder,
  }) : super(
          spellCheckService: HunspellSpellCheckService(
            options: options,
            maxSuggestions: maxSuggestions,
          ),
        );
}
