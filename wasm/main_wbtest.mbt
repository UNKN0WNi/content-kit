///|
/// wasm / wasm-gc 入口的单元测试。

///|
test "wasm entry produces same bundle" {
  assert_eq(goldenBundle(), @extract.bundle())
  assert_eq(extractJson("<p>x</p>"), @extract.extract_json("<p>x</p>"))
}
