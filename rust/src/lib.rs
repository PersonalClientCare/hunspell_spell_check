use hunspell_rs::{CheckResult, Hunspell};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::ptr;
use unicode_normalization::UnicodeNormalization;

/// Borrows the engine behind `handle`, or returns `None` if the handle is null.
///
/// The Dart side treats a null handle as a failed init, but a caller that
/// missed that would otherwise dereference null here.
unsafe fn engine<'a>(handle: *mut c_void) -> Option<&'a Hunspell> {
    if handle.is_null() {
        return None;
    }
    Some(unsafe { &*(handle as *mut Hunspell) })
}

/// Reads a UTF-8 path argument, or returns `None` if it is null or not UTF-8.
unsafe fn path_arg<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(ptr) }.to_str().ok()
}

/// Initializes the Hunspell engine and returns a pointer to it.
///
/// Returns null if either path is null or not valid UTF-8. Note that Hunspell
/// itself reports a dictionary it cannot read as an empty one rather than as
/// an error, so a non-null return does not by itself mean the dictionary
/// loaded; the Dart side probes for that.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_init(aff_path: *const c_char, dic_path: *const c_char) -> *mut c_void {
    let (Some(aff), Some(dic)) = (unsafe { path_arg(aff_path) }, unsafe { path_arg(dic_path) })
    else {
        return ptr::null_mut();
    };

    let hunspell = Box::new(Hunspell::new(aff, dic));
    Box::into_raw(hunspell) as *mut c_void
}

/// Checks if a word is spelled correctly.
#[unsafe(no_mangle)]
pub extern "C" fn hunspell_check(handle: *mut c_void, word: *const c_char) -> bool {
    let Some(hunspell) = (unsafe { engine(handle) }) else {
        return false;
    };
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
    let empty = || CString::new("").unwrap().into_raw();

    let Some(hunspell) = (unsafe { engine(handle) }) else {
        return empty();
    };
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
