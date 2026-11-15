# content-kit

[![CI](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml) · [![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

🌐 **Language / 语言:** **English** · [简体中文](./README.md)

> One MoonBit codebase produces JS / WASM / WASM-GC / native artifacts; `text`, Markdown and JSON are rendered from a single source, and cross-backend output is byte-for-byte identical.

Turn any web page into **clean body text + structured data**. The extraction algorithm, rule table and domain model are written once and shared by a CLI, Node, the browser and edge Workers.

## Quick start

The toolchain is portable and needs no installation: scripts automatically add `.tools/moonbit` to `PATH` and set `MOON_HOME`. If `moon` is already installed system-wide, that one is used.

```bash
bash scripts/test-all.sh       # format check + four-backend check + 67 cases x 3 backends
bash scripts/consistency.sh    # byte-for-byte comparison of 6 outputs
bash scripts/package-npm.sh    # build the npm package and run the Node smoke test
```

## Usage

### CLI

```bash
bash scripts/cxtract.sh page.html --format json   # json | text | md
cat page.html | bash scripts/cxtract.sh --format md
CXTRACT_TARGET=wasm bash scripts/cxtract.sh page.html   # js | wasm | wasm-gc
bash scripts/cxtract.sh --help
```

### npm / Node

```js
import { extractJson, extractText, extractMd, rulesVersion } from "content-kit";

const article = JSON.parse(extractJson(html));
const text = extractText(html);
const md = extractMd(html);
```

`js/index.d.ts` ships complete TypeScript declarations.

### MoonBit

```moonbit
import { "contentkit/extract" @extract }

let a = @extract.extract(html)      // -> Article
let json = @extract.extract_json(html)
let text = @extract.extract_text(html)
let md = @extract.extract_md(html)
```

## Output

```
Article { title, byline?, site_name?, excerpt?, lead_image?, lang?, published_at?,
          blocks : Array[Block], text, markdown, metadata, score, rules_version }
Block = Paragraph | Heading(level,text) | ListItem | Quote | Code | Image(src,alt?)
```

Metadata precedence, the scoring formula and the rule table live in `core/metadata.mbt`, `core/scoring.mbt` and `core/rules.mbt`.

## Consistency

- `core/` / `parse/` / `extract/` have no `targets` restriction: all four backends compile the same source; `core/` has zero backend dependencies.
- No runtime `Json` value: field order is fixed, floats are emitted as fixed 4-decimal values via integer arithmetic, and string escaping has one implementation.
- All three views are rendered from the same `Article.blocks`; the rule table ships with the version and exposes `rules_version`.
- Measured: all 6 outputs are 23,757 B and byte-identical; 67/67 tests pass on `js`, `wasm` and `wasm-gc`.

## Tests & demos

- **Visual test walkthrough**: [docs/test-visual.html](./docs/test-visual.html) — a single offline file with 13 real assertions, 14 corpus cases and 6 output hashes, all generated from real artifacts by `scripts/gen-test-visual.py`. (UI text is in Chinese.)
- **Real-world page demo**: save any page as `examples/page.html` or fetch it with `--fetch`, then run the whole pipeline (fetch → extraction → three-backend comparison → visual page) in three commands:

```bash
bash examples/run.sh --fetch "https://example.com/some-article"
bash examples/run.sh
node examples/demo.mjs examples/page.html --clean
```

> Windows PowerShell: `bash` may resolve to the WSL launcher and fail with *"no installed distributions"*. Use `& "C:\Program Files\Git\bin\bash.exe" examples/run.sh ...` or `powershell -ExecutionPolicy Bypass -File examples/run.ps1 -Fetch <URL>`; see [examples/README.en.md](./examples/README.en.md).

Real page snapshots are not committed; the scripts are generic and reproducible on any site. See the [quick-testing guide](./docs/real-world-testing.en.md) ([中文](./docs/real-world-testing.md)) and [examples/README.en.md](./examples/README.en.md) ([中文](./examples/README.md)).

## Layout

`core/` models and rules · `parse/html`, `parse/plain` parsers · `extract/` facade and three renderers · `cli/`, `js/`, `wasm/` entry points · `testdata/` corpus and Golden files · `scripts/` build and test · `docs/`, `examples/` demos

## License

Apache-2.0, see [LICENSE](./LICENSE).
