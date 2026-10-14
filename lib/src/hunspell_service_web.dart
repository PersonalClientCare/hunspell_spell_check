import 'hunspell_assets.dart';

export 'hunspell_assets.dart';

/// Web counterpart of the native [HunspellService].
///
/// The browser can't load the native Hunspell library, so initialization
/// always fails and [SpellChecker] stays uninitialized, which leaves spell
/// checking off instead of breaking the text fields.
class HunspellService {
  HunspellService(
    AbstractAssetLoader loader, {
    required this.affPath,
    required this.dicPath,
  });

  final String affPath;
  final String dicPath;

  Future<void> initialize() async {
    throw HunspellInitException('Hunspell is not available on the web.');
  }

  bool checkWord(String word) =>
      throw StateError('Hunspell is not available on the web.');

  List<String> getSuggestions(String word, {int maxSuggestions = 255}) =>
      throw StateError('Hunspell is not available on the web.');

  void dispose() {}
}
