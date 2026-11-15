///|
/// HTML → 正文块 + 元数据（§5.5.1 – §5.5.4）。
/// 打分权重全部来自 core/rules.mbt，本文件只负责 DOM 特征提取与决策。

///|
pub(all) struct Extracted {
  blocks : Array[@core.Block]
  meta : @core.MetaFields
  score : Double
  candidate_count : Int32
}

///|
fn pick(pairs : Array[(String, String)], key : String) -> String? {
  for (k, v) in pairs {
    if k == key {
      return Some(v)
    }
  }
  None
}

///|
fn pick_attr(node : Node, keys : Array[String]) -> String? {
  for key in keys {
    match attr(node, key) {
      Some(v) => if v == "" { () } else { return Some(v) }
      None => ()
    }
  }
  None
}

///|
fn raw_text(dom : Dom, idx : Int32) -> String {
  if idx < 0 || idx >= dom.nodes.length() {
    return ""
  }
  let b = StringBuilder()
  for child in dom.nodes[idx].children {
    match dom.nodes[child].kind {
      Text(t) => b.write_string(t)
      _ => ()
    }
  }
  b.to_string()
}

///|
fn find_sub(s : String, pattern : String, from : Int32) -> Int32 {
  let a = s.to_array()
  let p = pattern.to_array()
  if p.length() == 0 || p.length() > a.length() {
    return -1
  }
  let mut i = if from < 0 { 0 } else { from }
  while i + p.length() <= a.length() {
    let mut ok = true
    for j = 0; j < p.length(); j = j + 1 {
      if a[i + j] != p[j] {
        ok = false
        break
      }
    }
    if ok {
      return i
    }
    i += 1
  }
  -1
}

///|
fn json_parse_string(raw : String, quote_pos : Int32) -> String? {
  let cs = raw.to_array()
  if quote_pos >= cs.length() || cs[quote_pos] != '"' {
    return None
  }
  let b = StringBuilder()
  let mut i = quote_pos + 1
  while i < cs.length() {
    let c = cs[i]
    if c == '"' {
      return Some(b.to_string())
    }
    if c == '\\' && i + 1 < cs.length() {
      let nxt = cs[i + 1]
      match nxt {
        'n' => b.write_char('\n')
        'r' => b.write_char('\r')
        't' => b.write_char('\t')
        'b' => b.write_char('\u{0008}')
        'f' => b.write_char('\u{000C}')
        '/' => b.write_char('/')
        '"' => b.write_char('"')
        '\\' => b.write_char('\\')
        _ => b.write_char(nxt)
      }
      i += 2
    } else {
      b.write_char(c)
      i += 1
    }
  }
  None
}

///|
/// JSON-LD 基础字段读取：支持字符串、字符串数组、带 name 的对象。
/// 不引入完整 JSON 解析器，保证后端无关与实现可审计。
pub fn jsonld_lookup(raw : String, key : String) -> String? {
  let pattern = "\"" + key + "\""
  let key_pos = find_sub(raw, pattern, 0)
  if key_pos < 0 {
    return None
  }
  let cs = raw.to_array()
  let mut i = key_pos + pattern.length()
  while i < cs.length() && @core.is_whitespace(cs[i]) {
    i += 1
  }
  if i >= cs.length() || cs[i] != ':' {
    return None
  }
  i += 1
  while i < cs.length() && @core.is_whitespace(cs[i]) {
    i += 1
  }
  if i >= cs.length() {
    return None
  }
  if cs[i] == '"' {
    return json_parse_string(raw, i)
  }
  if cs[i] == '[' {
    let mut j = i + 1
    while j < cs.length() && cs[j] != ']' {
      if cs[j] == '"' {
        return json_parse_string(raw, j)
      }
      j += 1
    }
    return None
  }
  if cs[i] == '{' {
    let limit = if i + 400 < cs.length() { i + 400 } else { cs.length() }
    let name_pos = find_sub(raw, "\"name\"", i)
    if name_pos >= 0 && name_pos < limit {
      let mut j = name_pos + 6
      while j < cs.length() && @core.is_whitespace(cs[j]) {
        j += 1
      }
      if j < cs.length() && cs[j] == ':' {
        j += 1
        while j < cs.length() && @core.is_whitespace(cs[j]) {
          j += 1
        }
        if j < cs.length() && cs[j] == '"' {
          return json_parse_string(raw, j)
        }
      }
    }
  }
  None
}

///|
fn host_of(url : String) -> String {
  let mut start = 0
  let marker = find_sub(url, "://", 0)
  if marker >= 0 {
    start = marker + 3
  }
  let cs = url.to_array()
  let b = StringBuilder()
  let mut i = start
  while i < cs.length() && cs[i] != '/' && cs[i] != '?' && cs[i] != '#' {
    b.write_char(cs[i])
    i += 1
  }
  b.to_string()
}

///|
fn collect_meta(dom : Dom) -> (Array[(String, String)], String?) {
  let pairs : Array[(String, String)] = []
  let mut jsonld_raw : String? = None
  for idx in all_nodes(dom) {
    let name = tag(dom, idx)
    let node = dom.nodes[idx]
    match name {
      "title" => pairs.push(("html_title", text_content(dom, idx)))
      "h1" => pairs.push(("first_h1", text_content(dom, idx)))
      "html" =>
        match attr(node, "lang") {
          Some(v) => pairs.push(("html_lang", @core.normalize_ws(v)))
          None => ()
        }
      "time" =>
        match attr(node, "datetime") {
          Some(v) => pairs.push(("time_datetime", @core.normalize_ws(v)))
          None => ()
        }
      "img" =>
        match pick_attr(node, ["src", "data-src", "data-original"]) {
          Some(v) => pairs.push(("first_image", @core.normalize_ws(v)))
          None => ()
        }
      "meta" => {
        let key = match
          pick_attr(node, ["property", "name", "http-equiv", "itemprop"]) {
          Some(v) => @core.ascii_lower(@core.normalize_ws(v))
          None => ""
        }
        let content = @core.normalize_ws(attr_or(node, "content", ""))
        if key != "" && content != "" {
          match key {
            "og:title" => pairs.push(("og_title", content))
            "twitter:title" => pairs.push(("twitter_title", content))
            "og:site_name" => pairs.push(("og_site_name", content))
            "og:description" | "twitter:description" =>
              pairs.push(("og_description", content))
            "description" => pairs.push(("meta_description", content))
            "author" => pairs.push(("meta_author", content))
            "keywords" => pairs.push(("keywords", content))
            "og:image" | "twitter:image" | "og:image:url" =>
              pairs.push(("og_image", content))
            "article:published_time" =>
              pairs.push(("article_published", content))
            "content-language" => pairs.push(("content_language", content))
            "og:url" | "twitter:url" =>
              pairs.push(("url_host", host_of(content)))
            _ => ()
          }
        }
      }
      "script" => {
        let type_value = @core.ascii_lower(attr_or(node, "type", ""))
        if @core.contains_sub(type_value, "ld+json") {
          let raw = @core.normalize_ws(raw_text(dom, idx))
          if raw != "" {
            jsonld_raw = Some(raw)
          }
        }
      }
      _ => ()
    }
    let class_value = @core.ascii_lower(attr_or(node, "class", ""))
    if @core.contains_sub(class_value, "byline") ||
      @core.contains_sub(class_value, "author") {
      let t = text_content(dom, idx)
      if t != "" {
        pairs.push(("class_byline", t))
      }
    }
  }
  (pairs, jsonld_raw)
}

///|
fn split_keywords(raw : String) -> Array[String] {
  let out : Array[String] = []
  let mut b = StringBuilder()
  let cs = raw.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == ',' || cs[i] == '，' {
      let v = @core.normalize_ws(b.to_string())
      if v != "" {
        out.push(v)
      }
      b = StringBuilder()
    } else {
      b.write_char(cs[i])
    }
  }
  let v = @core.normalize_ws(b.to_string())
  if v != "" {
    out.push(v)
  }
  out
}

///|
fn build_meta_fields(dom : Dom) -> @core.MetaFields {
  let (pairs, jsonld_raw) = collect_meta(dom)
  let raw = match jsonld_raw {
    Some(v) => v
    None => ""
  }
  {
    jsonld_headline: jsonld_lookup(raw, "headline"),
    og_title: pick(pairs, "og_title"),
    twitter_title: pick(pairs, "twitter_title"),
    html_title: pick(pairs, "html_title"),
    first_h1: pick(pairs, "first_h1"),
    jsonld_author: jsonld_lookup(raw, "author"),
    meta_author: pick(pairs, "meta_author"),
    class_byline: pick(pairs, "class_byline"),
    og_site_name: pick(pairs, "og_site_name"),
    jsonld_publisher: jsonld_lookup(raw, "publisher"),
    url_host: pick(pairs, "url_host"),
    jsonld_description: jsonld_lookup(raw, "description"),
    og_description: pick(pairs, "og_description"),
    meta_description: pick(pairs, "meta_description"),
    body_first_paragraph: None,
    og_image: pick(pairs, "og_image"),
    jsonld_image: jsonld_lookup(raw, "image"),
    first_image: pick(pairs, "first_image"),
    jsonld_date: jsonld_lookup(raw, "datePublished"),
    article_published: pick(pairs, "article_published"),
    time_datetime: pick(pairs, "time_datetime"),
    html_lang: pick(pairs, "html_lang"),
    content_language: pick(pairs, "content_language"),
    keywords: match pick(pairs, "keywords") {
      Some(v) => split_keywords(v)
      None => []
    },
    jsonld_raw,
  }
}

///|
fn features_of(dom : Dom, idx : Int32) -> @core.Features {
  let node = dom.nodes[idx]
  let text = text_content(dom, idx)
  @core.make_features(
    text.to_array().length(),
    link_text_len(dom, idx),
    child_block_count(dom, idx),
    @core.count_commas(text),
    tag(dom, idx),
    @core.class_weight(attr_or(node, "class", "")),
    @core.id_weight(attr_or(node, "id", "")),
    @core.role_weight(attr_or(node, "role", ""), attr_or(node, "itemprop", "")),
  )
}

///|
fn is_leaf_block(name : String) -> Bool {
  name == "p" ||
  name == "h1" ||
  name == "h2" ||
  name == "h3" ||
  name == "h4" ||
  name == "h5" ||
  name == "h6" ||
  name == "li" ||
  name == "blockquote" ||
  name == "pre" ||
  name == "code" ||
  name == "figcaption" ||
  name == "td" ||
  name == "dt" ||
  name == "dd" ||
  name == "img"
}

///|
fn heading_level(name : String) -> Int32 {
  match name {
    "h1" => 1
    "h2" => 2
    "h3" => 3
    "h4" => 4
    "h5" => 5
    "h6" => 6
    _ => 1
  }
}

///|
fn make_block(name : String, node : Node, text : String) -> @core.Block {
  if name == "img" {
    let src = attr_or(node, "data-src", attr_or(node, "src", ""))
    let alt = match attr(node, "alt") {
      Some(v) => Some(@core.normalize_ws(v))
      None => None
    }
    @core.Image(src, alt)
  } else if @core.starts_with_sub(name, "h") && name.length() == 2 {
    @core.Heading(heading_level(name), text)
  } else if name == "li" {
    @core.ListItem(text)
  } else if name == "blockquote" {
    @core.Quote(text)
  } else if name == "pre" || name == "code" {
    @core.Code(text)
  } else {
    @core.Paragraph(text)
  }
}

///|
fn push_block(out : Array[@core.Block], block : @core.Block) -> Unit {
  // 去掉文档里常见的重复空块与连续重复块。
  let text = @core.block_text(block)
  if text == "" && !matches_image(block) {
    return
  }
  if out.length() > 0 {
    let last = out[out.length() - 1]
    if @core.block_text(last) == text &&
      @core.block_kind(last) == @core.block_kind(block) {
      return
    }
  }
  out.push(block)
}

///|
fn matches_image(block : @core.Block) -> Bool {
  match block {
    @core.Image(_, _) => true
    _ => false
  }
}

///|
fn emit_blocks(
  dom : Dom,
  idx : Int32,
  region : Int32,
  scores : Array[Double],
  out : Array[@core.Block],
) -> Unit {
  if idx < 0 || idx >= dom.nodes.length() {
    return
  }
  let name = tag(dom, idx)
  if name == "" {
    return
  }
  if @core.is_dropped_tag(name) || @core.is_structural_tag(name) {
    return
  }
  if idx != region && scores[idx] < 0.0 {
    return
  }
  let node = dom.nodes[idx]
  if name == "img" {
    let src = attr_or(node, "data-src", attr_or(node, "src", ""))
    if src != "" {
      push_block(out, make_block(name, node, ""))
    }
    return
  }
  if is_leaf_block(name) {
    let text = text_content(dom, idx)
    if text != "" {
      push_block(out, make_block(name, node, text))
    }
    return
  }
  // 容器：先输出「直接挂在自己名下」的文本，再递归子元素。
  let direct = StringBuilder()
  for child in node.children {
    match dom.nodes[child].kind {
      Text(t) => direct.write_string(t)
      _ => ()
    }
  }
  let direct_text = @core.normalize_ws(direct.to_string())
  if direct_text != "" {
    push_block(out, @core.Paragraph(direct_text))
  }
  for child in node.children {
    if is_element(dom, child) {
      emit_blocks(dom, child, region, scores, out)
    }
  }
}

///|
/// 从 HTML 抽取正文块与元数据。任何输入都返回合法结果，不抛错。
pub fn extract_html(html : String) -> Extracted {
  let dom = parse(html)
  let rules = @core.default_rules()
  let nodes = all_nodes(dom)
  let scores : Array[Double] = []
  for _idx in nodes {
    scores.push(0.0)
  }
  let mut candidate_count = 0
  let mut best = -1
  let mut best_score = 0.0
  for idx in nodes {
    let name = tag(dom, idx)
    if @core.is_block_tag(name) && !@core.is_structural_tag(name) {
      let f = features_of(dom, idx)
      if f.text_len >= rules.min_text_len {
        let s = @core.score(f, rules)
        scores[idx] = s
        candidate_count += 1
        if best < 0 || s > best_score {
          best = idx
          best_score = s
        }
      }
    }
  }
  let mut region = best
  if best >= 0 {
    let mut child_score = best_score
    let mut cur = parent(dom, region)
    while cur > 0 {
      let ps = scores[cur]
      if @core.should_merge_parent(ps, child_score, rules) {
        region = cur
        child_score = ps
        cur = parent(dom, cur)
      } else {
        break
      }
    }
  }
  let blocks : Array[@core.Block] = []
  if region >= 0 {
    emit_blocks(dom, region, region, scores, blocks)
  }
  // 降级路径：没有候选块时，用文档里所有非空 <p> 兜底。
  if blocks.length() == 0 {
    for idx in nodes {
      if tag(dom, idx) == "p" {
        let t = text_content(dom, idx)
        if t.to_array().length() >= rules.min_text_len {
          push_block(blocks, @core.Paragraph(t))
        }
      }
    }
  }
  let mut meta = build_meta_fields(dom)
  for block in blocks {
    match meta.body_first_paragraph {
      Some(_) => break
      None =>
        match block {
          @core.Paragraph(t) =>
            // MetaFields 的字段不可变，这里通过重建赋值。
            meta = { ..meta, body_first_paragraph: Some(t), }
          _ => ()
        }
    }
  }
  {
    blocks,
    meta,
    score: if best_score > 0.0 {
      best_score
    } else {
      0.0
    },
    candidate_count,
  }
}
