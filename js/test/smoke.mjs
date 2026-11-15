import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";
import {
  extractJson,
  extractText,
  extractMd,
  rulesVersion,
  goldenBundle,
} from "../dist/contentkit.js";

const html = `<html><head><title>Smoke test</title></head><body>
<nav>nav nav nav nav nav nav nav nav</nav>
<article id="content"><h1>Smoke test</h1>
<p>This is a sufficiently long article paragraph, with commas, punctuation, and enough natural language signal to be selected as the main content block by the scoring model.</p>
</article></body></html>`;

const json = extractJson(html);
const article = JSON.parse(json);
assert.equal(article.title, "Smoke test");
assert.ok(article.blocks.length >= 2);
assert.equal(article.rules_version, "1.0.0");
assert.ok(article.text.includes("sufficiently long article paragraph"));
assert.ok(article.markdown.startsWith("# Smoke test"));
assert.equal(extractText(html), article.text);
assert.equal(extractMd(html), article.markdown);
assert.equal(rulesVersion(), "1.0.0");

// 幂等性
assert.equal(extractJson(html), json);

// Golden Bundle 必须与仓库里的期望输出逐字节一致
const bundle = goldenBundle();
const goldenPath = new URL("../../testdata/expected/bundle.txt", import.meta.url);
if (existsSync(goldenPath)) {
  assert.equal(bundle, readFileSync(goldenPath, "utf8"));
}

console.log("npm smoke test OK:", bundle.trim().split("\n").length, "cases,", bundle.length, "bytes");
