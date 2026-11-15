///|
/// wasm / wasm-gc 入口：与 cli 共用同一个门面，产出相同的 Golden Bundle。
/// main 打印结果，moonrun（WASI）即可作为边缘侧的最小可运行形态。

///|
pub fn goldenBundle() -> String {
  @extract.bundle()
}

///|
pub fn extractJson(html : String) -> String {
  @extract.extract_json(html)
}

///|
fn main {
  println(@extract.bundle_line("json"))
}
