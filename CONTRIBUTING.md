# Contributing to promptarena-sandbox

Thanks for your interest in contributing! Please read the following before opening a pull request.

## Developer Certificate of Origin (DCO)

This project uses the Developer Certificate of Origin (DCO) to certify that you have the right to submit your contributions. By making a contribution you certify the statements in the [DCO](https://developercertificate.org/).

### Signing your commits

Add the `-s` flag to your commit:

```bash
git commit -s -m "Your commit message"
```

This adds a `Signed-off-by: Your Name <you@example.com>` line to the commit.

> **This is enforced.** A required `DCO` check verifies every commit in your pull request carries a matching `Signed-off-by` line. If you forget, fix it with `git commit --amend -s` (single commit) or `git rebase --signoff main` (multiple commits), then force-push.

## Contributor License Agreement (CLA)

Before your first contribution can be merged you must sign our Contributor License Agreement. When you open your first pull request, the **CLA Assistant** bot comments with a link to the CLA; you sign by replying on the PR with:

> I have read the CLA Document and I hereby sign the CLA

You sign **once** — the signature then applies to your future contributions across AltairaLabs repositories. The CLA is a **license grant**, not a copyright assignment: you keep ownership of your contribution and grant AltairaLabs a license to use and relicense it. You can read the full text [here](https://gist.github.com/chaholl/acc8f1f6c38376d00a162351f566b93e).

## Making a change

This is a single-image repo: one `Dockerfile`, one CI workflow, one release workflow. There's no build system beyond Docker.

```bash
docker build -t promptarena-sandbox:dev .

# Same probe CI runs, against your local build:
docker run --rm --entrypoint sh promptarena-sandbox:dev -c '
  [ -z "$(ls -A /workspace 2>/dev/null)" ]
  test -f /opt/promptarena/brief/AGENTS.md
  test -d /opt/promptarena/brief/.claude/skills/promptarena-authoring
  promptarena --version
  packc version
  [ "$(id -u)" -ne 0 ]
'
```

Conventional Commits for PR titles and commit messages (`feat:`, `fix:`, `chore:`, `ci:`, `docs:`).
