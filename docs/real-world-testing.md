# 用真实网页快速测试 content-kit（各环境）

🌐 **语言 / Language:** **简体中文** · [English](./real-world-testing.en.md) · [返回主 README](../README.md)

这份指南回答一个问题：**拿到任意一个真实网页，怎样在最短时间内看出 content-kit 的抽取效果？** 全部命令都在仓库根目录执行，不需要内置语料，也不需要联网（页面准备好之后）。

> 抓取到的网页与抽取产物**只留在本机**，`.gitignore` 已排除 `examples/page.*` 和 `docs/realworld-demo.html`，不会随仓库分发。仓库里只保留脚本、文档和可复现方法。

---

## 0. 最短路径（3 条命令）

```bash
# ① 准备任意真实网页，保存为 examples/page.html（UTF-8）
#    或让脚本抓取：
bash examples/run.sh --fetch "https://example.com/some-article"

# ② 一键：三后端抽取 → 逐字节比对 → Node 示范 → 生成可视化页面
bash examples/run.sh

# ③ 看结果
cat examples/page.text          # 纯文本正文
cat examples/page.md            # Markdown
python -m json.tool examples/page.json | head -40   # 结构化结果
```

`run.sh` 的输出形如：

```text
== 三后端 CLI 抽取（同一个真实页面：examples/page.html） ==
   js       <N> bytes  sha256 <16 位哈希>
   wasm     <N> bytes  sha256 <16 位哈希>   ← 三行必须完全相同
   wasm-gc  <N> bytes  sha256 <16 位哈希>
   OK: 3 outputs are byte-identical
== Node / ESM 使用示范 ==
内容块   : <blocks> | score: <score>
输出体积 : text ... / md ... / json ...
```

---

## 1. 准备一个真实网页

| 方式 | 命令 / 操作 | 适用 |
|---|---|---|
| A 手动保存 | 浏览器「另存为 → 网页，仅 HTML」，存成 `examples/page.html` | 最省事，含登录态页面也能测 |
| B `curl` | `curl -A "Mozilla/5.0" -o examples/page.html "https://example.com/a"` | 静态页、服务端渲染页 |
| C 无头浏览器 | `chrome --headless=new --dump-dom "https://example.com/a" > examples/page.html` | **推荐**：拿到渲染后 DOM，正文最完整 |
| D 脚本代劳 | `bash examples/run.sh --fetch "https://example.com/a"` | 自动找本机 Chrome/Edge 并抓到 `examples/page.html` |

三个注意点：

1. **编码必须是 UTF-8**。遇到 GBK 页面先转码：`iconv -f GBK -t UTF-8 page.html > examples/page.html`，否则中文会乱码。
2. **SPA / JS 渲染页**请用方式 C/D；`curl` 拿到的空壳 HTML 只能走 `parse/plain` 兜底。
3. 页面较大（数百 KB）也支持：包装脚本用环境变量通道传递内容，Node / ESM 通道更直接。

---

## 2. 各环境 × 命令速查

| # | 环境 | 命令 | 看什么 |
|---|---|---|---|
| 1 | **CLI · 默认 js 后端** | `bash scripts/cxtract.sh examples/page.html --format json` | 结构化 `Article`，字段顺序固定 |
| 2 | CLI · 三输出 | `--format text` / `--format md` / `--format json` | 三份视图同源，正文一致 |
| 3 | **CLI · wasm / wasm-gc** | `CXTRACT_TARGET=wasm-gc bash scripts/cxtract.sh examples/page.html --format json` | 与 js 输出逐字节一致 |
| 4 | **CLI · 管道** | `cat examples/page.html \| bash scripts/cxtract.sh --format md` | 无文件输入通道 |
| 5 | **Node / ESM** | `bash scripts/package-npm.sh && node examples/demo.mjs examples/page.html --clean` | 打印元数据 / 块数 / 体积，并演示调用方清洗 |
| 6 | **浏览器（纯前端）** | 见下方「浏览器最小片段」 | 零后端、页面内直接抽取 |
| 7 | **MoonBit 源码内** | 见下方「MoonBit 片段」 | 在 `.mbt` / 测试里直接调 `@extract` |
| 8 | **WASI / moonrun** | `CONTENTKIT_INPUT="$(cat examples/page.html)" moon run --target wasm cli -- --env-input --format json` | 不经过 Node，直接跑 wasm CLI |
| 9 | **native 原生** | 先装 MSVC/gcc，再 `moon run --target native cli -- --env-input --format json` | 本机缺 C 编译器时不可用，详见主 README「宿主限制」 |
| 10 | **不依赖真实网页的冒烟** | `bash scripts/cxtract.sh --list` / `--case news-cn --format md` | 14 篇内置语料，验证环境是否正常 |

### 浏览器最小片段

先产出浏览器可 import 的 ESM，再用任意静态服务器打开（不要用 `file://`，模块会被 CORS 拦截）：

```bash
bash scripts/package-npm.sh                 # 产出 js/dist/contentkit.js
cp js/dist/contentkit.js examples/         # 仅本机使用，不入库
python -m http.server 8000 -d examples     # 浏览器打开 http://localhost:8000/demo.html
```

```html
<!-- examples/demo.html（本机临时文件） -->
<script type="module">
  import { extractJson, extractText, extractMd, rulesVersion } from "./contentkit.js";
  const html = await (await fetch("./page.html")).text();
  const a = JSON.parse(extractJson(html));
  console.log("rules:", rulesVersion(), "blocks:", a.blocks.length, "score:", a.score);
  console.log(extractText(html));
  console.log(extractMd(html));
</script>
```

### MoonBit 源码内调用

```moonbit
import { "contentkit/extract" @extract }

let a = @extract.extract(html)          // -> Article
let json = @extract.extract_json(html) // 固定 schema JSON
let text = @extract.extract_text(html)
let md = @extract.extract_md(html)
```

把它放进任意包的 `*_wbtest.mbt` 里用 `assert_eq` 校验，再 `moon test --target js`；或直接用 `moon run --target js cli -- --env-input --format json` 跑 CLI。

---

## 3. 怎么判断「效果好不好」

按这个顺序看，30 秒能定位绝大多数问题：

1. **元数据**：`title` / `byline` / `site_name` / `published_at` / `lang` 是否符合主 README 的 §5.5.4 优先级；`null` 通常是页面本身没提供对应标签（例如只有 `article:author`、`<html>` 无 `lang`）。
2. **正文头尾**：`head -20 examples/page.text` 与 `tail -20`，看是否混入导航、广告、页脚、内联 base64。
3. **块数与分数**：`blocks` 数量、`score`、`rules_version`（应为 `1.0.0`）。
4. **噪声后处理**：`node examples/demo.mjs examples/page.html --clean` 会按**调用方规则**过滤内联 base64 图、广告位图、页脚推广，再由过滤后的 `blocks` 二次渲染，示范如何在**不改内核**的前提下清理。规则在 `demo.mjs` 的 `isNoise` 里，按自己的站点改。
5. **跨后端一致性**：三份 `page-{js,wasm,wasm-gc}.json` 的 sha256 必须相同，这是 L3 回归的核心。
6. **可视化**：`python scripts/gen-realworld-demo.py` 会读本地产物生成 `docs/realworld-demo.html`（单文件离线可开），可逐个查看块、三输出全文、清洗前后体积与三后端哈希。

```bash
sha256sum examples/page-js.json examples/page-wasm.json examples/page-wasm-gc.json
```

---

## 4. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 中文乱码 | 页面是 GBK / GB2312 | `iconv -f GBK -t UTF-8` 转为 UTF-8 |
| `curl` 返回 502 / 403 | 代理或站点反爬 | 用 `--dump-dom`（方式 C/D），或加 `-A` / `-e` 请求头 |
| 抽出的正文几乎为空 | 页面靠 JS 渲染，拿到的是空壳 | 用渲染后 DOM；内核**不执行 JavaScript** |
| `byline` / `lang` 为 `null` | 页面缺少对应标签 | 属预期行为；v1.0 计划做更完整的元数据与可配置规则 |
| `lead_image` 是登录头像 | `og:image` 为空，回退到首个 `<img>` | 调用方按 `src` 白名单/尺寸再筛一次 |
| native 链接失败 | 本机无 MSVC / clang-cl | 装 C 编译器；`test-all.sh` 会自动纳入 native |
| CLI 输出比 Node 多 1 字节 | `println` 的尾随换行 | 内容逐字节一致，比对时统一用 CLI 或统一用 Node |
| `--help` 卡住 | 旧版脚本会等待 stdin | 当前包装脚本只在 stdin 确实有数据时才读 |

---

## 5. 与仓库的关系

| 内容 | 是否入库 | 说明 |
|---|---|---|
| `examples/run.sh`、`examples/demo.mjs` | ✅ | 通用脚本，接受任意 HTML / URL |
| `scripts/gen-realworld-demo.py` | ✅ | 从本地产物生成可视化页面 |
| `docs/real-world-testing.md` / `.en.md` | ✅ | 本指南（中英双语） |
| `examples/page.html`、`page.url`、`page.*`、`page-{js,wasm,wasm-gc}.json` | ❌ | 本地真实页面与抽取产物，可能含第三方版权内容 |
| `docs/realworld-demo.html` | ❌ | 由本地产物生成，内嵌真实页面正文 |
| `docs/test-visual.html` | ✅ | 内置**合成语料**的测试可视化，不含第三方内容 |

各环境的完整说明也见主 README 的「真实网页使用示范」章节与 [examples/README.md](../examples/README.md)。
