///|
/// 实测演示：库里每一种能力各画一张表，直接输出到终端。
///
/// 入口在 .temp/run-demo.sh：WSL 里跑一次，或把 JS 产物交给 bun / node。
/// 颜色与超链接只有在真实终端里才可见，落盘到文件时是一串转义序列。
fn main {
  println(
    "【1】基础表格：列定义说「这一列怎么显示」，行数据说「显示什么」",
  )
  let basic = @clitable.Table::new([
      @clitable.Column::new("Name"),
      @clitable.Column::new("Age").align(@clitable.Right),
      @clitable.Column::new("City").align(@clitable.Center),
    ])
    .push(["Alice", "24", "Hangzhou"])
    .push(["Bob", "30", "Beijing"])
    .push(["Carol", "17", "Suzhou"])
  println(basic)
  println("")

  println("【2】CJK 宽度：全角按 2 列算，列不会跑偏")
  let cjk = @clitable.Table::new([
      @clitable.Column::new("名字"),
      @clitable.Column::new("一句话"),
    ])
    .push(["前端之虎", "写终端表格的"])
    .push(["chensuiyi", "喜欢朴素直接"])
    .push(["テスト", "全角折算"])
  println(cjk)
  println("")

  println("【3】边框预设：rounded / double / ascii / none")
  let cells : Array[Array[String]] = [["a", "b"], ["c", "d"]]
  println(@clitable.Table::grid(cells).with_chars(@clitable.Chars::rounded()))
  println("")
  println(@clitable.Table::grid(cards()).with_chars(@clitable.Chars::double()))
  println("")
  println(@clitable.Table::grid(cells).with_chars(@clitable.Chars::ascii()))
  println("")
  println(@clitable.Table::grid(cells).with_chars(@clitable.Chars::none()))
  println("")

  println(
    "【4】颜色：表头绿加粗、边框蓝、一格红（真实终端可见）",
  )
  let colored = @clitable.Table::new([
      @clitable.Column::new("Name"),
      @clitable.Column::new("Status"),
    ])
    .with_head_style(@clicolor.green.bold())
    .with_border_style(@clicolor.blue)
    .push(["alpha", "ok"])
    .push([
      @clitable.Cell::text("beta"),
      @clitable.Cell::text("failing").color(@clicolor.red),
    ])
  println(colored)
  println("")

  println("【5】跨行跨列：空洞自己补，占位符不用手写")
  let spans = @clitable.Table::new([
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
  println(spans)
  println("")

  println("【6】固定行高：放不下的内容末行收成省略号")
  let fixed = @clitable.Table::grid([["hello\nhi\nsup"], ["two lines\nonly"]]).with_row_height(
    2,
  )
  println(fixed)
  println("")

  println("【7】总宽 60 + 自动换行：窄列折行而不截断")
  let wrapped = @clitable.Table::new([
      @clitable.Column::new("Project").width(10),
      @clitable.Column::new("Description").wrap_lines(),
    ])
    .with_width(60)
    .with_word_wrap()
    .push([
      "clitable", "Unicode tables for the command line, designed for MoonBit",
    ])
    .push(["bm2", "A process manager written in MoonBit"])
  println(wrapped)
  println("")

  println("【8】超链接：终端支持 OSC 8 时文本可点击")
  let linked = @clitable.Table::new([
      @clitable.Column::new("Name"),
      @clitable.Column::new("Where"),
    ])
    .push([
      @clitable.Cell::text("package"),
      @clitable.Cell::text("mooncakes").link("https://mooncakes.io"),
    ])
    .push([
      @clitable.Cell::text("source"),
      @clitable.Cell::text("github").link(
        "https://github.com/chenbimo/clitable",
      ),
    ])
  println(linked)
  println("")

  println("【9】纵向表与无表头网格")
  println(@clitable.Table::kv([("Name", "clitable"), ("License", "MIT")]))
  println("")
  println(@clitable.Table::grid([["x", "y"], ["1", "2"], ["3", "4"]]))
}

///|
fn cards() -> Array[Array[String]] {
  [["foo", "bar"], ["frob", "quuz"]]
}
