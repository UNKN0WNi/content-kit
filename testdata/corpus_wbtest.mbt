///|
/// 语料库自身的完整性测试（Golden Vector 的元数据）。

///|
test "corpus is complete and names are unique" {
  let cases = cases()
  assert_true(cases.length() >= 14)
  let names = case_names()
  assert_eq(names.length(), cases.length())
  for i = 0; i < names.length(); i = i + 1 {
    for j = i + 1; j < names.length(); j = j + 1 {
      assert_true(names[i] != names[j])
    }
  }
}

///|
test "corpus lookup agrees with cases" {
  for (name, html) in cases() {
    match case_html(name) {
      Some(v) => assert_eq(v, html)
      None => assert_true(false)
    }
  }
  assert_eq(case_html("does-not-exist"), None)
  assert_eq(case_count(), cases().length())
}

///|
test "corpus covers the required scenarios" {
  let names = case_names()
  let required = [
    "news-cn", "blog-en", "docs", "jsonld-only", "entities", "malformed", "no-content",
    "plain", "forum", "meta-priority", "script-noise", "unicode", "empty", "tiny",
  ]
  for want in required {
    let mut found = false
    for got in names {
      if got == want {
        found = true
      }
    }
    assert_eq(found, true)
  }
}
