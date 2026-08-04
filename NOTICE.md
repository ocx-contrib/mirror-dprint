# NOTICE

This repository packages and redistributes upstream software published by the
[dprint](https://github.com/dprint/dprint) project. The Apache-2.0 license in
[`LICENSE`](LICENSE) covers the OCX pipeline files authored here. It does
**not** cover any upstream-derived asset — each package's redistributed bytes
carry their own license, recorded below.

Each package's logo in this repository is an **original mark authored here**,
not an upstream one: dprint publishes no logo of its own (checked at the
upstream repo root, `website/src/assets/images/` and the site layouts — none
present). No upstream trademark is reproduced, and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `dprint` | `ghcr.io/ocx-contrib/dprint/dprint` | `MIT` |

---

## `dprint`

Upstream: <https://github.com/dprint/dprint>
Published to `ghcr.io/ocx-contrib/dprint/dprint`.

| Component | SPDX | Holder |
|---|---|---|
| dprint (`dprint`) | **MIT** | Copyright (c) 2019 David Sherret |

Verified at the source, not inferred:

```
$ gh api repos/dprint/dprint/license --jq '.license.spdx_id'
MIT
```

The MIT License grants redistribution of the software in source and binary form
without restriction, on the single condition that the copyright notice and the
permission notice accompany all copies or substantial portions of the software.

**How that condition is met here matters, because the mirrored archive is a
single file.** Upstream's release zips contain the `dprint` binary and nothing
else — there is no `LICENSE` file inside them to republish. The notice instead
travels *inside the binary*, which embeds the full MIT text and prints it on
demand:

```
$ dprint license
==== DPRINT CLI LICENSE ====
The MIT License (MIT)

Copyright (c) 2019 David Sherret
…
```

So every copy this mirror distributes carries the copyright notice and the
permission notice with it. In addition, the published OCI index is annotated
`org.opencontainers.image.licenses: MIT`, and this file plus the package
catalog record the holder.

The published binaries statically link third-party Rust crates under permissive
licenses, enumerated in the `Cargo.lock` of the tagged upstream source for each
mirrored version. (`dprint license` prints the CLI's own MIT text only — it
does not enumerate the dependency licenses.)

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
