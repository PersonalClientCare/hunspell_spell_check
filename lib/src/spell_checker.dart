import 'dart:async';

import 'package:logging/logging.dart';

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
  Future<void> initialize({
    required HunspellSpellCheckOptions config,
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
  Future<bool> checkWord(String word) async {
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

    // 3. Delegate to Hunspell Service
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

    // Since Hunspell suggestions are only for misspelled words,
    // we first check if it's correct. If it is, we return empty list.
    if (_engine.checkWord(word)) {
      return [];
    }

    // Delegate to Hunspell Service
    return _engine.getSuggestions(word, maxSuggestions: maxSuggestions);
  }

  /// Cleans up native resources and stops the service.
  void dispose() {
    _engine.dispose();
    _isInitialized = false;
  }
}
