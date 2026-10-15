# 单格、跨行与业务类型

行数据由 `Cell` 组成;`"字符串"` 会被自动包成文本单格,更丰富的单格需要显式构造。

## 跨行与跨列

```
Table::new(cols).push([
  @clitable.Cell::text("greetings").span(2),
  @clitable.Cell::text("sup").span(2, rows=2),
])
```

空格子不用手写占位符,被跨的格子由表格自动填补,交界处的交叉字符也自动选对。

## 带超链接的单格

终端支持 OSC 8 超链接时可以点击;不支持时退化为普通文本:

```moonbit
@clitable.Cell::text("文档").link("https://mooncakes.io")
```

超链接本身不计入显示宽度,对齐不受影响。

## 业务类型直接入表

实现 `ToRow` 后,整个列表一次入表:

```moonbit
impl @clitable.ToRow for User with to_row(self) {
  [
    @clitable.Cell::text(self.name),
    @clitable.Cell::text(self.age.to_string()),
  ]
}

Table::new(cols).push_rows(users)
```

## 列定义管显示

表头、对齐、内边距、宽度全部挂在 `Column` 上;校验发生在入表时:
单元格数与列定义数不符即 `TableError::Arity`。对齐取值如 `@clitable.Right`(完整取值见安装后 IDE 中的提示)。
