---
name: ping-export-config
description: Use this skill when the user wants to export a live PingOne environment to config-as-code, capture an environment for the first time, bootstrap the ping-config/ directory from a live environment, or do a full export of a PingOne environment to repo. Invoke when the user says "export config", "export environment to repo", "bootstrap config from live", "capture live state to config-as-code", or "export environment".
summary: Export a live PingOne environment into ping-config/ subdirectories, separating base config from environment-specific overrides.
---

# Ping Export Config

This skill exports a live PingOne environment into `ping-config/`, writing one file per resource instance and splitting environment-specific fields into `ping-config/overrides/<ENV_NAME>/`.

This is distinct from `/ping-extract-changes`, which updates existing tracked files. Use this skill for initial capture of a new environment or resource type.

## When to invoke

- User says "export config", "export environment to repo", "bootstrap config-as-code from live"
- Setting up config-as-code for the first time against an existing environment
- Adding a new resource type to the repo that already exists live

## Inputs

Two values are required before starting:

```bash
# Environment to export from
echo $ENV_ID        # should be set, or ask user to provide

# Logical overlay name for this environment (sandbox / staging / production)
echo $ENV_NAME      # e.g. "staging"
```

If either is unset, ask the user before proceeding.

## Export workflow

### Step 1 — Confirm inputs

```bash
echo "Exporting ENV_ID=$ENV_ID as ENV_NAME=$ENV_NAME"
```

### Step 2 — Export each resource type in dependency order

For each type, list live resources and write config files:

```bash
RESOURCE_TYPES=(populations password-policies identity-providers notification-policies sign-on-policies groups applications)

for type in "${RESOURCE_TYPES[@]}"; do
  pingcli pingone "$type" list \
    --environment-id "$ENV_ID" \
    --output-format json \
    --no-color
done
```

For each item returned:

1. **Slug the name**: lowercase, spaces→hyphens, strip non-alphanumeric except hyphens
   - `"Demo Web App"` → `demo-web-app`
   - Warn and skip (asking user to resolve) if two resources produce the same slug

2. **Strip server-managed fields** — never write these to base config:
   - `id`, `_links`, `createdAt`, `updatedAt`, `environment`, `_embedded`, `type` (where system-assigned)

3. **Split env-specific fields to overlay**:

   | Resource type | Fields → overlay |
   |---------------|-----------------|
   | `applications` | `oidc.redirectUris`, `oidc.postLogoutRedirectUris`, `oidc.initiateLoginUri`, `oidc.targetLinkUri` |

4. **Write base file**: `ping-config/<type>/<slug>.json`
   - If file exists and content is unchanged: report "unchanged"
   - If file exists and content differs: show diff, ask "Update? (y/n)"
   - If new: write and report "added"

5. **Write overlay file**: `ping-config/overrides/<ENV_NAME>/<type>/<slug>.json`
   - Only write if there are env-specific fields to record
   - Same changed/unchanged/new reporting as base file

### Step 3 — Show summary and diff

```bash
git diff ping-config/
git status ping-config/
```

Report a table:

| Type | Resource | Base | Overlay |
|------|----------|------|---------|
| populations | Demo Users | added | — |
| applications | Demo Web App | added | added |

### Step 4 — Offer to commit

> Export complete. Commit these files to capture them in version control? (y/n)

If yes:

```bash
git add ping-config/
git commit -m "feat: export <ENV_NAME> environment config-as-code"
```

## Rules

- Never write `id` fields to base config — `apply` matches resources by `name`
- Never put env-specific values in base files — they must be valid across all environments
- Never overwrite an existing base file without user confirmation
- If `ping-config/<type>/` directory doesn't exist, create it
- Resources that exist live but have no file: report as "untracked" — offer to export
- Files that exist in repo but have no live counterpart: report as "missing live" — do not delete
- Match existing files to live resources by `name` field only, never by ID
- Skip known system-default resource names (see list below) — report them as "system-managed, skipped" rather than untracked

## Known system-managed resource names (skip on export)

These are auto-provisioned by PingOne and should not be tracked in config-as-code:

```
# populations
Default

# password-policies
Standard
Basic
Passphrase

# languages
Chinese, Czech, Dutch, English, French, French (Canada), German, Hungarian,
Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Thai, Turkish

# sign-on-policies
Single_Factor
Multi_Factor

# notification-policies
Default Notification Policy

# resources
PingOne API
openid

# applications
PingOne Application Portal
PingOne Self-Service - MyAccount
PingOne DaVinci Connection
PingOne Helix Connection
Getting Started Application
```

If a live resource name matches this list exactly, skip it silently (report count at end). If it does NOT match, treat as untracked and offer to export.

## Resource types exported (v1 scope)

| Order | Type | Depends on | Notes |
|-------|------|------------|-------|
| 1 | `populations` | environment | |
| 2 | `password-policies` | environment | |
| 3 | `languages` | environment | Skip if all `enabled: false` and default |
| 4 | `agreements` | environment | |
| 5 | `identity-providers` | environment | |
| 6 | `notification-policies` | environment | |
| 7 | `notification-templates` | environment | Skip system defaults with no custom content |
| 8 | `resources` | environment | Skip `PingOne API` and `openid` — system-managed |
| 9 | `sign-on-policies` | environment | |
| 10 | `groups` | populations | |
| 11 | `gateways` | environment | |
| 12 | `webhooks` | environment | |
| 13 | `custom-admin-roles` | environment | |
| 14 | `applications` | populations, sign-on-policies | |

Out of scope for v1: DaVinci flows/variables, MFA device policies, schema attributes, users, role assignments, gateway credentials, sop-actions (child resources).

## Example prompt to give the agent

> Export the live environment with ID `693db5e7-3432-4662-8d1a-597c20543d27` to ping-config/ as the `staging` overlay. Show me what's new or changed and ask before writing anything.
