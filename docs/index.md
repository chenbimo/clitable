---
layout: home

hero:
  name: clitable
  text: 终端表格渲染库
  tagline: 列定义说明「这一列怎么显示」,行数据说明「显示什么」。纯逻辑、无 FFI,一套 API 在 wasm-gc / js / native 三端可跑。
  actions:
    - theme: brand
      text: 快速上手
      link: /guide/quickstart
    - theme: alt
      text: 设计与语义
      link: /guide/design

---

## clitable 与手拼字符串对比

| 对比项 | clitable | 手拼字符串 |
| --- | --- | --- |
| 列定义 | 一处定义表头、对齐、宽度、内边距 | 表头、列宽、对齐分散在多处 |
| 数据错误 | 单元格数与列数不符直接报错 | 静默错位,测试追查 |
| 显示宽度 | 全角计 2 列、ANSI 计 0 列,带色内容对齐不乱 | 字节/字符数,对不齐 |
| 边框样式 | 六套预设 + 逐字段自定义 | 手写,拼错不易发现 |
| 颜色输出 | 默认无颜色,opt-in | 混入管道与日志很难排查 |
| 运行目标 | wasm-gc / js / native 三端 | 通常只测一端 |

功能面已覆盖参考实现 [cli-table3](https://github.com/cli-table/cli-table3) 的全部能力。

## 它不做的事

不做交互(无 TUI)、不做宽度自动探测(宽度一律由调用方显式给出)、不读环境。
`render()` 是纯函数:不写终端、不读时钟,该输出什么由调用方决定。
