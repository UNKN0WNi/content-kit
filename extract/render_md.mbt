///|
/// Markdown 渲染：与 render_text 共享同一个 blocks 序列（ADR-3）。

///|
fn repeat_char(c : Char, n : Int32) -> String {
  let b = StringBuilder()
  for _i = 0; _i < n; _i = _i + 1 {
    b.write_char(c)
  }
  b.to_string()
}

///|
/// 轻量 Markdown 转义：只处理会破坏行内结构的两个字符。
pub fn md_escape(text : String) -> String {
  let b = StringBuilder()
  let cs = text.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == '\\' || cs[i] == '`' {
      b.write_char('\\')
    }
    b.write_char(cs[i])
  }
  b.to_string()
}

///|
pub fn render_md(blocks : Array[@core.Block]) -> String {
  let b = StringBuilder()
  for i = 0; i < blocks.length(); i = i + 1 {
    if i > 0 {
      b.write_string("\n\n")
    }
    match blocks[i] {
      @core.Paragraph(t) => b.write_string(md_escape(t))
      @core.Heading(level, t) => {
        let lv = if level < 1 { 1 } else if level > 6 { 6 } else { level }
        b.write_string(repeat_char('#', lv))
        b.write_char(' ')
        b.write_string(md_escape(t))
      }
      @core.ListItem(t) => {
        b.write_string("- ")
        b.write_string(md_escape(t))
      }
      @core.Quote(t) => {
        b.write_string("> ")
        b.write_string(md_escape(t))
      }
      @core.Code(t) => {
        b.write_string("```\n")
        b.write_string(t)
        b.write_string("\n```")
      }
      @core.Image(src, alt) => {
        b.write_string("![")
        match alt {
          Some(a) => b.write_string(md_escape(a))
          None => ()
        }
        b.write_string("](")
        b.write_string(src)
        b.write_char(')')
      }
    }
  }
  b.to_string()
}
