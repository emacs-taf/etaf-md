// A long-lived renderer for the preview's pictures.
//
// One Chromium serves every diagram and every formula of a session: starting a
// browser costs seconds, drawing one picture into a running one costs a
// fraction of that.  mmdc started a browser per block, so a page with a dozen
// diagrams paid a dozen launches and ran a dozen Chromiums at once.
//
// Requests arrive as one JSON object per line on stdin, are drawn as pages
// become free, and are answered with one JSON object per line on stdout in
// whatever order they finish.  A diagram is parsed before it is drawn, so one
// that cannot be drawn reports the parser's message instead of producing
// mermaid's own error picture.
//
//   {"id":1,"kind":"mermaid","source":"graph LR; A-->B","out":"/tmp/a.png",
//    "config":"{...}"}
//   {"id":2,"kind":"math","source":"\\frac12","out":"/tmp/b.png",
//    "ink":"#ffffff","pixels":16,"cell":16}
//
//   {"id":1,"ok":true}
//   {"id":2,"ok":false,"error":"Parse error on line 2"}

import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import readline from 'node:readline'
import { createRequire } from 'node:module'
import { execFileSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'

const TIMEOUT_MS = 30000
// Chromium draws on several processes, so a few pages fill a document's
// diagrams in a fraction of the time one page takes.
const WORKERS = 4
// A picture wider than this is scaled down to the reading column anyway, and
// drawing it wider only costs memory.  Its pixels are still drawn at two device
// pixels per point, which is the size the preview places it at.
const WIDEST = 1200

// mermaid and KaTeX are taken from the installation `mmdc` comes from: the app
// has no package of its own, and a machine with diagram support has that one.
const mmdc = execFileSync('sh', ['-c', 'command -v mmdc'], { encoding: 'utf8' }).trim()
const cliDir = path.dirname(path.dirname(fs.realpathSync(mmdc)))
const require = createRequire(path.join(cliDir, 'package.json'))
const puppeteer = require('puppeteer')
const katex = require('katex')
const katexDir = path.dirname(require.resolve('katex/package.json'))
const mermaidESM = path.join(cliDir, 'node_modules/mermaid/dist/mermaid.esm.mjs')

const browser = await puppeteer.launch({
  headless: 'shell',
  args: ['--allow-file-access-from-files'],
})

// A page draws one picture at a time, so the workers hand pages around: a
// request waits for a free page and gives it back when its picture is saved.
const idle = []
const waiting = []

function takePage() {
  if (idle.length) return Promise.resolve(idle.pop())
  return new Promise((resolve) => waiting.push(resolve))
}

function givePage(page) {
  const next = waiting.shift()
  if (next) next(page)
  else idle.push(page)
}

// Mermaid draws in a document, so the page each worker draws in is opened once,
// loads mermaid, and renders every request into its canvas.
let pageRoot = null

async function openMermaidPage() {
  if (!pageRoot) {
    pageRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'etaf-md-preview-'))
    fs.writeFileSync(
      path.join(pageRoot, 'index.html'),
      `<!doctype html><body><div id="canvas"></div>
<script type="module">
import mermaid from ${JSON.stringify(pathToFileURL(mermaidESM).href)}
mermaid.initialize({ startOnLoad: false })
window.mermaid = mermaid
window.ready = true
</script></body>`,
    )
  }
  const page = await browser.newPage()
  await page.setViewport({ width: WIDEST + 200, height: 900, deviceScaleFactor: 2 })
  await page.goto(pathToFileURL(path.join(pageRoot, 'index.html')).href, { waitUntil: 'load' })
  await page.waitForFunction('window.ready === true', { timeout: TIMEOUT_MS })
  return page
}

const formulaPage = await browser.newPage()
await formulaPage.setViewport({ width: 1200, height: 800, deviceScaleFactor: 2 })

// Draw a diagram into a PNG at OUT.  The picture is the diagram's own canvas:
// its viewBox is what mermaid sized the drawing to.  An explicit height is
// dropped because several kinds declare one that does not match their drawing,
// which leaves a band of empty picture under the drawing itself.
async function drawDiagram(page, request) {
  const problem = await page.evaluate(async (source) => {
    try {
      await window.mermaid.parse(source)
      return null
    } catch (error) {
      return String(error?.message ?? error).split('\n')[0].slice(0, 300)
    }
  }, request.source)
  if (problem) return problem
  await page.evaluate(
    async ({ source, config, id, widest }) => {
      window.mermaid.initialize({ startOnLoad: false, ...JSON.parse(config) })
      const { svg } = await window.mermaid.render(`diagram-${id}`, source)
      const canvas = document.getElementById('canvas')
      canvas.innerHTML = svg
      const element = canvas.querySelector('svg')
      const viewBox = element.getAttribute('viewBox')
      const [width, height] = viewBox
        ? viewBox.split(/[\s,]+/).map(Number).slice(2)
        : [element.getBBox().width, element.getBBox().height]
      const scale = Math.min(1, widest / width)
      element.setAttribute('width', Math.round(width * scale))
      element.setAttribute('height', Math.round(height * scale))
      element.style.maxWidth = 'none'
      element.style.maxHeight = 'none'
      await document.fonts.ready
    },
    { source: request.source, config: request.config || '{}', id: request.id, widest: WIDEST },
  )
  const element = await page.$('#canvas svg')
  await element.screenshot({ path: request.out, omitBackground: true })
  return null
}

// A formula is one line of the sentence around it: KaTeX's own display margins
// are dropped, the frame is a whole number of text rows tall with the formula
// centred in it, and the picture is drawn at its own size.
async function drawFormula(request) {
  const markup = katex.renderToString(request.source, {
    displayMode: true,
    throwOnError: false,
    output: 'html',
  })
  const css = fs.readFileSync(path.join(katexDir, 'dist/katex.min.css'), 'utf8')
  const pixels = Math.max(8, Number(request.pixels) || 16)
  const row = Math.max(1, Number(request.cell) || 16)
  const html = `<!doctype html><html><head><meta charset="utf-8">
<base href="file://${path.join(katexDir, 'dist')}/">
<style>${css}</style><style>
  html, body { margin: 0; background: transparent; }
  #formula { display: inline-block; padding: 1px 2px; color: ${request.ink || '#000000'};
             font-size: ${pixels / 1.21}px; }
  #formula .katex-display { margin: 0; }
  #frame { display: flex; align-items: center; justify-content: center;
           background: transparent; }
</style></head><body><div id="frame"><div id="formula">${markup}</div></div></body></html>`
  await formulaPage.setContent(html, { waitUntil: 'load' })
  const size = await formulaPage.evaluate(() => {
    const box = document.getElementById('formula').getBoundingClientRect()
    return { width: box.width, height: box.height }
  })
  await formulaPage.evaluate(
    ({ width, height, row }) => {
      const frame = document.getElementById('frame')
      frame.style.width = `${Math.ceil(width)}px`
      frame.style.height = `${Math.ceil(height / row) * row}px`
    },
    { width: size.width, height: size.height, row },
  )
  const element = await formulaPage.$('#frame')
  await element.screenshot({ path: request.out, omitBackground: true })
  return null
}

async function draw(request) {
  try {
    if (request.kind === 'math') {
      const problem = await drawFormula(request)
      return problem ? { ok: false, error: problem } : { ok: true }
    }
    const page = await takePage()
    try {
      const problem = await drawDiagram(page, request)
      return problem ? { ok: false, error: problem } : { ok: true }
    } finally {
      givePage(page)
    }
  } catch (error) {
    return { ok: false, error: String(error?.message ?? error).split('\n')[0].slice(0, 300) }
  }
}

// A picture that never comes back must not leave the preview waiting: the block
// keeps its source and the next request draws the next picture.  The deadline is
// cleared when the picture lands, or the process would stay alive until it fires.
function withDeadline(request) {
  let timer = null
  const deadline = new Promise((resolve) => {
    timer = setTimeout(() => resolve({ ok: false, error: 'render timed out' }), TIMEOUT_MS)
  })
  return Promise.race([draw(request), deadline]).finally(() => clearTimeout(timer))
}

async function start() {
  for (let index = 0; index < WORKERS; index += 1) idle.push(await openMermaidPage())
}

async function main() {
  await start()
  const running = new Set()
  const input = readline.createInterface({ input: process.stdin })
  input.on('line', (line) => {
    if (!line.trim()) return
    let request
    try {
      request = JSON.parse(line)
    } catch {
      process.stdout.write(JSON.stringify({ id: null, ok: false, error: 'bad request' }) + '\n')
      return
    }
    const work = withDeadline(request).then((reply) => {
      process.stdout.write(JSON.stringify({ id: request.id, ...reply }) + '\n')
    })
    running.add(work)
    work.then(() => running.delete(work))
  })
  await new Promise((resolve) => input.on('close', resolve))
  // Piped input ends before the pictures are drawn: let every request finish
  // and answer before the process stops.
  while (running.size) await Promise.all([...running])
}

await main()
await browser.close().catch(() => {})
if (pageRoot) fs.rmSync(pageRoot, { recursive: true, force: true })
