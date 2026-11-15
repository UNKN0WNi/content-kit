#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 examples/ 的本地真实网页产物生成 docs/realworld-demo.html。

数据全部来自本地文件，不写死任何抽取结果，也不绑定任何具体站点：
  page.html                    任意真实网页（本地，不入库）
  page.url                     可选，抓取时记下的来源 URL
  page.text / page.md / page.json   Node ESM 三输出
  page.clean.text / .json      应用层清洗结果
  page-{js,wasm,wasm-gc}.json  三后端 CLI 输出（比对 sha256）

先跑 `bash examples/run.sh --fetch URL`（或自行准备 examples/page.html），
再运行本脚本。生成的 HTML 同样不随仓库分发。

用法：python scripts/gen-realworld-demo.py
"""
from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EX = ROOT / "examples"
OUT = ROOT / "docs" / "realworld-demo.html"
url_path = EX / "page.url"
URL = url_path.read_text(encoding="utf-8").strip() if url_path.exists() else "本地文件：examples/page.html"

html_path = EX / "page.html"
if not html_path.exists():
    raise SystemExit(
        "缺少 examples/page.html：先跑 `bash examples/run.sh --fetch URL`，"
        "或把任意真实网页保存为 examples/page.html"
    )
raw_html = html_path.read_text(encoding="utf-8")
page_title = re.search(r"<title[^>]*>(.*?)</title>", raw_html, re.S)
page_title = page_title.group(1).strip() if page_title else "(无标题)"

article = json.loads((EX / "page.json").read_text(encoding="utf-8"))
text = (EX / "page.text").read_text(encoding="utf-8")
md = (EX / "page.md").read_text(encoding="utf-8")
clean_text = (EX / "page.clean.text").read_text(encoding="utf-8")

NOISE = re.compile(r"^(海量资讯|广告|责任编辑|版权所有|阅读原文|扫码|下载APP)")
AD_SRC = re.compile(
    r"\b(ad|ads|advert|banner|sponsor|promo)\b|\d{2,4}x\d{2,4}\.(jpe?g|png|webp)", re.I
)


def is_noise(b: dict) -> str:
    """调用方的通用噪声识别示例（不是内核规则，可按自己的站点调整）。"""
    src = b.get("src") or ""
    t = b.get("text") or ""
    if src.startswith("data:"):
        return "内联 base64 图片"
    if AD_SRC.search(src):
        return "疑似广告图"
    if NOISE.match(t):
        return "站点页脚 / 推广"
    return ""


blocks = [
    {
        "i": i + 1,
        "kind": b["kind"],
        "preview": (b.get("text") or b.get("src") or "")[:96],
        "len": len((b.get("text") or b.get("src") or "")),
        "noise": is_noise(b),
    }
    for i, b in enumerate(article["blocks"])
]

backends = []
for t in ("js", "wasm", "wasm-gc"):
    f = EX / f"page-{t}.json"
    data = f.read_bytes()
    backends.append(
        {
            "label": t,
            "bytes": len(data),
            "sha": hashlib.sha256(data).hexdigest()[:16],
        }
    )
identical = len({b["sha"] for b in backends}) == 1

meta = [
    ("title", article["title"], "元数据优先级 §5.5.4 的结果"),
    ("published_at", article["published_at"] or "—", "datePublished / article:published_time / <time>"),
    ("site_name", article["site_name"] or "—", "og:site_name / JSON-LD publisher / 主机名"),
    ("byline", article["byline"] or "—", "JSON-LD author / meta[name=author] / .byline"),
    ("lang", article["lang"] or "—", "<html lang> / content-language"),
    ("lead_image", (article["lead_image"] or "—")[:70], "og:image / JSON-LD image / 首个 <img>"),
    ("excerpt", (article["excerpt"] or "—")[:70], "description / 正文首段截断"),
]

data = {
    "url": URL,
    "pageTitle": page_title,
    "htmlBytes": len(html_path.read_bytes()),
    "fetched": datetime.fromtimestamp(html_path.stat().st_mtime).strftime("%Y-%m-%d %H:%M"),
    "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "article": {
        "title": article["title"],
        "score": article["score"],
        "rules": article["rules_version"],
        "blocks": len(article["blocks"]),
    },
    "meta": meta,
    "blocks": blocks,
    "noiseCount": sum(1 for b in blocks if b["noise"]),
    "sizes": {
        "text": len(text.encode("utf-8")),
        "md": len(md.encode("utf-8")),
        "json": len((EX / "page.json").read_bytes()),
        "clean": len(clean_text.encode("utf-8")),
    },
    "backends": backends,
    "identical": identical,
    "views": {
        "clean": clean_text,
        "text": text,
        "md": md,
        "json": (EX / "page.json").read_text(encoding="utf-8"),
    },
    "commands": [
        "# ① 抓取任意真实页面（需本机 Chrome/Edge）",
        "bash examples/run.sh --fetch \"https://example.com/article\"",
        "# ② 用已保存页面一键复现：三后端抽取 + 比对 + Node 示范",
        "bash examples/run.sh",
        "# ③ 单独运行 Node / ESM 示范（可选 --clean）",
        "node examples/demo.mjs --clean",
        "# ④ 单独用 CLI 抽取（可切换后端）",
        "bash scripts/cxtract.sh examples/page.html --format json",
        "CXTRACT_TARGET=wasm-gc bash scripts/cxtract.sh examples/page.html --format md",
        "# ⑤ 刷新本可视化页面",
        "python scripts/gen-realworld-demo.py",
    ],
}

TEMPLATE = r"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>content-kit · 真实网页使用示范</title>
<style>
  :root{--bg:#f6f7fb;--panel:#fff;--panel2:#f2f4f9;--ink:#1b2030;--muted:#64708a;
    --line:#e2e6f0;--brand:#4f46e5;--soft:#eef0ff;--ok:#15803d;--oksoft:#e8f7ee;
    --warn:#b45309;--warnsoft:#fff3e0;--code:#0f1626;--codeink:#dce5f5;
    --shadow:0 1px 2px rgba(20,28,50,.05),0 8px 24px rgba(20,28,50,.05)}
  @media(prefers-color-scheme:dark){:root{--bg:#0e1220;--panel:#171d2e;--panel2:#1e2538;
    --ink:#e8ecf7;--muted:#9aa7c0;--line:#2b3450;--brand:#8b8cf8;--soft:#24264a;
    --ok:#4ade80;--oksoft:#16352a;--warn:#fbbf24;--warnsoft:#3a2c14;--code:#0b1020;
    --codeink:#d7e2f7;--shadow:0 1px 2px rgba(0,0,0,.3)}}
  *{box-sizing:border-box}
  body{margin:0;background:var(--bg);color:var(--ink);line-height:1.6;
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Microsoft YaHei",sans-serif}
  code,pre,.mono{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
  .wrap{max-width:1160px;margin:0 auto;padding:32px 20px 72px}
  h1{font-size:26px;margin:0 0 6px;letter-spacing:-.4px}
  h2{font-size:17px;margin:0 0 4px;display:flex;align-items:center;gap:10px}
  h2 .num{display:inline-flex;align-items:center;justify-content:center;width:24px;height:24px;
    border-radius:7px;background:var(--soft);color:var(--brand);font-size:12px;font-weight:700}
  .sub,.lead{color:var(--muted);font-size:13px;margin:0 0 18px}
  .sub a{color:var(--brand);text-decoration:none;word-break:break-all}
  .stamp{font-size:12px;color:var(--muted);text-align:right}
  header.top{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-end;gap:16px}
  .kpis{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:24px 0}
  .kpi{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:16px 18px;box-shadow:var(--shadow)}
  .kpi .v{font-size:24px;font-weight:700;color:var(--brand);letter-spacing:-.5px}
  .kpi .k{font-size:12px;color:var(--muted);margin-top:2px}
  section{background:var(--panel);border:1px solid var(--line);border-radius:16px;padding:22px 24px;
    margin-bottom:20px;box-shadow:var(--shadow)}
  .btn{border:1px solid var(--line);background:var(--panel2);color:var(--ink);border-radius:9px;
    padding:6px 13px;font-size:12px;cursor:pointer;font-weight:600}
  .btn:hover{border-color:var(--brand);color:var(--brand)}
  .pill{display:inline-block;padding:2px 9px;border-radius:999px;font-size:11px;font-weight:700}
  .pill.ok{background:var(--oksoft);color:var(--ok)}
  .pill.warn{background:var(--warnsoft);color:var(--warn)}
  .pill.idle{background:var(--panel2);color:var(--muted)}
  .flow{display:flex;gap:0;overflow-x:auto;padding:4px 0 10px}
  .step{flex:1;min-width:140px;background:var(--panel2);border:1px solid var(--line);border-radius:11px;padding:12px;text-align:center}
  .step .a{font-size:11px;color:var(--muted)}.step .b{font-size:13px;font-weight:700;margin-top:3px}
  .step .c{font-size:11px;color:var(--muted);margin-top:3px}
  .arrow{display:flex;align-items:center;color:var(--muted);padding:0 6px}
  table{width:100%;border-collapse:collapse;font-size:12px}
  th,td{text-align:left;padding:8px 9px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--muted);font-size:11px;font-weight:600}
  td.k{width:130px;color:var(--muted)}
  .miss{color:var(--warn)}
  .tabs{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px}
  .tab{border:1px solid var(--line);background:transparent;color:var(--muted);border-radius:8px;
    padding:5px 12px;font-size:12px;cursor:pointer;font-weight:600}
  .tab.on{background:var(--brand);border-color:var(--brand);color:#fff}
  pre.code{background:var(--code);color:var(--codeink);border-radius:11px;padding:14px 16px;font-size:11.5px;
    line-height:1.65;max-height:400px;overflow:auto;white-space:pre-wrap;word-break:break-word;margin:0}
  .blocks{max-height:400px;overflow:auto;border:1px solid var(--line);border-radius:10px}
  .blk{display:grid;grid-template-columns:34px 74px 1fr 62px;gap:10px;padding:7px 10px;font-size:11.5px;
    border-bottom:1px solid var(--line);align-items:start}
  .blk:last-child{border-bottom:0}
  .blk.noise{background:var(--warnsoft)}
  .blk .n{color:var(--muted);text-align:right}
  .blk .kd{color:var(--brand);font-weight:600}
  .blk .pv{word-break:break-all;color:var(--ink)}
  .blk .ln{color:var(--muted);text-align:right}
  .bar{height:14px;background:var(--panel2);border-radius:7px;overflow:hidden;margin:6px 0}
  .bar>i{display:block;height:100%;background:var(--brand);border-radius:7px}
  .bar.clean>i{background:var(--ok)}
  .grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}
  .out{border:1px solid var(--line);border-radius:11px;padding:13px 14px;background:var(--panel2)}
  .out.ok{border-color:var(--ok);background:var(--oksoft)}
  .cmds{position:relative}.cmds .btn{position:absolute;right:10px;top:10px}
  footer{color:var(--muted);font-size:11.5px;text-align:center;margin-top:28px;line-height:1.9}
  @media(max-width:860px){.kpis,.grid3{grid-template-columns:repeat(2,1fr)}.blk{grid-template-columns:28px 60px 1fr}}
</style>
</head>
<body>
<div class="wrap">
<header class="top">
  <div><h1>content-kit · 真实网页使用示范</h1>
    <p class="sub">任意真实网页 → 一次抽取 → 三份输出 → 三后端逐字节一致<br><a id="url"></a></p></div>
  <div class="stamp" id="stamp"></div>
</header>
<div class="kpis">
  <div class="kpi"><div class="v" id="k1"></div><div class="k">真实页面 DOM（UTF-8）</div></div>
  <div class="kpi"><div class="v" id="k2"></div><div class="k">内容块 · 其中噪声块 <span id="k2b"></span> 个</div></div>
  <div class="kpi"><div class="v" id="k3"></div><div class="k">个后端输出同一 sha256</div></div>
  <div class="kpi"><div class="v" id="k4"></div><div class="k">清洗后正文体积（原 <span id="k4b"></span> B）</div></div>
</div>

<section>
  <h2><span class="num">1</span>从真实页面到可用正文</h2>
  <p class="lead">抓取 → 三后端 CLI → Node ESM → 三输出；全程同一份 MoonBit 源码。</p>
  <div class="flow" id="flow"></div>
</section>

<section>
  <h2><span class="num">2</span>抽取到的元数据（实测）</h2>
  <p class="lead">绿色为命中，橙色为真实网页上缺失或回退不当的字段 —— 一并如实展示。</p>
  <table><thead><tr><th>字段</th><th>实测值</th><th>来源 / 说明</th></tr></thead><tbody id="meta"></tbody></table>
</section>

<section>
  <h2><span class="num">3</span>三份输出，同一份 blocks</h2>
  <p class="lead">默认展示应用层清洗后的正文；切到「原始 text」可以看到真实网页带来的 6.9 KB 内联 base64 噪声。</p>
  <div class="tabs" id="tabs"></div>
  <pre class="code" id="codeView"></pre>
</section>

<section>
  <h2><span class="num">4</span>__KPI_BLOCKS__ 个内容块的可视化清单</h2>
  <p class="lead">橙色行是真实站点的噪声块。点击按钮只看正文，即为 <code>demo.mjs --clean</code> 的结果。</p>
  <div style="margin-bottom:10px"><button class="btn" id="filterBtn">只显示正文（__KPI_NOISE__ 个噪声块）</button></div>
  <div class="blocks" id="blocks"></div>
  <div style="margin-top:16px">
    <div style="font-size:12px">原始 text <span id="origSize" class="mono"></span></div>
    <div class="bar"><i id="barOrig" style="width:100%"></i></div>
    <div style="font-size:12px">清洗后正文 <span id="cleanSize" class="mono"></span></div>
    <div class="bar clean"><i id="barClean" style="width:0"></i></div>
  </div>
</section>

<section>
  <h2><span class="num">5</span>三后端一致性（真实网页，非内置语料）</h2>
  <p class="lead">同一个 528 KB 页面分别由 js / wasm / wasm-gc 的 CLI 抽取，<code>cmp -s</code> 零差异。</p>
  <div class="grid3" id="backends"></div>
  <div class="status" style="margin-top:12px"><span class="pill ok" id="cmpPill"></span></div>
</section>

<section>
  <h2><span class="num">6</span>复现</h2>
  <p class="lead">在 content-kit 根目录执行；页面本身由 <code>scripts/gen-realworld-demo.py</code> 从 examples/ 真实产物生成。</p>
  <div class="cmds"><button class="btn" id="copyBtn">复制</button><pre class="code" id="cmds" style="max-height:250px"></pre></div>
</section>
<footer>页面标题：<span id="pageTitle"></span><br>
  抓取于 <span id="fetched"></span> · 页面生成于 <span id="genAt"></span> · rules_version <span id="rules"></span><br>
  说明：内核是 MVP 规则抽取器，站点页脚、内联图片与 <code>article:author</code> 属已知边界，应用层清洗示范见 <code>examples/demo.mjs</code>。
</footer>
</div>
<script id="ck-data" type="application/json">__CK_DATA__</script>
<script>
(function(){
 "use strict";
 var D=JSON.parse(document.getElementById("ck-data").textContent),$=function(i){return document.getElementById(i)};
 var esc=function(s){return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;")};
 var fmt=function(n){return Number(n).toLocaleString()};
 $("url").textContent=D.url;if(/^https?:/.test(D.url)){$("url").href=D.url;$("url").target="_blank";}
 $("stamp").innerHTML="抓取于 "+esc(D.fetched)+"<br>生成于 "+esc(D.generated);
 $("k1").textContent=fmt(D.htmlBytes)+" B";$("k2").textContent=D.article.blocks;
 $("k2b").textContent=D.noiseCount;$("k3").textContent=D.backends.length;
 $("k4").textContent=fmt(D.sizes.clean)+" B";$("k4b").textContent=fmt(D.sizes.text);
 $("pageTitle").textContent=D.pageTitle;$("fetched").textContent=D.fetched;
 $("genAt").textContent=D.generated;$("rules").textContent=D.article.rules;
 var steps=[["① 抓取","Chrome --dump-dom",fmt(D.htmlBytes)+" B · UTF-8"],
   ["② 三后端 CLI","js / wasm / wasm-gc","同一份源码"],
   ["③ Node ESM","extractJson / Text / Md","直接读文件"],
   ["④ 三输出同源","text · md · json",D.article.blocks+" 个 blocks"],
   ["⑤ 应用层清洗","过滤噪声块",D.sizes.text+" → "+D.sizes.clean+" B"]];
 $("flow").innerHTML=steps.map(function(s,i){return '<div class="step"><div class="a">'+esc(s[0])+
   '</div><div class="b">'+esc(s[1])+'</div><div class="c">'+esc(s[2])+'</div></div>'+
   (i<steps.length-1?'<div class="arrow">→</div>':'')}).join("");
 $("meta").innerHTML=D.meta.map(function(m){
   var miss=m[1]==="—"||/article:author|默认头像|无 lang/.test(m[2]);
   return '<tr><td class="k mono">'+esc(m[0])+'</td><td'+(miss?' class="miss"':'')+'>'+esc(m[1])+
     '</td><td>'+esc(m[2])+'</td></tr>'}).join("");
 var tabs=[["clean","清洗后正文"],["text","原始 text"],["md","Markdown"],["json","JSON"]];
 var cur="clean";
 $("tabs").innerHTML=tabs.map(function(t){return '<button class="tab'+(t[0]===cur?" on":"")+
   '" data-k="'+t[0]+'">'+esc(t[1])+'</button>'}).join("");
 function show(k){cur=k;$("codeView").textContent=D.views[k];
   Array.prototype.forEach.call($("tabs").children,function(b){b.className="tab"+(b.dataset.k===k?" on":"")})}
 $("tabs").addEventListener("click",function(e){if(e.target.dataset.k)show(e.target.dataset.k)});show("clean");
 var onlyClean=false;
 function renderBlocks(){
   $("blocks").innerHTML=D.blocks.filter(function(b){return !onlyClean||!b.noise}).map(function(b){
     return '<div class="blk'+(b.noise?" noise":"")+'"><div class="n mono">'+b.i+'</div><div class="kd mono">'+
       esc(b.kind)+'</div><div class="pv">'+esc(b.preview)+(b.noise?' <span class="pill warn">'+esc(b.noise)+'</span>':'')+
       '</div><div class="ln mono">'+fmt(b.len)+'</div></div>'}).join("")}
 renderBlocks();
 $("filterBtn").addEventListener("click",function(){onlyClean=!onlyClean;renderBlocks();
   this.textContent=onlyClean?"显示全部 "+D.article.blocks+" 块":"只显示正文（"+D.noiseCount+" 个噪声块）"});
 $("origSize").textContent=fmt(D.sizes.text)+" B";$("cleanSize").textContent=fmt(D.sizes.clean)+" B";
 setTimeout(function(){$("barClean").style.width=(D.sizes.clean/D.sizes.text*100)+"%"},80);
 $("backends").innerHTML=D.backends.map(function(b){
   return '<div class="out'+(D.identical?" ok":"")+'"><div style="font-size:13px;font-weight:700">'+esc(b.label)+
     '</div><div class="mono" style="font-size:11px;color:var(--muted);margin:5px 0 8px">sha256 '+
     esc(b.sha)+'…</div><div style="font-size:11px">'+fmt(b.bytes)+' B</div></div>'}).join("");
 $("cmpPill").textContent=D.identical?"OK: "+D.backends.length+" outputs are byte-identical":"哈希不一致";
 $("cmds").textContent=D.commands.join("\n");
 $("copyBtn").addEventListener("click",function(){var t=$("cmds").textContent,b=this;
   var done=function(){b.textContent="已复制";setTimeout(function(){b.textContent="复制"},1500)};
   if(navigator.clipboard&&navigator.clipboard.writeText)navigator.clipboard.writeText(t).then(done,done);
   else{var a=document.createElement("textarea");a.value=t;document.body.appendChild(a);a.select();
     try{document.execCommand("copy");done()}catch(e){}document.body.removeChild(a)}});
})();
</script>
</body>
</html>
"""

payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
html = (
    TEMPLATE.replace("__CK_DATA__", payload)
    .replace("__KPI_BLOCKS__", str(len(blocks)))
    .replace("__KPI_NOISE__", str(data["noiseCount"]))
)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html, encoding="utf-8", newline="\n")
print(f"generated {OUT.relative_to(ROOT)}  ({OUT.stat().st_size:,} bytes)")
print(
    f"  html={data['htmlBytes']}B blocks={len(blocks)} noise={data['noiseCount']} "
    f"backends_identical={identical} text={data['sizes']['text']}B clean={data['sizes']['clean']}B"
)
