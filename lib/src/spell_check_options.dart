/// Configuration for spell checking behavior
class HunspellSpellCheckOptions {
  const HunspellSpellCheckOptions({
    this.minWordLength = 3,
    this.checkOnlyCompletedWords = true,
    this.debounceDelay = Duration.zero,
    this.excludePatterns = const [],
    this.customWords = const {},
    required this.affPath,
    required this.dicPath,
  });

  /// Minimum word length to check for spelling errors.
  /// Words shorter than this will not be spell-checked.
  /// Default: 3 characters
  final int minWordLength;

  /// If true, only check words after whitespace/punctuation (completed words).
  /// If false, check words as you type (immediate feedback).
  ///
  /// Example:
  /// - true: "bas|" -> no redline, "bas " -> show redline
  /// - false: "bas|" -> show redline immediately
  ///
  /// Default: false (immediate checking)
  final bool checkOnlyCompletedWords;

  /// Delay before showing spell check underline.
  /// Useful to avoid flickering while typing.
  ///
  /// Example: Duration(milliseconds: 300) waits 300ms before showing redline
  /// Default: Duration.zero (immediate)
  final Duration debounceDelay;

  /// List of regex patterns to exclude from spell checking.
  ///
  /// Example:
  /// - RegExp(r'^#\w+') excludes hashtags (#flutter)
  /// - RegExp(r'@\w+') excludes mentions (@username)
  /// - RegExp(r'\d+') excludes numbers
  final List<RegExp> excludePatterns;

  /// Words to seed the custom dictionary with on initialization, in addition
  /// to any previously persisted via [SpellChecker.addCustomWord].
  final Set<String> customWords;

  /// Necessary hunspell file paths
  final String affPath;
  final String dicPath;

  HunspellSpellCheckOptions copyWith({
    int? minWordLength,
    bool? checkOnlyCompletedWords,
    Duration? debounceDelay,
    List<RegExp>? excludePatterns,
    Set<String>? customWords,
    String? affPath,
    String? dicPath,
  }) {
    return HunspellSpellCheckOptions(
      minWordLength: minWordLength ?? this.minWordLength,
      checkOnlyCompletedWords:
          checkOnlyCompletedWords ?? this.checkOnlyCompletedWords,
      debounceDelay: debounceDelay ?? this.debounceDelay,
      excludePatterns: excludePatterns ?? this.excludePatterns,
      customWords: customWords ?? this.customWords,
      affPath: affPath ?? this.affPath,
      dicPath: dicPath ?? this.dicPath,
    );
  }
}
