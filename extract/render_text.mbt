///|
/// 纯文本渲染：块间空行，段落内保留换行（代码块的换行原样保留）。
/// 输入只能是 Article.blocks，不允许另起一套抽取逻辑（ADR-3）。

///|
pub fn render_text(blocks : Array[@core.Block]) -> String {
  let b = StringBuilder()
  for i = 0; i < blocks.length(); i = i + 1 {
    if i > 0 {
      b.write_string("\n\n")
    }
    match blocks[i] {
      @core.Paragraph(t) => b.write_string(t)
      @core.Heading(_, t) => b.write_string(t)
      @core.ListItem(t) => b.write_string(t)
      @core.Quote(t) => b.write_string(t)
      @core.Code(t) => b.write_string(t)
      @core.Image(src, alt) =>
        match alt {
          Some(a) => b.write_string(a)
          None => b.write_string(src)
        }
    }
  }
  b.to_string()
}
