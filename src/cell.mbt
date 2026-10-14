///|
/// 绘制位置：一条顶线、一条内容行，或一条底线。
pub enum Line {
  Top
  Bottom
  At(Int32)
} derive(Debug)

///|
pub extend Line with Debug::{to_repr}

///|
/// 一次渲染里不变的绘制参数。`grid` 供交叉字符判断使用：某个位置该用 `┼` 还是
/// `┴`，取决于它上方是不是跨列占位、左侧是不是跨行占位。
priv struct DrawCtx {
  chars : Chars
  pad_l : Int32
  pad_r : Int32
  col_widths : Array[Int32]
  row_heights : Array[Int32]
  cols : Array[Column]
  head_style : Array[Ansi]
  border_style : Array[Ansi]
  truncate : String
  wrap : Bool
  on_word_boundary : Bool
  has_head : Bool
  grid : Array[Array[Placed]]
}

///|
fn placed_at(ctx : DrawCtx, y : Int32, x : Int32) -> Placed? {
  if y < 0 || y >= ctx.grid.length() {
    return None
  }
  let row = ctx.grid[y]
  if x < 0 || x >= row.length() {
    return None
  }
  Some(row[x])
}

///|
fn is_colspan_at(ctx : DrawCtx, y : Int32, x : Int32) -> Bool {
  match placed_at(ctx, y, x) {
    Some(p) =>
      match p.kind {
        ColSpan => true
        _ => false
      }
    None => false
  }
}

///|
fn is_rowspan_at(ctx : DrawCtx, y : Int32, x : Int32) -> Bool {
  match placed_at(ctx, y, x) {
    Some(p) =>
      match p.kind {
        RowSpan(_, _) => true
        _ => false
      }
    None => false
  }
}

///|
/// 跨行占位格对应的原格子。内容、行高、列宽都由原格子说了算。
fn origin_placed(ctx : DrawCtx, p : Placed, cell_offset : Int32) -> Placed {
  match placed_at(ctx, p.y - cell_offset, p.x) {
    Some(q) => q
    None => p
  }
}

///|
/// 格子宽度：它覆盖的列宽之和，加中间的竖线。
fn placed_width(ctx : DrawCtx, p : Placed) -> Int32 {
  let span = span_of(p.cell.col_span)
  let mut total = -1
  for i in 0..<span {
    let idx = p.x + i
    let w = if idx < ctx.col_widths.length() { ctx.col_widths[idx] } else { 1 }
    total += 1 + w
  }
  total
}

///|
/// 格子高度：它覆盖的行高之和，加中间的分隔线。
fn placed_height(ctx : DrawCtx, p : Placed) -> Int32 {
  let span = span_of(p.cell.row_span)
  let mut total = -1
  for i in 0..<span {
    let idx = p.y + i
    let h = if idx < ctx.row_heights.length() {
      ctx.row_heights[idx]
    } else {
      1
    }
    total += 1 + h
  }
  total
}

///|
/// 该格子是否延伸到最右侧，延伸到就要画右边界。
fn placed_draw_right(ctx : DrawCtx, p : Placed) -> Bool {
  p.x + span_of(p.cell.col_span) == ctx.col_widths.length()
}

///|
fn placed_h_align(ctx : DrawCtx, p : Placed) -> Align {
  match p.cell.h_align {
    Some(a) => a
    None => if p.x < ctx.cols.length() { ctx.cols[p.x].align } else { Left }
  }
}

///|
fn truncate_symbol(ctx : DrawCtx, p : Placed) -> String {
  match p.cell.truncate {
    Some(s) => s
    None =>
      if p.x < ctx.cols.length() {
        match ctx.cols[p.x].truncate {
          Some(s) => s
          None => ctx.truncate
        }
      } else {
        ctx.truncate
      }
  }
}

///|
fn placed_lines(ctx : DrawCtx, p : Placed) -> Array[String] {
  let inner = inner_width(
    ctx.col_widths,
    p.x,
    span_of(p.cell.col_span),
    ctx.pad_l,
    ctx.pad_r,
  )
  let raw = cell_lines(
    p,
    inner,
    wraps(p, ctx.cols, ctx.wrap),
    ctx.on_word_boundary,
  )
  // 超链接逐行包：终端按行渲染，跨行的 OSC 8 在多数终端里不会继承。
  match p.cell.link {
    Some(url) => raw.map(fn(line) { hyperlink(url, line) })
    None => raw
  }
}

///|
/// 该格子左边界用什么字符。跨行占位格要接住左侧格子，所以走 `rightMid`。
fn left_edge(ctx : DrawCtx, p : Placed, spanning : Int32?) -> String {
  let mut left = if p.x == 0 { ctx.chars.left } else { ctx.chars.middle }
  match spanning {
    Some(off) =>
      if p.x > 0 {
        let mut cy = p.y + off
        let mut cx = p.x - 1
        let mut done = false
        while !done {
          match placed_at(ctx, cy, cx) {
            Some(q) =>
              match q.kind {
                ColSpan => {
                  cy = q.y
                  cx = q.x - 1
                }
                RowSpan(_, _) => done = true
                Content => {
                  left = ctx.chars.right_mid
                  done = true
                }
              }
            None => done = true
          }
        }
      }
    None => ()
  }
  left
}

///|
/// 顶线上的交叉字符。四种情况：表格左上角、列之间的 `┬`、跨列格子上方的 `┬`、
/// 以及左侧跨行格子在顶线上该退成 `├`。
fn top_left_char(ctx : DrawCtx, p : Placed, offset : Int32) -> String {
  let x = p.x + offset
  if p.y == 0 {
    if x == 0 {
      ctx.chars.top_left
    } else if offset == 0 {
      ctx.chars.top_mid
    } else {
      ctx.chars.top
    }
  } else if x == 0 {
    ctx.chars.left_mid
  } else {
    let mut ch = if offset == 0 {
      ctx.chars.mid_mid
    } else {
      ctx.chars.bottom_mid
    }
    if is_colspan_at(ctx, p.y - 1, x) {
      ch = if offset == 0 { ctx.chars.top_mid } else { ctx.chars.mid }
    }
    if offset == 0 {
      let mut i = 1
      while is_colspan_at(ctx, p.y, x - i) {
        i += 1
      }
      if is_rowspan_at(ctx, p.y, x - i) {
        ch = ctx.chars.left_mid
      }
    }
    ch
  }
}

///|
fn stylize(
  ctx : DrawCtx,
  p : Placed,
  left : String,
  content : String,
  right : String,
) -> String {
  let styled_content = if p.y == 0 && ctx.has_head {
    wrap_ansi(ctx.head_style, content)
  } else {
    match p.cell.color {
      Some(c) => c.paint(content)
      None => content
    }
  }
  wrap_ansi(ctx.border_style, left) +
  styled_content +
  wrap_ansi(ctx.border_style, right)
}

///|
fn draw_top(ctx : DrawCtx, p : Placed) -> String {
  let buf = StringBuilder()
  let span = span_of(p.cell.col_span)
  let first_row = p.y == 0
  for i in 0..<span {
    let idx = p.x + i
    let width = if idx < ctx.col_widths.length() {
      ctx.col_widths[idx]
    } else {
      1
    }
    buf.write_string(top_left_char(ctx, p, i))
    buf.write_string(
      repeat_str(if first_row { ctx.chars.top } else { ctx.chars.mid }, width),
    )
  }
  if placed_draw_right(ctx, p) {
    buf.write_string(
      if first_row {
        ctx.chars.top_right
      } else {
        ctx.chars.right_mid
      },
    )
  }
  wrap_ansi(ctx.border_style, buf.to_string())
}

///|
fn draw_bottom(ctx : DrawCtx, p : Placed) -> String {
  let left = if p.x == 0 { ctx.chars.bottom_left } else { ctx.chars.bottom_mid }
  let content = repeat_str(ctx.chars.bottom, placed_width(ctx, p))
  let right = if placed_draw_right(ctx, p) {
    ctx.chars.bottom_right
  } else {
    ""
  }
  wrap_ansi(ctx.border_style, left + content + right)
}

///|
fn draw_empty(ctx : DrawCtx, p : Placed, spanning : Int32?) -> String {
  let left = left_edge(ctx, p, spanning)
  let right = if placed_draw_right(ctx, p) { ctx.chars.right } else { "" }
  stylize(ctx, p, left, repeat_str(" ", placed_width(ctx, p)), right)
}

///|
fn draw_line_at(
  ctx : DrawCtx,
  p : Placed,
  line_num : Int32,
  lines : Array[String],
  force_truncate : Bool,
  spanning : Int32?,
) -> String {
  let left = left_edge(ctx, p, spanning)
  let right = if placed_draw_right(ctx, p) { ctx.chars.right } else { "" }
  let symbol = truncate_symbol(ctx, p)
  let len = placed_width(ctx, p) - ctx.pad_l - ctx.pad_r
  let raw = if line_num < lines.length() { lines[line_num] } else { "" }
  let with_symbol = if force_truncate { raw + symbol } else { raw }
  let fitted = truncate_to(with_symbol, len, symbol)
  let padded = pad_to(fitted, len, placed_h_align(ctx, p))
  let content = spaces(ctx.pad_l) + padded + spaces(ctx.pad_r)
  stylize(ctx, p, left, content, right)
}

///|
/// 画一个有内容的格子：顶线、内容行、底线。内容不足格高时按纵向对齐补空行。
fn draw_content(
  ctx : DrawCtx,
  p : Placed,
  line : Line,
  spanning : Int32?,
) -> String {
  match line {
    Top => draw_top(ctx, p)
    Bottom => draw_bottom(ctx, p)
    At(n) => {
      let lines = placed_lines(ctx, p)
      let height = placed_height(ctx, p)
      let pad_len = if height > lines.length() {
        height - lines.length()
      } else {
        0
      }
      let pad_top = match p.cell.v_align {
        Some(Middle) => (pad_len + 1) / 2
        Some(Bottom) => pad_len
        _ => 0
      }
      if n < pad_top || n >= pad_top + lines.length() {
        draw_empty(ctx, p, spanning)
      } else {
        let force = lines.length() > height && n + 1 >= height
        draw_line_at(ctx, p, n - pad_top, lines, force, spanning)
      }
    }
  }
}

///|
/// 画一个跨行占位格：内容全部委托给原格子，只把行号按偏移挪过去。
fn draw_row_span(
  ctx : DrawCtx,
  p : Placed,
  cell_offset : Int32,
  offset : Int32,
  line : Line,
) -> String {
  let origin = origin_placed(ctx, p, cell_offset)
  match line {
    Top => draw_content(ctx, origin, At(offset), Some(cell_offset))
    Bottom => draw_bottom(ctx, origin)
    // 内容行不带跨行偏移：左右边界按普通列位处理，与 cli-table3 的
    // `RowSpanCell.draw` 一致——只有 `top` 分支才把偏移继续往下传。
    At(n) => draw_content(ctx, origin, At(offset + 1 + n), None)
  }
}

///|
/// 画一个位置。跨列占位格不画任何东西。
fn draw_placed(ctx : DrawCtx, p : Placed, line : Line) -> String {
  match p.kind {
    ColSpan => ""
    RowSpan(cell_offset, offset) =>
      draw_row_span(ctx, p, cell_offset, offset, line)
    Content => draw_content(ctx, p, line, None)
  }
}

///|
/// 画一整行的某个位置，把所有格子拼起来。全空的行不占输出（无边框形态靠它）。
fn draw_row_line(
  out : Array[String],
  ctx : DrawCtx,
  row : Array[Placed],
  line : Line,
) -> Unit {
  let buf = StringBuilder()
  for p in row {
    buf.write_string(draw_placed(ctx, p, line))
  }
  let s = buf.to_string()
  if s != "" {
    out.push(s)
  }
}
