///|
/// CLI 的纯逻辑层：参数解析 + 输出生成，不碰任何 IO。
/// main 只负责取 argv / 环境变量并打印结果，因此这一层可以被四后端单元测试覆盖。

///|
pub fn usage() -> String {
  "cxtract - content-kit CLI\n" +
  "usage: cxtract [options]\n" +
  "  --format text|md|json   输出格式（默认 json）\n" +
  "  --case <name>           抽取内置语料中的一篇\n" +
  "  --text <html>           直接抽取一段内联 HTML / 纯文本\n" +
  "  --env-input             从环境变量 CONTENTKIT_INPUT 读取输入\n" +
  "  --list                  列出内置语料名称\n" +
  "  --rules-version         打印规则表版本\n" +
  "  --help                  显示帮助\n" +
  "  无参数时输出全量语料的 Golden Bundle（名称<TAB>JSON，逐行）"
}

///|
fn is_format(value : String) -> Bool {
  value == "text" || value == "md" || value == "markdown" || value == "json"
}

///|
/// 解析参数并返回应当打印到 stdout 的字符串（不含末尾换行）。
pub fn run(args : Array[String], env_input : String?) -> String {
  let mut fmt = "json"
  let mut case_name : String? = None
  let mut inline_text : String? = None
  let mut show_help = false
  let mut show_list = false
  let mut show_rules = false
  let mut use_env = false
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if arg == "--format" && i + 1 < args.length() {
      fmt = args[i + 1]
      i += 2
    } else if arg == "--case" && i + 1 < args.length() {
      case_name = Some(args[i + 1])
      i += 2
    } else if arg == "--text" && i + 1 < args.length() {
      inline_text = Some(args[i + 1])
      i += 2
    } else if arg == "--env-input" {
      use_env = true
      i += 1
    } else if arg == "--list" {
      show_list = true
      i += 1
    } else if arg == "--rules-version" {
      show_rules = true
      i += 1
    } else if arg == "--help" || arg == "-h" {
      show_help = true
      i += 1
    } else {
      i += 1
    }
  }
  if show_help {
    return usage()
  }
  if show_rules {
    return @extract.current_rules_version()
  }
  if show_list {
    let b = StringBuilder()
    let names = @extract.corpus_case_names()
    for k = 0; k < names.length(); k = k + 1 {
      if k > 0 {
        b.write_char('\n')
      }
      b.write_string(names[k])
    }
    return b.to_string()
  }
  if !is_format(fmt) {
    return "cxtract: unknown format: " + fmt
  }
  let mut input : String? = None
  match inline_text {
    Some(t) => input = Some(t)
    None =>
      if use_env {
        match env_input {
          Some(v) => if v != "" { input = Some(v) }
          None => ()
        }
      }
  }
  match input {
    Some(t) => @extract.render_input(t, fmt)
    None =>
      match case_name {
        Some(name) =>
          match @extract.case_output(name, fmt) {
            Some(out) => out
            None => "cxtract: unknown case: " + name
          }
        None => @extract.bundle_line(fmt)
      }
  }
}
