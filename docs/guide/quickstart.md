# 快速上手

## 最小示例

```moonbit
let table = @clitable.Table::new([
  @clitable.Column::new("Name"),
  @clitable.Column::new("Age").align(@clitable.Right),
]).push_rows([["Alice", "24"], ["Bob", "30"]])

println(table)
```

输出:

```text
┌───────┬─────┐
│ Name  │ Age │
├───────┼─────┤
│ Alice │ 24  │
├───────┼─────┤
│ Bob   │ 30  │
└───────┴─────┘
```

`Table` 实现了 `Show`,所以 `println(table)` 直接出表,不必手动 `render()`。

## 三种成品器

除 `Table::new`(带表头)之外,还有两种从原始数据直接成表的方式:

无表头表格,列数从第一行推导:

```moonbit
@clitable.Table::grid([["a", "b"], ["c", "d"]])
```

纵向键值表,适合配置一览:

```moonbit
@clitable.Table::kv([("Name", "Alice"), ("Age", "24")])
```

## 错误即错误

行内单元格数与列定义数不一致时,`raise TableError::Arity`,不做静默补齐。
列宽低于边框与内边距所需时,`raise TableError::TooNarrow`。

## 下一步

- 要换边框、约束总宽、设固定行高:见[边框、宽度与样式](/guide/features)
- 要跨行跨列、带超链接、让业务类型直接入表:见[单格、跨行与业务类型](/guide/cells)
