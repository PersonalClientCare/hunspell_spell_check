// ignore_for_file: non_constant_identifier_names

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

// --- FFI Bindings (Unchanged) ---
@Native<Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>)>()
external Pointer<Void> hunspell_init(
  Pointer<Utf8> affPath,
  Pointer<Utf8> dicPath,
);

@Native<Bool Function(Pointer<Void>, Pointer<Utf8>)>()
external bool hunspell_check(Pointer<Void> handle, Pointer<Utf8> word);

@Native<Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, UintPtr)>()
external Pointer<Utf8> hunspell_suggest(
  Pointer<Void> handle,
  Pointer<Utf8> word,
  int max_suggestions,
);

@Native<Void Function(Pointer<Void>)>()
external void hunspell_free(Pointer<Void> handle);

@Native<Void Function(Pointer<Utf8>)>()
external void free_string(Pointer<Utf8> pointer);

/// Thrown when the native engine could not be brought up with a usable
/// dictionary.
class HunspellInitException implements Exception {
  HunspellInitException(this.message);

  final String message;

  @override
  String toString() => 'HunspellInitException: $message';
}

/// Converts a local file path into one Hunspell can open.
///
/// Hunspell only decodes a path as UTF-8 (`MultiByteToWideChar(CP_UTF8, ...)`
/// followed by a wide-char open) when it starts with the Windows long-path
/// prefix; otherwise it hands the raw bytes to `std::ifstream::open`, which
/// interprets them in the system ANSI codepage. Dart passes the path as UTF-8,
/// so without the prefix any non-ASCII character in it — most commonly an
/// umlaut in the Windows user name, as in `C:\Users\Mueller` spelled with an
/// actual umlaut — makes the dictionary silently fail to load. The prefix also
/// requires backslash separators and no `.`/`..` segments, hence the
/// normalization.
String hunspellPathFor(String path) {
  if (!Platform.isWindows) return path;
  const prefix = r'\\?\';
  if (path.startsWith(prefix)) return path;
  final normalized = p.windows.normalize(p.windows.absolute(path));
  // UNC shares take the `\\?\UNC\server\share` form.
  if (normalized.startsWith(r'\\')) {
    return '${prefix}UNC${normalized.substring(1)}';
  }
  return '$prefix$normalized';
}

// --- Abstraction for I/O (Decoupling for testing) ---
abstract class AbstractAssetLoader {
  Future<File> loadAsset(String assetPath, String fileName);
  Future<Directory> getWritableDirectory();
}

class AssetLoader implements AbstractAssetLoader {
  @override
  Future<File> loadAsset(String assetPath, String fileName) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, fileName));
    final data = await rootBundle.load(assetPath);

    if (!await file.exists() || await file.length() != data.lengthInBytes) {
      await file.writeAsBytes(data.buffer.asUint8List());
    }
    return file;
  }

  @override
  Future<Directory> getWritableDirectory() async {
    return await getApplicationSupportDirectory();
  }
}

// --- Service Class (Accepts dependency) ---
class HunspellService {
  final AbstractAssetLoader _loader;
  final String affPath;
  final String dicPath;

  Pointer<Void>? _engineHandle;

  HunspellService(
    this._loader, {
    required this.affPath,
    required this.dicPath,
  });

  /// Init spell checker. Extracts assets, initializes Rust backend.
  ///
  /// Throws a [HunspellInitException] if the native engine came up without a
  /// usable dictionary. Hunspell treats an unreadable dictionary file as an
  /// *empty* dictionary rather than as an error, which would otherwise surface
  /// as every word being misspelled with no suggestions offered.
  Future<void> initialize() async {
    // 1. Load paths via abstract loader
    final affFile = await _loader.loadAsset(affPath, p.basename(affPath));
    final dicFile = await _loader.loadAsset(dicPath, p.basename(dicPath));

    // 2. Words to verify the load with (see [_readProbeWords])
    final probeWords = await _readProbeWords(dicFile);

    // 3. Try the path spellings Hunspell might accept, most correct first.
    // The prefixed form is the one that handles non-ASCII paths, but it goes
    // through a different code path inside Hunspell, so fall back to the plain
    // path rather than risk regressing the (ASCII) case that already worked.
    final candidates = {
      (hunspellPathFor(affFile.path), hunspellPathFor(dicFile.path)),
      (affFile.path, dicFile.path),
    };

    for (final (aff, dic) in candidates) {
      final handle = _initEngine(aff, dic);
      if (handle == nullptr) continue;
      _engineHandle = handle;

      // A dictionary we couldn't parse for probe words can't be verified;
      // accept the handle as-is.
      if (probeWords.isEmpty || probeWords.any(checkWord)) return;

      // Loaded as an empty dictionary — this spelling of the path didn't work.
      dispose();
    }

    throw HunspellInitException(
      'Could not load the dictionary at ${dicFile.path} (aff: '
      '${affFile.path}). The files exist but Hunspell reads them as an empty '
      'dictionary: none of their own entries ($probeWords) are recognized. '
      'Tried: ${candidates.map((c) => c.$2).join(", ")}.',
    );
  }

  Pointer<Void> _initEngine(String affFilePath, String dicFilePath) {
    final affPtr = affFilePath.toNativeUtf8();
    final dicPtr = dicFilePath.toNativeUtf8();
    try {
      return hunspell_init(affPtr, dicPtr);
    } finally {
      malloc.free(affPtr);
      malloc.free(dicPtr);
    }
  }

  /// Reads a few plain-ASCII entries out of the `.dic` file to probe with.
  ///
  /// Probing with the dictionary's own words keeps the check language
  /// agnostic. The file's encoding is declared in the `.aff` and is often not
  /// UTF-8, so only ASCII-only entries are considered and the bytes are
  /// decoded as latin1, which never throws.
  Future<List<String>> _readProbeWords(File dicFile, {int count = 3}) async {
    try {
      final lines = latin1.decode(await dicFile.readAsBytes()).split('\n');
      final words = <String>[];
      // The first line holds the entry count, not a word.
      for (final line in lines.skip(1)) {
        final word = line.split(_entrySeparator).first;
        if (_asciiWord.hasMatch(word)) {
          words.add(word);
          if (words.length == count) break;
        }
      }
      return words;
    } catch (_) {
      // A dictionary we can't parse here is no evidence of a broken engine.
      return const [];
    }
  }

  /// Splits a `.dic` entry off its affix flags and morphological fields.
  static final RegExp _entrySeparator = RegExp(r'[/\s]');
  static final RegExp _asciiWord = RegExp(r'^[A-Za-z]{4,}$');

  /// Check word correctness.
  bool checkWord(String word) {
    if (_engineHandle == null) throw Exception("Hunspell not initialized.");
    final wordPtr = word.toNativeUtf8();
    try {
      final isCorrect = hunspell_check(_engineHandle!, wordPtr);
      return isCorrect;
    } finally {
      malloc.free(wordPtr);
    }
  }

  /// Get suggestions for misspelled word.
  List<String> getSuggestions(
    String word, {
    int maxSuggestions = 255,
  }) {
    if (_engineHandle == null) throw Exception("Hunspell not initialized.");
    final wordPtr = word.toNativeUtf8();

    Pointer<Utf8>? resultPtr;

    try {
      resultPtr = hunspell_suggest(
        _engineHandle!,
        wordPtr,
        maxSuggestions,
      );
      final resultString = resultPtr.toDartString();

      if (resultString.isEmpty) return [];
      return resultString.split(',');
    } finally {
      malloc.free(wordPtr);
      if (resultPtr != null) free_string(resultPtr);
    }
  }

  /// Clean up native resources.
  void dispose() {
    if (_engineHandle != null) {
      hunspell_free(_engineHandle!);
      _engineHandle = null;
    }
  }
}
