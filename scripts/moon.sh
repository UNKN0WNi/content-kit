#!/usr/bin/env bash
# 统一封装本机免安装的 MoonBit 工具链路径。
# 若系统已安装 moon（在 PATH 上），则直接使用系统的。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLED="$(cd "$ROOT/.." && pwd)/.tools/moonbit"

if [[ -x "$BUNDLED/bin/moon" || -x "$BUNDLED/bin/moon.exe" ]]; then
  export MOON_HOME="$BUNDLED"
  export PATH="$BUNDLED/bin:$PATH"
fi

if command -v moon >/dev/null 2>&1; then
  MOON_BIN="$(command -v moon)"
else
  echo "moon toolchain not found (expected $BUNDLED/bin/moon or a system-wide moon)" >&2
  exit 127
fi
export MOON_BIN
