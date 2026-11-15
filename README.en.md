<div align="center">

# content-kit

**Turn any web page into clean body text and structured data.**

One MoonBit codebase produces JS / WASM / WASM-GC / Native artifacts;<br>
`text`, Markdown and JSON are rendered from a single source and are byte-for-byte identical across backends.

[![CI](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

[Quick start](#quick-start) · [Usage](#usage) · [Output](#output) · [Architecture](#architecture) · [Testing](#testing-and-quality) · [简体中文](./README.md)

</div>

---

## Why content-kit

- **One source, four runtimes.** The extraction logic declares no `targets` split: JS, WASM, WASM-GC and Native all compile the same `core/`, `parse/` and `extract/`.
- **Deterministic output.** No runtime `Json` values and no hash-map iteration: field order is hardcoded, floats are fixed-point, escaping has a single implementation. The same input always yields the same bytes.
- **Fault-tolerant parsing.** A self-contained HTML lexer with implicit-close rules, so malformed markup, fake tags inside `script`, entities and UTF-16 surrogate pairs never break extraction — every input returns a valid result.
- **Rules live outside the algorithm.** Weights, thresholds and tag tables are in `core/rules.mbt`; tuning never touches the algorithm, and `rules_version` ships with every result.
- **No runtime dependencies.** The kernel pulls in no third-party packages, so it runs unchanged in browsers, Node, edge workers and native binaries.

## Quick start

You need the **MoonBit toolchain** and **bash**; the npm and browser paths additionally need **Node.js ≥ 18**. `scripts/moon.sh` looks for `../.tools/moonbit` first, then a system-wide `moon`.

```bash
git clone https://github.com/UNKN0WNi/content-kit.git
cd content-kit

bash scripts/test-all.sh                              # format check + four-backend typecheck + all tests
bash scripts/cxtract.sh --case news-cn --format md    # run one extraction on the built-in corpus
```

The second command prints the Markdown body of the built-in news article (excerpt):

```markdown
# 月球基地开始运行

作者：林深 发布时间：2026-11-14

我国首个月球科研基地于今日正式投入运行，首批六名科研人员已进驻，将开展为期三个月的原位资源利用实验。……

## 后续计划

项目团队计划在下一阶段扩大基地规模，引入更多国际合作载荷，并开展面向深空探测的长期生物学实验，为载人登月积累工程经验。

> 月球不是终点，而是通往更远深空的中转站。
```

Use `--format text` for plain text or `--format json` for the fixed-schema compact JSON. `--list` shows all 14 built-in cases.

## Usage

### CLI

`cxtract` is one CLI shared by all four backends: input comes from argv or the `CONTENTKIT_INPUT` environment variable, with no backend-specific FFI.

```bash
bash scripts/cxtract.sh page.html --format json       # file input
cat page.html | bash scripts/cxtract.sh --format md   # stdin
CXTRACT_TARGET=wasm bash scripts/cxtract.sh page.html # switch backend: js | wasm | wasm-gc
bash scripts/cxtract.sh --list                        # list built-in cases
```

| Flag | Description |
| --- | --- |
| `--format text\|md\|json` | Output format, `json` by default |
| `--case <name>` | Extract one built-in corpus case |
| `--text <html>` | Extract inline HTML or plain text |
| `--env-input` | Read input from `CONTENTKIT_INPUT` (used by the wrapper) |
| `--list` | List built-in case names |
| `--rules-version` | Print the current rule-table version |
| `-h`, `--help` | Show help |

### Node / ESM

The package is not published to the npm registry yet, so build the ESM artifact and type declarations locally:

```bash
bash scripts/package-npm.sh          # emits js/dist/contentkit.js + index.d.ts, runs the smoke test
```

```js
import { extractJson, extractText, extractMd, rulesVersion } from "./js/dist/contentkit.js";

const article = JSON.parse(extractJson(html)); // fixed field order, byte-comparable
const text = extractText(html);
const md = extractMd(html);

console.log(rulesVersion(), article.blocks.length, article.score);
```

`js/index.d.ts` ships full TypeScript declarations (`Article`, `ContentBlock`).

### Browser / edge

The same ESM artifact loads directly in the browser with no extra bundling step (serve it over HTTP; `file://` is blocked by CORS):

```html
<script type="module">
  import { extractJson, extractText } from "./contentkit.js";
  const html = await (await fetch("./page.html")).text();
  console.log(extractText(html), JSON.parse(extractJson(html)).blocks);
</script>
```

On the WASM side, `moonrun` is the smallest edge form factor: `CONTENTKIT_INPUT="$(cat page.html)" moon run --target wasm cli -- --env-input`.

### MoonBit

```moonbit
import { "contentkit/extract" @extract }

let article = @extract.extract(html)        // -> @core.Article
let plain   = @extract.extract_plain_text(text)
let auto    = @extract.extract_auto(input)  // auto-detects HTML vs plain text
let json    = @extract.extract_json(html)
let md      = @extract.extract_md(html)
```

## Output

All three views render from the same `Article.blocks`; there is no second parsing pass per format.

```json
{
  "title": "示例标题",
  "byline": null,
  "site_name": "示例站点",
  "excerpt": "这是一段示例摘要。",
  "lead_image": null,
  "lang": "zh-CN",
  "published_at": null,
  "blocks": [
    { "kind": "heading", "level": 1, "text": "示例标题" },
    { "kind": "paragraph", "text": "第一段正文，用来演示 content-kit 的输出结构。" },
    { "kind": "paragraph", "text": "第二段正文。" }
  ],
  "text": "示例标题\n\n第一段正文，用来演示 content-kit 的输出结构。\n\n第二段正文。",
  "markdown": "# 示例标题\n\n第一段正文，用来演示 content-kit 的输出结构。\n\n第二段正文。",
  "metadata": {
    "site_name": "示例站点",
    "description": "这是一段示例摘要。",
    "lead_image": null,
    "lang": "zh-CN",
    "published_at": null,
    "keywords": [],
    "jsonld": null
  },
  "score": 7.7,
  "rules_version": "1.0.0"
}
```

The real output is **single-line compact JSON** with floats fixed to 4 decimals (`"score":7.7000` above), which keeps byte comparison simple.

**Block kinds:**

| `kind` | Fields | Notes |
| --- | --- | --- |
| `paragraph` | `text` | Body paragraph |
| `heading` | `level`, `text` | Heading, `level` 1–6 |
| `list_item` | `text` | List item |
| `quote` | `text` | Block quote |
| `code` | `text` | Code block |
| `image` | `src`, `alt` | Image, `alt` may be `null` |

**Metadata precedence** (implementation in `core/metadata.mbt`):

| Field | Order |
| --- | --- |
| `title` | JSON-LD `headline` → `og:title` → `twitter:title` → `<title>` (site suffix stripped) → first `<h1>` |
| `excerpt` | JSON-LD `description` → `og:description` → `meta[name=description]` → first body paragraph (truncated to 160 chars) |
| `site_name` | `og:site_name` → JSON-LD `publisher` → URL host |
| `byline` | JSON-LD `author` → `meta[name=author]` → `.byline` / `.author` |
| `lead_image` | `og:image` → JSON-LD `image` → first image in body |
| `published_at` | JSON-LD `datePublished` → `article:published_time` → `<time datetime>` |
| `lang` | `<html lang>` → `meta[content-language]` |

## Architecture

```text
HTML
└─► parse/html      lexer · tree builder · selectors · block extraction
    └─► features     comma density · paragraph count · link length · semantic weight
        └─► scoring  rule-table score + ancestor merging
            └─► Article.blocks
                ├─► text
                ├─► markdown
                └─► json
```

| Module | Responsibility |
| --- | --- |
| `core/` | Domain model `Block` / `Metadata` / `Article`, rule table, scoring, text normalization, deterministic JSON serializer. Zero backend dependencies |
| `parse/html/` | HTML lexer and tree builder (comments, DOCTYPE, attributes, entities, implicit close, raw-text elements), selector subset, block extraction |
| `parse/plain/` | Plain text and Markdown-style segmentation (headings, lists, quotes, code fences) |
| `extract/` | Facade API, three renderers, corpus bundle / Golden export |
| `cli/` `js/` `wasm/` | Three entry packages over the same facade |
| `testdata/` | 14 built-in corpus cases and Golden Vector |

The scoring formula and its tunables live in `core/scoring.mbt` and `core/rules.mbt`: the approach follows Mozilla Readability, but every coefficient is externalized instead of hardcoded in the algorithm.

## Consistency guarantees

Cross-backend consistency is an implementation constraint, not a test-time hope:

- `core/`, `parse/` and `extract/` declare no `targets`, so all four backends compile the same source; `core/` has zero backend dependencies.
- No runtime `Json` values: field order, float formatting and string escaping each have exactly one implementation, removing hash-iteration nondeterminism.
- All three views render from the same `blocks`; the rule table is versioned and every result exposes `rules_version`.
- Measured: 6 outputs of **24,167 B** each, byte-identical (3 backend CLIs + Node ESM artifact + WASM entry + Golden Vector); **79/79** tests pass on `js`, `wasm` and `wasm-gc`.

## API reference

MoonBit (`contentkit/extract`):

| Function | Returns | Description |
| --- | --- | --- |
| `extract(html)` | `Article` | Full extraction from HTML |
| `extract_plain_text(text)` | `Article` | Plain-text / email fallback |
| `extract_auto(input)` | `Article` | Auto-detects HTML vs plain text |
| `extract_text(html)` | `String` | Plain-text view |
| `extract_md(html)` | `String` | Markdown view |
| `extract_json(html)` | `String` | Fixed-schema compact JSON |
| `article_to_json(a)` | `String` | Serialize an existing `Article` |
| `current_rules_version()` | `String` | Rule-table version |

JS / ESM: `extractJson`, `extractText`, `extractMd`, `rulesVersion`, `goldenBundle` (corpus bundle for cross-backend comparison).

## Testing and quality

```bash
bash scripts/test-all.sh       # format check + four-backend typecheck + 79 cases x 3 backends
bash scripts/consistency.sh    # byte-for-byte comparison of 6 outputs
bash scripts/golden.sh         # Golden Vector regression (--update to regenerate)
bash scripts/package-npm.sh    # build the npm artifact and run the Node smoke test
bash scripts/build-all.sh      # four-backend artifacts and sizes, written to BENCHMARKS.md
```

Tests come in four layers: unit (L1), integration and snapshots (L2), cross-backend consistency (L3), property tests (L4, malformed-HTML mutations plus quickcheck). CI runs `moon fmt --check`, then `check` / `test` / `build` on all four backends on `ubuntu-latest`, followed by consistency, Golden and the npm smoke test.

## Layout

```
content-kit/
├── core/           domain model, rule table, scoring, text and JSON serialization
├── parse/
│   ├── html/       HTML lexer/tree, selectors, block extraction
│   └── plain/      plain-text and Markdown-style segmentation
├── extract/        facade API and the text / md / json renderers
├── cli/ js/ wasm/  three entry packages
├── testdata/       14 built-in corpus cases and Golden Vector
├── scripts/        build, test, consistency, npm packaging
├── examples/       real-world demo (run.sh / demo.mjs)
└── docs/           visual test report and real-world testing guide
```

## Known limitations

- **No JavaScript execution.** Client-rendered pages need the rendered DOM first (`examples/run.sh --fetch` drives local Chrome/Edge).
- **Basic JSON-LD only.** No full schema.org type expansion (v1.0 scope).
- **Limited corpus size.** The current 14 cases are reproducible snapshots; a large human-annotated quality benchmark is not in the repo yet.
- **Native needs a C toolchain.** Without MSVC / clang-cl, `--target native` only typechecks and tests/linking are skipped (CI runs them fully on Linux).
- **`bash` on Windows.** It may resolve to the WSL launcher; use Git for Windows Bash or `powershell -ExecutionPolicy Bypass -File examples/run.ps1`. See [examples/README.en.md](./examples/README.en.md).

## Documentation and demos

| Document | Contents |
| --- | --- |
| [docs/test-visual.html](./docs/test-visual.html) | Single-file visual test report: real assertions, corpus snapshots, 6 output hashes (works offline) |
| [docs/real-world-testing.en.md](./docs/real-world-testing.en.md) | Verify with a real page in every environment (CLI / Node / browser / WASI / native) |
| [examples/README.en.md](./examples/README.en.md) | Fetch → extract → three-backend comparison in three steps |
| [BENCHMARKS.md](./BENCHMARKS.md) | Artifact sizes and budgets per backend |
| [CHANGELOG.md](./CHANGELOG.md) | Release history and known limitations |

## Contributing

Issues and PRs are welcome. Make sure everything is green before submitting:

```bash
bash scripts/test-all.sh && bash scripts/consistency.sh && bash scripts/golden.sh
```

Behavioural changes need new regression tests; when output changes are an intended fix, run `bash scripts/golden.sh --update` and explain the diff in the PR. Formatting is owned by `moon fmt` — hand alignment is not accepted.

## License

Apache-2.0, see [LICENSE](./LICENSE) and [NOTICE](./NOTICE).
