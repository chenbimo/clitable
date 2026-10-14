# clitable

用 MoonBit 写的终端表格渲染库。

列定义说明「这一列怎么显示」，行数据说明「显示什么」，渲染成 Unicode 表格。

## 状态

骨架阶段，公开接口已定，渲染主干与布局管理器都可用。

已实现：列定义与表头、对齐、内边距、显示宽度（含全角与 ANSI 与 OSC 8 超链接）、截断、断行、六套边框预设、颜色与样式、总宽约束、固定行高、无表头表格、纵向表、跨行跨列（含空洞填补与交叉字符）。

功能面已覆盖参考实现 cli-table3 的全部能力。

## 安装

发布到 mooncakes 之后：

```bash
moon add chensuiyi/clitable
```

## 最小示例

```moonbit
let table = @clitable.Table::new([
  @clitable.Column::new("Name"),
  @clitable.Column::new("Age").align(@clitable.Right),
]).push_rows([["Alice", "24"], ["Bob", "30"]])

println(table)
```

输出：

```text
┌───────┬─────┐
│ Name  │ Age │
├───────┼─────┤
│ Alice │ 24  │
├───────┼─────┤
│ Bob   │ 30  │
└───────┴─────┘
```

`Table` 实现了 `Show`，所以 `println(table)` 直接出表，不必手动 `render()`。

## 几个用法

边框换个样式：

```moonbit
Table::new(cols).with_chars(@clitable.Chars::rounded())
```

约束总宽，超出时按均摊削列宽：

```moonbit
Table::new(cols).with_width(80)
```

无表头表格，列数从第一行推导：

```moonbit
@clitable.Table::grid([["a", "b"], ["c", "d"]])
```

纵向键值表：

```moonbit
@clitable.Table::kv([("Name", "Alice"), ("Age", "24")])
```

跨行跨列，空格子不用手写占位符：

```moonbit
Table::new(cols).push([
  @clitable.Cell::text("greetings").span(2),
  @clitable.Cell::text("sup").span(2, rows=2),
])
```

单元格内容可以带超链接，终端支持时能点击：

```moonbit
@clitable.Cell::text("文档").link("https://mooncakes.io")
```

固定行高，内容放不下时末行收成省略号：

```moonbit
Table::new(cols).with_row_height(2)
```

整批入表的业务类型，实现 `ToRow` 即可：

```moonbit
impl @clitable.ToRow for User with to_row(self) {
  [@clitable.Cell::text(self.name), @clitable.Cell::text(self.age.to_string())]
}

Table::new(cols).push_rows(users)
```

## 设计要点

**列属性收在一处。** 表头、对齐、宽度都挂在 `Column` 上，不必像 cli-table3 那样把表头、列宽、列对齐分三个数组按同一下标维护。

**数量对不上就报错。** 行内单元格数与列表数不一致时 `raise TableError::Arity`，不做静默补齐。

**默认无颜色。** 颜色与边框样式全部 opt-in，避免在管道、日志、CI 里出现意外的转义序列。

**宽度按显示列数算。** 全角字符计 2 列，ANSI 序列计 0 列，所以带颜色的内容也能正确对齐。

## 参考

功能边界参考 [cli-table3](https://github.com/cli-table/cli-table3)（MIT）。本项目是独立的 MoonBit 实现，接口与实现均为重新设计，未移植其代码。

显示宽度依赖 [moonbit-community/unicodewidth](https://mooncakes.io/docs/moonbit-community/unicodewidth)。

## 许可证

MIT。
