---
name: ping-drift-detect
description: Use this skill when the user asks to check for drift, detect config drift, compare live infrastructure to repo config, or sync PingOne state with the ping-config directory. Invoke whenever the user wants to know if their live environment matches what's in the repo.
summary: Detect drift between ping-config/ repo files and live PingOne infrastructure, then offer to remediate.
---

# Ping Config Drift Detection

This skill detects drift between the configuration files in `ping-config/` and the live state of the PingOne environment, then offers to correct any differences.

## When to invoke

- User says "check for drift", "is live in sync", "what's changed", "detect drift", "compare config"
- After a manual change was made in the PingOne admin console
- Before a pipeline run to understand what will change

## Environment setup

Before running drift checks, confirm the environment ID is set:

```bash
# Check what's configured
pingcli config get

# Or use an explicit env var
export ENV_ID="<environment-id>"
```

## Drift detection workflow

### Step 1 — Read repo config

For each file in `ping-config/`, read the desired state:

```bash
cat ping-config/population.json
cat ping-config/password-policy.json
cat ping-config/application-oidc.json
```

### Step 2 — Read live state

Fetch current live state using the matching resource and name:

```bash
# Populations
pingcli pingone populations list \
  --environment-id $ENV_ID \
  --output-format json

# Password policies
pingcli pingone password-policies list \
  --environment-id $ENV_ID \
  --output-format json

# Applications
pingcli pingone applications list \
  --environment-id $ENV_ID \
  --output-format json
```

### Step 3 — Compare

For each resource, match by `name` field. Compare key fields between repo and live:

| Resource | Key fields to compare |
|---|---|
| Population | `name`, `description` |
| Password policy | `name`, `length.min`, `length.max`, `lockout.failureCount`, `history.count` |
| Application | `name`, `enabled`, `grantTypes`, `redirectUris`, `tokenEndpointAuthMethod` |

Report findings as a table:

| Resource | Name | Status | Drift details |
|---|---|---|---|
| population | Demo Users | ✅ In sync | — |
| password-policy | Demo Password Policy | ⚠️ Drift | `length.min`: repo=12, live=8 |
| application | Demo Web App | ✅ In sync | — |

### Step 4 — Offer remediation

For each drifted resource, ask the user:

> `Demo Password Policy` has drifted. Repo has `length.min=12`, live has `length.min=8`. Apply repo config to fix? (y/n)

If yes, run `apply` to push the repo version to live:

```bash
pingcli pingone password-policies apply \
  --environment-id $ENV_ID \
  --from-file ping-config/password-policy.json
```

## Rules

- Always match resources by `name`, never by ID (IDs differ between environments)
- Never delete resources not in the repo — only update
- If a resource in the repo does not exist live, offer to create it
- If a resource exists live but not in the repo, report it as "untracked" — do not touch it
- Show a summary of all drift before asking for any remediation
- Ask once per drifted resource — do not batch apply without confirmation

## Example prompt to give the agent

> Check for drift between the ping-config/ directory and the live pingcli-test environment (ID: 0e837154-0327-4add-9a33-9acf60c0ca10). Show me what's out of sync and ask me before fixing anything.
