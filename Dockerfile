# syntax=docker/dockerfile:1.7
#
# promptarena-sandbox — codegen-sandbox base plus the PromptArena CLI and
# packc compiler, briefed for PromptArena kit authoring.
#
# Unlike the tools-* variants in codegen-sandbox (which COPY a prebuilt
# sandbox-forward-style binary), this builds `promptarena` and `packc` from
# the published module source via `go install`, pinned to a released tag —
# there is no prebuilt linux binary artifact for either.
#
# This is a PROJECT-BOUND sandbox: /workspace is the user's mounted
# PromptArena project (read-write), not scratch space, so the agent brief
# must not land there. It goes to /opt/promptarena/brief instead.
#
# Precedent: promptarena/examples/test-a-codegen-agent/Dockerfile, which
# COPYs a prebuilt `bin/promptarena-linux` and briefs `/workspace` — that
# image has no project mount, so writing the brief into /workspace is safe
# there and is NOT safe here.
#
# Build via: docker build -t promptarena-sandbox:dev .

# -------- promptarena + packc builder --------
# promptarena's go.mod declares `go 1.26.0`, so this stage pins its own Go
# base rather than assuming whatever toolchain the sandbox base was built
# with.
FROM golang:1.26-alpine AS builder

# Pinned to the latest released tag (github.com/AltairaLabs/promptarena
# v2.1.0, 2026-09-22). Bump deliberately, not via @latest, so this image is
# reproducible.
ARG PROMPTARENA_VERSION=v2.1.0

RUN apk add --no-cache git ca-certificates

# purego (promptarena's dependency for dynamic library loading) is pure Go,
# so CGO_ENABLED=0 produces a fully static, musl-and-glibc-portable binary.
RUN CGO_ENABLED=0 GOBIN=/out go install \
      -trimpath -ldflags='-s -w' \
      github.com/AltairaLabs/promptarena/v2/arena/cmd/promptarena@${PROMPTARENA_VERSION} \
    && CGO_ENABLED=0 GOBIN=/out go install \
      -trimpath -ldflags='-s -w' \
      github.com/AltairaLabs/promptarena/v2/packc@${PROMPTARENA_VERSION} \
    && /out/promptarena --help >/dev/null \
    && /out/packc --help >/dev/null

# -------- Final: codegen-sandbox base + promptarena + packc --------
FROM ghcr.io/altairalabs/codegen-sandbox@sha256:10628364c517c125d3f4de8fc3ab8160d45b99434d46b1b38872aed4230dbbdd

COPY --chmod=755 --from=builder /out/promptarena /usr/local/bin/promptarena
COPY --chmod=755 --from=builder /out/packc /usr/local/bin/packc

# Brief the agent exactly like a real PromptArena project: drop AGENTS.md
# and the full .claude/skills/promptarena-authoring/SKILL.md so the agent
# has the same tooling a developer's coding agent would. Written to
# /opt/promptarena/brief, NOT /workspace — /workspace is the mounted
# project on a project-bound sandbox and must not be polluted with brief
# files that don't belong to it.
#
# The base image runs as the unprivileged `sandbox` user; switch to root
# only to create and own this directory, then drop back.
USER root
RUN mkdir -p /opt/promptarena/brief \
    && /usr/local/bin/promptarena agent-brief /opt/promptarena/brief \
    && chown -R sandbox:sandbox /opt/promptarena

# Offline schemas. The sandbox has no network, and promptarena's config
# loading (`validate`, `run`, and packc) fetches each JSON schema from
# https://promptkit.altairalabs.ai unless PROMPTKIT_SCHEMA_SOURCE=local. In
# local mode it looks for schemas/v1alpha1/<type>.json relative to the
# working directory and up to three parents — so /schemas/v1alpha1 is found
# from /workspace and anything below it, without writing into the project.
# The files are the CLI's own embedded schemas, so they always match the
# pinned promptarena version.
RUN mkdir -p /schemas/v1alpha1 \
    && for t in $(/usr/local/bin/promptarena schema --list); do \
         /usr/local/bin/promptarena schema "$t" > "/schemas/v1alpha1/$t.json"; \
       done \
    && test -s /schemas/v1alpha1/arena.json
ENV PROMPTKIT_SCHEMA_SOURCE=local
USER sandbox
