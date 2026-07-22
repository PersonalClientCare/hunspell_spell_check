use hunspell_rs::{CheckResult, Hunspell};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use unicode_normalization::UnicodeNormalization;

/// Initializes the Hunspell engine and returns a pointer to it.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_init(aff_path: *const c_char, dic_path: *const c_char) -> *mut c_void {
    let aff = unsafe { CStr::from_ptr(aff_path) }.to_str().unwrap();
    let dic = unsafe { CStr::from_ptr(dic_path) }.to_str().unwrap();

    let hunspell = Box::new(Hunspell::new(aff, dic));
    Box::into_raw(hunspell) as *mut c_void
}

/// Checks if a word is spelled correctly.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_check(handle: *mut c_void, word: *const c_char) -> bool {
    let hunspell = unsafe { &*(handle as *mut Hunspell) };
    let w = unsafe { CStr::from_ptr(word) }.to_str().unwrap();
    // Dictionaries store precomposed (NFC) text; normalize so decomposed
    // input (e.g. macOS dead-key umlauts) still matches.
    let w: String = w.nfc().collect();
    let res = hunspell.check(&w);
    res == CheckResult::FoundInDictionary
}

/// Returns a comma-separated string of suggestions for a misspelled word.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_suggest(
    handle: *mut c_void,
    word: *const c_char,
    max_suggestions: usize,
) -> *mut c_char {
    let hunspell = unsafe { &*(handle as *mut Hunspell) };
    let w = unsafe { CStr::from_ptr(word) }.to_str().unwrap();
    let w: String = w.nfc().collect();

    let suggestions = hunspell.suggest(&w);
    let result = suggestions
        .into_iter()
        .take(max_suggestions)
        .collect::<Vec<String>>()
        .join(",");

    CString::new(result)
        .unwrap_or_else(|_| CString::new("").unwrap())
        .into_raw()
}

/// Frees the Hunspell instance from memory when the app closes.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_free(handle: *mut c_void) {
    if !handle.is_null() {
        unsafe {
            let _ = Box::from_raw(handle as *mut Hunspell);
        }
    }
}

/// Frees a string allocated by Rust.
#[unsafe(no_mangle)]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe {
            let _ = CString::from_raw(s);
        }
    }
}
