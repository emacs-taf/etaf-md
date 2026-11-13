# 图表画廊

预览把一页 Markdown 画成文字页面，图和公式都是页面的一部分：配色跟页面走，缩放时按矢量重画。
这一页是全部图表类型的样本，每种都写真实的用法和不同的参数，方便对照。

## 流程图：形状与分组

每种形状有含义：圆角是开始结束，菱形是判断，圆柱是存储，子程序是调用。
两条分支分别用 `classDef` 上了色，颜色从页面的强调色取。

```mermaid
flowchart TB
  start([收到请求]) --> parse[[解析 Markdown]]
  parse --> cache{缓存命中?}
  cache -->|是| draw[(读取图片)]
  cache -->|否| renderer[调用渲染器]
  renderer --> draw
  draw --> measure[[量出格数]]
  measure --> page{宽度够?}
  page -->|够| place[按原尺寸摆放]
  page -->|不够| shrink[按列宽缩到格子里]
  place --> done([贴到页面])
  shrink --> done

  subgraph 缓存层
    cache
    draw
  end

  classDef hit fill:#1f6feb,stroke:#1f6feb,color:#ffffff
  classDef miss fill:#b42318,stroke:#b42318,color:#ffffff
  class cache,draw hit
  class renderer,measure miss
```

横向排布用于一条主线的流程，节点少的时候比竖排紧凑：

```mermaid
flowchart LR
  src[源文件] --> tokenize[分词] --> ast[语法树] --> layout[排版] --> publish[发布]
  publish -. 主题切换 .-> layout
```

## 时序图：一次主题切换

`autonumber` 给消息编号；`alt`、`opt`、`loop` 表达分支与重复；`activate` 画出演进期。

```mermaid
sequenceDiagram
  autonumber
  actor R as 读者
  participant A as 预览应用
  participant E as ETAF
  participant X as 渲染器

  R->>A: 切换主题
  activate A
  A->>A: 读页面配色
  alt 图片已在缓存
    A->>E: 发布新颜色
  else 需要重画
    A->>X: 请求图片（新配色）
    X-->>A: SVG 与 PNG
    A->>E: 发布图片
  end
  A->>E: 重新排版
  E-->>R: 一页新颜色
  deactivate A
  Note over A,X: 空闲 45 秒后渲染器自己退出
```

## 类图：泛型与关系

继承、组合、聚合、依赖各有一条线；`~T~` 写泛型参数，`{abstract}`、`{static}` 写在成员上。

```mermaid
classDiagram
  direction LR
  class Document {
    <<interface>>
    +blocks() List~Block~
    +publish()
  }
  class MarkdownDocument {
    -String path
    +parse() Document
    +blocks() List~Block~
  }
  class Block {
    <<abstract>>
    +String source
    +render(Env) View
  }
  class PictureBlock {
    +String picture
    +render(Env) View
  }
  class Typeset {
    +draw(kind, source) Picture
  }
  Document <|.. MarkdownDocument
  MarkdownDocument *-- Block
  Block <|-- PictureBlock
  PictureBlock ..> Typeset : 请求
```

## 状态图：复合状态与分叉

`state ... as` 起别名，`<<fork>>`、`<<join>>` 画并行，`--` 分出两条同时进行的路径。

```mermaid
stateDiagram-v2
  [*] --> 空闲
  空闲 --> 解析 : 打开文件
  解析 --> 排版
  state 排版 {
    [*] --> 文本
    文本 --> 图片 : 块里有图
    图片 --> 文本 : 图已就绪
  }
  排版 --> 发布
  state 分叉点 <<fork>>
  发布 --> 分叉点
  分叉点 --> 记缓存
  分叉点 --> 通知窗口
  记缓存 --> [*]
  通知窗口 --> [*]
```

## ER 图：主键与外键

`PK`、`FK` 标出键，`||--o{` 这样的写法表示一对多，注释写在各列后面。

```mermaid
erDiagram
  DOCUMENT ||--o{ BLOCK : contains
  DOCUMENT {
    string path PK
    string title
    datetime opened
  }
  BLOCK {
    int id PK
    int document_id FK
    string kind
    string source
  }
  PICTURE {
    string digest PK
    string path
    int width
    int height
  }
  BLOCK ||--o| PICTURE : draws
```

## 甘特图：里程碑与关键路径

`done`、`active`、`crit` 是任务状态；`milestone` 是零长度节点；`excludes` 跳过周末。

```mermaid
gantt
  title 一次改动的排期
  dateFormat YYYY-MM-DD
  axisFormat %m-%d
  excludes weekends

  section 定位
  复现重影            :done,   a1, 2026-11-06, 2d
  缩小到图片缩放      :done,   a2, after a1, 1d
  section 修复
  改渲染尺寸          :active, b1, 2026-11-09, 2d
  跑四档缩放验收      :crit,   b2, after b1, 2d
  section 收尾
  写进 CHANGELOG      :        c1, after b2, 1d
  交接                :milestone, m1, after c1, 0d
```

## 饼图：带数值

`showData` 把每段的数值写在标签里，适合占比一眼看明白。

```mermaid
pie showData
  title 一页里的内容
  "图片" : 16
  "文本" : 42
  "公式" : 4
  "表格" : 2
```

## 需求图：验证与满足

`requirement` 写需求，`element` 写实现，`satisfies`、`verifies` 连起来。

```mermaid
requirementDiagram
  requirement fast {
    id: 1
    text: "一页十六张图在四百毫秒内出齐"
    risk: medium
    verifymethod: test
  }
  requirement crisp {
    id: 2
    text: "任何缩放档位下文字都清晰"
    risk: low
    verifymethod: inspection
  }
  element renderer {
    type: module
  }
  element matrix {
    type: script
  }
  renderer - satisfies -> fast
  matrix - verifies -> fast
  renderer - satisfies -> crisp
```

## Git 图：分支与补丁

`branch`、`checkout`、`merge`、`cherry-pick` 各画一种线；`tag` 标版本。

```mermaid
gitGraph
  commit id: "起点"
  commit id: "读配色" tag: "v1"
  branch fix
  checkout fix
  commit id: "修缩放"
  commit id: "补检查"
  checkout main
  commit id: "写文档"
  merge fix id: "合并" tag: "v2"
  commit id: "补例子"
  cherry-pick id: "补检查"
```

## 旅程图：一段使用过程

`section` 分区，每行是「任务: 分数: 角色」，分数决定曲线的起伏。

```mermaid
journey
  title 打开一篇带图的文档
  section 打开
    找到文档: 5: 读者
    等第一屏: 3: 读者
  section 阅读
    看图: 5: 读者
    跟着源码对照: 4: 读者
  section 调整
    放大看细节: 4: 读者
    切主题: 5: 读者
```

## 思维导图：形状与图标

根节点用圆形，第二层用不同形状区分职责，`::icon` 挂图标。

```mermaid
mindmap
  root((预览))
    输入
      文件((Markdown))
      链接[网页]
      粘贴(剪贴板)
    排版
      文本
      表格
      公式
      图表
    输出
      页面((文字页面))
      图片
      链接(可跳转)
```

## 时间线：按年份分组

`section` 分期，`时间 : 事件 : 事件` 一行可以写多条。

```mermaid
timeline
  title 渲染器走过的几步
  section 2026 秋
    十月 : 每张图各起一个浏览器
         : 冷启动四秒
    十一月 : 常驻渲染器
           : 十六张图四百毫秒
  section 现在
    十一月 : 矢量副本
           : 缩放不重画
```

## 象限图：两个维度

`x-axis`、`y-axis` 给范围和两端名称，四个 `quadrant` 写判断，点用 `[x, y]` 定位。

```mermaid
quadrantChart
  title 该先做哪件事
  x-axis 影响小 --> 影响大
  y-axis 成本低 --> 成本高
  quadrant-1 想清楚再做
  quadrant-2 值得投入
  quadrant-3 顺手做掉
  quadrant-4 先放着
  修重影: [0.92, 0.35]
  补图表类型: [0.62, 0.28]
  换字体: [0.25, 0.7]
  做动画: [0.3, 0.85]
```

## 桑基图：能量的去向

第一列写来源，第二列写去向，第三个数是量；同一节点自动汇总。
节点名要用拉丁字母，mermaid 的桑基图只接受这种名字。

```mermaid
sankey-beta
Solar,Grid,120
Solar,Homes,80
Wind,Grid,90
Wind,Homes,40
Grid,Industry,150
Grid,Homes,60
Homes,Charging,90
```

## XY 图：柱与线

柱和线是两个序列，各取一种颜色；`x-axis` 写分类，`y-axis` 写范围和单位。

```mermaid
xychart-beta
  title "每月的图"
  x-axis ["七月", "八月", "九月", "十月", "十一月", "十二月"]
  y-axis "张" 0 --> 40
  bar [4, 9, 12, 21, 28, 36]
  line [3, 7, 11, 19, 27, 34]
```

## 块图：按列摆

`columns` 定列数，`块:2` 占两列，`space` 留空，箭头画出数据流向。

```mermaid
block-beta
  columns 4
  source["源文件"]:2  theme["主题"]:2
  space:4
  parse["解析"]:2  paint["配色"]:2
  space:4
  page["一页"]:4
  source --> parse
  theme --> paint
  parse --> page
  paint --> page
```

## 数据包图：字段与位宽

`起-止: "名称"` 给每个字段的位置，宽度自然就是字段的位数。

```mermaid
packet-beta
  0-15: "源端口"
  16-31: "目的端口"
  32-63: "序号"
  64-95: "确认号"
  96-99: "首部长度"
  100-105: "保留"
  106-111: "标志位"
  112-127: "窗口"
  128-159: "校验和与紧急指针"
```

## 看板：三列状态

列名写在方括号里，卡片可以带负责人与优先级。

```mermaid
kanban
  待办
    t1["补齐图表类型"]
    t2["写这一页"]
  进行中
    t3["修图片缩放"]
  已完成
    t4["渲染器常驻"]
    t5["矢量副本"]
```

## 架构图：分组与服务

`group` 画边界，`service` 写服务，`in` 表示属于哪个组，`A:R -- L:B` 连两个端口。

```mermaid
architecture-beta
  group app(cloud)[预览应用]
  service page(server)[页面] in app
  service typeset(server)[排版] in app
  service cache(database)[缓存] in app
  group draw(cloud)[渲染]
  service chromium(server)[Chromium] in draw
  page:R -- L:typeset
  typeset:R -- L:cache
  typeset:B -- T:chromium
```

## 雷达图：两组对比

`axis` 定维度，`curve` 给每组打分；两个序列用两种颜色，填充半透明。

```mermaid
radar-beta
  title 预览的几个方面
  axis speed["速度"], sharp["清晰"], steady["稳定"], cost["成本"]
  curve now["当前"]{9, 9, 8, 6}
  curve goal["目标"]{9, 10, 9, 8}
```

## 矩形树图：面积即数量

嵌套一层就是分组，数值决定面积，标签自动缩放。

```mermaid
treemap-beta
"一页的内容"
    "正文": 42
    "图表": 16
    "公式": 4
    "表格": 2
    "代码": 6
```

## C4：系统上下文

`Person`、`System`、`System_Ext` 画角色与系统，`Rel` 写关系，`Boundary` 圈出边界。

```mermaid
C4Context
  title 预览在系统里的位置
  Person(reader, "读者", "读文档的人")
  Boundary(app, "预览应用") {
    System(preview, "Markdown 预览", "把源码画成页面")
    System(renderer, "渲染器", "把图与公式画成图片")
  }
  System_Ext(editor, "编辑器", "改源码")
  Rel(reader, preview, "阅读")
  Rel(editor, preview, "保存后刷新")
  Rel(preview, renderer, "请求图片")
```

## 公式：行内与独立

行内公式跟着句子走，例如页面宽度按 $w = \lceil p / c \rceil$ 换算成格数，其中 $p$ 是像素宽，$c$ 是字符宽。
独立公式单独成行，居中，上下留一行空白。

$$
\text{行高} = \max_{g \in G}\bigl(\text{ascent}(g) + \text{descent}(g)\bigr)
$$

矩阵与分段函数：

$$
A = \begin{pmatrix}
a_{11} & a_{12} & a_{13} \\
a_{21} & a_{22} & a_{23} \\
a_{31} & a_{32} & a_{33}
\end{pmatrix},
\qquad
f(x) = \begin{cases}
x^2, & x \ge 0, \\
-x, & x < 0.
\end{cases}
$$

求和、极限与偏导写在一行里也不挤：

$$
\sum_{i=1}^{n} \frac{1}{i^2} = \frac{\pi^2}{6},
\qquad
\lim_{h \to 0} \frac{f(x+h) - f(x)}{h} = \frac{\partial f}{\partial x}
$$

## 表格与提示块

| 图表 | 参数 | 用在哪 |
| --- | --- | --- |
| 流程图 | `classDef`、子图 | 流程、调用链 |
| 时序图 | `autonumber`、`alt` | 交互过程 |
| 甘特图 | `done`、`crit` | 排期 |
| 象限图 | 轴范围、点坐标 | 取舍 |

> [!NOTE]
> 图里的颜色都来自页面：切到亮色、暗色或 sepia，图上每个字仍然清楚。

> [!WARNING]
> 语法错的块不会被记成永久失败，改对源码就会重新画。

## 代码、引用与清单

```elisp
(defun etaf-md-preview--typeset-grid (path max-columns)
  "Return the (COLUMNS . ROWS) grid for the picture at PATH."
  (cons (min max-columns (round (/ (car (etaf-md-preview--image-pixels path))
                                   (float (car (etaf-md-preview--cell-metrics))))))
        nil))
```

> 图片的纵向几何只有一个所有者，就是 Emacs 的排版结果。

- [x] 十几种图在三种配色下都能读
- [x] 切换缩放不重画矢量
- [ ] 图表在窄窗口里自动缩到列宽
