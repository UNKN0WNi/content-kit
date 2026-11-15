///|
/// npm 包（js 后端）入口。这些函数被导出到生成的 ESM 模块中，
/// 配套 js/index.d.ts 提供 TypeScript 类型声明。

///|
pub fn extractJson(html : String) -> String {
  @extract.extract_json(html)
}

///|
pub fn extractText(html : String) -> String {
  @extract.extract_text(html)
}

///|
pub fn extractMd(html : String) -> String {
  @extract.extract_md(html)
}

///|
pub fn rulesVersion() -> String {
  @extract.current_rules_version()
}

///|
/// 全量语料的 Golden Bundle，供 Node 侧一致性脚本调用。
pub fn goldenBundle() -> String {
  @extract.bundle()
}
