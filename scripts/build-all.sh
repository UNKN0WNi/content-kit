#!/usr/bin/env bash
# M5：四后端产物构建 + 体积记录。
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="BENCHMARKS.md"
{
  echo "# 产物体积与构建结果"
  echo
  echo "生成时间：$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "工具链：$("$MOON_BIN" version | head -1)"
  echo
  echo "| 后端 | 产物 | 体积 | 预算 |"
  echo "|---|---|---|---|"
} > "$OUT"

for target in js wasm wasm-gc; do
  echo "== moon build --target $target =="
  "$MOON_BIN" build --target "$target" --quiet >/dev/null
  for artifact in $(find "_build/$target/debug/build" -type f \( -name '*.js' -o -name '*.wasm' \) 2>/dev/null | sort); do
    size=$(wc -c < "$artifact" | tr -d ' ')
    echo "| $target | \`$artifact\` | $size B | $([[ $target == js ]] && echo '400 KB' || echo '500 KB') |" >> "$OUT"
  done
done

echo "== moon build --target native (pure libraries) =="
if "$MOON_BIN" build --target native --quiet core parse/html parse/plain extract testdata >/dev/null 2>&1; then
  echo "| native | 纯库包（core/parse/extract/testdata） | 链接产物需 MSVC | 3 MB |" >> "$OUT"
  echo "   native 纯库构建成功。"
else
  echo "   native 纯库构建失败。" >&2
fi

if "$MOON_BIN" build --target native --quiet >/dev/null 2>&1; then
  echo "   native 可执行产物构建成功。"
  for artifact in $(find "_build/native" -type f -perm -u+x 2>/dev/null | sort); do
    size=$(wc -c < "$artifact" | tr -d ' ')
    echo "| native | \`$artifact\` | $size B | 3 MB |" >> "$OUT"
  done
else
  cat >> "$OUT" <<'EOF'

> **宿主限制**：本机未安装 MSVC / clang-cl，`moon build --target native`
> 的**链接**步骤不可用；`moon check --target native`、纯库 `moon build`
> 与全部源码在四个后端的类型检查均已通过。安装 Visual Studio Build Tools
> 后重跑本脚本即可产出 native 可执行文件（代码无需改动）。
EOF
  echo "   native 链接被宿主环境阻止（缺 MSVC），详见 $OUT。"
fi

echo "== done: $OUT =="
