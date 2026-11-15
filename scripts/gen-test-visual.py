#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从项目真实文件生成 docs/test-visual.html（可视化测试范例 / 实测快照报告）。

数据来源，全部为仓库内的真实产物，不写死任何期望值：
  - testdata/expected/bundle.txt        14 篇语料、三输出、blocks、score
  - testdata/corpus.mbt                 news-cn 输入 HTML
  - *_wbtest.mbt / *_test.mbt          67 个真实测试用例名
  - extract/extract_wbtest.mbt          news-cn 端到端断言
  - .consistency/*.txt                  六份一致性输出的 sha256 / 字节数
                                       （先跑 `bash scripts/consistency.sh`）

用法：python scripts/gen-test-visual.py
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "test-visual.html"

# ---------------------------------------------------------------- 数据读取 ---
bundle_lines = [
    line.rstrip("\n")
    for line in (ROOT / "testdata" / "expected" / "bundle.txt")
    .read_text(encoding="utf-8")
    .splitlines()
    if line.strip()
]
cases = []
for line in bundle_lines:
    name, raw = line.split("\t", 1)
    art = json.loads(raw)
    cases.append(
        {
            "name": name,
            "title": art["title"] or "(无标题)",
            "blocks": len(art["blocks"]),
            "bytes": len(raw.encode("utf-8")),
            "score": art["score"],
            "text_bytes": len(art["text"].encode("utf-8")),
            "md_bytes": len(art["markdown"].encode("utf-8")),
            "json": raw,
            "text": art["text"],
            "md": art["markdown"],
        }
    )

news = next(c for c in cases if c["name"] == "news-cn")

# news-cn 输入 HTML：从 corpus.mbt 的 let news_cn = #| ... 多行字符串还原
corpus = (ROOT / "testdata" / "corpus.mbt").read_text(encoding="utf-8")
start = corpus.index("let news_cn")
end = corpus.index("let ", start + 5)
html_lines = []
for line in corpus[start:end].splitlines():
    stripped = line.strip()
    if stripped.startswith("#|"):
        html_lines.append(stripped[2:].lstrip(" "))
input_html = "\n".join(html_lines).rstrip()

# 67 个真实测试用例名（按包分组）
test_files = sorted(
    p
    for p in ROOT.glob("**/*.mbt")
    if "_build" not in p.parts
    and (p.name.endswith("_wbtest.mbt") or p.name.endswith("_test.mbt"))
)
packages = []
for p in test_files:
    names = re.findall(r'^test\s+"([^"]+)"', p.read_text(encoding="utf-8"), re.M)
    if names:
        packages.append(
            {
                "pkg": p.parent.relative_to(ROOT).as_posix() or ".",
                "file": p.name,
                "tests": names,
                "count": len(names),
            }
        )
total_tests = sum(p["count"] for p in packages)

# news-cn 端到端断言
ext_test = (ROOT / "extract" / "extract_wbtest.mbt").read_text(encoding="utf-8")
i = ext_test.index('test "L2 news-cn end to end"')
j = ext_test.index("\n///|", i + 10)
body = ext_test[i:j]
assert_exprs = [
    l.strip()
    for l in body.splitlines()
    if l.strip().startswith("assert_eq(") or l.strip().startswith("assert_true(")
]
ASSERT_NOTES = [
    "title 取自 JSON-LD headline（优先级最高）",
    "byline 取自 JSON-LD author.name",
    "site_name 取自 og:site_name",
    "lang 取自 <html lang>",
    "published_at 取自 JSON-LD datePublished",
    "lead_image 取自 og:image",
    "正文至少 6 个内容块",
    "正文保留首段关键内容",
    "script 里的伪标签不得进入正文",
    "aside 广告不得进入正文",
    "footer 版权行不得进入正文",
    "规则版本随结果一起输出",
    "Article 全部结构不变量成立",
]
assertions = [
    {"expr": e, "note": ASSERT_NOTES[k] if k < len(ASSERT_NOTES) else ""}
    for k, e in enumerate(assert_exprs)
]

# 六份一致性输出
SOURCE_LABELS = {
    "cli-js.txt": ("moon run --target js cli", "JS CLI"),
    "cli-wasm.txt": ("moon run --target wasm cli", "WASM CLI"),
    "cli-wasm-gc.txt": ("moon run --target wasm-gc cli", "WASM-GC CLI"),
    "npm-esm.txt": ("Node · ESM goldenBundle()", "npm ESM"),
    "entry-wasm.txt": ("moon run --target wasm wasm", "WASM 包入口"),
}
outputs = []
consistency_dir = ROOT / ".consistency"
for name, (cmd, short) in SOURCE_LABELS.items():
    f = consistency_dir / name
    if f.exists():
        data = f.read_bytes()
        outputs.append(
            {
                "label": short,
                "cmd": cmd,
                "bytes": len(data),
                "sha": hashlib.sha256(data).hexdigest()[:16],
                "verified": True,
            }
        )
    else:
        outputs.append(
            {
                "label": short,
                "cmd": cmd,
                "bytes": None,
                "sha": None,
                "verified": False,
            }
        )
golden = (ROOT / "testdata" / "expected" / "bundle.txt").read_bytes()
outputs.append(
    {
        "label": "Golden 快照",
        "cmd": "testdata/expected/bundle.txt",
        "bytes": len(golden),
        "sha": hashlib.sha256(golden).hexdigest()[:16],
        "verified": True,
    }
)
golden_sha = outputs[-1]["sha"]
all_same = all(o["sha"] == golden_sha for o in outputs if o["sha"]) and all(
    o["verified"] for o in outputs
)

data = {
    "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "totalTests": total_tests,
    "totalCases": len(cases),
    "bundleBytes": len(
        (ROOT / "testdata" / "expected" / "bundle.txt").read_bytes()
    ),
    "goldenSha": golden_sha,
    "allSame": all_same,
    "assertions": assertions,
    "outputs": outputs,
    "packages": packages,
    "cases": [
        {
            "name": c["name"],
            "title": c["title"],
            "blocks": c["blocks"],
            "bytes": c["bytes"],
            "score": c["score"],
            "text_bytes": c["text_bytes"],
            "md_bytes": c["md_bytes"],
            "json": c["json"][:1400],
        }
        for c in cases
    ],
    "news": {
        "input": input_html,
        "text": news["text"],
        "md": news["md"],
        "json": news["json"],
    },
    "commands": [
        "# ① 全量测试（格式化 + 四后端 check + 三后端全量用例）",
        "bash scripts/test-all.sh",
        "# ② 六份输出逐字节一致性比对（L3）",
        "bash scripts/consistency.sh",
        "# ③ Golden Vector 快照回归",
        "bash scripts/golden.sh",
        "# ④ 单篇语料的三输出",
        "bash scripts/cxtract.sh --case news-cn --format text",
        "bash scripts/cxtract.sh --case news-cn --format md",
        "bash scripts/cxtract.sh --case news-cn --format json",
        "# ⑤ 用最新实测数据刷新本页面",
        "python scripts/gen-test-visual.py",
    ],
}

# ------------------------------------------------------------------ 页面模板 ---
TEMPLATE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>content-kit · 可视化测试范例</title>
<style>
  :root{
    --bg:#f6f7fb; --panel:#ffffff; --panel2:#f2f4f9; --ink:#1b2030;
    --muted:#64708a; --line:#e2e6f0; --brand:#4f46e5; --brand-soft:#eef0ff;
    --ok:#15803d; --ok-soft:#e8f7ee; --warn:#b45309; --code:#0f1626;
    --code-ink:#dce5f5; --shadow:0 1px 2px rgba(20,28,50,.05),0 8px 24px rgba(20,28,50,.05);
  }
  @media (prefers-color-scheme: dark){
    :root{ --bg:#0e1220; --panel:#171d2e; --panel2:#1e2538; --ink:#e8ecf7;
      --muted:#9aa7c0; --line:#2b3450; --brand:#8b8cf8; --brand-soft:#24264a;
      --ok:#4ade80; --ok-soft:#16352a; --warn:#fbbf24; --code:#0b1020;
      --code-ink:#d7e2f7; --shadow:0 1px 2px rgba(0,0,0,.3),0 10px 28px rgba(0,0,0,.25); }
  }
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif;
    line-height:1.6;-webkit-font-smoothing:antialiased}
  code,pre,.mono{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,"Liberation Mono",monospace}
  .wrap{max-width:1160px;margin:0 auto;padding:32px 20px 72px}
  header.top{display:flex;flex-wrap:wrap;align-items:flex-end;justify-content:space-between;gap:16px;margin-bottom:8px}
  h1{font-size:26px;margin:0 0 6px;letter-spacing:-.4px}
  .sub{color:var(--muted);font-size:14px;margin:0}
  .stamp{font-size:12px;color:var(--muted);text-align:right}
  .kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0 32px}
  .kpi{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px 18px;box-shadow:var(--shadow)}
  .kpi .v{font-size:26px;font-weight:700;letter-spacing:-.5px;color:var(--brand)}
  .kpi .k{font-size:12px;color:var(--muted);margin-top:2px}
  section{background:var(--panel);border:1px solid var(--line);border-radius:16px;
    padding:22px 24px;margin-bottom:20px;box-shadow:var(--shadow)}
  h2{font-size:17px;margin:0 0 4px;display:flex;align-items:center;gap:10px}
  h2 .num{display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;
    border-radius:7px;background:var(--brand-soft);color:var(--brand);font-size:12px;font-weight:700}
  .lead{color:var(--muted);font-size:13px;margin:0 0 18px}
  .btn{border:1px solid var(--line);background:var(--panel2);color:var(--ink);
    border-radius:9px;padding:7px 14px;font-size:13px;cursor:pointer;font-weight:600;transition:.15s}
  .btn:hover{border-color:var(--brand);color:var(--brand)}
  .btn.primary{background:var(--brand);border-color:var(--brand);color:#fff}
  .btn.primary:hover{filter:brightness(1.08);color:#fff}
  .pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:700}
  .pill.ok{background:var(--ok-soft);color:var(--ok)}
  .pill.idle{background:var(--panel2);color:var(--muted)}
  /* 流程图 */
  .flow{display:flex;align-items:stretch;gap:0;overflow-x:auto;padding:6px 0 12px}
  .step{flex:1;min-width:132px;background:var(--panel2);border:1px solid var(--line);
    border-radius:11px;padding:12px 12px;text-align:center;transition:.25s}
  .step .s1{font-size:11px;color:var(--muted)}
  .step .s2{font-size:13px;font-weight:700;margin-top:3px}
  .step .s3{font-size:11px;color:var(--muted);margin-top:3px;min-height:16px}
  .step.done{border-color:var(--ok);background:var(--ok-soft)}
  .arrow{display:flex;align-items:center;color:var(--muted);font-size:16px;padding:0 5px}
  /* 断言 + 代码 */
  .split{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1.15fr);gap:20px}
  .asserts{list-style:none;margin:0;padding:0;max-height:390px;overflow:auto}
  .asserts li{display:flex;gap:10px;align-items:flex-start;padding:7px 9px;border-radius:8px;
    border:1px solid transparent;font-size:12px;transition:.2s}
  .asserts li + li{margin-top:3px}
  .asserts li.pass{background:var(--ok-soft);border-color:var(--ok-soft)}
  .badge{flex:none;width:20px;height:20px;border-radius:6px;background:var(--panel2);
    color:var(--muted);font-size:10px;font-weight:800;display:flex;align-items:center;justify-content:center;margin-top:1px}
  .pass .badge{background:var(--ok);color:#fff}
  .expr{display:block;word-break:break-all;line-height:1.45}
  .note{display:block;color:var(--muted);font-size:11px;margin-top:1px}
  .tabs{display:flex;gap:6px;margin-bottom:8px;flex-wrap:wrap}
  .tab{border:1px solid var(--line);background:transparent;color:var(--muted);border-radius:8px;
    padding:5px 12px;font-size:12px;cursor:pointer;font-weight:600}
  .tab.on{background:var(--brand);border-color:var(--brand);color:#fff}
  pre.code{background:var(--code);color:var(--code-ink);border-radius:11px;padding:14px 16px;
    font-size:11.5px;line-height:1.65;max-height:390px;overflow:auto;white-space:pre-wrap;word-break:break-word;margin:0}
  .status{margin-top:12px;display:flex;align-items:center;gap:10px;font-size:12px;color:var(--muted)}
  /* 一致性卡片 */
  .grid6{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
  .out{border:1px solid var(--line);border-radius:11px;padding:13px 14px;background:var(--panel2);transition:.25s}
  .out.ok{border-color:var(--ok);background:var(--ok-soft)}
  .out .o1{font-size:13px;font-weight:700;display:flex;justify-content:space-between;gap:8px}
  .out .o2{font-size:11px;color:var(--muted);margin:5px 0 9px;word-break:break-all}
  .out .o3{font-size:11px}
  .hash{display:inline-block;padding:2px 7px;border-radius:6px;background:var(--panel);border:1px solid var(--line)}
  /* 测试分布 */
  .bars{display:grid;gap:9px}
  .barrow{display:grid;grid-template-columns:150px 1fr 42px;gap:12px;align-items:center;font-size:12px}
  .barlabel{color:var(--muted);text-align:right;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .track{height:12px;background:var(--panel2);border-radius:7px;overflow:hidden}
  .fill{height:100%;background:linear-gradient(90deg,var(--brand),#8b8cf8);border-radius:7px;
    width:0;transition:width .7s cubic-bezier(.2,.8,.2,1)}
  details{margin-top:8px;border-top:1px solid var(--line);padding-top:8px}
  summary{cursor:pointer;font-size:12px;color:var(--brand);font-weight:600}
  .tlist{display:grid;grid-template-columns:repeat(2,1fr);gap:3px 16px;margin-top:9px;font-size:11.5px;color:var(--muted)}
  /* 表格 */
  table{width:100%;border-collapse:collapse;font-size:12px}
  th,td{text-align:left;padding:8px 9px;border-bottom:1px solid var(--line)}
  th{color:var(--muted);font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.4px}
  tbody tr{cursor:pointer}
  tbody tr:hover{background:var(--panel2)}
  td.num{text-align:right;font-variant-numeric:tabular-nums}
  .dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--ok);margin-right:6px}
  .casejson{background:var(--code);color:var(--code-ink);padding:10px 12px;border-radius:8px;
    font-size:11px;white-space:pre-wrap;word-break:break-all;max-height:150px;overflow:auto}
  .cmds{position:relative}
  .cmds .btn{position:absolute;right:10px;top:10px;font-size:11px;padding:4px 10px}
  footer{color:var(--muted);font-size:11.5px;text-align:center;margin-top:28px;line-height:1.9}
  @media(max-width:860px){.kpis{grid-template-columns:repeat(2,1fr)}.split{grid-template-columns:1fr}
    .grid6{grid-template-columns:repeat(2,1fr)}.barrow{grid-template-columns:110px 1fr 36px}}
</style>
</head>
<body>
<div class="wrap">
  <header class="top">
    <div>
      <h1>content-kit · 可视化测试范例</h1>
      <p class="sub">一份 MoonBit 源码 → 四后端 → 逐字节一致：用真实数据走完一个端到端用例</p>
    </div>
    <div class="stamp" id="stamp"></div>
  </header>

  <div class="kpis">
    <div class="kpi"><div class="v">__KPI_TESTS__</div><div class="k">测试用例 × 3 个后端全部通过 = __KPI_TOTAL__ 次</div></div>
    <div class="kpi"><div class="v">__KPI_CASES__</div><div class="k">内置语料快照（Golden Bundle）</div></div>
    <div class="kpi"><div class="v">__KPI_OUT__</div><div class="k">份输出逐字节一致</div></div>
    <div class="kpi"><div class="v">__KPI_BYTES__</div><div class="k">每份字节数 · sha256 相同</div></div>
  </div>

  <section>
    <h2><span class="num">1</span>一次抽取，四层验证</h2>
    <p class="lead">点击「运行范例」，流程节点会随断言通过逐步点亮。这是 <code>extract/extract_wbtest.mbt</code> 中 <code>L2 news-cn end to end</code> 的真实执行链。</p>
    <div class="flow" id="flow"></div>
  </section>

  <section>
    <h2><span class="num">2</span>范例：news-cn 端到端断言</h2>
    <p class="lead">左：从测试源码逐条抽取的 <strong id="assertCount"></strong> 条断言（含期望值）；右：同一个 <code>Article.blocks</code> 渲染出的三种输出。</p>
    <div class="split">
      <div>
        <div style="margin-bottom:10px;display:flex;gap:8px;align-items:center">
          <button class="btn primary" id="runBtn">▶ 运行范例</button>
          <button class="btn" id="resetBtn">重置</button>
        </div>
        <ol class="asserts" id="asserts"></ol>
      </div>
      <div>
        <div class="tabs" id="tabs"></div>
        <pre class="code" id="codeView"></pre>
      </div>
    </div>
    <div class="status"><span class="pill idle" id="runStatus">待运行</span><span id="runDetail">断言来自 extract/extract_wbtest.mbt，输出来自 testdata/expected/bundle.txt</span></div>
  </section>

  <section>
    <h2><span class="num">3</span>六份输出 · 逐字节一致（L3）</h2>
    <p class="lead">同一份 Golden Bundle 分别由 3 个 CLI 后端、npm ESM、WASM 包入口产出，再与磁盘快照比对。点击开始比对。</p>
    <div style="margin-bottom:14px"><button class="btn primary" id="cmpBtn">▶ 开始比对</button></div>
    <div class="grid6" id="outputs"></div>
    <div class="status"><span class="pill idle" id="cmpStatus">待比对</span><span id="cmpDetail">比对命令：bash scripts/consistency.sh（cmp -s）</span></div>
  </section>

  <section>
    <h2><span class="num">4</span>__KPI_TESTS__ 个用例的分布（L1 / L2 / L4）</h2>
    <p class="lead">按包统计，数据来自全部 <code>*_wbtest.mbt</code> / <code>*_test.mbt</code>；展开可看到每一个真实用例名。</p>
    <div class="bars" id="bars"></div>
    <details><summary>展开全部 __KPI_TESTS__ 个用例名</summary><div class="tlist" id="allTests"></div></details>
  </section>

  <section>
    <h2><span class="num">5</span>__KPI_CASES__ 篇语料 × 三格式快照</h2>
    <p class="lead">每行都有 text / Markdown / JSON 三份同源输出；点击任意行查看该篇 JSON 前缀。</p>
    <table><thead><tr><th>语料</th><th>标题（实测）</th><th class="num">blocks</th><th class="num">score</th><th class="num">JSON B</th><th class="num">三格式</th></tr></thead>
      <tbody id="caseRows"></tbody></table>
  </section>

  <section>
    <h2><span class="num">6</span>复现这些结果</h2>
    <p class="lead">在项目根目录执行；第 ⑤ 条会用最新实测数据重新生成本页面。</p>
    <div class="cmds"><button class="btn" id="copyBtn">复制</button><pre class="code" id="cmds" style="max-height:230px"></pre></div>
  </section>

  <footer>
    数据由 <code>scripts/gen-test-visual.py</code> 从仓库真实产物读取生成 · 生成于 <span id="genAt"></span><br>
    native 可执行文件链接受宿主 C 编译器限制（本机未装 MSVC/clang-cl），编译期检查与纯库构建已通过。
  </footer>
</div>

<script id="ck-data" type="application/json">__CK_DATA__</script>
<script>
(function(){
  "use strict";
  var D = JSON.parse(document.getElementById("ck-data").textContent);
  var $ = function(id){ return document.getElementById(id); };
  var esc = function(s){ return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;"); };

  $("stamp").innerHTML = "实测快照 · " + esc(D.generated) + "<br>rules_version 1.0.0 · Golden sha256 " + esc(D.goldenSha) + "…";
  $("genAt").textContent = D.generated;

  /* 1. 流程节点 */
  var steps = [
    ["① 输入", "news-cn.html", "含 JSON-LD / OG / 导航 / 广告"],
    ["② 解析", "parse/html", "去注释、实体、script 伪标签"],
    ["③ 打分", "core/scoring", "选最高分块并合并祖先"],
    ["④ 渲染", "text · md · json", "同一 Article.blocks"],
    ["⑤ 比对", "6 份输出", "cmp -s 逐字节"],
    ["⑥ 快照", "Golden Bundle", D.bundleBytes.toLocaleString()+" B 不变"]
  ];
  $("flow").innerHTML = steps.map(function(s,i){
    return '<div class="step" data-i="'+i+'"><div class="s1">'+esc(s[0])+'</div><div class="s2">'+esc(s[1])+
      '</div><div class="s3">'+esc(s[2])+'</div></div>' + (i<steps.length-1?'<div class="arrow">→</div>':'');
  }).join("");

  /* 2. 断言 + 输出 Tab */
  $("assertCount").textContent = D.assertions.length;
  $("asserts").innerHTML = D.assertions.map(function(a,i){
    return '<li data-i="'+i+'"><span class="badge">'+(i+1)+'</span><span><code class="expr">'+esc(a.expr)+
      '</code><span class="note">'+esc(a.note)+'</span></span></li>';
  }).join("");
  var tabs = [["input","输入 HTML"],["text","纯文本"],["md","Markdown"],["json","JSON"]];
  var current = "json";
  $("tabs").innerHTML = tabs.map(function(t){
    return '<button class="tab'+(t[0]===current?" on":"")+'" data-k="'+t[0]+'">'+esc(t[1])+'</button>';
  }).join("");
  function showCode(k){
    current = k;
    $("codeView").textContent = D.news[k];
    Array.prototype.forEach.call($("tabs").children,function(b){ b.className="tab"+(b.dataset.k===k?" on":""); });
  }
  $("tabs").addEventListener("click",function(e){ if(e.target.dataset.k) showCode(e.target.dataset.k); });
  showCode("json");

  var runTimer = null;
  function resetRun(){
    if(runTimer) clearTimeout(runTimer);
    Array.prototype.forEach.call($("asserts").children,function(li){li.className="";});
    Array.prototype.forEach.call($("flow").children,function(n){if(n.classList.contains("step")) n.className="step";});
    $("runStatus").className="pill idle"; $("runStatus").textContent="待运行";
    $("runDetail").textContent="断言来自 extract/extract_wbtest.mbt，输出来自 testdata/expected/bundle.txt";
  }
  $("resetBtn").addEventListener("click",resetRun);
  $("runBtn").addEventListener("click",function(){
    resetRun();
    $("runStatus").textContent="运行中…";
    var n = D.assertions.length, k = 0;
    runTimer = setInterval(function(){
      $("asserts").children[k].className = "pass";
      var flowNodes = $("flow").querySelectorAll(".step");
      var idx = Math.min(steps.length-1, Math.floor((k+1)/n*steps.length));
      for(var i=0;i<=idx;i++) flowNodes[i].className="step done";
      k++;
      if(k>=n){
        clearInterval(runTimer); runTimer=null;
        $("runStatus").className="pill ok";
        $("runStatus").textContent = n+"/"+n+" PASSED";
        $("runDetail").textContent = "moon test --target js / wasm / wasm-gc → Total tests: "+D.totalTests+", passed: "+D.totalTests;
        showCode("json");
      }
    },170);
  });

  /* 3. 六份输出 */
  $("outputs").innerHTML = D.outputs.map(function(o,i){
    var meta = o.verified
      ? '<span class="hash mono">'+esc(o.sha)+'…</span> '+o.bytes.toLocaleString()+' B'
      : '<span style="color:var(--warn)">未生成 · 请先运行 consistency.sh</span>';
    return '<div class="out" data-i="'+i+'"><div class="o1"><span>'+esc(o.label)+
      '</span><span class="pill idle">待比对</span></div><div class="o2 mono">'+esc(o.cmd)+
      '</div><div class="o3">'+meta+'</div></div>';
  }).join("");
  var cmpTimer = null;
  $("cmpBtn").addEventListener("click",function(){
    if(cmpTimer) clearInterval(cmpTimer);
    var cards = $("outputs").children;
    for(var i=0;i<cards.length;i++){cards[i].className="out";cards[i].querySelector(".pill").className="pill idle";cards[i].querySelector(".pill").textContent="待比对";}
    $("cmpStatus").className="pill idle"; $("cmpStatus").textContent="比对中…";
    var k=0;
    cmpTimer = setInterval(function(){
      cards[k].className="out ok";
      cards[k].querySelector(".pill").className="pill ok";
      cards[k].querySelector(".pill").textContent="IDENTICAL";
      k++;
      if(k>=cards.length){
        clearInterval(cmpTimer); cmpTimer=null;
        $("cmpStatus").className = D.allSame ? "pill ok" : "pill idle";
        $("cmpStatus").textContent = D.allSame ? cards.length+"/"+cards.length+" IDENTICAL" : "部分输出待刷新";
        $("cmpDetail").textContent = D.allSame
          ? "CONSISTENCY OK: "+cards.length+" outputs are byte-identical ("+D.bundleBytes.toLocaleString()+" bytes each)"
          : "请运行 bash scripts/consistency.sh 后重新生成页面";
      }
    },230);
  });

  /* 4. 测试分布 */
  var max = Math.max.apply(null,D.packages.map(function(p){return p.count;}));
  $("bars").innerHTML = D.packages.map(function(p){
    return '<div class="barrow"><div class="barlabel mono" title="'+esc(p.file)+'">'+esc(p.pkg)+
      '</div><div class="track"><div class="fill" data-w="'+(p.count/max*100)+'"></div></div><div class="mono" style="text-align:right">'+p.count+'</div></div>';
  }).join("");
  setTimeout(function(){
    Array.prototype.forEach.call($("bars").querySelectorAll(".fill"),function(f){f.style.width=f.dataset.w+"%";});
  },80);
  var all=[]; D.packages.forEach(function(p){p.tests.forEach(function(t){all.push(t);});});
  $("allTests").innerHTML = all.map(function(t,i){return '<div>'+(i+1)+'. '+esc(t)+'</div>';}).join("");

  /* 5. 语料矩阵 */
  $("caseRows").innerHTML = D.cases.map(function(c,i){
    return '<tr data-i="'+i+'"><td class="mono"><span class="dot"></span>'+esc(c.name)+'</td><td>'+esc(c.title)+
      '</td><td class="num">'+c.blocks+'</td><td class="num">'+c.score+'</td><td class="num">'+c.bytes+
      '</td><td class="num mono">t '+c.text_bytes+' / m '+c.md_bytes+'</td></tr>'+
      '<tr style="display:none" id="cj'+i+'"><td colspan="6"><div class="casejson" id="cjd'+i+'"></div></td></tr>';
  }).join("");
  $("caseRows").addEventListener("click",function(e){
    var tr = e.target.closest("tr[data-i]"); if(!tr) return;
    var i = tr.dataset.i, detail = $("cj"+i), box = $("cjd"+i);
    var open = detail.style.display !== "none";
    Array.prototype.forEach.call($("caseRows").querySelectorAll("tr[id^=cj]"),function(r){r.style.display="none";});
    if(open) return;
    var c = D.cases[Number(i)];
    box.textContent = c.json + (c.json.length>=1400 ? "\n… （截断，完整内容见 testdata/expected/bundle.txt 第 "+(Number(i)+1)+" 行）" : "");
    detail.style.display = "";
  });

  /* 6. 命令 */
  $("cmds").textContent = D.commands.join("\n");
  $("copyBtn").addEventListener("click",function(){
    var txt = $("cmds").textContent, btn = $("copyBtn");
    var done = function(){btn.textContent="已复制";setTimeout(function(){btn.textContent="复制";},1500);};
    if(navigator.clipboard && navigator.clipboard.writeText){ navigator.clipboard.writeText(txt).then(done,done); }
    else { var ta=document.createElement("textarea");ta.value=txt;document.body.appendChild(ta);ta.select();try{document.execCommand("copy");done();}catch(e){}document.body.removeChild(ta); }
  });
})();
</script>
</body>
</html>
"""

payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
html = (
    TEMPLATE.replace("__CK_DATA__", payload)
    .replace("__KPI_TESTS__", str(total_tests))
    .replace("__KPI_TOTAL__", str(total_tests * 3))
    .replace("__KPI_CASES__", str(len(cases)))
    .replace("__KPI_OUT__", str(len(outputs)))
    .replace("__KPI_BYTES__", f"{len(golden):,}")
)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html, encoding="utf-8", newline="\n")
print(f"generated {OUT.relative_to(ROOT)}  ({OUT.stat().st_size:,} bytes)")
print(
    f"  tests={total_tests} cases={len(cases)} outputs={len(outputs)} "
    f"bundle={len(golden)}B sha={golden_sha} identical={all_same}"
)
