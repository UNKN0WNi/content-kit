# Real-page walkthrough (local artifacts)

🌐 **Language / 语言:** **English** · [简体中文](./README.md) · [Back to main README](../README.en.md)

This directory holds the **scripts and local artifacts for running content-kit against any real web page**. Only the scripts are committed; the fetched page and extraction results stay on your machine and are excluded by `.gitignore`, so no third-party site content is distributed with the public repository.

> Full guide: [docs/real-world-testing.en.md](../docs/real-world-testing.en.md) ([中文](../docs/real-world-testing.md)) — how to quickly test a real page in every environment (CLI on three backends / Node ESM / browser / MoonBit / WASI / native).

---

## Three steps

```bash
cd content-kit

# ① Prepare a page: save it as examples/page.html, or fetch any URL
bash examples/run.sh --fetch "https://example.com/some-article"

# ② One command: 3-backend extraction + byte comparison + Node demo + visual page
bash examples/run.sh

# ③ Inspect the results
cat examples/page.text
cat examples/page.md
python -m json.tool examples/page.json | head -40
```

You can also point at your own file: `bash examples/run.sh my.html`, `node examples/demo.mjs my.html --clean`.

`run.sh` prints the byte count and sha256 of the three CLI JSON outputs — **all three must match exactly**. Then `demo.mjs` prints the title, published time, site, block count, score and the three output sizes, and shows how a caller can filter noise blocks without changing the kernel.

---

## Windows / PowerShell

On Windows, `bash` often resolves to `C:\Windows\System32\bash.exe` (the WSL launcher). Without an installed WSL distribution it fails with *"Windows Subsystem for Linux has no installed distributions"*. The repository scripts are bash scripts, so you need the **Bash shipped with Git for Windows**. Pick one:

```powershell
# ① Call Git Bash by its full path (simplest, verified)
& "C:\Program Files\Git\bin\bash.exe" examples/run.sh --fetch "https://example.com/some-article"

# ② Use the bundled PowerShell entry point: locates Git Bash and forwards arguments
powershell -ExecutionPolicy Bypass -File examples/run.ps1 -Fetch "https://example.com/some-article"

# ③ Permanent fix: point `bash` at Git Bash (write to your profile, reopen the terminal)
New-Item -ItemType Directory -Force (Split-Path $PROFILE) | Out-Null
Add-Content $PROFILE 'Set-Alias bash "C:\Program Files\Git\bin\bash.exe"'
```

After ③, the `bash examples/run.sh ...` commands above work verbatim. `run.ps1` also accepts `-Html my.html`, or forwards raw arguments such as `--fetch URL`. If Git for Windows is not installed, install it first: the scripts rely on `sha256sum`, `cmp`, `sed` and friends.

---

## Scripts

| File | Purpose |
|---|---|
| `run.sh` | One-command flow; `--fetch URL` grabs the rendered DOM via local Chrome/Edge, `--help` shows usage |
| `run.ps1` | Windows PowerShell entry point; finds a real Git Bash and forwards arguments |
| `demo.mjs` | Node / ESM demo; accepts an HTML path, `--clean` adds caller-side cleanup |
| `../scripts/gen-realworld-demo.py` | Generates the `../docs/realworld-demo.html` visual page from local `page.*` artifacts |

Prerequisites: `node >= 18`, Python 3, MoonBit toolchain (`scripts/moon.sh` finds the portable one automatically); on Windows also Git for Windows (or any working Bash).

---

## Local artifact names (none are committed)

| File | Content |
|---|---|
| `page.html` / `page.url` | fetched or manually saved real page, source URL |
| `page.text` / `page.md` / `page.json` | three Node / ESM output views |
| `page.clean.text` / `page.clean.json` | `--clean` results |
| `page-js.json` / `page-wasm.json` / `page-wasm-gc.json` | three-backend CLI outputs for byte comparison |
| `../docs/realworld-demo.html` | locally generated visual page |

---

## Why artifacts are generated locally

- Real pages contain copyrighted body text, ad images and inline base64 blobs, and can be hundreds of KB;
- A public repository should distribute the **method**, not someone else's **content**;
- With generic scripts, any site produces the same report in three commands — the result depends on the page under test, not on a snapshot in the repository.

For evaluating the result (metadata precedence, body head/tail, block count/score, noise post-processing, cross-backend hashes, visualization), see [the quick-testing guide §3](../docs/real-world-testing.en.md).
