///|
/// L1：纯文本 / 邮件兜底解析器测试。

///|
test "plain headings lists quotes and code" {
  let text = "第一段文字，包含逗号与句号。\n\n# 标题一\n\n- 项目一\n- 项目二\n\n> 引用内容\n\n```\nline1\nline2\n```\n\n最后一段。"
  let blocks = extract_plain(text)
  assert_true(blocks.length() >= 7)
  let kinds = StringBuilder()
  for block in blocks {
    kinds.write_string(@core.block_kind(block))
    kinds.write_char(',')
  }
  let k = kinds.to_string()
  assert_eq(@core.contains_sub(k, "paragraph"), true)
  assert_eq(@core.contains_sub(k, "heading"), true)
  assert_eq(@core.contains_sub(k, "list_item"), true)
  assert_eq(@core.contains_sub(k, "quote"), true)
  assert_eq(@core.contains_sub(k, "code"), true)
  assert_eq(@core.contains_sub(@core.blocks_text(blocks), "line1"), true)
}

///|
test "plain heading level and content" {
  let blocks = extract_plain("### 三级标题\n\n正文内容")
  match blocks[0] {
    @core.Heading(level, t) => {
      assert_eq(level, 3)
      assert_eq(t, "三级标题")
    }
    _ => assert_true(false)
  }
  assert_eq(blocks.length(), 2)
}

///|
test "plain empty and whitespace" {
  assert_eq(extract_plain("").length(), 0)
  assert_eq(extract_plain("   \n\n  ").length(), 0)
}

///|
test "plain unclosed code fence" {
  let blocks = extract_plain("```\nunclosed code")
  assert_eq(blocks.length(), 1)
  assert_eq(@core.block_kind(blocks[0]), "code")
}

///|
test "plain code fence keeps leading blank lines" {
  let blocks = extract_plain("```\n\nline1\n\nline2\n```")
  assert_eq(blocks.length(), 1)
  match blocks[0] {
    @core.Code(body) => assert_eq(body, "\nline1\n\nline2")
    _ => assert_true(false)
  }
}

///|
test "plain blank-only code fence produces no block" {
  assert_eq(extract_plain("```\n\n```").length(), 0)
}

///|
test "looks_like_plain" {
  assert_eq(looks_like_plain("hello world"), true)
  assert_eq(looks_like_plain("<p>hello</p>"), false)
  assert_eq(looks_like_plain("a < b"), false)
}
