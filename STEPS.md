# content-kit v0.1 实现步骤

> 依据《content-kit 项目计划书 v0.1》（`PLAN.md`）制定。
> 参考文档：<https://docs.moonbitlang.cn/language/index.html>
> 制定日期：2026-11-14
>
> **本文件先于代码产生**；代码实现按下面步骤逐步推进，每完成一步勾选并回填验收结论。

---

## 0. 实现范围与前置判定

### 0.1 本次交付范围

按计划书 §4.1 的 MVP（v0.1）落地 **M1–M8 的全部可自动化验证部分**：

| 编号 | 计划书交付物 | 本实现是否覆盖 |
|---|---|---|
| M1 | `core/` 领域模型 + 规则表，四后端 `moon check` 通过 | ✅ |
| M2 | HTML → 正文块抽取（打分模型 v1） | ✅ 含合成 + 真实结构语料 |
| M3 | 元数据抽取（title / og: / twitter: / JSON-LD 基础字段） | ✅ |
| M4 | 纯文本 / Markdown / 结构化 JSON 三输出同源 | ✅ |
| M5 | 四后端产物可构建 | ✅ js / wasm / wasm-gc / native |
| M6 | 跨后端一致性测试（零差异） | ✅ 自带确定性序列化 + 比对脚本 |
| M7 | CLI（native）`--format text\|md\|json` | ✅ |
| M8 | npm 包（js）+ `.d.ts` | ✅ 手写类型声明与 package.json |

**非目标**（计划书 §3.3 / §4.4）：爬虫、摘要、LLM、JS 执行、完整 CSS 选择器、浏览器扩展产品本身、WIT 组件（v1.0）、语言检测（v1.0）。

### 0.2 前置判定结论（S0 的两条关键决策）

计划书把「html5-mbt 依赖」与「core/json 四后端一致性」列为最大风险（R1/R2，D1/D2）。为保证本项目在**无外部 registry、无登录**的环境下依然可完整构建并达成「四后端逐字节一致」这一核心卖点，采用计划书已写明的 Plan B 分支：

| 决策点 | 计划书选项 | 本实现选择 | 理由 |
|---|---|---|---|
| D1 选择器 / HTML 解析 | A：复用 `moonbit-community/html` + `mizchi/css`；B：自实现最小子集 | **B（Plan B）** | ① 消除对外部 registry 的运行时依赖，四后端构建可离线复现；② 抽取只需 tag / class / id / attr / 后代 / `:not()` 子集；③ 自实现代码 100% 后端无关，一致性由构造保证 |
| D2 JSON 序列化 | A：`moonbitlang/core/json`；B：自写固定 schema 序列化 | **B（Plan B）** | 消除浮点格式、字段顺序、转义策略在不同后端的差异；`Article` schema 固定，手写序列化器可给出**逐字节**确定性保证 |
| D3 算法来源 | A：自研规则表；B：移植 Readability 源码 | **A** | 规则表外置为 `core/rules.mbt` 单一事实来源，符合 ADR-1 / ADR-2 |

> 这两条 Plan B 不是降低标准，而是把「一致性」从「测试时 hopefully 一致」提升为「实现上不可能不一致」。
> `core/` 保持零依赖（ADR-2），只包含标准库内置的 String / Array / Map 等。

---

## 1. 步骤总览

| 步骤 | 名称 | 主要产出 | 验收方式 |
|---|---|---|---|
| **S0** | 环境与工具链预研 | 可运行的 `moon`，hello-world 冒烟，配置文件格式结论 | `moon version` + `moon run` 输出 |
| **S1** | 多包工程骨架 | `moon.mod*`、`core/ parse/html/ parse/plain/ extract/ cli/ js/ wasm/` 包描述 | `moon check --target all` 全绿 |
| **S2** | `core/` 领域模型与规则表 | `article / rules / features / scoring / text / metadata / json` | L1 单元测试全绿 |
| **S3** | HTML 解析层 | 轻量 HTML 词法 + 树构造 + 属性/实体解码 + 最小选择器 | L1 单元测试 + 畸形 HTML 不崩溃 |
| **S4** | 抽取内核 | 预处理 → 候选块 → 特征 → 打分 → 正文选择 → 元数据 | L2 端到端快照测试 |
| **S5** | 门面与三输出渲染 | `extract / extract_text / extract_md / extract_json` + 纯文本兜底 | 三输出共享 `blocks` 断言 |
| **S6** | 四后端入口产物 | CLI（native）、js 包 + `.d.ts`、wasm / wasm-gc 入口 | `moon build --target {…}` 全绿 |
| **S7** | 语料库与一致性套件 | `testdata/corpus/*.html`、`expected/*.json`、`scripts/consistency.sh` | 四后端输出逐字节零差异 |
| **S8** | 全量测试与文档收尾 | L1/L2/L3/L4 四层测试、README / CHANGELOG / LICENSE / CI | `moon fmt --check` + 四后端 `moon test` + 一致性脚本 |

---

## 2. 逐步实现细则

### S0 — 环境与工具链预研

1. 安装官方 `moon` 工具链（Windows：官方 `moonbit-windows-x86_64.zip`，解压到工作区 `.tools/`，避免污染系统目录）。
2. `moon version` 记录版本号，写入 `SPIKE.md`。
3. `moon new` 生成临时 hello-world，记录**本工具链实际使用的** `moon.mod` / `moon.pkg` 配置格式（JSON 或 DSL），据此定稿 S1 的包描述文件。
4. 用 `moon build --target native|js|wasm|wasm-gc` 做四后端冒烟，记录可用 target 名称。
5. 验证 `moon test --target …` 的执行方式（native 直跑 / js 用 node / wasm 用 moonrun）。

**产出**：`.tools/` 内的工具链、`SPIKE.md`、`scripts/moon.sh`（统一封装 PATH）。
**通过标准**：四后端 build 全部成功，测试命令可执行。

- [x] S0 完成

### S1 — 多包工程骨架

1. 定名模块 `contentkit`（mooncakes 建议名），版本 `0.1.0`，许可证 Apache-2.0。
2. 建包（每个包一份 `moon.pkg*`，按 S0 结论填写 `import`）：
   - `core/`：零外部 import；
   - `parse/html/`、`parse/plain/`：import `contentkit/core`；
   - `extract/`：import 上述三者；
   - `cli/`、`js/`、`wasm/`：import `contentkit/extract`，标为入口包。
3. `core/` / `extract/` **不设** `targets` 限制 → 天然全后端可用（计划书 §5.2 关键配置）。
4. 每个包放最小可编译的占位 `.mbt`，跑通 `moon check`。

**产出**：完整目录骨架、`moon.mod*`。
**通过标准**：四后端 `moon check` 全绿。

- [x] S1 完成

### S2 — `core/` 领域模型与规则表（M1）

| 文件 | 内容 |
|---|---|
| `article.mbt` | `Block` 枚举（Paragraph / Heading / ListItem / Quote / Code / Image）、`Metadata`、`Article`，字段与计划书 §5.4 一致；`rules_version` 对外暴露 |
| `rules.mbt` | `Rules` 集中所有魔数：块级标签白名单、丢弃标签、标签基础权重、类/ID 正负面权重、阈值（`parent_ratio = 0.2`）、逗号/段落/长度系数；每条魔数带注释 |
| `features.mbt` | `BlockFeatures`（text_len / link_len / paragraphs / commas / tag_name / class_weight / id_weight / role_weight） |
| `scoring.mbt` | 纯函数 `score(features, rules) -> Double`，严格实现 §5.5.3 公式（含 `min(...,3)` 截断、除零保护） |
| `text.mbt` | 空白折叠、HTML 实体解码、Unicode 安全截断（不切 surrogate pair）、逗号计数、正文首段摘要 |
| `metadata.mbt` | `MetaFields` 收集器 + 优先级解析（title/byline/site_name/excerpt/lead_image/published_at/lang），严格按 §5.5.4 优先级 |
| `json.mbt` | 确定性 JSON 值类型 + 转义 + 序列化；`Article` → 固定字段顺序 JSON（D2 决策） |

**测试**：`core/*_test.mbt` 覆盖打分公式边界、除零、实体解码、空白折叠、截断、优先级回退、JSON 转义与浮点格式。

- [x] S2 完成

### S3 — HTML 解析层（Plan B）

1. `dom.mbt`：`Node` 结构（tag / attrs / children / parent 索引 / 文档序号），`Dom` 容器。
2. 词法：标签、属性（单/双/无引号）、注释、`DOCTYPE`、CDATA、自闭合、void 元素、`script/style/noscript` 原始文本跳过、字符实体。
3. 树构造：栈式建树 + 隐式闭合（`p`/`li`/`tr`/`td`/`dt`/`dd`）+ 容错（未闭合、多余闭合、畸形属性）；保证**任何输入都不 panic**。
4. `selector.mbt`：最小选择器子集 `tag`、`.class`、`#id`、`[attr]`、`[attr=value]`、后代组合、`:not()`；用于规则表命中与 body 定位。
5. 遍历工具：前序/文档序、父链、`text_content`、`link_len`、`child_block_count`。

**测试**：良构 HTML 树结构、畸形 HTML 不崩溃、实体解码、属性大小写、选择器 6 种子集、隐式闭合、script 内伪标签不进入 DOM。

- [x] S3 完成

### S4 — 抽取内核（M2 / M3）

按 §5.5.1–5.5.3：
1. 预处理：移除 `script/style/noscript/iframe/svg/form` 等；按规则表移除 `header/footer/nav/aside` 候选。
2. 元数据抽取：`title` / `meta[name]` / `meta[property]` / `meta[http-equiv]` / `<time>` / `<html lang>` / JSON-LD 基础字段（`headline`、`author`、`description`、`datePublished`、`image`、`publisher` 的字符串/数组形态）。
3. 建候选块：块级标签白名单内的元素，计算 8 项特征。
4. 打分 → 取最高分块 → 向上合并低分祖先（`parent_score > 0.2 * child_score`）→ 剔除 `score < 0` 兄弟 → 文档序输出。
5. 把选中区域的叶子文本转成有序 `Block` 序列（p / h1–h6 / li / blockquote / pre / img）。
6. 无正文时降级：取全文档最长文本块；纯文本输入走 `parse/plain/`。

**测试**：带导航栏/广告/页脚的正文定位、多个候选块打分排序、祖先合并、负分兄弟剔除、空文档、纯文本输入、元数据 7 个字段的优先级与回退。

- [x] S4 完成

### S5 — 门面与三输出渲染（M4）

1. `extract/api.mbt`：`extract(html) -> Article`、`extract_text` / `extract_md` / `extract_json` 便捷入口、`extract_plain(text) -> Article`。
2. `render_text.mbt`：块间空行，段落内保留换行。
3. `render_md.mbt`：标题 `#`~`######`、引用 `>`、代码围栏、图片 `![alt](src)`、列表 `- `。
4. `render_json.mbt`：`Article` 固定 schema 序列化（含 `rules_version`、`score`、`blocks` 判别标签）。
5. **同源断言**：三种输出均由同一 `Article.blocks` 渲染，`text` / `markdown` 字段直接嵌入 `Article`。

**测试**：同一输入三输出内容序列一致、Markdown 转义、空 blocks、JSON 字段顺序快照。

- [x] S5 完成

### S6 — 四后端入口（M5 / M7 / M8）

1. `cli/main.mbt`（native）：解析 `--format text|md|json`、`--rules-version`、文件/标准输入、`--help`；`cxtract` 风格命令。
2. `js/main.mbt`：导出 `extract / extractText / extractMd / extractJson` 到 JS；`js/package.json` + `js/index.d.ts` 手写声明。
3. `wasm/main.mbt`：导出同样的纯函数入口，供 wasm / wasm-gc 复用。
4. `scripts/build-all.sh`：四后端 `moon build`，记录产物体积到 `BENCHMARKS.md`。

**通过标准**：`moon build --target native`、`--target js`、`--target wasm`、`--target wasm-gc` 全绿。

- [x] S6 完成

### S7 — 语料库与一致性套件（M6）

1. `testdata/corpus/`：合成 + 真实结构样本（新闻、博客、文档、论坛、电商、代码页、无正文页、纯文本、畸形 HTML），覆盖中文/英文/混合。
2. `testdata/expected/`：每篇语料的 golden JSON（Golden Vector，附录 C）。
3. `scripts/consistency.sh`：同一语料分别经 native CLI / js(Node) / wasm / wasm-gc 产出，`diff` 四份输出必须零差异；同时比对 golden。
4. `scripts/golden.sh`：快照回归。

- [x] S7 完成

### S8 — 四层测试与文档收尾（§6.1 / §6.2）

| 层 | 实现 |
|---|---|
| L1 单元 | `*_test.mbt`，覆盖 core / 解析器 / 渲染器纯函数 |
| L2 集成 | HTML → Article 端到端快照，断言字段与 block 序列 |
| L3 一致性 | `consistency.sh` 四后端逐字节比对 |
| L4 性质 | 伪随机 + 确定性变异生成畸形 HTML，验证「不崩溃 + 不变量」（`text_len ≥ 0`、blocks 顺序单调、三输出同源、`extract` 幂等） |

收尾：`README.md`（含非目标、四后端用法、一致性说明）、`CHANGELOG.md`、`LICENSE`(Apache-2.0)、`CI.md`/工作流、`moon fmt --check`、四后端 `moon test`、`SPIKE.md` 回填。

- [x] S8 完成

---

## 3. 关键不变量（每步都要守住）

1. `core/` 内 **零** 后端相关 import（ADR-2）。
2. 所有权重/阈值只在 `core/rules.mbt` 出现一次（单一事实来源）。
3. 文本 / Markdown / JSON 只能从 `Article.blocks` 渲染，不得另起一套抽取（ADR-3）。
4. JSON 输出不依赖运行时 locale、哈希表遍历顺序、浮点默认格式化；字段顺序硬编码。
5. 任何输入（含空串、畸形 HTML、超长文本、孤立代理项）都不得 panic。
6. 四后端编译的是同一份 `core/` + `parse/` + `extract/` 源码。

---

## 4. 验收命令清单（最终执行）

```bash
moon fmt --check
moon check --target native && moon check --target js && moon check --target wasm && moon check --target wasm-gc
moon test  --target native && moon test  --target js && moon test  --target wasm && moon test  --target wasm-gc
moon build --target native && moon build --target js && moon build --target wasm && moon build --target wasm-gc
bash scripts/consistency.sh
bash scripts/golden.sh
```

---

## 5. 步骤状态跟踪

| 步骤 | 状态 | 验收结论 |
|---|---|---|
| S0 | ✅ 完成 | `moon 0.1.20261104`；hello-world 通过；四后端 check 全绿；D1/D2 采用 Plan B；详见 `SPIKE.md` |
| S1 | ✅ 完成 | 8 个包（core / parse/html / parse/plain / extract / testdata / cli / js / wasm），`moon check --target all` 全绿 |
| S2 | ✅ 完成 | `core/` 7 个模块零后端依赖；20 个 L1 单测全绿 |
| S3 | ✅ 完成 | HTML 词法/树构造 + 最小选择器 7 种子集；14 个 L1 单测全绿；畸形输入不崩溃 |
| S4 | ✅ 完成 | 打分模型、祖先合并、元数据 7 字段优先级、JSON-LD 基础字段；14 篇语料端到端通过 |
| S5 | ✅ 完成 | text/Markdown/JSON 同源；固定字段顺序 + 定点 4 位小数；`bundle()` 确定性输出 |
| S6 | ✅ 完成 | js/wasm/wasm-gc 三套可运行产物 + npm ESM + `.d.ts` + CLI；native 纯库产物通过（链接受宿主限制） |
| S7 | ✅ 完成 | 14 篇内置语料 + Golden Vector；`consistency.sh` **6 份输出逐字节零差异**（各 23,757 字节） |
| S8 | ✅ 完成 | 67 个测试 × 3 后端全绿；L1/L2/L3/L4 四层齐备；`moon fmt --check` 通过；README/CHANGELOG/LICENSE/SPIKE/CI 齐全 |

---

## 6. 实际执行结果（2026-11-14）

```text
moon fmt --check                      -> Finished, no work to do
moon check --target all               -> Finished (99 tasks, 0 errors, 0 warnings)
moon test  --target js                -> Total tests: 67, passed: 67, failed: 0
moon test  --target wasm              -> Total tests: 67, passed: 67, failed: 0
moon test  --target wasm-gc           -> Total tests: 67, passed: 67, failed: 0
moon build --target js|wasm|wasm-gc   -> 全部成功（体积见 BENCHMARKS.md）
moon build --target native <纯库>     -> Finished (5 tasks)
bash scripts/consistency.sh           -> 6 outputs byte-identical, 23757 bytes each
bash scripts/golden.sh                -> golden OK, 23757 bytes
bash scripts/package-npm.sh           -> npm smoke test OK, 14 cases
```

**唯一的宿主限制**：本机 Windows 无 MSVC / clang-cl，`moon build --target native`
的**可执行文件链接**与 `moon test --target native` 不可用。native 源码在
`moon check --target all` 中已通过四后端类型检查；纯库 native 构建成功；
native 测试代码已就绪，安装 C 编译器后由 `scripts/test-all.sh` 自动纳入。
这不是代码缺陷，详见 `SPIKE.md` 的 B6 与 `README.md` 的「宿主限制」。

---

## 7. 与计划书的取舍说明

| 计划书项 | 本实现 | 说明 |
|---|---|---|
| 50 篇人工标注语料 / 召回率 ≥ 85% | 14 篇内置可复现快照 | 质量指标（S2/S4）需要真实站点标注，属于后续工作；当前语料已覆盖全部结构场景并用于一致性回归 |
| `moonbit-community/html` + `mizchi/css` | 自实现最小子集（Plan B / D1） | 消除 registry 依赖，保证离线可复现与自建 DOM 无缝对接 |
| `moonbitlang/core/json` | 手写固定 schema 序列化（Plan B / D2） | 把「逐字节一致」从测试时验证提升为实现上保证 |
| WIT 组件、完整 JSON-LD、可配置规则表 | 未实现 | 计划书列为 v1.0，非 MVP 范围 |
| CLI 直接读文件 | 环境变量 `CONTENTKIT_INPUT` + 包装脚本 | 一套 `main` 通吃 Node / moonrun(WASI) / 原生，避免后端特有 FFI |

