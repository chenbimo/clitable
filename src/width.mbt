///|
/// ANSI 扫描状态：0 可见文本，1 CSI 序列中，2 OSC 序列中，3 刚读到 ESC。
const SCAN_TEXT : Int32 = 0

///|
const SCAN_CSI : Int32 = 1

///|
const SCAN_OSC : Int32 = 2

///|
const SCAN_ESC : Int32 = 3

///|
/// CSI 序列（`ESC [ ... 字母`）以字母收尾。
fn is_csi_end(c : Char) -> Bool {
  let code = c.to_int()
  (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
}

///|
/// OSC 序列（`ESC ] ... BEL`，超链接用的那种）以 BEL 收尾。
fn is_osc_end(c : Char) -> Bool {
  c.to_int() == 7
}

///|
/// 推进扫描状态。返回 (新状态, 该字符是否属于转义序列)。
///
/// CSI 与 OSC 必须分开判断：两者的收尾规则不同，混用会让 OSC 里的 URL 字母
/// 被当成 CSI 的收尾，序列后半截就泄漏成可见文本、宽度跟着算多。
fn scan_ansi(state : Int32, c : Char) -> (Int32, Bool) {
  match state {
    SCAN_ESC =>
      if c == '[' {
        (SCAN_CSI, true)
      } else if c == ']' {
        (SCAN_OSC, true)
      } else {
        // 不是 CSI / OSC，按两字符转义整个吃掉。
        (SCAN_TEXT, true)
      }
    SCAN_CSI => if is_csi_end(c) { (SCAN_TEXT, true) } else { (SCAN_CSI, true) }
    SCAN_OSC => if is_osc_end(c) { (SCAN_TEXT, true) } else { (SCAN_OSC, true) }
    _ => if c == ESC { (SCAN_ESC, true) } else { (SCAN_TEXT, false) }
  }
}

///|
/// 去掉文本里的 ANSI 转义序列，只留下可见字符。宽度计算与截断都先经它。
pub fn strip_ansi(text : String) -> String {
  let buf = StringBuilder()
  let mut state = SCAN_TEXT
  for c in text {
    let (next, in_escape) = scan_ansi(state, c)
    state = next
    if !in_escape {
      buf.write_string(c.to_string())
    }
  }
  buf.to_string()
}

///|
/// 单行文本的显示宽度（终端列数）。ANSI 序列不计宽，全角字符计 2 列。
pub fn display_width(text : String) -> Int32 {
  @unicodewidth.str_width(strip_ansi(text))
}

///|
/// 多行文本的显示宽度，取最长的一行。
pub fn display_width_multiline(text : String) -> Int32 {
  let mut widest = 0
  for line in strip_ansi(text).split("\n") {
    let w = @unicodewidth.str_width(line)
    if w > widest {
      widest = w
    }
  }
  widest
}

///|
fn char_width_of(c : Char) -> Int32 {
  match @unicodewidth.char_width(c) {
    Some(w) => w
    None => 0
  }
}

///|
/// `count` 个空格。
fn spaces(count : Int32) -> String {
  repeat_str(" ", count)
}

///|
/// 把 `text` 重复 `count` 次。
fn repeat_str(text : String, count : Int32) -> String {
  let buf = StringBuilder()
  for _ in 0..<count {
    buf.write_string(text)
  }
  buf.to_string()
}

///|
/// 按对齐方式把文本补齐到 `width` 列。宽度按显示列数算，全角字符不会算错。
pub fn pad_to(text : String, width : Int32, align : Align) -> String {
  let len = display_width(text)
  if len >= width {
    return text
  }
  let fill = width - len
  match align {
    Left => text + spaces(fill)
    Right => spaces(fill) + text
    Center => {
      // 与 cli-table3 一致：基数富余量偏右，左侧多留一列。
      let right = (fill + 1) / 2
      spaces(fill - right) + text + spaces(right)
    }
  }
}

///|
/// 按显示宽度取前缀。ANSI 序列整体保留且不计宽，所以带颜色的内容截断后
/// 颜色不会串到后面的文字上。
fn take_width(text : String, width : Int32) -> String {
  let buf = StringBuilder()
  let mut used = 0
  let mut state = SCAN_TEXT
  for c in text {
    let (next, in_escape) = scan_ansi(state, c)
    state = next
    if in_escape {
      buf.write_string(c.to_string())
      continue
    }
    let w = char_width_of(c)
    if used + w > width {
      break
    }
    buf.write_string(c.to_string())
    used += w
  }
  buf.to_string()
}

///|
/// 截断到给定显示宽度，超出部分换成省略符。放得下就原样返回。
pub fn truncate_to(text : String, width : Int32, symbol : String) -> String {
  if display_width(text) <= width {
    return text
  }
  let symbol_width = display_width(symbol)
  let keep = if width > symbol_width { width - symbol_width } else { 0 }
  let mut ret = take_width(text, keep)
  ret += symbol
  // 截断可能把 OSC 8 超链接的收尾序列切掉，补一个，免得后面的文字也被当成链接。
  if text.contains(OSC8_PREFIX) && !ret.contains(OSC8_SUFFIX) {
    ret += OSC8_SUFFIX
  }
  ret
}

///|
/// 把内容按 `\n` 切成若干行。
fn split_lines(text : String) -> Array[String] {
  text.split("\n").map(fn(line) { line.to_owned() }).to_array()
}

///|
/// 按显示宽度断行。`on_word_boundary` 为真时优先在空白处断，否则按列硬切。
pub fn wrap_text(
  text : String,
  width : Int32,
  on_word_boundary : Bool,
) -> Array[String] {
  let out : Array[String] = []
  if width <= 0 {
    return out
  }
  for line in split_lines(text) {
    if on_word_boundary {
      out.append(wrap_by_word(line, width))
    } else {
      out.append(wrap_by_char(line, width))
    }
  }
  out
}

///|
/// 按列硬切，忽略词边界。
fn wrap_by_char(line : String, width : Int32) -> Array[String] {
  let out : Array[String] = []
  let mut rest = line
  while display_width(rest) > width {
    let head = take_width(rest, width)
    out.push(head)
    rest = drop_width(rest, width)
  }
  out.push(rest)
  out
}

///|
/// 丢掉前 `width` 列，返回剩余部分。
fn drop_width(text : String, width : Int32) -> String {
  let seen = take_width(text, width)
  text[seen.length():].to_owned()
}

///|
/// 在空白处断行。单个词长于一列宽时退化为按列硬切，避免无限循环。
fn wrap_by_word(line : String, width : Int32) -> Array[String] {
  let out : Array[String] = []
  let mut current = ""
  for word in line.split(" ") {
    let word = word.to_owned()
    if current == "" {
      current = word
    } else if display_width(current) + 1 + display_width(word) <= width {
      current = current + " " + word
    } else {
      out.push(current)
      current = word
    }
    while display_width(current) > width {
      out.push(take_width(current, width))
      current = drop_width(current, width)
    }
  }
  out.push(current)
  out
}
