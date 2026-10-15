///|
/// 表格。列定义与行数据分离：列说"怎么显示"，行说"显示什么"。
///
/// 构建器就地累积（`push` 直接改内部行表并返回自身），链式调用不会复制中间
/// 结果。字段都不带 `mut`：内容靠引用原地修改。
pub struct Table {
  cols : Array[Column]
  rows : Array[Array[Cell]]
  chars : Chars
  pad_l : Int32
  pad_r : Int32
  head_style : @clicolor.Style
  border_style : @clicolor.Style
  total_width : Int32?
  row_height : Int32?
  word_wrap : Bool
  wrap_on_word_boundary : Bool
  truncate : String
} derive(Debug)

///|
pub extend Table with Debug::{to_repr}

///|
/// 建一张表。列定义必填，其余都有默认值，用 `with_*` 逐个叠加。
pub fn Table::new(cols : Array[Column]) -> Table {
  {
    cols,
    rows: [],
    chars: Chars::single(),
    pad_l: 1,
    pad_r: 1,
    head_style: @clicolor.default,
    border_style: @clicolor.default,
    total_width: None,
    row_height: None,
    word_wrap: false,
    wrap_on_word_boundary: true,
    truncate: "…",
  }
}

///|
/// 追加一行。数组元素经 `ToCell` 转成单元格，所以 `["a", "b"]` 与 `[1, 2]` 都行。
///
/// 跨行跨列靠单元格自己声明：`Cell::text("x").span(2, rows=3)`。空出来的位置
/// 不必补占位符，布局阶段会自己填。
pub fn[T : ToCell] Table::push(self : Table, cells : Array[T]) -> Table {
  self.rows.push(cells.map(fn(c) { c.to_cell() }))
  self
}

///|
/// 批量追加。元素实现 `ToRow` 即可：`Array[T]` 是一行，业务类型可以自己实现。
pub fn[R : ToRow] Table::push_rows(self : Table, rows : Array[R]) -> Table {
  for row in rows {
    self.rows.push(row.to_row())
  }
  self
}

///|
/// 换一套边框字符。
pub fn Table::with_chars(self : Table, chars : Chars) -> Table {
  { ..self, chars, }
}

///|
/// 换内边距。左右都按显示列数给。
pub fn Table::with_padding(self : Table, left : Int32, right : Int32) -> Table {
  { ..self, pad_l: left, pad_r: right, }
}

///|
/// 约束表格总宽。超出时按均摊削列宽，内容窄时不会被拉伸。
pub fn Table::with_width(self : Table, width : Int32) -> Table {
  { ..self, total_width: Some(width), }
}

///|
/// 固定每一行的行数。内容超出时在末行收成截断符，空出的行补空行。
pub fn Table::with_row_height(self : Table, height : Int32) -> Table {
  { ..self, row_height: Some(height), }
}

///|
/// 打开自动换行。配合列宽约束使用：窄列会把长内容折行而不是截断。
pub fn Table::with_word_wrap(self : Table) -> Table {
  { ..self, word_wrap: true, }
}

///|
/// 换行时是否优先在词边界断开。
pub fn Table::with_word_boundary(self : Table, on : Bool) -> Table {
  { ..self, wrap_on_word_boundary: on, }
}

///|
/// 表头与边框的样式。传一个 Style 值，空 Style 原样返回。
pub fn Table::with_head_style(self : Table, style : @clicolor.Style) -> Table {
  { ..self, head_style: style, }
}

///|
pub fn Table::with_border_style(self : Table, style : @clicolor.Style) -> Table {
  { ..self, border_style: style, }
}

///|
/// 无表头表格：列数从第一行推导。
pub fn Table::grid(rows : Array[Array[String]]) -> Table {
  let ncols = if rows.length() > 0 { rows[0].length() } else { 0 }
  let cols : Array[Column] = []
  for _ in 0..<ncols {
    cols.push(Column::new(""))
  }
  let t = Table::new(cols)
  for row in rows {
    let cells : Array[Cell] = []
    for text in row {
      cells.push(Cell::text(text))
    }
    t.rows.push(cells)
  }
  t
}

///|
/// 纵向表：两列无表头，每对是一行。
pub fn Table::kv(pairs : Array[(String, String)]) -> Table {
  let t = Table::new([Column::new(""), Column::new("")])
  for pair in pairs {
    let (key, value) = pair
    t.rows.push([Cell::text(key), Cell::text(value)])
  }
  t
}

///|
/// 是否有表头：任一列有标题就画表头行。
fn has_head(cols : Array[Column]) -> Bool {
  for col in cols {
    if col.title != "" {
      return true
    }
  }
  false
}

///|
/// 组装参与布局的行：有表头时把列标题作为第一行，其余行原样跟上。
fn build_rows(table : Table) -> Array[Array[Cell]] {
  let rows : Array[Array[Cell]] = []
  if has_head(table.cols) {
    rows.push(table.cols.map(fn(c) { Cell::text(c.title) }))
  }
  for row in table.rows {
    rows.push(row)
  }
  rows
}

///|
/// 渲染成字符串。
///
/// 流程与 cli-table3 一致：铺布局网格 → 算列宽 → 算行高 → 解出跨行偏移 →
/// 逐行画顶线、内容行与底线。行内单元格数与列表数不一致时
/// `raise TableError::Arity`，不做静默补齐。
pub fn Table::render(self : Table) -> String raise TableError {
  let ncols = self.cols.length()
  if ncols == 0 {
    if self.rows.length() == 0 {
      return ""
    }
    raise TableError::Arity(0, self.rows[0].length())
  }
  // 总宽连边框和最小列宽都放不下时直接报错，而不是画出一张挤碎的表。
  match self.total_width {
    Some(budget) => {
      let min_col = self.pad_l + self.pad_r + 1
      let needed = ncols + 1 + ncols * min_col
      if budget < needed {
        raise TableError::TooNarrow(budget)
      }
    }
    None => ()
  }
  let rows = build_rows(self)
  if rows.length() == 0 {
    return ""
  }
  let (grid, occupied) = layout_rows(rows)
  // 行宽校验：行内跨列数之和，加上被上方跨行格子占用的列数，必须刚好等于列数。
  // 写多写少都报错，不静默补齐——跨行表格里"少写"是正常的，占用的列会补回来。
  for i in 0..<rows.length() {
    let mut span_sum = 0
    for c in rows[i] {
      span_sum += span_of(c.col_span)
    }
    let taken = if i < occupied.length() { occupied[i] } else { 0 }
    if span_sum + taken != ncols {
      raise TableError::Arity(ncols, span_sum + taken)
    }
  }
  let col_widths = compute_col_widths(
    grid,
    self.cols,
    self.pad_l,
    self.pad_r,
    self.total_width,
  )
  let row_heights = compute_row_heights(
    grid,
    self.cols,
    col_widths,
    self.pad_l,
    self.pad_r,
    self.word_wrap,
    self.wrap_on_word_boundary,
  )
  // 固定行高：覆盖算出来的自然高度。放不下的内容在末行收成截断符。
  match self.row_height {
    Some(height) =>
      for i in 0..<row_heights.length() {
        row_heights[i] = height
      }
    None => ()
  }
  resolve_row_span_offsets(grid, row_heights)
  let ctx : DrawCtx = {
    chars: self.chars,
    pad_l: self.pad_l,
    pad_r: self.pad_r,
    col_widths,
    row_heights,
    cols: self.cols,
    head_style: self.head_style,
    border_style: self.border_style,
    truncate: self.truncate,
    wrap: self.word_wrap,
    on_word_boundary: self.wrap_on_word_boundary,
    has_head: has_head(self.cols),
    grid,
  }
  let out : Array[String] = []
  for y in 0..<grid.length() {
    draw_row_line(out, ctx, grid[y], Top)
    for n in 0..<row_heights[y] {
      draw_row_line(out, ctx, grid[y], At(n))
    }
    if y + 1 == grid.length() {
      draw_row_line(out, ctx, grid[y], Bottom)
    }
  }
  out.join("\n")
}

///|
/// 实现 `Show`，于是 `println(table)` 直接就是这张表。
pub impl Show for Table with fn output(self, logger) {
  logger.write_string(self.render() catch { _ => "" })
}

///|
/// 让 `table.to_string()` 与 `Show::to_string(table)` 两种写法都可用。
pub extend Table with Show::{to_string, output}
