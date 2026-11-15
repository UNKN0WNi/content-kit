///|
/// content-kit 门面 API。四个后端共享这一份实现。

///|
fn first_block_text(blocks : Array[@core.Block]) -> String? {
  for block in blocks {
    let t = @core.block_text(block)
    if t != "" {
      return Some(t)
    }
  }
  None
}

///|
fn with_first_paragraph(
  fields : @core.MetaFields,
  blocks : Array[@core.Block],
) -> @core.MetaFields {
  match first_block_text(blocks) {
    Some(t) => { ..fields, body_first_paragraph: Some(t), }
    None => fields
  }
}

///|
fn build_article(
  blocks : Array[@core.Block],
  fields : @core.MetaFields,
  score : Double,
) -> @core.Article {
  let rules = @core.default_rules()
  let resolved = @core.resolve(fields, rules.excerpt_len)
  let text = render_text(blocks)
  let markdown = render_md(blocks)
  let excerpt = match resolved.excerpt {
    Some(e) => Some(e)
    None =>
      match first_block_text(blocks) {
        Some(t) => Some(@core.truncate_chars(t, rules.excerpt_len))
        None => None
      }
  }
  {
    title: resolved.title,
    byline: resolved.byline,
    site_name: resolved.site_name,
    excerpt,
    lead_image: resolved.lead_image,
    lang: resolved.lang,
    published_at: resolved.published_at,
    blocks,
    text,
    markdown,
    metadata: @core.to_metadata(resolved, fields),
    score,
    rules_version: @core.rules_version,
  }
}

///|
/// 从 HTML 抽取完整 Article。
pub fn extract(html : String) -> @core.Article {
  let extracted = @html.extract_html(html)
  build_article(
    extracted.blocks,
    with_first_paragraph(extracted.meta, extracted.blocks),
    extracted.score,
  )
}

///|
/// 纯文本 / 邮件正文兜底入口。
pub fn extract_plain_text(text : String) -> @core.Article {
  let blocks = @plain.extract_plain(text)
  let fields = with_first_paragraph(@core.empty_meta_fields(), blocks)
  build_article(blocks, fields, 0.0)
}

///|
/// 自动判断输入是 HTML 还是纯文本。
pub fn extract_auto(input : String) -> @core.Article {
  if @plain.looks_like_plain(input) {
    extract_plain_text(input)
  } else {
    extract(input)
  }
}

///|
pub fn extract_text(html : String) -> String {
  extract(html).text
}

///|
pub fn extract_md(html : String) -> String {
  extract(html).markdown
}

///|
pub fn extract_json(html : String) -> String {
  render_json(extract(html))
}

///|
pub fn article_to_json(a : @core.Article) -> String {
  render_json(a)
}

///|
pub fn current_rules_version() -> String {
  @core.rules_version
}

///|
pub fn extract_to_text(blocks : Array[@core.Block]) -> String {
  render_text(blocks)
}

///|
pub fn extract_to_md(blocks : Array[@core.Block]) -> String {
  render_md(blocks)
}
