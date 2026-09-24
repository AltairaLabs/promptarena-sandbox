# promptarena-sandbox — Claude Code Project Instructions

## Project

A single Docker image: [codegen-sandbox](https://github.com/AltairaLabs/CodeGen-Sandbox)
plus the [PromptArena](https://github.com/AltairaLabs/promptarena) CLI
(`promptarena`, `packc`), briefed for PromptArena kit authoring. See
[README.md](README.md) for what it is and how Omnia uses it.

## What ships from this repo

- `Dockerfile` — the image. That's the whole product.
- `.github/workflows/ci.yml` — build + probe on PR and push to `main`.
- `.github/workflows/release.yml` — multi-arch build + push to GHCR on a
  `v*` tag.

There is no Go/Node/Python source in this repo, no build system beyond
Docker, and no docs site. Do not add one without discussing it first — the
whole point of splitting this out from codegen-sandbox was to keep it small.

## Conventions

- **Conventional commits** (`feat:`, `fix:`, `chore:`, `ci:`, `docs:`).
- **DCO required**: `git commit -s`, author email must match the
  `Signed-off-by:` line. See [CONTRIBUTING.md](CONTRIBUTING.md).
- Changing the Dockerfile means rerunning the local build + probe
  (README.md, "Local build + probe") before committing.

## Things that will bite you

- **`packc` is not cobra-based.** `packc --version` fails (unknown command,
  exit 1) — the subcommand is `packc version`, no dashes. `promptarena
  --version` works fine (it's a real cobra flag). Don't "fix" the probe to
  use `--version` for both; it's deliberate.
- **The brief goes to `/opt/promptarena/brief`, never `/workspace`.**
  `/workspace` is a real user project mounted read-write in Omnia — brief
  files written there would pollute it. See the Dockerfile comment and
  README "Why the brief isn't in /workspace".
- **The base image is pinned by digest, not tag.** Bumping it is a
  deliberate edit to the `FROM` line in `Dockerfile`, not something that
  happens implicitly via `:latest`.
- **This repo does not build or own the Omnia module** (the Helm chart
  wrapping this image's `ClusterSandboxClass` + `ToolRegistry`). That lives
  in the Omnia repo; this repo only ships the image it depends on.

## Upstream

`promptkit-local`-style read-only checkouts don't apply here — there's no Go
code importing anything. If you find a bug in `promptarena` or `packc`
itself (not this image), file it at
https://github.com/AltairaLabs/promptarena/issues; this repo can only work
around it by pinning to an older tag.
