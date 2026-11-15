///|
/// 最小选择器子集（ADR-4 的 Plan B）：
/// tag / .class / #id / [attr] / [attr=value] / 后代组合 / :not()。
/// 自实现而非复用 CSS 引擎，保证与本项目自建 DOM 无缝对接且后端无关。

///|
pub(all) enum Simple {
  Tag(String)
  Class(String)
  Id(String)
  Attr(String)
  AttrEq(String, String)
  Neg(Simple)
  And(Simple, Simple)
}

///|
pub(all) struct Selector {
  parts : Array[Simple]
}

///|
fn strip_quotes(s : String) -> String {
  let cs = s.to_array()
  if cs.length() >= 2 {
    let first = cs[0]
    let last = cs[cs.length() - 1]
    if (first == '"' && last == '"') || (first == '\'' && last == '\'') {
      let b = StringBuilder()
      for i = 1; i < cs.length() - 1; i = i + 1 {
        b.write_char(cs[i])
      }
      return b.to_string()
    }
  }
  s
}

///|
fn parse_simple(token : String) -> Simple {
  let cs = token.to_array()
  if cs.length() == 0 {
    return Tag("*")
  }
  if cs[0] == '.' {
    return Class(@core.ascii_lower(token[1:].to_owned()))
  }
  if cs[0] == '#' {
    return Id(token[1:].to_owned())
  }
  if cs[0] == '[' {
    let inner = if @core.ends_with_sub(token, "]") {
      token[1:token.length() - 1].to_owned()
    } else {
      token[1:].to_owned()
    }
    let eq_pos = find_eq(inner)
    if eq_pos >= 0 {
      let key = @core.ascii_lower(@core.normalize_ws(inner[:eq_pos].to_owned()))
      let value = strip_quotes(
        @core.normalize_ws(inner[eq_pos + 1:].to_owned()),
      )
      return AttrEq(key, value)
    }
    return Attr(@core.ascii_lower(@core.normalize_ws(inner)))
  }
  let not_pos = @core.index_of_sub(@core.ascii_lower(token), ":not(", 0)
  if not_pos >= 0 && @core.ends_with_sub(token, ")") {
    let inner = token[not_pos + 5:token.length() - 1].to_owned()
    let neg = Neg(parse_simple(inner))
    if not_pos == 0 {
      return neg
    }
    let head = token[:not_pos].to_owned()
    return And(parse_simple(head), neg)
  }
  Tag(@core.ascii_lower(token))
}

///|
fn find_eq(s : String) -> Int32 {
  let cs = s.to_array()
  for i = 0; i < cs.length(); i = i + 1 {
    if cs[i] == '=' {
      return i
    }
  }
  -1
}

///|
pub fn parse_selector(source : String) -> Selector {
  let parts : Array[Simple] = []
  for token in @core.split_whitespace(source) {
    parts.push(parse_simple(token))
  }
  Selector::{ parts, }
}

///|
fn class_list(node : Node) -> Array[String] {
  match attr(node, "class") {
    Some(v) => @core.split_whitespace(@core.ascii_lower(v))
    None => []
  }
}

///|
fn matches_simple(dom : Dom, idx : Int32, simple : Simple) -> Bool {
  if !is_element(dom, idx) {
    return false
  }
  let node = dom.nodes[idx]
  match simple {
    Tag(name) => name == "*" || tag(dom, idx) == name
    Class(name) => {
      let mut found = false
      for item in class_list(node) {
        if item == name {
          found = true
        }
      }
      found
    }
    Id(name) =>
      match attr(node, "id") {
        Some(v) => v == name
        None => false
      }
    Attr(key) =>
      match attr(node, key) {
        Some(_) => true
        None => false
      }
    AttrEq(key, value) =>
      match attr(node, key) {
        Some(v) => v == value
        None => false
      }
    Neg(inner) => !matches_simple(dom, idx, inner)
    And(left, right) =>
      matches_simple(dom, idx, left) && matches_simple(dom, idx, right)
  }
}

///|
/// 后代组合匹配：parts 从左到右是祖先到自身；
/// chain 从自身到祖先，所以逆序匹配 parts 并在 chain 上单调前进。
pub fn matches(dom : Dom, idx : Int32, sel : Selector) -> Bool {
  if sel.parts.length() == 0 {
    return false
  }
  let chain : Array[Int32] = []
  let mut cur = idx
  while cur >= 0 && cur < dom.nodes.length() {
    chain.push(cur)
    cur = dom.nodes[cur].parent
  }
  let last = sel.parts.length() - 1
  // 最后一个选择器必须命中节点自身，不能命中祖先。
  if !matches_simple(dom, chain[0], sel.parts[last]) {
    return false
  }
  let mut pos = 1
  let mut p = last - 1
  while p >= 0 {
    let mut found = -1
    let mut k = pos
    while k < chain.length() {
      if matches_simple(dom, chain[k], sel.parts[p]) {
        found = k
        break
      }
      k += 1
    }
    if found < 0 {
      return false
    }
    pos = found + 1
    p -= 1
  }
  true
}

///|
pub fn query_all(dom : Dom, sel : Selector) -> Array[Int32] {
  let out : Array[Int32] = []
  for idx in all_nodes(dom) {
    if matches(dom, idx, sel) {
      out.push(idx)
    }
  }
  out
}

///|
pub fn select(source : String) -> Selector {
  parse_selector(source)
}
