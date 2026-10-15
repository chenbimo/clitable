# 边框、宽度与样式

## 边框预设

六套内置预设,通过 `with_chars` 换:

```moonbit
Table::new(cols).with_chars(@clitable.Chars::rounded())
```

预设包括单线直角 `Chars::single()`(`┌─┬─┐`)、双线 `Chars::double()`(`╔═╤═╗`)等。
想要完全自己的形状时,逐字段给 `Chars`:每个字段编译期可见,拼错字段名会在编译期报错,
而不是画出一张缺角的表;置空某段字符即可画出无边框、纯 Markdown 等形态。

## 总宽约束

内容超出给定点阵宽度时,按均摊削列宽;内容窄时表格不自然撑满:

```moonbit
Table::new(cols).with_width(80)
```

## 固定行高

表格行高取内容自然高度;需要留白率一致的表时固定行高,
放不下的内容末行收成省略号:

```moonbit
Table::new(cols).with_row_height(2)
```

## 颜色与样式默认关

默认输出无颜色、无边框色,避免在管道、日志、CI 里出现意外转义序列。
颜色与样式全部 opt-in,终端能力探测由调用方负责——clitable 不读环境。
