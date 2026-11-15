///|
/// 文本归一化工具集。全部是纯函数，不依赖任何后端 API。

///|
/// ASCII 小写化。只转换 ASCII 码点，不依赖 locale 相关的 Unicode 大小写库。
pub fn ascii_lower(s : String) -> String {
  let b = StringBuilder()
  let cs = s.to_array()
  for c in cs {
    let code = c.to_int()
    if code >= 'A'.to_int() && code <= 'Z'.to_int() {
      match (code + 32).to_char() {
        Some(lower) => b.write_char(lower)
        None => b.write_char(c)
      }
    } else {
      b.write_char(c)
    }
  }
  b.to_string()
}

///|
pub fn is_whitespace(c : Char) -> Bool {
  match c {
    ' ' | '\t' | '\n' | '\r' | '\u{000C}' | '\u{00A0}' | '\u{3000}' => true
    _ => false
  }
}

///|
pub fn is_ascii_digit(c : Char) -> Bool {
  c.to_int() >= '0'.to_int() && c.to_int() <= '9'.to_int()
}

///|
pub fn is_hex_digit(c : Char) -> Bool {
  is_ascii_digit(c) ||
  (c.to_int() >= 'a'.to_int() && c.to_int() <= 'f'.to_int()) ||
  (c.to_int() >= 'A'.to_int() && c.to_int() <= 'F'.to_int())
}

///|
fn digit_value(c : Char) -> Int32 {
  if is_ascii_digit(c) {
    c.to_int() - '0'.to_int()
  } else if c.to_int() >= 'a'.to_int() && c.to_int() <= 'f'.to_int() {
    c.to_int() - 'a'.to_int() + 10
  } else {
    c.to_int() - 'A'.to_int() + 10
  }
}

///|
fn parse_number(s : String, base : Int32) -> Int32? {
  let cs = s.to_array()
  if cs.length() == 0 {
    return None
  }
  let mut value = 0
  for i = 0; i < cs.length(); i = i + 1 {
    if !is_hex_digit(cs[i]) {
      return None
    }
    let d = digit_value(cs[i])
    if d >= base {
      return None
    }
    value = value * base + d
    if value > 0x10FFFF {
      return None
    }
  }
  Some(value)
}

///|
/// HTML 命名实体与数字实体的最小实现。
/// 只覆盖内容抽取会遇到的实体；未知实体原样保留，保证不丢失信息。
fn entity_value(name : String) -> String? {
  let low = ascii_lower(name)
  match low {
    "amp" => Some("&")
    "lt" => Some("<")
    "gt" => Some(">")
    "quot" => Some("\"")
    "apos" => Some("'")
    "nbsp" => Some(" ")
    "mdash" => Some("\u{2014}")
    "ndash" => Some("\u{2013}")
    "hellip" => Some("\u{2026}")
    "laquo" => Some("\u{00AB}")
    "raquo" => Some("\u{00BB}")
    "lsquo" => Some("\u{2018}")
    "rsquo" => Some("\u{2019}")
    "ldquo" => Some("\u{201C}")
    "rdquo" => Some("\u{201D}")
    "copy" => Some("\u{00A9}")
    "reg" => Some("\u{00AE}")
    "trade" => Some("\u{2122}")
    _ => {
      let cs = name.to_array()
      if cs.length() > 1 && cs[0] == '#' {
        let mut start = 1
        let mut base = 10
        if cs.length() > 2 && (cs[1] == 'x' || cs[1] == 'X') {
          start = 2
          base = 16
        }
        let b = StringBuilder()
        for i = start; i < cs.length(); i = i + 1 {
          b.write_char(cs[i])
        }
        match parse_number(b.to_string(), base) {
          Some(code) =>
            if code == 0 {
              Some("")
            } else if code < 0xD800 || code > 0xDFFF {
              // 基本多文种平面内的码点可以直接转成 Char。
              // 用 Int::to_char 的安全版本，非法码点返回空串。
              match code.to_char() {
                Some(c) => {
                  let one = StringBuilder()
                  one.write_char(c)
                  Some(one.to_string())
                }
                None => Some("")
              }
            } else {
              Some("")
            }
          None => None
        }
      } else {
        None
      }
    }
  }
}

///|
pub fn decode_entities(s : String) -> String {
  let cs = s.to_array()
  let n = cs.length()
  let b = StringBuilder()
  let mut i = 0
  while i < n {
    if cs[i] == '&' {
      let mut found = -1
      let mut j = i + 1
      while j < n && j < i + 24 {
        if cs[j] == ';' {
          found = j
          break
        }
        if cs[j] == '&' || is_whitespace(cs[j]) || cs[j] == '<' {
          break
        }
        j += 1
      }
      if found > i + 1 {
        let name_builder = StringBuilder()
        for k = i + 1; k < found; k = k + 1 {
          name_builder.write_char(cs[k])
        }
        let decoded = entity_value(name_builder.to_string())
        match decoded {
          Some(v) => {
            b.write_string(v)
            i = found + 1
          }
          None => {
            b.write_char(cs[i])
            i += 1
          }
        }
      } else {
        b.write_char(cs[i])
        i += 1
      }
    } else {
      b.write_char(cs[i])
      i += 1
    }
  }
  b.to_string()
}

///|
/// 折叠所有空白为单个空格并去掉首尾空白。
pub fn normalize_ws(s : String) -> String {
  let b = StringBuilder()
  let cs = s.to_array()
  let mut pending_space = false
  let mut started = false
  for i = 0; i < cs.length(); i = i + 1 {
    let c = cs[i]
    if is_whitespace(c) {
      if started {
        pending_space = true
      }
    } else {
      if pending_space {
        b.write_char(' ')
        pending_space = false
      }
      b.write_char(c)
      started = true
    }
  }
  b.to_string()
}

///|
/// 中英文都适用的「句子标点」计数（Readability 用逗号密度识别正文）。
pub fn count_commas(s : String) -> Int32 {
  let cs = s.to_array()
  let mut count = 0
  for i = 0; i < cs.length(); i = i + 1 {
    match cs[i] {
      ',' | '，' | '、' | ';' | '；' | ':' | '：' | '.' => count += 1
      _ => ()
    }
  }
  count
}

///|
/// 按 Unicode 字符（而非 UTF-16 码元）截断，不会切坏代理对。
pub fn truncate_chars(s : String, limit : Int32) -> String {
  if limit <= 0 {
    return ""
  }
  let cs = s.to_array()
  if cs.length() <= limit {
    return s
  }
  let b = StringBuilder()
  for i = 0; i < limit; i = i + 1 {
    b.write_char(cs[i])
  }
  b.to_string()
}

///|
pub fn contains_sub(haystack : String, needle : String) -> Bool {
  index_of_sub(haystack, needle, 0) >= 0
}

///|
pub fn starts_with_sub(s : String, prefix : String) -> Bool {
  let a = s.to_array()
  let b = prefix.to_array()
  if b.length() > a.length() {
    return false
  }
  for i = 0; i < b.length(); i = i + 1 {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
pub fn ends_with_sub(s : String, suffix : String) -> Bool {
  let a = s.to_array()
  let b = suffix.to_array()
  if b.length() > a.length() {
    return false
  }
  let offset = a.length() - b.length()
  for i = 0; i < b.length(); i = i + 1 {
    if a[offset + i] != b[i] {
      return false
    }
  }
  true
}

///|
/// 从 from 开始查找子串，返回下标；未找到返回 -1。
pub fn index_of_sub(s : String, pattern : String, from : Int32) -> Int32 {
  let a = s.to_array()
  let p = pattern.to_array()
  if p.length() == 0 {
    return if from < 0 { 0 } else { from }
  }
  if p.length() > a.length() {
    return -1
  }
  let mut i = if from < 0 { 0 } else { from }
  while i + p.length() <= a.length() {
    let mut ok = true
    for j = 0; j < p.length(); j = j + 1 {
      if a[i + j] != p[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i += 1
  }
  -1
}

///|
pub fn split_whitespace(s : String) -> Array[String] {
  let out : Array[String] = []
  let mut b = StringBuilder()
  let mut pending = false
  let cs = s.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    if is_whitespace(cs[i]) {
      if pending {
        out.push(b.to_string())
        b = StringBuilder()
        pending = false
      }
    } else {
      b.write_char(cs[i])
      pending = true
    }
  }
  if pending {
    out.push(b.to_string())
  }
  out
}
