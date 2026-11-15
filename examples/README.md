# 真实网页示范（本地产物）

🌐 **语言 / Language:** **简体中文** · [English](./README.en.md) · [返回主 README](../README.md)

这个目录放的是**用任意真实网页跑 content-kit 的脚本与本地产物**。仓库只包含脚本；抓取的页面和抽取结果都留在本机、由 `.gitignore` 排除，避免把第三方站点内容分发到公开仓库。

> 完整教程：[docs/real-world-testing.md](../docs/real-world-testing.md)（[English](../docs/real-world-testing.en.md)）—— 各环境（CLI 三后端 / Node ESM / 浏览器 / MoonBit / WASI / native）如何用真实网页快速测试效果。

---

## 三步跑通

```bash
cd content-kit

# ① 准备页面：手动保存为 examples/page.html，或抓取任意 URL
bash examples/run.sh --fetch "https://example.com/some-article"

# ② 一键：三后端抽取 + 逐字节比对 + Node 示范 + 生成本地可视化页面
bash examples/run.sh

# ③ 查看结果
cat examples/page.text
cat examples/page.md
python -m json.tool examples/page.json | head -40
```

也可以指定自己的文件：`bash examples/run.sh my.html`、`node examples/demo.mjs my.html --clean`。

`run.sh` 会依次打印三份 CLI JSON 的字节数与 sha256，**三者必须完全一致**；随后 `demo.mjs` 打印标题、发布时间、站点、块数、score 与三份输出体积，并演示调用方如何在不改内核的前提下过滤噪声块。

---

## 脚本

| 文件 | 作用 |
|---|---|
| `run.sh` | 一键流程；`--fetch URL` 用本机 Chrome/Edge 抓渲染后 DOM，`--help` 看用法 |
| `demo.mjs` | Node / ESM 使用示范；接受 HTML 路径，`--clean` 追加应用层清洗对比 |
| `../scripts/gen-realworld-demo.py` | 从本地 `page.*` 产物生成 `../docs/realworld-demo.html` 可视化页面 |

前置：`node >= 18`、Python 3、MoonBit 工具链（`scripts/moon.sh` 会自动找免安装版本）。

---

## 本地产物命名（均不入库）

| 文件 | 内容 |
|---|---|
| `page.html` / `page.url` | 抓取或手动保存的真实网页、来源 URL |
| `page.text` / `page.md` / `page.json` | Node / ESM 的三份输出 |
| `page.clean.text` / `page.clean.json` | `--clean` 的清洗结果 |
| `page-js.json` / `page-wasm.json` / `page-wasm-gc.json` | 三后端 CLI 输出，用于逐字节比对 |
| `../docs/realworld-demo.html` | 本地生成的可视化页面 |

---

## 为什么要本地生成

- 真实站点页面常含版权正文、广告图、内联 base64，体积可达数百 KB；
- 公开仓库只应分发**方法**，不应分发**别人的内容**；
- 脚本通用化后，任何站点都能在 3 条命令内得到同样的报告，结果取决于被测页面而非仓库里的快照。

验证效果的方法（元数据优先级、正文头尾、块数/score、噪声后处理、跨后端哈希、可视化）见 [快速测试指南 §3](../docs/real-world-testing.md)。
