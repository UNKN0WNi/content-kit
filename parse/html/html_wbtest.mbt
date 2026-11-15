///|
/// L1：HTML 词法 / 树构造 / 最小选择器 / 抽取内核单元测试。

///|
test "parse basic tree and attributes" {
  let dom = parse("<DIV id='x' class='a b' data-k=v>Hello &amp; bye</DIV>")
  assert_eq(dom.nodes.length(), 3)
  assert_eq(tag(dom, 1), "div")
  assert_eq(attr(dom.nodes[1], "id"), Some("x"))
  assert_eq(attr(dom.nodes[1], "class"), Some("a b"))
  assert_eq(attr(dom.nodes[1], "data-k"), Some("v"))
  assert_eq(attr(dom.nodes[1], "missing"), None)
  assert_eq(text_content(dom, 1), "Hello & bye")
  assert_eq(parent(dom, 2), 1)
}

///|
test "parse comments doctype and entities" {
  let dom = parse(
    "<!DOCTYPE html><!-- <p>fake</p> --><p>A &lt; B &gt; C &#65; &#x26;</p>",
  )
  let p = query_all(dom, select("p"))
  assert_eq(p.length(), 1)
  assert_eq(text_content(dom, p[0]), "A < B > C A &")
}

///|
test "parse script raw text is not parsed as html" {
  let dom = parse(
    "<script>var x = \"<article><p>FAKE</p></article>\";</script><article><p>REAL</p></article>",
  )
  let scripts = query_all(dom, select("script"))
  assert_eq(scripts.length(), 1)
  let articles = query_all(dom, select("article"))
  assert_eq(articles.length(), 1)
  assert_eq(text_content(dom, articles[0]), "REAL")
  let extracted = extract_html(
    "<script><p>FAKE FAKE FAKE FAKE FAKE</p></script><article><p>REAL REAL REAL REAL REAL</p></article>",
  )
  let all = @core.blocks_text(extracted.blocks)
  assert_eq(@core.contains_sub(all, "FAKE"), false)
  assert_eq(@core.contains_sub(all, "REAL"), true)
}

///|
test "parse implicit close" {
  let dom = parse("<div><p>one<p>two</div>")
  let ps = query_all(dom, select("p"))
  assert_eq(ps.length(), 2)
  assert_eq(text_content(dom, ps[0]), "one")
  assert_eq(text_content(dom, ps[1]), "two")
}

///|
test "parse self closing and void tags" {
  let dom = parse("<div><br><img src='a.png'/><p>x</p></div>")
  assert_eq(query_all(dom, select("img")).length(), 1)
  assert_eq(query_all(dom, select("br")).length(), 1)
  let p = query_all(dom, select("p"))
  assert_eq(parent(dom, p[0]) == 1, true)
}

///|
test "parse malformed never panics" {
  let cases = [
    "", "<", "<<<", "<div", "<p>a", "</p></div>", "<div a='unclosed>", "a < b > c",
    "<p>x</q><span y>", "<!---->", "<?xml version='1.0'?>", "<div><span><b>deep</div>",
  ]
  for html in cases {
    let dom = parse(html)
    assert_true(dom.nodes.length() >= 1)
    let _ = all_nodes(dom)
    let ex = extract_html(html)
    assert_true(ex.blocks.length() >= 0)
  }
}

///|
test "dom helpers and document order" {
  let dom = parse(
    "<body><h1>T</h1><p>a<a href='#'>link</a>b</p><p>c</p></body>",
  )
  let body = body_node(dom)
  assert_eq(tag(dom, body), "body")
  let order = preorder(dom, body)
  assert_eq(tag(dom, order[0]), "body")
  assert_eq(@core.contains_sub(text_content(dom, body), "link"), true)
  assert_eq(link_text_len(dom, body), 4)
  assert_eq(child_block_count(dom, body), 3)
  assert_eq(is_ancestor(dom, body, order[order.length() - 1]), true)
  assert_eq(is_ancestor(dom, -1, body), false)
}

///|
test "selector tag class id attr" {
  let dom = parse(
    "<div id='main' class='post wide'><p class='lead'>A</p><p>B</p><span data-x='1'>C</span></div>",
  )
  assert_eq(query_all(dom, select("div")).length(), 1)
  assert_eq(query_all(dom, select("#main")).length(), 1)
  assert_eq(query_all(dom, select(".lead")).length(), 1)
  assert_eq(query_all(dom, select(".post")).length(), 1)
  assert_eq(query_all(dom, select("[data-x]")).length(), 1)
  assert_eq(query_all(dom, select("[data-x='1']")).length(), 1)
  assert_eq(query_all(dom, select("[data-x='2']")).length(), 0)
  assert_eq(query_all(dom, select("p:not(.lead)")).length(), 1)
}

///|
test "selector descendant combinator" {
  let dom = parse(
    "<article><div class='body'><p>A</p></div></article><div><p>B</p></div>",
  )
  assert_eq(query_all(dom, select("article p")).length(), 1)
  assert_eq(query_all(dom, select("p")).length(), 2)
  assert_eq(query_all(dom, select("article .body p")).length(), 1)
  assert_eq(query_all(dom, select("article div p")).length(), 1)
  assert_eq(query_all(dom, select("footer p")).length(), 0)
}

///|
test "jsonld lookup string array and object" {
  let raw = "{\"headline\":\"标题\",\"author\":{\"name\":\"作者\"},\"publisher\":{\"name\":\"出版方\"},\"image\":[\"a.png\",\"b.png\"],\"datePublished\":\"2026-01-01\"}"
  assert_eq(jsonld_lookup(raw, "headline"), Some("标题"))
  assert_eq(jsonld_lookup(raw, "author"), Some("作者"))
  assert_eq(jsonld_lookup(raw, "publisher"), Some("出版方"))
  assert_eq(jsonld_lookup(raw, "image"), Some("a.png"))
  assert_eq(jsonld_lookup(raw, "datePublished"), Some("2026-01-01"))
  assert_eq(jsonld_lookup(raw, "missing"), None)
  assert_eq(jsonld_lookup("not json", "headline"), None)
  assert_eq(
    jsonld_lookup(
      "{\"headline\":\"\\u6807\\u9898 \\uD83D\\uDE00\"}", "headline",
    ),
    Some("标题 😀"),
  )
  assert_eq(jsonld_lookup("{\"headline\":\"\\uD800\"}", "headline"), None)
}

///|
test "extract picks article over navigation" {
  let html = "<html><head><title>T</title></head><body>" +
    "<nav><a href='#'>导航 导航 导航 导航 导航 导航 导航 导航 导航 导航</a></nav>" +
    "<aside class='sidebar advert'><a href='#'>广告 广告 广告 广告 广告 广告 广告 广告</a></aside>" +
    "<article id='content'><h1>标题</h1>" +
    "<p>这是正文第一段，包含逗号，中文标点，句子结构与足够长的内容以便通过最小长度阈值参与打分竞争。</p>" +
    "<p>这是正文第二段，继续描述同一主题的细节，逗号，句号。并带有更多可用于区分导航与正文的自然语言特征。</p>" +
    "</article><footer>页脚 页脚 页脚 页脚 页脚 页脚</footer></body></html>"
  let ex = extract_html(html)
  let text = @core.blocks_text(ex.blocks)
  assert_eq(@core.contains_sub(text, "这是正文第一段"), true)
  assert_eq(@core.contains_sub(text, "这是正文第二段"), true)
  assert_eq(@core.contains_sub(text, "广告 广告"), false)
  assert_eq(@core.contains_sub(text, "页脚 页脚"), false)
  assert_true(ex.candidate_count > 0)
  assert_true(ex.score > 0.0)
}

///|
test "extract metadata sources" {
  let html = "<html lang='zh-CN'><head><title>HTML 标题</title>" +
    "<meta property='og:title' content='OG 标题'>" +
    "<meta name='author' content='作者'>" +
    "<meta property='og:site_name' content='站点'>" +
    "<meta name='keywords' content='a,b,c'>" +
    "<meta property='article:published_time' content='2026-11-14'>" +
    "</head><body><article><p>正文段落内容足够长，包含逗号，标点，以及可以被正确抽取的自然语言句子结构。</p></article></body></html>"
  let ex = extract_html(html)
  assert_eq(ex.meta.og_title, Some("OG 标题"))
  assert_eq(ex.meta.html_title, Some("HTML 标题"))
  assert_eq(ex.meta.meta_author, Some("作者"))
  assert_eq(ex.meta.og_site_name, Some("站点"))
  assert_eq(ex.meta.keywords, ["a", "b", "c"])
  assert_eq(ex.meta.article_published, Some("2026-11-14"))
  assert_eq(ex.meta.html_lang, Some("zh-CN"))
}

///|
test "extract empty and no content" {
  let a = extract_html("")
  assert_eq(a.blocks.length(), 0)
  assert_eq(a.candidate_count, 0)
  let b = extract_html(
    "<html><head><title>x</title></head><body></body></html>",
  )
  assert_eq(b.blocks.length(), 0)
}

///|
test "raw text elements keep their parent on the stack" {
  let dom = parse(
    "<article><script>var x = 1;</script><style>.x{}</style><p>REAL</p></article>",
  )
  let articles = query_all(dom, select("article"))
  let paragraphs = query_all(dom, select("p"))
  assert_eq(articles.length(), 1)
  assert_eq(paragraphs.length(), 1)
  assert_eq(parent(dom, paragraphs[0]), articles[0])
  assert_eq(text_content(dom, articles[0]), "REAL")
}

///|
test "consecutive block deduplication compares full content" {
  let blocks : Array[@core.Block] = []
  push_block(blocks, @core.Image("a.png", Some("A")))
  push_block(blocks, @core.Image("a.png", Some("A")))
  push_block(blocks, @core.Image("b.png", Some("B")))
  assert_eq(blocks.length(), 2)
  push_block(blocks, @core.Heading(1, "同名"))
  push_block(blocks, @core.Heading(2, "同名"))
  push_block(blocks, @core.Heading(2, "同名"))
  assert_eq(blocks.length(), 4)
}

///|
test "link text includes link ancestors above the traversal root" {
  let dom = parse("<a href='#'><div><p>链接正文</p></div></a>")
  let paragraphs = query_all(dom, select("p"))
  assert_eq(paragraphs.length(), 1)
  assert_eq(link_text_len(dom, paragraphs[0]), 4)
}

///|
test "extract_html fills first paragraph metadata" {
  let extracted = extract_html(
    "<article><h1>标题</h1><p>这是正文第一段，包含足够的文字与逗号，应该成为摘要来源。</p></article>",
  )
  assert_eq(
    extracted.meta.body_first_paragraph,
    Some(
      "这是正文第一段，包含足够的文字与逗号，应该成为摘要来源。",
    ),
  )
}

///|
test "structural descendants are not content candidates" {
  let html = "<nav><p>这是一段足够长的导航文案，包含逗号，但不应成为正文候选。</p></nav>"
  let extracted = extract_html(html)
  assert_eq(extracted.candidate_count, 0)
  assert_eq(extracted.blocks.length(), 0)
}

///|
test "extract block kinds" {
  let html = "<article><h2>标题</h2><p>段落</p><ul><li>项目</li></ul>" +
    "<blockquote>引用</blockquote><pre>代码</pre>" +
    "<img src='a.png' alt='图'></article>"
  let ex = extract_html(html)
  let kinds = StringBuilder()
  for block in ex.blocks {
    kinds.write_string(@core.block_kind(block))
    kinds.write_char(',')
  }
  let k = kinds.to_string()
  assert_eq(@core.contains_sub(k, "heading"), true)
  assert_eq(@core.contains_sub(k, "paragraph"), true)
  assert_eq(@core.contains_sub(k, "list_item"), true)
  assert_eq(@core.contains_sub(k, "quote"), true)
  assert_eq(@core.contains_sub(k, "code"), true)
  assert_eq(@core.contains_sub(k, "image"), true)
}
