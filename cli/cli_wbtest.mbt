///|
/// CLI 纯逻辑层的单元测试（四后端可跑，不依赖真实进程 IO）。

///|
test "cli help and rules version" {
  assert_eq(run(["--help"], None).length() > 50, true)
  assert_eq(run(["--rules-version"], None), "1.0.0")
  assert_eq(run([], None) == run([], None), true)
}

///|
test "cli format validation" {
  assert_eq(run(["--format", "xml"], None), "cxtract: unknown format: xml")
  assert_true(run(["--format", "text"], None).length() > 100)
  assert_true(run(["--format", "md"], None).length() > 100)
  assert_true(run(["--format", "json"], None).length() > 100)
}

///|
test "cli case selection" {
  let out = run(["--case", "news-cn", "--format", "text"], None)
  assert_true(out.length() > 50)
  assert_eq(
    run(["--case", "not-exist"], None),
    "cxtract: unknown case: not-exist",
  )
  let list = run(["--list"], None)
  assert_true(list.length() > 20)
}

///|
test "cli inline text and env input" {
  let html = "<article><p>一段足够长的正文内容，包含逗号与句号，用于验证 CLI 输入通道。</p></article>"
  let a = run(["--text", html, "--format", "text"], None)
  assert_true(a.length() > 20)
  let j = run(["--text", html, "--format", "json"], None)
  assert_true(j.length() > 100)
  let from_env = run(["--env-input"], Some(html))
  assert_eq(from_env, run(["--text", html], None))
  assert_eq(run(["--env-input"], None), run([], None))
}

///|
test "cli default bundle equals library bundle" {
  assert_eq(run([], None), @extract.bundle_line("json"))
}
