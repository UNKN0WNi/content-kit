///|
/// 候选块特征（§5.5.2）。打分模型只看这 8 个字段，是纯数据。
pub(all) struct Features {
  text_len : Int32
  link_len : Int32
  paragraphs : Int32
  commas : Int32
  tag_name : String
  class_weight : Double
  id_weight : Double
  role_weight : Double
}

///|
pub fn make_features(
  text_len : Int32,
  link_len : Int32,
  paragraphs : Int32,
  commas : Int32,
  tag_name : String,
  class_weight : Double,
  id_weight : Double,
  role_weight : Double,
) -> Features {
  {
    text_len,
    link_len,
    paragraphs,
    commas,
    tag_name,
    class_weight,
    id_weight,
    role_weight,
  }
}
