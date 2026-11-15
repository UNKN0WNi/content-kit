///|
/// 打分模型 v1（§5.5.3）。纯函数：输入 Features + Rules，输出 Double。
///
/// score(block) =
///     base_weight(tag)
///   + 1.0 * min(commas, 3)
///   + 0.5 * min(paragraphs, 3)
///   + 0.5 * min(text_len / 100, 3)
///   + 0.5 * min(link_len / 100, 3)
///   - 0.25 * min(link_len / paragraphs, 3)
///   - 0.5 * min(10 * class_weight, 3)
///   + 0.25 * min(10 * id_weight, 3)
///   + 0.5 * min(10 * role_weight, 3)
///
/// 所有系数都来自 Rules（单一事实来源）；所有除法都有除零保护。

///|
fn clamp_nonneg(x : Double) -> Double {
  if x < 0.0 {
    0.0
  } else {
    x
  }
}

///|
fn cap3(x : Double, cap : Double) -> Double {
  let v = clamp_nonneg(x)
  if v > cap {
    cap
  } else {
    v
  }
}

///|
/// link_len / paragraphs。paragraphs 为 0 时按 1 处理，避免除零。
pub fn link_per_paragraph(f : Features) -> Double {
  let divisor = if f.paragraphs > 0 { f.paragraphs.to_double() } else { 1.0 }
  f.link_len.to_double() / divisor
}

///|
pub fn score(f : Features, r : Rules) -> Double {
  let base = base_weight(f.tag_name)
  let commas = r.comma_coef * cap3(f.commas.to_double(), r.cap)
  let paragraphs = r.paragraph_coef * cap3(f.paragraphs.to_double(), r.cap)
  let text_len = r.text_len_coef * cap3(f.text_len.to_double() / 100.0, r.cap)
  let link_len = r.link_len_coef * cap3(f.link_len.to_double() / 100.0, r.cap)
  let density = r.link_density_penalty * cap3(link_per_paragraph(f), r.cap)
  let class_penalty = r.class_penalty * cap3(10.0 * f.class_weight, r.cap)
  let id_bonus = r.id_bonus * cap3(10.0 * f.id_weight, r.cap)
  let role_bonus = r.role_bonus * cap3(10.0 * f.role_weight, r.cap)
  base +
  commas +
  paragraphs +
  text_len +
  link_len -
  density -
  class_penalty +
  id_bonus +
  role_bonus
}

///|
/// 祖先合并判定：parent_score > parent_ratio * child_score。
pub fn should_merge_parent(parent : Double, child : Double, r : Rules) -> Bool {
  parent > r.parent_ratio * child && parent > 0.0
}
