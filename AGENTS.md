# clitable 仓库约定

用 MoonBit 写的终端表格渲染库。纯逻辑、无 FFI，wasm-gc / js / native 三端可跑。

## 工具链

工作区通用铁律（WSL 编译、`_build`/`_build-wsl` 两级目录、wsl 互操作文件通道、push 只在 Windows、告警档连写、依赖库读源码、测试三档）见上级 `../AGENTS.md`，本节只写本仓库特有的。

- 命令模板：`wsl -d Debian -- bash -lc 'cd /mnt/c/codes/moonbit/clitable && <命令>'`

## 目录地图

| 文件 | 职责 |
| --- | --- |
| `src/types.mbt` | `Align` / `VAlign` / `Column` / `Cell` / `ToCell` / `ToRow` / `TableError` |
| `src/chars.mbt` | 边框字符集 `Chars` 与六个预设 |
| `src/width.mbt` | 显示宽度、剥 ANSI、补齐、截断、断行（颜色/链接由依赖 `chensuiyi/clicolor` 提供） |
| `src/layout.mbt` | 布局网格（位置分配、空洞填补、两类占位格）、列宽行高 |
| `src/cell.mbt` | 单元格绘制、交叉字符选择、跨行委托 |
| `src/table.mbt` | `Table` 构建器、渲染管线、`Show` |
| `src/table_test.mbt` | 黑盒测试（只碰公开 API） |

依赖方向单向：`types` / `chars` / `ansi` → `width` → `layout` / `cell` → `table`。底层不得反向引用上层。

布局管线的顺序不能换：`layout_rows`（分配位置并回报每行被跨行占用的列数）→ 行宽校验 → `compute_col_widths` → `compute_row_heights` → `resolve_row_span_offsets` → 逐行绘制。跨行占位格的 `offset` 依赖行高，必须最后解。

## MoonBit 语法约束（本仓库实证，违反即编译失败）

1. struct 字段不能有默认值，默认值只能由构造函数给
2. 位置参数不能有默认值，带默认值必须 labeled（`rows~ : Int = 1`），调用写 `f(rows=3)`
3. 泛型写在 `fn` 之前：`pub fn[T : ToCell] Table::push(...)`
4. `derive(Show)` 已废弃，改用 `derive(Debug)` 或手写 `impl Show`
5. 枚举构造子跨包构造需要 `pub(all) enum`，`pub enum` 是只读的
6. 枚举变体只能带类型，不能写 `RowSpan(a : Int)`，要写 `RowSpan(Int)`
7. `derive(Eq)` / `derive(Debug)` 必须配 `pub extend X with Eq::{ not_equal, equal }` 之类声明，否则 `implicit_impl_as_method` 在 `--deny-warn` 下变错误
8. trait impl 要写 `pub impl`，否则报 `unused_value`
9. `extend`、`guard` 是关键字，不能当方法名或变量名
10. `self` 不能用作普通函数的参数名，否则该函数在其他地方全部报 unbound
11. 内部类型不出现在公开签名里时，要写 `priv struct`
12. `for i in 0..(n + 1)` 不合法，用 `0..=n`；`not(x)` 已废弃，用 `!(x)`
13. `mut` 只用于字段重新绑定。原地改内容（`array.push`）不需要 `mut`，加了反而报 `unused_mut`
14. `StringView` 转 `String` 用 `to_owned()`，`String::split` 返回 `Iter`，收集用 `.to_array()`
15. `try` / `catch` 分支末尾不能跟逗号

## 设计约定

- 列属性收在 `Column`，取值与格式化属于数据本身（`ToCell` / `ToRow`）
- 行内单元格数与列表数不一致时直接 `raise TableError::Arity`，绝不静默补齐
- 默认无颜色，颜色与边框样式全部 opt-in
- `render()` 是纯函数：不写终端、不读环境、不读时钟
- 总宽约束只削不拉，内容窄时表格不撑满一行
- 列宽低于边框与内边距所需时 `raise TableError::TooNarrow`

## 测试

- 黑盒测试命名 `*_test.mbt`（只碰公开 API），白盒测试命名 `*_wbtest.mbt`
- 快检（改完即跑）：`moon check --deny-warn --target-dir _build-wsl`
- 全量（批次收尾）：`bash scripts/devkit/verify.sh`（fmt / check / 多 target 测试 / 构建）

## 文档站

- VitePress 站点在 `docs/`，中文单语；依赖与构建在 Windows 侧跑，锁文件（`docs/bun.lock`）跟踪，`node_modules`、构建产物与缓存不跟踪
- 部署在 `clitable.moonbitlang.dev`（子域名根路径，`base` 为 `'/'`），托管于 Cloudflare Pages 项目 `moonbit-clitable`，推送到 `main` 且 `docs/**` 或 `moon.mod` 有改动时自动重建
- 构建环境变量 `BUN_VERSION`（与写本地锁文件的 bun 版本一致）与 `SKIP_DEPENDENCY_INSTALL=1` 必设，值与原因以及全套上站流程见工作区规范 `NEW-PROJECT.md`
- 名称约定：Pages 项目 `moonbit-clitable`，自定义域 `clitable.moonbitlang.dev`，提交前缀 `clitable`

## Git Hooks 与脚本

激活（仓库初始化后执行一次）：

```bash
git config core.hooksPath .githooks
```

| 文件 | 作用 |
| --- | --- |
| `.githooks/{commit-msg,pre-commit,pre-push}` | 三个入口，只负责把控制权交给 `scripts/devkit/hook-dispatch.sh` |
| `scripts/devkit/hook-dispatch.sh` | 跨边界分发：Linux 下直接跑，Windows 下转 WSL 执行（工具链在 WSL） |
| `scripts/devkit/commit-msg.sh` | 强制提交格式，merge / revert 豁免 |
| `scripts/devkit/pre-commit.sh` | 只在本批改了 `src/` 或 `moon.mod` 时：`moon fmt` 自动修并重新暂存 + 严格 check + moon.mod 完整性 |
| `scripts/devkit/pre-push.sh` | 推送前跑完整 `verify.sh` |
| `scripts/devkit/verify.sh` | 唯一的验收门禁：fmt / check / 多 target 测试 / 构建 |
| `scripts/devkit/lib/common.sh` | `module_check`：严格类型与警告门禁，hook 与 verify 共用 |
| `scripts/devkit/lib/checks.sh` | `check_package_metadata`：moon.mod 必填字段与 readme 存在性 |

以上都是工作区唯一源 `moonbit/scripts` 生成的，**生成物禁改**（后果见该目录 README）；项目只在 `scripts/devkit.conf` 里声明业务事实。

## 提交格式

```text
[clitable](类型) 提交内容
```

类型：`feat` / `fix` / `docs` / `refactor` / `test` / `chore`。中文一句话，结尾不加句号。

## 禁区

- 不引入 FFI，不读时钟与环境，保持多 target 可测
- 不建 `specs/` 一类契约目录：行为只有一处真相（代码加测试名），要提到别处时只放链接
- 不实现百分比宽度、自动终端探测等依赖外部环境的特性，宽度一律由调用方显式给出
