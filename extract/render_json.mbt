///|
/// 结构化 JSON 渲染（D2）：手写固定 schema 序列化器。
/// 字段顺序硬编码、浮点固定 4 位小数、字符串统一转义，
/// 因此 js / wasm / wasm-gc / native 输出逐字节一致。

///|
fn render_block(block : @core.Block) -> String {
  let b = StringBuilder()
  match block {
    @core.Paragraph(t) => {
      b.write_string("{\"kind\":\"paragraph\",\"text\":")
      b.write_string(@core.json_string(t))
    }
    @core.Heading(level, t) => {
      b.write_string("{\"kind\":\"heading\",\"level\":")
      b.write_string(level.to_string())
      b.write_string(",\"text\":")
      b.write_string(@core.json_string(t))
    }
    @core.ListItem(t) => {
      b.write_string("{\"kind\":\"list_item\",\"text\":")
      b.write_string(@core.json_string(t))
    }
    @core.Quote(t) => {
      b.write_string("{\"kind\":\"quote\",\"text\":")
      b.write_string(@core.json_string(t))
    }
    @core.Code(t) => {
      b.write_string("{\"kind\":\"code\",\"text\":")
      b.write_string(@core.json_string(t))
    }
    @core.Image(src, alt) => {
      b.write_string("{\"kind\":\"image\",\"src\":")
      b.write_string(@core.json_string(src))
      b.write_string(",\"alt\":")
      b.write_string(@core.json_nullable(alt))
    }
  }
  b.write_char('}')
  b.to_string()
}

///|
fn render_blocks(blocks : Array[@core.Block]) -> String {
  let b = StringBuilder()
  b.write_char('[')
  for i = 0; i < blocks.length(); i = i + 1 {
    if i > 0 {
      b.write_char(',')
    }
    b.write_string(render_block(blocks[i]))
  }
  b.write_char(']')
  b.to_string()
}

///|
fn render_metadata(m : @core.Metadata) -> String {
  let b = StringBuilder()
  b.write_string("{\"site_name\":")
  b.write_string(@core.json_nullable(m.site_name))
  b.write_string(",\"description\":")
  b.write_string(@core.json_nullable(m.description))
  b.write_string(",\"lead_image\":")
  b.write_string(@core.json_nullable(m.lead_image))
  b.write_string(",\"lang\":")
  b.write_string(@core.json_nullable(m.lang))
  b.write_string(",\"published_at\":")
  b.write_string(@core.json_nullable(m.published_at))
  b.write_string(",\"keywords\":")
  b.write_string(@core.json_string_array(m.keywords))
  b.write_string(",\"jsonld\":")
  b.write_string(@core.json_nullable(m.jsonld))
  b.write_char('}')
  b.to_string()
}

///|
/// 把 Article 序列化为单行紧凑 JSON（字段顺序固定）。
pub fn render_json(a : @core.Article) -> String {
  let b = StringBuilder()
  b.write_string("{\"title\":")
  b.write_string(@core.json_string(a.title))
  b.write_string(",\"byline\":")
  b.write_string(@core.json_nullable(a.byline))
  b.write_string(",\"site_name\":")
  b.write_string(@core.json_nullable(a.site_name))
  b.write_string(",\"excerpt\":")
  b.write_string(@core.json_nullable(a.excerpt))
  b.write_string(",\"lead_image\":")
  b.write_string(@core.json_nullable(a.lead_image))
  b.write_string(",\"lang\":")
  b.write_string(@core.json_nullable(a.lang))
  b.write_string(",\"published_at\":")
  b.write_string(@core.json_nullable(a.published_at))
  b.write_string(",\"blocks\":")
  b.write_string(render_blocks(a.blocks))
  b.write_string(",\"text\":")
  b.write_string(@core.json_string(a.text))
  b.write_string(",\"markdown\":")
  b.write_string(@core.json_string(a.markdown))
  b.write_string(",\"metadata\":")
  b.write_string(render_metadata(a.metadata))
  b.write_string(",\"score\":")
  b.write_string(@core.json_number(a.score))
  b.write_string(",\"rules_version\":")
  b.write_string(@core.json_string(a.rules_version))
  b.write_char('}')
  b.to_string()
}
