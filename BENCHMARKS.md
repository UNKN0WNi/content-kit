# 产物体积与构建结果

生成时间：2026-11-14 16:30:38 UTC
工具链：moon 0.1.20261104 (940aa18 2026-11-04)

| 后端 | 产物 | 体积 | 预算 |
|---|---|---|---|
| js | `_build/js/debug/build/cli/cli.js` | 175797 B | 400 KB |
| js | `_build/js/debug/build/js/js.js` | 157784 B | 400 KB |
| js | `_build/js/debug/build/wasm/wasm.js` | 157979 B | 400 KB |
| wasm | `_build/wasm/debug/build/cli/cli.wasm` | 170051 B | 500 KB |
| wasm | `_build/wasm/debug/build/js/js.wasm` | 204 B | 500 KB |
| wasm | `_build/wasm/debug/build/wasm/wasm.wasm` | 152714 B | 500 KB |
| wasm-gc | `_build/wasm-gc/debug/build/cli/cli.wasm` | 100524 B | 500 KB |
| wasm-gc | `_build/wasm-gc/debug/build/js/js.wasm` | 197 B | 500 KB |
| wasm-gc | `_build/wasm-gc/debug/build/wasm/wasm.wasm` | 91136 B | 500 KB |
| native | 纯库包（core/parse/extract/testdata） | 链接产物需 MSVC | 3 MB |

> **宿主限制**：本机未安装 MSVC / clang-cl，`moon build --target native`
> 的**链接**步骤不可用；`moon check --target native`、纯库 `moon build`
> 与全部源码在四个后端的类型检查均已通过。安装 Visual Studio Build Tools
> 后重跑本脚本即可产出 native 可执行文件（代码无需改动）。
