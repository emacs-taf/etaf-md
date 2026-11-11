# Changelog

## Unreleased

### Added

- `etaf-md-preview-follow-scroll` makes the page move with the source window:
  the block at the top of the markdown buffer becomes the first row of the
  preview as the source scrolls.  Only the source's scrolling follows, so the
  reader still scrolls the page freely, and typing follows as far as the
  source window scrolls.  Run it from either buffer; it takes no key.
- The preview follows the markdown file while it is edited: a change in the
  source buffer repaints the page on the next frame, block by block, so typing
  in the source costs the block under the caret instead of the whole document
  (measured: one new, one updated and one retired instance per keystroke on a
  703-line file).  A save, or a change made by another program, repaints the
  same way.
- The preview's own keys are `n`, `p`, `C-c j`, `r`, `t`, `[`, `]`, `C-c h` and
  `q`: outline navigation, reload, theme, reading width, help and close.  The
  page is a rendering, so native scrolling, isearch and link activation stay
  available as they are.
- A `mermaid' fence and a `$$' display formula are drawn by mermaid-cli when
  it is installed: the diagram through `mmdc', the formula through KaTeX in the
  Chromium that package brings.  A render runs in the background and is cached
  by its source and the page's colours, so a page paints the source at once and
  swaps in the picture when it arrives, and a block edited again draws again.
  Without the program the fence stays a code block and the formula keeps its
  plain-text rendering; an inline formula always keeps the text, because a
  picture inside a line would change the line height.
- A markdown file may name its own dialect with a `flavor:' line in its front
  matter, and the preview parses that file with it: one document can stay
  CommonMark while the rest read with everything the renderer supports.  A
  session's `:flavor' argument still wins, and the default now follows
  `etaf-ui-markdown-flavor' (the widest preset) instead of `gfm'.
- Definition lists, sub- and superscript, abbreviations and `$' math render in
  a preview, because the shared renderer enables them: `H~2~O' paints `H₂O',
  `Term' with a `:' line under it paints a term with its definitions, and a
  formula paints as text rather than an image.

### Fixed

- A line break the source wrote keeps its row: the page is read beside the
  markdown, so a soft break, a two-space break and a backslash break each put
  the next line on its own row, a blank line inside a fence stays a row inside
  the block, and blank lines between blocks keep their count.
- A typeset picture is placed at the size it is meant to occupy: the file is
  drawn at two device pixels per point for sharpness, and the grid it is put in
  now comes from half that file size.  Formulas are set at the reader's body
  size instead of a fixed 30 pixels, which had made one equation claim half the
  page, and mermaid diagrams stop appearing at twice their intended size.
- The blank lines after a leading definition line are painted again: a
  document that opens with a link reference or an abbreviation definition used
  to lose the gap after it, because the whole leading stretch was skipped as
  front matter.  The front matter alone is skipped now, and the blank lines
  around it keep their rows.
- The page title takes the size of a level-one heading, which is the rank a
  front matter title has.  It used to be a notch smaller than that rank, so a
  document whose sections start at level 2 read as if the title and the
  headings came from two different scales.
- The scroll follow reaches the top of the page: a source position above the
  first block sits in the front matter, which no block owns, so the page used
  to scroll past its header.  It now opens on the title, tags and metadata
  line the page starts with.
- An edit repaints a document that holds a definition list: the parse keeps a
  range for the paragraph above the list as well as for the list, and an edit
  whose document has a block without one falls back to a whole parse instead
  of stopping the follow timer with an error.
- A blank line next to a line the parser consumes without painting one, such
  as a link reference definition or an abbreviation definition, is painted
  again: the preview kept the file's own spacing instead of pulling the next
  block up against the previous one.

### Changed

- A preview no longer accepts typing on the painted page.  The markdown is
  edited in its own buffer with the reader's own commands, and the page shows
  the result; the commands that typed through the page
  (`etaf-md-preview-edit-document`, `etaf-md-preview-insert`,
  `etaf-md-preview-delete-char`, `etaf-md-preview-editing-p`) are gone with
  them.
