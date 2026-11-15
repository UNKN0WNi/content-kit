///|
/// 规则表：所有权重、阈值、标签白名单的单一事实来源（ADR-1）。
/// 四个后端编译同一份文件，调参只需改这里，天然一致。

///|
/// 规则表版本。对外暴露，便于消费方记录「用的是哪套规则」。
pub let rules_version : String = "1.0.0"

///|
/// 打分公式的可调参数。数值取自 Mozilla Readability 的思想，
/// 但全部外置为可配置项，而不是散落在算法里的魔数。
pub(all) struct Rules {
  // 逗号密度：正文段落通常含逗号，导航链接很少。
  comma_coef : Double
  // 子段落数量的正向权重。
  paragraph_coef : Double
  // 文本长度 / 100 的正向权重。
  text_len_coef : Double
  // 块内链接文本总长 / 100 的正向权重。
  link_len_coef : Double
  // 链接密度惩罚：link_len / paragraphs 越大越像导航。
  link_density_penalty : Double
  // 命中负面类名（ad / comment / sidebar …）的惩罚。
  class_penalty : Double
  // 命中正面 id（content / article …）的加成。
  id_bonus : Double
  // 语义属性（role=article / itemprop=articleBody）的加成。
  role_bonus : Double
  // 所有 min(..., cap) 的截断上限，防止长文一票定乾坤。
  cap : Double
  // 向上合并祖先的阈值：parent_score > parent_ratio * child_score。
  parent_ratio : Double
  // 候选块的最小文本长度，低于此值不参与竞争。
  min_text_len : Int32
  // 摘要（excerpt）截断长度。
  excerpt_len : Int32
}

///|
pub fn default_rules() -> Rules {
  {
    comma_coef: 1.0,
    paragraph_coef: 0.5,
    text_len_coef: 0.5,
    link_len_coef: 0.5,
    link_density_penalty: 0.25,
    class_penalty: 0.5,
    id_bonus: 0.25,
    role_bonus: 0.5,
    cap: 3.0,
    parent_ratio: 0.2,
    min_text_len: 12,
    excerpt_len: 160,
  }
}

///|
let block_tags_table : Array[String] = [
  "article", "section", "div", "main", "p", "td", "pre", "blockquote", "li", "h1",
  "h2", "h3", "h4", "h5", "h6", "dd", "dt", "figcaption", "tr", "body",
]

///|
let dropped_tags_table : Array[String] = [
  "script", "style", "noscript", "iframe", "svg", "form", "button", "input", "select",
  "textarea", "canvas", "template", "object", "embed", "applet",
]

///|
let structural_tags_table : Array[String] = ["header", "footer", "nav", "aside"]

///|
let void_tags_table : Array[String] = [
  "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param",
  "source", "track", "wbr",
]

///|
/// 遇到这些开始标签时，隐式闭合栈中同名的元素（HTML5 容错规则的子集）。
let implicit_close_table : Array[String] = [
  "p", "li", "tr", "td", "th", "dt", "dd", "option",
]

///|
let tag_weights_table : Array[(String, Double)] = [
  ("article", 5.0),
  ("main", 4.0),
  ("section", 2.0),
  ("blockquote", 1.5),
  ("pre", 1.0),
  ("td", 0.5),
  ("div", 0.5),
  ("body", 0.0),
  ("p", 1.0),
  ("h1", 0.5),
  ("h2", 0.5),
  ("h3", 0.5),
  ("h4", 0.5),
  ("h5", 0.5),
  ("h6", 0.5),
  ("li", 0.5),
  ("dd", 0.5),
  ("dt", 0.5),
  ("figcaption", 0.5),
  ("tr", 0.0),
]

///|
/// 命中即视为「负面」的类名片段。取值 0..1，越大惩罚越重。
let negative_class_tokens : Array[String] = [
  "comment", "advert", "ad-", "ads", "sidebar", "related", "promo", "sponsor", "footer",
  "header", "nav-", "navigation", "menu", "popup", "share", "social", "widget", "banner",
  "recommend", "subscribe", "paywall", "hidden", "sr-only",
]

///|
/// 命中即视为「正面」的 id / class 片段。
let positive_id_tokens : Array[String] = [
  "content", "article", "post", "entry", "mainbody", "story", "text", "bodytext",
]

///|
/// 语义属性命中值。
let positive_role_values : Array[String] = ["article", "main", "articlebody"]

///|
fn eq_lower(a : String, b : String) -> Bool {
  ascii_lower(a) == ascii_lower(b)
}

///|
fn in_list(list : Array[String], key : String) -> Bool {
  for item in list {
    if eq_lower(item, key) {
      return true
    }
  }
  false
}

///|
pub fn is_block_tag(tag : String) -> Bool {
  in_list(block_tags_table, tag)
}

///|
pub fn is_dropped_tag(tag : String) -> Bool {
  in_list(dropped_tags_table, tag)
}

///|
pub fn is_structural_tag(tag : String) -> Bool {
  in_list(structural_tags_table, tag)
}

///|
pub fn is_void_tag(tag : String) -> Bool {
  in_list(void_tags_table, tag)
}

///|
pub fn is_implicit_close(tag : String) -> Bool {
  in_list(implicit_close_table, tag)
}

///|
/// 标签基础权重。
pub fn base_weight(tag : String) -> Double {
  for (name, weight) in tag_weights_table {
    if eq_lower(name, tag) {
      return weight
    }
  }
  0.0
}

///|
/// 类名权重（正数 = 惩罚）。命中任一负面片段即返回 1.0，
/// 命中正面片段抵消 0.5，取值被 clamp 到 [0, 1]。
pub fn class_weight(class_value : String) -> Double {
  let low = ascii_lower(class_value)
  let mut penalty = 0.0
  for token in negative_class_tokens {
    if contains_sub(low, token) {
      penalty = penalty + 1.0
    }
  }
  let mut bonus = 0.0
  for token in positive_id_tokens {
    if contains_sub(low, token) {
      bonus = bonus + 0.5
    }
  }
  let value = penalty - bonus
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// id 权重（正数 = 加成），取值 [0, 1]。
pub fn id_weight(id_value : String) -> Double {
  let low = ascii_lower(id_value)
  let mut value = 0.0
  for token in positive_id_tokens {
    if contains_sub(low, token) {
      value = value + 0.5
    }
  }
  for token in negative_class_tokens {
    if contains_sub(low, token) {
      value = value - 0.5
    }
  }
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
/// role / itemprop 语义权重，取值 [0, 1]。
pub fn role_weight(role_value : String, itemprop_value : String) -> Double {
  let mut value = 0.0
  for candidate in [role_value, itemprop_value] {
    let low = ascii_lower(candidate)
    for positive in positive_role_values {
      if contains_sub(low, positive) {
        value = value + 0.5
      }
    }
  }
  if value > 1.0 {
    1.0
  } else {
    value
  }
}
