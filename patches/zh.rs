//! Runtime Chinese (zh-CN) translation of UI text, applied at text layout time.
//!
//! Every string epaint lays out (labels, buttons, tooltips, values painted with
//! `Painter::text`, …) passes through [`Fonts::layout_job`]. Translating there
//! covers the whole interface without touching each call site.
//!
//! The dictionary is a tab-separated file of `English<TAB>Chinese` lines.
//! English entries may contain `{...}` placeholders; a Chinese entry then uses
//! the same placeholders in the same order and the captured values are
//! substituted back in. See `zh.tsv` next to the app.

use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::OnceLock;

struct Pattern {
    /// Literal segments between placeholders; `segments.len() == parts.len() + 1`.
    segments: Vec<String>,
    /// Chinese segments between placeholders.
    parts: Vec<String>,
    /// Total bytes of literal text, which orders the patterns: the more fixed
    /// text a template has, the more specific its match.
    literals: usize,
}

impl Pattern {
    fn has_prefix(&self, text: &str) -> bool {
        text.starts_with(self.segments[0].as_str())
    }

    fn capture(&self, text: &str) -> Option<Vec<String>> {
        let last = self.segments.len() - 1;
        let mut rest = text.strip_prefix(self.segments[0].as_str())?;
        let mut captions = Vec::with_capacity(last);
        // A template of nothing but placeholders would match any sentence, so a
        // capture may not swallow a whole paragraph.
        const MAX_CAPTURE: usize = 80;
        for (i, segment) in self.segments.iter().enumerate().skip(1) {
            if i == last {
                let head = rest.strip_suffix(segment.as_str())?;
                if head.len() > MAX_CAPTURE {
                    return None;
                }
                captions.push(head.to_owned());
            } else {
                let pos = rest.find(segment.as_str())?;
                if pos > MAX_CAPTURE {
                    return None;
                }
                captions.push(rest[..pos].to_owned());
                rest = &rest[pos + segment.len()..];
            }
        }
        Some(captions)
    }

    fn render(&self, captions: &[String]) -> Option<String> {
        if captions.len() + 1 != self.parts.len() {
            return None;
        }
        let mut out = String::new();
        for (i, part) in self.parts.iter().enumerate() {
            out.push_str(part);
            if let Some(value) = captions.get(i) {
                out.push_str(value);
            }
        }
        Some(out)
    }
}

struct Dict {
    exact: HashMap<String, String>,
    patterns: Vec<Pattern>,
    /// Memoized lookups, including misses.
    memo: HashMap<String, Option<String>>,
    log: Option<PathBuf>,
    logged: HashMap<String, ()>,
}

fn dictionary_path() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("RAWMAKASE_ZH_DICT") {
        return Some(PathBuf::from(path));
    }
    if let Some(home) = std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
    {
        let user = home.join("rawmakase").join("zh.tsv");
        if user.is_file() {
            return Some(user);
        }
    }
    let system = PathBuf::from("/usr/local/share/rawmakase-zh/zh.tsv");
    system.is_file().then_some(system)
}

/// Split a string into literal segments and the placeholders between them.
fn split_placeholders(text: &str) -> (Vec<String>, usize) {
    let mut parts = Vec::new();
    let mut current = String::new();
    let mut count = 0;
    let bytes = text.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        let ch = text[i..].chars().next().unwrap();
        if ch == '{' {
            if let Some(end) = text[i..].find('}') {
                // `{{` is a literal brace, not a placeholder.
                if text[i..].starts_with("{{") {
                    current.push('{');
                    i += 2;
                    continue;
                }
                parts.push(std::mem::take(&mut current));
                count += 1;
                i += end + 1;
                continue;
            }
        }
        current.push(ch);
        i += ch.len_utf8();
    }
    parts.push(current);
    (parts, count)
}

impl Dict {
    fn load(path: &PathBuf) -> Option<Self> {
        let raw = std::fs::read_to_string(path).ok()?;
        let mut exact = HashMap::new();
        let mut patterns = Vec::new();
        for (number, line) in raw.lines().enumerate() {
            let line = line.trim_end_matches('\r');
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let Some((english, chinese)) = line.split_once('\t') else {
                log::warn!("zh.tsv:{}: expected English<TAB>Chinese", number + 1);
                continue;
            };
            let english = unescape(english);
            let chinese = unescape(chinese);
            if english.is_empty() || chinese.is_empty() {
                continue;
            }
            let (segments, placeholders) = split_placeholders(&english);
            if placeholders == 0 {
                exact.insert(english, chinese);
            } else {
                let (parts, chinese_placeholders) = split_placeholders(&chinese);
                if chinese_placeholders != placeholders {
                    log::warn!(
                        "zh.tsv:{}: placeholder count differs: {english:?} -> {chinese:?}",
                        number + 1
                    );
                    continue;
                }
                let max_literal = segments.iter().map(String::len).max().unwrap_or(0);
                let literals: usize = segments.iter().map(String::len).sum();
                // Two or more placeholders with (nearly) no fixed text match
                // almost any sentence; leave those to exact entries.
                if placeholders > 1 && max_literal < 3 {
                    log::warn!("zh.tsv:{}: template too generic, skipped: {english:?}", number + 1);
                    continue;
                }
                patterns.push(Pattern { segments, parts, literals });
            }
        }
        // Longest patterns first so a more specific template wins.
        patterns.sort_by_key(|p| std::cmp::Reverse(p.literals));
        let log = std::env::var_os("RAWMAKASE_ZH_LOG").map(PathBuf::from);
        Some(Self {
            exact,
            patterns,
            memo: HashMap::new(),
            log,
            logged: HashMap::new(),
        })
    }

    fn translate(&mut self, text: &str) -> Option<String> {
        if let Some(hit) = self.memo.get(text) {
            return hit.clone();
        }
        let mut found = self.exact.get(text).cloned();
        if found.is_none() {
            for pattern in &self.patterns {
                if !pattern.has_prefix(text) {
                    continue;
                }
                if let Some(captions) = pattern.capture(text) {
                    if let Some(out) = pattern.render(&captions) {
                        found = Some(out);
                        break;
                    }
                }
            }
        }
        self.memo.insert(text.to_owned(), found.clone());
        found
    }

    fn log_text(&mut self, text: &str) {
        let Some(path) = &self.log else { return };
        if self.logged.insert(text.to_owned(), ()).is_some() {
            return;
        }
        use std::io::Write;
        if let Ok(mut file) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
        {
            let escaped = text.replace('\n', "\\n").replace('\t', "\\t");
            let _ = writeln!(file, "{escaped}");
        }
    }
}

fn unescape(text: &str) -> String {
    text.replace("\\n", "\n").replace("\\t", "\t")
}

fn dict() -> Option<&'static std::sync::Mutex<Dict>> {
    static MUTEX: OnceLock<Option<std::sync::Mutex<Dict>>> = OnceLock::new();
    MUTEX
        .get_or_init(|| {
            let path = dictionary_path()?;
            let dict = Dict::load(&path)?;
            log::info!(
                "Chinese dictionary loaded from {} ({} exact, {} patterns)",
                path.display(),
                dict.exact.len(),
                dict.patterns.len()
            );
            Some(std::sync::Mutex::new(dict))
        })
        .as_ref()
}

/// Translate one laid-out string, if the dictionary has an entry for it.
pub fn translate(text: &str) -> Option<String> {
    if text.trim().is_empty() {
        return None;
    }
    let dict = dict()?;
    let mut guard = dict.lock().ok()?;
    guard.log_text(text);
    guard.translate(text)
}

/// Translate a layout job whose single section covers the whole text.
pub fn translate_job(job: crate::text::LayoutJob) -> crate::text::LayoutJob {
    use crate::text::ByteRangeExt as _;
    if job.sections.is_empty() {
        return job;
    }
    // Every section has to be part of one contiguous run over the whole text:
    // a label may split a sentence to tint one word, and then the translation
    // is drawn in the first section's format. Anything else (a text edit with a
    // selection, a highlighted code block) is left alone.
    let mut cursor = 0;
    for section in &job.sections {
        let range = section.byte_range.as_usize();
        if range.start != cursor {
            return job;
        }
        cursor = range.end;
    }
    if cursor != job.text.len() {
        return job;
    }
    let Some(chinese) = translate(&job.text) else {
        return job;
    };
    let mut job = job;
    job.text = chinese;
    job.sections.truncate(1);
    job.sections[0].byte_range = <crate::text::ByteRange as crate::text::ByteRangeExt>::full(&job.text);
    job
}
