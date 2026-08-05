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
