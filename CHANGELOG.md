# 0.3.3

- Bumps Flutter SDK to min 3.44
- Upgrade dependencies

# 0.3.2

- Fix the dictionary silently failing to load on Windows when the path to it contains non-ASCII characters (most commonly an umlaut in the user name, since the dictionaries are extracted into the application support directory). Hunspell only decodes a path as UTF-8 when it carries the `\\?\` long-path prefix and otherwise reads it in the system ANSI codepage, so paths handed to the native engine now get that prefix, falling back to the plain path if the prefixed one doesn't load.
- `HunspellService.initialize` now throws a `HunspellInitException` when the engine comes up without a usable dictionary, instead of leaving a silently empty one behind. Hunspell reports an unreadable dictionary as an empty dictionary, which used to surface as every word being underlined with no suggestions offered.
- Guard the native entry points against a null engine handle rather than dereferencing it, and return null from `hunspell_init` for unusable path arguments.

# 0.3.1

- Update rust toolchain to 1.97.0

# 0.3.0

- `HunspellSpellCheckService.fetchSpellCheckSuggestions` now yields to the event loop periodically instead of checking an entire text in one synchronous burst, avoiding UI hangs on large documents. `suggest` calls (the more expensive Hunspell operation) yield more aggressively than `checkWord` calls.
- Bound the in-memory validity/suggestion caches so long-running sessions over large documents don't grow them unboundedly.
- Fix abbreviations followed by a period (e.g. `bzw.`) being flagged as misspelled: the word is now also checked with its trailing period attached before falling back to reporting it as incorrect.

# 0.2.2

- Add `HunspellSpellCheckService.refreshSpellCheck` to force Flutter's TextField to recheck spelling immediately after adding a custom word.

# 0.2.1

- Add `CustomDictionaryStore` support for custom word persistence.

# 0.1.0

- Initial release, extracted from the `appflowy_editor` fork.
- Hunspell FFI bindings (`HunspellService`) with a Rust backend.
- `SpellChecker` singleton facade with word-length / exclude-pattern rules.
- `HunspellSpellCheckService` implementing Flutter's `SpellCheckService`.
- `HunspellSpellCheckConfiguration` extending Flutter's
  `SpellCheckConfiguration` for use with standard `TextField`s.
