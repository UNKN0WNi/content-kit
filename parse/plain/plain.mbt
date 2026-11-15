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
/// 把纯文本切成有序内容块。空行分段；支持 Markdown 风格的标题/列表/引用/代码围栏。
pub fn extract_plain(text : String) -> Array[@core.Block] {
  let blocks : Array[@core.Block] = []
  let lines = split_lines(text)
  let mut paragraph = StringBuilder()
  let mut in_code = false
  let mut code = StringBuilder()
  for raw in lines {
    let line = @core.normalize_ws(raw)
    if @core.starts_with_sub(line, "```") {
      if in_code {
        let body = code.to_string()
        if body != "" {
          blocks.push(@core.Code(body))
        }
        code = StringBuilder()
        in_code = false
      } else {
        let pending = @core.normalize_ws(paragraph.to_string())
        if pending != "" {
          blocks.push(@core.Paragraph(pending))
        }
        paragraph = StringBuilder()
        in_code = true
      }
      continue
    }
    if in_code {
      if code.to_string() != "" {
        code.write_char('\n')
      }
      code.write_string(raw)
      continue
    }
    if line == "" {
      let pending = @core.normalize_ws(paragraph.to_string())
      if pending != "" {
        blocks.push(@core.Paragraph(pending))
      }
      paragraph = StringBuilder()
      continue
    }
    let level = heading_level(line)
    if level > 0 {
      let pending = @core.normalize_ws(paragraph.to_string())
      if pending != "" {
        blocks.push(@core.Paragraph(pending))
      }
      paragraph = StringBuilder()
      blocks.push(@core.Heading(level, line_content(line, level + 1)))
    } else if @core.starts_with_sub(line, "- ") ||
      @core.starts_with_sub(line, "* ") {
      let pending = @core.normalize_ws(paragraph.to_string())
      if pending != "" {
        blocks.push(@core.Paragraph(pending))
      }
      paragraph = StringBuilder()
      blocks.push(@core.ListItem(line_content(line, 2)))
    } else if @core.starts_with_sub(line, "> ") {
      let pending = @core.normalize_ws(paragraph.to_string())
      if pending != "" {
        blocks.push(@core.Paragraph(pending))
      }
      paragraph = StringBuilder()
      blocks.push(@core.Quote(line_content(line, 2)))
    } else {
      if paragraph.to_string() != "" {
        paragraph.write_char(' ')
      }
      paragraph.write_string(line)
    }
  }
  if in_code {
    let body = code.to_string()
    if body != "" {
      blocks.push(@core.Code(body))
    }
  }
  let pending = @core.normalize_ws(paragraph.to_string())
  if pending != "" {
    blocks.push(@core.Paragraph(pending))
  }
  blocks
}

///|
/// 判断输入是否更像纯文本而不是 HTML。
pub fn looks_like_plain(text : String) -> Bool {
  !@core.contains_sub(text, "<")
}
