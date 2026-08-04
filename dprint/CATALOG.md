---
title: dprint
description: A pluggable and configurable code formatting platform — one fast binary that formats TypeScript, JSON, Markdown, TOML, Dockerfiles and more through WebAssembly plugins
keywords: dprint,formatter,format,fmt,prettier,typescript,javascript,json,markdown,toml,wasm,code-style,cli,rust
---

# dprint

[dprint](https://dprint.dev) is a pluggable and configurable code formatting
platform written in Rust. Instead of shipping one language's formatter, it ships
a fast parallel formatting *engine* and loads each language as a WebAssembly
plugin, so a single `dprint fmt` formats every file type in a repository from
one `dprint.json`.

## What's included

- **dprint** — the CLI and formatting engine. `dprint fmt` formats in place,
  `dprint check` fails on anything unformatted (the CI gate), `dprint init`
  scaffolds a config and `dprint lsp` serves formatting to an editor.

The archive contains exactly this one binary; the language formatters are
plugins, resolved at run time.

## Plugins are downloaded, not bundled

dprint's core contains no formatters. Each one is a WebAssembly module named in
your config and fetched from `plugins.dprint.dev` on first use, then cached — so
the first run in a fresh environment needs network access, and a config with an
empty `plugins` array exits 13 with *"No formatting plugins found"*.

```json
{
  "typescript": {},
  "json": {},
  "markdown": {},
  "excludes": ["**/node_modules", "**/target"],
  "plugins": [
    "https://plugins.dprint.dev/typescript-0.95.11.wasm",
    "https://plugins.dprint.dev/json-0.20.0.wasm",
    "https://plugins.dprint.dev/markdown-0.19.0.wasm"
  ]
}
```

`dprint init` writes a starting config for you, and `dprint config add <plugin>`
appends one at its latest version.

## Typical use

```sh
dprint fmt                 # format everything the config matches
dprint check               # exit 20 if anything is unformatted — the CI gate
dprint fmt --diff          # show what would change
dprint file-paths          # what the config actually resolves to
```

## Install with ocx

```sh
ocx install ocx.sh/dprint/dprint
```

```sh
# or pin a specific version
ocx install ocx.sh/dprint/dprint:0.55.2
```

## Links

- [dprint.dev](https://dprint.dev)
- [dprint on GitHub](https://github.com/dprint/dprint)
- [Plugin list](https://dprint.dev/plugins/)
- [Configuration reference](https://dprint.dev/config/)
- [Playground](https://dprint.dev/playground)
