///|
/// 纯文本 / 邮件正文兜底解析器（§5.1 parse/plain）。
/// 与 HTML 路径共享同一套 core/Block，保证输出结构一致。

///|
fn split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let mut b = StringBuilder()
  let cs = text.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == '\n' {
      lines.push(b.to_string())
      b = StringBuilder()
    } else if cs[i] != '\r' {
      b.write_char(cs[i])
    }
  }
  lines.push(b.to_string())
  lines
}

///|
fn heading_level(line : String) -> Int32 {
  let cs = line.to_array()
  let mut level = 0
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == '#' && level < 6 {
      level += 1
    } else {
      break
    }
  }
  if level > 0 && level < cs.length() && cs[level] == ' ' {
    level
  } else {
    0
  }
}

///|
fn line_content(line : String, prefix_len : Int32) -> String {
  @core.normalize_ws(line[prefix_len:].to_owned())
}

///|
fn flush_paragraph(
  blocks : Array[@core.Block],
  paragraph : StringBuilder,
) -> Unit {
  let pending = @core.normalize_ws(paragraph.to_string())
  if pending != "" {
    blocks.push(@core.Paragraph(pending))
  }
}

///|
fn flush_code(
  blocks : Array[@core.Block],
  code : StringBuilder,
  line_count : Int32,
) -> Unit {
  if line_count > 0 {
    let body = code.to_string()
    if body != "" {
      blocks.push(@core.Code(body))
    }
  }
}

///|
/// 把纯文本切成有序内容块。空行分段；支持 Markdown 风格的标题/列表/引用/代码围栏。
pub fn extract_plain(text : String) -> Array[@core.Block] {
  let blocks : Array[@core.Block] = []
  let lines = split_lines(text)
  let mut paragraph = StringBuilder()
  let mut paragraph_started = false
  let mut in_code = false
  let mut code = StringBuilder()
  let mut code_lines = 0
  for raw in lines {
    let line = @core.normalize_ws(raw)
    if @core.starts_with_sub(line, "```") {
      if in_code {
        flush_code(blocks, code, code_lines)
        code = StringBuilder()
        code_lines = 0
        in_code = false
      } else {
        flush_paragraph(blocks, paragraph)
        paragraph = StringBuilder()
        paragraph_started = false
        in_code = true
      }
      continue
    }
    if in_code {
      if code_lines > 0 {
        code.write_char('\n')
      }
      code.write_string(raw)
      code_lines += 1
      continue
    }
    if line == "" {
      flush_paragraph(blocks, paragraph)
      paragraph = StringBuilder()
      paragraph_started = false
      continue
    }
    let level = heading_level(line)
    if level > 0 {
      flush_paragraph(blocks, paragraph)
      paragraph = StringBuilder()
      paragraph_started = false
      blocks.push(@core.Heading(level, line_content(line, level + 1)))
    } else if @core.starts_with_sub(line, "- ") ||
      @core.starts_with_sub(line, "* ") {
      flush_paragraph(blocks, paragraph)
      paragraph = StringBuilder()
      paragraph_started = false
      blocks.push(@core.ListItem(line_content(line, 2)))
    } else if @core.starts_with_sub(line, "> ") {
      flush_paragraph(blocks, paragraph)
      paragraph = StringBuilder()
      paragraph_started = false
      blocks.push(@core.Quote(line_content(line, 2)))
    } else {
      if paragraph_started {
        paragraph.write_char(' ')
      }
      paragraph.write_string(line)
      paragraph_started = true
    }
  }
  if in_code {
    flush_code(blocks, code, code_lines)
  }
  flush_paragraph(blocks, paragraph)
  blocks
}

///|
/// 判断输入是否更像纯文本而不是 HTML。
pub fn looks_like_plain(text : String) -> Bool {
  !@core.contains_sub(text, "<")
}
