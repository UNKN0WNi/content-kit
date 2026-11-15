#!/usr/bin/env bash
# cxtract 包装器：把文件 / 标准输入读入 CONTENTKIT_INPUT，
# 再由 MoonBit CLI 通过 @env.get_env_var 读取 —— 这一通道在
# Node / moonrun(WASI) / 原生二进制上都可用，无需后端特有 FFI。
#
#   ./scripts/cxtract.sh page.html --format json
#   cat page.html | ./scripts/cxtract.sh --format md
#   CXTRACT_TARGET=wasm ./scripts/cxtract.sh page.html
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/moon.sh"
cd "$(dirname "${BASH_SOURCE[0]}")/.."

TARGET="${CXTRACT_TARGET:-js}"
ARGS=()

if [[ $# -ge 1 && -f "$1" ]]; then
  CONTENTKIT_INPUT="$(cat "$1")"
  export CONTENTKIT_INPUT
  shift
elif [[ ! -t 0 ]] && read -t 0; then
  # 仅在标准输入确实有数据时才读取，避免 `--help` 之类的调用挂住。
  DATA="$(cat)"
  if [[ -n "$DATA" ]]; then
    export CONTENTKIT_INPUT="$DATA"
  fi
fi

ARGS+=(--env-input)
ARGS+=("$@")
"$MOON_BIN" run --target "$TARGET" cli -- "${ARGS[@]}"
