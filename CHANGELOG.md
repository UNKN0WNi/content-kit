# Changelog

本文件遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与语义化版本。

## [Unreleased]

### Added

- **可视化测试范例** `docs/test-visual.html`：单文件、零外部依赖、深浅色自适应的交互式测试报告。包含端到端断言逐步执行动画、三输出真实全文切换、六份输出 SHA-256 逐字节比对、67 个用例分布条形图、14 篇语料快照矩阵与复现命令。
- `scripts/gen-test-visual.py`：从 `bundle.txt` / `corpus.mbt` / `*_wbtest.mbt` / `.consistency/*` 读取**真实实测数据**重新生成上述页面，不硬编码期望值。
- `README.md` / `README.en.md` 精简为用法速查，保留可视化测试范例与真实网页示范的入口。
- **Windows PowerShell 入口** `examples/run.ps1`：自动定位 Git for Windows 的 Bash 并转发参数，规避 `bash` 命中 WSL 启动器时报「没有已安装的分发」；中英文文档补 Windows / PowerShell 小节。
- **真实网页快速测试** `examples/`：`run.sh` / `demo.mjs` 接受任意本地 HTML 或 `--fetch URL`，一键完成三后端 CLI 抽取（同 sha256、零差异）、Node ESM 三输出与应用层清洗；`scripts/gen-realworld-demo.py` 从本地产物生成交互式可视化页。抓取页面与产物由 `.gitignore` 排除，**不随公开仓库分发**。
- `docs/real-world-testing.md` / `.en.md`：各环境（CLI 三后端 / Node ESM / 浏览器 / MoonBit 源码内 / WASI / native）用真实网页快速测试的中英双语指南，含页面准备、命令速查、效果评估与排错表。
- **中英文可选 README**：`README.md`（简体中文）与 `README.en.md`（English）章节一一对应、顶部互链；`examples/README.md` / `.en.md` 同步双语。
- `moon.mod`、`js/package.json` 补齐 GitHub 仓库元数据；README 加 CI / License 徽章。

### Changed

- 修复 HTML 原始文本元素误弹父节点、连续不同图片被去重、结构容器内段落参与正文候选、摘要误取标题、数字实体接受非法字符、JSON-LD `\uXXXX` 与代理对解码、纯文本代码围栏丢失前导空行等边界问题；HTML 与门面层共用同一套首段摘要逻辑。
- 精简重复子串查找与 ASCII 小写化实现，改用 `Array::pop` 就地出栈，并将 DOM 文本、链接文本、后代计数和块输出改为显式栈遍历，避免深嵌套输入依赖调用栈。
- 测试增至 76 例；重新生成 Golden Vector 与 `docs/test-visual.html`，六份输出仍逐字节一致。
- 示例脚本通用化：不再绑定任何具体站点，输入统一为 `examples/page.html`（可指定路径），输出统一为 `examples/page.*`；可视化生成器改为读取本地产物、噪声规则改为可调整的调用方示例。
- `STEPS.md` 去掉本机绝对路径；`.gitignore` 增加真实网页产物规则。
- 主 README 移除计划书、实现步骤、验收记录、非目标与决策记录等计划类章节（各 378 行 → 91 行）；快速测试指南不再引用已删除的「宿主限制」章节。

## [0.1.0] - 2026-11-14

对应计划书 §4.1 的 MVP（M1–M8）。

### Added

- **M1** `core/`：领域模型 `Block / Metadata / Article`、集中式规则表 `rules.mbt`（含 `rules_version`）、特征、打分、文本归一化、元数据优先级、确定性 JSON 序列化。零后端依赖。
- **M2** `parse/html/`：轻量 HTML 词法与树构造（注释 / DOCTYPE / 属性 / 实体 / 隐式闭合 / script 原始文本 / 畸形容错），最小选择器子集（tag / .class / #id / [attr] / [attr=value] / 后代 / :not），正文块打分抽取。
- **M3** 元数据抽取：`<title>`、`meta[name/property/http-equiv]`、`<html lang>`、`<time>`、`<img>`、`.byline/.author`、JSON-LD 基础字段（字符串 / 数组 / 带 name 的对象）。
- **M4** 三种输出（text / Markdown / 紧凑 JSON）全部由同一 `Article.blocks` 渲染。
- **M5** `js` / `wasm` / `wasm-gc` 三套可运行产物 + native 纯库产物；`cli/`、`js/`、`wasm/` 三个入口包。
- **M6** 14 篇内置语料 + Golden Vector + `scripts/consistency.sh`（六份输出逐字节比对，实测零差异）。
- **M7** `cxtract` CLI：`--format text|md|json`、`--case`、`--text`、`--env-input`、`--list`、`--rules-version`、`--help`；配套 `scripts/cxtract.sh` 文件/管道包装器。
- **M8** npm 包 `js/`：`package.json`、ESM 产物、`index.d.ts` 完整类型声明、Node 冒烟测试。
- 四层测试共 67 例：L1 单元、L2 集成/快照、L3 跨后端一致性、L4 性质测试（120 个畸形 HTML 变异 + quickcheck）。
- 文档：`STEPS.md`（实现步骤与逐项验收）、`SPIKE.md`（S0 预研结论）、`README.md`、`BENCHMARKS.md`、CI 工作流、Apache-2.0 许可证。

### Design decisions

- D1/D2 采用计划书已写明的 **Plan B**：自实现 HTML 最小子集与手写固定 schema JSON 序列化器，把「四后端逐字节一致」从测试时验证提升为实现上保证。
- `core/` 不设 `supported_targets` 限制，天然全后端可用。

### Known limitations

- Windows 宿主未安装 MSVC / clang-cl 时，native 后端的**可执行文件链接**不可用；`moon check --target native`、纯库 `moon build --target native` 与 native 测试代码均已就绪，安装 C 编译器后自动生效。
- 50 篇人工标注真实语料（S2/S4 的质量指标）属于后续工作；当前 14 篇为可复现的内置快照语料。
- JSON-LD 为基础字段读取，未实现完整 schema.org 类型（v1.0）。
