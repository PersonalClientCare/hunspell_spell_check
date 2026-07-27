# hunspell_spell_check

Hunspell-backed spell checking for Flutter desktop (Windows, Linux, macOS),
powered by a Rust FFI backend.

Flutter's built-in `DefaultSpellCheckService` only exists on Android and iOS.
This package brings spell checking to desktop by implementing Flutter's
standard spell check API on top of [Hunspell](https://hunspell.github.io/)
dictionaries, so it plugs into regular `TextField`s — and it also exposes a
low-level `SpellChecker` facade for custom editors (e.g. `appflowy_editor`).

## Setup

1. Add the dependency:

   ```bash
   flutter pub add hunspell_spell_check
   ```

2. Bundle Hunspell dictionary files (`.aff` + `.dic`) as assets in your app:

   ```yaml
   flutter:
     assets:
       - assets/hunspell/german/
   ```

   Dictionaries can be obtained e.g. from
   [LibreOffice dictionaries](https://github.com/LibreOffice/dictionaries).

3. A Rust toolchain is required to build the native backend (see
   `rust/rust-toolchain.toml`).

## Usage with a standard TextField

`HunspellSpellCheckConfiguration` extends Flutter's `SpellCheckConfiguration`
and wires in a `HunspellSpellCheckService` (an implementation of Flutter's
`SpellCheckService`):

```dart
import 'package:hunspell_spell_check/hunspell_spell_check.dart';

TextField(
  spellCheckConfiguration: HunspellSpellCheckConfiguration(
    options: const HunspellSpellCheckOptions(
      affPath: 'assets/hunspell/german/de_DE.aff',
      dicPath: 'assets/hunspell/german/de_DE.dic',
    ),
  ),
)
```

The service ignores the locale passed by the framework — the language is
determined by the dictionary files you configure.

You can also use `HunspellSpellCheckService` directly wherever a
`SpellCheckService` is accepted:

```dart
SpellCheckConfiguration(
  spellCheckService: HunspellSpellCheckService(
    options: const HunspellSpellCheckOptions(
      affPath: 'assets/hunspell/german/de_DE.aff',
      dicPath: 'assets/hunspell/german/de_DE.dic',
    ),
  ),
  misspelledTextStyle: TextField.materialMisspelledTextStyle,
)
```

## Low-level API

For custom editors, use the `SpellChecker` singleton directly:

```dart
await SpellChecker.instance.initialize(
  config: const HunspellSpellCheckOptions(
    affPath: 'assets/hunspell/german/de_DE.aff',
    dicPath: 'assets/hunspell/german/de_DE.dic',
  ),
);

final correct = await SpellChecker.instance.checkWord('Haus');
final suggestions = SpellChecker.instance.suggest('Hauss');
```

`HunspellSpellCheckOptions` also carries filtering rules (`minWordLength`,
`excludePatterns`, `checkOnlyCompletedWords`, `debounceDelay`) and UI hints
(`suggestionIcon`, `highlightColor`) consumed by editor integrations.

## Native backend

The engine is a small Rust cdylib (`rust/`) wrapping `hunspell-rs`, built
automatically:

- via Dart native-assets build hooks (`hook/build.dart`, using
  `native_toolchain_rust`) on Windows, Linux, and macOS, and
- via the Windows ffi-plugin CMake integration (`windows/CMakeLists.txt`),
  which compiles the crate with cargo and bundles `hunspell_backend.dll`
  next to the executable.

Words are NFC-normalized before lookup so decomposed input (e.g. macOS
dead-key umlauts) still matches dictionary entries.
