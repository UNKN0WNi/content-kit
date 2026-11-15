///|
/// 轻量 HTML 词法 + 树构造（Plan B：自实现最小子集）。
///
/// 目标不是完整 HTML5 一致性，而是：
///   1. 后端无关（只用 prelude 与 core/ 的纯函数）；
///   2. 任何输入都不 panic（畸形、未闭合、孤立 '<' 全部安全降级）；
///   3. 覆盖内容抽取需要的结构：标签、属性、注释、实体、隐式闭合、
///      script/style 原始文本跳过。

///|
pub(all) enum NodeKind {
  Element(String)
  Text(String)
  Comment
}

///|
pub(all) struct Node {
  kind : NodeKind
  attrs : Array[(String, String)]
  children : Array[Int32]
  parent : Int32
  order : Int32
}

///|
pub(all) struct Dom {
  nodes : Array[Node]
  root : Int32
}

///|
fn make_node(
  kind : NodeKind,
  attrs : Array[(String, String)],
  parent : Int32,
  order : Int32,
) -> Node {
  { kind, attrs, children: [], parent, order, }
}

///|
pub fn tag_of(kind : NodeKind) -> String {
  match kind {
    Element(t) => t
    Text(_) => ""
    Comment => ""
  }
}

///|
pub fn tag(dom : Dom, idx : Int32) -> String {
  if idx < 0 || idx >= dom.nodes.length() {
    return ""
  }
  tag_of(dom.nodes[idx].kind)
}

///|
pub fn is_element(dom : Dom, idx : Int32) -> Bool {
  if idx < 0 || idx >= dom.nodes.length() {
    return false
  }
  match dom.nodes[idx].kind {
    Element(_) => true
    _ => false
  }
}

///|
pub fn attr(node : Node, key : String) -> String? {
  let low = @core.ascii_lower(key)
  for (name, value) in node.attrs {
    if name == low {
      return Some(value)
    }
  }
  None
}

///|
pub fn attr_or(node : Node, key : String, fallback : String) -> String {
  match attr(node, key) {
    Some(v) => v
    None => fallback
  }
}

///|
fn skip_ws(cs : Array[Char], i : Int32, n : Int32) -> Int32 {
  let mut j = i
  while j < n && @core.is_whitespace(cs[j]) {
    j += 1
  }
  j
}

///|
fn read_raw_text(
  cs : Array[Char],
  i : Int32,
  n : Int32,
  tag : String,
) -> (String, Int32) {
  let b = StringBuilder()
  let mut j = i
  while j < n {
    if cs[j] == '<' && j + 1 < n && cs[j + 1] == '/' {
      let name_b = StringBuilder()
      let mut k = j + 2
      while k < n && cs[k] != '>' && !@core.is_whitespace(cs[k]) {
        name_b.write_char(cs[k])
        k += 1
      }
      if @core.ascii_lower(name_b.to_string()) == tag {
        while k < n && cs[k] != '>' {
          k += 1
        }
        if k < n {
          k += 1
        }
        return (b.to_string(), k)
      }
    }
    b.write_char(cs[j])
    j += 1
  }
  (b.to_string(), n)
}

///|
/// 把任意 HTML 字符串解析成 Dom。永不抛错。
pub fn parse(html : String) -> Dom {
  let cs = html.to_array()
  let n = cs.length()
  let nodes : Array[Node] = []
  nodes.push(make_node(Element("#document"), [], -1, 0))
  let stack : Array[Int32] = [0]
  let mut order = 1
  let mut i = 0
  while i < n {
    if cs[i] == '<' {
      if i + 3 < n && cs[i + 1] == '!' && cs[i + 2] == '-' && cs[i + 3] == '-' {
        // 注释：整体跳到 "-->"，不建节点。
        i += 4
        while i + 2 < n &&
              !(cs[i] == '-' && cs[i + 1] == '-' && cs[i + 2] == '>') {
          i += 1
        }
        i = if i + 2 < n { i + 3 } else { n }
      } else if i + 1 < n && (cs[i + 1] == '!' || cs[i + 1] == '?') {
        // DOCTYPE / 处理指令。
        i += 2
        while i < n && cs[i] != '>' {
          i += 1
        }
        i += 1
      } else if i + 1 < n && cs[i + 1] == '/' {
        // 结束标签：向栈上找最近的同名元素并把它连同其上层一起弹出。
        i += 2
        let name_b = StringBuilder()
        while i < n && cs[i] != '>' && !@core.is_whitespace(cs[i]) {
          name_b.write_char(cs[i])
          i += 1
        }
        while i < n && cs[i] != '>' {
          i += 1
        }
        if i < n {
          i += 1
        }
        let name = @core.ascii_lower(name_b.to_string())
        let mut k = stack.length() - 1
        let mut found = 0
        while k > 0 {
          if tag_of(nodes[stack[k]].kind) == name {
            found = k
            break
          }
          k -= 1
        }
        while found > 0 && stack.length() > found {
          let _ = stack.pop()
        }
      } else if i + 1 < n &&
        (@core.is_whitespace(cs[i + 1]) || cs[i + 1] == '>') {
        // 孤立的 '<'，当作普通文本。
        let parent = stack[stack.length() - 1]
        let idx = nodes.length()
        nodes.push(make_node(Text("<"), [], parent, order))
        order += 1
        nodes[parent].children.push(idx)
        i += 1
      } else {
        // 开始标签。
        i += 1
        let name_b = StringBuilder()
        while i < n &&
              !@core.is_whitespace(cs[i]) &&
              cs[i] != '>' &&
              cs[i] != '/' {
          name_b.write_char(cs[i])
          i += 1
        }
        let name_len = name_b.to_string().length()
        if name_len == 0 {
          // 无法识别，跳过这个字符，防止死循环。
          i += 1
        } else {
          let tag_name = @core.ascii_lower(name_b.to_string())
          let attrs : Array[(String, String)] = []
          let mut self_closing = false
          let mut closed = false
          while i < n && !closed {
            i = skip_ws(cs, i, n)
            if i >= n {
              break
            }
            if cs[i] == '>' {
              i += 1
              closed = true
            } else if cs[i] == '/' && i + 1 < n && cs[i + 1] == '>' {
              self_closing = true
              i += 2
              closed = true
            } else if cs[i] == '/' {
              i += 1
            } else {
              let key_b = StringBuilder()
              while i < n &&
                    !@core.is_whitespace(cs[i]) &&
                    cs[i] != '=' &&
                    cs[i] != '>' &&
                    cs[i] != '/' {
                key_b.write_char(cs[i])
                i += 1
              }
              let key = @core.ascii_lower(key_b.to_string())
              i = skip_ws(cs, i, n)
              let mut value = ""
              if i < n && cs[i] == '=' {
                i += 1
                i = skip_ws(cs, i, n)
                if i < n && (cs[i] == '"' || cs[i] == '\'') {
                  let quote = cs[i]
                  i += 1
                  let vb = StringBuilder()
                  while i < n && cs[i] != quote {
                    vb.write_char(cs[i])
                    i += 1
                  }
                  if i < n {
                    i += 1
                  }
                  value = vb.to_string()
                } else {
                  let vb = StringBuilder()
                  while i < n && !@core.is_whitespace(cs[i]) && cs[i] != '>' {
                    vb.write_char(cs[i])
                    i += 1
                  }
                  value = vb.to_string()
                }
              }
              if key != "" {
                attrs.push((key, @core.decode_entities(value)))
              } else {
                i += 1
              }
            }
          }
          // 隐式闭合：同名块级元素相遇时先关掉上一个。
          if @core.is_implicit_close(tag_name) && stack.length() > 1 {
            let top = stack[stack.length() - 1]
            if tag_of(nodes[top].kind) == tag_name {
              let _ = stack.pop()
            }
          }
          let parent = stack[stack.length() - 1]
          let idx = nodes.length()
          nodes.push(make_node(Element(tag_name), attrs, parent, order))
          order += 1
          nodes[parent].children.push(idx)
          let is_raw = tag_name == "script" ||
            tag_name == "style" ||
            tag_name == "noscript" ||
            tag_name == "template"
          if is_raw {
            let (raw, next) = read_raw_text(cs, i, n, tag_name)
            let tidx = nodes.length()
            nodes.push(make_node(Text(raw), [], idx, order))
            order += 1
            nodes[idx].children.push(tidx)
            i = next
          } else if !self_closing && !@core.is_void_tag(tag_name) {
            stack.push(idx)
          }
        }
      }
    } else {
      // 普通文本。
      let tb = StringBuilder()
      while i < n && cs[i] != '<' {
        tb.write_char(cs[i])
        i += 1
      }
      let parent = stack[stack.length() - 1]
      let idx = nodes.length()
      nodes.push(
        make_node(
          Text(@core.decode_entities(tb.to_string())),
          [],
          parent,
          order,
        ),
      )
      order += 1
      nodes[parent].children.push(idx)
    }
  }
  { nodes, root: 0, }
}

///|
fn collect_text(dom : Dom, idx : Int32, b : StringBuilder) -> Unit {
  if idx < 0 || idx >= dom.nodes.length() {
    return
  }
  let stack : Array[(Int32, Bool)] = [(idx, false)]
  while stack.length() > 0 {
    let (cur, visited) = stack[stack.length() - 1]
    let _ = stack.pop()
    if cur < 0 || cur >= dom.nodes.length() {
      continue
    }
    let node = dom.nodes[cur]
    match node.kind {
      Text(t) => if !visited { b.write_string(t) }
      Comment => ()
      Element(name) =>
        if @core.is_dropped_tag(name) {
          ()
        } else if visited {
          if name == "br" || name == "p" || name == "div" || name == "li" {
            b.write_char(' ')
          }
        } else {
          stack.push((cur, true))
          let mut k = node.children.length() - 1
          while k >= 0 {
            stack.push((node.children[k], false))
            k -= 1
          }
        }
    }
  }
}

///|
pub fn text_content(dom : Dom, idx : Int32) -> String {
  let b = StringBuilder()
  collect_text(dom, idx, b)
  @core.normalize_ws(b.to_string())
}

///|
fn collect_link_text(dom : Dom, idx : Int32, b : StringBuilder) -> Unit {
  if idx < 0 || idx >= dom.nodes.length() {
    return
  }
  let mut root = idx
  let mut root_inside_a = false
  while root >= 0 {
    if tag_of(dom.nodes[root].kind) == "a" {
      root_inside_a = true
      break
    }
    root = parent(dom, root)
  }
  let stack : Array[(Int32, Bool)] = [(idx, root_inside_a)]
  while stack.length() > 0 {
    let (cur, inside_a) = stack[stack.length() - 1]
    let _ = stack.pop()
    if cur < 0 || cur >= dom.nodes.length() {
      continue
    }
    let node = dom.nodes[cur]
    match node.kind {
      Text(t) => if inside_a { b.write_string(t) }
      Comment => ()
      Element(name) =>
        if !@core.is_dropped_tag(name) {
          let child_inside_a = inside_a || name == "a"
          let mut k = node.children.length() - 1
          while k >= 0 {
            stack.push((node.children[k], child_inside_a))
            k -= 1
          }
        }
    }
  }
}

///|
pub fn link_text_len(dom : Dom, idx : Int32) -> Int32 {
  let b = StringBuilder()
  collect_link_text(dom, idx, b)
  @core.normalize_ws(b.to_string()).to_array().length()
}

///|
pub fn child_block_count(dom : Dom, idx : Int32) -> Int32 {
  if idx < 0 || idx >= dom.nodes.length() {
    return 0
  }
  let mut count = 0
  for child in dom.nodes[idx].children {
    if @core.is_block_tag(tag(dom, child)) {
      count += 1
    }
  }
  count
}

///|
pub fn descendant_count(dom : Dom, idx : Int32) -> Int32 {
  if idx < 0 || idx >= dom.nodes.length() {
    return 0
  }
  let mut count = 0
  let stack = dom.nodes[idx].children.copy()
  while stack.length() > 0 {
    let cur = stack[stack.length() - 1]
    let _ = stack.pop()
    if is_element(dom, cur) {
      count += 1
      for child in dom.nodes[cur].children {
        stack.push(child)
      }
    }
  }
  count
}

///|
/// 文档序（前序）遍历，用显式栈避免深递归。
pub fn preorder(dom : Dom, start : Int32) -> Array[Int32] {
  let out : Array[Int32] = []
  if start < 0 || start >= dom.nodes.length() {
    return out
  }
  let stack : Array[Int32] = [start]
  while stack.length() > 0 {
    let idx = stack[stack.length() - 1]
    let _ = stack.pop()
    out.push(idx)
    let children = dom.nodes[idx].children
    let mut k = children.length() - 1
    while k >= 0 {
      stack.push(children[k])
      k -= 1
    }
  }
  out
}

///|
pub fn all_nodes(dom : Dom) -> Array[Int32] {
  preorder(dom, dom.root)
}

///|
pub fn parent(dom : Dom, idx : Int32) -> Int32 {
  if idx < 0 || idx >= dom.nodes.length() {
    return -1
  }
  dom.nodes[idx].parent
}

///|
pub fn is_ancestor(dom : Dom, ancestor : Int32, node : Int32) -> Bool {
  let mut cur = node
  while cur >= 0 {
    if cur == ancestor {
      return true
    }
    cur = dom.nodes[cur].parent
  }
  false
}

///|
/// 找到 body 节点；没有显式 body 时返回 root。
pub fn body_node(dom : Dom) -> Int32 {
  for idx in all_nodes(dom) {
    if tag(dom, idx) == "body" {
      return idx
    }
  }
  dom.root
}
