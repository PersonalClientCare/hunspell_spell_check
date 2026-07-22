// ignore_for_file: non_constant_identifier_names

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

// --- Abstraction for I/O (Decoupling for testing) ---
abstract class AbstractAssetLoader {
  Future<File> loadAsset(String assetPath, String fileName);
  Future<Directory> getWritableDirectory();
}

class AssetLoader implements AbstractAssetLoader {
  @override
  Future<File> loadAsset(String assetPath, String fileName) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$fileName');

    if (!await file.exists()) {
      final data = await rootBundle.load(assetPath);
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
  final AssetLoader _loader;
  final String affPath;
  final String dicPath;

  Pointer<Void>? _engineHandle;

  HunspellService(
    this._loader, {
    required this.affPath,
    required this.dicPath,
  });

  /// Init spell checker. Extracts assets, initializes Rust backend.
  Future<void> initialize() async {
    // 1. Load paths via abstract loader
    final affFile = await _loader.loadAsset(affPath, p.basename(affPath));
    final dicFile = await _loader.loadAsset(dicPath, p.basename(dicPath));

    // 2. Pass paths to Rust
    final affPtr = affFile.path.toNativeUtf8();
    final dicPtr = dicFile.path.toNativeUtf8();

    // Initialize engine
    _engineHandle = hunspell_init(affPtr, dicPtr);

    // Free path memory
    malloc.free(affPtr);
    malloc.free(dicPtr);
  }

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
