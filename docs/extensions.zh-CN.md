# 扩展语法

> **状态。** 今天页面能渲染的只有 GitHub 提示块，写法是 `> [!NOTE]`、`> [!TIP]`、`> [!IMPORTANT]`、`> [!WARNING]`、`> [!CAUTION]`。本文其余部分是设计契约，先把模型、语法、属性和验收定下来，实现时照它做。标「计划中」的名字今天都不存在，函数名也只是提案。
>
> **怎么读。** 写文档看第 3、5、6 章。写容器定义看第 9、10 章。实现渲染器看第 2、7、8、11 章。想知道今天能用什么，看 6.16。想知道某个名字为什么这么写，看附录 E。
>
> 中英两版一节对一节。改一处，另一处同时改。

## 速查

写一份文档只需要知道这些。

**两条规则。** `:::名字 {属性}` 开一块，`:::` 单独一行结束，关掉最近打开的那个。文件里最后一块可以不写结束行。

一个块容器：

````markdown
:::card {title="缓存命中"}
图片和矢量按页面尺寸缩放，不重新画。
:::
````

一个父类型。子块的名字由它解释，所以 `:::tab` 只在 `tabs` 里有意义：

````markdown
:::tabs
:::tab {title="Emacs 29"}
用 `image-size` 的旧签名。
:::
:::tab {title="Emacs 30+" selected=true}
直接传 buffer。
:::
:::
````

**最常用的属性。**

| 属性 | 类型 | 写在哪 | 例子 |
| --- | --- | --- | --- |
| `title` | string | 容器与子块 | `title="缓存命中"` |
| `description` | string | card | `description="一句话摘要"` |
| `surface` | surface | box、card | `surface=raised` |
| `accent` | accent | box、card、提示块 | `accent=warning` |
| `text-align` | align | box、card | `text-align=center` |
| `columns` | number 或 string | columns、stats | `columns="2fr 1fr"` |
| `gap` | length | columns | `gap="2ch"` |
| `padding` | length | box、columns | `padding="1lh"` |
| `open` | boolean | collapse、提示块 | `open=true` |
| `selected` | boolean | tab | `selected=true` |
| `list-style` | enum | steps、timeline、file-tree | `list-style=decimal` |
| `href` | string | card | `href="#安装"` |

**五个面：** `none`、`page`、`raised`、`sunken`、`quote`。**六个强调：** `neutral`、`primary`、`success`、`warning`、`danger`、`important`。

长度必须带单位，`2ch` 或 `1lh`，光写 `2` 是错的。颜色和字号文档里一个都不写，它们由读者的主题与样式表决定。

属性名想不起来，就用 `etaf-md-describe-nodes` 查，或者开 `etaf-md-edit-mode` 让补全替你想。

## 1. 定位

### 1.1 这个包做什么

一件事：把一份 Markdown 文档变成 ETAF 视图，挂在 buffer 里给人读。输入是文本，输出是字符网格上的盒子、文本和 face。

它自带一套容器词汇，让文档能写出普通 Markdown 写不出的结构：提示块、卡片、步骤、标签页、时间线。词汇是关闭的，用户可以在第 10 章的口子上加，但文档本身不能定义新东西。

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

### 2.1 一种东西：节点

一篇文档是一串节点。节点有类型、属性、子节点。段落、标题、代码、表格、容器都是节点，区别只在类型。

解析器只认三件事：开、关、嵌套。它不知道 `card` 是什么意思，也不知道它收什么属性。名字的含义归注册表，属性的含义归定义，摆放归渲染。

### 2.2 一个模型

系统里只有一种东西：节点类型。文本类型和容器类型在同一张表里，走同一个 `etaf-md-define-node`。

| 类型 | 文档写得出来吗 | 例子 |
| --- | --- | --- |
| 解析器产生 | 写不出，没有名字 | `heading`、`quote`、`code`、`table` |
| 文档写得出来 | 写 `:::名字` | `card`、`tabs`、`columns` |

区别只有一处：**文档写得出来的类型有名字**（定义里的 `:name`），别的没有。`heading` 没有名字，所以 `:::heading` 不存在，它只能由 `###` 产生。

收固定子块的类型声明 `:accepts`，比如 `columns` 只收 `col`；不声明的类型内容是任意块，比如 `card` 里能放段落、代码、表格、另一个容器。

**子块不是类型，它没有自己的定义。** 名字由父类型的 `:accepts` 解释，解析器不认。所以 `:::tab` 在 `tabs` 里是一个标签，在页面顶层只是一行没法解释的文字，按失败规则报出来。

父子关系不跨层。`tabs` 里的 `tab` 可以再装一个 `card`，但 `tab` 不能再装一个 `tab`。要嵌套就再包一层 `tabs`。

### 2.3 四个扩展点

系统有四层，每层的权限不一样。

| 层 | 谁决定 | 改什么 | 能不能改 |
| --- | --- | --- | --- |
| 语法 | 包的解析器 | 文本怎么变成节点 | 不能 |
| 结构 | 文档和容器定义 | 多一种块、块收哪些属性 | 能，见第 10 章 |
| 外观 | 读者的样式表 | 颜色、字重、前缀、间距、编号 | 能，见 4.3 |
| 渲染 | 读者的函数 | 一个节点画成什么 | 能，见 10.4 |

四层共用一个节点模型：`(类型 属性 子节点)`。文本节点和容器节点在这张表里没有区别：`heading` 是类型叫 `heading`、带 `level` 属性的节点，`card` 是类型叫 `card`、带 `title` 属性的节点。

还有一条：**定义本身能被覆盖**。读者可以给一个类型加键、换画法，甚至整条替掉。加键只对读者侧有效，文档侧的属性表不开放，见 10.5。

### 2.4 管道

```
文本 → 解析 → 节点树 → 派生 → 渲染 → 视图
```

- **解析**：封闭。调用共享的 `etaf-ui-markdown-parse`，本文不改它。
- **派生**：整篇算一次。标题编号、表格序号、锚点、块的显示身份都在这一步。
- **渲染**：按块独立。样式和渲染函数在这一步生效。

派生为什么要单独一步。块是独立重画的，编号却要看整篇。放进渲染，重画一块就要重算全篇；放进解析，又把显示决策混进了语法层。

两条派生规则。

- **锚点从原文算，不从显示文字算。** 标题的 `◆` 前缀是显示层的事。改前缀不能断掉别人收藏的 `#安装` 链接。
- **编号只在样式要求时算。** 关掉编号就跳过这一步，不做无用功。

### 2.5 九个不变量

每个新容器都必须同时满足这九条。少一条，这个容器就不该进注册表。

| 不变量 | 判据 |
| --- | --- |
| 一种语法 | 新效果只加名字，不加标点。没有第二种块标记 |
| 一个内容模型 | 内容是块，不是字符串，不是 HTML。容器不改解析 |
| 一套属性 | 属性名和含义来自一张共享词汇表，容器只挑选，不发明同义词 |
| 一组布局 | 摆放只用 `box`、`columns` 和共享的间距属性 |
| 一个外观来源 | 颜色来自底色与强调，字号来自读者 |
| 一条失败规则 | 坏块留源码加一行说明，页面继续渲染 |
| 状态归渲染器 | 文档不写行为，交互由容器定义实现 |
| 一条渲染路径 | 内置节点、容器节点、读者样式走同一张表，代码里没有按名字的分支 |
| 一条定义边界 | 定义只做声明、校验、翻译；可复用的壳和交互归组件，见第 9 章 |

### 2.6 命名规则

名字分五个命名空间。每个命名空间只有一个权威，新名字必须能在附录 E 找到出处；找不到就不许加。

| 命名空间 | 谁写 | 权威 | 例子 |
| --- | --- | --- | --- |
| 文档属性 | 文档作者 | HTML 属性名，加主流组件库共用的 prop 名 | `title`、`href`、`open`、`selected`、`padding`、`columns` |
| 类型 | 写定义的人 | JSON Schema 加 CSS 值类型 | `string`、`number`、`boolean`、`length`、`enum` |
| 令牌 | 渲染器 | shadcn/ui 的一套语义令牌 | `background`、`foreground`、`surface-raised`、`primary` |
| 样式键 | 读者 | CSS 属性名 | `background`、`color`、`font-weight`、`margin-top` |
| 函数 | 包作者 | 动词加宾语，一个动词一个意思 | `etaf-md-render`、`etaf-md-follow-link` |

五条规矩。

1. **不缩写。** 写 `background` 不写 `bg`，写 `columns` 不写 `cols`，写 `padding` 不写 `pad`。只有 `id` 和 `href` 例外，它们是 HTML 的正式拼写。
2. **不编号。** 写 `surface-raised` 不写 `panel2`，写 `primary` 不写 `accent-1`。
3. **一个词一个意思。** `accent` 永远是强调值，不是令牌；`surface` 永远是面，样式键叫 `background`，不叫 `surface`。
4. **值用标准词。** `decimal`、`lower-roman`、`bullet` 取自 CSS 的 `list-style-type`；`boolean` 取自 JSON Schema。
5. **先查再借。** 同一含义已有词就复用；没有就从权威里借一个；借不到才新造，并在附录 E 写明为什么。

## 3. 语法

### 3.1 开与关

````markdown
:::card {title="缓存命中" surface=raised}
图片和公式都按矢量画一次，之后按页面尺寸缩放。

- 命中时读文件
- 未命中时画一次
:::
````

| 规则 | 说明 |
| --- | --- |
| 名字 | 只收小写字母、数字、连字符，例如 `card`、`code-tabs` |
| 属性 | 花括号里的 `键=值`，空格分隔；没有属性时整对花括号省略 |
| 关闭 | 单独一行三个冒号，不写名字，关掉最近打开的那个 |
| 嵌套 | 直接套，内外都用三个冒号；层数不靠冒号个数区分 |
| 深度 | 最多 8 层。第 9 层报错，不渲染 |
| 空容器 | 允许。渲染成只有标题或一个空位，不算错误 |
| 开头 | `:::` 必须独占一行，前面只允许空白 |

关闭只有一种写法，所以只有一种读法：**关掉最近打开的那个**。不数冒号，不对名字，也就不会有对不上的时候。

嵌套不需要多加冒号，同名容器套同名容器也一样：

````markdown
:::card {title="外面"}
:::card {title="里面"}
内容
:::
:::
````

两个 `:::` 后进先出，先关里面再关外面。多写冒号、按名字匹配都会带来第二条规则，而第二条规则只会多一种写错的方式。

深度上限是 8，不是无限。每层都是一个盒子，窄窗口里读的人数不清自己站在第几层；每层还要一次测量和一次重排，深一层就多一层成本。上限把最坏情况钉住。

一个代价要说清：**没有内容的子块也要写关闭行。** 比如 `:::stat` 只带属性，就写成两行。这是为了让关闭只有一种规则；能省这一行的写法，就得让解析器认识名字，而它不认。

### 3.2 子块

子块的写法和普通容器一样，只是名字由父类型解释。父类型通过 `:accepts` 决定它收哪些子块、子块上哪些属性有效。

````markdown
:::columns {columns="2fr 1fr" gap="2ch"}
:::col
左边这一栏是普通 Markdown。
:::
:::col
右边这一栏也是。
:::
:::
````

父类型必须能处理三种边缘情况，不允许崩溃或者画出半块。

- **没有子块**：画它自己的空状态，不报错。
- **子块顺序不对**：按出现顺序解释，不重排。
- **子块缺必填属性**：那一块降级，别的子块照常。

### 3.3 属性

八种类型。所有类型都从这一张表里挑。

| 类型 | 写法 | 含义 | 非法示例 |
| --- | --- | --- | --- |
| `string` | `title="缓存命中"` | 文本。含空格就加双引号，引号里的 `\"` 是转义 | `title=缓存 命中` |
| `number` | `start=2` | 整数或小数，可带负号 | `start=two` |
| `boolean` | `open=true` | 只认 `true` 和 `false` | `open=yes` |
| `length` | `gap="2ch"` | 数字加单位：`ch`、`lh`、`%` | `gap=2` |
| `surface` | `surface=raised` | 底色：`none`、`page`、`raised`、`sunken`、`quote` | `surface="#24262a"` |
| `accent` | `accent=warning` | 强调：`neutral`、`primary`、`success`、`warning`、`danger`、`important` | `accent=urgent` |
| `align` | `text-align=center` | 水平位置：`start`、`center`、`end` | `text-align=middle` |
| `enum` | `list-style=decimal` | 该属性声明时列出的词之一 | `list-style=number` |

有一种修饰，写法和 `:type` 并列。

| 修饰 | 含义 | 例子 |
| --- | --- | --- |
| `:pattern` | 值要匹配这个正则 | `(id :type string :pattern "^[a-z]+$" :doc "锚点")` |

要固定几个词就用 `enum`，不要给 `string` 加 `:one-of`。

五条约定。

- **属性名共享。** `title` 在卡片、提示块、折叠、演示窗口里是同一个意思。类型只挑选词汇表里的名字，不发明 `heading`、`caption` 这类同义词。
- **一个名字一个类型。** `columns` 永远是「几栏」或「一串轨道」，不会是别的。同一个名字在不同类型里换类型是禁止的。
- **没有单位就没有长度。** `gap=2` 是错的，`gap="2ch"` 是对的。一个数字可能是字符、可能是行、可能是百分比，猜错一次就排错一次。
- **布尔只认 `true` 和 `false`。** 不认 `yes`、`1`、`on`。三种写法意味着三条解析分支。
- **联合类型只允许一个。** `columns` 写 `number 或 string`，因为「几栏」和「一套轨道」是同一个概念的两个形态，拆成两个名字会逼作者记两个词。别处不许出现联合类型。

校验时值会换成渲染器要的形态，定义不用自己解析单位。

| 类型 | 写作 | 校验后拿到的值 |
| --- | --- | --- |
| `string` | `title="缓存命中"` | 字符串 `"缓存命中"` |
| `number` | `start=2` | 数字 `2` |
| `boolean` | `selected=true` | `t` 或 `nil` |
| `length` | `padding="1lh"` | ETAF 的长度 `(lh 1)`，可直接放进属性 |
| `surface` | `surface=raised` | 符号 `raised` |
| `accent` | `accent=warning` | 符号 `warning` |
| `align` | `text-align=center` | 符号 `center` |
| `enum` | `list-style=decimal` | 符号 `decimal` |

同一个属性写两次是错误，不取后者。理由：重复通常意味着作者改了一半，静默取一个会把问题藏起来。

属性有两个权限，都由数据表达，不靠人的记忆。

| 权限 | 谁说了算 | 怎么写 |
| --- | --- | --- |
| 文档能不能写 | 文档 | 默认能写；写不了的在定义里标 `:derived t` |
| 读者能不能盖 | 样式表 | 由类型决定：`surface`、`accent`、`align` 能盖，其余不能 |

第一条最典型的例子是标题的 `level`：文档写不出它，它由 `###` 决定，所以它是派生属性；样式表却能按它选（`(:level 1 :prefix "◆ ")`）。

两类各一个词：**文档属性**是花括号里写的，**派生属性**是解析或派生阶段给出来的。

共享属性表在附录 A，类型只引用它。定义里怎么声明这些类型，见 10.2。

### 3.4 校验、降级与失败目录

校验在搭视图之前一次做完，把这一块的所有错误一起报。报错是一条灰字，写在源码块上方，行号是容器开头那一行。

````markdown
:::card {title="缓存命中" colour=blue surface="#24262a"}
内容
:::
````

```
line 42: card 不收 "colour"，它收 title、description、surface、accent、href、text-align、width
line 42: card 的 surface 是 "#24262a"，它只认 none、page、raised、sunken、quote
line 44: 第 9 层嵌套超过上限 8 层
```

失败分十四种。每一种都有确定的页面表现，不允许「看情况」。

| 情况 | 页面表现 | 影响范围 |
| --- | --- | --- |
| 名字没有定义 | 源码原样加一行说明 | 这一块 |
| 属性不认识 | 源码原样，说明列出它认的属性 | 这一块 |
| 属性值不合法 | 源码原样，说明给出值和一个合法例子 | 这一块 |
| 必填属性缺失 | 源码原样，说明点名缺哪个 | 这一块 |
| 属性写了两遍 | 源码原样，说明点名重复的那个 | 这一块 |
| 子块出现在父类型外 | 源码原样，说明哪个类型的 `:accepts` 收了它 | 这一块 |
| 容器出现在不允许的位置 | 源码原样，说明它只允许在顶层与容器内容里 | 这一块 |
| 子块缺必填属性 | 源码原样，父类型继续解析其余子块 | 这个子块 |
| 父类型没有子块 | 画空状态，不报错 | 这一块 |
| 同一组两项都写 `selected` | 只认第一项，报一行 | 这一组 |
| 嵌套超过 8 层 | 源码原样，说明层数 | 这一块 |
| 文末还有没关的容器 | 内容照常渲染，页面末尾一行说明从第几行开始没关 | 文末 |
| 定义自己报错 | 源码原样，说明是哪个定义、报了什么 | 这一块 |
| 契约版本不符 | 源码原样，说明要哪个版本 | 这一块 |

三条通则。

1. **不弹窗。** 报错是页面的一部分，不是 Emacs 的错误。一份有十处错的文件，弹十次窗就没法读了。
2. **不中断整页。** 只有出错的那一块降级，别的照常渲染。
3. **一行一条。** 同一块的多条错误各占一行，按属性在定义里声明的顺序排。

错误文案跟着页面语言走。中文页面给中文，英文页面给英文，标签机制和提示块的标题共用一套。

### 3.5 未闭合与恢复

一个容器到文件末尾还没关，就当作它在那儿关了：内容照常渲染，页面末尾加一行说明，指出从第几行开始没关。

````markdown
:::card {title="少了一个关闭行"}
这段仍然是正文。

## 后面的标题照常成立
````

这个选择偏向读者。把整块判成源码会让人以为预览坏了；吞掉半篇文档比多一行字糟得多，而且作者改起来也更难发现。

### 3.6 源码 buffer 的编辑体验

渲染出来的页面没有标记，所以标记的代价全落在写的人身上。这一节说的东西全部发生在源码 buffer，不改语法，也不改渲染结果。

四层，按收益排。四层合成一个可选 minor mode，名字是 `etaf-md-edit-mode`，默认关。

| 层 | 做什么 | 解决什么 |
| --- | --- | --- |
| 一 | 标记降权：`:::`、花括号、等号用 `markdown-markup-face`；容器名用语言关键字色；属性名与属性值各一色 | 竖线不再和正文抢眼 |
| 二 | 配对提示：光标在容器里时，把它的开行与关行各提亮一档，离开即恢复 | 不用自己数哪个冒号配哪个 |
| 三 | 插入与补全：一条命令补出开行、空行、关行；容器名与它收的属性就地补全 | 名字和属性不用背 |
| 四 | 折叠：只留容器的开行 | 长文档里先看结构 |

四条硬约束，每一条都是「不破坏原有 Markdown 体验」的判据。

1. **只加不改。** 新增的 font-lock 规则只匹配 `^:::` 与属性花括号，这两处在 markdown-mode 今天没有任何规则，不存在覆盖。不动它的键位表、缩进函数、`electric-pair`、`markdown-hide-markup`。
2. **不改 buffer 内容。** 降权、提亮、折叠全部是 face、overlay 与 `invisible` 属性，`buffer-string` 前后相同。否则保存就会改文件。
3. **关掉即复原。** 关闭时移除 font-lock 关键字、删 overlay、清 hook、摘掉自己的 `completion-at-point-functions`。测试断言开启再关闭之后，`font-lock-keywords` 与开启前 `equal`。
4. **不抢键。** 只用自己前缀的键，不 remap 任何既有命令。

性能预算，和 8.3 一样可以量。

| 动作 | 预算 | 靠什么保证 |
| --- | --- | --- |
| 打开一份 2000 行的文档 | 额外耗时 50 毫秒以内 | font-lock 按块惰性走，没有整篇扫描 |
| 光标跨行 | 5 毫秒以内 | 只在行号变化时算一次 |
| 同一行内打字 | 0 次配对计算 | 上一条的直接结果 |
| 空闲 | 0 个定时器 | 没有轮询，没有后台刷新 |
| 折叠与展开 | 一次 overlay 增删 | 不动文字 |

配对提示要找到容器开头，所以它按行数给上限。一份几千行的文档里反查一次，超过上限就跳过这一屏的提示，不做无上限的反向扫描。

它救不了的三处，写在这里免得以后当承诺：GitHub 上、别人的编辑器里、复制出去的一段文字里，都没有这些标记。所以语法必须能在裸文本里读得下去，这一节只是加成。加语法时不拿它当理由。

## 4. 外观与样式

### 4.1 底色与强调

外观只有两个属性：`surface` 管底色，`accent` 管强调色。两套词分开，因为它们是两件事。两个属性的值和令牌一一对应，没有例外，见附录 B。

| `surface` | 落到哪个令牌 | 用在哪 |
| --- | --- | --- |
| `none` | 不画底 | 默认。正文里的卡片、并排的块 |
| `page` | `background` | 需要和正文拉开的地方 |
| `raised` | `surface-raised` | 代码块、需要边界的卡片 |
| `sunken` | `surface-sunken` | 表头、条纹、次要信息 |
| `quote` | `quote` | 引用性质的块 |

| `accent` | 前景 | 浅底 | 语义 |
| --- | --- | --- | --- |
| `neutral` | `foreground` | `surface-raised` | 没有强调 |
| `primary` | `primary` | `primary-soft` | 说明、提示、链接 |
| `success` | `success` | `success-soft` | 成功、建议 |
| `warning` | `warning` | `warning-soft` | 注意 |
| `danger` | `danger` | `danger-soft` | 危险 |
| `important` | `important` | `important-soft` | 重要 |

一个强调值只决定强调色和浅底，不改字号、不改字重、不改行高。要更醒目就换一个强调值，不要叠效果。

### 4.2 令牌

令牌是渲染器内部的名词。文档里写 `surface=raised`，不写 `surface-raised` 令牌，更不写色值。名字取 shadcn/ui 那一套，因为它是现在最通行的语义令牌。

| 令牌 | 用途 |
| --- | --- |
| `background` | 页面底色 |
| `foreground` | 正文 |
| `muted` | 次要文字、说明 |
| `faint` | 最弱的一层，序号、分隔 |
| `border` | 边框、分隔线 |
| `surface-raised` | 抬起的面：卡片、代码块 |
| `surface-sunken` | 下沉的面：表头、条纹 |
| `quote` | 引用块底 |
| `quote-bar` | 引用块左侧竖条 |
| `table-header` | 表格头 |
| `table-stripe` | 表格条纹 |
| `heading` | 标题 |
| `primary` / `primary-soft` | 信息类 |
| `success` / `success-soft` | 成功 |
| `warning` / `warning-soft` | 注意 |
| `danger` / `danger-soft` | 危险 |
| `important` / `important-soft` | 重要 |

令牌在三种配色下各有一套值，跟随 Emacs 主题时由当前 frame 的 face 推出来。容器只声明底色与强调，配色换了它跟着换。

**为什么不收十六进制。** 一个在暗色页上好看的 `#24262a`，换到纸色页就是一块黑斑。写十六进制会报错，报错行里列出这个属性认的语义词。

### 4.3 样式表

样式表是读者改外观的地方。一张表，按节点类型给键值，键名就是 CSS 属性名。

```elisp
(setq etaf-md-styles
      '((heading . ((:font-weight bold :color heading)      ; 所有级别
                    (:level 1 :color primary :scale 2.0 :prefix "◆ ")
                    (:level 2 :prefix "◇ ")
                    (:level 6 :font-weight normal :color muted)))
        (quote   . ((:background quote :accent neutral
                     :border-left-width "1ch" :font-style italic)))
        (code    . ((:background surface-raised :label-color muted)))
        (table   . ((:header-background table-header
                     :stripe-background table-stripe)))
        (strong  . ((:font-weight bold)))
        (em      . ((:font-style italic)))
        (link    . ((:color primary :text-decoration underline)))
        (callout . ((:accent-map ((neutral . foreground) (primary . primary)
                                  (success . success) (warning . warning)
                                  (danger . danger) (important . important)))))))
```

颜色只有两个名字，加一条命名规矩。

| 键 | 类型 | 说明 |
| --- | --- | --- |
| `background` | 面，或色值 | 底色 |
| `color` | 令牌，或色值 | 字色 |
| `<部件>-background` | 面，或色值 | 某个部件的底色，例如 `header-background` |
| `<部件>-color` | 令牌，或色值 | 某个部件的字色，例如 `label-color` |

四条规则。

- **省略是继承，`nil` 是关闭，`:default` 是回落内置。** 三句话回答「怎么改回来」。`(:level 1 :prefix nil)` 是去掉一级的前缀；把 `:prefix` 整个删掉，就是从节点级继承；`:color :default` 是回到内置颜色，不管节点级写了什么。
- **条目先写选择器，再写键值，选择器就是属性名。** `(:level 1 :prefix "◆ ")` 的意思是「当这个节点的 `level` 是 1」。不给选择器就是整个类型。`level` 不是白名单里的特权名字，任何类型声明了同名属性都能这么选，没声明的永远匹配不上。
- **每个键的类型固定。** 未知键加载时报错，这类型回退内置，页面照常渲染。
- **内置样式也写在这张表里。** 代码里没有字面颜色值，所以你改的和你看的是同一套东西。

能写的键有两个来源：附录 C 的全局键，加这个类型自己的可盖属性（`surface`、`accent`、`align` 三种类型）。所以 `card` 的 `accent` 可以在这里写 `(:accent warning)`，不需要另造一个键名。

`etaf-md-set-style` 往同一张表里写，不是第二套。同一个键在两处都写时，后生效的那个赢。传 `nil` 就删掉自己那一条，回到内置。

改了表要重画整页并重新派生，但不重新解析，见 8.2。要给一个类型加新键，写一个渲染函数，见 10.4。

### 4.4 两套颜色权限

| 谁 | 能写什么 | 为什么 |
| --- | --- | --- |
| 文档 | 语义词，例如 `surface=raised`、`accent=warning` | 文档要能在任何主题、任何机器上读 |
| 读者样式 | 面或令牌的名字，或字面值 `"#ff0000"` | 读者拥有自己的页面 |

写字面值有一个代价：它不跟随主题切换。暗色页上选的蓝，换到纸色页可能读不清。所以文档里永远不写字面值，这条是硬规矩。

**读者能盖哪些属性，由属性的类型决定。** `surface`、`accent`、`align` 三种类型天生可盖；其余五种只认文档，读者写了也不生效。所以「哪些是外观」不需要标记，也不可能标记错。

派生属性（`:derived t`）是另一件事：文档写不出来，它由解析或派生阶段给，例如标题的 `level`。它仍能被样式表当选择器用。

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

多栏只有一种写法，`columns`。原来分开的 `layout`、`flex`、`card-grid` 合并成它一个，因为它们的差别只是默认值。`columns` 一个属性收两种形态：给一个数字就是等宽几栏，给一串轨道就是按比例分。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `columns` | number 或 string | 无 | 数字表示等宽几栏；字符串是一串轨道，空格分隔，单位 `fr`、`ch`、`%` |
| `gap` | length | `"2ch"` | 栏间距 |
| `padding` | length | 无 | 内边距，四边同值 |
| `min-width` | length | `"24ch"` | 每栏最小宽度，放不下就叠成一栏 |
| `align-items` | enum | `stretch` | 子块在交叉轴的对齐：`start`、`center`、`end`、`stretch` |
| `justify-content` | enum | `start` | 主轴：`start`、`center`、`end`、`between` |
| `wrap` | boolean | `false` | 放不下时换行，不叠栏 |
| `align-self` | enum | `start` | 容器自身在父级里的水平位置：`start`、`center`、`end` |

子块是 `col`，收一个属性。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `grow` | number | `1` | 分到剩余宽度的份数 |

````markdown
:::columns {columns="2fr 1fr" gap="2ch"}
:::col
## 一次命中

缓存里只有一张图，命中时页面从磁盘读它，不再启动渲染器。
:::
:::col
旁边的说明写成普通段落就行，宽度由栏决定。
:::
:::
````

三张卡片并排，就是 `columns` 里放三个 `card`。

````markdown
:::columns {columns=3}
:::card {title="解析"}
文本到语义树。
:::
:::card {title="排版"}
语义树到视图。
:::
:::card {title="发布"}
视图到 buffer。
:::
:::
````

### 5.2 轨道、间距、内边距

- `columns=3` 就是三条 `1fr`。
- `columns="2fr 1fr"` 是显式轨道，按 Ebox 的写法：`(fr 2)` 写成 `2fr`，固定宽写 `20ch`，百分比写 `30%`。
- `gap` 只加在块与块之间，不加在外面。外面那一圈归 `padding`。
- `padding` 只收一个长度，四个方向同值。不做 `padding-x`、`padding-y`，两个轴分开给会让同一页出现两种内边距。
- 垂直间距用 `lh` 的整数倍。用像素会让行距和行高对不上，边框压在字上。

### 5.3 窄窗降级

放不下并排的栏时，按顺序降级，不做横向滚动。

1. **减栏。** `columns=3` 先降到 2，再降到 1，每栏不小于 `min-width`。
2. **叠栏。** 用了轨道的，每栏小于 `min-width` 时整块叠成一栏，栏与栏之间留一个空行。
3. **收边距。** `padding` 从 2ch 收到 1ch，`gap` 从 2ch 收到 1ch，外框保留。
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
| 提示 | `note`、`tip`、`important`、`warning`、`caution` | 一种定义，五个固定的强调值 |
| 集合 | `steps`、`timeline`、`stats`、`field`、`file-tree`、`chat` | 子块带标签，按顺序或按名字排 |
| 交互 | `tabs`、`code-tabs`、`accordion`（子块 `collapse`） | 有状态，可按键切换 |
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
| `title` | string | 该强调值的固定标题 | 换掉标题文字 |
| `collapsible` | boolean | `false` | 允许收起 |
| `open` | boolean | `true` | 收起时默认展开 |

```markdown
:::warning {title="兼容性" collapsible=true}
这段只在 Emacs 30 及以上可用。
:::
```

两个写法渲染成同一个东西，都在同一张定义上。名字到强调值的映射是固定的：`note` 对 `primary`，`tip` 对 `success`，`important` 对 `important`，`warning` 对 `warning`，`caution` 对 `danger`。

为什么两条路都留。GitHub 上的文档粘贴过来就能用，这是最常见的入口；写长文档时容器写法能和别的容器对齐，也能带属性。

### 6.3 卡片

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 标题，省略就不画标题行 |
| `description` | string | 无 | 标题下一行灰色摘要 |
| `surface` | surface | `raised` | 见 4.1 |
| `accent` | accent | `neutral` | 见 4.1 |
| `href` | string | 无 | 整张卡片可点，跳到这个地址 |
| `text-align` | align | `start` | 内容水平位置 |
| `width` | length | 省略即占满 | 自身宽度，省略时撑满父级 |

解决的场景：一组并列材料需要一个共同边界。用标题分节会把材料抬到节标题同级，用列表会把图压成一项。

组件：`etaf-card`，默认槽接正文，`title` 和 `description` 直接对应。`surface` 需要组件接受一个面参数，属于组件侧改动，见 9.6。

### 6.4 盒子

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `surface` | surface | `none` | 见 4.1 |
| `accent` | accent | `neutral` | 见 4.1 |
| `padding` | length | 无 | 内边距 |
| `text-align` | align | `start` | 内容水平位置 |
| `width` | length | 省略即占满 | 自身宽度，省略时撑满父级 |

盒子是卡片的无标题形式。居中一张图就是它。

```markdown
:::box {text-align=center padding="1lh"}
![示意图](figures/hit.png)
:::
```

### 6.5 步骤

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `start` | number | `1` | 起始编号 |
| `list-style` | enum | `decimal` | `decimal` 用数字，`bullet` 用圆点 |

子块是 `step`，属性 `title` 必填。

````markdown
:::steps
:::step {title="定位"}
用 `sample` 抓栈，别先猜。
:::
:::step {title="改因"}
改产生现象的那一层，不改它的结果。
:::
:::
````

解决的场景：操作手册里读者要看得出有几步、站在第几步。用有序列表也能写，但编号和标题挤在一行，长标题折行后编号落单。

组件：`etaf-steps`。

### 6.6 时间线

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `list-style` | enum | `bullet` | `bullet`、`decimal`、`none` |

子块是 `event`，属性 `title` 必填，`time` 可选。

````markdown
:::timeline
:::event {time="2026-11-12" title="定位到慢在画图"}
`image-size` 会真的把图画出来。
:::
:::event {time="2026-11-13" title="改成读文件头"}
打开从 5.4 秒降到 0.33 秒。
:::
:::
````

解决的场景：版本记录、事故经过。用列表会丢掉「时间在上、内容在下」的对齐。

组件：`etaf-timeline`。

### 6.7 字段表

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `label-width` | length | 自动 | 名称列宽度，省略时按最长的名称算 |
| `separator` | enum | `colon` | `colon` 用冒号，`none` 只留间距 |

内容是列表，每项第一个冒号前是名称。对应 HTML 的描述列表 `<dl>`。

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
| `columns` | number | `3` | 一行放几个，窄窗减少 |

子块是 `stat`，属性 `title` 必填（说明文字），`value` 必填（数字文本）。子块没有内容，也要写关闭行。

````markdown
:::stats
:::stat {title="打开" value="0.33 s"}
:::
:::stat {title="缩放" value="0.18 s"}
:::
:::stat {title="内存" value="349 MB"}
:::
:::
````

数字用 `foreground` 加粗，说明用 `muted`。超过一行换行，不缩字号。组件：`etaf-statistic`。

### 6.9 文件树

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 树上方一行标题 |
| `list-style` | enum | `tree` | `tree` 画树线，`none` 只缩进 |

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

组件：`etaf-tree`。

### 6.10 对话

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `self` | enum | `left` | 自己说的话放哪边：`left`、`right` |

子块是 `message`，属性 `from` 必填（发送者），`time` 可选。

````markdown
:::chat
:::message {from="问" time="14:20"}
预览为什么不刷新？
:::
:::message {from="答" time="14:21"}
保存之后才刷新，改到一半不重排。
:::
:::
````

解决的场景：教程里演示一次问答。它是一块对齐的文本加缩进，不画气泡。

### 6.11 标签页

子块是 `tab`，属性 `title` 必填，`selected` 可选（布尔，一组里只能一项写）。

````markdown
:::tabs
:::tab {title="Emacs 29"}
用 `image-size` 的旧签名。
:::
:::tab {title="Emacs 30+" selected=true}
直接传 buffer。
:::
:::
````

两处都写 `selected` 时只认第一项，页面报一行，见 3.4。

解决的场景：同一件事的几种写法并行，读者只需要一种。三个并列小节会让目录变长，标签页只占一块位置。

交互按第 7 章的契约，不单独定规则。组件是 `etaf-tabs`，受控，状态由块提供。

### 6.12 代码标签页

和 `tabs` 一样，只是子块里放围栏代码，`title` 省略时用围栏的语言名。

````markdown
:::code-tabs
:::tab
```elisp
(etaf-md-open)
```
:::
:::tab
```python
print("hi")
```
:::
:::
````

它是一条定义，不是新语义。渲染走的是和 `tabs` 同一条路径，区别只有标签的默认来源：省略 `title` 时取第一段围栏代码的语言名。

### 6.13 折叠

子块是 `collapse`，放在 `:::accordion` 里，同时只开一块。只有一项时就是普通的一折。

子块的属性：`title` 必填（收起时的标题），`open` 可选（布尔，默认 `false`）。

````markdown
:::accordion
:::collapse {title="完整的报错"}
```
后面的长文本放这里。
```
:::
:::collapse {title="版本差异"}
:::
:::
````

只要一折时写一项：

````markdown
:::accordion
:::collapse {title="完整的报错" open=true}
```
长文本。
```
:::
:::
````

解决的场景：长推导、长日志、完整报错。留在页面上备查，但不挡路。

组件：`etaf-accordion`，受控，`open` 与 `multiple` 由块提供。

### 6.14 表格

普通管道表格已经能用。这个容器管表格的**呈现**，不管表格本身：它给一行标题，标出要看的行与列。不带它，表格照常渲染，只是没有标题和强调。

只有标题一个职责时，名字该是标题相关的词。它现在还管高亮，将来表格的对齐、脚注也归它，职责比一个标题大，所以名字停在 `table`。

| 属性 | 类型 | 默认 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 无 | 表格上方一行标题 |
| `highlight-rows` | string | 无 | 高亮的行号，空格分隔，例如 `2 3` |
| `highlight-columns` | string | 无 | 高亮的列号，空格分隔，例如 `1` |
| `highlight` | accent | `warning` | 高亮用哪个强调值 |

```markdown
:::table {title="打开耗时" highlight-rows="3" highlight=warning}
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
| `height` | length | 省略即由内容决定 | 内容区高度 |

```markdown
:::window {title="etaf-md-preview"}
一段界面截图或者一段文字。
:::
```

从 plume 的 `window` 变形而来。它画圆角和阴影，我们只画一条标题栏。圆角在字符网格里画不出来，硬画就是一排乱字符。

### 6.16 状态总表

| 容器 | 家族 | 实现层 | 状态 |
| --- | --- | --- | --- |
| GitHub 提示块 `> [!NOTE]` 等五种 | 提示 | 原语 | 已实现 |
| `note`、`tip`、`important`、`warning`、`caution` | 提示 | 原语 | 计划中 |
| `box` | 结构 | 原语 | 计划中 |
| `card` | 结构 | `etaf-card` | 计划中 |
| `columns` + `col` | 结构 | 原语，引擎的 grid | 计划中 |
| `steps` + `step` | 集合 | `etaf-steps` | 计划中 |
| `timeline` + `event` | 集合 | `etaf-timeline` | 计划中 |
| `stats` + `stat` | 集合 | `etaf-statistic` | 计划中 |
| `field` | 集合 | 原语 | 计划中 |
| `file-tree` | 集合 | `etaf-tree` | 计划中 |
| `chat` + `message` | 集合 | 原语 | 计划中 |
| `tabs` + `tab` | 交互 | `etaf-tabs` | 计划中 |
| `code-tabs` + `tab` | 交互 | `etaf-tabs` | 计划中 |
| `accordion` + `collapse` | 交互 | `etaf-accordion` | 计划中 |
| `table` | 文稿 | 原语 | 计划中 |
| `window` | 文稿 | 原语 | 计划中 |

## 7. 交互契约

### 7.1 交互来自组件

文档不能给任何东西加行为。定义也不能：**能交互是因为它背后是一个组件，不是因为定义里写了什么。** 定义只负责两件事：给一个本块状态格子，给状态变化时的回调。按键、焦点、方向键全在组件里。

这条跟第 9 章的「组件厚」是同一件事：`etaf-tabs` 本来就能用键盘，`:::tabs` 只是把它接到文档里。所以没有「声明可交互」的关键字，也不需要。

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
- 默认状态由属性决定，`selected`、`open` 两个属性就够。

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

## 9. 定义与组件

这一章说清两件事：定义该有多薄，可复用的东西放在哪。

### 9.1 三层

| 层 | 东西 | 一句话 | 谁调用 |
| --- | --- | --- | --- |
| 引擎 | `box`、`column`、`grid`、文本属性 | 只会摆和画，不懂含义 | 组件 |
| 组件 | `etaf-card`、`etaf-tabs`、`etaf-accordion` | 有名字、有参数、可复用 | 应用和定义 |
| 语法 | `:::card`、`:::tabs` | 把文档的名字和属性翻成组件调用 | 渲染器 |

判据只有一句：**删掉这层，别人还能用吗？** `etaf-card` 删了，别的应用就用不了卡片，所以它在组件层；`:::card` 删了，只是这份文档写不了卡片，所以它在语法层。

### 9.2 从组件到语法

做一个新容器的顺序是固定的三步，判据就是 9.1 那一句。

1. **先找组件。** `etaf-ui` 里有语义对得上的组件，定义只写翻译那三行。这一步最常见，也最薄。
2. **没有组件，而这份形状会被第二处用到，就先写组件，再封语法。** 组件放 `etaf-ui`，带参数、测试和文档；定义缩回翻译。
3. **只用这一次，就在 `:view` 里用 `etaf-view` 搭。** DSL 是默认写法，只有它表达不了的地方（运行时才算出来的标签或列表）才降到 `etaf-node`。用够两次，按 9.6 搬进 `etaf-ui`。

第 3 步不是例外，是第一次实现。风险是它永远留在定义里，所以 9.6 那条搬家的规矩跟着它。

**接口边界。** `:body` 里只能用 `etaf-` 开头的公开接口，不能用 `ebox-` 开头的引擎内部函数。这条和应用、组件的规矩一致。

**内置容器走同一条路。** 6.16 的实现层一列写明每个内置容器靠哪个组件，还是靠原语。写自定义容器时照那一列判断自己该走哪条路。

### 9.3 定义只做三件事

一个类型的定义写三样东西，不多写。

1. **声明**：文档能写哪些属性，各是什么类型、默认值。
2. **校验**：交给渲染器统一做，定义只声明。
3. **翻译**：把文档的语义（底色、强调、属性）换成组件的参数。

```elisp
(etaf-md-define-node 'card
  :name "card"
  :attrs '((title :type string :doc "卡片标题"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
             (expr (etaf-md-render env (etaf-md-children env)))))))
```

这是形状，不是完整例子。带多个属性、可盖属性与组件映射的完整写法在 10.1。

定义里没有一行画边框、写内边距。那些在 `etaf-card` 里。定义只把文档的词翻成组件的参数。`variant` 的取值由 `etaf-ui` 定，这里只是示意映射。

一条硬约束：**组件没有的参数，定义不能变出来。** 想让 `:::card` 收 `surface`，就得先让 `etaf-card` 接受一个面参数，那是组件侧的改动，见 9.6。绕过去只有一个办法，就是在定义里自己画一层壳，而那正好是 9.5 要禁的事。

### 9.4 组件只收语义参数

组件的参数是给人写的 Elisp 用的，不是给文档用的。

- **不收文档词汇。** 组件里不出现 `:accent`、`:container`、`:::card` 这类词，别的应用不该被迫理解 Markdown。
- **不收颜色值。** 组件认 `surface` 与 `accent` 这类语义角色，不认 `"#c00"`。具体颜色在组件里查令牌，换配色不会漏掉某个容器。
- **几何属性尽量少。** 内边距、间距这类由组件自己的默认值负责，定义只在必要时覆盖。

反例：组件里加一个 `:markdown-level`，或者定义里手画卡片边框。前者把语法漏进组件，后者把组件复制一份。

### 9.5 一个视觉事实一个权威

| 事实 | 权威 |
| --- | --- |
| 标题、引用、代码、表格长什么样 | 样式表（第 4 章），读者可改 |
| 容器长什么样 | 定义传给组件的参数 |
| 组件自己的基线 | 组件 |
| 配色 | 令牌，三种配色各一套 |

两处都能改同一个事实，就是 bug。组件的默认值只是基线，定义可以覆盖；定义的值是文档默认，外观属性还能被读者盖掉，见 4.4。

### 9.6 用够两次就上移

新容器要的窗口没人有，定义只能拿原语自己搭。这不是重复造轮子，是第一次实现。风险是它永远留在定义里。

规则：**第二个应用也要它，就搬进 `etaf-ui`**，连参数、测试和文档一起搬。搬完定义缩回翻译那三行。

判据还是 9.1 那句：删掉它，别人还能用吗？

### 9.7 内置定义也走定义

`box`、`card`、`columns` 不是渲染器里的特例，它们是同一张注册表里的三条定义。`heading`、`quote`、`code` 也一样，只不过它们没有名字，文档写不出来。

这一条是整套分法能不能长期成立的关键。只要有一个类型在渲染器里有专属分支，这套 API 就没被验证过，用户迟早撞上只有那条分支才有的能力。

三个后果。

- 内置定义写在包的加载代码里，和用户定义用同一个入口注册。
- 测试里必须有一条：把内置的 `card` 换成用户定义，页面照常渲染。
- 组件改参数时，先红的是定义测试，不是用户。

## 10. 扩展

### 10.1 一个类型的定义

一个定义是数据加一个函数，不是文档里的代码。

```elisp
(etaf-md-define-node 'card
  :name "card"
  :summary "一张带标题的卡片"
  :attrs '((title  :type string :doc "卡片标题")
           (accent :type accent :default neutral :doc "强调"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
                      :variant (pcase (etaf-md-attr env :accent)
                                 ('warning 'warning)
                                 ('success 'success)
                                 (_ 'default))
             (expr (etaf-md-render env (etaf-md-children env)))))))
```

| 关键字 | 取值 | 含义 |
| --- | --- | --- |
| 名字 | 符号，第一个参数 | 类型名。`heading` 和 `card` 都在这张表里 |
| `:name` | 字符串 | 文档写得出的写法，`"card"` 对应 `:::card`。省略表示文档写不出来 |
| `:summary` | 字符串 | 一行说明，进帮助和报错 |
| `:attrs` | 属性表 | 属性名、类型、默认值、权限 |
| `:accepts` | 子块表 | 收哪些子块。有它就是父类型，没有就是任意块 |
| `:view` | 函数 | `(lambda (env) VIEW)`，这个类型的默认画法 |
| `:contract` | 整数，当前 `1` | 文档侧属性表的版本，见 10.5 |
| `:extends t` | 标记 | 保留内置，你的追加，见 10.5 |
| `:replace t` | 标记 | 丢掉内置，由你重写，见 10.5 |

标题没有 `:name`，所以 `:::heading` 不存在；它的层级是一条派生属性：

```elisp
(etaf-md-define-node 'heading
  :attrs '((level :type number :derived t :default 1))
  :view #'etaf-md-heading-view)
```

`level` 文档写不出来，`###` 写几级它就是几。样式表却能拿它当选择器，见 4.3。这就是「层级」的全部定义，没有专属关键字，也没有渲染器里的分支。

**`view` 只收一个 `env`。** 当前节点就在里面，属性已经校验、补过默认值，派生属性也在里面。下面就是定义能拿到的全部。

| 能力 | 用法 | 给谁用 |
| --- | --- | --- |
| 读属性 | `(etaf-md-attr env :title)`；读某个子节点时把节点放最后：`(etaf-md-attr env :title tab)` | 所有类型 |
| 读类型 | `(etaf-md-type env)`，一个类型的画法被几个名字共用时用它分支 | 所有类型 |
| 文字内容 | `(etaf-md-text env)` 把子节点的文字拼成一个字符串 | 标题、段落这类纯文本 |
| 子节点 | `(etaf-md-children env)` 按顺序给一串节点 | 所有类型 |
| 画节点 | `(etaf-md-render env nodes)` | 只画一部分子节点时 |
| 内置画法 | `(etaf-md-default-view env)` 这个节点用内置画法再画一遍 | 包一层时 |
| 令牌 | `(etaf-md-token env 'muted)` | 所有类型 |
| 行高 | `(etaf-md-token env 'lh)` | 所有类型 |
| 面 | `(etaf-md-surface env 'raised)` 把面换成底色，`none` 返回 `nil` | 所有类型 |
| 强调 | `(etaf-md-accent env 'warning)` 把强调值换成颜色 | 提示块、卡片 |
| 样式值 | `(etaf-md-style env :background)` 读本节点的样式值 | 自定义画法 |
| 编号 | `(etaf-md-number env)`，`(etaf-md-format-number N 'lower-roman)` | 标题、表格 |
| 打开链接 | `(etaf-md-follow-link env href)` | `card` 的 `href` |
| 本块状态 | 读 `(etaf-md-block-state env :current)`，带默认值 `(etaf-md-block-state env :current v)`；写 `(etaf-md-block-state env :current VALUE)` | `tabs`、`accordion` |
| 可用宽度 | `(etaf-md-available-width env)` | `columns` 的降级判断 |

**画法默认用 `etaf-view` 的 DSL。** 它比手工搭节点短，也看得出结构：属性写在前面，子节点写在后面，属性值是普通 Elisp，动态子节点用 `(expr …)` 包一层。

```elisp
(etaf-view
 (box :padding '((lh 1) (ch 2))
   (text "标题")
   (expr (etaf-md-render env (etaf-md-children env)))))
```

只有一个地方降到 `etaf-node`：标签或属性要在运行时才算出来，比如用 `mapcar` 生成一串行。那种时候 DSL 写不出来，不是风格选择。

状态那一行是关键。`etaf-tabs` 是受控组件，`selected` 和 `on-change` 都由调用方给；定义本身没有地方存状态，所以每个块要有一个自己的状态格子，由渲染器创建，按块隔离。

**子块表每项写什么。**

```elisp
:accepts '((col :attrs ((grow :type number :default 1 :doc "宽度份数")))
           (tab :attrs ((title :type string :required t)
                        (selected :type boolean :default false))))
```

子块自带一个 `title` 属性，类型 `string`，由渲染器提供，不在 `:attrs` 里重复声明。省略时它的值是 `nil`，父类型在 `:view` 里自己补默认值：`col` 不补，`tab` 补成空字符串，`code-tabs` 补成第一段围栏代码的语言名。

### 10.2 属性的规则

- 定义只能引用共享属性表里的名字，或者自己声明的专有属性。专有属性要在 `:summary` 里说清只能和它一起用。
- 每一项只有一个位置：第一个元素是名字，它是这一项的键。后面全是具名字段。
- `:type` 必写，取值是 `string`、`number`、`boolean`、`length`、`surface`、`accent`、`align`、`enum`。`string` 可以再加 `:pattern`；`enum` 必须写 `:one-of (...)`。
- `:default` 不写就是 `nil`，所以 `nil` 默认值一个字都不用写。
- 必填写 `:required t`，例如 `(title :type string :required t :doc "标题文字")`。此时不许写 `:default`，两个都写是加载错误。必填只用于文档侧属性，读者侧的键一律可选。
- 派生属性写 `:derived t`，例如标题的 `level`。文档写不出它，它由解析或派生阶段给，但能被样式表当选择器。
- `surface`、`accent`、`align` 三种类型天生可被读者盖，不需要标记；其余五种只认文档。所以没有 `:appearance` 这个字段，也就没有标错的可能。
- `:doc` 可选，但建议写。它出现在帮助和报错里。
- **子块的标签是渲染器给的，不是定义声明的。** 每个 `:accepts` 项都多一个 `title`，类型 `string`。定义只能在 `:view` 里给它补默认值，不能改它的名字或类型。
- 定义不能自己读文件、发网络请求、起定时器。它只能拿到 `env`。
- **`:view` 里用 `etaf-` 开头的公开接口，不用 `ebox-` 的引擎函数**，见 9.2。引擎是 `etaf-ui` 的内部，越过它的人会在下一次升级时撞车。
- 渲染器的分发代码里不出现类型名字。它只按注册表找定义，不按名字写分支。

### 10.3 给一个类型装值

样式是数据，不写代码。按层级给不同前缀，就是三行。

```elisp
(etaf-md-set-style 'heading
  '((:font-weight bold)
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

条目第一段是选择器，就是属性名；`(:level 1 …)` 的意思是「当这个节点的 `level` 是 1」。不给选择器就是整个类型。`level` 没有特权，任何类型声明了同名属性都能这么选，没声明过的名字永远匹配不上。

前缀是包自带的键，所以这一段不用写函数。默认定义没想到的东西，才需要函数，见 10.4。

加载时校验：类型不认识、键不认识、值类型不对，都当场报错，这一类型回退内置。错误行点名类型、键、合法值。传 `nil` 就删掉自己那一条。

### 10.4 给一个类型换画法

样式不够用时，给一个函数。函数还能给这个类型加读者侧的新键。

```elisp
(etaf-md-set-view 'heading
  (lambda (env)
    (etaf-view
     (box :background-color (etaf-md-surface env (etaf-md-style env :background))
       (expr (etaf-md-default-view env)))))
  :extends t
  :style-keys '((background :type surface :doc "标题底色")))
```

| 部分 | 含义 |
| --- | --- |
| 第一个参数 | 类型名，`heading` 或 `card` 都行，没有特例 |
| 第二个参数 | `(lambda (env) VIEW)`，和定义里的 `:view` 同一个签名 |
| `:extends t` | 保留内置的画法与键，你的追加 |
| `:replace t` | 丢掉内置的画法与键 |
| `:style-keys` | 新的读者键，写法同 10.2。只能在函数里声明 |

三条规则。

- 必须返回一个视图，不能改节点树。
- 函数报错时，这类型回退内置，页面继续渲染，错误进 `doctor`。
- **加键必须配函数。** 数据定义不能加键，理由很直接：没人读的键就是死配置。

编号也走这里，不需要专用关键字：`etaf-md-number` 读派生阶段算好的数，`etaf-md-format-number` 按 CSS `list-style-type` 的词格式化，取 `decimal`、`lower-roman`、`upper-alpha`。

```elisp
(etaf-md-set-view 'heading
  (lambda (env)
    (etaf-view
     (text :weight (etaf-md-style env :font-weight)
       (expr (concat (etaf-md-style env :prefix)
                     (etaf-md-format-number (etaf-md-number env) 'decimal)
                     " "
                     (etaf-md-text env))))))
  :extends t)
```

### 10.5 覆盖与卸载

三种写法，一张表说清。

| 写法 | 效果 | 用在 |
| --- | --- | --- |
| `:extends t` | 保留内置的属性与画法，你的追加进去 | 想加属性、包一层 |
| `:replace t` | 丢掉内置定义，属性表和画法都由你定 | 想彻底换一种做法 |
| 两个都不写 | 只在没有同名类型时生效，重名报错 | 新类型 |

四条约束。

- **文档侧的属性表只能增，不能改。** 新属性只能追加，改名或删掉算破坏性变更，升 `:contract`，旧文档按 3.4 降级并说明。子块名字同理。
- **`:attrs` 和 `:style-keys` 是两个名字，权限不同。** `:attrs` 是文档写的；`:style-keys` 是读者写的，可扩展。
- **`:default` 永远指内置原值。** 加载时给内置定义留一份快照，否则「回到默认」没有意义。
- **覆盖要留痕。** `:replace t` 的报错行点名被替换的定义，`doctor` 列出覆盖链和来源文件。

同名冲突按加载顺序解决：两个第三方包都改一个类型时，后加载的那个必须显式 `:replace t`，否则报错点名双方。

**卸载。** 每个入口都给一条回路，测试才写得出「装上去、卸下来、页面回到内置」。

| 动作 | 怎么写 |
| --- | --- |
| 删掉一个类型定义 | `(etaf-md-undefine-node 'card)` |
| 删掉自己的一条样式 | `(etaf-md-set-style 'heading nil)` |
| 删掉自己换的画法 | `(etaf-md-set-view 'heading nil)` |

内置类型卸载后回到内置那份；用户定义卸载后名字不再存在，文档里写它就是「名字没有定义」。

### 10.6 定义放在哪、什么时候读

- 内置定义写在 `lisp/etaf-md-nodes.el`，包加载时按注册表顺序注册一次：先文本类型，再提示，再结构，再集合，最后交互。它们和用户定义走同一个 `etaf-md-define-node`，没有第二套注册路径。
- 用户定义放在 `etaf-md-node-directory` 指的目录里，一个 `.el` 一个文件。
- 加载顺序固定：包自带的先，用户目录后，同一目录内按文件名排序。后加载的能覆盖先加载的，但必须显式声明，见 10.5。
- 一个 session 创建时读一次注册表，之后不再读盘。改了定义要 `r` 重载，或者重开预览。
- 文档不能注册类型，也不能执行 Elisp。分享文档不等于分享代码。
- **契约版本由文档自己声明。** front matter 里可以写 `contract: 1`；不写就按当前版本处理。声明了却对不上时，那一份文档按 3.4 逐块降级并说明要哪个版本。

### 10.7 调试

- `etaf-md-describe-nodes` 列出注册表：类型名、文档里的写法、摘要、属性、子块、实现层、来源文件。计划中。
- 出问题先查一条链：这块是什么类型 → 哪个定义 → 调了哪个组件 → 样式值来自哪里 → 落到哪个令牌。计划中。
- 报错行永远在页面上，不用开日志。
- 定义自己报错时，那一块降级成源码，加一行「`card` 的定义报错：…」，后面的块照常。
- `etaf-md-doctor` 报告注册了几个类型、有没有定义文件加载失败、有哪些覆盖、有没有卸载不了的残留。计划中。

### 10.8 信任模型

- 文档没有执行权限。它能做的只有命名和给属性。
- 定义只从用户配置的目录加载。不读当前目录的定义，不读文档旁边目录的定义。
- 定义不能读文件、发网络请求、起定时器、改全局状态。要数据就在 `attrs` 里传。
- 渲染不产生副作用。视图只读 refs 和缓存值。

## 11. 路线图

### 11.1 阶段

| 阶段 | 内容 | 完成判据 |
| --- | --- | --- |
| 0 | GitHub 提示块 | 已实现，51 个测试覆盖 |
| 1 | 渲染路径：解析、派生、样式表、失败目录，并把 `heading`、`box`、`columns`、`card` 用定义写 | 14 种失败各有一条断言；三层嵌套与超限；窄窗三档截图；用户定义能替掉内置的 `card`；每个内置节点至少一个样式键生效；改样式表不重新解析 |
| 2 | 提示容器：五个名字，和 GitHub 写法共用一张定义 | 两种写法渲染成同一个 buffer 文本；强调值映射正确 |
| 3 | 集合：`steps`、`timeline`、`stats`、`field`、`file-tree`、`chat` | 每个容器有正例、反例、三种配色截图 |
| 4 | 交互：`tabs`、`code-tabs`、`accordion` 与它的子块 `collapse` | 按键走命令循环；状态经重排与换主题不丢；扁平化输出不缺内容 |
| 5 | 文稿：`table`、`window` | 表格高亮按行列生效；窗口只画标题栏 |
| 6 | 注册表与用户定义 | 示例定义能装能卸，卸载后页面回到内置；给内置类型加一个键并生效；覆盖后 `:default` 仍回内置；契约版本不符有提示；`doctor` 报数量与覆盖链 |
| 7 | 源码 buffer 的编辑体验：降权、配对提示、插入与补全、折叠，合成 `etaf-md-edit-mode` | 关闭后 `font-lock-keywords` 与开启前 `equal`；`buffer-string` 不变；2000 行文档额外耗时 50 毫秒以内；同一行内打字不触发配对计算 |

### 11.2 每个容器的验收矩阵

每个容器都要过这六格，少一格不算完成。

| 格 | 检查什么 |
| --- | --- |
| 正例 | 文档写出来，渲染成预期的样子 |
| 反例 | 少一个必填属性、写错一个值，页面降级且说明准确 |
| 嵌套 | 放进 `columns` 的栏里、放进 `card` 里，仍然成立 |
| 配色 | 暗色、亮色、纸色、跟随主题，四档下都可读 |
| 窄窗 | 宽、中、窄三档，内容不少，字号不变 |
| 样式 | 一个样式键改变了它的外观；一个未知键报错并回退内置 |

渲染路径另有四条断言，跟容器无关。

- 同一份文档，改样式前后解析次数不变。
- 标题加了前缀，锚点不变。
- 关了编号，派生阶段跳过。
- 覆盖了 `heading` 的渲染后，`etaf-md-default-view` 仍是内置画法。

### 11.3 完成判据

一个阶段完成，必须同时满足三条。

1. `make check` 通过，包括结构检查、编译、测试、接口核对。
2. 受影响的示例在真实 GUI 里跑过一遍，截图看过。
3. 附录 A 的属性表、附录 C 的样式表、附录 D 的对照表、附录 E 的词汇表同步更新。

## 12. 不做的事

- 不做 HTML 子集、CSS 子集、`<style>` 标签。一套渲染器里塞两个排版系统，边界会越来越模糊。
- 不做文档内嵌脚本，不让文档注册容器。
- 不做字号参数、缩放参数。缩放只存在于读者样式表的 `:scale`。
- 不做远程 iframe、远程播放器、远程代码执行。
- 不做圆角、阴影、渐变、动画。
- 不做 markdown 之外的第二种文档格式。
- 不做页面、路由、导航、发布。那是上层应用的事，见 1.2。
- 不做 `justify` 文本两端对齐。字符网格里没有字间距可以拉，只能填空格，中文段落行尾会出洞。

## 附录 A：属性参考

共享属性。类型只从这里挑，不发明同义词。下表是**文档属性**，也就是花括号里写得出来的；**派生属性**由解析或派生阶段给，在最后单独列出。

| 属性 | 类型 | 含义 | 用在 |
| --- | --- | --- | --- |
| `title` | string | 标题文字 | 提示块、card、steps、timeline、file-tree、accordion、table、window；子块里是 tab、step、event、stat、collapse |
| `description` | string | 标题下的摘要 | card |
| `surface` | surface | 底色 | box、card |
| `accent` | accent | 强调 | box、card |
| `text-align` | align | 内容水平位置 | box、card |
| `align-self` | enum | 自身在父级里的位置 | columns |
| `align-items` | enum | 子块的交叉轴对齐 | columns |
| `justify-content` | enum | 子块的主轴对齐 | columns |
| `width` | length | 自身宽度；省略即占满 | box、card |
| `height` | length | 内容区高度；省略即由内容决定 | window |
| `padding` | length | 内边距 | box、columns |
| `gap` | length | 块间距 | columns |
| `columns` | number 或 string | 栏数或轨道 | columns、stats |
| `min-width` | length | 最小栏宽 | columns |
| `wrap` | boolean | 放不下时换行 | columns |
| `grow` | number | 宽度份数 | col |
| `list-style` | enum | 列表记号 | steps、timeline、file-tree |
| `open` | boolean | 默认展开 | 提示块；子块里是 collapse |
| `collapsible` | boolean | 允许收起 | 提示块 |
| `selected` | boolean | 这一项默认选中 | tab 子块 |
| `href` | string | 跳转地址 | card |
| `start` | number | 起始编号 | steps |
| `separator` | enum | 名称与值的分隔 | field |
| `label-width` | length | 名称列宽 | field |
| `self` | enum | 自己一侧 | chat |
| `from` | string | 发送者 | message |
| `time` | string | 时间 | event、message |
| `value` | string | 数字文本 | stat |
| `highlight-rows` | string | 高亮行号，空格分隔 | table |
| `highlight-columns` | string | 高亮列号，空格分隔 | table |
| `highlight` | accent | 高亮的强调值 | table |
| `id` | string | 稳定锚点 | 所有块 |

**派生属性。** 文档写不出来，由解析器或派生阶段给。它们能被样式表当选择器用，见 4.3。

| 属性 | 类型 | 含义 | 用在 |
| --- | --- | --- | --- |
| `level` | number | 标题级别，由 `#` 的数量决定 | heading |
| `language` | string | 围栏代码的语言名 | code |
| `number` | number | 派生阶段算好的序号 | heading、table |

## 附录 B：底色、强调与令牌

`surface` 的每个值对应一个令牌，`accent` 的每个值对应一对。

| 属性值 | 前景 | 底色 | 说明 |
| --- | --- | --- | --- |
| `surface=none` | — | 无 | 不画底 |
| `surface=page` | — | `background` | 与正文拉开 |
| `surface=raised` | — | `surface-raised` | 代码块、卡片 |
| `surface=sunken` | — | `surface-sunken` | 表头、次要信息 |
| `surface=quote` | — | `quote` | 引用性质 |
| `accent=neutral` | `foreground` | `surface-raised` | 无强调 |
| `accent=primary` | `primary` | `primary-soft` | 说明、链接 |
| `accent=success` | `success` | `success-soft` | 成功 |
| `accent=warning` | `warning` | `warning-soft` | 注意 |
| `accent=danger` | `danger` | `danger-soft` | 危险 |
| `accent=important` | `important` | `important-soft` | 重要 |

提示块的五个名字到强调值的映射固定：`note` 对 `primary`，`tip` 对 `success`，`important` 对 `important`，`warning` 对 `warning`，`caution` 对 `danger`。

## 附录 C：样式键参考

样式表能写的键有三个来源：下面这张全局表，该类型自己的可盖属性（`surface`、`accent`、`align` 三种类型），用 `:style-keys` 新加的键。键名就是 CSS 属性名。类型一列里，面是 4.1 的五个词，颜色是令牌名，两者都可以写字面值。值写 `:default` 表示回落内置。这张表是包自带的词汇。要给某个类型加键，用 `:style-keys`，见 10.4。

| 键 | 类型 | 用在 | 含义 |
| --- | --- | --- | --- |
| `background` | 面或颜色 | quote、code、table、callout | 底色 |
| `color` | 颜色 | heading、strong、em、link、code | 字色 |
| `accent` | accent | quote、callout | 强调色与浅底 |
| `font-weight` | `normal` / `bold` | heading、strong | 字重 |
| `font-style` | `normal` / `italic` | em、quote | 倾斜 |
| `text-decoration` | `none` / `underline` | link、strong | 装饰线 |
| `text-align` | `left` / `center` / `right` | table | 单元格对齐 |
| `prefix` | string | heading | 显示前缀，不影响锚点 |
| `suffix` | string | heading | 显示后缀 |
| `numbering` | `none` / `decimal` / `lower-roman` | heading、table | 由派生阶段编号 |
| `scale` | number | heading | 基准字号的倍数 |
| `margin-top` / `margin-bottom` | 长度 | heading、quote、code、table | 上下间距 |
| `border-left-width` | 长度 | quote、callout | 左侧竖条宽度 |
| `list-style` | enum 或字符 | list | 列表记号，字符只用 4.6 允许的 |
| `label-color` | 颜色 | code | 围栏语言标签 |
| `header-background` | 面或颜色 | table | 表头底色 |
| `stripe-background` | 面或颜色 | table | 条纹底色 |
| `accent-map` | alist | callout | 强调值到颜色的映射 |

## 附录 D：plume 对照

| plume | 我们的决定 | 说明 |
| --- | --- | --- |
| `align` | 并入 `box` 的 `text-align` 属性 | 不为一种对齐加一个容器 |
| `flex` | 并入 `columns` | 一个容器管横向、换行、比例 |
| `card` | 吸收，`card` | 圆角阴影改成一圈边框加面 |
| `card-grid` | 并入 `columns {columns=N}` | 卡片并排就是栏里放卡片 |
| `card-masonry` | 不吸收 | 行高固定，瀑布流装出来就是网格 |
| `steps` | 吸收，`steps` + `step` | 编号加标题 |
| `tabs` | 吸收，`tabs` + `tab` | 键盘可达，切换只重画一块 |
| `code-tabs` | 保留为 `tabs` 的一条定义 | 子块里放围栏代码，`title` 省略时取围栏的语言名 |
| `collapse` | 吸收，`accordion` 的子块 | 同时只开一块，搜索命中自动展开 |
| `field` | 吸收，`field` | 名称列自动对齐 |
| `timeline` | 吸收，`timeline` + `event` | 记号可选 |
| `table` | 部分吸收 | 标题与行列高亮 |
| `file-tree` | 吸收，`file-tree` | 记号只用允许的字符 |
| `code-tree` | 不吸收 | 和 `code-tabs` 加 `file-tree` 重合 |
| `chat` | 吸收，`chat` + `message` | 左右对齐加缩进，不画气泡 |
| `window` | 变形吸收，`window` | 只画标题栏 |
| `encrypt` | 不吸收 | 保密文档不该进预览 |
| `npm-to`、`lang-repl` | 不吸收 | 要包管理器和解释器 |
| `plot`、`qrcode`、`pdf` | 不吸收 | 要绘图和图像生成 |
| `annotation`、`abbreviation` | 不吸收 | 要图上标注和悬停浮层 |
| `code-pen`、`code-sandbox`、`repl`、`caniuse` | 不吸收 | 要浏览器和网络 |

## 附录 E：词汇表

这张表是命名的依据。新名字先在这里查；查不到就从「权威」那一列借一个，再补进这张表。

### E.1 文档属性

| 名字 | 出处 | 含义 | 不要写成 |
| --- | --- | --- | --- |
| `title` | HTML | 标题文字 | `heading`、`caption` |
| `description` | Ant、Primer | 标题下的摘要 | `summary`、`subtitle` |
| `surface` | Material、Polaris | 底色角色 | `background`、`fill`、`panel` |
| `accent` | shadcn/ui | 强调值 | `tone`、`variant`、`type`、`intent` |
| `text-align` | CSS | 内容水平位置 | `align`、`position` |
| `align-self` | CSS | 自身在父级里的位置 | `self-align`、`align` |
| `align-items` | CSS | 子块的交叉轴对齐 | `items`、`cross-align` |
| `justify-content` | CSS | 子块的主轴对齐 | `justify` |
| `width` | CSS | 自身宽度 | `w` |
| `height` | CSS | 内容区高度 | `h` |
| `padding` | CSS | 内边距 | `pad`、`inset` |
| `gap` | CSS | 块间距 | `spacing`、`space` |
| `columns` | Bootstrap 栅格、CSS | 栏数或轨道 | `cols`、`tracks`、`grid` |
| `min-width` | CSS | 最小栏宽 | `min`、`threshold` |
| `wrap` | CSS `flex-wrap`、Ant | 放不下时换行 | `flex-wrap`、`nowrap` |
| `grow` | Tailwind | 宽度份数 | `flex`、`ratio`、`weight` |
| `list-style` | CSS `list-style-type` | 列表记号 | `marker`、`bullet` |
| `open` | HTML `<details open>` | 默认展开 | `expanded`、`visible` |
| `collapsible` | Bootstrap、Primer | 允许收起 | `foldable`、`toggle` |
| `selected` | HTML `<option selected>` | 这一项默认选中 | `active`、`current` |
| `derived` | 本文的解析与派生阶段 | 派生属性，文档写不出 | `read-only`、`computed` |
| `href` | HTML | 跳转地址 | `url`、`link`、`to` |
| `start` | HTML `<ol start>` | 起始编号 | `begin`、`from` |
| `separator` | 通用 | 名称与值的分隔 | `divider` |
| `label-width` | CSS 风格组合 | 名称列宽 | `label-w`、`width` |
| `self` | 聊天界面通用 | 自己一侧 | `me`、`own` |
| `from` | 邮件、聊天 | 发送者 | `sender`、`author` |
| `time` | HTML `<time>` | 时间 | `date`、`at` |
| `value` | HTML `<input value>` | 数字文本 | `number`、`figure` |
| `highlight-rows` | 通用 | 高亮行号 | `hl-rows`、`mark` |
| `highlight-columns` | 通用 | 高亮列号 | `hl-cols`、`mark` |
| `highlight` | 本表命名规矩 | 高亮的强调值 | `tone`、`mark-color` |
| `id` | HTML | 稳定锚点 | `anchor`、`slug` |

### E.2 类型

| 名字 | 出处 | 含义 | 不要写成 |
| --- | --- | --- | --- |
| `string` | JSON Schema | 文本 | `str`、`text` |
| `number` | JSON Schema | 整数或小数 | `int`、`float`、`num` |
| `boolean` | JSON Schema | `true` 或 `false` | `bool`、`flag` |
| `length` | CSS 值类型 | 数字加单位 | `size`、`dimension` |
| `enum` | JSON Schema | 定义列出的词之一 | `one-of`、`choice` |
| `surface` | Material、Polaris | 五个面值之一 | `background`、`fill` |
| `align` | CSS | 三个水平位置之一 | `text-align`、`justify` |
| `accent` | shadcn/ui | 六个强调值之一 | `tone`、`variant` |

### E.3 令牌

| 名字 | 出处 | 含义 | 不要写成 |
| --- | --- | --- | --- |
| `background` | shadcn/ui | 页面底色 | `bg`、`page` |
| `foreground` | shadcn/ui | 正文 | `ink`、`text` |
| `muted` | shadcn/ui | 次要文字 | `secondary`、`dim` |
| `faint` | 通用 | 最弱的一层 | `subtle`、`ghost` |
| `border` | shadcn/ui | 边框 | `line`、`stroke` |
| `surface-raised` | Material 分层命名 | 抬起的面 | `panel`、`card-bg` |
| `surface-sunken` | Material 分层命名 | 下沉的面 | `panel2`、`inset` |
| `quote` | 通用 | 引用底 | `quote-bg`、`blockquote` |
| `quote-bar` | 通用 | 引用竖条 | `bar`、`accent-bar` |
| `table-header` | 通用 | 表头底 | `th`、`header` |
| `table-stripe` | 通用 | 条纹底 | `stripe`、`zebra` |
| `heading` | HTML | 标题色 | `title`、`h` |
| `primary` | shadcn/ui | 主要强调 | `accent`、`brand`、`info` |
| `primary-soft` | shadcn 的 `-foreground` 风格 | 主要强调的浅底 | `accent-soft` |
| `success` | Bootstrap、shadcn | 成功 | `ok`、`positive`、`green` |
| `success-soft` | 同上 | 成功的浅底 | `ok-soft` |
| `warning` | Bootstrap、shadcn | 注意 | `warn`、`caution` |
| `warning-soft` | 同上 | 注意的浅底 | `warn-soft` |
| `danger` | Bootstrap、shadcn | 危险 | `error`、`red`、`critical` |
| `danger-soft` | 同上 | 危险的浅底 | `error-soft` |
| `important` | GitHub 提示块 | 重要 | `note`、`emphasis` |
| `important-soft` | 同上 | 重要的浅底 | — |

### E.4 样式键

键名就是 CSS 属性名。CSS 里没有对应属性的，只有四个，单独列出并说明为什么留下。

| 名字 | 出处 | 含义 | 不要写成 |
| --- | --- | --- | --- |
| `background` | CSS | 底色 | `surface`、`bg`、`fill` |
| `color` | CSS | 字色 | `ink`、`fg`、`text-color` |
| `accent` | shadcn/ui | 强调色 | `tone`、`variant` |
| `font-weight` | CSS | 字重 | `weight`、`bold` |
| `font-style` | CSS | 倾斜 | `slant`、`italic` |
| `text-decoration` | CSS | 装饰线 | `underline`、`decoration` |
| `text-align` | CSS | 对齐 | `align` |
| `margin-top` / `margin-bottom` | CSS | 上下间距 | `gap-before`、`gap-after` |
| `border-left-width` | CSS | 左侧竖条宽度 | `bar-width` |
| `header-background` | 本表命名规矩 | 表头底色 | `header-surface` |
| `stripe-background` | 本表命名规矩 | 条纹底色 | `stripe-surface` |
| `label-color` | 本表命名规矩 | 围栏语言标签色 | `tag-color` |
| `list-style` | CSS | 列表记号 | `marker` |
| `prefix` | 无 CSS 对应 | 标题前缀，只改显示 | — |
| `suffix` | 无 CSS 对应 | 标题后缀，只改显示 | — |
| `numbering` | CSS `list-style-type` 的值 | 编号格式 | `number` |
| `scale` | 无 CSS 对应 | 基准字号倍数 | `font-size`、`size` |
| `accent-map` | 无 CSS 对应 | 强调值到颜色的表 | `tone-colors` |

`scale`、`prefix`、`suffix`、`accent-map` 没有 CSS 对应，原因是它们描述的是「这个节点额外多出来的东西」，不是布局或上色。它们仍然只在这里出现：`prefix`、`suffix`、`numbering`、`scale` 只对 `heading` 有效。

### E.5 函数

| 名字 | 含义 |
| --- | --- |
| `etaf-md-attr` | 读本节点校验过的属性 |
| `etaf-md-type` | 读本节点的类型 |
| `etaf-md-text` | 把子节点的文字拼成一个字符串 |
| `etaf-md-token` | 按令牌名取颜色或行高 |
| `etaf-md-surface` | 把面换成底色，`none` 返回 `nil` |
| `etaf-md-accent` | 把强调值换成颜色 |
| `etaf-md-children` | 按顺序取子节点 |
| `etaf-md-render` | 画一串节点 |
| `etaf-md-follow-link` | 打开一个目标 |
| `etaf-md-block-state` | 读写本块的状态 |
| `etaf-md-available-width` | 本块可用的宽度，用于降级判断 |
| `etaf-md-style` | 读本块的样式值 |
| `etaf-md-number` | 读派生阶段算好的编号 |
| `etaf-md-format-number` | 按 `list-style-type` 的词格式化编号 |
| `etaf-md-default-view` | 取某个类型的**内置**画法 |
| `etaf-md-define-node` | 注册一个节点类型 |
| `etaf-md-undefine-node` | 删掉一个类型定义 |
| `etaf-md-set-style` | 给一个类型装值 |
| `etaf-md-set-view` | 给一个类型换画法 |
| `etaf-md-describe-nodes` | 列出注册表 |

四个 `etaf-md-` 之外的名字：`etaf-card`、`etaf-tabs`、`etaf-accordion`、`etaf-steps`、`etaf-timeline`、`etaf-statistic` 属于 `etaf-ui` 的组件目录，本包只调用，不改名。

## 附录 F：一个完整的例子

下面三段是同一件事的三侧：文档、定义、读者配置。三段合起来，把正文里讲过的每条规则都用到一次。

### F.1 文档

````markdown
---
contract: 1
---

# 安装

> [!WARNING]
> 这段只在 Emacs 30 及以上可用。

:::card {title="缓存命中" accent=primary}
图片和矢量按页面尺寸缩放，不重新画。

:::columns {columns=2}
:::col
命中时从磁盘读一张图。
:::
:::col
没有命中时画一次。
:::
:::

:::tabs
:::tab {title="Emacs 29"}
用 `image-size` 的旧签名。
:::
:::tab {title="Emacs 30+" selected=true}
直接传 buffer。
:::
:::
:::

:::steps {start=2 list-style=decimal}
:::step {title="定位"}
用 `sample` 抓栈，别先猜。
:::
:::

:::box {text-align=center padding="1lh"}
![一次命中](figures/hit.png)
:::
````

### F.2 定义文件

```elisp
;;; 1. 标题：派生属性、样式值、编号、文字拼接
(etaf-md-define-node 'heading
  :summary "标题，级别由 # 的个数决定"
  :attrs '((level :type number :derived t :default 1))
  :view (lambda (env)
          (etaf-view
           (text :weight (etaf-md-style env :font-weight)
                 :color (etaf-md-token env 'heading)
             (expr (concat (or (etaf-md-style env :prefix) "")
                           (etaf-md-format-number (etaf-md-number env) 'decimal)
                           " "
                           (etaf-md-text env)))))))

;;; 2. 提示：五个名字共用一份画法，靠类型分辨
(defun my-callout-view (env)
  (etaf-view
   (box :padding '((lh 1) (ch 2))
        :background-color (etaf-md-surface env 'raised)
        :color (etaf-md-accent env
                               (pcase (etaf-md-type env)
                                 ('note 'primary)
                                 ('tip 'success)
                                 ('warning 'warning)
                                 ('caution 'danger)
                                 (_ 'important)))
     (expr (etaf-md-render env (etaf-md-children env))))))

(dolist (type '(note tip important warning caution))
  (etaf-md-define-node type
    :name (symbol-name type)
    :summary "提示块"
    :attrs '((title :type string :doc "换掉固定标题"))
    :view #'my-callout-view))

;;; 3. 卡片：文档属性，翻成组件参数
(etaf-md-define-node 'card
  :name "card"
  :contract 1
  :summary "一张带标题的卡片"
  :attrs '((title  :type string :required t      :doc "卡片标题")
           (accent :type accent :default neutral :doc "强调"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
                      :variant (pcase (etaf-md-attr env :accent)
                                 ('warning 'warning)
                                 ('success 'success)
                                 (_ 'default))
             (expr (etaf-md-render env (etaf-md-children env)))))))

;;; 4. 盒子：长度与对齐
(etaf-md-define-node 'box
  :name "box"
  :summary "一块没有标题的底"
  :attrs '((text-align :type align  :default start :doc "内容水平位置")
           (padding    :type length                :doc "内边距")
           (width      :type length                :doc "自身宽度，省略即占满"))
  :view (lambda (env)
          (etaf-view
           (column :width (or (etaf-md-attr env :width) 'stretch)
                   :text-align (etaf-md-attr env :text-align)
                   :padding (if (etaf-md-attr env :padding)
                                (list (etaf-md-attr env :padding))
                              '((lh 0) (ch 0)))
             (expr (etaf-md-render env (etaf-md-children env)))))))

;;; 5. 栏：数量属性、可用宽度、子块
(etaf-md-define-node 'columns
  :name "columns"
  :summary "并排的栏"
  :attrs '((columns :type number :default 2 :doc "栏数"))
  :accepts '((col))
  :view (lambda (env)
          (let* ((cols (etaf-md-children env))
                 (n (max 1 (etaf-md-attr env :columns)))
                 (wide (> (etaf-md-available-width env) 60))
                 (rows (seq-partition cols (if wide n 1))))
                 ;; 行和栏的数量在运行时才知道，DSL 写不出来，用 etaf-node
            (etaf-node 'column
                       (list :item-gap '((lh 1)))
                       (mapcar (lambda (row)
                                 (etaf-node 'row
                                            (list :item-gap '((ch 2)))
                                            (mapcar (lambda (col)
                                                      (etaf-node 'column
                                                                 (list :width 'stretch)
                                                                 (etaf-md-render env
                                                                                 (etaf-md-children env col))))
                                                    row)))
                               rows)))))

;;; 6. 标签页：父类型、子块属性、本块状态
;; 真正接线时把 :on-change 交给组件，里面写
;; (etaf-md-block-state env :current 新值)
(etaf-md-define-node 'tabs
  :name "tabs"
  :summary "标签页"
  :accepts '((tab :attrs ((title    :type string  :required t :doc "标签文字")
                          (selected :type boolean :default false :doc "默认选中"))))
  :view (lambda (env)
          (let* ((tabs (etaf-md-children env))
                 (picked (or (seq-find (lambda (tab) (etaf-md-attr env :selected tab)) tabs)
                             (car tabs)))
                 (current (etaf-md-block-state env :current picked)))
            (etaf-view
             (column :item-gap '((lh 1))
               (text (expr (mapconcat (lambda (tab)
                                    (etaf-md-attr env :title tab))
                                  tabs " │ ")))
               (expr (etaf-md-render env (etaf-md-children env current))))))))

;;; 7. 步骤：数字与 enum
(etaf-md-define-node 'steps
  :name "steps"
  :summary "带编号的步骤"
  :attrs '((start      :type number :default 1       :doc "起始编号")
           (list-style :type enum   :default decimal :one-of (decimal bullet)
                       :doc "记号"))
  :accepts '((step :attrs ((title :type string :required t :doc "这一步的名字"))))
  :view (lambda (env)
          (let ((n (1- (etaf-md-attr env :start)))
                (mark (pcase (etaf-md-attr env :list-style)
                        ('decimal "%d. ")
                        (_ "· "))))
                 ;; 每一项的编号要按顺序算，DSL 写不出来，用 etaf-node
            (etaf-node 'column
                       (list :item-gap '((lh 1)))
                       (mapcar (lambda (step)
                                 (setq n (1+ n))
                                 (etaf-node 'column
                                            nil
                                            (list (etaf-node 'text
                                                             nil
                                                             (list (concat
                                                                    (format mark n)
                                                                    (etaf-md-attr env :title step))))
                                                  (etaf-node 'fragment
                                                             nil
                                                             (etaf-md-render env
                                                                             (etaf-md-children env step))))))
                               (etaf-md-children env))))))
```

### F.3 读者配置

```elisp
;; 1. 改值：选择器写属性名，键来自附录 C 加本类型的可盖属性
(etaf-md-set-style 'heading
  '((:font-weight bold)
    (:level 1 :prefix "◆ ")
    (:level 2 :prefix "◇ " :margin-top "1lh")))
(etaf-md-set-style 'card '((:accent warning)))

;; 2. 换画法：保留内置，外面包一层，顺手加一个读者键
(etaf-md-set-view 'heading
  (lambda (env)
    (etaf-node 'box
               (list :padding '((lh 1) (ch 2))
                     :background-color (etaf-md-surface env
                                                       (etaf-md-style env :background)))
               (list (etaf-md-default-view env))))
  :extends t
  :style-keys '((background :type surface :doc "标题底色")))

;; 3. 整体替换
(etaf-md-set-view 'box (lambda (env) (etaf-md-default-view env)) :replace t)

;; 4. 卸载：回到内置
(etaf-md-set-style 'heading nil)
(etaf-md-set-view 'heading nil)
(etaf-md-define-node 'card :replace t
  :name "card"
  :attrs '((title :type string))
  :view (lambda (env)
          (etaf-view (text (expr (etaf-md-attr env :title))))))
```

### F.4 页面结果

```
◆ 1 安装

  ⚠ 这段只在 Emacs 30 及以上可用。

┌ 缓存命中 ─────────────────────────────┐
│ 图片和矢量按页面尺寸缩放，不重新画。  │
│ ┌ 命中时读一张图 ┐┌ 没命中时画一次 ┐ │
│ └────────────────┘└────────────────┘ │
│ Emacs 29 │ Emacs 30+                  │
│ 直接传 buffer。                       │
│ 2. 定位                               │
│    用 sample 抓栈，别先猜。           │
└───────────────────────────────────────┘

              一次命中
           [figures/hit.png]
```

### F.5 覆盖表

| 知识 | 出现在哪 |
| --- | --- |
| `:name` | 卡片、提示五个名字、栏、标签页、步骤有；标题没有 |
| `:summary` | 每个定义各一行 |
| `:contract` | 卡片的定义，文档 front matter |
| `:attrs` 的 `:default` | 标题的 `level`、卡片的 `accent`、盒子的 `text-align` |
| `:attrs` 的 `:required` | 卡片的 `title`，标签页与步骤的 `title` |
| `:attrs` 的 `:derived` | 标题的 `level` |
| `:attrs` 的 `:pattern` | 附录 A 与 10.2 的例子 |
| `:attrs` 的 `:one-of` | 步骤的 `list-style` |
| `:attrs` 的 `:doc` | 每个属性都有 |
| `:accepts` | 栏收 `col`（无属性），标签页收 `tab`，步骤收 `step` |
| `:view` | 七个定义各一个，签名 `(lambda (env))` |
| DSL 与 `etaf-node` 的分工 | 五个定义用 `etaf-view`；`columns` 与 `steps` 用 `etaf-node`，因为行数、编号要运行时才算 |
| 八种类型 | string（`title`）、number（`columns`、`start`、`level`）、boolean（`selected`）、length（`padding`、`width`）、surface（提示的底）、accent（卡片的强调）、align（`text-align`）、enum（`list-style`） |
| `etaf-md-attr` | 每一处读属性，含读子节点的 `(etaf-md-attr env :title tab)` |
| `etaf-md-type` | 提示的共用画法 |
| `etaf-md-text` | 标题拼「前缀 + 编号 + 正文」 |
| `etaf-md-children` | 每个父类型，含取子节点内容的 `(etaf-md-children env current)` |
| `etaf-md-render` | 每个把子节点画成视图的地方 |
| `etaf-md-default-view` | 读者配置第 2、3 段 |
| `etaf-md-token` | 标题拿 `heading` 色 |
| `etaf-md-surface` | 提示的底、读者包的那层 |
| `etaf-md-accent` | 提示的字色 |
| `etaf-md-style` | 标题的字重与前缀、读者的 `background` |
| `etaf-md-number` + `format-number` | 标题的编号 |
| `etaf-md-block-state` | 标签页读默认值 |
| `etaf-md-available-width` | 栏判断宽窗还是窄窗 |
| 样式选择器 | `(:level 1 …)` |
| `:extends` / `:replace` / 卸载 | 读者配置第 2、3、4 段 |

**这个例子没覆盖 `etaf-md-follow-link`。** 它要把一段可点区域接到 ETAF 的交互接口上，那套属性写在第 7 章，附录不重复一遍。
