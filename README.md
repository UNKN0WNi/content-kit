<div align="center">

# content-kit

**把任意网页变成干净正文 + 结构化数据。**

一份 MoonBit 源码产出 JS / WASM / WASM-GC / Native 四套产物；<br>
`text`、Markdown、JSON 三种视图同源渲染，跨后端逐字节一致。

[![CI](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/UNKN0WNi/content-kit/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](./LICENSE)

[快速开始](#快速开始) · [用法](#用法) · [输出格式](#输出格式) · [架构](#架构) · [测试与质量](#测试与质量) · [English](./README.en.md)

</div>

---

## 为什么用 content-kit

- **一份源码，四端运行。** 抽取逻辑不写 `targets` 分支，JS、WASM、WASM-GC、Native 编译的是同一份 `core/`、`parse/`、`extract/`。
- **输出确定。** 不依赖运行时 `Json` 与哈希表遍历：字段顺序硬编码、浮点定点输出、转义单一实现。同样的输入，永远得到同样的字节。
- **解析容错。** 自实现 HTML 词法与隐式闭合规则，畸形标签、`script` 伪标签、实体、UTF-16 代理对都不会让抽取失败，任何输入都返回合法结果。
- **规则外置。** 权重、阈值、标签表集中在 `core/rules.mbt`，调参不动算法；`rules_version` 随每次输出返回，便于消费方记录口径。
- **零运行时依赖。** 内核不引第三方包，可直接跑在浏览器、Node、边缘 Worker 与 native 二进制里。

## 快速开始

需要 **MoonBit 工具链** 与 **bash**；涉及 npm / 浏览器链路时另需 **Node.js ≥ 18**。`scripts/moon.sh` 会依次查找 `../.tools/moonbit` 与系统 `moon`。

```bash
git clone https://github.com/UNKN0WNi/content-kit.git
cd content-kit

bash scripts/test-all.sh                              # 格式检查 + 四后端类型检查 + 全部测试
bash scripts/cxtract.sh --case news-cn --format md    # 用内置语料跑一次抽取
```

第二条命令会输出内置新闻语料的 Markdown 正文（节选）：

```markdown
# 月球基地开始运行

作者：林深 发布时间：2026-11-14

我国首个月球科研基地于今日正式投入运行，首批六名科研人员已进驻，将开展为期三个月的原位资源利用实验。……

## 后续计划

项目团队计划在下一阶段扩大基地规模，引入更多国际合作载荷，并开展面向深空探测的长期生物学实验，为载人登月积累工程经验。

> 月球不是终点，而是通往更远深空的中转站。
```

换成 `--format text` 得到纯文本，`--format json` 得到固定 schema 的紧凑 JSON。14 篇内置语料可用 `--list` 查看。

## 用法

### CLI

`cxtract` 是四个后端共享的同一个 CLI：输入来自命令行参数或环境变量 `CONTENTKIT_INPUT`，不依赖任何后端特有 FFI。

```bash
bash scripts/cxtract.sh page.html --format json       # 文件输入
cat page.html | bash scripts/cxtract.sh --format md   # 标准输入
CXTRACT_TARGET=wasm bash scripts/cxtract.sh page.html # 切换后端：js | wasm | wasm-gc
bash scripts/cxtract.sh --list                        # 列出内置语料
```

| 参数 | 说明 |
| --- | --- |
| `--format text\|md\|json` | 输出格式，默认 `json` |
| `--case <name>` | 抽取内置语料中的一篇 |
| `--text <html>` | 直接抽取一段内联 HTML 或纯文本 |
| `--env-input` | 从 `CONTENTKIT_INPUT` 读取输入（包装脚本使用） |
| `--list` | 列出内置语料名称 |
| `--rules-version` | 打印当前规则表版本 |
| `-h`, `--help` | 显示帮助 |

### Node / ESM

包尚未发布到 npm registry，先本地构建出 ESM 产物与类型声明：

```bash
bash scripts/package-npm.sh          # 产出 js/dist/contentkit.js + index.d.ts，并跑冒烟测试
```

```js
import { extractJson, extractText, extractMd, rulesVersion } from "./js/dist/contentkit.js";

const article = JSON.parse(extractJson(html)); // 字段顺序固定，可直接比对字节
const text = extractText(html);
const md = extractMd(html);

console.log(rulesVersion(), article.blocks.length, article.score);
```

`js/index.d.ts` 提供完整 TypeScript 声明（`Article`、`ContentBlock`）。

### 浏览器 / 边缘

同一份 ESM 产物可直接被浏览器加载，无需额外打包步骤（用静态服务器打开，`file://` 会被 CORS 拦截）：

```html
<script type="module">
  import { extractJson, extractText } from "./contentkit.js";
  const html = await (await fetch("./page.html")).text();
  console.log(extractText(html), JSON.parse(extractJson(html)).blocks);
</script>
```

WASM 侧用 `moonrun` 即可作为边缘最小运行形态：`CONTENTKIT_INPUT="$(cat page.html)" moon run --target wasm cli -- --env-input`。

### MoonBit

```moonbit
import { "contentkit/extract" @extract }

let article = @extract.extract(html)        // -> @core.Article
let plain   = @extract.extract_plain_text(text)
let auto    = @extract.extract_auto(input)  // 自动判断 HTML / 纯文本
let json    = @extract.extract_json(html)
let md      = @extract.extract_md(html)
```

## 输出格式

三个视图都由同一个 `Article.blocks` 渲染，不存在“各自解析一遍”的第二套逻辑。

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

实际输出是**单行紧凑 JSON**，浮点固定 4 位小数（上例为 `"score":7.7000`），便于逐字节比对。

**内容块类型：**

| `kind` | 字段 | 说明 |
| --- | --- | --- |
| `paragraph` | `text` | 正文段落 |
| `heading` | `level`, `text` | 标题，`level` 为 1–6 |
| `list_item` | `text` | 列表项 |
| `quote` | `text` | 引用 |
| `code` | `text` | 代码块 |
| `image` | `src`, `alt` | 图片，`alt` 可为 `null` |

**元数据优先级**（实现见 `core/metadata.mbt`）：

| 字段 | 取值顺序 |
| --- | --- |
| `title` | JSON-LD `headline` → `og:title` → `twitter:title` → `<title>`（清洗站点后缀）→ 首个 `<h1>` |
| `excerpt` | JSON-LD `description` → `og:description` → `meta[name=description]` → 正文首段（截断 160 字） |
| `site_name` | `og:site_name` → JSON-LD `publisher` → URL host |
| `byline` | JSON-LD `author` → `meta[name=author]` → `.byline` / `.author` |
| `lead_image` | `og:image` → JSON-LD `image` → 正文首张图片 |
| `published_at` | JSON-LD `datePublished` → `article:published_time` → `<time datetime>` |
| `lang` | `<html lang>` → `meta[content-language]` |

## 架构

```text
HTML
└─► parse/html      词法 · 树构造 · 选择器 · 块抽取
    └─► 特征提取      逗号密度 · 段落数 · 链接长度 · 语义权重
        └─► 打分筛选   规则表打分 + 祖先合并
            └─► Article.blocks
                ├─► text
                ├─► markdown
                └─► json
```

| 模块 | 职责 |
| --- | --- |
| `core/` | 领域模型 `Block` / `Metadata` / `Article`、规则表、打分、文本归一化、确定性 JSON 序列化。零后端依赖 |
| `parse/html/` | HTML 词法与树构造（注释、DOCTYPE、属性、实体、隐式闭合、原始文本标签）、选择器子集、正文块抽取 |
| `parse/plain/` | 纯文本与 Markdown 风格分段（标题、列表、引用、代码围栏） |
| `extract/` | 门面 API、三种渲染、语料 bundle 与 Golden 导出 |
| `cli/` `js/` `wasm/` | 三个入口包，共用同一门面 |
| `testdata/` | 14 篇内置语料与 Golden Vector |

打分公式与可调参数集中在 `core/scoring.mbt`、`core/rules.mbt`，采用 Mozilla Readability 的思路但把系数全部外置，不留算法内魔数。

## 一致性保证

「跨后端一致」不是测试时的期望，而是实现上的约束：

- `core/`、`parse/`、`extract/` 不声明 `targets`，四个后端编译同一份源码；`core/` 零后端依赖。
- 不使用运行时 `Json` 值：字段顺序、浮点格式与字符串转义各只有一处实现，避开哈希遍历顺序带来的不确定性。
- 三种输出只从同一个 `blocks` 渲染；规则表随版本走，对外返回 `rules_version`。
- 实测：6 份输出均为 **24,167 B** 且逐字节相同（3 后端 CLI + Node ESM 产物 + WASM 入口 + Golden Vector）；`js` / `wasm` / `wasm-gc` 各 **79/79** 用例通过。

## API 参考

MoonBit（`contentkit/extract`）：

| 函数 | 返回 | 说明 |
| --- | --- | --- |
| `extract(html)` | `Article` | 从 HTML 抽取完整结果 |
| `extract_plain_text(text)` | `Article` | 纯文本 / 邮件正文兜底 |
| `extract_auto(input)` | `Article` | 自动判断 HTML 或纯文本 |
| `extract_text(html)` | `String` | 纯文本视图 |
| `extract_md(html)` | `String` | Markdown 视图 |
| `extract_json(html)` | `String` | 固定 schema 的紧凑 JSON |
| `article_to_json(a)` | `String` | 已有的 `Article` 直接序列化 |
| `current_rules_version()` | `String` | 规则表版本 |

JS / ESM：`extractJson`、`extractText`、`extractMd`、`rulesVersion`、`goldenBundle`（语料 bundle，用于跨后端比对）。

## 测试与质量

```bash
bash scripts/test-all.sh       # 格式检查 + 四后端类型检查 + 79 用例 × 3 后端
bash scripts/consistency.sh    # 6 份输出的逐字节比对
bash scripts/golden.sh         # Golden Vector 快照回归（--update 重新生成）
bash scripts/package-npm.sh    # 构建 npm 产物并跑 Node 冒烟测试
bash scripts/build-all.sh      # 四后端产物与体积，结果写入 BENCHMARKS.md
```

测试分四层：单元（L1）、集成与快照（L2）、跨后端一致性（L3）、性质测试（L4，畸形 HTML 变异 + quickcheck）。CI 在 `ubuntu-latest` 上执行 `moon fmt --check`、四后端 `check` / `test` / `build`，再跑一致性、Golden 与 npm 冒烟。

## 目录结构

```
content-kit/
├── core/           领域模型、规则表、打分、文本与 JSON 序列化
├── parse/
│   ├── html/       HTML 词法/树构造、选择器、正文块抽取
│   └── plain/      纯文本与 Markdown 风格分段
├── extract/        门面 API 与 text / md / json 三种渲染
├── cli/ js/ wasm/  三个入口包
├── testdata/       14 篇内置语料与 Golden Vector
├── scripts/        构建、测试、一致性、npm 打包
├── examples/       真实网页示范（run.sh / demo.mjs）
└── docs/           可视化测试报告与真实网页测试指南
```

## 已知限制

- **不执行 JavaScript。** 客户端渲染的页面需先拿到渲染后 DOM（`examples/run.sh --fetch` 调用本机 Chrome/Edge）。
- **JSON-LD 为基础字段读取。** 不做完整 schema.org 类型展开（v1.0 范围）。
- **语料规模有限。** 当前 14 篇为可复现快照，人工标注的大规模质量评测尚未纳入仓库。
- **native 需要 C 工具链。** 无 MSVC / clang-cl 时 `--target native` 只做类型检查，测试与链接会被跳过（CI 在 Linux 上完整执行）。
- **Windows 上的 `bash`。** 可能命中 WSL 启动器，请用 Git for Windows 的 Bash 或 `powershell -ExecutionPolicy Bypass -File examples/run.ps1`，详见 [examples/README.md](./examples/README.md)。

## 文档与示例

| 文档 | 内容 |
| --- | --- |
| [docs/test-visual.html](./docs/test-visual.html) | 单文件可视化测试报告：真实断言、语料快照、6 份输出哈希（离线可开） |
| [docs/real-world-testing.md](./docs/real-world-testing.md) | 各环境（CLI / Node / 浏览器 / WASI / native）用真实网页快速验证 |
| [examples/README.md](./examples/README.md) | 抓取 → 抽取 → 三后端比对，三步跑通 |
| [BENCHMARKS.md](./BENCHMARKS.md) | 各后端产物体积与预算 |
| [CHANGELOG.md](./CHANGELOG.md) | 版本变更与已知限制 |

## 贡献

欢迎 issue 与 PR。提交前请确保本地全绿：

```bash
bash scripts/test-all.sh && bash scripts/consistency.sh && bash scripts/golden.sh
```

涉及抽取行为的改动需要同步新增回归测试；若输出变化属于预期修复，用 `bash scripts/golden.sh --update` 更新 Golden Vector 并在 PR 中说明原因。代码格式由 `moon fmt` 统一，不接受手工对齐。

## 许可证

Apache-2.0，见 [LICENSE](./LICENSE) 与 [NOTICE](./NOTICE)。
