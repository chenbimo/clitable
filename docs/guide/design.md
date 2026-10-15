# 设计与语义

## 设计要点

**列属性收在一处。** 表头、对齐、宽度都挂在 `Column` 上;不像 cli-table3 把表头、列宽、列对齐分三个数组按同一下标维护。

**数量对不上就报错。** 行内单元格数与列表数不一致时 `raise TableError::Arity`,不做静默补齐;表列放不下时 `TableError::TooNarrow`。

**颜色默认无。** 颜色与边框样式全部 opt-in,管道、日志与 CI 里不会有意外转义序列。

**宽度按显示列数算。** 全角字符计 2 列、ANSI 序列计 0 列,带颜色的内容也能对齐;OSC 8 超链接同样零宽。

**渲染是纯函数。** `render()` 不写终端、不读时钟、不探测环境;输出的选型由调用方决定,便于把表格嵌进任何输出目标(文件、网页、日志)。

**跨行不做占位。** 被跨格子自动填补空洞,交叉字符自动选对;单格 `span(col, rows)` 两个方向都支持。

## 已实现

- 列定义、表头、对齐、内边距
- 显示宽度:全角、ANSI 与 OSC 8 超链接
- 截断与断行
- 六套边框预设与逐字段自定义
- 颜色与样式(opt-in)
- 总宽约束、固定行高、无表头表格
- 纵向键值表
- 跨行跨列(含空洞填补与交叉字符)

## 参考与许可

功能边界参考 [cli-table3](https://github.com/cli-table/cli-table3)(MIT)。
本项目是独立的 MoonBit 实现,接口与实现均为重新设计,未移植其代码。显示宽度依赖
[`moonbit-community/unicodewidth`](https://mooncakes.io/docs/moonbit-community/unicodewidth)。许可是 [MIT](https://github.com/chenbimo/clitable/blob/main/LICENSE)。
