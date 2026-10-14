///|
/// 表格边框字符集。空字符串表示不画该处字符，据此可以拼出无边框、纯 Markdown
/// 等形态，而不必在渲染代码里到处特判。
///
/// 与 cli-table3 的 `chars` 字符串键 map 对应，但字段是编译期可见的：
/// 拼错 `top_mid` 会在编译期报错，而不是画出一张缺角的表。
pub struct Chars {
  top : String
  top_mid : String
  top_left : String
  top_right : String
  bottom : String
  bottom_mid : String
  bottom_left : String
  bottom_right : String
  left : String
  left_mid : String
  mid : String
  mid_mid : String
  right : String
  right_mid : String
  middle : String
} derive(Debug)

///|
pub extend Chars with Debug::{to_repr}

///|
/// 单线直角边框：`┌─┬─┐`
pub fn Chars::single() -> Chars {
  {
    top: "─",
    top_mid: "┬",
    top_left: "┌",
    top_right: "┐",
    bottom: "─",
    bottom_mid: "┴",
    bottom_left: "└",
    bottom_right: "┘",
    left: "│",
    left_mid: "├",
    mid: "─",
    mid_mid: "┼",
    right: "│",
    right_mid: "┤",
    middle: "│",
  }
}

///|
/// 双线直角边框：`╔═╤═╗`
pub fn Chars::double() -> Chars {
  {
    top: "═",
    top_mid: "╤",
    top_left: "╔",
    top_right: "╗",
    bottom: "═",
    bottom_mid: "╧",
    bottom_left: "╚",
    bottom_right: "╝",
    left: "║",
    left_mid: "╟",
    mid: "─",
    mid_mid: "┼",
    right: "║",
    right_mid: "╢",
    middle: "║",
  }
}

///|
/// 单线圆角边框：`╭─┬─╮`
pub fn Chars::rounded() -> Chars {
  {
    top: "─",
    top_mid: "┬",
    top_left: "╭",
    top_right: "╮",
    bottom: "─",
    bottom_mid: "┴",
    bottom_left: "╰",
    bottom_right: "╯",
    left: "│",
    left_mid: "├",
    mid: "─",
    mid_mid: "┼",
    right: "│",
    right_mid: "┤",
    middle: "│",
  }
}

///|
/// ASCII 边框：`+---+`
pub fn Chars::ascii() -> Chars {
  {
    top: "-",
    top_mid: "+",
    top_left: "+",
    top_right: "+",
    bottom: "-",
    bottom_mid: "+",
    bottom_left: "+",
    bottom_right: "+",
    left: "|",
    left_mid: "+",
    mid: "-",
    mid_mid: "+",
    right: "|",
    right_mid: "+",
    middle: "|",
  }
}

///|
/// 无边框，只用 `|` 分隔列：适合直接粘进 Markdown 或纯文本。
pub fn Chars::none() -> Chars {
  {
    top: "",
    top_mid: "",
    top_left: "",
    top_right: "",
    bottom: "",
    bottom_mid: "",
    bottom_left: "",
    bottom_right: "",
    left: "",
    left_mid: "",
    mid: "",
    mid_mid: "",
    right: "",
    right_mid: "",
    middle: " ",
  }
}

///|
/// Markdown 表格边框：`| a | b |` 加 `|---|---|` 分隔线。
pub fn Chars::markdown() -> Chars {
  {
    top: "",
    top_mid: "",
    top_left: "",
    top_right: "",
    bottom: "",
    bottom_mid: "",
    bottom_left: "",
    bottom_right: "",
    left: "|",
    left_mid: "|",
    mid: "-",
    mid_mid: "|",
    right: "|",
    right_mid: "|",
    middle: "|",
  }
}
