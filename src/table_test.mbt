///|
/// 黑盒测试：只看公开 API 与渲染结果。
test "simple table" {
  let t = @clitable.Table::new([
    @clitable.Column::new("Name"),
    @clitable.Column::new("Age"),
  ]).push_rows([["Alice", "24"], ["Bob", "30"]])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───────┬─────┐\n│ Name  │ Age │\n├───────┼─────┤\n│ Alice │ 24  │\n├───────┼─────┤\n│ Bob   │ 30  │\n└───────┴─────┘",
  )
}

///|
test "right aligned column" {
  let t = @clitable.Table::new([
    @clitable.Column::new("N").align(@clitable.Right),
  ]).push_rows([["1"], ["22"]])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌────┐\n│  N │\n├────┤\n│  1 │\n├────┤\n│ 22 │\n└────┘",
  )
}

///|
test "cjk width is counted as two columns" {
  let t = @clitable.Table::new([@clitable.Column::new("名")]).push_rows([
    ["中文"],
  ])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌──────┐\n│ 名   │\n├──────┤\n│ 中文 │\n└──────┘",
  )
}

///|
test "arity mismatch raises" {
  let t = @clitable.Table::new([
    @clitable.Column::new("A"),
    @clitable.Column::new("B"),
  ]).push(["only"])
  let caught = try {
    let _ = t.render()
    false
  } catch {
    @clitable.TableError::Arity(_, _) => true
    _ => false
  }
  assert_eq(caught, true)
}

///|
test "grid has no head" {
  let t = @clitable.Table::grid([["a", "b"], ["c", "d"]])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───┬───┐\n│ a │ b │\n├───┼───┤\n│ c │ d │\n└───┴───┘",
  )
}

///|
/// `Show` 让 `println(table)` 直接可用，这里验证它与 `render` 一致。
test "show delegates to render" {
  let t = @clitable.Table::grid([["a", "b"]])
  assert_eq(
    Show::to_string(t),
    "┌───┬───┐\n│ a │ b │\n└───┴───┘",
  )
}

///|
/// 跨列：上方的格吃掉两列，下面的分隔线在中缝处才落 `┬`。
test "colSpan above normal cells" {
  let t = @clitable.Table::new([
      @clitable.Column::new(""),
      @clitable.Column::new(""),
    ])
    .push([@clitable.Cell::text("greetings").span(2)])
    .push([@clitable.Cell::text("greetings").span(2)])
    .push(["hello", "howdy"])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───────────────┐\n│ greetings     │\n├───────────────┤\n│ greetings     │\n├───────┬───────┤\n│ hello │ howdy │\n└───────┴───────┘",
  )
}

///|
/// 跨行：左侧格子纵跨两行，右侧两行各自成格，接缝处要退成 `├`。
test "rowSpan on the left" {
  let t = @clitable.Table::new([
      @clitable.Column::new(""),
      @clitable.Column::new(""),
      @clitable.Column::new(""),
    ])
    .push([
      @clitable.Cell::text("greetings").span(1, rows=2),
      @clitable.Cell::text("greetings").span(1, rows=2).middle(),
      @clitable.Cell::text("hello"),
    ])
    .push(["howdy"])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───────────┬───────────┬───────┐\n│ greetings │           │ hello │\n│           │ greetings ├───────┤\n│           │           │ howdy │\n└───────────┴───────────┴───────┘",
  )
}

///|
/// 混合跨行跨列：`hello` 跨两列、`sup` 跨两行两列、`hi` 纵跨三行。
/// 交叉字符要分别退成 `┤`、`┼`、`┴`。
test "mixed colSpan and rowSpan" {
  let t = @clitable.Table::new([
      @clitable.Column::new(""),
      @clitable.Column::new(""),
      @clitable.Column::new(""),
      @clitable.Column::new(""),
      @clitable.Column::new(""),
    ])
    .push([
      @clitable.Cell::text("hello").span(2),
      @clitable.Cell::text("sup").span(2, rows=2),
      @clitable.Cell::text("hi").span(1, rows=3),
    ])
    .push([@clitable.Cell::text("howdy").span(2)])
    .push(["o", "k", "", ""])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───────┬───────┬────┐\n│ hello │ sup   │ hi │\n├───────┤       │    │\n│ howdy │       │    │\n├───┬───┼───┬───┤    │\n│ o │ k │   │   │    │\n└───┴───┴───┴───┴────┘",
  )
}

///|
/// 跨行格子错位排布：`a` 跨两行、`c` 在它右侧跨两行、`d` 再往下接一行。
test "staggered rowSpan" {
  let t = @clitable.Table::new([
      @clitable.Column::new(""),
      @clitable.Column::new(""),
    ])
    .push([@clitable.Cell::text("a").span(1, rows=2), @clitable.Cell::text("b")])
    .push([@clitable.Cell::text("c").span(1, rows=2)])
    .push(["d"])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───┬───┐\n│ a │ b │\n│   ├───┤\n│   │ c │\n├───┤   │\n│ d │   │\n└───┴───┘",
  )
}

///|
/// 跨列格子的内容会撑宽它覆盖的列，否则 `hello there` 放不下。
test "colSpan widens the columns below" {
  let t = @clitable.Table::new([
      @clitable.Column::new(""),
      @clitable.Column::new(""),
    ])
    .push([@clitable.Cell::text("hello there").span(2)])
    .push(["hi", "hi"])
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌─────────────┐\n│ hello there │\n├──────┬──────┤\n│ hi   │ hi   │\n└──────┴──────┘",
  )
}

///|
/// 写多了要报错，不静默丢弃。
test "too many cells raises" {
  let t = @clitable.Table::new([
    @clitable.Column::new("A"),
    @clitable.Column::new("B"),
  ]).push(["x", "y", "z"])
  let caught = try {
    let _ = t.render()
    false
  } catch {
    @clitable.TableError::Arity(_, _) => true
    _ => false
  }
  assert_eq(caught, true)
}

///|
/// 超链接：终端支持时可点击，宽度计算要剥掉 OSC 8 转义，否则列会算宽。
test "hyperlink wraps content in OSC 8" {
  let url = "http://example.com"
  let t = @clitable.Table::new([@clitable.Column::new("")]).push([
    @clitable.Cell::text("Text Link").link(url),
  ])
  let out = t.render() catch { _ => "ERR" }
  let linked = "\u{1B}]8;;" + url + "\u{7}Text Link\u{1B}]8;;\u{7}"
  assert_eq(
    out,
    "┌───────────┐\n│ " +
    linked +
    " │\n└───────────┘",
  )
}

///|
/// 固定行高：内容放不下时，末行收成截断符。
test "fixed row height truncates the last line" {
  let t = @clitable.Table::new([@clitable.Column::new("")])
    .push([@clitable.Cell::text("hello\nhi\nsup")])
    .with_row_height(2)
  let out = t.render() catch { _ => "ERR" }
  assert_eq(
    out, "┌───────┐\n│ hello │\n│ hi…   │\n└───────┘",
  )
}
