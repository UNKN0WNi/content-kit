# S0 技术预研结论（Spike 报告）

日期：2026-11-14
依据：计划书附录 B（B0–B8）

---

## B0 / B1 工具链与 hello-world

| 项 | 结论 |
|---|---|
| 安装方式 | 直接下载官方 `moonbit-windows-x86_64.zip` + `core-latest.tar.gz`，解压到工作区 `.tools/moonbit`（绿色免安装，不改动系统目录/注册表） |
| `moon version` | `moon 0.1.20261104 (940aa18 2026-11-04)` |
| Feature flags | `rr_moon_mod, rr_moon_pkg` |
| 额外步骤 | 必须执行 `moon -C "$MOON_HOME/lib/core" bundle --warn-list -a --all` 与 `--target wasm-gc`，否则报 `Cannot inject the standard library moonbitlang/core: Cannot load the core file` |
| hello-world | `moon run cmd/main` → `Hello` ✅ |

Windows 官方安装脚本（`irm ... powershell.ps1 | iex`）在本环境被安全策略拦截，故改用二进制包直装；效果等价，且可随工作区一起归档。

## B4 / D1 选择器对接判定

**结论：采用 Plan B（自实现最小子集）。**

理由不是「复用不可行」，而是「复用会破坏本项目的核心保证」：

- 抽取只需 `tag` / `.class` / `#id` / `[attr]` / `[attr=value]` / 后代组合 / `:not()`，共 7 种，工作量可控；
- 自实现代码 100% 后端无关，且能与自建 DOM 的索引式节点结构无缝对接，不需要适配层；
- 消除对 mooncakes registry 的构建期依赖，四后端产物可以**离线复现**。

实现位置：`parse/html/dom.mbt`、`parse/html/selector.mbt`。已通过 14 个 HTML 层单元测试（含畸形输入、script 伪标签、隐式闭合、6 种子选择器）。

## B5 / D2 JSON 四后端一致性判定

**结论：采用 Plan B（手写固定 schema 序列化器）。**

`moonbitlang/core/json` 是运行时的动态 `Json` 值；字段顺序、浮点格式化、转义策略在不同后端存在实现自由度。计划书的 R2 明确指出这会直接破坏核心卖点。本实现：

- `core/json.mbt`：`json_escape`（控制字符统一 `\u00XX`）、`json_nullable`、`json_string_array`、`json_number`（整数运算，固定 4 位小数）；
- `extract/render_json.mbt`：`Article` 的 14 个顶层字段顺序**硬编码**，`Block` 判别标签固定；
- 不使用任何哈希表遍历顺序、locale 或 `Double::to_string()`。

实测：js / wasm / wasm-gc 三后端 CLI、npm ESM 产物、wasm 包入口、Golden 文件共 **6 份输出，均为 23,757 字节，`cmp` 零差异**（`scripts/consistency.sh`）。

## B6 四后端构建冒烟

| 后端 | `moon check` | `moon test` | `moon build` | 产物体积 |
|---|---|---|---|---|
| js | ✅ | ✅ 67/67 | ✅ ESM | 155–158 KB |
| wasm | ✅ | ✅ 67/67 | ✅ | 167 KB |
| wasm-gc | ✅ | ✅ 67/67 | ✅ | 99 KB |
| native | ✅ | ⚠️ 需 C 编译器 | ✅ 纯库；❌ 可执行文件链接 | — |

`moon check --target all` 一次覆盖四后端全绿。

**native 宿主限制**：本机 Windows 未安装 MSVC Build Tools / clang-cl。MoonBit native 后端在 Windows 使用 "MSVC direct object" 模式，构建计划阶段即要求 `cl.exe` 或 `clang-cl.exe`（报错 `Windows native backend requires MSVC Build Tools with C++ tools and Windows SDK`）。

- 已验证 `moon build --target native core parse/html parse/plain extract testdata`（纯库）成功；
- 已验证 `moon check --target native` 成功；
- `MOON_CC`、`pkgtype` 的 `cc` 覆盖、内置 `tcc.exe` 均无法绕过该检查（工具链强制要求 cl 兼容驱动）；
- 代码与测试无需改动，安装 MSVC/gcc 后 `scripts/test-all.sh`、`scripts/build-all.sh`、`scripts/consistency.sh` 会自动把 native 纳入。

## B7 依赖许可证

本项目**不引入任何第三方 mooncakes 依赖**（只用随工具链分发的 `moonbitlang/core` 内置包：prelude / builtin / env / quickcheck）。`moonbitlang/core` 为 Apache-2.0，与本项目 LICENSE 一致，无许可证冲突风险。

`NOTICE`：算法思想参考 Mozilla Readability（Apache-2.0），本项目为自研规则表，未复制其源码。

## B8 语料库种子

`testdata/corpus.mbt` 内置 14 篇可复现快照：中文新闻、英文博客、API 文档、纯 JSON-LD、HTML 实体、畸形 HTML、无正文门户页、纯文本、论坛、元数据优先级、script 噪声、Unicode 代理对、空输入、极短输入。语料以 MoonBit 字符串常量形式内置，四后端无需文件 IO 即可读取同一份语料 —— 这是跨后端一致性测试能完全脱离宿主 IO 的关键。

50 篇人工标注真实语料属于 S2/S4 后续工作（见 CHANGELOG Known limitations）。

---

## 结论

S0 全部判定项有明确结论；两条最大风险（R1/R2）已用计划书预设的 Plan B 从架构上消除；四后端编译期同源成立；三后端运行时一致性与 67 个测试全绿。唯一未闭合项是**宿主缺少 native 链接器**，属环境依赖，非代码问题。
