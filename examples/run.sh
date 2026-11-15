#!/usr/bin/env bash
# 用「任意真实网页」跑一遍 content-kit 全链路：
#   抓取（可选） → 三后端 CLI 抽取 → 逐字节比对 → Node / ESM 示范
#
#   bash examples/run.sh                                  # 用 examples/page.html
#   bash examples/run.sh my.html                          # 指定本地 HTML
#   bash examples/run.sh --fetch "https://example.com/a"  # 抓取后复现
#   bash examples/run.sh my.html --fetch "https://..."    # 抓到指定文件
#
# 产物全部写入 examples/page.*，这些文件（含抓取的页面）都不随仓库分发。
# 各环境下的更多用法见 docs/real-world-testing.md。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

HTML="examples/page.html"
URL=""
FETCH=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fetch)
      FETCH=1
      shift
      if [[ $# -gt 0 && "$1" != --* ]]; then URL="$1"; shift; fi
      ;;
    --url)
      shift
      URL="${1:-}"
      shift || true
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    --*) echo "未知参数: $1" >&2; exit 2 ;;
    *) HTML="$1"; shift ;;
  esac
done

if (( FETCH )); then
  [[ -n "$URL" ]] || { echo "用法: bash examples/run.sh [--fetch URL] 或设置 --url URL" >&2; exit 2; }
  CHROME="${CHROME_BIN:-}"
  if [[ -z "$CHROME" ]]; then
    for c in \
      "/c/Program Files/Google/Chrome/Application/chrome.exe" \
      "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
      "$(command -v google-chrome || true)" \
      "$(command -v chromium || true)" \
      "$(command -v chromium-browser || true)"; do
      if [[ -n "$c" && -x "$c" ]]; then CHROME="$c"; break; fi
    done
  fi
  [[ -n "$CHROME" && -x "$CHROME" ]] || { echo "未找到 Chrome/Edge；可设置 CHROME_BIN，或手动把页面保存为 $HTML" >&2; exit 1; }
  mkdir -p "$(dirname "$HTML")"
  echo "== 抓取真实页面 =="
  "$CHROME" --headless=new --disable-gpu --no-sandbox \
    --virtual-time-budget=8000 --dump-dom "$URL" > "$HTML" 2>/dev/null
  printf '%s\n' "$URL" > "${HTML%.*}.url"
  echo "   $(wc -c < "$HTML" | tr -d ' ') bytes → $HTML"
fi

[[ -f "$HTML" ]] || {
  echo "缺少输入页面：$HTML" >&2
  echo "先准备任意真实网页（见 docs/real-world-testing.md），或用 --fetch URL 抓取。" >&2
  exit 1
}
# shellcheck source=/dev/null
source scripts/moon.sh

STEM="examples/page"
echo "== 三后端 CLI 抽取（同一个真实页面：$HTML） =="
for t in js wasm wasm-gc; do
  CXTRACT_TARGET="$t" bash scripts/cxtract.sh "$HTML" --format json \
    > "$STEM-$t.json" 2>/dev/null
  printf "   %-8s %s bytes  sha256 %s\n" "$t" \
    "$(wc -c < "$STEM-$t.json" | tr -d ' ')" \
    "$(sha256sum "$STEM-$t.json" | cut -c1-16)"
done

for t in wasm wasm-gc; do
  cmp -s "$STEM-js.json" "$STEM-$t.json" \
    || { echo "FAIL: $t differs" >&2; exit 1; }
done
echo "   OK: 3 outputs are byte-identical"

echo "== Node / ESM 使用示范 =="
"$MOON_BIN" build --target js --quiet js >/dev/null
node examples/demo.mjs "$HTML" --clean

echo "== 生成本地可视化页面（不入库） =="
python scripts/gen-realworld-demo.py >/dev/null && echo "   docs/realworld-demo.html 已刷新"
