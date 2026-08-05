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
