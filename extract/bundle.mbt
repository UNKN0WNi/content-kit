///|
/// 语料批处理：把「同一语料 × 同一算法」的结果导出成一个确定性字符串。
/// 这是跨后端一致性测试的核心入口 —— 各后端把 bundle() 打印到 stdout，
/// 脚本逐字节 diff，不需要任何文件 IO 或后端特有 API。

///|
fn format_output(fmt : String, html : String) -> String {
  match fmt {
    "text" => extract_text(html)
    "md" | "markdown" => extract_md(html)
    _ => extract_json(html)
  }
}

///|
/// 全量语料的标准输出：每行 `名称<TAB>渲染结果`。
pub fn bundle() -> String {
  bundle_with_format("json")
}

///|
pub fn bundle_with_format(fmt : String) -> String {
  let b = StringBuilder()
  for (name, html) in @testdata.cases() {
    b.write_string(name)
    b.write_char('\t')
    b.write_string(format_output(fmt, html))
    b.write_char('\n')
  }
  b.to_string()
}

///|
/// 去掉末尾换行的 bundle，供只有 println 的后端使用（输出更干净）。
pub fn bundle_line(fmt : String) -> String {
  let s = bundle_with_format(fmt)
  if @core.ends_with_sub(s, "\n") {
    s[:s.length() - 1].to_owned()
  } else {
    s
  }
}

///|
/// 语料名称清单（转出给 CLI，避免 CLI 直接依赖 testdata 包）。
pub fn corpus_case_names() -> Array[String] {
  @testdata.case_names()
}

///|
/// 单篇语料输出，供 CLI --case / --text 使用。
pub fn case_output(name : String, fmt : String) -> String? {
  for (key, html) in @testdata.cases() {
    if key == name {
      return Some(format_output(fmt, html))
    }
  }
  None
}

///|
/// 直接对一段输入按指定格式渲染。
pub fn render_input(input : String, fmt : String) -> String {
  let article = extract_auto(input)
  match fmt {
    "text" => article.text
    "md" | "markdown" => article.markdown
    _ => render_json(article)
  }
}

///|
/// 语料名称、字节长度与内容块数量的摘要，用于 Golden Vector 断言。
pub fn corpus_summary() -> String {
  let b = StringBuilder()
  for (name, html) in @testdata.cases() {
    let a = extract(html)
    b.write_string(name)
    b.write_char('\t')
    b.write_string(html.to_array().length().to_string())
    b.write_char('\t')
    b.write_string(a.blocks.length().to_string())
    b.write_char('\t')
    b.write_string(a.title)
    b.write_char('\n')
  }
  b.to_string()
}
