///|
/// 元数据收集与优先级归一化（§5.5.4）。
/// MetaFields 只负责「收集」，ResolvedMeta 才负责「按优先级挑选」，
/// 两层分离使得优先级可以被单元测试精确覆盖。

///|
pub(all) struct MetaFields {
  jsonld_headline : String?
  og_title : String?
  twitter_title : String?
  html_title : String?
  first_h1 : String?
  jsonld_author : String?
  meta_author : String?
  class_byline : String?
  og_site_name : String?
  jsonld_publisher : String?
  url_host : String?
  jsonld_description : String?
  og_description : String?
  meta_description : String?
  body_first_paragraph : String?
  og_image : String?
  jsonld_image : String?
  first_image : String?
  jsonld_date : String?
  article_published : String?
  time_datetime : String?
  html_lang : String?
  content_language : String?
  keywords : Array[String]
  jsonld_raw : String?
}

///|
pub fn empty_meta_fields() -> MetaFields {
  {
    jsonld_headline: None,
    og_title: None,
    twitter_title: None,
    html_title: None,
    first_h1: None,
    jsonld_author: None,
    meta_author: None,
    class_byline: None,
    og_site_name: None,
    jsonld_publisher: None,
    url_host: None,
    jsonld_description: None,
    og_description: None,
    meta_description: None,
    body_first_paragraph: None,
    og_image: None,
    jsonld_image: None,
    first_image: None,
    jsonld_date: None,
    article_published: None,
    time_datetime: None,
    html_lang: None,
    content_language: None,
    keywords: [],
    jsonld_raw: None,
  }
}

///|
pub(all) struct ResolvedMeta {
  title : String
  byline : String?
  site_name : String?
  excerpt : String?
  lead_image : String?
  published_at : String?
  lang : String?
}

///|
fn non_empty(v : String?) -> String? {
  match v {
    Some(s) => {
      let normalized = normalize_ws(s)
      if normalized == "" {
        None
      } else {
        Some(normalized)
      }
    }
    None => None
  }
}

///|
/// 从一串候选值中取第一个非空值。
fn first_of(candidates : Array[String?]) -> String? {
  for candidate in candidates {
    match non_empty(candidate) {
      Some(v) => return Some(v)
      None => ()
    }
  }
  None
}

///|
pub fn first_paragraph_text(blocks : Array[Block]) -> String? {
  for block in blocks {
    match block {
      Paragraph(t) => if t != "" { return Some(t) }
      _ => ()
    }
  }
  None
}

///|
pub fn with_first_paragraph(
  fields : MetaFields,
  blocks : Array[Block],
) -> MetaFields {
  match fields.body_first_paragraph {
    Some(_) => fields
    None =>
      match first_paragraph_text(blocks) {
        Some(t) => { ..fields, body_first_paragraph: Some(t), }
        None => fields
      }
  }
}

///|
/// <title> 常带 " - 站点名" 后缀，做一次轻量清洗。
fn clean_title(raw : String) -> String {
  let mut t = normalize_ws(raw)
  let seps = [" | ", " - ", " – ", " — ", " :: ", " _ "]
  for sep in seps {
    if contains_sub(t, sep) {
      // 取最后一段（站点名后缀）之前的全部内容。
      let parts = split_at_last(t, sep)
      match parts {
        Some(head) => if head.length() > 0 { t = head }
        None => ()
      }
      break
    }
  }
  t
}

///|
fn split_at_last(s : String, sep : String) -> String? {
  let a = s.to_array()
  let b = sep.to_array()
  if b.length() == 0 || b.length() > a.length() {
    return None
  }
  let mut found = -1
  let mut i = 0
  while i + b.length() <= a.length() {
    let mut ok = true
    for j = 0; j < b.length(); j = j + 1 {
      if a[i + j] != b[j] {
        ok = false
        break
      }
    }
    if ok {
      found = i
    }
    i += 1
  }
  if found < 0 {
    return None
  }
  let out = StringBuilder()
  for k = 0; k < found; k = k + 1 {
    out.write_char(a[k])
  }
  Some(normalize_ws(out.to_string()))
}

///|
/// 按 §5.5.4 的优先级表解析所有字段。
pub fn resolve(f : MetaFields, excerpt_len : Int32) -> ResolvedMeta {
  let title = match first_of([f.jsonld_headline, f.og_title, f.twitter_title]) {
    Some(t) => t
    None =>
      match non_empty(f.html_title) {
        Some(t) => clean_title(t)
        None =>
          match non_empty(f.first_h1) {
            Some(t) => t
            None => ""
          }
      }
  }
  let excerpt_raw = first_of([
    f.jsonld_description,
    f.og_description,
    f.meta_description,
    f.body_first_paragraph,
  ])
  let excerpt = match excerpt_raw {
    Some(t) => Some(truncate_chars(t, excerpt_len))
    None => None
  }
  {
    title,
    byline: first_of([f.jsonld_author, f.meta_author, f.class_byline]),
    site_name: first_of([f.og_site_name, f.jsonld_publisher, f.url_host]),
    excerpt,
    lead_image: first_of([f.og_image, f.jsonld_image, f.first_image]),
    published_at: first_of([f.jsonld_date, f.article_published, f.time_datetime]),
    lang: first_of([f.html_lang, f.content_language]),
  }
}

///|
/// 把解析结果组装成对外暴露的 Metadata。
pub fn to_metadata(r : ResolvedMeta, f : MetaFields) -> Metadata {
  {
    site_name: r.site_name,
    description: r.excerpt,
    lead_image: r.lead_image,
    lang: r.lang,
    published_at: r.published_at,
    keywords: f.keywords,
    jsonld: f.jsonld_raw,
  }
}
