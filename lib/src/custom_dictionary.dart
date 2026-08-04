import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persistence backend for words the user has chosen to ignore.
///
/// Implement this to plug in your own storage (e.g. a database or
/// shared_preferences) instead of the default file-based
/// [FileCustomDictionaryStore].
abstract class CustomDictionaryStore {
  /// Loads previously saved custom words.
  Future<Set<String>> load();

  /// Persists the full set of custom words, replacing any previous contents.
  Future<void> save(Set<String> words);
}

/// Default [CustomDictionaryStore] that persists words as newline-separated
/// text in the app's writable support directory.
class FileCustomDictionaryStore implements CustomDictionaryStore {
  FileCustomDictionaryStore({this.fileName = 'custom_dictionary.txt'});

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$fileName');
  }

  @override
  Future<Set<String>> load() async {
    final file = await _file();
    if (!await file.exists()) return {};
    final contents = await file.readAsString();
    return contents
        .split('\n')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> save(Set<String> words) async {
    final file = await _file();
    await file.writeAsString(words.join('\n'));
  }
}

/// Tracks misspellings the user has explicitly marked as correct, so future
/// spell checks treat them as valid words instead of flagging them again.
///
/// Backed by a [CustomDictionaryStore] for persistence across app restarts.
class CustomDictionary {
  CustomDictionary({
    CustomDictionaryStore? store,
    Set<String> seedWords = const {},
  }) : _store = store ?? FileCustomDictionaryStore(),
       _seedWords = seedWords;

  final CustomDictionaryStore _store;
  final Set<String> _seedWords;
  final Set<String> _words = {};

  /// Words currently ignored by the spell checker.
  Set<String> get words => Set.unmodifiable(_words);

  /// Loads persisted words and merges in any configured seed words.
  Future<void> initialize() async {
    final persisted = await _store.load();
    _words
      ..clear()
      ..addAll(_seedWords)
      ..addAll(persisted);
  }

  /// Whether [word] has been marked as correct and should be ignored.
  bool contains(String word) => _words.contains(word.toLowerCase());

  /// Adds [word] to the custom dictionary and persists the change.
  Future<void> add(String word) async {
    if (_words.add(word.toLowerCase())) {
      await _store.save(_words);
    }
  }

  /// Removes [word] from the custom dictionary and persists the change.
  Future<void> remove(String word) async {
    if (_words.remove(word.toLowerCase())) {
      await _store.save(_words);
    }
  }
}
