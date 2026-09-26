# promptarena-sandbox

[![CI](https://github.com/AltairaLabs/promptarena-sandbox/actions/workflows/ci.yml/badge.svg)](https://github.com/AltairaLabs/promptarena-sandbox/actions/workflows/ci.yml)

A [codegen-sandbox](https://github.com/AltairaLabs/CodeGen-Sandbox) derivative
that adds the [PromptArena](https://github.com/AltairaLabs/promptarena) CLI
(`promptarena`) and pack compiler (`packc`), briefed for authoring PromptArena
kits. It's not a fork — it's a separate image built `FROM` a pinned
codegen-sandbox digest, with the PromptArena tooling layered on top.

## What's in the image

- The codegen-sandbox base: the sandbox MCP server (`Read`, `Write`, `Edit`,
  `Glob`, `Grep`, `Bash`, `run_tests`/`run_lint`/`run_typecheck`) plus its
  pinned toolchains, running as the unprivileged `sandbox` user.
- `promptarena` and `packc`, `go install`ed from the published
  `github.com/AltairaLabs/promptarena` module at a pinned release tag (not a
  prebuilt binary — there isn't one for these two commands).
- The PromptArena **authoring brief**: `AGENTS.md` and the full
  `.claude/skills/promptarena-authoring/` skill (including its reference
  docs), written by `promptarena agent-brief` at build time.

## Offline schemas

The sandbox has no network, but promptarena's config loading fetches its JSON
schemas from `https://promptkit.altairalabs.ai` unless
`PROMPTKIT_SCHEMA_SOURCE=local`. The image writes the CLI's own embedded
schemas to `/schemas/v1alpha1` and sets that variable, so `promptarena
validate`, `promptarena run` and `packc` work from `/workspace` (local mode
looks in `schemas/v1alpha1` relative to the working directory and up to three
parents). CI probes this with `--network none`.

## Why the brief isn't in `/workspace`

Most codegen-sandbox variants brief `/workspace` directly, because
`/workspace` is scratch space with nothing else in it. This image is
different: it's **project-bound**. In Omnia, a `SandboxClaim` with
`spec.mount.role: project` mounts the user's actual PromptArena project at
`/workspace`, read-write — writing brief files there would pollute a real
project's tree with files that aren't part of it.

So the brief lives at `/opt/promptarena/brief` instead:

```
/opt/promptarena/brief/
├── AGENTS.md
└── .claude/skills/promptarena-authoring/
    ├── SKILL.md
    └── reference/
```

An AI builder agent working against this sandbox reads the brief from there
before touching `/workspace`, exactly as if a developer had run
`promptarena agent-brief` in their own project.

## How Omnia uses this image

This image is meant to back a **project-bound sandbox class** — see
[AltairaLabs/Omnia#2742](https://github.com/AltairaLabs/Omnia/issues/2742).
The intended shape, mirroring Omnia's existing `sandbox.defaultClass.*` Helm
value:

```yaml
# values.yaml (Omnia chart)
sandbox:
  promptarenaClass:
    enabled: true
    name: promptarena
    image: ghcr.io/altairalabs/promptarena-sandbox:v0.1.0
    resources:
      requests: { cpu: 500m, memory: 512Mi }
      limits: { cpu: "2", memory: 2Gi }
```

which renders a `ClusterSandboxClass`:

```yaml
apiVersion: omnia.altairalabs.ai/v1alpha1
kind: ClusterSandboxClass
metadata:
  name: promptarena
spec:
  image: ghcr.io/altairalabs/promptarena-sandbox:v0.1.0
  mounts:
    - role: project
      access: ReadWrite
  # resources, runtimeClassName, etc. — same shape as the default class
```

A `SandboxClaim` with `spec.classRef: {name: promptarena, kind:
ClusterSandboxClass}` and `spec.mount: {role: project, id: <projectID>}` then
gets a sandbox pod with the mounted project at `/workspace` and this image's
tooling on `PATH`. The dashboard's AI builder agent works the project with
`promptarena` / `packc` from there.

**This repo ships the image only.** Packaging it as an installable Omnia
**module** — a Helm chart rendering the `ClusterSandboxClass` and a
`ToolRegistry` referencing it — is the intended next step, not done here.

## Bumping versions

### The codegen-sandbox base digest

`Dockerfile`'s first `FROM` in the final stage pins
`ghcr.io/altairalabs/codegen-sandbox` by digest, not by tag, so this image is
reproducible independent of what `:latest` currently points to. To bump it:

```bash
docker pull ghcr.io/altairalabs/codegen-sandbox:latest
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/altairalabs/codegen-sandbox:latest
```

Paste the resulting `sha256:...` into the `FROM` line, rebuild, and rerun the
probe (see below) before committing.

### The PromptArena version

`Dockerfile`'s builder stage pins `ARG PROMPTARENA_VERSION=v2.1.0` to a
released tag of `github.com/AltairaLabs/promptarena` — deliberately, not
`@latest`, so builds are reproducible. Bump it to a new release tag, rebuild,
and rerun the probe.

## Releases

Pushing a `v*` tag (e.g. `v0.1.0`) runs `.github/workflows/release.yml`,
which builds the image for `linux/amd64` + `linux/arm64` and pushes:

- `ghcr.io/altairalabs/promptarena-sandbox:<tag>`
- `ghcr.io/altairalabs/promptarena-sandbox:latest`

**New GHCR packages start private.** The first release creates the
`promptarena-sandbox` package under `ghcr.io/altairalabs` as a private
package by default — an org owner needs to flip its visibility to public in
the package settings before Omnia deployments outside AltairaLabs' own GHCR
credentials can pull it.

Every PR and push to `main` runs `.github/workflows/ci.yml`, which builds the
image (amd64 only — the release build is what proves multi-arch) and probes
it: `/workspace` is empty, the brief files exist, `promptarena --version` and
`packc version` both work, and the process runs as the non-root sandbox user.

## Local build + probe

```bash
docker build -t promptarena-sandbox:dev .

docker run --rm --entrypoint sh promptarena-sandbox:dev -c '
  [ -z "$(ls -A /workspace 2>/dev/null)" ]
  test -f /opt/promptarena/brief/AGENTS.md
  test -d /opt/promptarena/brief/.claude/skills/promptarena-authoring
  promptarena --version
  packc version
  [ "$(id -u)" -ne 0 ]
'
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the DCO/CLA workflow this repo
inherits from codegen-sandbox.

## License

Apache 2.0 — see [LICENSE](LICENSE).
