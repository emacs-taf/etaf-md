# 全部语法总览

这一段是普通段落，里面有 **粗体**、*斜体*、`行内代码` 和一个 [链接](https://example.com)。
段落后面跟第二行，不换段。

## 二级标题

### 三级标题

#### 四级标题

- 无序列表第一项
- 无序列表第二项
  - 嵌套的一项
  - 嵌套的另一项

1. 有序列表第一项
2. 有序列表第二项

- [x] 已完成的任务
- [ ] 未完成的任务

> 引用块的第一段。
>
> 引用块的第二段，里面有 `代码`。

```elisp
(etaf-md-open "笔记")
```

| 属性 | 类型 | 默认 |
| --- | --- | --- |
| `title` | string | 无 |
| `columns` | number | 3 |

---

## 卡片

:::card {title="缓存命中" description="一次缩放，不重画" accent=warning width="60ch"}
图片和矢量按页面尺寸缩放一次。

- 命中时读文件
- 未命中时画一次
:::

## 盒子

:::box {surface=raised padding="3ch"}
盒子有底色、内边距与一圈细框。
:::

## 两栏

:::columns {columns=2 gap="2ch"}
:::col
左栏第一段。

左栏第二段。
:::
:::col
右栏只有一段，但比左栏长一些，用来看两栏高度不一致时竖线怎么收。
:::
:::

## 三栏

:::columns {columns=3 gap="2ch"}
:::col
第一栏
:::
:::col
第二栏
:::
:::col
第三栏
:::
:::

## 提示块

:::warning {title="兼容性"}
这段只在 Emacs 30 及以上可用。
:::

:::note
省略标题时用这个强调值固定的标题。
:::

:::tip {title="小技巧"}
提示块也能写标题与正文。
:::

## 标签页

:::tabs
@tab 第一页
第一页的正文。
@tab 第二页
第二页的正文。
:::

## 步骤

:::steps {start=1}
:::step {title="定位"}
先用 `sample` 抓栈，别先猜。
:::
:::step {title="改因"}
改产生现象的那一层，不改它的结果。
:::
:::step {title="复验"}
同一个输入再跑一遍。
:::
:::

列表写法只带标题，正文用 `step` 子块。

:::steps {start=1}
1. 读源码，找出产生现象的那一层
2. 改那一层，不改它的结果
:::

## 时间线

:::timeline
:::event {time="2026-11-12" title="定位到慢在画图"}
`image-size` 会真的把图画出来。
:::
:::event {time="2026-11-13" title="改成读文件头" status="success"}
打开从 5.4 秒降到 0.33 秒。
:::
:::

## 数字组

:::stats
:::stat {title="打开" value="0.33 s"}
:::
:::stat {title="缩放" value="0.18 s"}
:::
:::stat {title="内存" value="349 MB"}
:::
:::

## 字段表

:::field
- 版本：12.3.0
- 渲染器：Chromium，常驻
- 缓存：`~/.cache/etaf-md/typeset`
:::

## 文件树

:::file-tree {title="lisp/"}
- lisp/
  - etaf-md-model.el
  - etaf-md-views.el
- etaf-md.el
:::

## 对话

:::chat
:::message {from="问" time="14:20"}
预览为什么不刷新？
:::
:::message {from="答" time="14:21"}
保存之后才刷新，改到一半不重排。
:::
:::

## 代码标签页

:::code-tabs
@tab
```elisp
(etaf-md-open)
```
@tab
```python
print("hi")
```
:::

## 折叠

:::accordion
:::collapse {title="完整的报错"}
```
后面的长文本放这里。
```
:::
:::collapse {title="版本差异"}
第二折的正文。
:::
:::

## 表格容器

:::table {title="打开耗时" highlight-rows="3" highlight=warning}
| 版本 | 耗时 |
| --- | --- |
| 0.1.9 | 5.4 s |
| 0.2.0 | 0.33 s |
:::

## 演示窗口

:::window {title="etaf-md-preview"}
一段界面截图或者一段文字。
:::

## 嵌套

:::card {title="外层卡片" description="里面再放盒子和分栏"}
:::box {surface=sunken}
卡片里的盒子。
:::

:::columns {columns=2}

:::col
嵌套左栏
:::

:::col
嵌套右栏
:::

:::
:::

## 围栏里的同名字样

```markdown
:::card {title="这是代码"}
:::
```

