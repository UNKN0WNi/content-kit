///|
/// 确定性 JSON 序列化工具（D2 决策）。
///
/// 不使用运行时 Json 值：字段顺序、浮点格式、转义策略全部由本文件硬编码，
/// 因此 js / wasm / wasm-gc / native 四个后端的输出必然逐字节相同。

///|
fn hex_digits() -> Array[Char] {
  "0123456789abcdef".to_array()
}

///|
fn hex4(code : Int32) -> String {
  let digits = hex_digits()
  let b = StringBuilder()
  b.write_string("\\u")
  b.write_char(digits[code / 4096 % 16])
  b.write_char(digits[code / 256 % 16])
  b.write_char(digits[code / 16 % 16])
  b.write_char(digits[code % 16])
  b.to_string()
}

///|
/// JSON 字符串转义。控制字符统一输出 \u00XX，避免各后端对控制字符的不同处理。
pub fn json_escape(s : String) -> String {
  let b = StringBuilder()
  let cs = s.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    let c = cs[i]
    let code = c.to_int()
    match c {
      '"' => b.write_string("\\\"")
      '\\' => b.write_string("\\\\")
      '\n' => b.write_string("\\n")
      '\r' => b.write_string("\\r")
      '\t' => b.write_string("\\t")
      '\u{0008}' => b.write_string("\\b")
      '\u{000C}' => b.write_string("\\f")
      _ => if code < 32 { b.write_string(hex4(code)) } else { b.write_char(c) }
    }
  }
  b.to_string()
}

///|
pub fn json_string(s : String) -> String {
  "\"" + json_escape(s) + "\""
}

///|
pub fn json_nullable(v : String?) -> String {
  match v {
    Some(s) => json_string(s)
    None => "null"
  }
}

///|
pub fn json_string_array(values : Array[String]) -> String {
  let b = StringBuilder()
  b.write_char('[')
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      b.write_char(',')
    }
    b.write_string(json_string(values[i]))
  }
  b.write_char(']')
  b.to_string()
}

///|
fn pad4(n : Int32) -> String {
  let digits = "0123456789".to_array()
  let b = StringBuilder()
  b.write_char(digits[n / 1000 % 10])
  b.write_char(digits[n / 100 % 10])
  b.write_char(digits[n / 10 % 10])
  b.write_char(digits[n % 10])
  b.to_string()
}

///|
/// 固定 4 位小数的浮点序列化，完全由整数运算实现。
/// 不使用 Double::to_string，避免不同后端的科学计数法 / 尾零差异。
pub fn json_number(d : Double) -> String {
  let negative = d < 0.0
  let abs_value = if negative { -d } else { d }
  // 分数不可能超过这个量级，做一个硬上限防止整数溢出。
  let bounded = if abs_value > 100000.0 { 100000.0 } else { abs_value }
  let scaled = (bounded * 10000.0 + 0.5).to_int()
  let whole = scaled / 10000
  let frac = scaled % 10000
  let sign = if negative { "-" } else { "" }
  sign + whole.to_string() + "." + pad4(frac)
}
