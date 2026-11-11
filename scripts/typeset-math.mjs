import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { execFileSync } from 'node:child_process'

const [texPath, outPath, ink = '#000000', pixels = '30'] = process.argv.slice(2)

function requireFromMermaidCli() {
  const mmdc = execFileSync('sh', ['-c', 'command -v mmdc'], { encoding: 'utf8' }).trim()
  const packageDir = path.dirname(path.dirname(fs.realpathSync(mmdc)))
  return createRequire(path.join(packageDir, 'package.json'))
}

const require = requireFromMermaidCli()
const katex = require('katex')
const puppeteer = require('puppeteer')

const latex = fs.readFileSync(texPath, 'utf8')
const markup = katex.renderToString(latex, {
  displayMode: true,
  throwOnError: false,
  output: 'html',
})

// KaTeX positions fractions, limits and scripts with its stylesheet, and its
// glyphs come from the fonts that ship beside it.
const katexDir = path.dirname(require.resolve('katex/package.json'))
const css = fs.readFileSync(path.join(katexDir, 'dist/katex.min.css'), 'utf8')

const html = `<!doctype html><html><head><meta charset="utf-8">
<base href="file://${path.join(katexDir, 'dist')}/">
<style>${css}</style><style>
  html, body { margin: 0; background: transparent; }
  #formula { display: inline-block; padding: 6px 8px; color: ${ink};
             font-size: ${pixels}px; }
</style></head><body><div id="formula">${markup}</div></body></html>`

const browser = await puppeteer.launch({
  headless: 'shell',
  args: ['--allow-file-access-from-files'],
})
try {
  const page = await browser.newPage()
  // Twice the device pixels for the same CSS size: the page places the picture
  // by its own pixel size, so the extra resolution only sharpens the edges.
  await page.setViewport({ width: 1200, height: 800, deviceScaleFactor: 2 })
  await page.setContent(html, { waitUntil: 'load' })
  const element = await page.$('#formula')
  await element.screenshot({ path: outPath, omitBackground: true })
} finally {
  await browser.close()
}
