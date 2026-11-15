///|
/// npm 包导出面的单元测试。

///|
test "js exports return deterministic strings" {
  let html = "<article><p>一段足够长的正文内容，包含逗号与句号，用于验证 JS 导出函数。</p></article>"
  assert_eq(extractJson(html), extractJson(html))
  assert_eq(extractJson(html), @extract.extract_json(html))
  assert_eq(extractText(html), @extract.extract_text(html))
  assert_eq(extractMd(html), @extract.extract_md(html))
  assert_eq(rulesVersion(), "1.0.0")
  assert_eq(goldenBundle(), @extract.bundle())
}
