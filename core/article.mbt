///|
/// 正文内容序列中的单个内容块。
/// 文本 / Markdown / JSON 三种输出全部由同一个 Block 序列渲染（ADR-3）。
pub(all) enum Block {
  Paragraph(String)
  Heading(Int32, String)
  ListItem(String)
  Quote(String)
  Code(String)
  Image(String, String?)
}

///|
/// 结构化元数据。
/// jsonld 保留原始 JSON-LD 文本而不是解析后的 Json 值：固定 schema 的
/// 手写序列化器不依赖任何运行时的 Json 实现，四后端输出逐字节一致（D2）。
pub(all) struct Metadata {
  site_name : String?
  description : String?
  lead_image : String?
  lang : String?
  published_at : String?
  keywords : Array[String]
  jsonld : String?
}

///|
/// 抽取结果：四个后端共享的唯一数据载体。
/// 字段顺序即 JSON 字段顺序，硬编码在 render_json 中，禁止依赖哈希表遍历。
pub(all) struct Article {
  title : String
  byline : String?
  site_name : String?
  excerpt : String?
  lead_image : String?
  lang : String?
  published_at : String?
  blocks : Array[Block]
  text : String
  markdown : String
  metadata : Metadata
  score : Double
  rules_version : String
}

///|
/// 取内容块的文本（图片块没有文本，返回空串）。
pub fn block_text(b : Block) -> String {
  match b {
    Paragraph(t) => t
    Heading(_, t) => t
    ListItem(t) => t
    Quote(t) => t
    Code(t) => t
    Image(_, _) => ""
  }
}

///|
/// 内容块的类型标签，用于 JSON 的 "kind" 字段。
pub fn block_kind(b : Block) -> String {
  match b {
    Paragraph(_) => "paragraph"
    Heading(_, _) => "heading"
    ListItem(_) => "list_item"
    Quote(_) => "quote"
    Code(_) => "code"
    Image(_, _) => "image"
  }
}

///|
/// 把内容块的文本按顺序拼成一个字符串（测试与摘要用）。
pub fn blocks_text(blocks : Array[Block]) -> String {
  let b = StringBuilder()
  for i = 0; i < blocks.length(); i = i + 1 {
    if i > 0 {
      b.write_char(' ')
    }
    b.write_string(block_text(blocks[i]))
  }
  b.to_string()
}

///|
/// 空的元数据容器。
pub fn empty_metadata() -> Metadata {
  {
    site_name: None,
    description: None,
    lead_image: None,
    lang: None,
    published_at: None,
    keywords: [],
    jsonld: None,
  }
}
