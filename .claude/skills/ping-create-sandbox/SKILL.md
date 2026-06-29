---
name: ping-create-sandbox
description: Use this skill when the user wants to create a sandbox or dev environment that matches the golden config (ping-config/), spin up a feature environment, provision a new SDLC environment from repo config, or clone the base config into a new named environment. Invoke when the user says "create a sandbox", "spin up a dev environment", "create an environment from config", "provision a feature environment", or "set up a dev env".
summary: Create a new git branch, push it, and let the GitHub Actions workflow provision a matching PingOne sandbox environment from ping-config/.
---

# Ping Create Sandbox

This skill creates a developer sandbox in PingOne by pushing a new git branch. The GitHub Actions workflow `.github/workflows/create-sandbox.yml` triggers automatically on `feature/**`, `dev/**`, and `sandbox/**` branches, creates the environment, applies all resources from `ping-config/`, and prints the console URL in the run log.

This is step 1 of the SDLC workflow: **create → develop → extract → promote**.

## When to invoke

- Developer wants to start building a new feature and needs an isolated environment
- User says "create a sandbox", "spin up a dev env", "provision a feature environment"
- Starting work on a new branch before making changes in PingOne

## Prerequisites

- GitHub CLI authenticated (`gh auth status`)
- Working tree is clean (or at least `ping-config/` is committed)

## Workflow

### Step 1 — Determine the branch name

If no name was provided, ask:

> What is this sandbox for? The branch name becomes the environment name. (e.g. `feature/mfa-upgrade`, `dev/jane`)

Branch must start with `feature/`, `dev/`, or `sandbox/` — the workflow only triggers on those prefixes.

### Step 2 — Create and push the branch

```bash
git checkout -b <branch-name>
git push -u origin <branch-name>
```

### Step 3 — Watch the GitHub Actions run

Wait for the workflow to appear (it may take a few seconds to register), then watch it:

```bash
gh run watch --repo "$(gh repo view --json nameWithOwner -q .nameWithOwner)"
```

If `gh run watch` returns before the run is complete, poll with:

```bash
gh run list --workflow=create-sandbox.yml --branch <branch-name> --limit 1
```

### Step 4 — Extract the console URL from the run log

Once the run completes successfully, grep the console URL out of the "Print sandbox details" step log:

```bash
RUN_ID=$(gh run list --workflow=create-sandbox.yml --branch <branch-name> --limit 1 --json databaseId -q '.[0].databaseId')
gh run view "$RUN_ID" --log | grep 'SANDBOX_CONSOLE_URL'
```

The output will contain a line like:

```
SANDBOX_CONSOLE_URL=https://console.pingone.com/?env=693db5e7-3432-4662-8d1a-597c20543d27
```

### Step 5 — Report to the user

Show the user:
- Branch name
- Environment name (same as branch with `/` replaced by `-`)
- Console URL (clickable link)

Remind them: make changes in the PingOne admin console, then run `/ping-extract-changes` to capture them back into the branch.

## Rules

- Branch name must use one of the trigger prefixes: `feature/`, `dev/`, `sandbox/`
- Never run `create-sandbox.sh` locally — provisioning always goes through the GitHub Actions workflow
- If the workflow run fails, show the user the failed step log output from `gh run view --log`
- Do not push to `main` — sandbox branches only

## Example prompt to give the agent

> Create a sandbox for the feature I'm about to build called `feature/social-login`. Watch the workflow and give me the console link when it's ready.
