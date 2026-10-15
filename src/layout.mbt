///|
/// 布局后的格子种类。占位格是 cli-table3 里 `ColSpanCell` / `RowSpanCell`
/// 的对应物：不用继承与 `instanceof`，把三态写进类型，绘制时靠模式匹配分流。
pub enum PlacedKind {
  /// 有内容的格子，可能跨行跨列。
  Content
  /// 跨列占位：自身不画内容，只把宽度让给左侧的格子。
  ColSpan
  /// 跨行占位：内容取自原格子，行号按 `(cell_offset, offset)` 偏移。
  RowSpan(Int32, Int32)
} derive(Debug)

///|
pub extend PlacedKind with Debug::{to_repr}

///|
/// 布局网格里的一个位置。
pub struct Placed {
  cell : Cell
  kind : PlacedKind
  x : Int32
  y : Int32
} derive(Debug)

///|
pub extend Placed with Debug::{to_repr}

///|
/// 跨行列数的最小值：0 或负数一律当 1。
fn span_of(v : Int32) -> Int32 {
  if v < 1 {
    1
  } else {
    v
  }
}

// ---------------------------------------------------------------------------
// 位置分配
// ---------------------------------------------------------------------------

///|
/// 取第一个没有被上方跨行格子占用的列。
fn next_free_col(alloc : Array[Int32], col : Int32) -> Int32 {
  if col < alloc.length() && alloc[col] > 0 {
    next_free_col(alloc, col + 1)
  } else {
    col
  }
}

///|
fn alloc_reserve(alloc : Array[Int32], col : Int32, rows : Int32) -> Unit {
  while alloc.length() <= col {
    alloc.push(0)
  }
  alloc[col] = rows
}

///|
/// 一行处理完，所有占用计数减一，减到零的列重新可用。
fn alloc_tick(alloc : Array[Int32]) -> Unit {
  for i in 0..<alloc.length() {
    if alloc[i] > 0 {
      alloc[i] = alloc[i] - 1
    }
  }
}

///|
/// 给每个格子分配 `x` / `y`。跨行格子会在它覆盖的列上登记剩余行数，后面的行
/// 自动跳过这些列位，所以用户不必为空出来的位置补占位符。
///
/// 返回每一行进入时"已被上方跨行格子占用"的列数，供调用方校验行宽是否合理。
fn assign_positions(grid : Array[Array[Placed]]) -> Array[Int32] {
  let alloc : Array[Int32] = []
  let occupied : Array[Int32] = []
  for y in 0..<grid.length() {
    let mut count = 0
    for i in 0..<alloc.length() {
      if alloc[i] > 0 {
        count += 1
      }
    }
    occupied.push(count)
    let row = grid[y]
    let mut col = 0
    for i in 0..<row.length() {
      let p = row[i]
      let x = if y == 0 { col } else { next_free_col(alloc, col) }
      let col_span = span_of(p.cell.col_span)
      let row_span = span_of(p.cell.row_span)
      if row_span > 1 {
        for cs in 0..<col_span {
          alloc_reserve(alloc, x + cs, row_span)
        }
      }
      col = x + col_span
      row[i] = { ..p, x, y, }
    }
    alloc_tick(alloc)
  }
  occupied
}

// ---------------------------------------------------------------------------
// 冲突判断
// ---------------------------------------------------------------------------

///|
fn cells_conflict(p : Placed, x : Int32, y : Int32) -> Bool {
  let y_end = p.y - 1 + span_of(p.cell.row_span)
  let y_overlap = !(p.y > y || y > y_end)
  let x_end = p.x - 1 + span_of(p.cell.col_span)
  let x_overlap = !(p.x > x || x > x_end)
  y_overlap && x_overlap
}

///|
/// `(x, y)` 是否已被某个格子覆盖。只看到 `y` 为止的行。
fn conflict_exists(grid : Array[Array[Placed]], x : Int32, y : Int32) -> Bool {
  let last = if y < grid.length() { y } else { grid.length() - 1 }
  for i in 0..<=last {
    for p in grid[i] {
      if cells_conflict(p, x, y) {
        return true
      }
    }
  }
  false
}

///|
fn all_blank(
  grid : Array[Array[Placed]],
  y : Int32,
  x_min : Int32,
  x_max : Int32,
) -> Bool {
  for x in x_min..<x_max {
    if conflict_exists(grid, x, y) {
      return false
    }
  }
  true
}

///|
/// 网格的列数：所有格子右边界里的最大值。
fn grid_cols(grid : Array[Array[Placed]]) -> Int32 {
  let mut widest = 0
  for row in grid {
    for p in row {
      let end = p.x + span_of(p.cell.col_span)
      if end > widest {
        widest = end
      }
    }
  }
  widest
}

///|
/// 按 `x` 顺序把格子插进行，保持该行有序。
fn insert_placed(row : Array[Placed], placed : Placed) -> Unit {
  let mut i = 0
  while i < row.length() && row[i].x < placed.x {
    i += 1
  }
  row.insert(i, placed)
}

// ---------------------------------------------------------------------------
// 空洞填补
// ---------------------------------------------------------------------------

///|
/// 用户没铺满的位置补成空格子：先向右扩到下一个已被占用的列位，再向下扩到
/// 有内容的行为止。补出来的格子参与绘制，所以缺格子的行照样对齐。
fn fill_holes(grid : Array[Array[Placed]]) -> Unit {
  let h_max = grid.length()
  let w_max = grid_cols(grid)
  for y in 0..<h_max {
    let mut x = 0
    while x < w_max {
      if !conflict_exists(grid, x, y) {
        let start_x = x
        let mut col_span = 1
        x += 1
        while x < w_max && !conflict_exists(grid, x, y) {
          col_span += 1
          x += 1
        }
        let mut row_span = 1
        let mut y2 = y + 1
        while y2 < h_max && all_blank(grid, y2, start_x, start_x + col_span) {
          row_span += 1
          y2 += 1
        }
        let blank = Cell::text("")
        insert_placed(grid[y], {
          cell: { ..blank, col_span, row_span, },
          kind: Content,
          x: start_x,
          y,
        })
      } else {
        x += 1
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 占位格
// ---------------------------------------------------------------------------

///|
fn is_content(p : Placed) -> Bool {
  match p.kind {
    Content => true
    _ => false
  }
}

///|
/// 为跨行格子在其下方的每一行插入占位格。占位格持有原格子的副本，绘制时按
/// `(cell_offset, offset)` 找到原格子该画的内容行。
fn add_row_span_slots(grid : Array[Array[Placed]]) -> Unit {
  for y in 0..<grid.length() {
    let row = grid[y]
    for i in 0..<row.length() {
      let p = row[i]
      if !is_content(p) {
        continue
      }
      let row_span = span_of(p.cell.row_span)
      for k in 1..<row_span {
        insert_placed(grid[p.y + k], {
          cell: p.cell,
          kind: RowSpan(k, 0),
          x: p.x,
          y: p.y + k,
        })
      }
    }
  }
}

///|
/// 为跨列格子在右侧插入占位格。它们不画内容，只是把边界让出来，好让格子覆盖
/// 到多列的宽度上。
fn add_col_span_slots(grid : Array[Array[Placed]]) -> Unit {
  let mut y = grid.length()
  while y > 0 {
    y -= 1
    let row = grid[y]
    let mut i = 0
    while i < row.length() {
      let p = row[i]
      let col_span = span_of(p.cell.col_span)
      for k in 1..<col_span {
        row.insert(i + 1, {
          cell: Cell::text(""),
          kind: ColSpan,
          x: p.x + k,
          y: p.y,
        })
      }
      i += 1
    }
  }
}

///|
/// 把行数据铺成布局网格：分配位置 → 补空洞 → 插两类占位格。
///
/// 同时返回每行进入时被上方跨行格子占用的列数，调用方据此校验行宽是否合理：
/// `行内跨列数之和 + 占用列数` 必须等于总列数。
pub fn layout_rows(
  rows : Array[Array[Cell]],
) -> (Array[Array[Placed]], Array[Int32]) {
  let grid = rows.map(fn(row) {
    row.map(fn(cell) { { cell, kind: Content, x: 0, y: 0, } })
  })
  let occupied = assign_positions(grid)
  fill_holes(grid)
  add_row_span_slots(grid)
  add_col_span_slots(grid)
  (grid, occupied)
}

// ---------------------------------------------------------------------------
// 列宽与行高
// ---------------------------------------------------------------------------

///|
/// 格子的自然宽度：最宽一行内容加左右内边距。
fn desired_width(p : Placed, pad_l : Int32, pad_r : Int32) -> Int32 {
  display_width_multiline(p.cell.content) + pad_l + pad_r
}

///|
fn sum_of(xs : Array[Int32]) -> Int32 {
  let mut total = 0
  for x in xs {
    total += x
  }
  total
}

///|
/// 在给定预算里按均摊方式削列宽：每轮对所有还能再减的列减同样的量，到最小宽
/// 就停，绝不把列压到装不下内边距。
///
/// `explicit` 标记显式列宽的列：这些列不参与削减。显式 `Column.width` 是用户
/// 的决定，总宽预算只能向自动列伸手，不能反悔用户写下的数字。
fn shrink_to(
  widths : Array[Int32],
  budget : Int32,
  min_col : Int32,
  explicit : Array[Bool],
) -> Unit {
  let mut steps = 0
  while sum_of(widths) > budget && steps < 1000 {
    steps += 1
    let mut cuttable = 0
    for i in 0..<widths.length() {
      if !explicit[i] && widths[i] > min_col {
        cuttable += 1
      }
    }
    if cuttable == 0 {
      break
    }
    let over = sum_of(widths) - budget
    let per = if over / cuttable > 0 { over / cuttable } else { 1 }
    for i in 0..<widths.length() {
      if !explicit[i] && widths[i] > min_col {
        let next = widths[i] - per
        widths[i] = if next < min_col { min_col } else { next }
      }
    }
  }
}

///|
/// 每列的最终显示宽度（含左右内边距）。
///
/// 先按普通格子取各自自然宽度，显式列宽覆盖之，再把跨列格子放不下的差额均摊给
/// 它覆盖的可编辑列，最后在有总宽约束时按均摊削减。
pub fn compute_col_widths(
  grid : Array[Array[Placed]],
  cols : Array[Column],
  pad_l : Int32,
  pad_r : Int32,
  total_width : Int32?,
) -> Array[Int32] {
  let ncols = cols.length()
  let result : Array[Int32] = []
  let explicit : Array[Bool] = []
  for _ in 0..<ncols {
    result.push(0)
    explicit.push(false)
  }
  let spanners : Array[Placed] = []
  for row in grid {
    for p in row {
      if span_of(p.cell.col_span) > 1 {
        spanners.push(p)
      } else if p.x < ncols {
        let w = desired_width(p, pad_l, pad_r)
        if w > result[p.x] {
          result[p.x] = w
        }
      }
    }
  }
  for i in 0..<ncols {
    match cols[i].width {
      Some(w) => {
        result[i] = w + pad_l + pad_r
        explicit[i] = true
      }
      None => ()
    }
  }
  // 跨列格子放不下时，把差额均摊给它覆盖的可编辑列。
  let mut k = spanners.length()
  while k > 0 {
    k -= 1
    let p = spanners[k]
    let span = span_of(p.cell.col_span)
    let col = p.x
    if col >= ncols {
      continue
    }
    let needed = desired_width(p, pad_l, pad_r)
    let mut existing = result[col]
    let mut editable = if explicit[col] { 0 } else { 1 }
    for i in 1..<span {
      if col + i < ncols {
        existing += 1 + result[col + i]
        if !explicit[col + i] {
          editable += 1
        }
      }
    }
    if needed > existing {
      let mut i = 0
      while editable > 0 && needed > existing && col + i < ncols {
        if !explicit[col + i] {
          let raw = needed - existing
          let diff = (raw + editable / 2) / editable
          existing += diff
          result[col + i] = result[col + i] + diff
          editable -= 1
        }
        i += 1
      }
    }
  }
  let min_col = pad_l + pad_r + 1
  for i in 0..<ncols {
    if result[i] < min_col {
      result[i] = min_col
    }
  }
  match total_width {
    Some(budget) =>
      // 每列之间与两侧各有一条分隔线，也要算进总宽。
      shrink_to(result, budget - (ncols + 1), min_col, explicit)
    None => ()
  }
  result
}

///|
/// 格子内容在渲染时占几行。开启换行的列按列宽折行，其余按 `\n` 分行。
fn cell_lines(
  p : Placed,
  inner : Int32,
  wrap : Bool,
  on_word_boundary : Bool,
) -> Array[String] {
  if wrap {
    wrap_text(p.cell.content, inner, on_word_boundary)
  } else {
    split_lines(p.cell.content)
  }
}

///|
/// 每行的内容行数（不含上下边框）。
///
/// 普通格子取自身行数。跨行格子要的行数比它覆盖的几行加起来还多时，把差额均摊
/// 给这些行，跨行内容才放得下。
pub fn compute_row_heights(
  grid : Array[Array[Placed]],
  cols : Array[Column],
  col_widths : Array[Int32],
  pad_l : Int32,
  pad_r : Int32,
  wrap : Bool,
  on_word_boundary : Bool,
) -> Array[Int32] {
  let nrows = grid.length()
  let heights : Array[Int32] = []
  for _ in 0..<nrows {
    heights.push(1)
  }
  let spanners : Array[Placed] = []
  for row in grid {
    for p in row {
      let inner = inner_width(
        col_widths,
        p.x,
        span_of(p.cell.col_span),
        pad_l,
        pad_r,
      )
      let lines = cell_lines(p, inner, wraps(p, cols, wrap), on_word_boundary)
      if span_of(p.cell.row_span) > 1 {
        spanners.push(p)
      } else if p.y < nrows {
        if lines.length() > heights[p.y] {
          heights[p.y] = lines.length()
        }
      }
    }
  }
  let spans : Array[Int32] = []
  for p in spanners {
    spans.push(span_of(p.cell.row_span))
  }
  let mut k = spanners.length()
  while k > 0 {
    k -= 1
    let p = spanners[k]
    let span = span_of(p.cell.row_span)
    let inner = inner_width(
      col_widths,
      p.x,
      span_of(p.cell.col_span),
      pad_l,
      pad_r,
    )
    let needed = cell_lines(p, inner, wraps(p, cols, wrap), on_word_boundary).length()
    let row = p.y
    if row >= nrows {
      continue
    }
    let mut existing = heights[row]
    let mut editable = 1
    for i in 1..<span {
      if row + i < nrows {
        existing += 1 + heights[row + i]
        editable += 1
      }
    }
    if needed > existing {
      let mut i = 0
      while editable > 0 && needed > existing && row + i < nrows {
        let raw = needed - existing
        let diff = (raw + editable / 2) / editable
        existing += diff
        heights[row + i] = heights[row + i] + diff
        editable -= 1
        i += 1
      }
    }
  }
  heights
}

///|
/// 该列是否开启换行：列级开关优先，其次看表格级开关。
fn wraps(p : Placed, cols : Array[Column], table_wrap : Bool) -> Bool {
  table_wrap || (p.x < cols.length() && cols[p.x].wrap)
}

///|
/// 一个格子占用的内容宽度：这些列的宽度之和，加上中间的分隔线。
fn inner_width(
  col_widths : Array[Int32],
  x : Int32,
  span : Int32,
  pad_l : Int32,
  pad_r : Int32,
) -> Int32 {
  let mut total = 0
  for i in 0..<span {
    let idx = x + i
    let w = if idx < col_widths.length() {
      col_widths[idx]
    } else {
      pad_l + pad_r + 1
    }
    if i > 0 {
      total += 1
    }
    total += w
  }
  let inner = total - pad_l - pad_r
  if inner > 0 {
    inner
  } else {
    1
  }
}

///|
/// 算出跨行占位格相对原格子的内容行偏移。原格子跨了多行时，它的内容要按这些
/// 行的累积高度往下排。
pub fn resolve_row_span_offsets(
  grid : Array[Array[Placed]],
  row_heights : Array[Int32],
) -> Unit {
  for y in 0..<grid.length() {
    let row = grid[y]
    for i in 0..<row.length() {
      let p = row[i]
      match p.kind {
        RowSpan(cell_offset, _) => {
          let origin_y = p.y - cell_offset
          let offset = dimension_sum(row_heights, origin_y, cell_offset)
          row[i] = { ..p, kind: RowSpan(cell_offset, offset), }
        }
        _ => ()
      }
    }
  }
}

///|
/// 原行的高度，加上中间每一行的 (1 + 高度)。与 cli-table3 的 `findDimension` 一致。
fn dimension_sum(heights : Array[Int32], start : Int32, span : Int32) -> Int32 {
  let mut total = if start < heights.length() { heights[start] } else { 1 }
  for i in 1..<span {
    let idx = start + i
    let h = if idx < heights.length() { heights[idx] } else { 1 }
    total += 1 + h
  }
  total
}
