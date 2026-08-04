# dprint/tests/smoke.star — stable across upstream dprint releases.
# Asserts the contract (exit codes, version shape, computed diagnostics), never
# help/version prose. See ocx.mirror testing-practices.md.
#
# ⚠ WHY THIS TEST DOES NOT FORMAT ANY CODE.
# dprint's core binary contains ZERO formatters. Every language plugin is a
# WebAssembly module fetched from plugins.dprint.dev at run time and compiled
# by the wasmtime engine embedded in the binary — measured directly:
#
#   $ dprint check -c <config with "plugins": []>
#   No formatting plugins found. …            exit 13
#
# A `dprint fmt` smoke test would therefore be a test of the network and of
# whichever plugin version it happened to download, in a bare `alpine:3.20`
# container with no CA bundle — exactly the "any network call" anti-pattern.
# So this follows the fleet's deliberate-stop pattern (cf.
# mirror-bazelbuild/bazelisk, which likewise cannot download its payload):
# drive dprint's OWN logic as far as it reaches offline, then stop it on
# purpose, and assert on tokens THE BINARY COMPUTED plus its documented exit
# code.
#
# Exit codes below are read out of upstream's source, not guessed —
# crates/dprint/src/run_cli.rs at tag 0.55.2 maps each error type to a fixed
# code:  ParseArgsError 10 · ResolveConfigError 11 · ResolvePluginsError 12 ·
# NoPluginsFoundError 13 · NoFilesFoundError 14 · CheckError 20.
# Every assertion here was measured against ALL THREE in-range versions
# (0.55.0, 0.55.1, 0.55.2) under `unshare -rn` — i.e. with no network at all —
# and is identical on each.

DPRINT = "dprint.exe" if ocx.target_platform.os == ocx.os.Windows else "dprint"

# The bogus plugin's first four bytes are a marker chosen HERE. wasmtime echoes
# the bytes it actually read back as the "actual" magic number, so asserting
# them proves the embedded wasm engine parsed OUR file — a binary that merely
# printed its arguments could not produce them.
#   "OCX!" = 0x4f 0x43 0x58 0x21
FAKE_PLUGIN = "OCX!not-a-wasm-module\n"

# ── Tier 1 + 2: liveness on the composed PATH + version SHAPE ───────────────
# The digits are the contract; the vendor banner around them is not.
r_version = ocx.run(DPRINT, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

# ── Tier 3a: a real code-generation path that succeeds offline ──────────────
# `completions` walks dprint's entire clap command tree and emits a ~50 KB bash
# completion script. Asserted on structure (`COMPREPLY`, a shell builtin the
# generator writes) and on SUBCOMMAND NAMES, which are contract; the help
# descriptions wrapped around them are not, and are not asserted.
r_comp = ocx.run(DPRINT, "completions", "bash")
expect.ok(r_comp)
expect.contains(r_comp.stdout, "COMPREPLY")
expect.contains(r_comp.stdout, "resolved-config")
expect.contains(r_comp.stdout, "clear-cache")

# ── Tier 3b: the embedded wasm engine, driven to a deliberate stop ──────────
# `--plugins` accepts local FILE PATHS as well as URLs, so this stays entirely
# inside the scratch sandbox and never resolves a hostname. dprint canonicalises
# the path, reads the file and hands it to wasmtime, which rejects the magic
# number — proving arg parsing, plugin resolution, local file IO and the wasm
# engine itself all work in this bundle. `--config-discovery=false` keeps the
# result independent of any dprint.json that might exist in an ancestor of the
# scratch directory on some runner.
ocx.write_file("fake-plugin.wasm", FAKE_PLUGIN)
ocx.write_file("sample.txt", "hello\n")
r_plugin = ocx.run(
    DPRINT, "check", "--config-discovery=false",
    "--plugins", "fake-plugin.wasm", "--", "sample.txt",
)
expect.eq(r_plugin.exit_code, 12)                        # ResolvePluginsError
# wasmtime's own constant for the WASM preamble, `\0asm`:
expect.matches(r_plugin.stderr, r"0x0,\s*0x61,\s*0x73,\s*0x6d,")
# …and the four bytes it read out of the file written above. Whitespace-
# tolerant so a change in the engine's array formatting cannot break it.
expect.matches(r_plugin.stderr, r"0x4f,\s*0x43,\s*0x58,\s*0x21,")

# ── Tier 3c: negative control — the config parser really parses ─────────────
# Malformed JSONC must NOT be accepted. Without this, a dprint that ignored its
# config file entirely would pass every other assertion here.
ocx.write_file("bad.json", "{ \"plugins\": [ }\n")
r_bad = ocx.run(DPRINT, "check", "-c", "bad.json", "--", "sample.txt")
expect.eq(r_bad.exit_code, 11)                           # ResolveConfigError

# ── Tier 3d: negative control — a WELL-FORMED config is accepted, and the ───
# run then stops for the one remaining reason: no plugins. Paired with 3c this
# proves both directions of the parser — 11 means "rejected the bad file", 13
# means "accepted the good one and got past it".
ocx.write_file("empty.json", "{\n  \"plugins\": []\n}\n")
r_empty = ocx.run(DPRINT, "check", "-c", "empty.json", "--", "sample.txt")
expect.eq(r_empty.exit_code, 13)                         # NoPluginsFoundError
