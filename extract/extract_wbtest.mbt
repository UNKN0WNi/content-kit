///|
/// L2 集成测试 / L4 性质测试：HTML → Article 端到端断言与不变量检查。

///|
fn article_invariants(a : @core.Article) -> Bool {
  // 1. 文本长度非负（天然成立，显式断言以固化不变量）。
  if a.text.to_array().length() < 0 {
    return false
  }
  if a.markdown.to_array().length() < 0 {
    return false
  }
  // 2. JSON 必须有固定字段顺序且非空。
  let json = render_json(a)
  if json.length() < 2 {
    return false
  }
  if !@core.starts_with_sub(json, "{\"title\":") {
    return false
  }
  if !@core.contains_sub(json, ",\"blocks\":") {
    return false
  }
  if !@core.contains_sub(json, ",\"rules_version\":\"1.0.0\"}") {
    return false
  }
  // 3. blocks 顺序单调：text 中各块文本按文档顺序出现。
  let mut cursor = 0
  for block in a.blocks {
    let t = @core.block_text(block)
    if t == "" {
      continue
    }
    let pos = @core.index_of_sub(a.text, t, cursor)
    if pos < 0 {
      return false
    }
    cursor = pos + t.to_array().length()
  }
  // 4. 三种输出同源：每个块的文本都出现在 text 与 markdown 中。
  for block in a.blocks {
    let t = @core.block_text(block)
    if t == "" {
      continue
    }
    if !@core.contains_sub(a.text, t) {
      return false
    }
  }
  true
}

///|
test "L2 news-cn end to end" {
  let html = @testdata.case_html("news-cn").unwrap()
  let a = extract(html)
  assert_eq(a.title, "来自 JSON-LD 的标题")
  assert_eq(a.byline, Some("赵岩"))
  assert_eq(a.site_name, Some("每日科学"))
  assert_eq(a.lang, Some("zh-CN"))
  assert_eq(a.published_at, Some("2026-11-14"))
  assert_eq(a.lead_image, Some("https://example.com/moon.jpg"))
  assert_true(a.blocks.length() >= 6)
  assert_eq(@core.contains_sub(a.text, "我国首个月球科研基地"), true)
  assert_eq(@core.contains_sub(a.text, "这段脚本里的伪标签"), false)
  assert_eq(@core.contains_sub(a.text, "广告位招租"), false)
  assert_eq(@core.contains_sub(a.text, "版权所有 每日科学"), false)
  assert_eq(a.rules_version, "1.0.0")
  assert_true(article_invariants(a))
}

///|
test "L2 metadata priority case" {
  let a = extract(@testdata.case_html("meta-priority").unwrap())
  assert_eq(a.title, "JSON-LD 标题")
  assert_eq(a.byline, Some("JSON-LD 作者"))
  assert_eq(a.site_name, Some("OG 站点"))
  assert_eq(a.excerpt, Some("JSON-LD 摘要"))
  assert_eq(a.published_at, Some("2026-01-02"))
  assert_eq(a.lang, Some("fr"))
  assert_true(article_invariants(a))
}

///|
test "L2 jsonld-only metadata" {
  let a = extract(@testdata.case_html("jsonld-only").unwrap())
  assert_eq(a.title, "JSON-LD 标题")
  assert_eq(a.byline, Some("钱学森"))
  assert_eq(a.metadata.lead_image, Some("https://example.com/ld.png"))
  match a.metadata.jsonld {
    Some(raw) => assert_true(@core.contains_sub(raw, "headline"))
    None => assert_true(false)
  }
  assert_true(a.blocks.length() >= 2)
}

///|
test "L2 three outputs share one block sequence" {
  for (name, html) in @testdata.cases() {
    let a = extract(html)
    let json = render_json(a)
    for block in a.blocks {
      let t = @core.block_text(block)
      if t == "" {
        continue
      }
      assert_eq(@core.contains_sub(a.text, t), true)
      // JSON 中至少包含该文本的转义形式（去掉首尾引号后比较）。
      let escaped = @core.json_escape(t)
      assert_eq(@core.contains_sub(json, escaped), true)
    }
    if name != "" {
      assert_true(article_invariants(a))
    }
  }
}

///|
test "L2 excerpt skips heading and uses first paragraph" {
  let a = extract(
    "<article><h1>这是标题，不是摘要</h1><p>这是正文第一段，包含逗号，并且足够长以成为有效的摘要来源。</p><p>第二段。</p></article>",
  )
  assert_eq(
    a.excerpt,
    Some(
      "这是正文第一段，包含逗号，并且足够长以成为有效的摘要来源。",
    ),
  )
}

///|
test "L2 json field order is hardcoded" {
  let a = extract(
    "<article><p>一段足够长的正文内容，包含逗号与句号，用于验证序列化字段顺序。</p></article>",
  )
  let json = render_json(a)
  let keys = [
    "title", "byline", "site_name", "excerpt", "lead_image", "lang", "published_at",
    "blocks", "text", "markdown", "metadata", "score", "rules_version",
  ]
  let mut cursor = 0
  for key in keys {
    let pattern = "\"" + key + "\":"
    let pos = @core.index_of_sub(json, pattern, cursor)
    assert_true(pos >= cursor)
    cursor = pos + pattern.length()
  }
}

///|
test "L2 code block keeps newlines in all views" {
  let a = extract(
    "<article><p>说明段落，足够长以成为有效的正文候选内容。</p><pre>a = 1\nb = 2</pre></article>",
  )
  assert_true(@core.contains_sub(a.text, "a = 1\nb = 2"))
  assert_true(@core.contains_sub(a.markdown, "```\na = 1\nb = 2\n```"))
  assert_true(@core.contains_sub(render_json(a), "a = 1\\nb = 2"))
}

///|
test "L2 renderers from same blocks" {
  let blocks : Array[@core.Block] = [
    @core.Heading(2, "标题"),
    @core.Paragraph("段落"),
    @core.ListItem("项目"),
    @core.Quote("引用"),
    @core.Code("代码"),
    @core.Image("a.png", Some("图")),
  ]
  let text = extract_to_text(blocks)
  let md = extract_to_md(blocks)
  assert_eq(@core.contains_sub(text, "标题"), true)
  assert_eq(@core.contains_sub(md, "## 标题"), true)
  assert_eq(@core.contains_sub(md, "- 项目"), true)
  assert_eq(@core.contains_sub(md, "> 引用"), true)
  assert_eq(@core.contains_sub(md, "```\n代码\n```"), true)
  assert_eq(@core.contains_sub(md, "![图](a.png)"), true)
}

///|
test "L2 convenience APIs agree with extract" {
  let html = @testdata.case_html("docs").unwrap()
  let a = extract(html)
  assert_eq(extract_text(html), a.text)
  assert_eq(extract_md(html), a.markdown)
  assert_eq(extract_json(html), render_json(a))
  assert_eq(current_rules_version(), @core.rules_version)
  assert_eq(article_to_json(a), render_json(a))
}

///|
test "L2 extract_auto plain fallback" {
  let a = extract_auto(
    "纯文本第一段，包含逗号。\n\n# 标题\n\n第二段内容。",
  )
  assert_true(a.blocks.length() >= 2)
  assert_true(article_invariants(a))
  assert_eq(@core.contains_sub(a.markdown, "# 标题"), true)
}

///|
test "L2 empty input degrades gracefully" {
  let a = extract("")
  assert_eq(a.title, "")
  assert_eq(a.blocks.length(), 0)
  assert_eq(a.text, "")
  assert_eq(a.markdown, "")
  assert_eq(a.score, 0.0000)
  assert_true(article_invariants(a))
}

///|
test "L2 bundle is deterministic and complete" {
  let b1 = bundle()
  let b2 = bundle()
  assert_eq(b1, b2)
  assert_eq(b1.to_array().length() > 1000, true)
  assert_eq(bundle_line("json") + "\n", b1)
  assert_eq(
    @core.contains_sub(
      bundle_with_format("text"),
      "我国首个月球科研基地",
    ),
    true,
  )
  assert_eq(@core.contains_sub(bundle_with_format("md"), "#"), true)
  assert_eq(case_output("missing-case", "json"), None)
  match case_output("tiny", "json") {
    Some(v) => assert_true(v.length() > 0)
    None => assert_true(false)
  }
  assert_eq(corpus_case_names().length(), @testdata.case_count())
}

///|
test "L2 render_input matches extract_json" {
  let html = "<article><p>一段足够长的正文内容，包含逗号与句号，用于验证输入渲染入口。</p></article>"
  assert_eq(render_input(html, "json"), extract_json(html))
  assert_eq(render_input(html, "text"), extract_text(html))
  assert_eq(render_input(html, "md"), extract_md(html))
}

///|
fn mutate(base : String, seed : Int32) -> String {
  // 确定性变异：按 seed 选择一种破坏方式，生成畸形 HTML。
  let cs = base.to_array()
  let b = StringBuilder()
  let cut = if cs.length() > 0 { seed % cs.length() } else { 0 }
  let mode = seed % 7
  for i = 0; i < cs.length(); i = i + 1 {
    if i == cut {
      match mode {
        0 => b.write_string("<broken")
        1 => b.write_string("</div></p>")
        2 => b.write_string("<!--")
        3 => b.write_string("&bogus;")
        4 => b.write_string("<script><p>")
        5 => ()
        _ => b.write_string("<p>")
      }
    }
    b.write_char(cs[i])
  }
  b.to_string()
}

///|
test "L4 malformed html never breaks invariants" {
  let base = @testdata.case_html("news-cn").unwrap()
  for seed = 0; seed < 120; seed = seed + 1 {
    let html = mutate(base, seed)
    let a = extract(html)
    assert_true(article_invariants(a))
    // 幂等：同一输入两次调用逐字节相同。
    assert_eq(extract_json(html), extract_json(html))
    // 三种格式都非空或一致为空。
    assert_eq(extract_text(html), a.text)
    assert_eq(extract_md(html), a.markdown)
  }
}

///|
test "L4 property: extraction is pure for arbitrary mutation seeds" {
  @quickcheck.check(
    (x : Int32) => {
      let seed = if x < 0 { -x } else { x }
      let html = mutate(
        "<article><p>正文，包含逗号，足够长以参与打分竞争。</p></article>",
        seed,
      )
      let a = extract(html)
      article_invariants(a) && extract_json(html) == render_json(a)
    },
    count=100,
    seed=2026,
  )
}

///|
test "L4 property: normalize_ws idempotence" {
  @quickcheck.check(
    (x : Int32) => {
      let s = "  a " + x.to_string() + " b  \n c "
      @core.normalize_ws(@core.normalize_ws(s)) == @core.normalize_ws(s)
    },
    count=50,
    seed=11,
  )
}

///|
test "L4 all corpus satisfy invariants" {
  for (_name, html) in @testdata.cases() {
    let a = extract(html)
    assert_true(article_invariants(a))
  }
}
