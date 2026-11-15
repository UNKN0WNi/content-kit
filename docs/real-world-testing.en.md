# Quick-testing content-kit with a real web page (all environments)

🌐 **Language / 语言:** **English** · [简体中文](./real-world-testing.md) · [Back to main README](../README.en.md)

This guide answers one question: **given any real web page, how do you evaluate content-kit's extraction quality in the shortest time?** Run all commands from the repository root. No built-in corpus and (once the page is saved) no network access required.

> The fetched page and all extraction artifacts **stay on your machine**. `.gitignore` excludes `examples/page.*` and `docs/realworld-demo.html`, so they are never distributed with the repository. Only scripts, docs and reproducible procedures are committed.

---

## 0. Shortest path (3 commands)

```bash
# ① Save any real page as examples/page.html (UTF-8), or let the script fetch it:
bash examples/run.sh --fetch "https://example.com/some-article"

# ② One command: 3-backend extraction → byte comparison → Node demo → visual page
bash examples/run.sh

# ③ Inspect the results
cat examples/page.text          # plain body text
cat examples/page.md            # Markdown
python -m json.tool examples/page.json | head -40   # structured result
```

`run.sh` prints something like:

```text
== Three-backend CLI extraction (same real page: examples/page.html) ==
   js       <N> bytes  sha256 <16-char hash>
   wasm     <N> bytes  sha256 <16-char hash>   ← all three lines must be identical
   wasm-gc  <N> bytes  sha256 <16-char hash>
   OK: 3 outputs are byte-identical
== Node / ESM demo ==
Blocks   : <blocks> | score: <score>
Sizes    : text ... / md ... / json ...
```

---

## 1. Prepare a real web page

| Method | Command / action | Best for |
|---|---|---|
| A Save manually | Browser "Save as → Web page, HTML only" → `examples/page.html` | Easiest; also works for pages behind a login |
| B `curl` | `curl -A "Mozilla/5.0" -o examples/page.html "https://example.com/a"` | Static / server-rendered pages |
| C Headless browser | `chrome --headless=new --dump-dom "https://example.com/a" > examples/page.html` | **Recommended**: rendered DOM with the complete body |
| D Let the script do it | `bash examples/run.sh --fetch "https://example.com/a"` | Auto-detects local Chrome/Edge and saves to `examples/page.html` |

Three caveats:

1. **The file must be UTF-8.** For a GBK page: `iconv -f GBK -t UTF-8 page.html > examples/page.html`, otherwise Chinese text will be mangled.
2. **SPAs / JS-rendered pages** need method C/D; the empty shell returned by `curl` can only fall through to the `parse/plain` fallback.
3. Large pages (hundreds of KB) are supported: the wrapper passes content through an environment variable, and the Node / ESM channel is the most direct path.

---

## 2. Environment × command cheat sheet

| # | Environment | Command | What to look at |
|---|---|---|---|
| 1 | **CLI · default js backend** | `bash scripts/cxtract.sh examples/page.html --format json` | Structured `Article` with a fixed field order |
| 2 | CLI · three views | `--format text` / `--format md` / `--format json` | Same body across all three views |
| 3 | **CLI · wasm / wasm-gc** | `CXTRACT_TARGET=wasm-gc bash scripts/cxtract.sh examples/page.html --format json` | Byte-identical to the js output |
| 4 | **CLI · pipe** | `cat examples/page.html \| bash scripts/cxtract.sh --format md` | No file input needed |
| 5 | **Node / ESM** | `bash scripts/package-npm.sh && node examples/demo.mjs examples/page.html --clean` | Metadata / block count / sizes plus caller-side cleanup |
| 6 | **Browser (front-end only)** | See "Minimal browser snippet" below | Extraction inside a page, zero backend |
| 7 | **Inside MoonBit source** | See "MoonBit snippet" below | Call `@extract` from `.mbt` / tests |
| 8 | **WASI / moonrun** | `CONTENTKIT_INPUT="$(cat examples/page.html)" moon run --target wasm cli -- --env-input --format json` | wasm CLI without Node |
| 9 | **native** | Install MSVC/gcc, then `moon run --target native cli -- --env-input --format json` | Unavailable without a host C compiler; see "Host limitation" in the main README |
| 10 | **Smoke test without a page** | `bash scripts/cxtract.sh --list` / `--case news-cn --format md` | 14 built-in corpus cases verify the toolchain |

### Minimal browser snippet

First produce a browser-importable ESM, then open it through any static server (do **not** use `file://` — module imports are blocked by CORS):

```bash
bash scripts/package-npm.sh                 # produces js/dist/contentkit.js
cp js/dist/contentkit.js examples/         # local only, not committed
python -m http.server 8000 -d examples     # open http://localhost:8000/demo.html
```

```html
<!-- examples/demo.html (temporary local file) -->
<script type="module">
  import { extractJson, extractText, extractMd, rulesVersion } from "./contentkit.js";
  const html = await (await fetch("./page.html")).text();
  const a = JSON.parse(extractJson(html));
  console.log("rules:", rulesVersion(), "blocks:", a.blocks.length, "score:", a.score);
  console.log(extractText(html));
  console.log(extractMd(html));
</script>
```

### Inside MoonBit source

```moonbit
import { "contentkit/extract" @extract }

let a = @extract.extract(html)          // -> Article
let json = @extract.extract_json(html) // fixed-schema JSON
let text = @extract.extract_text(html)
let md = @extract.extract_md(html)
```

Put it in a `*_wbtest.mbt` test with `assert_eq` checks and run `moon test --target js`, or run the CLI directly with `moon run --target js cli -- --env-input --format json`.

---

## 3. How to judge the result

Check in this order; 30 seconds is enough to localize most issues:

1. **Metadata**: do `title` / `byline` / `site_name` / `published_at` / `lang` follow the §5.5.4 precedence in the main README? A `null` usually means the page simply lacks the tag (e.g. only `article:author`, or no `<html lang>`).
2. **Body head/tail**: `head -20 examples/page.text` and `tail -20` — look for navigation, ads, footers and inline base64 blobs.
3. **Blocks and score**: block count, `score`, `rules_version` (should be `1.0.0`).
4. **Noise post-processing**: `node examples/demo.mjs examples/page.html --clean` filters inline base64 images, ad images and footer promos using **caller-side rules**, then re-renders from the filtered `blocks` — a demo of cleaning **without touching the kernel**. Adjust `isNoise` in `demo.mjs` for your own sites.
5. **Cross-backend consistency**: `page-{js,wasm,wasm-gc}.json` must share one sha256; this is the core of the L3 regression.
6. **Visual**: `python scripts/gen-realworld-demo.py` reads the local artifacts and writes `docs/realworld-demo.html` (single file, works offline) with every block, the full text/Markdown/JSON views, before/after cleanup sizes and the three backend hashes.

```bash
sha256sum examples/page-js.json examples/page-wasm.json examples/page-wasm-gc.json
```

---

## 4. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Mangled Chinese text | Page is GBK / GB2312 | `iconv -f GBK -t UTF-8` |
| `curl` returns 502 / 403 | Proxy or anti-bot rules | Use `--dump-dom` (method C/D), or add `-A` / `-e` headers |
| Almost empty body | JS-rendered page; you captured the empty shell | Use rendered DOM; the kernel **does not execute JavaScript** |
| `byline` / `lang` is `null` | Page lacks the corresponding tags | Expected behavior; fuller metadata and configurable rules are v1.0 work |
| `lead_image` is a login avatar | Empty `og:image` → fallback to first `<img>` | Re-filter by `src` allowlist / dimensions in the caller |
| native link failure | No MSVC / clang-cl on the host | Install a C compiler; `test-all.sh` will then include native automatically |
| CLI output is 1 byte larger than Node | `println` trailing newline | Content is byte-identical; compare like with like (all CLI or all Node) |
| `--help` hangs | Older wrapper waited on stdin | Current wrapper only reads stdin when data is actually present |

---

## 5. What is committed

| Item | In repository | Note |
|---|---|---|
| `examples/run.sh`, `examples/demo.mjs` | ✅ | Generic scripts accepting any HTML / URL |
| `scripts/gen-realworld-demo.py` | ✅ | Generates the visual page from local artifacts |
| `docs/real-world-testing.md` / `.en.md` | ✅ | This bilingual guide |
| `examples/page.html`, `page.url`, `page.*`, `page-{js,wasm,wasm-gc}.json` | ❌ | Local real page and outputs, may contain third-party copyrighted content |
| `docs/realworld-demo.html` | ❌ | Generated locally; embeds the real page body |
| `docs/test-visual.html` | ✅ | Test visualization over **synthetic built-in corpus**, no third-party content |

See also the "Real-world page walkthrough" section of the main README and [examples/README.en.md](../examples/README.en.md).
