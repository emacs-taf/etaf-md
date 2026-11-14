# Extension syntax

> **Status.** The only extension the page renders today is the GitHub alert block: `> [!NOTE]`, `> [!TIP]`, `> [!IMPORTANT]`, `> [!WARNING]`, `> [!CAUTION]`. Everything else here is a design contract: it fixes the model, the syntax, the attributes and the acceptance before the code exists. Any name marked *planned* does not exist today, and its function names are proposals.
>
> **How to read it.** Writing a document: chapters 3, 5 and 6. Writing a container definition: chapters 9 and 10. Implementing the renderer: chapters 2, 7, 8 and 11. What works today: the status table in 6.16. Why a name is spelled that way: Appendix E.
>
> The Chinese and English versions run section for section. Change one, change the other.

## Quick reference

This is all a writer needs.

**Two rules.** `:::name {attrs}` opens a block, a line holding `:::` alone closes the one opened last. The last block in a file may omit its closing line.

A block container:

````markdown
:::card {title="Cache hit"}
Images and figures scale with the page instead of being redrawn.
:::
````

A parent container. A child name is interpreted by its parent, so `:::tab` means nothing outside `tabs`:

````markdown
:::tabs
:::tab {title="Emacs 29"}
Uses the old `image-size` signature.
:::
:::tab {title="Emacs 30+" selected=true}
Passes the buffer directly.
:::
:::
````

**The attributes that carry most documents.**

| Attribute | Type | Written on | Example |
| --- | --- | --- | --- |
| `title` | string | Containers and children | `title="Cache hit"` |
| `description` | string | card | `description="One line of summary"` |
| `surface` | surface | box, card | `surface=raised` |
| `accent` | accent | box, card, callouts | `accent=warning` |
| `text-align` | align | box, card | `text-align=center` |
| `columns` | number or string | columns, stats | `columns="2fr 1fr"` |
| `gap` | length | columns | `gap="2ch"` |
| `padding` | length | box, columns | `padding="1lh"` |
| `open` | boolean | collapse, callouts | `open=true` |
| `selected` | boolean | tab | `selected=true` |
| `list-style` | enum | steps, timeline, file-tree | `list-style=decimal` |
| `href` | string | card | `href="#install"` |

**Five surfaces:** `none`, `page`, `raised`, `sunken`, `quote`. **Six accents:** `neutral`, `primary`, `success`, `warning`, `danger`, `important`.

A length always carries its unit, `2ch` or `1lh`; a bare `2` is wrong. A document never names a colour or a type size; the reader's theme and style table decide those.

When an attribute name slips your mind, ask `etaf-md-describe-nodes`, or turn on `etaf-md-edit-mode` and let completion answer.

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

### 2.1 One thing: the node

A document is a sequence of nodes. A node has a type, attributes and children. A paragraph, a heading, a code block, a table and a container are all nodes; only the type differs.

The parser knows three things: opening, closing and nesting. It does not know what `card` means, nor which attributes it takes. The registry owns the names, the definitions own the attributes, and the renderer owns the placement.

### 2.2 One model

The system has one kind of thing: the node type. Text types and container types sit in the same table and go through the same `etaf-md-define-node`.

| Type | Can a document write it? | Examples |
| --- | --- | --- |
| The parser makes it | No, it has no name | `heading`, `quote`, `code`, `table` |
| A document writes it | `:::name` | `card`, `tabs`, `columns` |

The only difference is that **a type a document can write has a name** (the definition's `:name`). `heading` has none, so `:::heading` does not exist and only `###` makes one.

A type that takes a fixed set of children declares `:accepts`, such as `columns` taking `col`. A type without it takes anything: a `card` holds paragraphs, code, tables, another container.

**A child is not a type and has no definition of its own.** Its name is interpreted by the parent's `:accepts`, and the parser does not recognise it. So `:::tab` inside `tabs` is a tab, and `:::tab` at the top of a page is a line nothing can explain, reported by the failure rule.

The relationship does not cross layers. A `tab` may hold a `card`, but a `tab` may not hold another `tab`. To nest, wrap another `tabs`.

### 2.3 Four extension points

The system has four layers, each with different rights.

| Layer | Decided by | Changes | Open? |
| --- | --- | --- | --- |
| Syntax | The package's parser | How text becomes nodes | No |
| Structure | The document and node definitions | A new type, the attributes it takes | Yes, chapter 10 |
| Appearance | The reader's style table | Colours, weight, prefixes, spacing, numbering | Yes, 4.3 |
| Rendering | The reader's functions | What one node is painted as | Yes, 10.4 |

The four share one node model: `(type attributes children)`. A text node and a container node have the same shape in that table: `heading` is a node whose type is `heading` and which carries a `level` attribute; `card` is a node whose type is `card` and which carries `title`.

One more thing: **a definition can itself be overridden.** A reader may add attributes to a type, replace its rendering, or replace the whole definition. Added keys are reader-side only; the document-side attribute table stays closed; see 10.5.

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

### 2.6 The naming rules

Names live in five namespaces. Each namespace has exactly one authority, and a new name has to be traceable in Appendix E; if it is not, it does not get added.

| Namespace | Written by | Authority | Examples |
| --- | --- | --- | --- |
| Document attributes | The document author | HTML attribute names, plus props the mainstream component libraries share | `title`, `href`, `open`, `selected`, `padding`, `columns` |
| Types | Whoever writes a definition | JSON Schema plus CSS value types | `string`, `number`, `boolean`, `length`, `enum` |
| Tokens | The renderer | One shadcn/ui semantic token set | `background`, `foreground`, `surface-raised`, `primary` |
| Style keys | The reader | CSS property names | `background`, `color`, `font-weight`, `margin-top` |
| Functions | The package author | Verb plus object, one verb one meaning | `etaf-md-render`, `etaf-md-follow-link` |

Five rules.

1. **No abbreviations.** Write `background`, not `bg`; `columns`, not `cols`; `padding`, not `pad`. Only `id` and `href` are exempt, because those are HTML's own spelling.
2. **No numbering.** Write `surface-raised`, not `panel2`; `primary`, not `accent-1`.
3. **One word, one meaning.** `accent` is always an accent value, never a token; `surface` is always a surface, and the style key is `background`, never `surface`.
4. **Values use standard words.** `decimal`, `lower-roman` and `bullet` come from CSS `list-style-type`; `boolean` comes from JSON Schema.
5. **Look first, then borrow.** If the meaning already has a word, reuse it; if not, borrow one from the authority; invent only when nothing fits, and say why in Appendix E.

## 3. Syntax

### 3.1 Opening and closing

````markdown
:::card {title="Cache hit" surface=raised}
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

### 3.2 Children

A child is written exactly like a container; only its name is interpreted by the parent type. The parent type declares `:accepts`, which decides the names it takes and the attributes that apply.

````markdown
:::columns {columns="2fr 1fr" gap="2ch"}
:::col
The left column is ordinary Markdown.
:::
:::col
So is the right one.
:::
:::
````

A parent type must handle three edge cases without crashing or painting half a block.

- **No children**: paint its own empty state, no error.
- **Children out of order**: interpret them in source order, never reorder.
- **A child missing a required attribute**: that child degrades; the others still render.

### 3.3 Attributes

Eight types. Every type selects from this one table.

| Type | Spelling | Meaning | Invalid |
| --- | --- | --- | --- |
| `string` | `title="Cache hit"` | Text. Quote it when it contains spaces; `\"` escapes a quote | `title=cache hit` |
| `number` | `start=2` | Integer or decimal, optionally signed | `start=two` |
| `boolean` | `open=true` | `true` or `false`, nothing else | `open=yes` |
| `length` | `gap="2ch"` | A number with a unit: `ch`, `lh`, `%` | `gap=2` |
| `surface` | `surface=raised` | Fill: `none`, `page`, `raised`, `sunken`, `quote` | `surface="#24262a"` |
| `accent` | `accent=warning` | Emphasis: `neutral`, `primary`, `success`, `warning`, `danger`, `important` | `accent=urgent` |
| `align` | `text-align=center` | Horizontal position: `start`, `center`, `end` | `text-align=middle` |
| `enum` | `list-style=decimal` | One of the words the attribute declares | `list-style=number` |

A string takes one optional modifier, written beside `:type`.

| Modifier | Meaning | Example |
| --- | --- | --- |
| `:pattern` | The value must match this regular expression | `(id :type string :pattern "^[a-z]+$" :doc "Anchor")` |

A fixed word list is `enum`, not a `string` with `:one-of`.

Five conventions.

- **Attribute names are shared.** `title` means the same in a card, a callout, a collapse and a demo window. A type selects from the vocabulary and never invents `heading` or `caption`.
- **One name, one type.** `columns` is always either a count or a track list, never anything else. The same name changing type between types is forbidden.
- **No unit, no length.** `gap=2` is wrong and `gap="2ch"` is right. One bare number could mean characters, lines or percent, and guessing wrong mislays the layout once per guess.
- **Booleans accept neither `yes` nor `1` nor `on`.** Only `true` and `false`. Three spellings mean three parse branches.
- **Exactly one union type is allowed.** `columns` writes `number or string`, because "how many columns" and "a track list" are two forms of one concept, and splitting them into two names would make the author remember two words. No other union type.

Validation converts each value into the shape the renderer wants, so a definition never parses a unit.

| Type | Written as | The value a definition receives |
| --- | --- | --- |
| `string` | `title="Cache hit"` | The string `"Cache hit"` |
| `number` | `start=2` | The number `2` |
| `boolean` | `selected=true` | `t` or `nil` |
| `length` | `padding="1lh"` | ETAF's length `(lh 1)`, ready to pass as a property |
| `surface` | `surface=raised` | The symbol `raised` |
| `accent` | `accent=warning` | The symbol `warning` |
| `align` | `text-align=center` | The symbol `center` |
| `enum` | `list-style=decimal` | The symbol `decimal` |

Writing the same attribute twice is an error, not a last-one-wins. The reason: a duplicate usually means the author changed half of it, and silently picking one hides the problem.

Two permissions, both expressed as data rather than memory.

| Permission | Who holds it | How it is written |
| --- | --- | --- |
| May the document write it | The document | Yes by default; the ones it cannot write carry `:derived t` in the definition |
| May the reader override it | The style table | Decided by the type: `surface`, `accent` and `align` can be overridden, the other five cannot |

The clearest example of the first row is a heading's `level`: a document cannot write it, `###` decides it, so it is a derived attribute. The style table can still select on it (`(:level 1 :prefix "◆ ")`).

Two words cover both classes: a **document attribute** is written inside the braces; a **derived attribute** comes from the parse or derive stage.

The shared attribute table is Appendix A; types only reference it. How a definition declares these types is 10.2.

### 3.4 Validation, degradation and the failure catalogue

Validation runs once, before a view is built, and reports every error in the block together. An error is a muted line above the block's source, numbered by the line that opened the container.

````markdown
:::card {title="Cache hit" colour=blue surface="#24262a"}
Content
:::
````

```
line 42: card does not take "colour"; it takes title, description, surface, accent, href, text-align, width
line 42: card received surface="#24262a"; it takes none, page, raised, sunken, quote
line 44: nesting depth 9 exceeds the limit of 8
```

Failures come in fourteen kinds. Each has a determined page result; none is "it depends".

| Case | Page | Scope |
| --- | --- | --- |
| Unknown name | Source plus one line | This block |
| Unknown attribute | Source, and the line lists what it takes | This block |
| Invalid value | Source, and the line gives the value and one valid example | This block |
| Missing required attribute | Source, and the line names it | This block |
| Duplicate attribute | Source, and the line names the duplicate | This block |
| Child outside its parent type | Source, and the line names the `:accepts` that takes it | This block |
| Container in a place it cannot go | Source, and the line says it belongs at the top level or inside container content | This block |
| Child missing a required attribute | Source; the parent keeps parsing the rest | This child |
| Parent without children | Empty state, no error | This block |
| Two children claim `selected` | Only the first counts, with one line saying so | This group |
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

### 3.6 Editing the source buffer

A rendered page carries no markup, so the whole cost of it falls on the writer. Everything here happens in the source buffer. It changes neither the syntax nor the rendered result.

Four layers, in order of payoff. All four form one optional minor mode named `etaf-md-edit-mode`, off by default.

| Layer | What it does | What it fixes |
| --- | --- | --- |
| One | Push the markup back: `:::`, the braces and the equals sign in `markdown-markup-face`; the container name in the language keyword face; attribute names and values in two different faces | The colons stop competing with the prose |
| Two | Pair hint: while point is inside a container, its opening and closing lines are each lifted one step; both fall back on leaving | No counting which colon matches which |
| Three | Insert and complete: one command writes the opening line, a blank line and the closing line; container names and the attributes each container takes complete in place | Names and attributes need not be memorised |
| Four | Fold: keep the container's opening line only | Read structure first in a long document |

Four hard constraints, each one a test of "hurts no existing Markdown habit".

1. **Add, never replace.** The new font-lock rules match `^:::` and the attribute braces only; markdown-mode has no rule for either today, so nothing is overridden. Its keymap, indent function, `electric-pair` and `markdown-hide-markup` stay untouched.
2. **Never change buffer text.** Dimming, lifting and folding are faces, overlays and the `invisible` property only; `buffer-string` is identical before and after. Otherwise saving writes a different file.
3. **Off means gone.** Disabling removes the font-lock keywords, deletes the overlays, clears the hook and drops its `completion-at-point-functions` entry. A test asserts that `font-lock-keywords` after an enable-and-disable cycle is `equal` to what it was before.
4. **Never take a key.** Only its own prefix; no existing command is remapped.

Performance budget, measured the same way as 8.3.

| Action | Budget | What guarantees it |
| --- | --- | --- |
| Open a 2000-line document | 50 milliseconds of extra work at most | font-lock runs per chunk, never over the whole file |
| Move point to another line | 5 milliseconds at most | computed once per line change |
| Typing inside one line | no pair computation at all | the previous row |
| Idle | no timers | no polling, no background refresh |
| Fold and unfold | one overlay added or removed | text is never touched |

The pair hint has to find the container's opening line, so it has a line limit. One backward search in a document of a few thousand lines, skipping the hint beyond that limit; never an unbounded reverse scan.

Three places it cannot help, recorded here so it is never mistaken for a promise: on GitHub, in someone else's editor, and in a fragment pasted elsewhere. The syntax therefore has to read well as bare text; this section is only a bonus, and it is never a reason to add syntax.

## 4. Appearance and style

### 4.1 Surface and accent

Appearance has two attributes: `surface` for the fill, `accent` for the accent colour. They are separate words because they are separate things. Every value of both maps onto exactly one token, with no exceptions; see Appendix B.

| `surface` | Token | Used for |
| --- | --- | --- |
| `none` | No fill | Default. Cards in prose, blocks side by side |
| `page` | `background` | Places that must separate from the prose |
| `raised` | `surface-raised` | Code blocks, cards that need a boundary |
| `sunken` | `surface-sunken` | Table headers, stripes, secondary information |
| `quote` | `quote` | Quotation-like blocks |

| `accent` | Foreground | Soft fill | Meaning |
| --- | --- | --- | --- |
| `neutral` | `foreground` | `surface-raised` | No emphasis |
| `primary` | `primary` | `primary-soft` | Note, link |
| `success` | `success` | `success-soft` | Success, advice |
| `warning` | `warning` | `warning-soft` | Caution |
| `danger` | `danger` | `danger-soft` | Danger |
| `important` | `important` | `important-soft` | Important |

One accent value decides the accent colour and the soft fill only. It never changes type size, weight or line height. For stronger emphasis, change the accent value, do not stack effects.

### 4.2 Tokens

A token is a name inside the renderer. A document writes `surface=raised`, never the `surface-raised` token, and certainly never a colour value. The names come from shadcn/ui, because that is today's most widespread semantic token set.

| Token | Use |
| --- | --- |
| `background` | Page background |
| `foreground` | Body text |
| `muted` | Secondary text and notes |
| `faint` | The weakest layer: numbering, separators |
| `border` | Borders and rules |
| `surface-raised` | A raised surface: cards, code blocks |
| `surface-sunken` | A sunken surface: table headers, stripes |
| `quote` | Quote fill |
| `quote-bar` | The quote's left bar |
| `table-header` | Table header |
| `table-stripe` | Table stripe |
| `heading` | Headings |
| `primary` / `primary-soft` | Informational |
| `success` / `success-soft` | Success |
| `warning` / `warning-soft` | Caution |
| `danger` / `danger-soft` | Danger |
| `important` / `important-soft` | Important |

Every token has a value in all three palettes, and the face-derived mode computes them from the active frame. A container declares a surface and an accent, and follows the palette when it changes.

**Why no hexadecimal.** A `#24262a` that looks right on a dark page is a black blot on a paper-coloured one. A hexadecimal value is an error, and the error line lists the semantic words that attribute accepts.

### 4.3 The style table

The style table is where a reader changes appearance. One table, keyed by node type, with CSS property names as keys.

```elisp
(setq etaf-md-styles
      '((heading . ((:font-weight bold :color heading)      ; every level
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

Colours have two names plus one naming rule.

| Key | Type | Meaning |
| --- | --- | --- |
| `background` | A surface, or a colour value | Fill |
| `color` | A token, or a colour value | Ink |
| `<part>-background` | A surface, or a colour value | A part's fill, e.g. `header-background` |
| `<part>-color` | A token, or a colour value | A part's ink, e.g. `label-color` |

Four rules.

- **Omitted inherits, `nil` disables, `:default` resets to the shipped value.** Three answers to "how do I undo this". `(:level 1 :prefix nil)` drops the level-1 prefix; deleting `:prefix` entirely inherits it from the node entry; `:color :default` goes back to the shipped colour whatever the node entry said.
- **An entry opens with a selector, and the selector is an attribute name.** `(:level 1 :prefix "◆ ")` means "when this node's `level` is 1". No selector means the whole type. `level` carries no privilege: any type that declares an attribute of that name can be selected this way, and an undeclared name never matches.
- **Every key has one type.** An unknown key is an error at load; that node type falls back to the shipped style and the page still renders.
- **The shipped styles live in this table too.** No literal colour values in the code, so what you change and what you see are the same thing.

Two sources supply the keys: the global table in Appendix C, and the type's own overridable attributes (the `surface`, `accent` and `align` types). So a card's `accent` is written here as `(:accent warning)`, with no second key name invented for it.

`etaf-md-set-style` writes into this same table, not a second one. When a key is written in both places, the later one wins. Passing `nil` removes the entry and restores the shipped value.

Editing the table repaints the page and re-derives it, but never re-parses it; see 8.2. Giving a type a new key takes a render function, see 10.4.

### 4.4 Two colour rights

| Who | May write | Why |
| --- | --- | --- |
| The document | Semantic words such as `surface=raised`, `accent=warning` | A document has to read on any theme and any machine |
| The reader's style | A surface or token name, or a literal `"#ff0000"` | The reader owns their page |

A literal has a cost: it stops following the theme. A blue chosen on a dark page may be unreadable on a paper-coloured one. So a document never writes a literal, and that is a hard rule.

**Which attributes a reader may override is decided by the attribute's type.** `surface`, `accent` and `align` are overridable by nature; the other five listen to the document alone. So "which attributes are appearance" needs no flag and cannot be flagged wrong.

A derived attribute (`:derived t`) is a different matter: a document cannot write it, because the parse or the derive step supplies it, such as a heading's `level`. The style table may still use it as a selector.

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

There is one way to make columns: `columns`. The former `layout`, `flex` and `card-grid` merge into it, because their differences were only defaults. One attribute takes two forms: a number for equal columns, a track list for proportions.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `columns` | number or string | none | A number of equal columns, or a track list in `fr`, `ch` or `%` |
| `gap` | length | `"2ch"` | Space between columns |
| `padding` | length | none | Padding on all four sides |
| `min-width` | length | `"24ch"` | Smallest column; below it the columns stack |
| `align-items` | enum | `stretch` | Cross-axis alignment: `start`, `center`, `end`, `stretch` |
| `justify-content` | enum | `start` | Main axis: `start`, `center`, `end`, `between` |
| `wrap` | boolean | `false` | Wrap when it does not fit instead of stacking |
| `align-self` | enum | `start` | The container's own horizontal position: `start`, `center`, `end` |

The child is `col`, with one attribute.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `grow` | number | `1` | Share of the remaining width |

````markdown
:::columns {columns="2fr 1fr" gap="2ch"}
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
:::columns {columns=3}
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

- `columns=3` is three equal `1fr` columns.
- `columns="2fr 1fr"` is an explicit track list, in Ebox spelling: `(fr 2)` is written `2fr`, a fixed width `20ch`, a percentage `30%`.
- `gap` separates siblings only, never the outside. The outside ring belongs to `padding`.
- `padding` takes one length and applies it on four sides. No `padding-x` or `padding-y`: splitting the axes lets one page show two different paddings.
- Vertical spacing uses whole multiples of `lh`. Pixels would misalign the line spacing and put borders on top of glyphs.

### 5.3 Narrow windows

When side-by-side columns do not fit, the layout degrades in order, never scrolling sideways.

1. **Fewer columns.** `columns=3` drops to 2, then to 1, with every column at least `min-width`.
2. **Stacking.** With a track list, a column below `min-width` stacks the whole block into one column with a blank row between former columns.
3. **Tighter spacing.** `padding` drops from 2ch to 1ch and `gap` from 2ch to 1ch; the frame stays.
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
| Callouts | `note`, `tip`, `important`, `warning`, `caution` | One definition, five fixed accent values |
| Collections | `steps`, `timeline`, `stats`, `field`, `file-tree`, `chat` | Children carry labels and are ordered or named |
| Interaction | `tabs`, `code-tabs`, `accordion` (child `collapse`) | Stateful, switchable by key |
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
| `collapsible` | boolean | `false` | Allow the block to collapse |
| `open` | boolean | `true` | Whether it starts expanded |

```markdown
:::warning {title="Compatibility" collapsible=true}
This only works on Emacs 30 and later.
:::
```

Both spellings render the same thing, from the same definition. The name-to-accent mapping is fixed: `note` to `primary`, `tip` to `success`, `important` to `important`, `warning` to `warning`, `caution` to `danger`.

Why keep both. A document pasted from GitHub works immediately, which is the commonest entry; a long document written with containers aligns with the other containers and can carry attributes.

### 6.3 Card

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | Title; omit it and there is no title row |
| `description` | string | none | One muted summary line under the title |
| `surface` | surface | `raised` | See 4.1 |
| `accent` | accent | `neutral` | See 4.1 |
| `href` | string | none | The whole card activates and opens this target |
| `text-align` | align | `start` | Horizontal position of its content |
| `width` | length | `stretch` | Its own width |

The case it solves: a group of parallel material needs one boundary. A section heading lifts it to the level of a section, and a list flattens a figure into one item.

Component: `etaf-card`, whose default slot takes the body and whose `title` and `description` map directly. `surface` needs the component to accept a fill, which is a component-side change; see 9.6.

### 6.4 Box

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `surface` | surface | `none` | See 4.1 |
| `accent` | accent | `neutral` | See 4.1 |
| `padding` | length | none | Padding |
| `text-align` | align | `start` | Horizontal position of its content |
| `width` | length | `stretch` | Its own width |

A box is a card without a title. Centring a figure is what it is for.

```markdown
:::box {text-align=center padding="1lh"}
![A cache hit](figures/hit.png)
:::
```

### 6.5 Steps

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `start` | number | `1` | First number |
| `list-style` | enum | `decimal` | `decimal` for digits, `bullet` for a dot |

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
| `list-style` | enum | `bullet` | `bullet`, `decimal`, `none` |

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

The body is a list; the text before the first colon is the name. It corresponds to HTML's description list, `<dl>`.

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
| `columns` | number | `3` | Numbers per row; a narrow window reduces it |

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

The number takes `foreground` in bold, the caption `muted`. A fourth entry wraps instead of shrinking text. Component: `etaf-statistic`.

### 6.9 File tree

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | One title line above the tree |
| `list-style` | enum | `tree` | `tree` draws the lines, `none` keeps indentation only |

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

Component: `etaf-tree`.

### 6.10 Chat

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `self` | enum | `left` | Which side the reader's own words take: `left`, `right` |

The child is `message`, with a required `from` and an optional `time`.

````markdown
:::chat
:::message {from="Q" time="14:20"}
Why does the preview not refresh?
:::
:::message {from="A" time="14:21"}
It refreshes after a save; a half-finished edit does not reflow.
:::
:::
````

The case it solves: a tutorial demonstrating one exchange. It is aligned text with an indent, and no bubble is drawn.

### 6.11 Tabs

The child is `tab`, with a required `title` and an optional `selected` (a boolean; one child per group may set it).

````markdown
:::tabs
:::tab {title="Emacs 29"}
Uses the old `image-size` signature.
:::
:::tab {title="Emacs 30+" selected=true}
Passes the buffer directly.
:::
:::
````

When two children both set `selected`, only the first counts and the page says so; see 3.4.

The case it solves: several spellings of one thing in parallel, of which a reader needs one. Three parallel subsections lengthen the outline; tabs occupy one block.

Interaction follows the contract in chapter 7; no rules are restated here. The component is `etaf-tabs`: controlled, with its state supplied by the block.

### 6.12 Code tabs

The same as `tabs`, except the children hold fenced code, and an omitted `title` comes from the fence's language.

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

It is one definition, not new meaning. It renders along the same path as `tabs`; the only difference is where the label comes from by default, which is the language of the first fenced block when `title` is omitted.

### 6.13 Collapse

The child is `collapse`, used inside `:::accordion`, with one open at a time. A single fold is a group of one.

A child's attributes: `title` required (the title while closed), `open` optional (a boolean, `false` by default).

````markdown
:::accordion
:::collapse {title="The complete error"}
```
The long text goes here.
```
:::
:::collapse {title="Version differences"}
:::
:::
````

For one fold, write one child:

````markdown
:::accordion
:::collapse {title="The complete error" open=true}
```
The long text.
```
:::
:::
````

The case it solves: long derivations, long logs, a complete error report. They stay on the page for reference without blocking the way.

Component: `etaf-accordion`, controlled, with `open` and `multiple` supplied by the block.

### 6.14 Table

A plain pipe table already works. This container owns the table's **presentation**, never the table itself: it sets one title line and marks the rows and columns to look at. Without it the table renders as usual, just without a title or emphasis.

With a title as its only job, the name would belong to captions. It also carries highlighting, and a table's alignment and footnotes would land here too, so its duty is wider than a caption and the name stays `table`.

| Attribute | Type | Default | Meaning |
| --- | --- | --- | --- |
| `title` | string | none | One title line above the table |
| `highlight-rows` | string | none | Highlighted row numbers, space separated, e.g. `2 3` |
| `highlight-columns` | string | none | Highlighted column numbers, space separated, e.g. `1` |
| `highlight` | accent | `warning` | Which accent the highlight uses |

```markdown
:::table {title="Opening cost" highlight-rows="3" highlight=warning}
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

| Container | Family | Implementation | Status |
| --- | --- | --- | --- |
| GitHub alert `> [!NOTE]` and its four siblings | Callouts | Primitives | Implemented |
| `note`, `tip`, `important`, `warning`, `caution` | Callouts | Primitives | Planned |
| `box` | Structure | Primitives | Planned |
| `card` | Structure | `etaf-card` | Planned |
| `columns` + `col` | Structure | Primitives, the engine's grid | Planned |
| `steps` + `step` | Collections | `etaf-steps` | Planned |
| `timeline` + `event` | Collections | `etaf-timeline` | Planned |
| `stats` + `stat` | Collections | `etaf-statistic` | Planned |
| `field` | Collections | Primitives | Planned |
| `file-tree` | Collections | `etaf-tree` | Planned |
| `chat` + `message` | Collections | Primitives | Planned |
| `tabs` + `tab` | Interaction | `etaf-tabs` | Planned |
| `code-tabs` + `tab` | Interaction | `etaf-tabs` | Planned |
| `accordion` + `collapse` | Interaction | `etaf-accordion` | Planned |
| `table` | Documents | Primitives | Planned |
| `window` | Documents | Primitives | Planned |

## 7. The interaction contract

### 7.1 Interaction comes from the component

A document cannot give anything behaviour, and neither can a definition. **Something is interactive because a component stands behind it, not because a definition says so.** The definition supplies two things: a per-block state cell, and the callback for when the state changes. Keys, focus and arrow keys all live in the component.

This is the same statement as "components are thick" in chapter 9: `etaf-tabs` already works from the keyboard; `:::tabs` only connects it to a document. So there is no keyword for declaring interactivity, and none is needed.

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
- The default state comes from attributes; `selected` and `open` are enough.

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

### 9.2 From a component to syntax

A new container follows a fixed order of three steps, and the test is the one in 9.1.

1. **Look for a component first.** When `etaf-ui` has one whose semantics fit, the definition writes those three lines of translation and nothing else. This is the common case and the thinnest one.
2. **With no component, and a shape a second place will use, write the component first and wrap it after.** The component goes into `etaf-ui` with its parameters, tests and documentation; the definition shrinks back to translation.
3. **Used exactly once, build it with `etaf-view` inside `:view`.** The DSL is the default; only what it cannot say (a tag or a list known at run time) drops to `etaf-node`. Once a second place needs it, it moves up under 9.6.

Step 3 is not an exception, it is the first implementation. Its risk is staying inside the definition forever, which is why the promotion rule in 9.6 follows it.

**The interface boundary.** `:body` may call public interfaces whose names start with `etaf-`; it may not call the engine's internals, which start with `ebox-`. The same rule already binds applications and components.

**Shipped containers take the same route.** The implementation column in 6.16 names the component each shipped container uses, or says it is built from primitives. A custom container reads that column to decide its own route.

### 9.3 A definition does three things

A type definition writes three things, and no more.

1. **Declare**: which attributes a document may write, at which type and default.
2. **Validate**: the renderer does it uniformly; the definition only declares.
3. **Translate**: the document's semantics (surface, accent, attributes) into component parameters.

```elisp
(etaf-md-define-node 'card
  :name "card"
  :attrs '((title :type string :doc "Card title"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
             (expr (etaf-md-render env (etaf-md-children env)))))))
```

That is the shape, not a complete example. Several attributes, an overridable attribute and a component mapping are shown together in 10.1.

No line in the definition draws a border or sets padding. Those live in `etaf-card`. The definition only turns the document's words into the component's parameters. `variant`'s values are `etaf-ui`'s to define; the mapping here is illustrative.

One hard constraint: **a definition cannot invent a parameter its component does not have.** Making `:::card` accept `surface` means first making `etaf-card` accept a fill, which is a component-side change; see 9.6. The only way around it is to draw a shell inside the definition, which is exactly what 9.5 forbids.

### 9.4 Components take semantic parameters

A component's parameters are written for Elisp, not for documents.

- **No document words.** A component never mentions `:accent` as a Markdown concept, `:container` or `:::card`; no other app should have to understand Markdown.
- **No colour values.** A component takes `surface` and `accent` as semantic roles, never `"#c00"`. Turning a role into a colour happens inside the component, so switching palettes cannot miss a container.
- **Few geometry parameters.** Padding and spacing belong to the component's own defaults; a definition overrides them only when it must.

Counter-examples: a component growing a `:markdown-level` parameter leaks syntax into the component layer; a definition drawing a card border copies the component.

### 9.5 One authority per visual fact

| Fact | Authority |
| --- | --- |
| How headings, quotes, code and tables look | The style table (chapter 4), reader-editable |
| How a container looks | The parameters its definition passes |
| A component's own baseline | The component |
| Colours | Tokens, one set per palette |

Two places that can change one fact is a bug. A component's default is only a baseline the definition may override; a definition's value is the document's default, which a reader may override for appearance attributes, see 4.4.

### 9.6 Two uses promote a widget

A new container's widget may not exist, and the definition builds it from primitives. That is not duplication, it is the first implementation. The risk is that it stays in the definition forever.

The rule: **when a second app needs it, move it into `etaf-ui`**, together with its parameters, tests and documentation. The definition then shrinks back to the three lines of translation.

The test is the one from 9.1: delete it, can anyone else still use it?

### 9.7 Shipped definitions are definitions too

`box`, `card` and `columns` are not special cases in the renderer; they are three definitions in the same registry.

This is what keeps the split honest over time. As long as one container has a private branch in the renderer, the API has never been exercised, and a user will eventually hit a capability only that branch has.

Three consequences.

- Shipped definitions are registered through the same entry, in the package's own loading code.
- A test must replace the shipped `card` with a user definition and still render the page.
- When a component's parameters change, the definition tests go red before a user does.

## 10. Extending

### 10.1 The definition of one type

A definition is data plus one function, not code inside a document.

```elisp
(etaf-md-define-node 'card
  :name "card"
  :summary "A card with a title"
  :attrs '((title  :type string :doc "Card title")
           (accent :type accent :default neutral :doc "Emphasis"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
                      :variant (pcase (etaf-md-attr env :accent)
                                 ('warning 'warning)
                                 ('success 'success)
                                 (_ 'default))
             (expr (etaf-md-render env (etaf-md-children env)))))))
```

| Keyword | Value | Meaning |
| --- | --- | --- |
| The name | A symbol, the first argument | The type name. `heading` and `card` both live in this table |
| `:name` | A string | The spelling a document may write: `"card"` is `:::card`. Omitted means a document cannot write it |
| `:summary` | A string | One line, used in help and errors |
| `:attrs` | An attribute table | Names, types, defaults and permissions |
| `:accepts` | A child table | Which children it takes. With it the type is a parent; without it the content is any block |
| `:view` | A function | `(lambda (env) VIEW)`, the type's default paint |
| `:contract` | An integer, `1` today | The version of the document-side attribute table, see 10.5 |
| `:extends t` | A flag | Keep the shipped definition and add, see 10.5 |
| `:replace t` | A flag | Drop the shipped definition and rewrite it, see 10.5 |

A heading has no `:name`, so `:::heading` does not exist; its level is a derived attribute:

```elisp
(etaf-md-define-node 'heading
  :attrs '((level :type number :derived t :default 1))
  :view #'etaf-md-heading-view)
```

A document cannot write `level`; how many `#` characters there are decides it. The style table can still select on it, see 4.3. That is the whole definition of "level": no keyword of its own and no branch in the renderer.

**`view` takes one argument, `env`.** The current node is inside it: attributes are validated and defaulted, derived ones included. This is everything a definition can reach.

| Capability | Usage | Available to |
| --- | --- | --- |
| Read an attribute | `(etaf-md-attr env :title)`; for a child, pass the node last: `(etaf-md-attr env :title tab)` | Every type |
| Read the type | `(etaf-md-type env)`, for a paint shared by several names | Every type |
| Text content | `(etaf-md-text env)` joins the text of the child nodes into one string | Text-only types such as headings |
| Children | `(etaf-md-children env)` gives the child nodes in order | Every type |
| Paint nodes | `(etaf-md-render env nodes)` | When only some children are painted |
| The shipped paint | `(etaf-md-default-view env)` paints this node with the shipped view | When wrapping it |
| A token | `(etaf-md-token env 'muted)` | Every type |
| Line height | `(etaf-md-token env 'lh)` | Every type |
| A surface | `(etaf-md-surface env 'raised)` turns a surface into a fill; `none` gives `nil` | Every type |
| An accent | `(etaf-md-accent env 'warning)` turns an accent into a colour | Callouts, cards |
| A style value | `(etaf-md-style env :background)` reads this node's style value | Custom paints |
| Numbering | `(etaf-md-number env)`, `(etaf-md-format-number N 'lower-roman)` | Headings, tables |
| Open a target | `(etaf-md-follow-link env href)` | A card's `href` |
| This block's state | Read `(etaf-md-block-state env :current)`, with a default `(etaf-md-block-state env :current v)`; write `(etaf-md-block-state env :current VALUE)` | `tabs`, `accordion` |
| Available width | `(etaf-md-available-width env)` | A column's degrade check |

**A view uses the `etaf-view` DSL by default.** It is shorter than building nodes by hand and shows the structure: properties first, children last, property values are ordinary Elisp, and a computed child is wrapped in `(expr …)`.

```elisp
(etaf-view
 (box :padding '((lh 1) (ch 2))
   (text "Title")
   (expr (etaf-md-render env (etaf-md-children env)))))
```

Exactly one case drops to `etaf-node`: when the tag or a property is only known at run time, as when `mapcar` builds a list of rows. The DSL cannot express that, so it is a limit, not a style choice.

The state row is the important one. `etaf-tabs` is a controlled component: `selected` and `on-change` come from the caller, and a definition has nowhere to keep state. So every block gets its own state cell, created by the renderer and isolated per block.

**What a child table entry writes.**

```elisp
:accepts '((col :attrs ((grow :type number :default 1 :doc "Width share")))
           (tab :attrs ((title :type string :required t)
                        (selected :type boolean :default false))))
```

A child carries a `title` attribute of type `string` supplied by the renderer, so a definition never redeclares it in `:attrs`. Its value is `nil` when omitted, and the parent fills in a default inside `:view`: `col` leaves it empty, `tab` fills an empty string, `code-tabs` fills the language of the first fenced block.

### 10.2 Rules for attributes

- A definition references names from the shared attribute table, or declares its own. A private attribute says in `:summary` that it only works with that type.
- An entry has exactly one position: its first element is the name, which is the entry's key. Everything after is a named field.
- `:type` is required and takes `string`, `number`, `boolean`, `length`, `surface`, `accent`, `align` or `enum`. A `string` may add `:pattern`; an `enum` must write `:one-of (...)`.
- An omitted `:default` means `nil`, so a `nil` default takes no characters at all.
- A required attribute writes `:required t`, as in `(title :type string :required t :doc "Title text")`, and then no `:default`; writing both is an error at load. Required exists only on the document side; reader-side keys are always optional.
- A derived attribute writes `:derived t`, as in a heading's `level`. A document cannot write it, the parse or derive stage supplies it, and the style table can still select on it.
- `surface`, `accent` and `align` are overridable by a reader without any flag; the other five listen to the document alone. There is no `:appearance` field, so there is nothing to mark wrong.
- `:doc` is optional but recommended; it appears in help and in errors.
- **A child's label comes from the renderer, not from the definition.** Every `:accepts` entry gets one extra `title` of type `string`. A definition may fill a default inside `:view`; it never renames the attribute or changes its type.
- A definition may not read files, make network requests or start timers. It receives `node` and `env`.
- **`:view` calls public interfaces that start with `etaf-`, never the engine functions that start with `ebox-`**, see 9.2. The engine belongs to `etaf-ui`; whoever reaches past it will break on the next upgrade.
- The renderer's dispatch contains no type names. It looks a definition up by the registry, and never branches on a name.

### 10.3 Setting values on one type

A style is data, never code. Giving each level its own prefix is three lines.

```elisp
(etaf-md-set-style 'heading
  '((:font-weight bold)
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

An entry opens with a selector, and the selector is an attribute name: `(:level 1 …)` means "when this node's `level` is 1". No selector means the whole type. `level` carries no privilege; any type that declares an attribute of that name can be selected this way, and an undeclared name never matches.

The prefix is a shipped key, so this part needs no function. Only what the shipped definition never imagined needs one, see 10.4.

Load-time validation: an unknown type, an unknown key or a wrong value type fails at once, and that type falls back to the shipped style. The error line names the type, the key and the legal values. Passing `nil` removes your own entry.

### 10.4 Giving one type a new paint

When a style is not enough, give a function. A function may also add reader-side keys to the type.

```elisp
(etaf-md-set-view 'heading
  (lambda (env)
    (etaf-view
     (box :background-color (etaf-md-surface env (etaf-md-style env :background))
       (expr (etaf-md-default-view env)))))
  :extends t
  :style-keys '((background :type surface :doc "Heading fill")))
```

| Part | Meaning |
| --- | --- |
| The first argument | A type name. `heading` and `card` both work; neither is special |
| The second argument | `(lambda (env) VIEW)`, the same signature as a definition's `:view` |
| `:extends t` | Keep the shipped paint and keys, and add |
| `:replace t` | Drop the shipped paint and keys |
| `:style-keys` | New reader-side keys, written as in 10.2. Only a function may add them |

Three rules.

- It must return a view and must not change the node tree.
- When it signals, the type falls back to the shipped paint, the page still renders, and the error reaches `doctor`.
- **A new key needs a function.** A data definition cannot add keys, for the plain reason that a key nobody reads is dead configuration.

Numbering goes through here too, with no keyword of its own: `etaf-md-number` reads the number the derive step computed, and `etaf-md-format-number` formats it with a CSS `list-style-type` word: `decimal`, `lower-roman`, `upper-alpha`.

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

### 10.5 Overriding and unloading

Three forms, one table.

| Form | Effect | Use it when |
| --- | --- | --- |
| `:extends t` | Keep the shipped attributes and paint, add yours | You want more attributes or one wrapper |
| `:replace t` | Drop the shipped definition; the attribute table and the paint are yours | You want a different way altogether |
| Neither | Applies only when no type of that name exists; a duplicate is an error | A new type |

Four constraints.

- **The document-side attribute table only grows, never changes.** A new attribute may only be appended; a rename or a removal is breaking, bumps `:contract`, and old documents degrade under 3.4 with a line that says so. Child names work the same way.
- **`:attrs` and `:style-keys` are two names with different rights.** `:attrs` is what a document writes; `:style-keys` is what a reader writes, and it is open-ended.
- **`:default` always means the shipped value.** The loader keeps a snapshot of the shipped definition, otherwise "back to the default" would mean nothing.
- **An override leaves a trace.** A `:replace t` error names the definition it replaced, and `doctor` lists the override chain and the source file.

Name collisions follow load order: when two third-party packages change one type, the later one must write `:replace t` explicitly, or the error names both.

**Unloading.** Every entry has a way back, which is what makes a test able to say "install it, remove it, the page is shipped again".

| Action | How |
| --- | --- |
| Remove a type definition | `(etaf-md-undefine-node 'card)` |
| Remove your style entry | `(etaf-md-set-style 'heading nil)` |
| Remove your paint | `(etaf-md-set-view 'heading nil)` |

Removing a shipped type restores the shipped definition; removing a user type makes the name disappear, and a document that writes it gets "unknown name".

### 10.6 Where definitions live and when they are read

- The shipped definitions live in `lisp/etaf-md-nodes.el` and are registered once at load time in one order: text types, then callouts, then structure, then collections, then interaction. They go through the same `etaf-md-define-node` as user definitions; there is no second registration path.
- User definitions are `.el` files inside the directory named by `etaf-md-node-directory`, one file each.
- Load order is fixed: the package's own definitions first, the user directory after, and file name order within a directory. A later definition may override an earlier one, but only by saying so; see 10.5.
- A session reads the registry once when created and does not touch the disk again. A changed definition needs `r` or a fresh preview.
- A document cannot register a type and cannot run Elisp. Sharing a document is not sharing code.
- **The document declares its contract version.** Front matter may carry `contract: 1`; without it the current version is assumed. When a declared version does not match, that document degrades block by block under 3.4 and the line names the version it needs.

### 10.7 Debugging

- `etaf-md-describe-nodes` lists the registry: type name, the spelling a document uses, summary, attributes, children, implementation layer and source file. Planned.
- When something looks wrong, follow one chain: what type is this block, which definition renders it, which component it calls, where its style value came from, and which token that landed on. Planned.
- The error line is always on the page, so no log has to be opened.
- When a definition signals, that block degrades to its source plus one line reading "the `card` definition failed: …", and the rest of the page keeps rendering.
- `etaf-md-doctor` reports how many types are registered, whether a definition file failed to load, which overrides are in place and whether an unload left anything behind. Planned.

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
| 4 | Interaction: `tabs`, `code-tabs`, `collapse`, `accordion` | Keys go through the command loop; state survives reflow and a theme change; flattened output loses nothing |
| 5 | Documents: `table`, `window` | Row and column highlights land; the window draws only a title bar |
| 6 | Registry and user definitions | A sample definition installs and uninstalls; a new key on a shipped type takes effect; `:default` still reaches the shipped view after an override; a contract mismatch is reported; `doctor` reports counts and the override chain |
| 7 | Editing the source buffer: dimming, pair hint, insert and complete, folding, as `etaf-md-edit-mode` | `font-lock-keywords` is `equal` before and after an enable-and-disable cycle; `buffer-string` is unchanged; a 2000-line document costs 50 milliseconds of extra work at most; typing inside one line triggers no pair computation |

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
- After overriding `heading`'s rendering, `etaf-md-default-view` still returns the shipped view.

### 11.3 Done means

A phase is done only when all three hold.

1. `make check` passes: structure, compilation, tests and the API check.
2. The affected examples have been run in a real GUI and their captures reviewed.
3. The attribute table in Appendix A, the style keys in Appendix C, the mapping in Appendix D and the vocabulary in Appendix E are updated with it.

## 12. What this will not do

- No HTML subset, no CSS subset, no `<style>` tag. Two layout systems in one renderer blur the boundary until nobody can say which layer produced a gap.
- No scripts in documents, and no container registration from documents.
- No type-size parameter and no scale parameter. Scaling exists only as `:scale` in the reader's style table.
- No remote frames, remote players or remote code execution.
- No rounded corners, shadows, gradients or animation.
- No second document format beside Markdown.
- No pages, routes, navigation or publishing. That is the application's work, see 1.2.
- No `justify` text. A character grid has no inter-word space to stretch, so it can only pad with blanks, and Chinese paragraphs get holes at the line ends.

## Appendix A: attribute reference

The shared attributes. A type selects from here and never invents a synonym. The table lists **document attributes**, the ones written inside the braces; **derived attributes**, supplied by the parse or derive stage, follow separately.

| Attribute | Type | Meaning | Used by |
| --- | --- | --- | --- |
| `title` | string | Title text | Callouts, card, steps, timeline, file-tree, accordion, table, window, and the children tab, step, event, stat, collapse |
| `description` | string | Summary under the title | card |
| `surface` | surface | Fill | box, card |
| `accent` | accent | Emphasis | box, card |
| `text-align` | align | Horizontal position of content | box, card |
| `align-self` | enum | Own position within the parent | columns |
| `align-items` | enum | Children's cross-axis alignment | columns |
| `justify-content` | enum | Children's main-axis alignment | columns |
| `width` | length | Own width | box, card |
| `height` | length | Content height | window |
| `padding` | length | Padding | box, columns |
| `gap` | length | Space between siblings | columns |
| `columns` | number or string | Column count or track list | columns, stats |
| `min-width` | length | Smallest column | columns |
| `wrap` | boolean | Wrap when it does not fit | columns |
| `grow` | number | Width share | col |
| `list-style` | enum | List marks | steps, timeline, file-tree |
| `open` | boolean | Starts expanded | Callouts, and the collapse child |
| `collapsible` | boolean | May collapse | Callouts |
| `selected` | boolean | This child is selected by default | The tab child |
| `href` | string | Target of the whole block | card |
| `start` | number | First number | steps |
| `separator` | enum | Name/value separator | field |
| `label-width` | length | Name column width | field |
| `self` | enum | The reader's own side | chat |
| `from` | string | Sender | message |
| `time` | string | Timestamp | event, message |
| `value` | string | The number as text | stat |
| `highlight-rows` | string | Highlighted row numbers, space separated | table |
| `highlight-columns` | string | Highlighted column numbers, space separated | table |
| `highlight` | accent | Accent used for the highlight | table |
| `id` | string | Stable anchor | Every block |

**Derived attributes.** A document cannot write these; the parser or the derive step supplies them. The style table may use them as selectors, see 4.3.

| Attribute | Type | Meaning | On |
| --- | --- | --- | --- |
| `level` | number | Heading level, decided by the number of `#` | heading |
| `language` | string | The language name of a fenced block | code |
| `number` | number | The ordinal the derive step computed | heading, table |

## Appendix B: surfaces, accents and tokens

Every `surface` value maps to one token, and every `accent` value maps to a pair.

| Value | Foreground | Fill | Meaning |
| --- | --- | --- | --- |
| `surface=none` | — | none | No fill |
| `surface=page` | — | `background` | Separated from the prose |
| `surface=raised` | — | `surface-raised` | Code blocks, cards |
| `surface=sunken` | — | `surface-sunken` | Table headers, secondary information |
| `surface=quote` | — | `quote` | Quotation-like |
| `accent=neutral` | `foreground` | `surface-raised` | No emphasis |
| `accent=primary` | `primary` | `primary-soft` | Note, link |
| `accent=success` | `success` | `success-soft` | Success |
| `accent=warning` | `warning` | `warning-soft` | Caution |
| `accent=danger` | `danger` | `danger-soft` | Danger |
| `accent=important` | `important` | `important-soft` | Important |

The five callout names map to accent values fixedly: `note` to `primary`, `tip` to `success`, `important` to `important`, `warning` to `warning`, `caution` to `danger`.

## Appendix C: style keys

The keys a style table may write; the key names are CSS property names. In the type column, a surface is one of the five words in 4.1, a colour is a token name, and either may be a literal for a reader. The value `:default` means the shipped value. This is the shipped vocabulary; a user gives a type new keys with `:style-keys`, see 10.4.

| Key | Type | Used by | Meaning |
| --- | --- | --- | --- |
| `background` | surface or colour | quote, code, table, callout | Fill |
| `color` | colour | heading, strong, em, link, code | Ink |
| `accent` | accent | quote, callout | Accent colour and soft fill |
| `font-weight` | `normal` / `bold` | heading, strong | Weight |
| `font-style` | `normal` / `italic` | em, quote | Slant |
| `text-decoration` | `none` / `underline` | link, strong | Decoration line |
| `text-align` | `left` / `center` / `right` | table | Cell alignment |
| `prefix` | string | heading | Display prefix; anchors unaffected |
| `suffix` | string | heading | Display suffix |
| `numbering` | `none` / `decimal` / `lower-roman` | heading, table | Numbered by the derive step |
| `scale` | number | heading | Multiple of the base size |
| `margin-top` / `margin-bottom` | length | heading, quote, code, table | Space above and below |
| `border-left-width` | length | quote, callout | The left bar's width |
| `list-style` | enum or a character | list | The bullet; a character must be one 4.6 allows |
| `label-color` | colour | code | The fence's language label |
| `header-background` | surface or colour | table | Header fill |
| `stripe-background` | surface or colour | table | Stripe fill |
| `accent-map` | alist | callout | Accent value to colour |

## Appendix D: the plume map

| Plume | Our decision | Note |
| --- | --- | --- |
| `align` | Folded into `box`'s `text-align` attribute | One alignment does not deserve a container |
| `flex` | Folded into `columns` | One container handles rows, wrapping and proportions |
| `card` | Absorbed as `card` | Rounded corners and shadow become one border and a surface |
| `card-grid` | Folded into `columns {columns=N}` | Cards side by side are cards in columns |
| `card-masonry` | Declined | Row heights are fixed, so packing yields a grid |
| `steps` | Absorbed as `steps` + `step` | Number plus title |
| `tabs` | Absorbed as `tabs` + `tab` | Keyboard reachable; a switch repaints one block |
| `code-tabs` | Kept as one definition on top of `tabs` | Children hold fenced code; an omitted `title` comes from the fence's language |
| `collapse` | Absorbed as the child of `accordion` | One open at a time, plus auto-expansion on a search hit |
| `field` | Absorbed as `field` | Auto-aligned name column |
| `timeline` | Absorbed as `timeline` + `event` | Optional marks |
| `table` | Partly absorbed | Title and row/column highlights |
| `file-tree` | Absorbed as `file-tree` | Marks use only the allowed characters |
| `code-tree` | Declined | Overlaps `code-tabs` plus `file-tree` |
| `chat` | Absorbed as `chat` + `message` | Alternating sides and indentation, no bubbles |
| `window` | Absorbed with a change, as `window` | Title bar only |
| `encrypt` | Declined | A document that must stay secret does not belong in a preview |
| `npm-to`, `lang-repl` | Declined | Needs a package manager and an interpreter |
| `plot`, `qrcode`, `pdf` | Declined | Needs plotting and image generation |
| `annotation`, `abbreviation` | Declined | Needs marks over an image and a hover popup |
| `code-pen`, `code-sandbox`, `repl`, `caniuse` | Declined | Needs a browser and a network |

## Appendix E: vocabulary

This table is the ground for naming. A new name is looked up here first; if it is absent, borrow one from the authority column and add it here.

### E.1 Document attributes

| Name | Source | Meaning | Not |
| --- | --- | --- | --- |
| `title` | HTML | Title text | `heading`, `caption` |
| `description` | Ant, Primer | Summary under the title | `summary`, `subtitle` |
| `surface` | Material, Polaris | Fill role | `background`, `fill`, `panel` |
| `accent` | shadcn/ui | Accent value | `tone`, `variant`, `type`, `intent` |
| `text-align` | CSS | Horizontal position of content | `align`, `position` |
| `align-self` | CSS | Own position within the parent | `self-align`, `align` |
| `align-items` | CSS | Children's cross-axis alignment | `items`, `cross-align` |
| `justify-content` | CSS | Children's main-axis alignment | `justify` |
| `width` | CSS | Own width | `w` |
| `height` | CSS | Content height | `h` |
| `padding` | CSS | Padding | `pad`, `inset` |
| `gap` | CSS | Space between siblings | `spacing`, `space` |
| `columns` | Bootstrap grid, CSS | Column count or track list | `cols`, `tracks`, `grid` |
| `min-width` | CSS | Smallest column | `min`, `threshold` |
| `wrap` | CSS `flex-wrap`, Ant | Wrap when it does not fit | `flex-wrap`, `nowrap` |
| `grow` | Tailwind | Width share | `flex`, `ratio`, `weight` |
| `list-style` | CSS `list-style-type` | List marks | `marker`, `bullet` |
| `open` | HTML `<details open>` | Starts expanded | `expanded`, `visible` |
| `collapsible` | Bootstrap, Primer | May collapse | `foldable`, `toggle` |
| `selected` | HTML `<option selected>` | This child is selected by default | `active`, `current` |
| `derived` | This document's parse and derive stages | A derived attribute; a document cannot write it | `read-only`, `computed` |
| `href` | HTML | Target | `url`, `link`, `to` |
| `start` | HTML `<ol start>` | First number | `begin`, `from` |
| `separator` | General | Name/value separator | `divider` |
| `label-width` | CSS-style compound | Name column width | `label-w`, `width` |
| `self` | Chat interfaces | The reader's own side | `me`, `own` |
| `from` | Mail, chat | Sender | `sender`, `author` |
| `time` | HTML `<time>` | Timestamp | `date`, `at` |
| `value` | HTML `<input value>` | The number as text | `number`, `figure` |
| `highlight-rows` | General | Highlighted row numbers | `hl-rows`, `mark` |
| `highlight-columns` | General | Highlighted column numbers | `hl-cols`, `mark` |
| `highlight` | Naming rule of this table | Accent used for the highlight | `tone`, `mark-color` |
| `id` | HTML | Stable anchor | `anchor`, `slug` |

### E.2 Types

| Name | Source | Meaning | Not |
| --- | --- | --- | --- |
| `string` | JSON Schema | Text | `str`, `text` |
| `number` | JSON Schema | Integer or decimal | `int`, `float`, `num` |
| `boolean` | JSON Schema | `true` or `false` | `bool`, `flag` |
| `length` | CSS value type | A number with a unit | `size`, `dimension` |
| `enum` | JSON Schema | One of the listed words | `one-of`, `choice` |
| `surface` | Material, Polaris | One of five fill values | `background`, `fill` |
| `align` | CSS | One of three horizontal positions | `text-align`, `justify` |
| `accent` | shadcn/ui | One of six accent values | `tone`, `variant` |

### E.3 Tokens

| Name | Source | Meaning | Not |
| --- | --- | --- | --- |
| `background` | shadcn/ui | Page background | `bg`, `page` |
| `foreground` | shadcn/ui | Body text | `ink`, `text` |
| `muted` | shadcn/ui | Secondary text | `secondary`, `dim` |
| `faint` | General | The weakest layer | `subtle`, `ghost` |
| `border` | shadcn/ui | Borders | `line`, `stroke` |
| `surface-raised` | Material layering | A raised surface | `panel`, `card-bg` |
| `surface-sunken` | Material layering | A sunken surface | `panel2`, `inset` |
| `quote` | General | Quote fill | `quote-bg`, `blockquote` |
| `quote-bar` | General | The quote's bar | `bar`, `accent-bar` |
| `table-header` | General | Table header fill | `th`, `header` |
| `table-stripe` | General | Table stripe fill | `stripe`, `zebra` |
| `heading` | HTML | Heading colour | `title`, `h` |
| `primary` | shadcn/ui | Primary emphasis | `accent`, `brand`, `info` |
| `primary-soft` | shadcn's `-foreground` style | Primary soft fill | `accent-soft` |
| `success` | Bootstrap, shadcn | Success | `ok`, `positive`, `green` |
| `success-soft` | Same | Success soft fill | `ok-soft` |
| `warning` | Bootstrap, shadcn | Caution | `warn`, `caution` |
| `warning-soft` | Same | Caution soft fill | `warn-soft` |
| `danger` | Bootstrap, shadcn | Danger | `error`, `red`, `critical` |
| `danger-soft` | Same | Danger soft fill | `error-soft` |
| `important` | GitHub alerts | Important | `note`, `emphasis` |
| `important-soft` | Same | Important soft fill | — |

### E.4 Style keys

The key names are CSS property names. Four have no CSS counterpart; they are listed with the reason they stay.

| Name | Source | Meaning | Not |
| --- | --- | --- | --- |
| `background` | CSS | Fill | `surface`, `bg`, `fill` |
| `color` | CSS | Ink | `ink`, `fg`, `text-color` |
| `accent` | shadcn/ui | Accent colour | `tone`, `variant` |
| `font-weight` | CSS | Weight | `weight`, `bold` |
| `font-style` | CSS | Slant | `slant`, `italic` |
| `text-decoration` | CSS | Decoration line | `underline`, `decoration` |
| `text-align` | CSS | Alignment | `align` |
| `margin-top` / `margin-bottom` | CSS | Space above and below | `gap-before`, `gap-after` |
| `border-left-width` | CSS | The left bar's width | `bar-width` |
| `header-background` | This table's rule | Header fill | `header-surface` |
| `stripe-background` | This table's rule | Stripe fill | `stripe-surface` |
| `label-color` | This table's rule | The fence's language label colour | `tag-color` |
| `list-style` | CSS | List marks | `marker` |
| `prefix` | No CSS counterpart | Heading prefix, display only | — |
| `suffix` | No CSS counterpart | Heading suffix, display only | — |
| `numbering` | CSS `list-style-type` values | Number format | `number` |
| `scale` | No CSS counterpart | Multiple of the base size | `font-size`, `size` |
| `accent-map` | No CSS counterpart | Accent value to colour | `tone-colors` |

`scale`, `prefix`, `suffix` and `accent-map` have no CSS counterpart because they describe something a node carries on top of layout and colour. They still appear only here: `prefix`, `suffix`, `numbering` and `scale` apply to `heading` alone.

### E.5 Functions

| Name | Meaning |
| --- | --- |
| `etaf-md-attr` | Read one of this node's validated attributes |
| `etaf-md-type` | Read this node's type |
| `etaf-md-text` | Join the text of the child nodes into one string |
| `etaf-md-token` | Look up a token's colour or line height |
| `etaf-md-surface` | Turn a surface into its fill; `none` yields `nil` |
| `etaf-md-accent` | Turn an accent value into its colour |
| `etaf-md-children` | Read the child nodes in order |
| `etaf-md-render` | Paint a list of nodes |
| `etaf-md-follow-link` | Open a target |
| `etaf-md-block-state` | Read or write this block's state |
| `etaf-md-available-width` | This block's usable width, for degradation |
| `etaf-md-style` | Read this block's style value |
| `etaf-md-number` | Read the number the derive step computed |
| `etaf-md-format-number` | Format a number by a `list-style-type` word |
| `etaf-md-default-view` | The **shipped** view for a type |
| `etaf-md-define-node` | Register a node type |
| `etaf-md-undefine-node` | Remove a type definition |
| `etaf-md-set-style` | Set values on one type |
| `etaf-md-set-view` | Replace one type's paint |
| `etaf-md-describe-nodes` | List the registry |

Four names outside `etaf-md-`: `etaf-card`, `etaf-tabs`, `etaf-accordion`, `etaf-steps`, `etaf-timeline` and `etaf-statistic` belong to the `etaf-ui` component catalogue. This package calls them and does not rename them.

## Appendix F: one complete example

The three parts below are three sides of one thing: a document, its definitions, and a reader's configuration. Together they use every rule the chapters above state.

### F.1 The document

````markdown
---
contract: 1
---

# Install

> [!WARNING]
> This only works on Emacs 30 and later.

:::card {title="Cache hit" accent=primary}
Images and figures scale with the page instead of being redrawn.

:::columns {columns=2}
:::col
A hit reads one image from disk.
:::
:::col
A miss draws it once.
:::
:::

:::tabs
:::tab {title="Emacs 29"}
Uses the old `image-size` signature.
:::
:::tab {title="Emacs 30+" selected=true}
Passes the buffer directly.
:::
:::
:::

:::steps {start=2 list-style=decimal}
:::step {title="Locate"}
Sample the stack; do not guess.
:::
:::

:::box {text-align=center padding="1lh"}
![One hit](figures/hit.png)
:::
````

### F.2 The definitions

```elisp
;;; 1. Heading: a derived attribute, style values, numbering, text assembly
(etaf-md-define-node 'heading
  :summary "A heading whose level comes from the number of #"
  :attrs '((level :type number :derived t :default 1))
  :view (lambda (env)
          (etaf-view
           (text :weight (etaf-md-style env :font-weight)
                 :color (etaf-md-token env 'heading)
             (expr (concat (or (etaf-md-style env :prefix) "")
                           (etaf-md-format-number (etaf-md-number env) 'decimal)
                           " "
                           (etaf-md-text env)))))))

;;; 2. Callouts: five names share one paint and read their own type
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
    :summary "A callout"
    :attrs '((title :type string :doc "Replace the fixed title"))
    :view #'my-callout-view))

;;; 3. Card: document attributes turned into component parameters
(etaf-md-define-node 'card
  :name "card"
  :contract 1
  :summary "A card with a title"
  :attrs '((title  :type string :required t      :doc "Card title")
           (accent :type accent :default neutral :doc "Emphasis"))
  :view (lambda (env)
          (etaf-view
           (etaf-card :title (etaf-md-attr env :title)
                      :variant (pcase (etaf-md-attr env :accent)
                                 ('warning 'warning)
                                 ('success 'success)
                                 (_ 'default))
             (expr (etaf-md-render env (etaf-md-children env)))))))

;;; 4. Box: a length and an alignment
(etaf-md-define-node 'box
  :name "box"
  :summary "A surface without a title"
  :attrs '((text-align :type align  :default start :doc "Horizontal position")
           (padding    :type length                :doc "Inner padding")
           (width      :type length                :doc "Own width; omitted means full"))
  :view (lambda (env)
          (etaf-view
           (column :width (or (etaf-md-attr env :width) 'stretch)
                   :text-align (etaf-md-attr env :text-align)
                   :padding (if (etaf-md-attr env :padding)
                                (list (etaf-md-attr env :padding))
                              '((lh 0) (ch 0)))
             (expr (etaf-md-render env (etaf-md-children env)))))))

;;; 5. Columns: a count attribute, the usable width, declared children
(etaf-md-define-node 'columns
  :name "columns"
  :summary "Side-by-side columns"
  :attrs '((columns :type number :default 2 :doc "How many columns"))
  :accepts '((col))
  :view (lambda (env)
          (let* ((cols (etaf-md-children env))
                 (n (max 1 (etaf-md-attr env :columns)))
                 (wide (> (etaf-md-available-width env) 60))
                 (rows (seq-partition cols (if wide n 1))))
                 ;; row and column counts are known only at run time; the DSL cannot say it, so etaf-node
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

;;; 6. Tabs: a parent type, child attributes, this block's state
;; When wiring the real thing, hand :on-change to the component and write
;; (etaf-md-block-state env :current NEW-VALUE) inside it.
(etaf-md-define-node 'tabs
  :name "tabs"
  :summary "Tabs"
  :accepts '((tab :attrs ((title    :type string  :required t :doc "Tab label")
                          (selected :type boolean :default false :doc "Starts selected"))))
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

;;; 7. Steps: a number and an enum
(etaf-md-define-node 'steps
  :name "steps"
  :summary "Numbered steps"
  :attrs '((start      :type number :default 1       :doc "First number")
           (list-style :type enum   :default decimal :one-of (decimal bullet)
                       :doc "Marker"))
  :accepts '((step :attrs ((title :type string :required t :doc "The step's name"))))
  :view (lambda (env)
          (let ((n (1- (etaf-md-attr env :start)))
                (mark (pcase (etaf-md-attr env :list-style)
                        ('decimal "%d. ")
                        (_ "· "))))
                 ;; each item's number is computed in sequence; the DSL cannot say it, so etaf-node
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

### F.3 The reader's configuration

```elisp
;; 1. Change values: selectors are attribute names, keys come from Appendix C and this type
(etaf-md-set-style 'heading
  '((:font-weight bold)
    (:level 1 :prefix "◆ ")
    (:level 2 :prefix "◇ " :margin-top "1lh")))
(etaf-md-set-style 'card '((:accent warning)))

;; 2. Give one type a new paint: keep the shipped one, wrap it, add a reader key
(etaf-md-set-view 'heading
  (lambda (env)
    (etaf-node 'box
               (list :padding '((lh 1) (ch 2))
                     :background-color (etaf-md-surface env
                                                       (etaf-md-style env :background)))
               (list (etaf-md-default-view env))))
  :extends t
  :style-keys '((background :type surface :doc "Heading fill")))

;; 3. Replace one type outright
(etaf-md-set-view 'box (lambda (env) (etaf-md-default-view env)) :replace t)

;; 4. Unload: back to the shipped behaviour
(etaf-md-set-style 'heading nil)
(etaf-md-set-view 'heading nil)
(etaf-md-define-node 'card :replace t
  :name "card"
  :attrs '((title :type string))
  :view (lambda (env)
          (etaf-view (text (expr (etaf-md-attr env :title))))))
```

### F.4 The page

```
◆ 1 Install

  ⚠ This only works on Emacs 30 and later.

┌ Cache hit ────────────────────────────┐
│ Images and figures scale with the page.│
│ ┌ A hit reads one image ┐┌ A miss draws it ┐ │
│ └───────────────────────┘└─────────────────┘ │
│ Emacs 29 │ Emacs 30+                   │
│ Passes the buffer directly.            │
│ 2. Locate                              │
│    Sample the stack; do not guess.     │
└────────────────────────────────────────┘

              One hit
          [figures/hit.png]
```

### F.5 Coverage

| Knowledge | Where it appears |
| --- | --- |
| `:name` | Card, the five callouts, columns, tabs and steps have one; heading does not |
| `:summary` | One line in every definition |
| `:contract` | The card's definition, and the document's front matter |
| `:attrs` with `:default` | The heading's `level`, the card's `accent`, the box's `text-align` |
| `:attrs` with `:required` | The card's `title`, the tab's and the step's `title` |
| `:attrs` with `:derived` | The heading's `level` |
| `:attrs` with `:pattern` | The examples in Appendix A and 10.2 |
| `:attrs` with `:one-of` | The steps' `list-style` |
| `:attrs` with `:doc` | Every attribute has one |
| `:accepts` | Columns take `col` (no attributes), tabs take `tab`, steps take `step` |
| `:view` | Seven definitions, each `(lambda (env))` |
| DSL versus `etaf-node` | Five definitions use `etaf-view`; `columns` and `steps` use `etaf-node` because row counts and numbers are computed at run time |
| The eight types | string (`title`), number (`columns`, `start`, `level`), boolean (`selected`), length (`padding`, `width`), surface (a callout's fill), accent (a card's emphasis), align (`text-align`), enum (`list-style`) |
| `etaf-md-attr` | Every attribute read, including a child's: `(etaf-md-attr env :title tab)` |
| `etaf-md-type` | The callouts' shared paint |
| `etaf-md-text` | The heading, assembling prefix, number and text |
| `etaf-md-children` | Every parent, including a child's content: `(etaf-md-children env current)` |
| `etaf-md-render` | Everywhere child nodes become views |
| `etaf-md-default-view` | The reader's second and third entries |
| `etaf-md-token` | The heading's colour |
| `etaf-md-surface` | A callout's fill, the reader's wrapper |
| `etaf-md-accent` | A callout's ink |
| `etaf-md-style` | The heading's weight and prefix, the reader's `background` |
| `etaf-md-number` and `format-number` | The heading's number |
| `etaf-md-block-state` | Tabs reading their default |
| `etaf-md-available-width` | Columns deciding wide or narrow |
| Style selectors | `(:level 1 …)` |
| `:extends`, `:replace`, unload | The reader's second, third and fourth entries |

**`etaf-md-follow-link` is the one thing this example does not cover.** It wires a clickable region to ETAF's interaction interface, which chapter 7 describes; the appendix does not repeat it.
