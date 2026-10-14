///|
/// 横向对齐。列级给默认，单元格级可覆盖。
pub(all) enum Align {
  Left
  Center
  Right
} derive(Eq, Debug)

///|
pub extend Align with Eq::{not_equal, equal}

///|
pub extend Align with Debug::{to_repr}

///|
/// 纵向对齐。用于单元格内容不足一格的场景（跨行、固定行高）。
pub(all) enum VAlign {
  Top
  Middle
  Bottom
} derive(Eq, Debug)

///|
pub extend VAlign with Eq::{not_equal, equal}

///|
pub extend VAlign with Debug::{to_repr}

///|
/// 一列：表头文本与展示属性。
///
/// 列的职责只有"怎么显示"：表头、对齐、宽度。取值与格式化属于数据本身，
/// 由 `ToCell` / `ToRow` 决定。列属性收在一处，改一列不必同时改三个下标数组
/// ——这是与 cli-table3 的 `head` / `colWidths` / `colAligns` 分开传的主要区别。
pub struct Column {
  title : String
  align : Align
  width : Int32?
  wrap : Bool
  truncate : String?
} derive(Debug)

///|
pub extend Column with Debug::{to_repr}

///|
pub fn Column::new(title : String) -> Column {
  { title, align: Left, width: None, wrap: false, truncate: None, }
}

///|
pub fn Column::align(self : Column, align : Align) -> Column {
  { ..self, align, }
}

///|
pub fn Column::width(self : Column, width : Int32) -> Column {
  { ..self, width: Some(width), }
}

///|
pub fn Column::wrap_lines(self : Column) -> Column {
  { ..self, wrap: true, }
}

///|
pub fn Column::truncate_with(self : Column, text : String) -> Column {
  { ..self, truncate: Some(text), }
}

///|
/// 一个单元格。内容一律是字符串，数字等类型经 `ToCell` 转换后进来。
pub struct Cell {
  content : String
  col_span : Int32
  row_span : Int32
  h_align : Align?
  v_align : VAlign?
  color : Ansi?
  truncate : String?
  link : String?
} derive(Debug)

///|
pub extend Cell with Debug::{to_repr}

///|
pub fn Cell::text(content : String) -> Cell {
  {
    content,
    col_span: 1,
    row_span: 1,
    h_align: None,
    v_align: None,
    color: None,
    truncate: None,
    link: None,
  }
}

///|
pub fn Cell::span(self : Cell, cols : Int32, rows~ : Int32 = 1) -> Cell {
  { ..self, col_span: cols, row_span: rows, }
}

///|
pub fn Cell::align(self : Cell, align : Align) -> Cell {
  { ..self, h_align: Some(align), }
}

///|
pub fn Cell::middle(self : Cell) -> Cell {
  { ..self, v_align: Some(VAlign::Middle), }
}

///|
pub fn Cell::bottom(self : Cell) -> Cell {
  { ..self, v_align: Some(VAlign::Bottom), }
}

///|
pub fn Cell::color(self : Cell, color : Ansi) -> Cell {
  { ..self, color: Some(color), }
}

///|
pub fn Cell::truncate_with(self : Cell, text : String) -> Cell {
  { ..self, truncate: Some(text), }
}

///|
pub fn Cell::link(self : Cell, url : String) -> Cell {
  { ..self, link: Some(url), }
}

///|
/// 能被放进单元格的内容。为 String / Int / Double / Bool 提供实现，
/// 业务类型可以自己实现它（例如把金额格式化成千分位）。
pub trait ToCell {
  fn to_cell(Self) -> Cell
}

///|
pub impl ToCell for String with fn to_cell(self) {
  Cell::text(self)
}

///|
pub impl ToCell for Int32 with fn to_cell(self) {
  Cell::text(self.to_string())
}

///|
pub impl ToCell for Double with fn to_cell(self) {
  Cell::text(self.to_string())
}

///|
pub impl ToCell for Bool with fn to_cell(self) {
  Cell::text(self.to_string())
}

///|
/// 单元格自己也可以入表，这样跨行列的行可以写成
/// `[Cell::text("a").span(2), Cell::text("b")]`，与普通行混排。
pub impl ToCell for Cell with fn to_cell(self) {
  self
}

///|
pub extend Cell with ToCell::{to_cell}

///|
/// 能被当作一整行的数据。`Array[T]` 自动成为一行，业务类型实现它即可整批入表。
pub trait ToRow {
  fn to_row(Self) -> Array[Cell]
}

///|
pub impl[T : ToCell] ToRow for Array[T] with fn to_row(self) {
  self.map(fn(c) { c.to_cell() })
}

///|
/// 建表与渲染期间的错误。数量对不上直接报错，不做静默补齐。
pub suberror TableError {
  Arity(Int32, Int32)
  TooNarrow(Int32)
}
