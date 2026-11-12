# 图表场景

这一页把预览支持的十四种 mermaid 图各画一遍，用的是接近真实的复杂度：多个参与者、多层结构、多种关系。源码就是围栏里的内容，改一行，图跟着变。

## 流程图

```mermaid
flowchart TD
  subgraph 输入
    A[打开文件] --> B{读得出来吗}
    B -- 读不出 --> E[显示错误]
    B -- 读得出 --> C[解析成块]
  end
  subgraph 渲染
    C --> D[建立会话]
    D --> F[生成视图]
    F --> G[画进缓冲区]
  end
  G --> H{窗口够宽吗}
  H -- 不够 --> I[横向裁切]
  H -- 够 --> J[保持阅读栏]
  I --> K[滚轮看全]
  J --> K
```

## 菱形判断

```mermaid
flowchart LR
  S([开始]) --> Q1{文件在本地}
  Q1 -- 是 --> Q2{图片缓存命中}
  Q1 -- 否 --> X[显示占位卡]
  Q2 -- 是 --> D[直接画图]
  Q2 -- 否 --> R[起外部程序]
  R --> Q3{画成功吗}
  Q3 -- 成功 --> D
  Q3 -- 失败 --> SRC[保留源码]
```

## 时序图

```mermaid
sequenceDiagram
  participant 读者
  participant 预览
  participant 渲染器
  读者->>预览: 打开文件
  预览->>渲染器: 解析源码
  loop 每个图片块
    预览->>渲染器: 起外部程序
    渲染器-->>预览: 写回图片
  end
  alt 全部就绪
    预览-->>读者: 一次画出整页
  else 有块失败
    预览-->>读者: 失败的块留源码
  end
  Note over 预览,渲染器: 图片按内容和配色寻址缓存
  读者->>预览: 改一行源码
  预览->>预览: 只重画那一块
```

## 状态图

```mermaid
stateDiagram-v2
  direction LR
  [*] --> 空闲
  空闲 --> 渲染中: 打开或改动
  state 渲染中 {
    [*] --> 解析
    解析 --> 画页
    画页 --> 等图片
    等图片 --> 画页: 图片到达
    等图片 --> 画页: 外部程序失败
  }
  渲染中 --> 空闲: 关闭
  渲染中 --> 出错: 解析失败
  出错 --> 渲染中: 改对文件
  出错 --> [*]: 放弃
```

## 类图

```mermaid
classDiagram
  direction LR
  class 会话 {
    +String 文件
    +Symbol 主题
    +Number 阅读栏宽
    +打开()
    +刷新()
    +关闭()
  }
  class 文档 {
    +List 块
    +List 大纲
    +List 脚注
    +标题()
  }
  class 块 {
    +Symbol 类型
    +String 文本
    +Number 行号
    +画()
  }
  class 视图 {
    +画页面()
    +测高()
  }
  class 图片视图 {
    +String 路径
    +Number 列数
    +Number 行数
  }
  会话 *-- 文档 : 持有
  文档 *-- 块 : 包含
  会话 --> 视图 : 生成
  视图 <|-- 图片视图
  块 ..> 视图 : 转成
```

## 实体关系图

```mermaid
erDiagram
  direction LR
  会话 ||--|| 文档 : 持有
  文档 ||--o{ 块 : 包含
  块 }o--o| 图片 : 引用
  会话 {
    string 文件
    string 主题
    int 阅读栏宽
  }
  文档 {
    string 标题
    int 块数
  }
  块 {
    string 类型
    string 文本
    int 行号
  }
  图片 {
    string 路径
    int 宽
    int 高
  }
```

## 需求图

```mermaid
requirementDiagram
  requirement open {
  id: 1
  text: "一秒内看到第一页"
  risk: high
  verifymethod: test
  }
  requirement picture {
  id: 2
  text: "图片画在离屏进程里"
  risk: medium
  verifymethod: inspection
  }
  requirement theme {
  id: 3
  text: "换主题不重开文件"
  risk: low
  verifymethod: analysis
  }
  element preview {
  type: simulation
  }
  element typeset {
  type: compilation
  }
  open - satisfies -> preview
  picture - satisfies -> typeset
  theme - derives -> picture
  preview - contains -> typeset
```

## 饼图

```mermaid
pie showData title 文档里的块类型
  "段落" : 148
  "代码" : 36
  "表格" : 12
  "列表" : 9
  "公式" : 5
  "图片" : 3
```

## 甘特图

```mermaid
gantt
  title 一次改版的排期
  dateFormat YYYY-MM-DD
  axisFormat %m-%d
  section 设计
    画版式 :done, d1, 2026-01-05, 4d
    定配色 :done, d2, after d1, 3d
  section 实现
    排版引擎 :a1, after d2, 8d
    图片管线 :a2, after d2, 6d
    交互动效 :a3, after a1, 4d
  section 验收
    宽窗口 :v1, after a3, 2d
    窄窗口 :v2, after v1, 1d
    发布 :milestone, m1, after v2, 0d
```

## 用户旅程图

```mermaid
journey
  title 读者的一天
  section 早上
    打开文件: 5: 读者
    扫一眼大纲: 4: 读者
    读正文: 4: 读者
  section 下午
    改一段源码: 3: 读者
    看页面重画: 4: 读者
    翻到脚注: 3: 读者
  section 晚上
    换暗色主题: 4: 读者
    关掉预览: 5: 读者
```

## 思维导图

```mermaid
mindmap
  root((预览11))
    输入
      文件
      Markdown 源码
      剪贴板
    渲染
      块
        段落
        代码
        表格
        公式
        图片
      行内
        粗斜体
        链接
        脚注
    交互
      键盘
        搜索
        大纲跳转
        跟随滚动
      鼠标
        点链接
        点图片
    外观
      主题
      阅读栏
      窄窗口
```

## 版本图

```mermaid
gitGraph
  commit id: "起步" tag: "v0.1"
  commit id: "解析"
  branch typeset
  checkout typeset
  commit id: "视图"
  commit id: "管线"
  checkout main
  merge typeset id: "合并" tag: "v0.2"
  branch theme
  checkout theme
  commit id: "暗色"
  checkout main
  merge theme id: "主题"
  commit id: "滚动"
```

## 象限图

```mermaid
quadrantChart
  title 功能取舍
  x-axis 做得少 --> 做得多
  y-axis 用得少 --> 经常用
  跟随滚动: [0.25, 0.8]
  块内编辑: [0.6, 0.55]
  打印样式: [0.8, 0.2]
  导出 PDF: [0.9, 0.35]
  搜索: [0.35, 0.75]
  脚注跳转: [0.3, 0.5]
```

## 时间线

```mermaid
timeline
  title 版本演进
  2024 : 第一版渲染器
       : 只画标题和段落
  2025 : 块视图
       : 表格与代码
       : 图片与视频
  2026 : 公式与图表
       : 跟随滚动
       : 宽窗口与窄窗口都验收
```

## 自定义配色

图里可以自己给颜色，用 init 指令覆盖默认配色：

```mermaid
%%{init: {"themeVariables": {"mainBkg": "#ff00aa", "primaryTextColor": "#ffffff"}}}%%
flowchart LR
  A[指令给底色] --> B[节点]
  B --> C[连线]
```

写在源码开头的 front matter 也一样：

```mermaid
---
config:
  themeVariables:
    mainBkg: "#00aaff"
    primaryTextColor: "#ffffff"
---
flowchart LR
  A[本文给底色] --> B[节点]
  B --> C[连线]
```

这两种写法都优先于预览自己的配色，所以一页里可以有几块不同样子的图。
