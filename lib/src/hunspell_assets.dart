import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
