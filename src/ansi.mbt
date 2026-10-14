///|
/// 终端 ANSI 样式。可以叠加使用，例如 `[Ansi::Bold, Ansi::Red]`。
///
/// 与 cli-table3 用字符串 `'hex(#FFA500)'` 表达颜色相对，这里把颜色与样式收成
/// 枚举：拼错的样式名编译期就报错，真彩色的取值由 `Hex` 携带。
pub(all) enum Ansi {
  Black
  Red
  Green
  Yellow
  Blue
  Magenta
  Cyan
  White
  BrightBlack
  BrightRed
  BrightGreen
  BrightYellow
  BrightBlue
  BrightMagenta
  BrightCyan
  BrightWhite
  Bold
  Italic
  Underline
  Inverse
  Strikethrough
  BgBlack
  BgRed
  BgGreen
  BgYellow
  BgBlue
  BgMagenta
  BgCyan
  BgWhite
  Hex(String)
  BgHex(String)
} derive(Eq, Debug)

///|
pub extend Ansi with Eq::{not_equal, equal}

///|
pub extend Ansi with Debug::{to_repr}

///|
/// ESC 字符。ANSI 序列一律以它开头。
const ESC : Char = '\u{1B}'

///|
/// 重置所有样式。
const RESET : String = "\u{1B}[0m"

///|
/// 单个样式对应的 SGR 参数（不含 ESC 与结尾的 `m`）。返回空串表示不输出。
fn Ansi::sgr_params(self : Ansi) -> String {
  match self {
    Black => "30"
    Red => "31"
    Green => "32"
    Yellow => "33"
    Blue => "34"
    Magenta => "35"
    Cyan => "36"
    White => "37"
    BrightBlack => "90"
    BrightRed => "91"
    BrightGreen => "92"
    BrightYellow => "93"
    BrightBlue => "94"
    BrightMagenta => "95"
    BrightCyan => "96"
    BrightWhite => "97"
    Bold => "1"
    Italic => "3"
    Underline => "4"
    Inverse => "7"
    Strikethrough => "9"
    BgBlack => "40"
    BgRed => "41"
    BgGreen => "42"
    BgYellow => "43"
    BgBlue => "44"
    BgMagenta => "45"
    BgCyan => "46"
    BgWhite => "47"
    Hex(hex) => "38;2;" + rgb_params(hex)
    BgHex(hex) => "48;2;" + rgb_params(hex)
  }
}

///|
/// 把 `#RRGGBB` 或 `#RGB` 拆成 `r;g;b`。取不到合法值时按黑色处理，
/// 与 cli-table3 的 `parseHexValue` 行为一致，保证渲染不会因为一个坏色值中断。
fn rgb_params(hex : String) -> String {
  let digits = hex_digits(hex)
  let (r, g, b) = match digits {
    [r, g, b] => (r, g, b)
    [r, g, b, _, _, _] => (r, g, b)
    _ => (0, 0, 0)
  }
  r.to_string() + ";" + g.to_string() + ";" + b.to_string()
}

///|
/// 从字符串里取出十六进制数字。`#RGB` 会被展开成 `RRGGBB` 的等价形式。
fn hex_digits(hex : String) -> Array[Int32] {
  let out : Array[Int32] = []
  for c in hex {
    let d = match hex_value(c) {
      Some(v) => v
      None => continue
    }
    out.push(d)
  }
  if out.length() == 3 {
    [out[0] * 17, out[1] * 17, out[2] * 17]
  } else {
    out
  }
}

///|
/// 单个十六进制字符的取值。
fn hex_value(c : Char) -> Int32? {
  let code = c.to_int()
  if code >= 48 && code <= 57 {
    Some(code - 48)
  } else if code >= 97 && code <= 102 {
    Some(code - 97 + 10)
  } else if code >= 65 && code <= 70 {
    Some(code - 65 + 10)
  } else {
    None
  }
}

///|
/// 把一串样式包在文本外面。空数组表示不加任何样式。
pub fn wrap_ansi(styles : Array[Ansi], text : String) -> String {
  if styles.length() == 0 {
    return text
  }
  let buf = StringBuilder()
  for style in styles {
    let params = style.sgr_params()
    if params != "" {
      buf.write_string("\u{1B}[")
      buf.write_string(params)
      buf.write_string("m")
    }
  }
  buf.write_string(text)
  buf.write_string(RESET)
  buf.to_string()
}

///|
/// 用单个样式包住文本的便捷入口。
pub fn Ansi::paint(self : Ansi, text : String) -> String {
  wrap_ansi([self], text)
}

///|
/// OSC 8 超链接的起始序列前缀。
pub const OSC8_PREFIX : String = "\u{1B}]8;;"

///|
/// 关掉当前 OSC 8 超链接的收尾序列。
pub const OSC8_SUFFIX : String = "\u{1B}]8;;\u{7}"

///|
/// 把文本包成 OSC 8 超链接。终端支持时文本可以点击，不支持时按普通文本显示。
/// 宽度计算会剥掉这层转义，所以链接不影响列对齐。
pub fn hyperlink(url : String, text : String) -> String {
  OSC8_PREFIX + url + "\u{7}" + text + OSC8_SUFFIX
}
