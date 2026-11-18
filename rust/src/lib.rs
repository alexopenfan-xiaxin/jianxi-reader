use serde::{Deserialize, Serialize};
use std::alloc::{alloc, dealloc, Layout};
use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;
use std::str;
use std::sync::{OnceLock, RwLock};

const CJK_START: u32 = 0x4E00;
const CJK_END: u32 = 0x9FFF;
const CJK_EXT_A_START: u32 = 0x3400;
const CJK_EXT_A_END: u32 = 0x4DBF;

#[derive(Clone, Debug, Deserialize, Serialize)]
struct IndexedDocument {
    #[serde(default)]
    id: String,
    path: String,
    #[serde(default)]
    title: String,
    #[serde(default)]
    size: u64,
    #[serde(rename = "updatedAt", default)]
    updated_at: i64,
    #[serde(default)]
    length: u64,
    #[serde(default)]
    tokens: HashMap<String, u64>,
}

#[derive(Default)]
struct SearchIndex {
    documents: Vec<IndexedDocument>,
}

#[derive(Deserialize)]
struct IndexPayload {
    #[serde(default)]
    documents: Vec<IndexedDocument>,
}

#[derive(Serialize)]
struct SearchHit {
    path: String,
    score: u64,
}

static INDEX: OnceLock<RwLock<SearchIndex>> = OnceLock::new();

fn index() -> &'static RwLock<SearchIndex> {
    INDEX.get_or_init(|| RwLock::new(SearchIndex::default()))
}

fn is_cjk(rune: u32) -> bool {
    (CJK_START..=CJK_END).contains(&rune)
        || (CJK_EXT_A_START..=CJK_EXT_A_END).contains(&rune)
}

fn is_ascii_word(rune: u32) -> bool {
    matches!(rune, 0x30..=0x39 | 0x41..=0x5A | 0x61..=0x7A)
}

fn tokenize(text: &str) -> Vec<String> {
    let runes: Vec<char> = text.chars().collect();
    let mut tokens = Vec::new();
    let mut index = 0;

    while index < runes.len() {
        let rune = runes[index] as u32;
        if is_cjk(rune) {
            let mut end = index;
            while end < runes.len() && is_cjk(runes[end] as u32) {
                end += 1;
            }
            for position in index..end.saturating_sub(1) {
                tokens.push(runes[position..position + 2].iter().copied().collect());
            }
            index = end;
        } else if is_ascii_word(rune) {
            let mut end = index + 1;
            while end < runes.len() && is_ascii_word(runes[end] as u32) {
                end += 1;
            }
            tokens.push(
                runes[index..end]
                    .iter()
                    .copied()
                    .collect::<String>()
                    .to_ascii_lowercase(),
            );
            index = end;
        } else {
            index += 1;
        }
    }
    tokens
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_tokenize(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
) -> isize {
    catch_unwind(AssertUnwindSafe(|| {
        let text = read_utf8(input, input_length)?;
        let json = serde_json::to_vec(&tokenize(text)).map_err(|error| error.to_string())?;
        Ok::<isize, String>(write_result(output, output_capacity, &json))
    }))
    .ok()
    .and_then(Result::ok)
    .unwrap_or(-1)
}

fn count_tokens(text: &str) -> HashMap<String, u64> {
    let mut counts = HashMap::new();
    for token in tokenize(text) {
        *counts.entry(token).or_insert(0) += 1;
    }
    counts
}

fn search(query: &str) -> Vec<SearchHit> {
    let mut tokens = Vec::new();
    for token in tokenize(query.trim()) {
        if !tokens.contains(&token) {
            tokens.push(token);
        }
    }
    if tokens.is_empty() {
        return Vec::new();
    }

    let guard = index().read().unwrap_or_else(|poisoned| poisoned.into_inner());
    let mut hits = Vec::new();
    for document in &guard.documents {
        let mut score = 0_u64;
        let mut matches_all = true;
        for token in &tokens {
            let count = document.tokens.get(token).copied().unwrap_or(0);
            if count == 0 {
                matches_all = false;
                break;
            }
            score = score.saturating_add(count.saturating_mul(if token.len() > 1 { 2 } else { 1 }));
        }
        if matches_all {
            hits.push(SearchHit { path: document.path.clone(), score });
        }
    }
    hits.sort_by(|left, right| right.score.cmp(&left.score));
    hits
}

unsafe fn read_utf8<'a>(input: *const u8, length: usize) -> Result<&'a str, String> {
    if input.is_null() && length != 0 {
        return Err("null input".into());
    }
    let bytes = if length == 0 { &[] } else { slice::from_raw_parts(input, length) };
    str::from_utf8(bytes).map_err(|error| error.to_string())
}

unsafe fn write_result(output: *mut u8, capacity: usize, bytes: &[u8]) -> isize {
    if output.is_null() || capacity < bytes.len() {
        return bytes.len() as isize;
    }
    slice::from_raw_parts_mut(output, bytes.len()).copy_from_slice(bytes);
    bytes.len() as isize
}

#[no_mangle]
pub extern "C" fn jianxi_alloc(length: usize) -> *mut u8 {
    if length == 0 {
        return std::ptr::null_mut();
    }
    let Ok(layout) = Layout::array::<u8>(length) else {
        return std::ptr::null_mut();
    };
    unsafe { alloc(layout) }
}

#[no_mangle]
pub extern "C" fn jianxi_dealloc(pointer: *mut u8, length: usize) {
    if pointer.is_null() || length == 0 {
        return;
    }
    if let Ok(layout) = Layout::array::<u8>(length) {
        unsafe { dealloc(pointer, layout) };
    }
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_count_tokens(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
) -> isize {
    catch_unwind(AssertUnwindSafe(|| {
        let text = read_utf8(input, input_length)?;
        let json = serde_json::to_vec(&count_tokens(text)).map_err(|error| error.to_string())?;
        Ok::<isize, String>(write_result(output, output_capacity, &json))
    }))
    .ok()
    .and_then(Result::ok)
    .unwrap_or(-1)
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_replace_index(input: *const u8, input_length: usize) -> i32 {
    catch_unwind(AssertUnwindSafe(|| {
        let json = read_utf8(input, input_length)?;
        let payload: IndexPayload = serde_json::from_str(json).map_err(|error| error.to_string())?;
        let mut guard = index().write().unwrap_or_else(|poisoned| poisoned.into_inner());
        guard.documents = payload.documents;
        Ok::<(), String>(())
    }))
    .ok()
    .and_then(Result::ok)
    .map_or(-1, |_| 0)
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_upsert_document(input: *const u8, input_length: usize) -> i32 {
    catch_unwind(AssertUnwindSafe(|| {
        let json = read_utf8(input, input_length)?;
        let document: IndexedDocument = serde_json::from_str(json).map_err(|error| error.to_string())?;
        let mut guard = index().write().unwrap_or_else(|poisoned| poisoned.into_inner());
        if let Some(existing) = guard.documents.iter_mut().find(|item| item.path == document.path) {
            *existing = document;
        } else {
            guard.documents.push(document);
        }
        Ok::<(), String>(())
    }))
    .ok()
    .and_then(Result::ok)
    .map_or(-1, |_| 0)
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_remove_document(input: *const u8, input_length: usize) -> i32 {
    catch_unwind(AssertUnwindSafe(|| {
        let path = read_utf8(input, input_length)?;
        let mut guard = index().write().unwrap_or_else(|poisoned| poisoned.into_inner());
        guard.documents.retain(|document| document.path != path);
        Ok::<(), String>(())
    }))
    .ok()
    .and_then(Result::ok)
    .map_or(-1, |_| 0)
}

#[no_mangle]
pub unsafe extern "C" fn jianxi_search(
    input: *const u8,
    input_length: usize,
    output: *mut u8,
    output_capacity: usize,
) -> isize {
    catch_unwind(AssertUnwindSafe(|| {
        let query = read_utf8(input, input_length)?;
        let hits = search(query);
        let json = serde_json::to_vec(&hits).map_err(|error| error.to_string())?;
        Ok::<isize, String>(write_result(output, output_capacity, &json))
    }))
    .ok()
    .and_then(Result::ok)
    .unwrap_or(-1)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tokenizes_cjk_bigrams_and_ascii_words() {
        assert_eq!(
            tokenize("缓存失效 Hello 42"),
            vec!["缓存", "存失", "失效", "hello", "42"]
        );
        assert!(tokenize("缓").is_empty());
    }

    #[test]
    fn counts_duplicate_tokens() {
        let counts = count_tokens("缓存 缓存");
        assert_eq!(counts.get("缓存"), Some(&2));
    }

    #[test]
    fn matches_all_tokens_and_ranks_by_frequency() {
        let documents = vec![
            test_document("often", "缓存 缓存"),
            test_document("once", "缓存 失效"),
            test_document("partial", "缓存"),
        ];
        *index().write().unwrap() = SearchIndex { documents };
        assert_eq!(search("缓存 失效")[0].path, "once");
        assert_eq!(search("缓存")[0].path, "often");
    }

    fn test_document(path: &str, text: &str) -> IndexedDocument {
        IndexedDocument {
            id: path.into(),
            path: path.into(),
            title: path.into(),
            size: 0,
            updated_at: 0,
            length: 0,
            tokens: count_tokens(text),
        }
    }
}
