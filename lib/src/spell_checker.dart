import 'dart:async';

import 'package:logging/logging.dart';

import 'custom_dictionary.dart';
import 'hunspell_service.dart';
import 'spell_check_options.dart';

final Logger _log = Logger('hunspell_spell_check');

/// Final facade for the spell checking system.
/// This class orchestrates the configuration, manages the native Hunspell engine,
/// and applies business logic before querying the spell checker.
class SpellChecker {
  // The underlying engine implementation
  late HunspellService _engine;
  late HunspellSpellCheckOptions _config;
  late CustomDictionary _customDictionary;

  static final SpellChecker _instance = SpellChecker._internal();
  static SpellChecker get instance => _instance;

  // Private constructor enforces singleton pattern
  SpellChecker._internal();

  // State management
  bool _isInitialized = false;
  bool _initializing = false;

  /// Whether the native engine has been initialized successfully.
  bool get isInitialized => _isInitialized;

  /// Initializes the native spell checker engine by extracting assets.
  /// Must be called before any checking operations.
  ///
  /// [customDictionaryStore] controls where words added via [addCustomWord]
  /// are persisted. Defaults to [FileCustomDictionaryStore].
  Future<void> initialize({
    required HunspellSpellCheckOptions config,
    CustomDictionaryStore? customDictionaryStore,
  }) async {
    if (_isInitialized || _initializing) return;
    _initializing = true;
    try {
      _config = config;
      _engine = HunspellService(
        AssetLoader(),
        affPath: _config.affPath,
        dicPath: _config.dicPath,
      );
      await _engine.initialize();
      _customDictionary = CustomDictionary(
        store: customDictionaryStore,
        seedWords: _config.customWords,
      );
      await _customDictionary.initialize();
      _isInitialized = true;
    } catch (ex) {
      _log.severe("Failed to init spell check service: $ex");
    } finally {
      _initializing = false;
    }
  }

  /// Checks a word against the dictionary, applying configuration rules.
  ///
  /// This method implements the high-level business logic (e.g., minimum word length,
  /// exclusion patterns, and completed word checks).
  ///
  /// @param word The word to check.
  /// @return True if the word is correct or excluded by configuration, false otherwise.
  bool checkWord(String word) {
    if (!_isInitialized) {
      throw StateError(
        "SpellChecker must be initialized before checking words.",
      );
    }

    // 1. Configuration Check: Minimum word length
    if (word.length < _config.minWordLength) {
      return true; // Treat as correct/non-checkable if too short
    }

    // 2. Configuration Check: Exclusion Patterns (Regex)
    for (final regex in _config.excludePatterns) {
      if (regex.hasMatch(word)) {
        return true; // Excluded, so treat as correct
      }
    }

    // 3. Custom Dictionary Check: words the user marked as correct
    if (_customDictionary.contains(word)) {
      return true;
    }

    // 4. Delegate to Hunspell Service
    try {
      final checkResult = _engine.checkWord(word);
      return checkResult;
    } catch (e) {
      _log.severe("Failed hunspell check for word: $word with $e");
      // Log or handle engine failure gracefully
      return false; // Default to misspelled on engine failure
    }
  }

  /// Suggests corrections for a misspelled word, applying configuration filters.
  ///
  /// @param word The misspelled word.
  /// @return A list of suggested correct spellings.
  List<String> suggest(
    String word, {
    int maxSuggestions = 5,
  }) {
    if (!_isInitialized) {
      throw StateError(
        "SpellChecker must be initialized before suggesting words.",
      );
    }

    // Apply configuration checks before suggesting (e.g., if word is too short, no suggestions are needed)
    if (word.length < _config.minWordLength) {
      return [];
    }

    // A word the user has already marked as correct needs no suggestions.
    if (_customDictionary.contains(word)) {
      return [];
    }

    // Since Hunspell suggestions are only for misspelled words,
    // we first check if it's correct. If it is, we return empty list.
    if (_engine.checkWord(word)) {
      return [];
    }

    // Delegate to Hunspell Service
    return _engine.getSuggestions(word, maxSuggestions: maxSuggestions);
  }

  /// Words the user has marked as correct, so they're ignored by future
  /// spell checks.
  Set<String> get customWords {
    if (!_isInitialized) {
      throw StateError(
        "SpellChecker must be initialized before reading custom words.",
      );
    }
    return _customDictionary.words;
  }

  /// Marks [word] as correct so future checks and suggestions ignore it.
  /// Persisted via the configured [CustomDictionaryStore].
  ///
  /// Takes effect immediately for subsequent [checkWord]/[suggest] calls.
  /// If [word] is currently underlined in a live [TextField], Flutter won't
  /// clear that underline on its own since it only rechecks spelling when
  /// the text changes — call `HunspellSpellCheckService.refreshSpellCheck`
  /// (from `flutter_spell_check.dart`) right after this to force it.
  Future<void> addCustomWord(String word) async {
    if (!_isInitialized) {
      throw StateError(
        "SpellChecker must be initialized before adding custom words.",
      );
    }
    await _customDictionary.add(word);
  }

  /// Removes [word] from the custom dictionary, so it will be flagged
  /// again by future spell checks.
  Future<void> removeCustomWord(String word) async {
    if (!_isInitialized) {
      throw StateError(
        "SpellChecker must be initialized before removing custom words.",
      );
    }
    await _customDictionary.remove(word);
  }

  /// Cleans up native resources and stops the service.
  void dispose() {
    _engine.dispose();
    _isInitialized = false;
  }
}
