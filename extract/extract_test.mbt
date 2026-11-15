///|
/// 黑盒测试：只通过公共 API 使用 content-kit，验证发布面的可用性。

///|
test "public API is usable from outside the package" {
  let html = "<html><head><title>公开 API 测试</title></head><body><article><p>这是一段足够长的正文，包含逗号、句号，用于验证外部调用者可以通过公共 API 完成抽取并拿到三种输出。</p></article></body></html>"
  let article = @extract.extract(html)
  assert_eq(article.title, "公开 API 测试")
  assert_true(article.blocks.length() > 0)
  assert_eq(@extract.extract_text(html), article.text)
  assert_eq(@extract.extract_md(html), article.markdown)
  assert_eq(@extract.extract_json(html), @extract.article_to_json(article))
  assert_eq(@extract.current_rules_version(), "1.0.0")
  assert_true(@extract.render_input(html, "md").length() > 0)
}

///|
test "public plain-text API" {
  let a = @extract.extract_plain_text(
    "纯文本第一段，包含逗号。\n\n# 标题\n\n第二段。",
  )
  assert_true(a.blocks.length() >= 2)
  assert_true(a.markdown.length() > 0)
}

///|
test "public bundle and case API" {
  let b = @extract.bundle()
  assert_true(b.length() > 1000)
  assert_eq(@extract.bundle_line("json") + "\n", b)
  assert_true(@extract.corpus_case_names().length() >= 10)
  match @extract.case_output("news-cn", "json") {
    Some(v) => assert_true(v.length() > 100)
    None => assert_true(false)
  }
  assert_eq(@extract.case_output("不存在", "json") == None, true)
  assert_true(@extract.corpus_summary().length() > 50)
}
