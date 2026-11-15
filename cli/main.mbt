///|
/// cxtract —— native / js / wasm / wasm-gc 四后端共享的 CLI 入口。
/// 输入通道刻意保持后端无关：命令行参数 + 环境变量 CONTENTKIT_INPUT。

///|
fn main {
  let argv = @env.args()
  let env_input = @env.get_env_var("CONTENTKIT_INPUT")
  println(run(argv, env_input))
}
