# mirror-dprint

OCX mirror for [dprint](https://github.com/dprint/dprint), a pluggable and
configurable code formatting platform. One repository, one spec directory per
package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [dprint](https://github.com/dprint/dprint) | [`dprint/mirror.yml`](dprint/mirror.yml) | `ghcr.io/ocx-contrib/dprint/dprint` | [`ocx.sh/dprint/dprint`](https://index.ocx.sh/dprint/dprint) | `MIT` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

`dprint` is the project's own brand and its own GitHub org, so the tool names
itself: the package is `dprint/dprint`.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
dprint/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all. `dprint/mirror.yml` does not restate it at all, which removes the
trap structurally.

## Tags carry no `v`

dprint releases are tagged with **bare semver** — `0.55.2`, not `v0.55.2`. That
makes it the odd one out in this fleet, where `^v(?P<version>…)$` is the norm.
A `^v…` pattern copied from a sibling mirror matches nothing here, and a
`tag_pattern` matching nothing produces a silently empty mirror rather than an
error.

## Platforms

`dprint` publishes six platform entries: both Linux arches, both macOS arches
and both Windows arches. Upstream ships **both** a `-gnu` and a `-musl` Linux
asset for each arch, so which one to carry is a measurement, not a default —
and both were byte-measured on both arches at **both ends** of the mirrored
range (0.55.0 and 0.55.2).

The musl builds are fully **static** — no `PT_INTERP`, no `DT_NEEDED`, and no
UPX packing that could fake that reading (`strings -a | grep -c '^UPX'` → 0,
28 section headers present). `os.features` states what an artifact requires
*of the host*, so both Linux keys are **bare**: tagging them `+libc.musl`
would be a false requirement that hid the package from every glibc host it in
fact runs on.

The `-gnu` twins are rejected for two independent reasons, both measured:
0.55.0's x86_64 gnu build links `liblzma.so.5` — a runtime dependency beyond
libc that `os.features` cannot express at all — and the glibc floor *moved*
inside this three-release range (aarch64 `GLIBC_2.39` at 0.55.0,
`GLIBC_2.17` at 0.55.2), so the host set the gnu key would claim is not even
stable across the versions carried here.

Both claims were cross-checked by execution under `docker run --network none`:
the musl binary runs in `ubuntu:24.04`, `alpine:3.20` and `fedora:40` alike,
while the gnu binary dies in Alpine with `exec …: no such file or directory` —
the loader failing to find `ld-linux`. That is the exec-time death a bare key
on the gnu asset would have shipped to every musl host, and it is what makes
the `alpine:3.20` container leg in `mirror-base.yml` evidence rather than
habit.

Upstream also publishes Android, `loongarch64`, `powerpc64le` and `riscv64gc`
targets, and a Windows GUI `-installer.exe` beside the real `.zip`. ocx's
architecture enum expresses `amd64` and `arm64` only, so the exotic arches are
not declarable platforms at all; the installer is excluded by the `\.zip$` end
anchor. Resolution was verified **both ways on every in-range release**
(0.55.0, 0.55.1, 0.55.2): each of the six patterns matches exactly one asset of
seventeen, every time. A pattern matching zero would be silently skipped rather
than reported, so this check is not optional.

Asset names here are Rust target triples carrying **no version segment**, so
they are byte-identical across releases and a name-based check cannot detect an
upstream that shipped the previous version's binaries under a new tag. That was
checked by running each extracted binary instead — 0.55.0, 0.55.1 and 0.55.2
each report their own version.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `dprint/mirror.yml` | hand | yes — see below |
| `dprint/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `dprint/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec dprint/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`dprint/metadata.json` declares `binaries: ["dprint"]` by hand, and
`dprint/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. The scan
only inspects an interface-visible `${installPath}/<dir>` PATH entry, and
dprint's archives are flat **single-file** zips: `dprint` (`dprint.exe` on
Windows) alone at the archive root, with no subdirectory to point one at. With
nothing to inspect the scan would pass green whatever the archive contained, so
`auto` and `verify` both fail spec load at exit 65 rather than offer a hollow
check. The hand-written list is what the error message itself directs, and it
is as short as a list gets — the archive contains exactly one file.

## The smoke test

dprint's core binary contains **zero formatters**. Every language plugin is a
WebAssembly module fetched from `plugins.dprint.dev` at run time, so a
`dprint fmt` smoke test would really be testing the network and whichever
plugin version it downloaded — inside a bare `alpine:3.20` container with no CA
bundle. That is the "any network call" anti-pattern, so
`dprint/tests/smoke.star` does not do it.

Instead it follows the fleet's deliberate-stop pattern: drive dprint's own
logic as far as it reaches offline, then stop it on purpose and assert on
tokens **the binary computed**, plus exit codes read out of upstream's
`crates/dprint/src/run_cli.rs` (`ResolveConfigError` 11, `ResolvePluginsError`
12, `NoPluginsFoundError` 13).

The load-bearing assertion points `--plugins` at a local scratch file whose
first four bytes are the marker `OCX!`. dprint canonicalises the path, reads
the file and hands it to its embedded wasmtime engine, which rejects the magic
number and **echoes back the bytes it read** — `0x4f, 0x43, 0x58, 0x21`. A
binary that merely printed its arguments could not produce those, so the pass
proves arg parsing, plugin resolution, local file IO and the wasm engine all
work in this bundle. Two negative controls bracket the config parser: malformed
JSONC must be rejected (exit 11) and well-formed JSONC must be accepted and
then stop only for want of plugins (exit 13).

Every assertion was measured against all three in-range versions under
`unshare -rn`, and the whole sequence re-run in `ubuntu:24.04`, `alpine:3.20`
and `fedora:40` with `docker run --network none` — identical everywhere, which
is also why no `containers[].setup` line is needed.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md). The
logo is an original mark authored here — dprint publishes none.
