# 安装与引入

clitable 发布到 [mooncakes](https://mooncakes.io)。把它加进模块的 `moon.mod`:

```moonbit
import {
  "chensuiyi/clitable",
}
```

或者用命令安装:

```bash
moon add chensuiyi/clitable
```

之后在模块内以 `@clitable` 前缀使用:

```moonbit
@clitable.Table::new([@clitable.Column::new("Name")])
```

## 运行目标

- 纯逻辑、无 FFI:`wasm-gc` / `js` / `native` 三端可跑
- 显示宽度依赖 [`moonbit-community/unicodewidth`](https://mooncakes.io/docs/moonbit-community/unicodewidth),会随安装自动拉取,无须额外配置

## 版本

文档右上角的版本号取自 `moon.mod` 的 `version` 字段,与发布保持一致。
