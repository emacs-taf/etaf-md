# Extension syntax

> **Status.** The only extension the page renders today is the GitHub alert block: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`. Everything else here is a design contract. It fixes the syntax, the parameters and the acceptance criteria before the code exists, so the implementation has one thing to follow. Any container or function marked *planned* does not exist yet, and its name is a proposal that the root entry's Commentary will settle.
>
> The Chinese and English versions run section for section. Change one, change the other.

## 1. The reference and the distance from it

The design refers to `vuepress-theme-plume`. Its Markdown extensions live in `plugins/plugin-md-power/`, and the real structure is three things.

- **One container factory**, in `src/node/container/createContainer.ts`. It exposes `createContainerPlugin`, which turns `:::name` into a custom container whose content is still parsed as Markdown, and `createContainerSyntaxPlugin` for containers whose content goes to a custom renderer.
- **One registry**, in `src/node/container/index.ts`. It installs about twenty presets at once: `align`, `tabs`, `code-tabs`, `window`, `steps`, `card`, `card-grid`, `card-masonry`, `encrypt`, `npm-to`, `lang-repl`, `file-tree`, `code-tree`, `timeline`, `collapse`, `chat`, `field`, `table`.
- **About thirty client components**, among them `VPCodeTabs`, `VPTabs`, `VPCollapse`, `VPField`, `VPTimeline`, `VPCodeTree`, `VPTable`, `VPPlot`, `VPAnnotation`, `VPAbbreviation`, `VPQRCode`, `VPPdf`, `VPArtPlayer`, `VPCodePen`, `VPCodeSandbox`, `VPCard`, `VPCardGrid`, `VPCardMasonry`, `VPCaniuse`.

Copying it will not work. Three hard differences:

1. **The output differs.** Plume emits HTML, Vue components and CSS. We emit boxes, text and faces on a character grid. A container that lands in a buffer is a run of characters carrying text properties.
2. **The expression differs.** CSS has arbitrary lengths, absolute positioning, gradients, rounded corners, shadows and animation. A character grid has line height, character width, borders, fills, weight and underlines, plus a handful of box-drawing characters.
3. **The runtime differs.** A plume page carries client-side scripts, so a container can load, expand and play inside the browser. Our page is a plain-text result: a reader has to find it with isearch, copy it with `C-w`, export it through org, and read it in a terminal.

Copying shows immediately. A card's rounded corners and shadow become garbled glyphs, a tab strip's sliding animation becomes a repaint per frame, and a chat avatar becomes a missing-glyph box.

Two things are worth taking, and neither is an implementation:

1. **The container factory.** Twenty effects sharing two factory functions means the shape of a definition converged. We keep that shape, but the render hook returns an ETAF view instead of HTML.
2. **The effect inventory.** What plume solved is a requirement list. Ask of each one what it looks like on a character grid. What the grid can express gets absorbed; what it cannot gets declined, with the reason in Appendix A.

## 2. Six primitives and six rules

The extension system has six primitives. A new container only declares how it uses these.

| Primitive | What it is | Why nothing else |
| --- | --- | --- |
| One syntax | `:::name {params}` | A second punctuation brings a second set of escapes and a second nesting rule |
| One content model | Parsed Markdown views | Content is views, not a string and not HTML |
| One parameter system | Name, type, default, validation | There is one validation point and one error shape |
| One set of layout atoms | Row, column, grid, gap, padding | Every container's layout composes from these |
| One appearance source | The page's tokens | Colours follow the theme; a container carries no palette of its own |
| One failure rule | Keep the source, add one line | The page stays readable and the broken block stays visible |

The six consistency rules, each with its reason:

1. **One syntax.** A new effect gets a new name, not new punctuation. Slash commands, `@` directives and HTML tags do not enter a document. The reason: a reader learns one block shape, and a writer never has to remember which punctuation works at which depth.
2. **One content model.** A container holds anything the page holds: paragraphs, lists, tables, fenced code, formulas, diagrams, other containers. A definition decides placement and never touches parsing. The reason: publication, outlines, links, search and per-block repaint keep working inside a container with no code change.
3. **One parameter system.** Values are validated before a view is built, never guessed during rendering. The reason: a bad value should not paint half a card and then turn into a different error on the next reflow.
4. **One set of layout atoms.** Row, column and grid, with gap, alignment, padding and a token fill. The reason: layout is bounded, so a new visual effect has to compose rather than add a private layout engine.
5. **One appearance source.** Colours come from page tokens, and the type size is inherited from the reader's Emacs. The reason: a colour that looks right on a dark page is unreadable on a paper-coloured one, and a card that hard-codes 12 points becomes a footnote on a machine set to 20.
6. **One failure rule.** An unknown name, a bad parameter, too much nesting or a definition that signals all keep the source and add one line. The reason: a document travels to machines that lack a definition, and failing the whole page is the worst degradation.

## 3. The syntax

### 3.1 Opening and closing

````markdown
:::card {title="Cache hit" tone=panel}
The image and the formula are each drawn once and scaled to the page.

- A hit reads the file
- A miss draws once
:::
````

The rules:

| Rule | Meaning |
| --- | --- |
| Name | Lowercase letters, digits and hyphens: `card`, `card-grid`, `code-tabs` |
| Parameters | `key=value` inside braces, separated by spaces; omit the braces when there are none |
| Closing | As many colons as opened, three at minimum |
| Nesting | An outer container uses more colons: `:::card` inside `::::card` |
| Depth | Eight levels at most. The ninth is an error, not a render |
| Empty | Allowed; it renders as a block with only its title |
| Line start | `:::` occupies its own line, preceded by whitespace only |

`:::col`, `:::tab`, `:::step`, `:::item`, `:::stat`, `:::event` and `:::said` are ordinary containers whose names only a parent interprets. The parent owns the relationship; the parser knows only opening, closing and nesting.

To wrap a container of the same name, give the outer one an extra colon:

````markdown
::::card {title="Outside"}
:::card {title="Inside"}
Content
:::
::::
````

The depth limit is eight rather than unbounded for two reasons. First, each level is a box, and a reader in a narrow window loses track of which level they are in; eight is already past what ordinary documents need. Second, every level costs one measurement and one reflow, so doubling the depth grows the cost linearly; the limit pins the worst case.

### 3.2 Parameters

Seven types. A definition declares which parameters it takes, at which type and with which default.

| Type | Spelling | Meaning | Invalid |
| --- | --- | --- | --- |
| `string` | `title="Cache hit"` | Text. Quote it when it contains spaces; `\"` escapes a quote | `title=cache hit` |
| `number` | `level=2` | Integer or decimal, optionally signed | `level=two` |
| `bool` | `open=true` | `true` or `false`, nothing else | `open=yes` |
| `length` | `gap="2ch"` | A number with a unit: `ch`, `lh`, `px`, `%` | `gap=2` |
| `color` | `tone=panel` | A page token name, see 3.4 | `tone="#24262a"` |
| `enum` | `tone=warning` | One of the words the definition lists | `tone=urgent` |
| `regex` | `id="^[a-z]+$"` | A value matching the pattern | `id="A-1"` |

Three conventions:

- **No unit, no length.** `gap=2` is wrong and `gap="2ch"` is right. The reason: one bare number in a two-column layout could mean characters, lines or pixels, and guessing wrong mislays the layout once per guess.
- **Booleans accept neither `yes` nor `1` nor `on`.** Only `true` and `false`. The reason: three spellings mean three parse branches and three error messages.
- **Colours accept token names only.** A hexadecimal value is an error, and the error line lists the tokens that parameter accepts. See 3.4 for why.

Errors and help list parameters in declaration order. Rendering ignores the order.

### 3.3 Validation and errors

Validation runs once, reports every error in the block together, and never guesses or half-renders. An error is a muted line above the block's source, and its line number is the line that opened the container:

````markdown
:::card {title="Cache hit" colour=blue tone="#24262a"}
Content
:::
````

```
line 42: card does not take "colour"; it takes title, tone
line 42: card received tone="#24262a"; it takes panel, quote, accent, danger
line 44: nesting depth 9 exceeds the limit of 8
```

Three rules:

1. **No dialog.** The error is part of the page, not an Emacs error. A file with ten mistakes would otherwise interrupt ten times.
2. **No whole-page failure.** Only the failing block degrades; the rest renders.
3. **One line per error.** Several errors in one block each take a line, ordered by the definition's parameter order.

Error text follows the page language. A Chinese page answers in Chinese, an English page in English, through the same label mechanism the alert titles use.

### 3.4 Tokens

These are all the colours a container may use. They follow the page palette: dark, light and sepia each define a set, and the face-derived mode computes them from the active frame.

| Token | Use |
| --- | --- |
| `bg` | Page background |
| `ink` | Body text |
| `muted` | Secondary text and notes |
| `faint` | The weakest layer: numbering, separators |
| `accent` | Links, emphasis, informational marks |
| `accent-soft` | Informational fill |
| `panel` | Code blocks, card surface |
| `panel2` | Table header, stripes |
| `border` | Borders and rules |
| `quote-bg` | Quote fill |
| `quote-bar` | Quote's left bar |
| `table-header` | Table header |
| `table-stripe` | Table stripe |
| `heading` | Headings |
| `ok` / `ok-soft` | Success foreground and fill |
| `warn` / `warn-soft` | Warning |
| `danger` / `danger-soft` | Danger |
| `important` / `important-soft` | Important |

**Why no hexadecimal.** A `#24262a` that looks right on a dark page is a black blot on a paper-coloured one, with unreadable text on top. The page defines every token in all three palettes, so a container asks for "a panel fill" and follows the palette when it changes. A hexadecimal value is an error, and the error line lists the tokens that parameter accepts.

### 3.5 Type size is not a parameter

There is no `size`, no `font-size`, no `scale`, and no equivalent. Type size always comes from the reader's Emacs.

The reason: a container and the body share one size, and that is what gives the page a consistent reading rhythm. A card title that should catch the eye uses weight, whitespace, a colour bar or a fill, never size. A short window drops a whole row instead of shrinking text.

A counter-example makes it concrete: a `size=large` card occupies three rows at 12-point and five rows at 20-point. The same document lays out differently on two machines, and captions stop lining up with card titles.

## 4. Built-in containers

Each entry states its status. *Implemented* means a document can write it and the page renders it today; *planned* means the design fixes it and the code does not exist.

### 4.1 Implemented: GitHub alerts

The spelling puts a marker on the first line of a blockquote:

```markdown
> [!WARNING]
> This only works on Emacs 30 and later.
```

Five markers: `NOTE`, `TIP`, `IMPORTANT`, `WARNING`, `CAUTION`. The block renders with a soft fill, a 3px colour bar on the left, 2ch padding on both sides, a bold first row of mark and label, and the body as ordinary Markdown.

| Feature | Status today |
| --- | --- |
| Five markers | Implemented |
| Title text | Fixed per kind; a Chinese page shows 笔记, 提示, 重要, 警告, 小心 |
| Changing the title | Planned, via the `title` parameter in 4.2 |
| Collapsing | Planned, via `collapsible` in 4.2 |
| Other marker names | Unrecognised; the block renders as an ordinary quote without an error |

Two limits are worth writing down. The marker must be the blockquote's first line, or the block is just a quote. Only those five names count, so `[!DANGER]` renders as a quote.

### 4.2 Planned: the container form of an alert

`:::note`, `:::tip`, `:::important`, `:::warning` and `:::caution` take the same parameters:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | The kind's fixed title | Replaces the title text |
| `collapsible` | bool | `false` | Allow the block to collapse |
| `open` | bool | `true` | Whether it starts expanded |

```markdown
:::warning {title="Compatibility" collapsible=true}
This only works on Emacs 30 and later.
:::
```

It renders as the same thing as `> [!WARNING]`, so a writer picks either. The reason for both: pasting a block written on GitHub should just work, and a long document written with containers keeps its block shapes aligned.

### 4.3 Planned: card

`:::card` gathers related material inside one boundary: a note plus a figure, a set of links, a piece of code.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | Card title; omit it and there is no title row |
| `description` | string | none | One muted summary line under the title |
| `tone` | enum | `panel` | Fill: `panel`, `quote`, `accent`, `danger` |
| `href` | string | none | The whole card becomes activatable and opens this target |
| `cols` | enum | `1` | Body columns: `1`, `2`, `3`; a narrow window drops to one |

The case it solves: a long article holds a group of parallel pieces. A section heading lifts them to the level of a section, and a list flattens a figure into one item. A card gives them a shared boundary, with a title row heavier than body text and lighter than a section heading.

Mapping: ETAF UI's `etaf-card`, whose `default` slot takes the body and whose `title` and `description` map directly.

### 4.4 Planned: card grid

`:::card-grid` holds several `:::card` blocks and lays them out in one row or a grid of equal widths.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cols` | number | `2` | Cards per row; a narrow window reduces it |
| `gap` | length | `"2ch"` | Horizontal space between cards |

```markdown
:::card-grid {cols=3}
:::card {title="Parse"}
Text to a semantic tree.
:::card {title="Lay out"}
Tree to views.
:::card {title="Publish"}
Views to a buffer.
:::
```

Plume also has `card-masonry`, which packs by height. We decline it: row heights are fixed on a character grid, so packing produces an ordinary grid, and one more parameter would not buy one more effect.

### 4.5 Planned: steps

`:::steps` draws a numbered sequence, one `:::step` per step.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `start` | number | `1` | First number |
| `style` | enum | `number` | `number` for digits, `dot` for a dot |

```markdown
:::steps
:::step {title="Locate"}
Take a stack with `sample` before guessing.
:::step {title="Fix the cause"}
Change the layer that produces the symptom, not its result.
:::
```

The case it solves: in a procedure, a reader wants to see how many steps there are and which one they are on. An ordered list can do it, but the number and the title share a line, and a long title wraps so the number is left alone on its row.

Mapping: ETAF UI's `etaf-steps`, whose `:items` take `:key` and `:label` and whose `current` the page supplies.

### 4.6 Planned: tabs

`:::tabs` holds several `:::tab` blocks: several versions of one thing in one place, switched by the reader.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label` | string | required | Tab label |
| `active` | string | the first | Which tab shows first, by label |

```markdown
:::tabs
:::tab {label="Emacs 29"}
Uses the old `image-size` signature.
:::tab {label="Emacs 30+"}
Passes the buffer directly.
:::
```

The case it solves: several spellings of one thing in parallel, of which a reader needs one. Three subsections in parallel lengthen the outline; tabs occupy one block.

Interaction is the heaviest part of this design, so it gets its own rules:

- A tab is a real focusable target, not painted text. `TAB` reaches the tab row, left and right arrows switch, `RET` activates.
- Switching repaints this block only. The active tab lives in the container's own state and survives reflow, a theme change and a width change.
- An already selected tab takes no pointer hover highlight; the two states do not stack.
- After a switch, focus stays on the tab row so the reader can keep pressing arrows.

### 4.7 Planned: code tabs

`:::code-tabs` is a spelling of tabs for one case: each `:::tab` holds a fenced block, and an omitted label comes from the fence's language.

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

The reason: it adds no meaning, only "the label comes from the code language". One container for that would add a definition to maintain, while making it the default behaviour of tabs keeps the registry shorter.

### 4.8 Planned: collapse

`:::collapse` starts closed and opens on a key press. `:::collapse-group {accordion=true}` keeps only one block open at a time.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | required | The title shown while closed |
| `open` | bool | `false` | Starts expanded |
| `accordion` | bool | `false` | One open block per group; only meaningful inside `collapse-group` |

The case it solves: long derivations, long logs, a complete error report. They stay on the page for reference without blocking the way.

One detail has to be fixed now: collapsed content still takes part in isearch. When a search hits a word inside, the block opens and the match takes focus. The reason: something unsearchable does not exist as far as a reader is concerned, and they have no way to know it was folded away.

Mapping: ETAF UI's `etaf-accordion`, whose `:items` take `:title` and content, with `open` and `multiple` from the page.

### 4.9 Planned: field list

`:::field` draws a list of "name: value" pairs with an aligned name column.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `label-width` | length | computed | Name column width; computed from the longest name by default |
| `separator` | enum | `colon` | `colon` puts a colon after the name, `none` leaves the gap only |

The body is a list; the text before the first colon is the name:

```markdown
:::field
- Version: 12.3.0
- Renderer: Chromium, resident
- Cache: `~/.cache/etaf-md/typeset`
:::
```

The case it solves: parameter notes, environment facts, key-value pairs. A table needs a header row and an alignment row, which is too much machinery for two columns.

### 4.10 Planned: timeline

`:::timeline` lays events in one column, each with a time, a title and a note.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `marker` | enum | `dot` | Mark: `dot`, `number`, `none` |

```markdown
:::timeline
:::event {time="2026-11-12"}
Found that `image-size` actually draws the image.
:::event {time="2026-11-13"}
Read the file header instead: opening dropped from 5.4 s to 0.33 s.
:::
```

The case it solves: release notes, incident timelines, publication cadence. A list loses the "time above, content below" alignment, so a reader has to hunt for each timestamp.

Mapping: ETAF UI's `etaf-timeline`.

### 4.11 Planned: statistics

`:::stats` lays several numbers side by side, each with a caption.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cols` | number | `3` | Numbers per row; a narrow window reduces it |

```markdown
:::stats
:::stat {label="Open" value="0.33 s"}
:::stat {label="Resize" value="0.18 s"}
:::stat {label="Memory" value="349 MB"}
:::
```

The number is emphasized with a token colour and the caption uses `muted`. A fourth entry wraps to the next row instead of shrinking text. Mapping: ETAF UI's `etaf-statistic`.

### 4.12 Planned: layout

`:::layout` splits the page-level flow into columns, marked with `:::col`.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cols` | string | `"2fr 1fr"` | Space-separated track widths, in `fr`, `ch` or `%` |
| `gap` | length | `"2ch"` | Space between columns |
| `align` | enum | `start` | Cross-axis alignment: `start`, `center`, `end`, `stretch` |
| `min` | length | `"28ch"` | Smallest column; below it the columns stack |

```markdown
:::layout {cols="2fr 1fr" gap="2ch"}
:::col
## One hit

The cache holds one image; a hit reads it from disk and never starts the renderer.
:::col
The note beside it is an ordinary paragraph; the column decides its width.
:::
```

`:::layout`, `:::flex` and `:::card-grid` all lay out columns, for different purposes:

| Container | Purpose |
| --- | --- |
| `layout` | Page-level layout; a column holds a complete document flow |
| `flex` | Proportional split inside a block, a figure beside its note |
| `card-grid` | Equal-width cards, a group of material with clear boundaries |

The rule is to pick the narrowest one that works. Use `flex` rather than `layout` when you can, and one column rather than two.

### 4.13 Planned: proportional row

`:::flex` arranges children horizontally inside a block; children are `:::item`.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `gap` | length | `"2ch"` | Space between children |
| `align` | enum | `start` | `start`, `center`, `end`, `stretch` |
| `justify` | enum | `start` | `start`, `center`, `end`, `between` |
| `wrap` | bool | `false` | Wrap when the row does not fit |

An `:::item` takes a `grow` parameter for its share; items without one split the remainder.

### 4.14 Planned: alignment

`:::align` takes `to`: `left`, `center` or `right`.

```markdown
:::align {to=center}
![A cache hit](figures/hit.png)
:::
```

`justify` is not implemented. A character grid has no inter-word space to stretch, so justified text can only pad with blanks, and the padding leaves ragged holes at the end of Chinese paragraphs.

### 4.15 Planned: file tree

`:::file-tree` draws an indented list as a directory tree.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | One title line above the tree |
| `marker` | enum | `ascii` | Mark style: `ascii`, `none` |

```markdown
:::file-tree {title="lisp/"}
- lisp/
  - etaf-md-model.el
  - etaf-md-views.el
- etaf-md.el
:::
```

The case it solves: saying what a directory holds. A fenced block can show the same thing, but its tree lines have to line up with the indentation, and hand-written ones are off by a cell sooner or later. The marks are ASCII (`+`, `-`, `|`, `` ` ``) because those occupy exactly one cell in every monospace font.

### 4.16 Planned: chat

`:::chat` draws a conversation as messages split left and right, each with a sender and a time.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `me` | enum | `left` | Which side the reader's own words take: `left`, `right` |

```markdown
:::chat
:::said {from="Q" time="14:20"}
Why does the preview not refresh?
:::said {from="A" time="14:21"}
It refreshes after a save; a half-finished edit does not reflow.
:::
```

The case it solves: a tutorial demonstrating one exchange, or a log of a debugging conversation. It is aligned text with an indent, and no bubble graphic is needed.

### 4.17 Planned: table additions

Plain pipe tables already work. A container is planned to add two things:

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | A numbered title above the table |
| `hl-rows` | string | none | Highlighted rows, e.g. `warn:2,3` |
| `hl-cols` | string | none | Highlighted columns, e.g. `accent:1` |

The reason: the two commonest table needs are "give it a title" and "mark the row to watch". A paragraph of prose around the table cannot do either.

### 4.18 Planned: demo window

`:::window` draws a title bar over a block, with three dots and a title.

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | Title bar text |
| `height` | length | computed | Content height |

This one is a transformation of plume's `window`. Plume draws a macOS window with rounded corners and a shadow; we draw a single title bar, with three `·` marks and a centred title. The reason: rounded corners and shadows cannot be drawn on a character grid, and forcing them produces a row of stray glyphs. Three dots and a rule already say "this is a piece of interface".

### 4.19 Not absorbed

These are containers in plume that we decline. The reasons fall into three groups.

**Needing a browser runtime.** These render a page that runs code, or a remote frame:

| Plume container | Why not | Instead |
| --- | --- | --- |
| `code-pen`, `jsfiddle`, `code-sandbox`, `repl` | Requires executing code in a browser; the previewer runs no scripts | A fenced block and a link |
| `embed-frame`, `video-embed` | Embeds a remote page or player, needing a network and a browser | A link, or a local video card |
| `pdf` | Needs a PDF renderer | A link |
| `qrcode` | Needs image generation and a scannable result | A link |
| `plot` | Needs JavaScript plotting | Draw it with mermaid, or paste an image |
| `caniuse` | Fetches remote data | A table |
| `npm-to`, `lang-repl` | Needs a package manager and an interpreter | The command and its output |

**Needing images and gradients.** `annotation` draws marks on an image, `abbreviation` needs a hover popup, and the `background` family needs gradients and particles. On a character grid these come out as blocks of glyphs, so they are better left out.

**Meaning that does not belong to this package.** `encrypt` decrypts in the front end: `:::encrypt` makes the browser wait for a password. Emacs has epa and gpg, but that is file-level encryption, not a container in a previewer's syntax. A document that must stay secret does not belong in a preview.

## 5. The layout model

### 5.1 Rows, columns, grids

Three atoms, mapping onto what Ebox already provides:

| Atom | Built from | Main properties |
| --- | --- | --- |
| Row | `flex` in the `row` direction | `:flex-basis`, `:flex-grow`, `:align-items` |
| Column | `column` | `:item-gap`, `:align-items` |
| Grid | `grid` | `:grid-template-columns`, `:column-gap`, `:row-gap` |

Grid tracks accept what Ebox already accepts: pixels, `ch`, `lh`, `min-content`, `max-content`, `auto`, `(fr N)`, `(minmax MIN MAX)` and `(repeat N TRACK)`. A container's `fr` maps onto a fractional track, and `gap` maps onto `:column-gap` and `:row-gap`.

### 5.2 Gaps and padding

- `gap` only separates siblings; it never applies outside them. The outer ring belongs to the container's own padding, and adding both gives double spacing and visibly misaligned boundaries.
- `pad` takes one length and applies it on four sides; `pad-x` and `pad-y` give the axes separately.
- Units are `ch`, `lh`, `px` and `%`. `ch` follows the font width and `lh` follows the line height, so both track a machine whose type size changes.
- Vertical spacing inside a block uses whole multiples of `lh`. Pixels would misalign the line spacing and put borders on top of glyphs.

### 5.3 Narrow windows

When a window is too narrow for side-by-side columns, the layout degrades in order, never scrolling sideways:

1. **Fewer columns.** `cols=3` drops to 2, then to 1.
2. **Stacking.** When a `layout` column falls below `min`, the whole block stacks into one column with a blank row between former columns.
3. **Tighter padding.** Padding drops from 2ch to 1ch, and the container's frame stays.
4. **Same marks.** Step numbers and card title rows stay; only the spacing tightens.

Nothing is dropped and no type size shrinks. The reason: shrinking type makes one document read differently in a narrow window, and resizing a window should not change the type size.

### 5.4 How tokens and type size are inherited

- A container declares no type size. It inherits the page's body size.
- Colours come from tokens only. ETAF UI components inside a container follow the page's `:ui-*` tokens, so cards, tabs and callouts change together on a theme switch and none stays on the old palette.
- Borders default to 1px of `border` and accent bars to 3px of the semantic colour. Both are fixed in the component and are not container parameters: border weight is one of the few legible steps, and exposing it would let a page mix 1px, 2px and 3px side by side.
- Nested fills alternate: `panel` on the first level, `panel2` on the second, `panel` again on the third. The reason: the same fill three levels deep reads as one flat block, and the reader loses the boundaries.

## 6. User definitions

### 6.1 The shape of a definition

A definition is data, not code inside a document. It looks like this:

```elisp
(etaf-md-define-container
 'card
 :summary "A titled card"
 :params '((title :string "" "Card title")
           (tone (enum panel quote accent danger) panel "Fill")
           (cols (enum 1 2 3) 1 "Body columns"))
 :body (lambda (params body env)
         (etaf-node 'box
                    (list :width 'stretch
                          :gap '((lh 1) (ch 0))
                          :padding '((lh 1) (ch 2))
                          :background-color (etaf-md-token env 'panel)
                          :border-left (list '(px 3) 'solid
                                             (etaf-md-token env 'border)))
                    (append
                     (when-let* ((title (plist-get params :title)))
                       (list (etaf-node 'text (list :weight 'bold) (list title))))
                     body))))
```

Four fields:

| Field | Purpose |
| --- | --- |
| The name | The first argument, a symbol. `:::card` in a document looks it up |
| `:summary` | One line, used only in help and errors |
| `:params` | The parameter table; each entry is `(name type default docstring)` |
| `:body` | A function taking three arguments and returning an ETAF view |

What `body` receives:

- `params`: a validated plist. Omitted parameters hold their defaults and types are already converted, so a `number` is a number and a `bool` is `t` or `nil`.
- `body`: the parsed content as a list of views, not a string. A definition decides placement and never touches parsing.
- `env`: the rendering environment. Read a colour with `(etaf-md-token env 'panel)` and the line height of the current type size with `(etaf-md-token env 'lh)`.

### 6.2 Where it lives, when it is read

- Definitions are `.el` files in a user directory, named in `etaf-md-container-directory`.
- A session reads the registry once when it is created and does not touch the disk again. A changed definition needs `r` or a fresh preview.
- Definitions load only from the configured directory. A document cannot register a container and cannot run Elisp. The reason: a Markdown file should carry no execution rights, and sharing a document must not mean sharing code.
- A duplicate name is an error rather than a silent override. Replacing a shipped definition takes `:replace t`, and the error line names the definition being replaced.

### 6.3 Debugging

- `etaf-md-describe-containers` lists the registry: name, summary, parameters and the file it came from. Planned.
- The error line is always on the page, so no log has to be opened.
- When a definition itself signals, that block degrades to its source plus a line reading "the `card` definition failed: …", and the rest of the page keeps rendering.
- `etaf-md-doctor` reports how many containers are registered and whether a definition file failed to load. Planned.

### 6.4 Versions and portability

- Every definition declares `:contract 1`. When the contract version does not match, that block degrades and says so.
- A document opened on a machine without the definition degrades under the 3.3 failure rule. The prose still reads and the missing block stays visible.
- Definitions are not stored in a document, so the same document elsewhere loses effects instead of changing shape.
- Token names are part of the contract. New tokens may only be appended; a rename is a breaking change and bumps the contract version.

## 7. The roadmap

Six steps. Each one's acceptance has three parts: ERT scenarios, counter-examples, and a real GUI capture.

| Step | Content | Acceptance |
| --- | --- | --- |
| 1 | The `:::` scanner: open, close, nesting, depth limit, unknown-name degradation | Scenarios for three levels and for the limit; an unclosed container keeps its source; a GUI capture beside the source block |
| 2 | Parameters: seven types, validation, error lines | Two positive and one negative case per type; three errors in one block; correct line numbers |
| 3 | Layout: `layout`, `col`, `flex`, `item`, `gap`, `pad`, narrow-window degradation | Captures at wide, medium and narrow widths; declared track ratios hold; nothing is lost after degrading |
| 4 | Content containers: `card`, `steps`, `collapse`, `field`, `timeline`, `stats`, `card-grid` | Each renders in all three palettes; no type size is set; nested fills alternate |
| 5 | Interactive containers: `tabs`, `code-tabs`, `accordion` | Keys go through the command loop (`execute-kbd-macro`); a switch does not rebuild the page; the selected tab takes no hover fill |
| 6 | Registry and user definitions: `define-container`, directory, contract version, help | A sample definition installs and uninstalls; uninstalling degrades; a contract mismatch is reported |

Step 1 first rewrites the GitHub alert as one container definition, which is how equivalence gets checked. The criterion is that the same document produces byte-identical buffer text before and after the rewrite; any difference means the contract is missing something.

The gate for each step: `make check` passes, the affected tests are green, and a GUI capture has been looked at. A capture is evidence, not a test; behaviour assertions and visual review stay separate.

## 8. Risks and non-goals

**Risks.**

1. **Layout cost.** Every level of container measures once. A document with twenty containers will visibly raise the cost of a reflow. Mitigation: each container is its own Component and only a changed one repaints, and a layout change reflows the affected subtree alone.
2. **Interaction state.** Tabs and collapsed blocks own state. It must survive a reflow and a theme change, and a search hit must open the block. Each of those needs a scenario.
3. **Narrow windows.** The threshold for dropping two columns to one is hard to set. Too high and ordinary windows become single-column; too low and a horizontal scroll appears. Mitigation: the threshold is the `min` parameter, its default derives from the reading measure, and acceptance happens in a real window.
4. **Definition portability.** A user definition only works on its own machine, so a document degrades elsewhere. That is not a bug, but the document has to say so, or authors will assume the effect ships with the file.
5. **Error noise.** An old document using ten unimplemented containers gains ten muted lines. Mitigation: report each name once and summarise at the top of the page with one line, "3 undefined containers on this page".

**Non-goals.**

- No HTML subset, no CSS subset, no `<style>` tag. Stuffing two layout systems into one renderer blurs the boundary until nobody can say which layer produced a gap.
- No scripts in documents, and no container registration from documents.
- No type-size parameter and no scale parameter.
- No remote frames, remote players or remote code execution.
- No rounded corners, shadows, gradients or animation. On a character grid these can only be faked with special glyphs, and the result is garbled.
- No second document format beside Markdown.

## Appendix A: the plume container map

| Plume | Our decision | Note |
| --- | --- | --- |
| `align` | Absorbed as `:::align` | `left`, `center`, `right` only; no `justify` |
| `flex` | Absorbed as `:::flex` | Ebox flex properties; `gap` becomes a `length` |
| `card` | Absorbed as `:::card` | Rounded corners and shadow become one border and a `panel` fill |
| `card-grid` | Absorbed as `:::card-grid` | `cols` is an integer; no pixel spelling for `gap` |
| `card-masonry` | Declined | Row heights are fixed, so packing yields a grid |
| `steps` | Absorbed as `:::steps` | Number plus title, mapped to `etaf-steps` |
| `tabs` | Absorbed as `:::tabs` | Keyboard reachable; a switch repaints one block |
| `code-tabs` | Absorbed as tab default behaviour | The label comes from the fence language; no new container |
| `collapse` | Absorbed as `:::collapse` | Adds `accordion` and isearch auto-expansion |
| `field` | Absorbed as `:::field` | Auto-aligned name column, two-column grid |
| `timeline` | Absorbed as `:::timeline` | Optional marks, mapped to `etaf-timeline` |
| `table` | Partly absorbed | `title` first; row highlighting later |
| `file-tree` | Absorbed as `:::file-tree` | ASCII marks only; an indented list becomes a tree |
| `code-tree` | Declined | Overlaps `code-tabs` plus `file-tree` |
| `chat` | Absorbed as `:::chat` | Alternating sides and indentation; no bubbles |
| `window` | Absorbed with a change, as `:::window` | Title bar only; no rounded corners or shadow |
| `encrypt` | Declined | A document that must stay secret does not belong in a preview |
| `npm-to`, `lang-repl` | Declined | Needs a package manager and an interpreter |
| `plot`, `qrcode`, `pdf` | Declined | Needs plotting and image generation |
| `annotation`, `abbreviation` | Declined | Needs marks over an image and a hover popup |
| `code-pen`, `code-sandbox`, `repl`, `caniuse` | Declined | Needs a browser and a network |
