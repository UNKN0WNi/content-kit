# content-kit

[![CI](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml) · [![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

🌐 **语言 / Language:** **简体中文** · [English](./README.en.md)

> 一份 MoonBit 源码，产出 JS / WASM / WASM-GC / 原生四套产物；`text` / Markdown / JSON 同源渲染，跨后端输出逐字节一致。

把任意网页变成「干净正文 + 结构化数据」。抽取算法、规则表与领域模型只写一次，CLI、Node、浏览器、边缘 Worker 共享同一份实现。

## 快速开始

工具链绿色免安装：脚本自动把 `.tools/moonbit` 加入 `PATH` 并设置 `MOON_HOME`；系统已装 `moon` 时直接用系统的。

```bash
bash scripts/test-all.sh       # 格式检查 + 四后端 check + 76 用例 × 3 后端
bash scripts/consistency.sh    # 6 份输出逐字节比对
bash scripts/package-npm.sh    # 产出 npm 包并跑 Node 冒烟测试
```

## 用法

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

`js/index.d.ts` 含完整 TypeScript 声明。

### MoonBit

```moonbit
import { "contentkit/extract" @extract }

let a = @extract.extract(html)      // -> Article
let json = @extract.extract_json(html)
let text = @extract.extract_text(html)
let md = @extract.extract_md(html)
```

## 输出

```
Article { title, byline?, site_name?, excerpt?, lead_image?, lang?, published_at?,
          blocks : Array[Block], text, markdown, metadata, score, rules_version }
Block = Paragraph | Heading(level,text) | ListItem | Quote | Code | Image(src,alt?)
```

元数据优先级、打分公式与规则表见 `core/metadata.mbt`、`core/scoring.mbt`、`core/rules.mbt`。

## 一致性

- `core/` / `parse/` / `extract/` 无 `targets` 限制，四后端编译同一份源码；`core/` 零后端依赖。
- 不用运行时 `Json`：字段顺序固定、浮点以整数运算输出 4 位小数、字符串转义统一实现。
- 三种输出只从同一个 `Article.blocks` 渲染；规则表随版本走，对外暴露 `rules_version`。
- 实测：6 份输出均 24,161 B 且逐字节相同；`js` / `wasm` / `wasm-gc` 各 76/76 用例通过。

## 测试与示范

- **可视化测试范例**：[docs/test-visual.html](./docs/test-visual.html)（单文件，离线可开）——13 条真实断言、14 篇语料、6 份输出哈希，均由 `scripts/gen-test-visual.py` 从真实产物生成。
- **真实网页示范**：把任意页面存为 `examples/page.html` 或用 `--fetch` 抓取，三条命令跑完抓取 → 抽取 → 三后端比对 → 可视化：

```bash
bash examples/run.sh --fetch "https://example.com/some-article"
bash examples/run.sh
node examples/demo.mjs examples/page.html --clean
```

> Windows PowerShell：`bash` 可能指向 WSL 启动器并报「没有已安装的分发」。改用 `& "C:\Program Files\Git\bin\bash.exe" examples/run.sh ...`，或 `powershell -ExecutionPolicy Bypass -File examples/run.ps1 -Fetch <URL>`，详见 [examples/README.md](./examples/README.md)。

真实网页快照不入库，脚本通用，任意站点可复现。详见 [各环境快速测试指南](./docs/real-world-testing.md)（[English](./docs/real-world-testing.en.md)）与 [examples/README.md](./examples/README.md)（[English](./examples/README.en.md)）。

## 目录

`core/` 领域模型与规则 · `parse/html`、`parse/plain` 解析 · `extract/` 门面与三输出渲染 · `cli/`、`js/`、`wasm/` 入口 · `testdata/` 语料与 Golden · `scripts/` 构建测试 · `docs/`、`examples/` 示范

## 许可证

Apache-2.0，见 [LICENSE](./LICENSE)。
