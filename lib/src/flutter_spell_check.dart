import 'dart:async';
import 'package:flutter/services.dart' show SpellCheckService, SuggestionSpan;
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

  // In-memory caches to make repetitive word checking O(1). Bounded (see
  // [_maxCacheEntries]) so long-running sessions over large documents don't
  // grow these unboundedly.
  final Map<String, bool> _validityCache = {};
  final Map<String, List<String>> _suggestionCache = {};

  static const int _maxCacheEntries = 5000;

  // hunspell_check/hunspell_suggest are synchronous FFI calls, so awaiting
  // them concurrently would only interleave microtasks on the same thread,
  // not run in parallel. Instead we yield to the event loop periodically so
  // a long block of text doesn't hold the UI thread for one uninterrupted
  // synchronous burst. hunspell_suggest (edit-distance search) is far more
  // expensive than hunspell_check (dictionary lookup), so it gets its own,
  // much tighter, yield threshold.
  static const int _checkYieldBatchSize = 100;
  static const int _suggestYieldBatchSize = 3;

  static final RegExp _wordReg = RegExp(
    r'[\p{L}\p{M}\p{N}_]+',
    unicode: true,
  );

  void _capCache<V>(Map<String, V> cache) {
    if (cache.length <= _maxCacheEntries) return;
    cache.remove(cache.keys.first);
  }

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    // 1. Ensure initialization happens once without blocking hot path execution unnecessarily
    if (!SpellChecker.instance.isInitialized) {
      await SpellChecker.instance.initialize(config: options);
      if (!SpellChecker.instance.isInitialized) return null;
    }

    final spans = <SuggestionSpan>[];
    final matches = _wordReg.allMatches(text);

    var checksSinceYield = 0;
    var suggestionsSinceYield = 0;
    for (final match in matches) {
      final word = match.group(0)!;

      // Skip completed word check if user is still typing at the end of text
      if (options.checkOnlyCompletedWords && match.end == text.length) {
        continue;
      }

      // The word regex excludes punctuation, so an abbreviation like "bzw."
      // is matched as bare "bzw" — but dictionaries store such abbreviations
      // with their trailing period, so the bare token never matches. Cache
      // this separately from the bare word (rather than under `word`) so a
      // mid-sentence occurrence without a period isn't wrongly considered
      // correct just because the abbreviated form was seen elsewhere.
      final hasTrailingDot =
          match.end < text.length && text[match.end] == '.';
      final cacheKey = hasTrailingDot ? '$word.' : word;

      // 2. Fast cache lookup for word validity
      bool? isCorrect = _validityCache[cacheKey];
      if (isCorrect == null) {
        isCorrect = SpellChecker.instance.checkWord(word);
        if (!isCorrect && hasTrailingDot) {
          isCorrect = SpellChecker.instance.checkWord('$word.');
        }
        _validityCache[cacheKey] = isCorrect;
        _capCache(_validityCache);

        // Cheap dictionary lookup: only yield every so often.
        if (++checksSinceYield >= _checkYieldBatchSize) {
          checksSinceYield = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }

      if (isCorrect) continue;

      // 3. Fast cache lookup for Hunspell suggestions
      List<String>? suggestions = _suggestionCache[cacheKey];
      if (suggestions == null) {
        suggestions = SpellChecker.instance.suggest(
          word,
          maxSuggestions: maxSuggestions,
        );
        _suggestionCache[cacheKey] = suggestions;
        _capCache(_suggestionCache);

        // Expensive edit-distance search: yield much more often so a run of
        // new misspelled words can't block the UI thread for long.
        if (++suggestionsSinceYield >= _suggestYieldBatchSize) {
          suggestionsSinceYield = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }

      spans.add(
        SuggestionSpan(
          TextRange(start: match.start, end: match.end),
          suggestions,
        ),
      );
    }

    return spans;
  }

  /// Clears in-memory caches when custom words are added or dictionaries switch.
  void clearCache() {
    _validityCache.clear();
    _suggestionCache.clear();
  }

  static void refreshSpellCheck(
    TextEditingController controller, {
    HunspellSpellCheckService? serviceInstance,
  }) {
    // Clear caches so updated word rules take effect immediately
    serviceInstance?.clearCache();

    final TextEditingValue original = controller.value;
    controller.value = original.copyWith(text: '${original.text} ');
    controller.value = original;
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
