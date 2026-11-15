///|
/// L1：core/ 纯函数单元测试。

///|
test "ascii_lower" {
  assert_eq(ascii_lower("Hello WORLD-123 中文"), "hello world-123 中文")
  assert_eq(ascii_lower(""), "")
}

///|
test "normalize_ws" {
  assert_eq(normalize_ws("  a \t\n  b  c  "), "a b c")
  assert_eq(normalize_ws("\n\n"), "")
  assert_eq(normalize_ws("中文　全角空格"), "中文 全角空格")
}

///|
test "decode_entities named" {
  assert_eq(
    decode_entities("a &amp; b &lt;c&gt; &quot;d&quot; &apos;e&apos;"),
    "a & b <c> \"d\" 'e'",
  )
  assert_eq(decode_entities("&nbsp;&copy;&mdash;&hellip;"), " ©—…")
  assert_eq(decode_entities("&unknown; &bogus"), "&unknown; &bogus")
}

///|
test "decode_entities numeric" {
  assert_eq(decode_entities("&#65;&#66;&#67;"), "ABC")
  assert_eq(decode_entities("&#x26; &#39;"), "& '")
  assert_eq(decode_entities("&#0;"), "")
}

///|
test "count_commas mixed" {
  assert_eq(count_commas("a,b，c、d;e；f:g：h.i"), 8)
  assert_eq(count_commas("no punctuation here"), 0)
}

///|
test "truncate_chars keeps surrogate pairs" {
  let s = "a😀b🌕c"
  assert_eq(truncate_chars(s, 2), "a😀")
  assert_eq(truncate_chars(s, 100), s)
  assert_eq(truncate_chars(s, 0), "")
}

///|
test "substring helpers" {
  assert_eq(contains_sub("Hello World", "lo Wo"), true)
  assert_eq(contains_sub("Hello", "hello"), false)
  assert_eq(contains_sub("a", ""), true)
  assert_eq(starts_with_sub("content-kit", "content"), true)
  assert_eq(ends_with_sub("content-kit", "kit"), true)
  assert_eq(split_whitespace("  a  b\tc "), ["a", "b", "c"])
}

///|
test "json_escape" {
  assert_eq(json_escape("a\"b\\c\nd\te"), "a\\\"b\\\\c\\nd\\te")
  assert_eq(json_escape("\u{0001}"), "\\u0001")
  assert_eq(json_string("中文 😀"), "\"中文 😀\"")
  assert_eq(json_nullable(None), "null")
  assert_eq(json_nullable(Some("x")), "\"x\"")
  assert_eq(json_string_array(["a", "b\"c"]), "[\"a\",\"b\\\"c\"]")
}

///|
test "json_number is fixed and deterministic" {
  assert_eq(json_number(0.0), "0.0000")
  assert_eq(json_number(1.0), "1.0000")
  assert_eq(json_number(3.14159), "3.1416")
  assert_eq(json_number(-2.5), "-2.5000")
  assert_eq(json_number(12.0 + 0.25), "12.2500")
}

///|
test "rules tables" {
  assert_eq(is_block_tag("ARTICLE"), true)
  assert_eq(is_block_tag("span"), false)
  assert_eq(is_dropped_tag("SCRIPT"), true)
  assert_eq(is_void_tag("img"), true)
  assert_eq(is_void_tag("div"), false)
  assert_eq(is_implicit_close("p"), true)
  assert_eq(is_structural_tag("nav"), true)
  assert_eq(base_weight("article"), 5.0)
  assert_eq(base_weight("div"), 0.5)
  assert_eq(base_weight("span"), 0.0)
}

///|
test "class id role weights" {
  assert_eq(class_weight("sidebar advert related"), 1.0)
  assert_eq(class_weight("article-body"), 0.0)
  assert_eq(id_weight("main-content"), 0.5)
  assert_eq(id_weight("ad-banner"), 0.0)
  assert_eq(role_weight("article", ""), 0.5)
  assert_eq(role_weight("", "articleBody"), 1.0)
  assert_eq(role_weight("", ""), 0.0)
}

///|
test "default_rules and version" {
  let r = default_rules()
  assert_eq(rules_version, "1.0.0")
  assert_eq(r.cap, 3.0)
  assert_eq(r.parent_ratio, 0.2)
  assert_eq(r.min_text_len, 12)
  assert_eq(r.excerpt_len, 160)
}

///|
test "scoring exact formula" {
  let r = default_rules()
  let f = make_features(200, 20, 3, 2, "article", 0.0, 0.0, 0.0)
  // base 5 + 1*min(2,3)=2 + .5*min(3,3)=1.5 + .5*min(2,3)=1
  // + .5*min(.2,3)=0.1 - .25*min(20/3,3)=0.75
  let expected = 5.0 + 2.0 + 1.5 + 1.0 + 0.1 - 0.75
  let got = score(f, r)
  assert_true(got > expected - 0.0001 && got < expected + 0.0001)
}

///|
test "scoring caps and zero paragraphs" {
  let r = default_rules()
  let huge = make_features(100000, 100000, 100, 100, "div", 0.0, 0.0, 0.0)
  let capped = score(huge, r)
  assert_true(capped < 20.0)
  let zero = make_features(0, 0, 0, 0, "div", 0.0, 0.0, 0.0)
  assert_true(score(zero, r) == 0.5)
  assert_eq(link_per_paragraph(zero), 0.0)
}

///|
test "scoring negative class penalty" {
  let r = default_rules()
  let clean = make_features(50, 0, 1, 1, "div", 0.0, 0.0, 0.0)
  let dirty = make_features(50, 0, 1, 1, "div", 1.0, 0.0, 0.0)
  assert_true(score(dirty, r) < score(clean, r))
  let diff = score(clean, r) - score(dirty, r)
  assert_true(diff > 1.4999 && diff < 1.5001)
}

///|
test "should_merge_parent" {
  let r = default_rules()
  assert_eq(should_merge_parent(3.0, 10.0, r), true)
  assert_eq(should_merge_parent(1.0, 10.0, r), false)
  assert_eq(should_merge_parent(0.0, 10.0, r), false)
}

///|
test "metadata priority" {
  let f = {
    ..empty_meta_fields(),
    jsonld_headline: Some("JSON-LD 标题"),
    og_title: Some("OG 标题"),
    html_title: Some("HTML 标题 - 站点"),
    first_h1: Some("H1 标题"),
    jsonld_author: Some("JSON-LD 作者"),
    meta_author: Some("Meta 作者"),
    og_site_name: Some("OG 站点"),
    jsonld_publisher: Some("JSON-LD 出版方"),
    og_description: Some("OG 摘要"),
    meta_description: Some("Meta 摘要"),
    og_image: Some("og.png"),
    jsonld_image: Some("ld.png"),
    jsonld_date: Some("2026-01-01"),
    article_published: Some("2026-02-02"),
    html_lang: Some("zh-CN"),
    content_language: Some("en"),
    keywords: ["a", "b"],
  }
  let r = resolve(f, 160)
  assert_eq(r.title, "JSON-LD 标题")
  assert_eq(r.byline, Some("JSON-LD 作者"))
  assert_eq(r.site_name, Some("OG 站点"))
  assert_eq(r.excerpt, Some("OG 摘要"))
  assert_eq(r.lead_image, Some("og.png"))
  assert_eq(r.published_at, Some("2026-01-01"))
  assert_eq(r.lang, Some("zh-CN"))
  let m = to_metadata(r, f)
  assert_eq(m.keywords, ["a", "b"])
}

///|
test "metadata fallbacks and title cleanup" {
  let f = {
    ..empty_meta_fields(),
    html_title: Some("  正文标题  -  站点名  "),
    body_first_paragraph: Some("第一段正文"),
    first_image: Some("fallback.png"),
  }
  let r = resolve(f, 10)
  assert_eq(r.title, "正文标题")
  assert_eq(r.excerpt, Some("第一段正文"))
  assert_eq(r.lead_image, Some("fallback.png"))
  assert_eq(r.site_name, None)
  let empty = resolve(empty_meta_fields(), 160)
  assert_eq(empty.title, "")
  assert_eq(empty.excerpt, None)
}

///|
test "metadata excerpt truncation" {
  let f = {
    ..empty_meta_fields(),
    og_description: Some("abcdefghijklmnopqrstuvwxyz"),
  }
  let r = resolve(f, 5)
  assert_eq(r.excerpt, Some("abcde"))
}

///|
test "block helpers" {
  assert_eq(block_text(Paragraph("p")), "p")
  assert_eq(block_text(Heading(2, "h")), "h")
  assert_eq(block_text(Image("a.png", None)), "")
  assert_eq(block_kind(Code("x")), "code")
  assert_eq(block_kind(ListItem("x")), "list_item")
  assert_eq(block_kind(Image("a", Some("b"))), "image")
  let m = empty_metadata()
  assert_eq(m.jsonld, None)
  assert_eq(m.keywords.length(), 0)
}
