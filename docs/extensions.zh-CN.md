# 扩展语法

> **状态。** 今天页面能渲染的只有 GitHub 提示块，写法是 `> [!NOTE]`、`[!TIP]`、`[!IMPORTANT]`、`[!WARNING]`、`[!CAUTION]`。本文其余部分是设计契约，先把模型、语法、属性和验收定下来，实现时照它做。标「计划中」的名字今天都不存在，函数名也只是提案。
>
> **怎么读。** 写文档看第 3、5、6 章。给这个包定义容器看第 9 章。实现渲染器看第 2、7、8、10 章。想知道现在能用什么，直接看 6.16 的状态总表。
>
> 中英两版一节对一节。改一处，另一处同时改。

## 1. 定位

### 1.1 这个包做什么

一件事：把一份 Markdown 文档变成 ETAF 视图，挂在 buffer 里给人读。输入是文本，输出是字符网格上的盒子、文本和 face。

它自带一套容器词汇，让文档能写出普通 Markdown 写不出的结构：提示块、卡片、步骤、标签页、时间线。词汇是关闭的，用户可以在第 9 章的口子上加，但文档本身不能定义新东西。

### 1.2 边界：文档与页面

页面、目录、路由、导航、数据源、发布，这个包一概不知道。那些属于上层应用。

上层应用有自己的页面模型、布局注册表、目录树、站点导航和数据源。它 `require` 这里的根入口，只调用公开接口。这里不为上层的策略加开关、加参数。

两边的接缝只有一处：文档变成视图。今天还没有这个接口，公开的只有创建会话、打开、关闭、导航、状态和诊断。上层真要把渲染结果嵌进自己的区域时，这个包补两个入口，一个是给一段文本或一个文件返回可以直接挂进任意区域的视图，另一个是容器注册。两个都算计划中。

这个包也不产出 HTML。它画的是 buffer。要让别人在浏览器里看，那是上层应用自己的后端。

一条容易混的地方先钉住：第 5 章的 `columns` 是**文档内部的栏**，管一段正文怎么排。页面的版式是上层注册表里的名字，不在本文范围内。

### 1.3 参考对象和它的差距

设计参考 `vuepress-theme-plume`。它的 Markdown 扩展在 `plugins/plugin-md-power/` 里，真实结构是三样东西。

- **一个容器工厂**，在 `src/node/container/createContainer.ts`。它暴露 `createContainerPlugin` 和 `createContainerSyntaxPlugin`，前者让内容照常按 Markdown 解析，后者自己处理内容。
- **一张注册表**，在 `src/node/container/index.ts`。一次装二十来个预设：`align`、`tabs`、`code-tabs`、`window`、`steps`、`card`、`card-grid`、`card-masonry`、`encrypt`、`npm-to`、`lang-repl`、`file-tree`、`code-tree`、`timeline`、`collapse`、`chat`、`field`、`table`。
- **三十来个客户端组件**，例如 `VPCodeTabs`、`VPTabs`、`VPCollapse`、`VPField`、`VPTimeline`、`VPCodeTree`、`VPTable`、`VPPlot`、`VPAnnotation`、`VPQRCode`、`VPPdf`、`VPArtPlayer`、`VPCodePen`、`VPCodeSandbox`、`VPCard`、`VPCardGrid`、`VPCaniuse`。

照抄不行，三条硬差别。

1. **产物不同。** plume 的产物是 HTML、Vue 组件和 CSS。我们的产物是字符网格上的盒子、文本和 face。一个容器最后落到 buffer 里，就是若干行带文本属性的字符。
2. **表达力不同。** CSS 有任意长度、绝对定位、渐变、圆角、阴影和动画。字符网格只有行高、字符宽、边框、底色、字重、下划线，加上框线字符。
3. **运行环境不同。** plume 的页面带客户端脚本。我们的页面是纯文本结果，读的人要能用 isearch 搜到它，用 `C-w` 复制，用 org 导出，在终端里看。

照抄的症状很明显。卡片的圆角和阴影会变成乱码字符，标签页的滑动动画会变成逐帧重绘，聊天头像会变成缺字方块。

能借鉴的是两件事，不是实现。

1. **容器工厂。** 二十个效果共用两个工厂函数，说明这个名字收敛得对。我们照这个形状做，渲染钩子返回 ETAF 视图。
2. **效果清单。** plume 解决过的问题就是一张需求表。逐个问「这个问题在字符网格里长什么样」。网格里说得清的吸收，说不清的不做，理由写进附录 D。

## 2. 模型

### 2.1 块、容器、父子

一篇文档是一串块。块可以是段落、标题、列表、代码、表格，也可以是一个容器。

容器有名字、属性、内容。内容是解析好的块，不是字符串，也不是 HTML。所以容器里能装页面能装的任何东西，包括别的容器。

解析器只认三件事：开、关、嵌套。它不知道 `tab` 是什么意思，也不知道 `card` 有什么属性。名字的含义归注册表，属性的含义归定义，摆放归渲染。

### 2.2 三种容器

写文档的人只看见一种形状，但系统里有三种角色。定义必须声明自己是哪一种。

| 角色 | 内容是什么 | 例子 | 规则 |
| --- | --- | --- | --- |
| 独立块 | 任意块 | `note`、`card`、`box`、`table` | 可以出现在任何能出现段落的地方 |
| 父容器 | 只收它声明的子块 | `columns`、`tabs`、`steps` | 子块的名字只在它内部有效 |
| 子块 | 没有父容器就没有意义 | `col`、`tab`、`step`、`item` | 出现在父容器外是错误，不做猜测 |

一条规则连接三者：**子块的名字由父容器解释，解析器不认它们。** 所以 `:::tab` 在 `tabs` 里是一个标签，在页面顶层只是一行没法解释的文字，按失败规则报出来。

父子关系不跨层。`tabs` 里的 `tab` 可以再装一个 `card`，但 `tab` 不能再装一个 `tab`。要嵌套就再包一层 `tabs`。

### 2.3 四个扩展点

系统有四层，每层的权限不一样。

| 层 | 谁决定 | 改什么 | 能不能改 |
| --- | --- | --- | --- |
| 语法 | 包的解析器 | 文本怎么变成节点 | 不能 |
| 结构 | 文档和容器定义 | 多一种块、块收哪些属性 | 能，见第 9 章 |
| 外观 | 读者的样式表 | 颜色、字重、前缀、间距、编号 | 能，见 4.3 |
| 渲染 | 读者的函数 | 一个节点画成什么 | 能，见 9.4 |

四层共用一个节点模型：`(类型 属性 子节点 出处)`。内置节点和容器节点在这张表里没有区别：`heading` 是类型叫 heading、带 `:level` 的节点，`card` 是类型叫 card、带 `:title` 的节点。

还有一条：**定义本身能被覆盖**。读者可以给一个类型加键、换画法，甚至整条替掉。加键只对读者侧有效，文档侧的属性表不开放，见 9.5。

### 2.4 管道

```
文本 → 解析 → 节点树 → 派生 → 渲染 → 视图
```

- **解析**：封闭。调用共享的 `etaf-ui-markdown-parse`，本文不改它。
- **派生**：整篇算一次。标题编号、表格序号、锚点、块的显示身份都在这一步。
- **渲染**：按块独立。样式和渲染函数在这一步生效。

派生为什么要单独一步。块是独立重画的，编号却要看整篇。放进渲染，重画一块就要重算全篇；放进解析，又把显示决策混进了语法层。

两条派生规则。

- **锚点从原文算，不从显示文字算。** 标题的 `§` 前缀是显示层的事。改前缀不能断掉别人收藏的 `#安装` 链接。
- **编号只在样式要求时算。** 关掉编号就跳过这一步，不做无用功。

### 2.5 九个不变量

每个新容器都必须同时满足这九条。少一条，这个容器就不该进注册表。

| 不变量 | 判据 |
| --- | --- |
| 一种语法 | 新效果只加名字，不加标点。没有第二种块标记 |
| 一个内容模型 | 内容是块，不是字符串，不是 HTML。容器不改解析 |
| 一套属性 | 属性名和含义来自一张共享词汇表，容器只挑选，不发明同义词 |
| 一组布局 | 摆放只用 `box`、`columns` 和共享的间距属性 |
| 一个外观来源 | 颜色来自面与语气，字号来自读者 |
| 一条失败规则 | 坏块留源码加一行说明，页面继续渲染 |
| 状态归渲染器 | 文档不写行为，交互由容器定义实现 |
| 一条渲染路径 | 内置节点、容器节点、读者样式走同一张表，代码里没有按名字的分支 |
| 可移植 | 没有定义时页面仍可读，只是少效果 |

## 3. 语法

### 3.1 开与关

````markdown
:::card {title="缓存命中" surface=panel}
图片和公式都按矢量画一次，之后按页面尺寸缩放。

- 命中时读文件
- 未命中时画一次
:::
````

| 规则 | 说明 |
| --- | --- |
| 名字 | 只收小写字母、数字、连字符，例如 `card`、`code-tabs` |
| 属性 | 花括号里的 `键=值`，空格分隔；没有属性时整对花括号省略 |
| 关闭 | 开几个冒号就关几个冒号，最少三个；关闭行不写名字 |
| 嵌套 | 外层用更多冒号，例如 `::::box` 里放 `:::card` |
| 深度 | 最多 8 层。第 9 层报错，不渲染 |
| 空容器 | 允许。渲染成只有标题或一个空位，不算错误 |
| 开头 | `:::` 必须独占一行，前面只允许空白 |

关闭行不写名字是一个有意的选择。写了名字就要校验两处名字一致，还要决定不一致时报哪一边。省略名字，只数冒号，永远不会错配。

深度上限是 8，不是无限。每层都是一个盒子，窄窗口里读的人数不清自己站在第几层；每层还要一次测量和一次重排，深一层就多一层成本。上限把最坏情况钉住。

### 3.2 子块与父容器

外层要包住一个同名容器，就给外层多写一个冒号。

````markdown
::::box {surface=panel}
:::card {title="里面"}
内容
:::
::::
````

子块的写法和普通容器一样，只是名字由父容器解释。父容器决定它收哪些子块、子块上哪些属性有效。

````markdown
:::columns {tracks="2fr 1fr" gap="2ch"}
:::col
左边这一栏是普通 Markdown。
:::col
右边这一栏也是。
:::
````

父容器必须能处理三种边缘情况，不允许崩溃或者画出半块。

- **没有子块**：画容器自己的空状态，不报错。
- **子块顺序不对**：按出现顺序解释，不重排。
- **子块缺必填属性**：那一块降级，别的子块照常。

### 3.3 属性

七种类型。

| 类型 | 写法 | 含义 | 非法示例 |
| --- | --- | --- | --- |
| `string` | `title="缓存命中"` | 文本。含空格就加双引号，引号里的 `\"` 是转义 | `title=缓存 命中` |
| `number` | `start=2` | 整数或小数，可带负号 | `start=two` |
| `bool` | `open=true` | 只认 `true` 和 `false` | `open=yes` |
| `length` | `gap="2ch"` | 数字加单位：`ch`、`lh`、`px`、`%` | `gap=2` |
| `color` | `tone=info` | 语义词，见 4.1；不收十六进制 | `tone="#24262a"` |
| `enum` | `items=center` | 定义里列出的词之一 | `items=middle` |
| `regex` | `id="^[a-z]+$"` | 值要匹配这个模式 | `id="A-1"` |

四条约定。

- **属性名共享。** `title` 在卡片、提示块、折叠、演示窗口里是同一个意思。容器只挑选词汇表里的名字，不发明 `heading`、`caption` 这类同义词。
- **一个名字一个类型。** `cols` 永远是数字（等宽几栏），要写比例就用 `tracks`。同一个名字在不同容器里换类型是禁止的。
- **没有单位就没有长度。** `gap=2` 是错的，`gap="2ch"` 是对的。一个数字可能是字符、可能是行、可能是像素，猜错一次就排错一次。
- **布尔只认 `true` 和 `false`。** 不认 `yes`、`1`、`on`。三种写法意味着三条解析分支。

同一个属性写两次是错误，不取后者。理由：重复通常意味着作者改了一半，静默取一个会把问题藏起来。

共享属性表在附录 A，容器只引用它。定义里怎么声明这些类型，见 9.2。

### 3.4 校验、降级与失败目录

校验在搭视图之前一次做完，把这一块的所有错误一起报。报错是一条灰字，写在源码块上方，行号是容器开头那一行。

````markdown
:::card {title="缓存命中" colour=blue tone="#24262a"}
内容
:::
````

```
line 42: card 不收 "colour"，它收 title、description、surface、tone、href、align、width
line 42: card 的 tone 是 "#24262a"，它只认 neutral、info、ok、warn、danger、important
line 44: 第 9 层嵌套超过上限 8 层
```

失败分十二种。每一种都有确定的页面表现，不允许「看情况」。

| 情况 | 页面表现 | 影响范围 |
| --- | --- | --- |
| 名字没有定义 | 源码原样加一行说明 | 这一块 |
| 属性不认识 | 源码原样，说明列出它认的属性 | 这一块 |
| 属性值不合法 | 源码原样，说明给出值和一个合法例子 | 这一块 |
| 必填属性缺失 | 源码原样，说明点名缺哪个 | 这一块 |
| 属性写了两遍 | 源码原样，说明点名重复的那个 | 这一块 |
| 子块出现在父容器外 | 源码原样，说明它属于谁 | 这一块 |
| 子块缺必填属性 | 源码原样，父容器继续解析其余子块 | 这个子块 |
| 父容器没有子块 | 画空状态，不报错 | 这一块 |
| 嵌套超过 8 层 | 源码原样，说明层数 | 这一块 |
| 未闭合 | 开头的 `:::` 行当作普通文字，后面照常解析 | 这一行 |
| 定义自己报错 | 源码原样，说明是哪个定义、报了什么 | 这一块 |
| 契约版本不符 | 源码原样，说明要哪个版本 | 这一块 |

三条通则。

1. **不弹窗。** 报错是页面的一部分，不是 Emacs 的错误。一份有十处错的文件，弹十次窗就没法读了。
2. **不中断整页。** 只有出错的那一块降级，别的照常渲染。
3. **一行一条。** 同一块的多条错误各占一行，按属性在定义里声明的顺序排。

错误文案跟着页面语言走。中文页面给中文，英文页面给英文，标签机制和提示块的标题共用一套。

### 3.5 未闭合与恢复

未闭合的容器不吞掉后面的正文。开头的 `:::` 行当作普通文字，后面照常解析。

````markdown
:::card {title="少了一个关闭行"}
这段仍然是正文。

## 后面的标题照常成立
````

这个选择偏向读者。吞掉半篇文档比多一行字糟得多，而且作者改起来也更难发现。

## 4. 外观与样式

### 4.1 面与语气

外观只有两个属性，`surface` 管底，`tone` 管强调。两套词分开，因为它们是两件事。

| `surface` | 底色 | 用在哪 |
| --- | --- | --- |
| `none` | 不画底 | 默认。正文里的卡片、并排的块 |
| `panel` | `panel` 令牌 | 代码块、需要边界的卡片 |
| `quote` | `quote-bg` 令牌 | 引用性质的块 |
| `sunken` | `panel2` 令牌 | 表头、次要信息 |
| `page` | `bg` 令牌 | 需要和正文拉开的地方 |

| `tone` | 前景 | 浅底 | 语义 |
| --- | --- | --- | --- |
| `neutral` | `ink` | `panel` | 没有语气 |
| `info` | `accent` | `accent-soft` | 说明、提示 |
| `ok` | `ok` | `ok-soft` | 成功、建议 |
| `warn` | `warn` | `warn-soft` | 注意 |
| `danger` | `danger` | `danger-soft` | 危险 |
| `important` | `important` | `important-soft` | 重要 |

语气只影响强调色和浅底，不改字号、不改字重、不改行高。要更强的强调就换语气，不要叠效果。

### 4.2 令牌

令牌是渲染器内部的名词。文档里写 `tone=info`，不写 `accent`，更不写色值。

| 令牌 | 用途 |
| --- | --- |
| `bg` | 页面底色 |
| `ink` | 正文 |
| `muted` | 次要文字、说明 |
| `faint` | 最弱的一层，序号、分隔 |
| `accent` / `accent-soft` | 信息类 |
| `panel` / `panel2` | 面 |
| `border` | 边框、分隔线 |
| `quote-bg` / `quote-bar` | 引用 |
| `table-header` / `table-stripe` | 表格 |
| `heading` | 标题 |
| `ok` / `ok-soft` | 成功 |
| `warn` / `warn-soft` | 注意 |
| `danger` / `danger-soft` | 危险 |
| `important` / `important-soft` | 重要 |

令牌在三种配色下各有一套值，跟随 Emacs 主题时由当前 frame 的 face 推出来。容器只声明面与语气，配色换了它跟着换。

**为什么不收十六进制。** 一个在暗色页上好看的 `#24262a`，换到纸色页就是一块黑斑。写十六进制会报错，报错行里列出这个属性认的语义词。

### 4.3 样式表

样式表是读者改外观的地方。一张表，按节点类型给键值。

```elisp
(setq etaf-md-styles
      '((heading . ((:weight bold :color heading)        ; 所有级别
                    (:level 1 :color accent :scale 2.0 :prefix "§ ")
                    (:level 2 :prefix "▌ ")
                    (:level 6 :weight normal :color muted)))
        (quote   . ((:bar-color quote-bar :bar-width "3px"
                     :background quote-bg :slant italic)))
        (code    . ((:background panel :border border :tag-color muted)))
        (table   . ((:header table-header :stripe table-stripe :border border)))
        (strong  . ((:weight bold)))
        (em      . ((:slant italic)))
        (link    . ((:color accent :underline t)))
        (callout . ((:tone-colors ((neutral . ink) (info . accent)
                                   (ok . ok) (warn . warn)
                                   (danger . danger) (important . important)))))))
```

四条规则。

- **省略是继承，`nil` 是关闭，`:default` 是回落内置。** 三句话回答「怎么改回来」。`(:level 1 :prefix nil)` 是去掉一级的前缀；把 `:prefix` 整个删掉，就是从节点级继承；`:color :default` 是回到内置颜色，不管节点级写了什么。
- **先匹配节点级，再匹配级别。** `heading` 的 `:level 1` 盖在节点级上，最终是 `:weight bold :color accent :scale 2.0 :prefix "§ "`。
- **每个键的类型固定。** 未知键加载时报错，这类型回退内置，页面照常渲染。
- **内置样式也写在这张表里。** 代码里没有字面颜色值，所以你改的和你看的是同一套东西。

`etaf-md-define-style` 往同一张表里写，不是第二套。同一个键在两处都写时，后生效的那个赢。

改了表要重画整页并重新派生，但不重新解析，见 8.2。表里的键是包自带的词汇，要给一个类型加新键，写一个渲染函数，见 9.4。

### 4.4 两套颜色权限

| 谁 | 能写什么 | 为什么 |
| --- | --- | --- |
| 文档 | 语义词，例如 `tone=warn`、`surface=panel` | 文档要能在任何主题、任何机器上读 |
| 读者样式 | 令牌名，或字面值 `"#ff0000"` | 读者拥有自己的页面 |

写字面值有一个代价：它不跟随主题切换。暗色页上选的蓝，换到纸色页可能读不清。所以文档里永远不写字面值，这条是硬规矩。

### 4.5 字号与度量

文档里没有字号属性，也没有等价的写法。容器和正文永远同一个字号。

读者样式表里有 `:scale`，它是读者基准字号的**倍数**，不是磅数。`1.0` 是正文，一级标题默认 `2.0`，二级 `1.5`。换台机器字号变了，比例不变。

缩放会撑高这一块的行，所以块流按实际高度排，不假设一行。不缩放时，层级靠字重、颜色、前缀、一条线、一块底色。

两个反例。一个 `size=large` 的卡片，在 12 号字的机器上占 3 行，在 20 号字的机器上占 5 行，同一份文档在两台机器上版面完全不同。一个缩到 80% 的表格，在窄窗口里字比正文小一号，读者会以为自己放大了页面。

### 4.6 装饰字符

装饰只用 ASCII 和框线字符，不用 emoji，不用变体选择符。

允许的集合是 `-`、`=`、`|`、`+`、`*`、`` ` ``、`.`、`o`，加上 `─│┌┐└┘├┤┬┴┼`。

理由：这个集合在等宽字体里都占一格。emoji 的宽度由字体决定，可能一格、可能两格，还会因为缺字变成方块；变体选择符（U+FE0E）在有些字体上会把整行撑高，底部一行被裁掉。

框线字符只在画树和表格时用，不用来画卡片边框。卡片边框由渲染器画，属性里没有「边框字符」这一项。

## 5. 布局

### 5.1 一个结构容器

多栏只有一种写法，`columns`。原来分开的 `layout`、`flex`、`card-grid` 合并成它一个，因为它们的差别只是默认值。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `cols` | number | 无 | 等宽几栏。写了 `tracks` 就忽略它 |
| `tracks` | string | 无 | 一串轨道，空格分隔，单位 `fr`、`ch`、`%` |
| `gap` | length | `"2ch"` | 栏间距 |
| `pad` | length | 无 | 内边距，四边同值 |
| `min` | length | `"24ch"` | 每栏最小宽度，放不下就叠成一栏 |
| `items` | enum | `stretch` | 子块在交叉轴的对齐：`start`、`center`、`end`、`stretch` |
| `justify` | enum | `start` | 主轴：`start`、`center`、`end`、`between` |
| `wrap` | bool | `false` | 放不下时换行，不叠栏 |
| `align` | enum | `start` | 容器自身在父级里的水平位置：`start`、`center`、`end` |

子块是 `col`，收一个属性。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `grow` | number | `1` | 分到剩余宽度的份数 |

````markdown
:::columns {tracks="2fr 1fr" gap="2ch"}
:::col
## 一次命中

缓存里只有一张图，命中时页面从磁盘读它，不再启动渲染器。
:::col
旁边的说明写成普通段落就行，宽度由栏决定。
:::
````

三张卡片并排，就是 `columns` 里放三个 `card`。

````markdown
:::columns {cols=3}
:::card {title="解析"}
文本到语义树。
:::card {title="排版"}
语义树到视图。
:::card {title="发布"}
视图到 buffer。
:::
````

### 5.2 轨道、间距、内边距

- `cols` 是等宽轨道。`cols=3` 就是三条 `1fr`。
- `tracks` 是显式轨道，按 Ebox 的写法：`(fr 2)` 写成 `2fr`，固定宽写 `20ch`，百分比写 `30%`。
- `gap` 只加在块与块之间，不加在外面。外面那一圈归 `pad`。
- `pad` 只收一个长度，四个方向同值。不做 `pad-x`、`pad-y`，两个轴分开给会让同一页出现两种内边距。
- 垂直间距用 `lh` 的整数倍。用像素会让行距和行高对不上，边框压在字上。

### 5.3 窄窗降级

放不下并排的栏时，按顺序降级，不做横向滚动。

1. **减栏。** `cols=3` 先降到 2，再降到 1，每栏不小于 `min`。
2. **叠栏。** 用了 `tracks` 的，每栏小于 `min` 时整块叠成一栏，栏与栏之间留一个空行。
3. **收边距。** `pad` 从 2ch 收到 1ch，`gap` 从 2ch 收到 1ch，外框保留。
4. **保持字号。** 无论降到哪一档，字号不变，行高不变。

`wrap=true` 时先换行，换到一行只剩一栏还放不下，才叠。

### 5.4 三个结构容器怎么选

只有三个，判据是内容关系。

| 想要什么 | 用哪个 | 理由 |
| --- | --- | --- |
| 并排 | `columns` | 唯一的多栏机制 |
| 一块有标题、有边界的材料 | `card` | 标题比正文重，比节标题轻 |
| 一块没有标题、只要底色或内边距 | `box` | 卡片的最简形式，不画标题行 |

**不该用的地方。** 两段并列的正文不要用 `columns` 硬凑成表格；表格用表格。三行两列的键值不要用 `card`，那是 `field`。

## 6. 容器目录

### 6.1 家族总览

| 家族 | 容器 | 共同点 |
| --- | --- | --- |
| 结构 | `columns`、`card`、`box` | 只决定摆放和边界，不解释内容 |
| 提示 | `note`、`tip`、`important`、`warning`、`caution` | 一种定义，五个固定语气 |
| 集合 | `steps`、`timeline`、`stats`、`field`、`file-tree`、`chat` | 子块带标签，按顺序或按名字排 |
| 交互 | `tabs`、`code-tabs`、`collapse`、`collapse-group` | 有状态，可按键切换 |
| 文稿 | `table`、`window` | 包住别的东西，换一种呈现 |

### 6.2 提示块

已实现的是 GitHub 写法，标记放在引用块第一行。

```markdown
> [!WARNING]
> 这段只在 Emacs 30 及以上可用。
```

计划中的容器写法，五个名字共用一套属性。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 该语气的固定标题 | 换掉标题文字 |
| `collapsible` | bool | `false` | 允许收起 |
| `open` | bool | `true` | 收起时默认展开 |

```markdown
:::warning {title="兼容性" collapsible=true}
这段只在 Emacs 30 及以上可用。
:::
```

两个写法渲染成同一个东西，都在同一张定义上。语气映射是固定的：`note` 对 `info`，`tip` 对 `ok`，`important` 对 `important`，`warning` 对 `warn`，`caution` 对 `danger`。

为什么两条路都留。GitHub 上的文档粘贴过来就能用，这是最常见的入口；写长文档时容器写法能和别的容器对齐，也能带属性。

### 6.3 卡片

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 标题，省略就不画标题行 |
| `description` | string | 无 | 标题下一行灰色摘要 |
| `surface` | enum | `panel` | 见 4.1 |
| `tone` | enum | `neutral` | 见 4.1 |
| `href` | string | 无 | 整张卡片可点，跳到这个地址 |
| `align` | enum | `start` | 内容水平位置 |
| `width` | length | `stretch` | 自身宽度 |

解决的场景：一组并列材料需要一个共同边界。用标题分节会把材料抬到节标题同级，用列表会把图压成一项。

映射：ETAF UI 的 `etaf-card`，`default` 槽接正文，`title` 和 `description` 直接对应。

### 6.4 盒子

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `surface` | enum | `none` | 见 4.1 |
| `tone` | enum | `neutral` | 见 4.1 |
| `pad` | length | 无 | 内边距 |
| `align` | enum | `start` | 内容水平位置 |
| `width` | length | `stretch` | 自身宽度 |

盒子是卡片的无标题形式。居中一张图就是它。

```markdown
:::box {align=center pad="1lh"}
![示意图](figures/hit.png)
:::
```

### 6.5 步骤

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `start` | number | `1` | 起始编号 |
| `marker` | enum | `number` | `number` 用数字，`dot` 用圆点 |

子块是 `step`，属性 `title` 必填。

```markdown
:::steps
:::step {title="定位"}
用 `sample` 抓栈，别先猜。
:::step {title="改因"}
改产生现象的那一层，不改它的结果。
:::
```

解决的场景：操作手册里读者要看得出有几步、站在第几步。用有序列表也能写，但编号和标题挤在一行，长标题折行后编号落单。

映射：ETAF UI 的 `etaf-steps`。

### 6.6 时间线

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `marker` | enum | `dot` | `dot`、`number`、`none` |

子块是 `event`，属性 `title` 必填，`time` 可选。

```markdown
:::timeline
:::event {time="2026-11-12" title="定位到慢在画图"}
`image-size` 会真的把图画出来。
:::event {time="2026-11-13" title="改成读文件头"}
打开从 5.4 秒降到 0.33 秒。
:::
```

解决的场景：版本记录、事故经过。用列表会丢掉「时间在上、内容在下」的对齐。

映射：ETAF UI 的 `etaf-timeline`。

### 6.7 字段表

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `label-width` | length | 自动 | 名称列宽度，省略时按最长的名称算 |
| `separator` | enum | `colon` | `colon` 用冒号，`none` 只留间距 |

内容是列表，每项第一个冒号前是名称。

```markdown
:::field
- 版本：12.3.0
- 渲染器：Chromium，常驻
- 缓存：`~/.cache/etaf-md/typeset`
:::
```

解决的场景：参数说明、环境信息。两列表格要写表头和对齐行，太重。

### 6.8 数字组

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `cols` | number | `3` | 一行放几个，窄窗减少 |

子块是 `stat`，属性 `title` 必填（说明文字），`value` 必填（数字文本）。

```markdown
:::stats
:::stat {title="打开" value="0.33 s"}
:::stat {title="缩放" value="0.18 s"}
:::stat {title="内存" value="349 MB"}
:::
```

数字用 `ink` 加粗，说明用 `muted`。超过一行换行，不缩字号。映射：ETAF UI 的 `etaf-statistic`。

### 6.9 文件树

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 树上方一行标题 |
| `marker` | enum | `ascii` | `ascii` 画树线，`none` 只缩进 |

内容是缩进列表，一层一个 `-`。

```markdown
:::file-tree {title="lisp/"}
- lisp/
  - etaf-md-model.el
  - etaf-md-views.el
- etaf-md.el
:::
```

解决的场景：讲清一个目录里有什么。围栏代码也能写，但树线要和缩进对齐，手写容易错一格。记号只用 4.6 允许的字符。

### 6.10 对话

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `me` | enum | `left` | 自己说的话放哪边：`left`、`right` |

子块是 `said`，属性 `from` 必填（发送者），`time` 可选。

```markdown
:::chat
:::said {from="问" time="14:20"}
预览为什么不刷新？
:::said {from="答" time="14:21"}
保存之后才刷新，改到一半不重排。
:::
```

解决的场景：教程里演示一次问答。它是一块对齐的文本加缩进，不画气泡。

### 6.11 标签页

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `active` | string | 第一个 | 默认显示哪个标签，写标签文字 |

子块是 `tab`，属性 `label` 必填。

```markdown
:::tabs
:::tab {label="Emacs 29"}
用 `image-size` 的旧签名。
:::tab {label="Emacs 30+"}
直接传 buffer。
:::
```

解决的场景：同一件事的几种写法并行，读者只需要一种。三个并列小节会让目录变长，标签页只占一块位置。

交互按第 7 章的契约，不单独定规则。

### 6.12 代码标签页

和 `tabs` 一样，只是子块里放围栏代码，`label` 省略时用围栏的语言名。

````markdown
:::code-tabs
:::tab
```elisp
(etaf-md-open)
```
:::tab
```python
print("hi")
```
:::
````

这是糖，不是新语义。多一条定义就多一处要维护的规则，能靠默认行为解决的就不加。

### 6.13 折叠

单个折叠。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 必填 | 收起时显示的标题 |
| `open` | bool | `false` | 默认展开 |

分组。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `accordion` | bool | `false` | 同组里同时只开一块 |

```markdown
:::collapse {title="完整报错"}
```
后面的长文本放这里。
```
:::
```

解决的场景：长推导、长日志、完整报错。留在页面上备查，但不挡路。

映射：ETAF UI 的 `etaf-accordion`。

### 6.14 表格包装

普通管道表格已经能用。包装层加两件事。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 表格上方一行标题 |
| `hl-rows` | string | 无 | 高亮的行，例如 `warn:2,3` |
| `hl-cols` | string | 无 | 高亮的列，例如 `accent:1` |

```markdown
:::table {title="打开耗时" hl-rows="warn:3"}
| 版本 | 耗时 |
| --- | --- |
| 0.1.9 | 5.4 s |
| 0.2.0 | 0.33 s |
:::
```

理由：表格最常见的两个需求是给个标题、标出要注意的那一行。为这两件事写一段说明，不如挂两个属性。

### 6.15 演示窗口

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 标题栏文字 |
| `height` | length | 自动 | 内容区高度 |

```markdown
:::window {title="etaf-md-preview"}
一段界面截图或者一段文字。
:::
```

从 plume 的 `window` 变形而来。它画圆角和阴影，我们只画一条标题栏。圆角在字符网格里画不出来，硬画就是一排乱字符。

### 6.16 状态总表

| 容器 | 家族 | 状态 |
| --- | --- | --- |
| GitHub 提示块 `> [!NOTE]` 等五种 | 提示 | 已实现 |
| `note`、`tip`、`important`、`warning`、`caution` | 提示 | 计划中 |
| `box` | 结构 | 计划中 |
| `card` | 结构 | 计划中 |
| `columns` + `col` | 结构 | 计划中 |
| `steps` + `step` | 集合 | 计划中 |
| `timeline` + `event` | 集合 | 计划中 |
| `stats` + `stat` | 集合 | 计划中 |
| `field` | 集合 | 计划中 |
| `file-tree` | 集合 | 计划中 |
| `chat` + `said` | 集合 | 计划中 |
| `tabs` + `tab` | 交互 | 计划中 |
| `code-tabs` + `tab` | 交互 | 计划中 |
| `collapse`、`collapse-group` | 交互 | 计划中 |
| `table` | 文稿 | 计划中 |
| `window` | 文稿 | 计划中 |

## 7. 交互契约

### 7.1 只有声明过的容器可以交互

文档不能给任何东西加行为。可交互是容器定义的属性，不是文档的属性。

理由：一份 Markdown 文件可能有执行权限的错觉。它没有。文档能做的只有声明「这里有一组标签页」，按键由渲染器决定。

### 7.2 焦点与按键

- 可聚焦目标是容器画出来的元素，不是文字本身。`TAB` 和 `S-TAB` 在它们之间移动。
- `RET` 激活当前目标。
- 组内用左右方向键切换，例如标签行、折叠组。
- 焦点进入容器时，容器在页面上有可见的焦点标记。焦点离开后恢复原样。
- 焦点顺序按文档顺序，不按视觉位置。窄窗口降级后顺序不变。

### 7.3 状态与重绘

- 状态存在容器自己身上，不存在文档上，也不存到磁盘。
- 重排、换主题、改窗口宽度不丢状态。重新加载文档回到默认状态。
- 状态变化只重画这一块，不重建整页。
- 默认状态由属性决定，`active`、`open` 两个属性就够。

### 7.4 搜索、复制、导出

- **isearch**：隐藏的内容仍然参与搜索。命中时那一块自动展开，焦点落在命中处。搜不到就等于内容不存在，而读者不知道它被收起来了。
- **复制**：复制的是看得见的文本，包含容器的标签文字，不包含隐藏的内容。
- **导出**：org 或 HTML 导出时，交互容器按 7.5 的方式展开，读者拿到的文本不缺东西。

### 7.5 无交互环境的扁平化

没有键盘、没有焦点的地方，例如批处理、导出、终端截图，交互容器必须能扁平化。

| 容器 | 扁平化后 |
| --- | --- |
| 标签页 | 每个标签一节，标题是标签文字，全部展开 |
| 折叠 | 全部展开，标题保留 |

扁平化不是降级，是同一份内容的另一种排法。所以测试可以在批处理里跑，断言不需要模拟按键。

## 8. 渲染与性能

### 8.1 一块一个组件

每个顶层块是一个独立 Component，键是块的类型加源码。改一个字只重画那一个块，别的块连输出都不碰。

容器不是特例。一个 `card` 是一个块，一个 `columns` 是一个块，里面的 `col` 在同一个块里画。

### 8.2 重绘范围

| 发生了什么 | 重画范围 |
| --- | --- |
| 正文改一个字 | 那一个块 |
| 展开一个折叠 | 那一个块 |
| 切一个标签 | 那一个块 |
| 改主题 | 整页，但每块只换颜色，不重排 |
| 改样式表 | 整页重画并重新派生，不重新解析 |
| 改窗口宽度 | 整页重排，不重建 |
| 改容器定义 | 用到它的块 |

样式可能改变块高，所以块流按每块的实际高度排。带 `:scale` 的标题占几行，下面就接第几行。

### 8.3 成本与预算

- 每个块在一次宽度下只测量一次。宽度没变就不重新测量。
- 嵌套的栏只测量自己的子树，不测量整页。
- 一个块的重排目标在 50 毫秒以内。一份 200 块的文档首次打开目标在 1 秒以内。
- 没有定时器，没有后台刷新。页面静止时不动。
- 样式表每个节点查一次，是一次哈希查找，不进字符循环。

预算写在这里是为了验收时有数可对。具体数字在实现时按基准测试校准，校准时改这一节。

## 9. 扩展

### 9.1 定义的数据形状

一个定义是数据，不是文档里的代码。

```elisp
(etaf-md-define-container
 'card
 :kind 'block
 :summary "一张带标题的卡片"
 :attrs '((title   :type string :doc "卡片标题")
          (surface :type enum :one-of (none panel quote sunken page)
                   :default panel :doc "底色")
          (tone    :type enum :one-of (neutral info ok warn danger important)
                   :default neutral :doc "语气"))
 :body (lambda (attrs body env)
         (etaf-node 'box
                    (list :width 'stretch
                          :gap '((lh 1) (ch 0))
                          :padding '((lh 1) (ch 2))
                          :background-color (etaf-md-surface env (plist-get attrs :surface))
                          :border-left (list '(px 3) 'solid
                                             (etaf-md-tone env (plist-get attrs :tone))))
                    (append
                     (when-let* ((title (plist-get attrs :title)))
                       (list (etaf-node 'text (list :weight 'bold) (list title))))
                     body))))
```

| 字段 | 作用 |
| --- | --- |
| 名字 | 第一个参数，符号。文档写 `:::card` 就找它 |
| `:kind` | `block`、`parent`、`child` |
| `:summary` | 一行说明，出现在帮助和报错里 |
| `:attrs` | 属性表，每项写法见 9.2：`(名字 :type 类型 :default 值 :doc 说明)`，`nil` 默认值不用写 |
| `:children` | 只有父容器要写，声明子块名字和它们的属性 |
| `:body` | 函数，收三样东西，返回 ETAF 视图 |

`body` 收到三样东西。位置参数只留给每类定义都有的，其余都从 `env` 具名取。

- `attrs`：校验过的 plist。没写的取默认值，类型已经转换好。
- `body`：解析好的内容，一串视图。默认画法就是它。
- `env`：渲染环境，可选能力都从这里取，见下表。

`env` 提供的能力，就是定义能拿到的全部。

| 能力 | 用法 | 给谁用 |
| --- | --- | --- |
| 令牌 | `(etaf-md-token env 'info)` | 所有容器 |
| 行高 | `(etaf-md-token env 'lh)` | 所有容器 |
| 面 | `(etaf-md-surface env 'panel)` 把面换成底色，`none` 返回 `nil` | 所有容器 |
| 语气 | `(etaf-md-tone env 'warn)` 把语气换成强调色 | 提示块、卡片 |
| 子块 | `(etaf-md-children env)` 按顺序给 `(:name :attrs :view)` | 父容器 |
| 块树 | `(etaf-md-content env)` 给解析好的块，不是视图 | `field`、`code-tabs`、`table` |
| 画子块 | `(etaf-md-render env blocks &rest options)` | `field`、`chat`、`table` |
| 打开目标 | `(etaf-md-open env href)` | `card` 的 `href` |
| 本块状态 | `(etaf-md-state env :active)` | `tabs`、`collapse` |
| 度量 | `(etaf-md-measure env)` | `columns` 的降级判断 |

状态那一行是关键。目录里的 `etaf-tabs` 是受控组件，`active` 和 `on-change` 都由调用方给；定义本身没有地方存状态，所以每个块要有一个自己的状态格子，由渲染器创建，按块隔离。

`etaf-md-render` 带 `&rest options`，是为了包装容器。`table` 要在包住的那张表上打开行高亮，它不需要改表怎么画，只需要把选项递下去。

父容器多写一个字段。

```elisp
:children '((col :attrs ((grow :type number :default 1 :doc "宽度份数"))))
```

三个内置结构容器也走这条路。`box`、`card`、`columns` 不是特例，它们是同一张注册表里的三条定义。理由很简单：只要有一个容器在渲染器里有专属分支，这套 API 就没被验证过，用户迟早撞上只有那条分支才有的能力。

### 9.2 属性与子块的规则

- 定义只能引用共享属性表里的名字，或者自己声明的专有属性。专有属性要在 `:summary` 里说清只能和它一起用。
- 每一项只有一个位置：第一个元素是名字，它是这一项的键。后面全是具名字段，和 `:children '((col ...))` 一个形状。
- `:type` 必写，取值是 `string`、`number`、`bool`、`length`、`color`、`enum`、`regex`。枚举写 `:type enum :one-of (...)`，正则写 `:type regex :pattern "..."`。类型只有一种写法，不再有「关键字还是列表」两种形状。
- `:default` 不写就是 `nil`，所以 `nil` 默认值一个字都不用写。
- 必填写 `:required t`，例如 `(label :type string :required t :doc "标签文字")`。此时不许写 `:default`，两个都写是加载错误。必填只用于文档侧属性，读者侧的键一律可选。
- `:doc` 可选，但建议写。它出现在帮助和报错里。
- `:kind` 是 `child` 的定义不写 `:children`。
- 定义不能自己读文件、发网络请求、起定时器。它只能拿到 `attrs`、`body`、`env`，其余从 `env` 具名取。
- 渲染器的分发代码里不出现容器名字。它只按角色的和属性找定义，不按名字写分支。
- 内置定义和用户定义从同一张表加载。测试要能用一份用户定义替换内置的 `card`，并把结果渲染出来。

### 9.3 定义一条样式

和数据表同形，只是写成一次调用。按级别给不同前缀，就是三行数据。

```elisp
(etaf-md-define-style 'heading
  '((:weight bold)
    (:level 1 :prefix "◆ ")
    (:level 2 :prefix "◇ ")
    (:level 3 :prefix "· ")))
```

渲染出来是这样：

```
◆ 安装
◇ 依赖
· Emacs 29 以上
```

前缀是包自带的键，所以这一段不用写函数。默认定义没想到的东西，才需要函数，见 9.4。

加载时校验：节点类型不认识、键不认识、值类型不对，都当场报错，这一类型回退内置。错误行点名节点、键、合法值。

### 9.4 换一个节点的渲染

样式不够用时，给一个函数。函数还能给这个类型加新的键。

```elisp
(etaf-md-define-render 'heading
  :extends t
  :keys '((background :type color :doc "标题底色"))
  (lambda (node env)
    (etaf-node 'box
               (list :width 'stretch
                     :background-color (etaf-md-color env
                                                      (etaf-md-style env :background)))
               (list (etaf-md-style-default 'heading node env)))))
```

| 拿到什么 | 说明 |
| --- | --- |
| `node` | 类型、属性、子节点。`heading` 带 `:level` 和 `:children` |
| `env` | 令牌、度量、派生数据。`(etaf-md-style env :background)` 读本块的样式值，`(etaf-md-derived env :number)` 读编号 |
| `:extends t` | 保留内置的键和画法，只往上加 |
| `:keys` | 新键，写法同 9.2。只能在函数里声明 |
| `etaf-md-style-default` | 内置画法。包一层，或改一处，或完全不用。标题多收一个 `:label`，用来接编号 |

三条规则。

- 必须返回一个视图，不能改节点树。
- 函数报错时，这类型回退内置，页面继续渲染，错误进 `doctor`。
- **加键必须配函数。** 数据定义不能加键，理由很直接：没人读的键就是死配置。

按章节号变的前缀也用这里。它不是常量，数据写不出来。

```elisp
(etaf-md-define-render 'heading
  :extends t
  (lambda (node env)
    (etaf-md-style-default 'heading node env
                           :label (etaf-md-roman (etaf-md-derived env :number)))))
```

`:label` 是标题专用关键字，接派生阶段算好的编号；其它类型不认这个关键字。

### 9.5 覆盖一个内置定义

三种写法，一张表说清。

| 写法 | 效果 | 用在 |
| --- | --- | --- |
| `:extends t` | 保留内置的键和画法，你的键追加进去 | 想加参数、包一层 |
| `:replace t` | 丢掉内置定义，键表和画法都由你定 | 想彻底换一种画法 |
| 两个都不写 | 只在没有同名定义时生效，重名报错 | 新类型 |

四条约束。

- **文档侧的属性表只能增，不能改。** 容器的新属性只能追加，改名或删掉算破坏性变更，升 `:contract`，旧文档按 3.4 降级并说明。子块名字同理。加键只对读者侧有效。
- **`attrs` 和 `keys` 是两个名字，权限不同。** `attrs` 是文档写的，封闭；`keys` 是读者写的，可扩展。
- **`:default` 永远指内置原值。** 加载时给内置定义留一份快照，否则「回到默认」没有意义。
- **覆盖要留痕。** `:replace t` 的报错行点名被替换的定义，`doctor` 列出覆盖链和来源文件。

同名冲突按加载顺序解决：两个第三方包都改一个类型时，后加载的那个必须显式 `:replace t`，否则报错点名双方。

### 9.6 定义放在哪、什么时候读

- 定义放在用户目录里的 `.el` 文件，路径写进 `etaf-md-container-directory`。
- 加载顺序固定：包自带的先，用户目录后，同一目录内按文件名排序。后加载的能覆盖先加载的，但必须显式声明，见 9.5。
- 一个 session 创建时读一次注册表，之后不再读盘。改了定义要 `r` 重载，或者重开预览。
- 文档不能注册容器，也不能执行 Elisp。分享文档不等于分享代码。

### 9.7 调试

- `etaf-md-describe-containers` 列出注册表：名字、角色、摘要、属性、来源文件。计划中。
- 报错行永远在页面上，不用开日志。
- 定义自己报错时，那一块降级成源码，加一行「`card` 的定义报错：…」，后面的块照常。
- `etaf-md-doctor` 报告注册了几个容器、有没有定义文件加载失败。计划中。

### 9.8 信任模型

- 文档没有执行权限。它能做的只有命名和给属性。
- 定义只从用户配置的目录加载。不读当前目录的定义，不读文档旁边目录的定义。
- 定义不能读文件、发网络请求、起定时器、改全局状态。要数据就在 `attrs` 里传。
- 渲染不产生副作用。视图只读 refs 和缓存值。

## 10. 路线图

### 10.1 阶段

| 阶段 | 内容 | 完成判据 |
| --- | --- | --- |
| 0 | GitHub 提示块 | 已实现，51 个测试覆盖 |
| 1 | 渲染路径：解析、派生、样式表、失败目录，并把 `box`、`columns`、`card` 用定义写 | 12 种失败各有一条断言；三层嵌套与超限；窄窗三档截图；用户定义能替掉内置的 `card`；每个内置节点至少一个样式键生效；改样式表不重新解析 |
| 2 | 提示容器：五个名字，和 GitHub 写法共用一张定义 | 两种写法渲染成同一个 buffer 文本；语气映射正确 |
| 3 | 集合：`steps`、`timeline`、`stats`、`field`、`file-tree`、`chat` | 每个容器有正例、反例、三种配色截图 |
| 4 | 交互：`tabs`、`code-tabs`、`collapse`、`collapse-group` | 按键走命令循环；状态经重排与换主题不丢；扁平化输出不缺内容 |
| 5 | 文稿：`table`、`window` | 表格高亮按行列生效；窗口只画标题栏 |
| 6 | 注册表与用户定义 | 示例定义能装能卸；给内置类型加一个键并生效；覆盖后 `:default` 仍回内置；契约版本不符有提示；`doctor` 报数量与覆盖链 |

### 10.2 每个容器的验收矩阵

每个容器都要过这五格，少一格不算完成。

| 格 | 检查什么 |
| --- | --- |
| 正例 | 文档写出来，渲染成预期的样子 |
| 反例 | 少一个必填属性、写错一个值，页面降级且说明准确 |
| 嵌套 | 放进 `columns` 的栏里、放进 `card` 里，仍然成立 |
| 配色 | 暗色、亮色、纸色、跟随主题，四档下都可读 |
| 窄窗 | 宽、中、窄三档，内容不少，字号不变 |
| 样式 | 一个样式键改变了它的外观；一个未知键报错并回退内置 |

渲染路径另有三条断言，跟容器无关。

- 同一份文档，改样式前后解析次数不变。
- 标题加了前缀，锚点不变。
- 关了编号，派生阶段跳过。
- 覆盖了 `heading` 的渲染后，`etaf-md-style-default` 仍是内置画法。

### 10.3 完成判据

一个阶段完成，必须同时满足三条。

1. `make check` 通过，包括结构检查、编译、测试、接口核对。
2. 受影响的示例在真实 GUI 里跑过一遍，截图看过。
3. 附录 A 的属性表、附录 C 的样式表和附录 D 的对照表同步更新。

## 11. 不做的事

- 不做 HTML 子集、CSS 子集、`<style>` 标签。一套渲染器里塞两个排版系统，边界会越来越模糊。
- 不做文档内嵌脚本，不让文档注册容器。
- 不做字号参数、缩放参数。
- 不做远程 iframe、远程播放器、远程代码执行。
- 不做圆角、阴影、渐变、动画。
- 不做 markdown 之外的第二种文档格式。
- 不做页面、路由、导航、发布。那是上层应用的事，见 1.2。
- 不做 `justify`。字符网格里没有字间距可以拉，只能填空格，中文段落行尾会出洞。

## 附录 A：属性参考

共享属性。容器只从这里挑，不发明同义词。

| 属性 | 类型 | 含义 | 用在 |
| --- | --- | --- | --- |
| `title` | string | 标题文字 | 提示块、card、steps、timeline、file-tree、collapse、table、window、stat |
| `label` | string | 短标签 | tab、stat |
| `description` | string | 标题下的摘要 | card |
| `surface` | enum | 底色角色 | box、card |
| `tone` | enum | 语气 | box、card |
| `align` | enum | 内容水平位置 | box、card、columns |
| `width` | length | 自身宽度 | box、card |
| `pad` | length | 内边距 | box、columns |
| `gap` | length | 块间距 | columns |
| `cols` | number | 等宽栏数 | columns、stats |
| `tracks` | string | 显式轨道 | columns |
| `min` | length | 最小栏宽 | columns |
| `items` | enum | 交叉轴对齐 | columns |
| `justify` | enum | 主轴对齐 | columns |
| `wrap` | bool | 放不下时换行 | columns |
| `grow` | number | 宽度份数 | col |
| `marker` | enum | 记号风格 | steps、timeline、file-tree |
| `open` | bool | 默认展开 | 提示块、collapse |
| `collapsible` | bool | 允许收起 | 提示块 |
| `accordion` | bool | 同组只开一块 | collapse-group |
| `active` | string | 默认选中 | tabs |
| `href` | string | 跳转地址 | card |
| `start` | number | 起始编号 | steps |
| `separator` | enum | 名称与值的分隔 | field |
| `label-width` | length | 名称列宽 | field |
| `me` | enum | 自己一侧 | chat |
| `from` | string | 发送者 | said |
| `time` | string | 时间 | event、said |
| `value` | string | 数字文本 | stat |
| `height` | length | 内容区高度 | window |
| `hl-rows` | string | 高亮行 | table |
| `hl-cols` | string | 高亮列 | table |
| `id` | string | 稳定锚点 | 所有块 |

## 附录 B：面、语气与令牌

| 属性值 | 落到哪个令牌 | 说明 |
| --- | --- | --- |
| `surface=none` | 无 | 不画底 |
| `surface=panel` | `panel` | 代码块、卡片 |
| `surface=quote` | `quote-bg` | 引用性质 |
| `surface=sunken` | `panel2` | 次要信息 |
| `surface=page` | `bg` | 与正文拉开 |
| `tone=neutral` | `ink` / `panel` | 无语气 |
| `tone=info` | `accent` / `accent-soft` | 说明 |
| `tone=ok` | `ok` / `ok-soft` | 成功 |
| `tone=warn` | `warn` / `warn-soft` | 注意 |
| `tone=danger` | `danger` / `danger-soft` | 危险 |
| `tone=important` | `important` / `important-soft` | 重要 |

提示块的五个名字到语气的映射固定：`note` 对 `info`，`tip` 对 `ok`，`important` 对 `important`，`warning` 对 `warn`，`caution` 对 `danger`。

## 附录 C：样式键参考

样式表能写的键。类型一列里，颜色指令牌名或字面值，长度只用 `ch`、`lh`、`px`。值写 `:default` 表示回落内置。这张表是包自带的词汇，用户可以用 `:keys` 给某个类型加键，见 9.4。

| 键 | 类型 | 用在 | 含义 |
| --- | --- | --- | --- |
| `color` | 颜色 | heading、strong、em、link、code-inline | 文字颜色 |
| `background` | 颜色 | code、table、quote、callout | 底色 |
| `border` | 颜色 | code、table | 边框颜色 |
| `weight` | `normal` / `bold` | heading、strong | 字重 |
| `slant` | `normal` / `italic` | em、quote | 倾斜 |
| `underline` | bool | link、strong | 下划线 |
| `prefix` | string | heading | 显示前缀，不影响锚点 |
| `suffix` | string | heading | 显示后缀 |
| `numbering` | `none` / `arabic` / `roman` | heading、table | 由派生阶段编号 |
| `scale` | number | heading | 基准字号的倍数 |
| `gap-before` / `gap-after` | 长度 | heading、quote、code、table | 上下间距 |
| `bar-color` / `bar-width` | 颜色 / 长度 | quote、callout | 左侧竖条 |
| `marker` | string | list | 列表记号字符，只用 4.6 允许的字符 |
| `tag-color` | 颜色 | code | 围栏语言标签 |
| `header` / `stripe` | 颜色 | table | 表头与条纹底色 |
| `tone-colors` | alist | callout | 语气到颜色的映射 |
| `align` | `left` / `center` / `right` | table | 单元格对齐 |

## 附录 D：plume 对照

| plume | 我们的决定 | 说明 |
| --- | --- | --- |
| `align` | 并入 `box` 的 `align` 属性 | 不为一种对齐加一个容器 |
| `flex` | 并入 `columns` | 一个容器管横向、换行、比例 |
| `card` | 吸收，`card` | 圆角阴影改成一圈边框加面 |
| `card-grid` | 并入 `columns {cols=N}` | 卡片并排就是栏里放卡片 |
| `card-masonry` | 不吸收 | 行高固定，瀑布流装出来就是网格 |
| `steps` | 吸收，`steps` + `step` | 编号加标题 |
| `tabs` | 吸收，`tabs` + `tab` | 键盘可达，切换只重画一块 |
| `code-tabs` | 吸收为 `tabs` 的默认行为 | 标签文字取围栏语言 |
| `collapse` | 吸收，`collapse` 与 `collapse-group` | 加 `accordion`，加搜索自动展开 |
| `field` | 吸收，`field` | 名称列自动对齐 |
| `timeline` | 吸收，`timeline` + `event` | 记号可选 |
| `table` | 部分吸收 | 标题与行列高亮 |
| `file-tree` | 吸收，`file-tree` | 记号只用允许的字符 |
| `code-tree` | 不吸收 | 和 `code-tabs` 加 `file-tree` 重合 |
| `chat` | 吸收，`chat` + `said` | 左右对齐加缩进，不画气泡 |
| `window` | 变形吸收，`window` | 只画标题栏 |
| `encrypt` | 不吸收 | 保密文档不该进预览 |
| `npm-to`、`lang-repl` | 不吸收 | 要包管理器和解释器 |
| `plot`、`qrcode`、`pdf` | 不吸收 | 要绘图和图像生成 |
| `annotation`、`abbreviation` | 不吸收 | 要图上标注和悬停浮层 |
| `code-pen`、`code-sandbox`、`repl`、`caniuse` | 不吸收 | 要浏览器和网络 |
