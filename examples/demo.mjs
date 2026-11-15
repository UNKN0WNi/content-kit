#!/usr/bin/env node
// content-kit 真实网页使用示范（Node / ESM 通道）
//
//   node examples/demo.mjs                         # 用 examples/page.html
//   node examples/demo.mjs my.html                # 指定任意本地 HTML
//   node examples/demo.mjs my.html --clean        # 附带应用层轻量清洗对比
//
// 输入：任意真实网页的 HTML（UTF-8），不随仓库分发。
// 前置：先跑 `bash scripts/package-npm.sh` 或 `moon build --target js js`
//       产出 _build/js/debug/build/js/js.js
// 输出：examples/page.text / page.md / page.json（+ --clean 时的 page.clean.*）
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const HERE = path.join(ROOT, "examples");
const STEM = path.join(HERE, "page");
const ARTIFACT = path.join(ROOT, "_build/js/debug/build/js/js.js");
const args = process.argv.slice(2);
const HTML = args.find((a) => !a.startsWith("--")) ?? path.join(HERE, "page.html");

if (!fs.existsSync(HTML) || !fs.existsSync(ARTIFACT)) {
  console.error(
    "缺少输入网页或 js 产物，请先执行：\n" +
      "  bash examples/run.sh --fetch \"https://example.com/article\"   # 抓取任意真实页面\n" +
      "  # 或手动把页面保存为 examples/page.html\n" +
      "  bash scripts/package-npm.sh        # 构建 js 产物",
  );
  process.exit(1);
}

const kit = await import(new URL(`file://${ARTIFACT.replace(/\\/g, "/")}`).href);
const html = fs.readFileSync(HTML, "utf8");

console.log("输入网页 :", path.relative(ROOT, HTML));
console.log("输入字节 :", Buffer.byteLength(html).toLocaleString(), "B");
console.log("导出函数 :", ["extractJson", "extractText", "extractMd", "rulesVersion"].join(", "));
console.log("规则版本 :", kit.rulesVersion());

// ① 一次抽取，三种输出（都来自同一个 Article.blocks）
const json = kit.extractJson(html);
const text = kit.extractText(html);
const md = kit.extractMd(html);
fs.writeFileSync(`${STEM}.json`, json);
fs.writeFileSync(`${STEM}.text`, text);
fs.writeFileSync(`${STEM}.md`, md);

const article = JSON.parse(json);
console.log("\n— 抽取结果 —");
console.log("标题     :", article.title);
console.log("发布时间 :", article.published_at ?? "(无)");
console.log("站点     :", article.site_name ?? "(无)");
console.log("作者     :", article.byline ?? "(无)");
console.log("语言     :", article.lang ?? "(无)");
console.log("内容块   :", article.blocks.length, "| score:", article.score);
console.log("输出体积 :", `text ${Buffer.byteLength(text).toLocaleString()} B`,
  `/ md ${Buffer.byteLength(md).toLocaleString()} B`,
  `/ json ${Buffer.byteLength(json).toLocaleString()} B`);

// ② 应用层轻量清洗（可选）：真实站点常有内联 base64 图、广告图、页脚推广。
//    这不是 content-kit 内核能力，而是调用方拿到 Article 后能做的后处理示范。
//    规则可按自己的站点调整，属于「调用方策略」而非内核规则。
if (args.includes("--clean")) {
  const isNoise = (b) => {
    const t = b.text ?? "";
    const src = b.src ?? b.url ?? "";
    return (
      src.startsWith("data:") ||
      /\b(ad|ads|advert|banner|sponsor|promo)\b|\d{2,4}x\d{2,4}\.(jpe?g|png|webp)/i.test(src) ||
      /^(海量资讯|广告|责任编辑|版权所有|阅读原文|扫码|下载APP)/.test(t)
    );
  };
  const kept = article.blocks.filter((b) => !isNoise(b));
  const line = (b) => {
    switch (b.kind) {
      case "heading": return `${"#".repeat(b.level ?? 1)} ${b.text}`;
      case "paragraph": return b.text;
      case "quote": return `> ${b.text}`;
      case "listitem": return `- ${b.text}`;
      case "code": return "```\n" + b.text + "\n```";
      case "image": return `![${b.alt ?? ""}](${b.src})`;
      default: return b.text ?? "";
    }
  };
  const cleanText = kept.map(line).join("\n\n");
  const cleanJson = JSON.stringify({ ...article, blocks: kept }, null, 2);
  fs.writeFileSync(`${STEM}.clean.text`, cleanText);
  fs.writeFileSync(`${STEM}.clean.json`, cleanJson);
  console.log("\n— 应用层清洗对比 —");
  console.log("剔除噪声块 :", article.blocks.length - kept.length,
    `(保留 ${kept.length} 块)`);
  console.log("正文体积   :", `${Buffer.byteLength(text).toLocaleString()} B →`,
    `${Buffer.byteLength(cleanText).toLocaleString()} B`);
  console.log("输出文件   : examples/page.clean.text / page.clean.json");
  console.log("说明       : 由过滤后的 blocks 二次渲染，仍保持「同一份 blocks 单一来源」。");
}

console.log("\n三份输出已写入 examples/page.*（本地产物，不入库）。");
