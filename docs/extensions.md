# Extension syntax

> **Status.** The only extension the page renders today is the GitHub alert block: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`. Everything else here is a design contract: it fixes the model, the syntax, the attributes and the acceptance before the code exists. Any name marked *planned* does not exist today, and its function names are proposals.
>
> **How to read it.** Writing a document: chapters 3, 5 and 6. Writing a container definition: chapters 9 and 10. Implementing the renderer: chapters 2, 7, 8 and 11. What works today: the status table in 6.16.
>
> The Chinese and English versions run section for section. Change one, change the other.

## 1. Place

### 1.1 What this package does

One thing: turn a Markdown document into ETAF views inside a buffer, for reading. The input is text; the output is boxes, text and faces on a character grid.

It ships a container vocabulary so a document can express structures plain Markdown cannot: callouts, cards, steps, tabs, timelines. The vocabulary is closed; a user can add to it through the seam in chapter 10, but a document cannot define anything itself.

### 1.2 The boundary: documents and pages

Pages, directories, routes, navigation, data sources and publishing are things this package knows nothing about. They belong to an application above it.

That application owns its page model, its layout registry, its outline tree, its site navigation and its data. It requires this package's root entry and calls only the public interfaces. Nothing here grows a switch or a parameter for that layer's policy.

The seam has one place: a document becomes a view. That interface does not exist yet; what is public today is creating a session, opening, closing, navigating, reading state and reporting capability. When the application needs to embed a rendered document, this package adds two entries: one returns a view for a text or a file that can be mounted in any region, and one registers a container. Both are planned.

The package also emits no HTML. It paints a buffer. Serving a page to a browser is the application's own backend.

One confusion is worth pinning down: `columns` in chapter 5 is **a column inside a document**, deciding how a passage is laid out. A page's layout is a name in the application's registry, and it is out of scope here.

### 1.3 The reference and the distance from it

The design refers to `vuepress-theme-plume`. Its Markdown extensions live in `plugins/plugin-md-power/`, and the real structure is three things.

- **One container factory**, in `src/node/container/createContainer.ts`. It exposes `createContainerPlugin` and `createContainerSyntaxPlugin`; the first parses content as Markdown, the second handles content itself.
- **One registry**, in `src/node/container/index.ts`. It installs about twenty presets: `align`, `tabs`, `code-tabs`, `window`, `steps`, `card`, `card-grid`, `card-masonry`, `encrypt`, `npm-to`, `lang-repl`, `file-tree`, `code-tree`, `timeline`, `collapse`, `chat`, `field`, `table`.
- **About thirty client components**, among them `VPCodeTabs`, `VPTabs`, `VPCollapse`, `VPField`, `VPTimeline`, `VPCodeTree`, `VPTable`, `VPPlot`, `VPAnnotation`, `VPQRCode`, `VPPdf`, `VPArtPlayer`, `VPCodePen`, `VPCodeSandbox`, `VPCard`, `VPCardGrid`, `VPCaniuse`.

Copying it will not work. Three hard differences.

1. **The output differs.** Plume emits HTML, Vue components and CSS. We emit boxes, text and faces on a character grid. A container that lands in a buffer is a run of characters carrying text properties.
2. **The expression differs.** CSS has arbitrary lengths, absolute positioning, gradients, rounded corners, shadows and animation. A character grid has line height, character width, borders, fills, weight and underlines, plus box-drawing characters.
3. **The runtime differs.** A plume page carries client-side scripts. Our page is a plain-text result: a reader has to find it with isearch, copy it with `C-w`, export it through org, and read it in a terminal.

Copying shows immediately. A card's rounded corners and shadow become garbled glyphs, a tab strip's sliding animation becomes a repaint per frame, and a chat avatar becomes a missing-glyph box.

Two things are worth taking, and neither is an implementation.

1. **The container factory.** Twenty effects sharing two factory functions means the shape of a definition converged. We keep that shape, but the render hook returns an ETAF view.
2. **The effect inventory.** What plume solved is a requirement list. Ask of each one what it looks like on a character grid. What the grid can express gets absorbed; what it cannot gets declined, with the reason in Appendix D.

## 2. Model

### 2.1 Blocks, containers, parents

A document is a sequence of blocks. A block can be a paragraph, a heading, a list, a code block, a table, or a container.

A container has a name, attributes and content. Its content is parsed blocks, not a string and not HTML. So a container holds anything the page holds, including other containers.

The parser knows three things: opening, closing and nesting. It does not know what `tab` means, nor which attributes `card` takes. The registry owns the names, the definitions own the attributes, and the renderer owns the placement.

### 2.2 Three kinds of container

A writer sees one shape, but the system has three roles. A definition must declare which one it is.

| Role | Content | Examples | Rule |
| --- | --- | --- | --- |
| Block | Any blocks | `note`, `card`, `box`, `table` | Appears anywhere a paragraph may |
| Parent | Only the children it declares | `columns`, `tabs`, `steps` | A child name is valid only inside it |
| Child | Meaningless without a parent | `col`, `tab`, `step`, `item` | Outside its parent it is an error, never a guess |

One rule connects the three: **a child name is interpreted by its parent, and the parser does not recognise it.** So `:::tab` inside `tabs` is a tab, and `:::tab` at the top of a page is a line nothing can explain, reported by the failure rule.

The relationship does not cross layers. A `tab` may hold a `card`, but a `tab` may not hold another `tab`. To nest, wrap another `tabs`.

### 2.3 Four extension points

The system has four layers, each with different rights.

| Layer | Decided by | Changes | Open? |
| --- | --- | --- | --- |
| Syntax | The package's parser | How text becomes nodes | No |
| Structure | The document and container definitions | A new kind of block, the attributes it takes | Yes, chapter 10 |
| Appearance | The reader's style table | Colours, weight, prefixes, spacing, numbering | Yes, 4.3 |
| Rendering | The reader's functions | What one node is painted as | Yes, 10.4 |

The four share one node model: `(type attributes children origin)`. A built-in node and a container node are the same shape in that table: `heading` is a node whose type is heading and which carries `:level`; `card` is a node whose type is card and which carries `:title`.

One more thing: **a definition can itself be overridden.** A reader may add keys to a type, replace its rendering, or replace the whole definition. Added keys are reader-side only; the document-side attribute table stays closed; see 10.5.

### 2.4 The pipeline

```
text → parse → node tree → derive → render → views
```

- **Parse**: closed. It calls the shared `etaf-ui-markdown-parse`, and nothing here changes it.
- **Derive**: computed once for the whole document. Heading numbers, table numbers, anchors and each block's display identity live here.
- **Render**: per block. Style and render functions take effect in this step.

Why derive is its own step. A block repaints alone, but a number depends on the whole document. Inside rendering, repainting one block would recompute the document; inside parsing, a display decision would leak into the syntax layer.

Two derive rules.

- **Anchors come from the source, never from displayed text.** A heading's `◆` prefix is a display fact. Changing it must not break someone's saved `#install` link.
- **Numbers are computed only when the style asks for them.** With numbering off, the step is skipped.

### 2.5 Nine invariants

Every new container has to satisfy all nine. Miss one and it does not belong in the registry.

| Invariant | Test |
| --- | --- |
| One syntax | A new effect adds a name, never punctuation. No second block marker |
| One content model | Content is blocks, not strings, not HTML. A container never changes parsing |
| One attribute set | Attribute names and meanings come from one shared vocabulary; a container selects, never invents a synonym |
| One layout set | Placement uses `box`, `columns` and the shared spacing attributes only |
| One appearance source | Colours come from surface and accent; type size comes from the reader |
| One failure rule | A bad block keeps its source plus one line, and the page keeps rendering |
| State belongs to the renderer | A document states no behaviour; interaction is implemented by the container definition |
| One render path | Built-in nodes, container nodes and reader styles go through one table, and the code has no branch on a name |
| One definition boundary | A definition only declares, validates and translates; a reusable shell or interaction belongs to a component, see chapter 9 |

## 3. Syntax

### 3.1 Opening and closing

````markdown
:::card {title="Cache hit" surface=panel}
The image and the formula are each drawn once and scaled to the page.

- A hit reads the file
- A miss draws once
:::
````

| Rule | Meaning |
| --- | --- |
| Name | Lowercase letters, digits and hyphens: `card`, `code-tabs` |
| Attributes | `key=value` inside braces, space separated; omit the braces when there are none |
| Closing | One line of three colons, no name; it closes the innermost open container |
| Nesting | Nest directly; inner and outer both use three colons, and depth is not counted in colons |
| Depth | Eight levels at most. The ninth is an error, not a render |
| Empty | Allowed. It renders a title row or an empty slot, and that is not an error |
| Line start | `:::` occupies its own line, preceded by whitespace only |

There is one spelling for closing, so there is one reading: **close the innermost open container.** No counting, no name matching, so nothing can fail to match.

Nesting needs no extra colons, and that includes a container of the same name:

````markdown
:::card {title="Outside"}
:::card {title="Inside"}
Content
:::
:::
````

The two `:::` lines are last-in-first-out: inside closes first, outside second. Extra colons or name matching would bring a second rule, and a second rule only adds a second way to get it wrong.

The depth limit is eight rather than unbounded. Every level is a box, and a reader in a narrow window loses track of which level they are in; every level also costs one measurement and one reflow. The limit pins the worst case.

One cost is worth stating: **a child with no content still needs its own closing line.** A `:::stat` that carries only attributes is written on two lines. That is what one closing rule costs; a spelling that saves the line would require the parser to know names, and it does not.

### 3.2 Children and parents

A child is written exactly like a container; only its name is interpreted by the parent. The parent decides which children it takes and which attributes apply to them.

````markdown
:::columns {tracks="2fr 1fr" gap="2ch"}
:::col
The left column is ordinary Markdown.
:::
:::col
So is the right one.
:::
:::
````

A parent must handle three edge cases without crashing or painting half a block.

- **No children**: paint the container's own empty state, no error.
- **Children out of order**: interpret them in source order, never reorder.
- **A child missing a required attribute**: that child degrades; the others still render.

### 3.3 Attributes

Eight types. The first six are general types; `surface` and `accent` are two fixed word lists.

| Type | Spelling | Meaning | Invalid |
| --- | --- | --- | --- |
| `string` | `title="Cache hit"` | Text. Quote it when it contains spaces; `\"` escapes a quote | `title=cache hit` |
| `number` | `start=2` | Integer or decimal, optionally signed | `start=two` |
| `bool` | `open=true` | `true` or `false`, nothing else | `open=yes` |
| `length` | `gap="2ch"` | A number with a unit: `ch`, `lh`, `px`, `%` | `gap=2` |
| `surface` | `surface=panel` | Fill: `none`, `panel`, `quote`, `sunken`, `page` | `surface="#24262a"` |
| `accent` | `accent=warn` | Emphasis: `neutral`, `info`, `ok`, `warn`, `danger`, `important` | `accent=urgent` |
| `enum` | `items=center` | One of the words the definition lists | `items=middle` |
| `regex` | `id="^[a-z]+$"` | A value matching the pattern | `id="A-1"` |

Four conventions.

- **Attribute names are shared.** `title` means the same in a card, a callout, a collapse and a demo window. A container selects from the vocabulary and never invents `heading` or `caption`.
- **One name, one type.** `cols` is always a number (equal columns); proportions go in `tracks`. The same name changing type between containers is forbidden.
- **No unit, no length.** `gap=2` is wrong and `gap="2ch"` is right. One bare number could mean characters, lines or pixels, and guessing wrong mislays the layout once per guess.
- **Booleans accept neither `yes` nor `1` nor `on`.** Only `true` and `false`. Three spellings mean three parse branches.

Writing the same attribute twice is an error, not a last-one-wins. The reason: a duplicate usually means the author changed half of it, and silently picking one hides the problem.

Attributes come in two classes, and a definition marks them.

| Class | Who decides the value | Examples |
| --- | --- | --- |
| Content | The document. A reader cannot change it | `title`, `label`, `href` |
| Appearance | The document gives the default; the reader's style table may override | `surface`, `accent`, `align` |

An appearance attribute says `:appearance t` in the definition; see 10.2. That keeps "which attributes are appearance" in one place instead of a second list.

The shared attribute table is Appendix A; containers only reference it. How a definition declares these types is 10.2.

### 3.4 Validation, degradation and the failure catalogue

Validation runs once, before a view is built, and reports every error in the block together. An error is a muted line above the block's source, numbered by the line that opened the container.

````markdown
:::card {title="Cache hit" colour=blue surface="#24262a"}
Content
:::
````

```
line 42: card does not take "colour"; it takes title, description, surface, accent, href, align, width
line 42: card received surface="#24262a"; it takes none, panel, quote, sunken, page
line 44: nesting depth 9 exceeds the limit of 8
```

Failures come in twelve kinds. Each has a determined page result; none is "it depends".

| Case | Page | Scope |
| --- | --- | --- |
| Unknown name | Source plus one line | This block |
| Unknown attribute | Source, and the line lists what it takes | This block |
| Invalid value | Source, and the line gives the value and one valid example | This block |
| Missing required attribute | Source, and the line names it | This block |
| Duplicate attribute | Source, and the line names the duplicate | This block |
| Child outside its parent | Source, and the line names the parent | This block |
| Child missing a required attribute | Source; the parent keeps parsing the rest | This child |
| Parent without children | Empty state, no error | This block |
| Nesting beyond eight | Source, and the line gives the depth | This block |
| Unclosed at end of file | Content still renders; one line at the end names the opening line | End of page |
| Definition signals | Source, and the line names the definition and its error | This block |
| Contract version mismatch | Source, and the line names the required version | This block |

Three general rules.

1. **No dialog.** The error is part of the page, not an Emacs error. A file with ten mistakes would otherwise interrupt ten times.
2. **No whole-page failure.** Only the failing block degrades; the rest renders.
3. **One line per error.** Several errors in one block each take a line, ordered by the definition's declaration order.

Error text follows the page language. A Chinese page answers in Chinese, an English page in English, through the same label mechanism the callout titles use.

### 3.5 Unclosed containers and recovery

A container still open at the end of the file is treated as closed there: its content renders, and one line at the end of the page names the line that opened it.

````markdown
:::card {title="Missing its closing line"}
This is still body text.

## The heading below still counts
````

The choice favours the reader. Turning the block into source makes the preview look broken; swallowing half a document is much worse than one extra line, and the author would also have a harder time finding it.

## 4. Appearance and style

### 4.1 Surface and accent

Appearance has two attributes: `surface` for the fill, `accent` for the accent colour. They are separate words because they are separate things. None of `accent`'s values is itself called `accent`; `info` is the one that means "use the accent token". An attribute name and a token name are two namespaces; do not mix them.

| `surface` | Fill | Used for |
| --- | --- | --- |
| `none` | No fill | Default. Cards in prose, blocks side by side |
| `panel` | `panel` token | Code blocks, cards that need a boundary |
| `quote` | `quote-bg` token | Quotation-like blocks |
| `sunken` | `panel2` token | Table headers, secondary information |
| `page` | `bg` token | Places that must separate from the prose |

| `accent` | Foreground | Soft fill | Meaning |
| --- | --- | --- | --- |
| `neutral` | `ink` | `panel` | No accent |
| `info` | `accent` | `accent-soft` | Note, information |
| `ok` | `ok` | `ok-soft` | Success, advice |
| `warn` | `warn` | `warn-soft` | Caution |
| `danger` | `danger` | `danger-soft` | Danger |
| `important` | `important` | `important-soft` | Important |

Tone changes the accent colour and the soft fill only. It never changes type size, weight or line height. For stronger emphasis, change the accent, do not stack effects.

### 4.2 Tokens

A token is a name inside the renderer. A document writes `surface=panel`, never the `panel` token, and certainly never a colour value.

| Token | Use |
| --- | --- |
| `bg` | Page background |
| `ink` | Body text |
| `muted` | Secondary text and notes |
| `faint` | The weakest layer: numbering, separators |
| `accent` / `accent-soft` | Informational |
| `panel` / `panel2` | Surfaces |
| `border` | Borders and rules |
| `quote-bg` / `quote-bar` | Quotes |
| `table-header` / `table-stripe` | Tables |
| `heading` | Headings |
| `ok` / `ok-soft` | Success |
| `warn` / `warn-soft` | Caution |
| `danger` / `danger-soft` | Danger |
| `important` / `important-soft` | Important |

Every token has a value in all three palettes, and the face-derived mode computes them from the active frame. A container declares a surface and a accent, and follows the palette when it changes.

**Why no hexadecimal.** A `#24262a` that looks right on a dark page is a black blot on a paper-coloured one. A hexadecimal value is an error, and the error line lists the semantic words that attribute accepts.

### 4.3 The style table

The style table is where a reader changes appearance. One table, keyed by node type.

```elisp
(setq etaf-md-styles
      '((heading . ((:weight bold :color heading)        ; every level
                    (:level 1 :color accent :scale 2.0 :prefix "◆ ")
                    (:level 2 :prefix "◇ ")
                    (:level 6 :weight normal :color muted)))
        (quote   . ((:surface quote-bg :accent neutral :bar-width "3px" :slant italic)))
        (code    . ((:surface panel :tag-color muted)))
        (table   . ((:header-surface table-header :stripe-surface table-stripe)))
        (strong  . ((:weight bold)))
        (em      . ((:slant italic)))
        (link    . ((:color accent :underline t)))
        (callout . ((:accent-colors ((neutral . ink) (info . accent)
                                   (ok . ok) (warn . warn)
                                   (danger . danger) (important . important)))))))
```

Colours have two names plus one naming rule.

| Key | Type | Meaning |
| --- | --- | --- |
| `surface` | A surface, or a colour value | Fill |
| `color` | A token, or a colour value | Ink |
| `<part>-surface` | A surface, or a colour value | A part's fill, e.g. `header-surface` |
| `<part>-color` | A token, or a colour value | A part's ink, e.g. `tag-color` |

Four rules.

- **Omitted inherits, `nil` disables, `:default` resets to the shipped value.** Three answers to "how do I undo this". `(:level 1 :prefix nil)` drops the level-1 prefix; deleting `:prefix` entirely inherits it from the node entry; `:color :default` goes back to the shipped colour whatever the node entry said.
- **The node entry matches first, the level entry second.** `heading`'s `:level 1` lands on the node entry, so level 1 ends up as `:weight bold :color accent :scale 2.0 :prefix "◆ "`.
- **Every key has one type.** An unknown key is an error at load; that node type falls back to the shipped style and the page still renders.
- **The shipped styles live in this table too.** No literal colour values in the code, so what you change and what you see are the same thing.

`etaf-md-define-style` writes into this same table, not a second one. When a key is written in both places, the later one wins.

Editing the table repaints the page and re-derives it, but never re-parses it; see 8.2. The keys here are the shipped vocabulary; giving a type a new key takes a render function, see 10.4.

### 4.4 Two colour rights

| Who | May write | Why |
| --- | --- | --- |
| The document | Semantic words such as `surface=panel`, `accent=warn` | A document has to read on any theme and any machine |
| The reader's style | A surface or token name, or a literal `"#ff0000"` | The reader owns their page |

A literal has a cost: it stops following the theme. A blue chosen on a dark page may be unreadable on a paper-coloured one. So a document never writes a literal, and that is a hard rule.

An appearance attribute has a second direction: **the document's value is the default, the reader's value wins.** Only attributes declared as appearance (`:appearance t`) get that treatment; a content attribute listens to the document alone, and a reader's value has no effect.

### 4.5 Type size and measures

A document has no size attribute and no equivalent. A container and the body always share one size.

The reader's style table has `:scale`, a **multiple** of the reader's base size, never a point size. `1.0` is body text; a level-1 heading defaults to `2.0`, level 2 to `1.5`. On another machine the size changes and the ratio does not.

Scaling makes that block taller, so the block flow uses each block's real height and never assumes one row. Without scaling, hierarchy comes from weight, colour, a prefix, a rule or a fill.

Two counter-examples. A `size=large` card occupies three rows at 12-point and five at 20-point, so the same document lays out differently on two machines. A table squeezed to 80% makes its text smaller than the body, and the reader concludes they zoomed the page.

### 4.6 Decoration characters

Decoration uses ASCII and box-drawing characters only. No emoji, no variation selectors.

The allowed set: `-`, `=`, `|`, `+`, `*`, `` ` ``, `.`, `o`, plus `─│┌┐└┘├┤┬┴┼`.

The reason: every character in that set occupies one cell in a monospace font. An emoji's width is decided by the font, so it may take one cell or two, and may become a box when the glyph is missing; a variation selector (U+FE0E) can raise the whole line and clip the bottom row.

Box-drawing characters are for trees and tables only, not for card borders. The renderer draws card borders; there is no "border character" attribute.

## 5. Layout

### 5.1 One structural container

There is one way to make columns: `columns`. The former `layout`, `flex` and `card-grid` merge into it, because their differences were only defaults.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cols` | number | none | Equal columns. Ignored when `tracks` is present |
| `tracks` | string | none | A track list, space separated, in `fr`, `ch` or `%` |
| `gap` | length | `"2ch"` | Space between columns |
| `pad` | length | none | Padding on all four sides |
| `min` | length | `"24ch"` | Smallest column; below it the columns stack |
| `items` | enum | `stretch` | Cross-axis alignment: `start`, `center`, `end`, `stretch` |
| `justify` | enum | `start` | Main axis: `start`, `center`, `end`, `between` |
| `wrap` | bool | `false` | Wrap when it does not fit instead of stacking |
| `align` | enum | `start` | The container's own horizontal position: `start`, `center`, `end` |

The child is `col`, with one attribute.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `grow` | number | `1` | Share of the remaining width |

````markdown
:::columns {tracks="2fr 1fr" gap="2ch"}
:::col
## One hit

The cache holds one image; a hit reads it from disk and never starts the renderer.
:::
:::col
The note beside it is an ordinary paragraph; the column decides its width.
:::
:::
````

Three cards side by side is `columns` holding three `card` blocks.

````markdown
:::columns {cols=3}
:::card {title="Parse"}
Text to a semantic tree.
:::
:::card {title="Lay out"}
Tree to views.
:::
:::card {title="Publish"}
Views to a buffer.
:::
:::
````

### 5.2 Tracks, gaps, padding

- `cols` gives equal tracks. `cols=3` is three `1fr` tracks.
- `tracks` gives explicit tracks in Ebox spelling: `(fr 2)` is written `2fr`, a fixed width `20ch`, a percentage `30%`.
- `gap` separates siblings only, never the outside. The outside ring belongs to `pad`.
- `pad` takes one length and applies it on four sides. No `pad-x` or `pad-y`: splitting the axes lets one page show two different paddings.
- Vertical spacing uses whole multiples of `lh`. Pixels would misalign the line spacing and put borders on top of glyphs.

### 5.3 Narrow windows

When side-by-side columns do not fit, the layout degrades in order, never scrolling sideways.

1. **Fewer columns.** `cols=3` drops to 2, then to 1, with every column at least `min`.
2. **Stacking.** With `tracks`, a column below `min` stacks the whole block into one column with a blank row between former columns.
3. **Tighter spacing.** `pad` drops from 2ch to 1ch and `gap` from 2ch to 1ch; the frame stays.
4. **Same type size.** At every step the type size and line height stay.

With `wrap=true`, the row wraps first, and only stacks when one column still does not fit.

### 5.4 Choosing among the three structural containers

There are only three, and the test is the content's relationship.

| What you want | Use | Why |
| --- | --- | --- |
| Things side by side | `columns` | The only column mechanism |
| A piece of material with a title and a boundary | `card` | The title is heavier than body text, lighter than a section heading |
| A fill or padding with no title | `box` | The simplest form of a card, with no title row |

**Where not to use them.** Two parallel passages are not a table, so do not force them into `columns`; use a table. Three key-value pairs are not a card; that is `field`.

## 6. The container catalogue

### 6.1 Families

| Family | Containers | Shared property |
| --- | --- | --- |
| Structure | `columns`, `card`, `box` | Decide placement and boundary only, never interpret content |
| Callouts | `note`, `tip`, `important`, `warning`, `caution` | One definition, five fixed accents |
| Collections | `steps`, `timeline`, `stats`, `field`, `file-tree`, `chat` | Children carry labels and are ordered or named |
| Interaction | `tabs`, `code-tabs`, `collapse`, `collapse-group` | Stateful, switchable by key |
| Documents | `table`, `window` | Wrap something else and change how it presents |

### 6.2 Callouts

What ships today is the GitHub spelling, with the marker on the first line of a blockquote.

```markdown
> [!WARNING]
> This only works on Emacs 30 and later.
```

The planned container spelling shares one attribute set across five names.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | The accent's fixed title | Replaces the title text |
| `collapsible` | bool | `false` | Allow the block to collapse |
| `open` | bool | `true` | Whether it starts expanded |

```markdown
:::warning {title="Compatibility" collapsible=true}
This only works on Emacs 30 and later.
:::
```

Both spellings render the same thing, from the same definition. The accent mapping is fixed: `note` to `info`, `tip` to `ok`, `important` to `important`, `warning` to `warn`, `caution` to `danger`.

Why keep both. A document pasted from GitHub works immediately, which is the commonest entry; a long document written with containers aligns with the other containers and can carry attributes.

### 6.3 Card

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | Title; omit it and there is no title row |
| `description` | string | none | One muted summary line under the title |
| `surface` | surface | `panel` | See 4.1 |
| `accent` | accent | `neutral` | See 4.1 |
| `href` | string | none | The whole card activates and opens this target |
| `align` | enum | `start` | Horizontal position of its content |
| `width` | length | `stretch` | Its own width |

The case it solves: a group of parallel material needs one boundary. A section heading lifts it to the level of a section, and a list flattens a figure into one item.

Component: `etaf-card`, whose default slot takes the body and whose `title` and `description` map directly. `surface` needs the component to accept a fill, which is a component-side change; see 9.4.

### 6.4 Box

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `surface` | surface | `none` | See 4.1 |
| `accent` | accent | `neutral` | See 4.1 |
| `pad` | length | none | Padding |
| `align` | enum | `start` | Horizontal position of its content |
| `width` | length | `stretch` | Its own width |

A box is a card without a title. Centring a figure is what it is for.

```markdown
:::box {align=center pad="1lh"}
![A cache hit](figures/hit.png)
:::
```

### 6.5 Steps

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `start` | number | `1` | First number |
| `marker` | enum | `number` | `number` for digits, `dot` for a dot |

The child is `step`, with a required `title`.

````markdown
:::steps
:::step {title="Locate"}
Take a stack with `sample` before guessing.
:::
:::step {title="Fix the cause"}
Change the layer that produces the symptom, not its result.
:::
:::
````

The case it solves: in a procedure a reader wants to see how many steps there are and which one they are on. An ordered list can do it, but the number and the title share a line, and a wrapped title leaves the number alone on its row.

Component: `etaf-steps`.

### 6.6 Timeline

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `marker` | enum | `dot` | `dot`, `number`, `none` |

The child is `event`, with a required `title` and an optional `time`.

````markdown
:::timeline
:::event {time="2026-11-12" title="Found the cost in drawing"}
`image-size` actually drew the picture.
:::
:::event {time="2026-11-13" title="Read the header instead"}
Opening dropped from 5.4 s to 0.33 s.
:::
:::
````

The case it solves: release notes and incident timelines. A list loses the "time above, content below" alignment.

Component: `etaf-timeline`.

### 6.7 Field list

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label-width` | length | computed | Name column width; from the longest name by default |
| `separator` | enum | `colon` | `colon` puts a colon after the name, `none` leaves the gap |

The body is a list; the text before the first colon is the name.

```markdown
:::field
- Version: 12.3.0
- Renderer: Chromium, resident
- Cache: `~/.cache/etaf-md/typeset`
:::
```

The case it solves: parameter notes and environment facts. A two-column table needs a header row and an alignment row, which is too much machinery.

### 6.8 Statistics

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cols` | number | `3` | Numbers per row; a narrow window reduces it |

The child is `stat`, with a required `title` (the caption) and a required `value` (the number as text). A child with no content still needs its closing line.

````markdown
:::stats
:::stat {title="Open" value="0.33 s"}
:::
:::stat {title="Resize" value="0.18 s"}
:::
:::stat {title="Memory" value="349 MB"}
:::
:::
````

The number takes `ink` in bold, the caption `muted`. A fourth entry wraps instead of shrinking text. Component: `etaf-statistic`.

### 6.9 File tree

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | One title line above the tree |
| `marker` | enum | `ascii` | `ascii` draws the lines, `none` keeps indentation only |

The body is an indented list, one `-` per level.

```markdown
:::file-tree {title="lisp/"}
- lisp/
  - etaf-md-model.el
  - etaf-md-views.el
- etaf-md.el
:::
```

The case it solves: saying what a directory holds. A fenced block can show the same thing, but its lines have to line up with the indentation, and hand-written ones are off by a cell sooner or later. The marks use only the characters 4.6 allows.

### 6.10 Chat

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `me` | enum | `left` | Which side the reader's own words take: `left`, `right` |

The child is `said`, with a required `from` and an optional `time`.

````markdown
:::chat
:::said {from="Q" time="14:20"}
Why does the preview not refresh?
:::
:::said {from="A" time="14:21"}
It refreshes after a save; a half-finished edit does not reflow.
:::
:::
````

The case it solves: a tutorial demonstrating one exchange. It is aligned text with an indent, and no bubble is drawn.

### 6.11 Tabs

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `active` | string | the first | Which tab shows first, by label |

The child is `tab`, with a required `label`.

````markdown
:::tabs
:::tab {label="Emacs 29"}
Uses the old `image-size` signature.
:::
:::tab {label="Emacs 30+"}
Passes the buffer directly.
:::
:::
````

The case it solves: several spellings of one thing in parallel, of which a reader needs one. Three parallel subsections lengthen the outline; tabs occupy one block.

Interaction follows the contract in chapter 7; no rules are restated here. The component is `etaf-tabs`: controlled, with its state supplied by the block.

### 6.12 Code tabs

The same as `tabs`, except the children hold fenced code, and an omitted `label` comes from the fence's language.

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

This is sugar, not new meaning. One more definition is one more rule to maintain; what a default behaviour can do, a container need not.

### 6.13 Collapse

A single fold.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | required | The title shown while closed |
| `open` | bool | `false` | Starts expanded |

A group.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `accordion` | bool | `false` | One open block per group |

````markdown
:::collapse {title="Complete error"}
```
The long text goes here.
```
:::
````

The case it solves: long derivations, long logs, a complete error report. They stay on the page for reference without blocking the way.

Component: `etaf-accordion`, controlled, with `open` and `multiple` supplied by the block.

### 6.14 Table wrapper

A plain pipe table already works. The wrapper adds two things.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | One title line above the table |
| `hl-rows` | string | none | Highlighted rows, e.g. `warn:2,3` |
| `hl-cols` | string | none | Highlighted columns, e.g. `accent:1` |

```markdown
:::table {title="Opening cost" hl-rows="warn:3"}
| Version | Cost |
| --- | --- |
| 0.1.9 | 5.4 s |
| 0.2.0 | 0.33 s |
:::
```

The reason: the two commonest table needs are a title and a marked row. A paragraph of prose cannot do either.

### 6.15 Demo window

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | Title bar text |
| `height` | length | computed | Content height |

```markdown
:::window {title="etaf-md-preview"}
A screenshot or a passage of text.
:::
```

A transformation of plume's `window`, which draws rounded corners and a shadow; we draw one title bar. Rounded corners cannot be drawn on a character grid, and forcing them produces a row of stray glyphs.

### 6.16 Status table

| Container | Family | Status |
| --- | --- | --- |
| GitHub alert `> [!NOTE]` and its four siblings | Callouts | Implemented |
| `note`, `tip`, `important`, `warning`, `caution` | Callouts | Planned |
| `box` | Structure | Planned |
| `card` | Structure | Planned |
| `columns` + `col` | Structure | Planned |
| `steps` + `step` | Collections | Planned |
| `timeline` + `event` | Collections | Planned |
| `stats` + `stat` | Collections | Planned |
| `field` | Collections | Planned |
| `file-tree` | Collections | Planned |
| `chat` + `said` | Collections | Planned |
| `tabs` + `tab` | Interaction | Planned |
| `code-tabs` + `tab` | Interaction | Planned |
| `collapse`, `collapse-group` | Interaction | Planned |
| `table` | Documents | Planned |
| `window` | Documents | Planned |

## 7. The interaction contract

### 7.1 Only declared containers interact

A document cannot give anything behaviour. Interactivity is a property of a container definition, never of the document.

The reason: a Markdown file may give the impression of having execution rights. It has none. A document can only state "here is a group of tabs"; the keys are the renderer's decision.

### 7.2 Focus and keys

- A focusable target is an element the container draws, not the text itself. `TAB` and `S-TAB` move between them.
- `RET` activates the current target.
- Inside a group, left and right arrows switch, for a tab row or a collapse group.
- When focus enters a container, the container shows a visible focus mark; it returns to its resting paint when focus leaves.
- Focus order follows document order, not visual position. It is the same after a narrow window degrades.

### 7.3 State and repaint

- State lives on the container, not on the document, and never on disk.
- A reflow, a theme change or a width change keeps it. Reloading the document returns to defaults.
- A state change repaints that block only, never the page.
- The default state comes from attributes; `active` and `open` are enough.

### 7.4 Search, copy, export

- **isearch**: hidden content still takes part. A match opens the block and puts focus on the match. Something unsearchable does not exist as far as a reader is concerned, and they cannot know it was folded away.
- **Copy**: the visible text is copied, including container labels, excluding hidden content.
- **Export**: an org or HTML export flattens interactive containers the way 7.5 describes, so the reader's text is complete.

### 7.5 Flattening without interaction

Where there is no keyboard and no focus, such as batch rendering, export or a terminal capture, an interactive container must flatten.

| Container | Flattened |
| --- | --- |
| Tabs | One section per tab, titled by its label, all expanded |
| Collapse | All expanded, titles kept |

Flattening is not degradation; it is the same content in another arrangement. That is why the tests can run in batch without simulating keys.

## 8. Rendering and performance

### 8.1 One block, one component

Every top-level block is its own Component, keyed by block type and source. Changing one word repaints that block alone; the others are not even touched.

A container is no exception. A `card` is one block, a `columns` is one block, and the `col` children are painted inside it.

### 8.2 Repaint scope

| What happened | What repaints |
| --- | --- |
| One word of prose changed | That block |
| A fold opened | That block |
| A tab switched | That block |
| The theme changed | The page, but each block only recolours, never reflows |
| The style table changed | The page repaints and re-derives; nothing is re-parsed |
| The window width changed | The page reflows, and nothing is rebuilt |
| A container definition changed | The blocks that use it |

A style can change a block's height, so the flow uses each block's real height. A `:scale` heading occupies several rows, and the next block starts below them.

### 8.3 Cost and budget

- Every block is measured once per width. An unchanged width is never re-measured.
- A nested column measures its own subtree, not the page.
- A block's reflow targets 50 milliseconds. A 200-block document targets one second for its first open.
- No timers, no background refresh. A still page does nothing.
- The style table is looked up once per node: one hash lookup, never inside a character loop.

The budget is written down so acceptance has a number to compare with. The concrete numbers are calibrated against the benchmark during implementation, and this section changes with them.

## 9. Definitions and components

This chapter settles two things: how thin a definition should be, and where reusable parts live.

### 9.1 Three layers

| Layer | Things | In one line | Called by |
| --- | --- | --- | --- |
| Engine | `box`, `column`, `grid`, text properties | Places and paints, knows no meaning | Components |
| Components | `etaf-card`, `etaf-tabs`, `etaf-accordion` | Named, parameterised, reusable | Apps and definitions |
| Syntax | `:::card`, `:::tabs` | Turns a document's names and attributes into component calls | The renderer |

The test is one line: **delete this layer, can anyone else still use it?** Delete `etaf-card` and no other app can draw a card, so it belongs to the component layer; delete `:::card` and only this document loses the spelling, so it belongs to the syntax layer.

### 9.2 A definition does three things

A container definition writes three things, and no more.

1. **Declare**: which attributes a document may write, at which type and default.
2. **Validate**: the renderer does it uniformly; the definition only declares.
3. **Translate**: the document's semantics (surface, accent, attributes) into component parameters.

```elisp
(etaf-md-define-container 'card
  :kind 'block
  :attrs '((title :type string :doc "Card title")
           (accent :type accent :default neutral :appearance t :doc "Accent"))
  :body (lambda (attrs body env)
          (etaf-card :title (plist-get attrs :title)
                     :variant (pcase (plist-get attrs :accent)
                                ('warn 'warning)
                                ('ok 'success)
                                (level level))
                     body)))
```

No line in the definition draws a border or sets padding. Those live in `etaf-card`. The definition only turns the document's words into the component's parameters.

One hard constraint: **a definition cannot invent a parameter its component does not have.** Making `:::card` accept `surface` means first making `etaf-card` accept a fill, which is a component-side change; see 9.5. The only way around it is to draw a shell inside the definition, which is exactly what 9.4 forbids.

### 9.3 Components take semantic parameters

A component's parameters are written for Elisp, not for documents.

- **No document words.** A component never mentions `:accent` as a Markdown concept, `:container` or `:::card`; no other app should have to understand Markdown.
- **No colour values.** A component takes `surface` and `accent` as semantic roles, never `"#c00"`. Turning a role into a colour happens inside the component, so switching palettes cannot miss a container.
- **Few geometry parameters.** Padding and spacing belong to the component's own defaults; a definition overrides them only when it must.

Counter-examples: a component growing a `:markdown-level` parameter leaks syntax into the component layer; a definition drawing a card border copies the component.

### 9.4 One authority per visual fact

| Fact | Authority |
| --- | --- |
| How headings, quotes, code and tables look | The style table (chapter 4), reader-editable |
| How a container looks | The parameters its definition passes |
| A component's own baseline | The component |
| Colours | Tokens, one set per palette |

Two places that can change one fact is a bug. A component's default is only a baseline the definition may override; a definition's value is the document's default, which a reader may override for appearance attributes, see 4.4.

### 9.5 Two uses promote a widget

A new container's widget may not exist, and the definition builds it from primitives. That is not duplication, it is the first implementation. The risk is that it stays in the definition forever.

The rule: **when a second app needs it, move it into `etaf-ui`**, together with its parameters, tests and documentation. The definition then shrinks back to the three lines of translation.

The test is the one from 9.1: delete it, can anyone else still use it?

### 9.6 Shipped definitions are definitions too

`box`, `card` and `columns` are not special cases in the renderer; they are three definitions in the same registry.

This is what keeps the split honest over time. As long as one container has a private branch in the renderer, the API has never been exercised, and a user will eventually hit a capability only that branch has.

Three consequences.

- Shipped definitions are registered through the same entry, in the package's own loading code.
- A test must replace the shipped `card` with a user definition and still render the page.
- When a component's parameters change, the definition tests go red before a user does.

## 10. Extending

### 10.1 The shape of a definition

A definition is data, not code inside a document.

```elisp
(etaf-md-define-container
 'card
 :kind 'block
 :summary "A titled card"
 :attrs '((title :type string :doc "Card title")
          (accent :type accent :default neutral :appearance t :doc "Accent"))
 :body (lambda (attrs body env)
         (etaf-card :title (plist-get attrs :title)
                    :variant (pcase (plist-get attrs :accent)
                               ('warn 'warning)
                               ('ok 'success)
                               (level level))
                    body)))
```

| Field | Purpose |
| --- | --- |
| The name | The first argument, a symbol. `:::card` in a document looks it up |
| `:kind` | `block`, `parent` or `child` |
| `:summary` | One line, used in help and errors |
| `:attrs` | The attribute table; each entry follows 10.2 |
| `:children` | Parent only: the child names and their attributes |
| `:body` | A function taking three arguments and returning an ETAF view |

What `body` receives is three things. A positional slot is only for what every definition of that kind has; everything else is a named accessor on `env`.

- `attrs`: a validated plist. Omitted attributes hold their defaults and types are converted.
- `body`: the parsed content as views. This is the default rendering.
- `env`: the rendering environment; optional capabilities come from here, as the table below lists.

What `env` offers is all a definition can reach.

| Capability | Call | Used by |
| --- | --- | --- |
| Token | `(etaf-md-token env 'info)` | Every container |
| Line height | `(etaf-md-token env 'lh)` | Every container |
| Surface | `(etaf-md-surface env 'panel)` turns a surface into its fill; `none` returns `nil` | Every container |
| Tone | `(etaf-md-accent env 'warn)` turns a accent into its accent colour | Callouts, cards |
| Children | `(etaf-md-children env)`, each as `(:name :attrs :view)` in source order | Parents |
| Block tree | `(etaf-md-content env)`, the parsed blocks, not views | `field`, `code-tabs`, `table` |
| Render blocks | `(etaf-md-render env blocks &rest options)` | `field`, `chat`, `table` |
| Open a target | `(etaf-md-open env href)` | `card`'s `href` |
| This block's state | `(etaf-md-state env :active)` | `tabs`, `collapse` |
| Measure | `(etaf-md-measure env)` | `columns` degradation |

The state row is the key one. `etaf-tabs` in the catalogue is a controlled component: `active` and `on-change` come from the caller, and a definition has nowhere to keep state. So every block gets its own state cell, created by the renderer and isolated per block.

The `&rest options` on `etaf-md-render` are for wrapping containers. `table` turns row highlights on for the table it wraps; it does not need to change how a table draws, only to pass the option down.

A parent adds one field.

```elisp
:children '((col :attrs ((grow :type number :default 1 :doc "Width share"))))
```

### 10.2 Rules for attributes and children

- A definition references names from the shared attribute table, or declares its own. A private attribute says in `:summary` that it only works with that container.
- An entry has exactly one position: its first element is the name, which is the entry's key. Everything after is a named field, the same shape as `:children '((col ...))`.
- `:type` is required and takes `string`, `number`, `bool`, `length`, `surface`, `accent`, `enum` or `regex`. An enum writes `:type enum :one-of (...)`, a pattern writes `:type regex :pattern "..."`. There is one spelling for a type, not a keyword for some kinds and a list for others.
- An omitted `:default` means `nil`, so a `nil` default takes no characters at all.
- A required attribute writes `:required t`, as in `(label :type string :required t :doc "Tab label")`, and then no `:default`; writing both is an error at load. Required exists only on the document side; reader-side keys are always optional.
- An appearance attribute writes `:appearance t`. It means "the reader may override the document's value", see 4.4. It may only mark an appearance type such as `surface`, `accent` or `align`; marking a `string` is an error at load.
- `:doc` is optional but recommended; it appears in help and in errors.
- A `child` definition declares no `:children`.
- A definition may not read files, make network requests or start timers. It receives `attrs`, `body` and `env`, and reads the rest from `env` by name.
- The renderer's dispatch contains no container names. It looks a definition up by role and attributes, and never branches on a name.

### 10.3 Defining one style

Same shape as the table, written as one call. Giving each level its own prefix is three lines of data.

```elisp
(etaf-md-define-style 'heading
  '((:weight bold)
    (:level 1 :prefix "◆ ")
    (:level 2 :prefix "◇ ")
    (:level 3 :prefix "· ")))
```

It renders like this:

```
◆ Install
◇ Requirements
· Emacs 29 and later
```

A prefix is a shipped key, so this needs no function. Only what the shipped definition did not foresee needs one; see 10.4.

Validation happens at load: an unknown node type, an unknown key or a value of the wrong type is an error, that node type falls back to the shipped style, and the error names the node, the key and the accepted values.

### 10.4 Replacing one node's rendering

When the style table is not enough, supply a function. The function can also give the type new keys.

```elisp
(etaf-md-define-render 'heading
  :extends t
  :keys '((surface :type surface :doc "Heading fill"))
  (lambda (node env)
    (etaf-node 'box
               (list :width 'stretch
                     :background-color (etaf-md-surface env (etaf-md-style env :surface)))
               (list (etaf-md-style-default 'heading node env)))))
```

| What you get | Meaning |
| --- | --- |
| `node` | Type, attributes and children. A `heading` carries `:level` and `:children` |
| `env` | Tokens, measures and derived data. `(etaf-md-style env :surface)` reads this block's style value; `(etaf-md-derived env :number)` reads its number |
| `:extends t` | Keep the shipped keys and rendering, and add to them |
| `:keys` | New keys, written like 10.2. Only a function may declare them |
| `etaf-md-style-default` | The shipped view. Wrap it, change one thing, or skip it. A heading also takes `:label` for its number |

One name may appear on several types: this adds a `surface` that `heading` did not have.

Three rules.

- It returns a view and never modifies the node tree.
- When it signals, that node type falls back to the shipped rendering, the page keeps going, and `doctor` reports the error.
- **A new key needs a function.** A data definition cannot add keys, for a plain reason: a key nobody reads is dead configuration.

A prefix built from the section number also lives here. It is not a constant, so data cannot express it.

```elisp
(etaf-md-define-render 'heading
  :extends t
  (lambda (node env)
    (etaf-md-style-default 'heading node env
                           :label (etaf-md-roman (etaf-md-derived env :number)))))
```

`:label` is a heading-only keyword that takes the number the derive step computed; no other type accepts it.

### 10.5 Overriding a shipped definition

Three spellings, one table.

| Spelling | Effect | Use it for |
| --- | --- | --- |
| `:extends t` | Keep the shipped keys and rendering; yours are added | Adding a parameter, wrapping it |
| `:replace t` | Drop the shipped definition; you own the keys and the rendering | Replacing the look entirely |
| Neither | Applies only when no definition of that name exists; a duplicate is an error | A new type |

Four constraints.

- **The document-side attribute table only grows, never changes.** A container's new attributes may only be appended; a rename or a removal is breaking, bumps `:contract`, and old documents degrade under 3.4 with a line that says so. Child names work the same way. Added keys are reader-side only.
- **`attrs` and `keys` are two names because the rights differ.** `attrs` are written by the document and closed; `keys` are written by the reader and extensible.
- **`:default` always means the shipped value.** Loading keeps a snapshot of the shipped definition, or "back to the default" would mean nothing.
- **An override leaves a trace.** A `:replace t` error line names what was replaced, and `doctor` lists the override chain with each source file.

Name clashes resolve by load order: when two third-party packages change one type, the later one must say `:replace t`, or the error names both.

### 10.6 Where definitions live and when they are read

- Definitions are `.el` files in a user directory named by `etaf-md-container-directory`.
- Load order is fixed: the package's own definitions first, the user directory after, and file name order within a directory. A later definition may override an earlier one, but only by saying so; see 10.5.
- A session reads the registry once when created and does not touch the disk again. A changed definition needs `r` or a fresh preview.
- A document cannot register a container and cannot run Elisp. Sharing a document is not sharing code.

### 10.7 Debugging

- `etaf-md-describe-containers` lists the registry: name, kind, summary, attributes and source file. Planned.
- When something looks wrong, follow one chain: what type is this block, which definition renders it, which component it calls, where its style value came from, and which token that landed on. Planned.
- The error line is always on the page, so no log has to be opened.
- When a definition signals, that block degrades to its source plus one line reading "the `card` definition failed: …", and the rest of the page keeps rendering.
- `etaf-md-doctor` reports how many containers are registered, whether a definition file failed to load, and which overrides are in place. Planned.

### 10.8 Trust model

- A document has no execution rights. It can name things and pass attributes.
- Definitions load only from the configured directory. Not the current directory, not a directory beside the document.
- A definition may not read files, make network requests, start timers or change global state. Data travels through `attrs`.
- Rendering has no side effects. A view reads refs and cached values only.

## 11. Roadmap

### 11.1 Phases

| Phase | Content | Done when |
| --- | --- | --- |
| 0 | GitHub alerts | Implemented, covered by 51 tests |
| 1 | Render path: parsing, derive, the style table, the failure catalogue, with `box`, `columns` and `card` written as definitions | One assertion per failure kind; three-level nesting and the limit; captures at three widths; a user definition replaces the shipped `card`; at least one style key changes each built-in node; a style edit does not re-parse |
| 2 | Callout containers: five names sharing one definition with the GitHub spelling | Both spellings produce the same buffer text; the accent mapping holds |
| 3 | Collections: `steps`, `timeline`, `stats`, `field`, `file-tree`, `chat` | Each container has a positive case, a counter-example and captures in three palettes |
| 4 | Interaction: `tabs`, `code-tabs`, `collapse`, `collapse-group` | Keys go through the command loop; state survives reflow and a theme change; flattened output loses nothing |
| 5 | Documents: `table`, `window` | Row and column highlights land; the window draws only a title bar |
| 6 | Registry and user definitions | A sample definition installs and uninstalls; a new key on a shipped type takes effect; `:default` still reaches the shipped view after an override; a contract mismatch is reported; `doctor` reports counts and the override chain |

### 11.2 The acceptance matrix per container

Every container passes these six cells; fewer is not done.

| Cell | What it checks |
| --- | --- |
| Positive | A document writes it and it renders as intended |
| Counter-example | One missing required attribute or one wrong value degrades the page with an accurate line |
| Nesting | Inside a `columns` column and inside a `card`, it still holds |
| Palette | Dark, light, sepia and face-derived: readable in all four |
| Narrow | Wide, medium and narrow: nothing lost, type size unchanged |
| Style | One style key changes its appearance; an unknown key is reported and falls back to the shipped style |

The render path carries four more assertions, independent of any container.

- Editing the style table leaves the parse count unchanged.
- A heading prefix does not change its anchor.
- With numbering off, the derive step is skipped.
- After overriding `heading`'s rendering, `etaf-md-style-default` still returns the shipped view.

### 11.3 Done means

A phase is done only when all three hold.

1. `make check` passes: structure, compilation, tests and the API check.
2. The affected examples have been run in a real GUI and their captures reviewed.
3. The attribute table in Appendix A, the style keys in Appendix C and the mapping in Appendix D are updated with it.

## 12. What this will not do

- No HTML subset, no CSS subset, no `<style>` tag. Two layout systems in one renderer blur the boundary until nobody can say which layer produced a gap.
- No scripts in documents, and no container registration from documents.
- No type-size parameter and no scale parameter. Scaling exists only as `:scale` in the reader's style table.
- No remote frames, remote players or remote code execution.
- No rounded corners, shadows, gradients or animation.
- No second document format beside Markdown.
- No pages, routes, navigation or publishing. That is the application's work, see 1.2.
- No `justify`. A character grid has no inter-word space to stretch, so it can only pad with blanks, and Chinese paragraphs get holes at the line ends.

## Appendix A: attribute reference

The shared attributes. A container selects from here and never invents a synonym.

| Attribute | Type | Meaning | Used by |
| --- | --- | --- | --- |
| `title` | string | Title text | Callouts, card, steps, timeline, file-tree, collapse, table, window, stat |
| `label` | string | Short label | tab, stat |
| `description` | string | Summary under the title | card |
| `surface` | surface | Fill role | box, card |
| `accent` | accent | Emphasis | box, card |
| `align` | enum | Horizontal position of content | box, card, columns |
| `width` | length | Own width | box, card |
| `pad` | length | Padding | box, columns |
| `gap` | length | Space between siblings | columns |
| `cols` | number | Number of equal columns | columns, stats |
| `tracks` | string | Explicit tracks | columns |
| `min` | length | Smallest column | columns |
| `items` | enum | Cross-axis alignment | columns |
| `justify` | enum | Main-axis alignment | columns |
| `wrap` | bool | Wrap when it does not fit | columns |
| `grow` | number | Width share | col |
| `marker` | enum | Mark style | steps, timeline, file-tree |
| `open` | bool | Starts expanded | Callouts, collapse |
| `collapsible` | bool | May collapse | Callouts |
| `accordion` | bool | One open per group | collapse-group |
| `active` | string | Initially selected | tabs |
| `href` | string | Target of the whole block | card |
| `start` | number | First number | steps |
| `separator` | enum | Name/value separator | field |
| `label-width` | length | Name column width | field |
| `me` | enum | The reader's own side | chat |
| `from` | string | Sender | said |
| `time` | string | Timestamp | event, said |
| `value` | string | The number as text | stat |
| `height` | length | Content height | window |
| `hl-rows` | string | Highlighted rows | table |
| `hl-cols` | string | Highlighted columns | table |
| `id` | string | Stable anchor | Every block |

## Appendix B: surfaces, accents and tokens

| Value | Token | Meaning |
| --- | --- | --- |
| `surface=none` | none | No fill |
| `surface=panel` | `panel` | Code blocks, cards |
| `surface=quote` | `quote-bg` | Quotation-like |
| `surface=sunken` | `panel2` | Secondary information |
| `surface=page` | `bg` | Separated from the prose |
| `accent=neutral` | `ink` / `panel` | No accent |
| `accent=info` | `accent` / `accent-soft` | Note |
| `accent=ok` | `ok` / `ok-soft` | Success |
| `accent=warn` | `warn` / `warn-soft` | Caution |
| `accent=danger` | `danger` / `danger-soft` | Danger |
| `accent=important` | `important` / `important-soft` | Important |

The five callout names map to accents fixedly: `note` to `info`, `tip` to `ok`, `important` to `important`, `warning` to `warn`, `caution` to `danger`.

## Appendix C: style keys

The keys a style table may write. In the type column, a surface is one of the five words in 4.1, a colour is a token name, and either may be a literal for a reader. The value `:default` means the shipped value. This is the shipped vocabulary; a user gives a type new keys with `:keys`, see 10.4.

| Key | Type | Used by | Meaning |
| --- | --- | --- | --- |
| `surface` | surface or colour | quote, code, table, callout | Fill |
| `color` | colour | heading, strong, em, link, code | Ink |
| `accent` | accent | quote, callout | Accent colour and soft fill |
| `weight` | `normal` / `bold` | heading, strong | Weight |
| `slant` | `normal` / `italic` | em, quote | Slant |
| `underline` | bool | link, strong | Underline |
| `prefix` | string | heading | Display prefix; anchors unaffected |
| `suffix` | string | heading | Display suffix |
| `numbering` | `none` / `arabic` / `roman` | heading, table | Numbered by the derive step |
| `scale` | number | heading | Multiple of the base size |
| `gap-before` / `gap-after` | length | heading, quote, code, table | Space above and below |
| `bar-width` | length | quote, callout | The left bar's width |
| `marker` | string | list | The bullet glyph; only characters 4.6 allows |
| `tag-color` | colour | code | The fence's language label |
| `header-surface` | surface or colour | table | Header fill |
| `stripe-surface` | surface or colour | table | Stripe fill |
| `accent-colors` | alist | callout | Tone to colour |
| `align` | `left` / `center` / `right` | table | Cell alignment |

## Appendix D: the plume map

| Plume | Our decision | Note |
| --- | --- | --- |
| `align` | Folded into `box`'s `align` attribute | One alignment does not deserve a container |
| `flex` | Folded into `columns` | One container handles rows, wrapping and proportions |
| `card` | Absorbed as `card` | Rounded corners and shadow become one border and a surface |
| `card-grid` | Folded into `columns {cols=N}` | Cards side by side are cards in columns |
| `card-masonry` | Declined | Row heights are fixed, so packing yields a grid |
| `steps` | Absorbed as `steps` + `step` | Number plus title |
| `tabs` | Absorbed as `tabs` + `tab` | Keyboard reachable; a switch repaints one block |
| `code-tabs` | Absorbed as tabs default behaviour | The label comes from the fence language |
| `collapse` | Absorbed as `collapse` and `collapse-group` | Adds `accordion` and search auto-expansion |
| `field` | Absorbed as `field` | Auto-aligned name column |
| `timeline` | Absorbed as `timeline` + `event` | Optional marks |
| `table` | Partly absorbed | Title and row/column highlights |
| `file-tree` | Absorbed as `file-tree` | Marks use only the allowed characters |
| `code-tree` | Declined | Overlaps `code-tabs` plus `file-tree` |
| `chat` | Absorbed as `chat` + `said` | Alternating sides and indentation, no bubbles |
| `window` | Absorbed with a change, as `window` | Title bar only |
| `encrypt` | Declined | A document that must stay secret does not belong in a preview |
| `npm-to`, `lang-repl` | Declined | Needs a package manager and an interpreter |
| `plot`, `qrcode`, `pdf` | Declined | Needs plotting and image generation |
| `annotation`, `abbreviation` | Declined | Needs marks over an image and a hover popup |
| `code-pen`, `code-sandbox`, `repl`, `caniuse` | Declined | Needs a browser and a network |
