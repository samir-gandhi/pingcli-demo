---
name: ping-extract-changes
description: Use this skill when the user wants to capture live infrastructure changes back into the repo, sync config files from live state, extract what changed in PingOne to local files, or reverse-sync from live to code. Invoke when the user says "extract changes", "pull from live", "update my config files", "capture live state", or "sync to repo".
summary: Compare live PingOne state against ping-config/ and update local config files to match, ready for git commit.
---

# Ping Extract Changes

This skill captures changes made directly in the PingOne admin console (or by other means) back into the local `ping-config/` directory so they can be committed to version control.

This is the reverse of deployment — instead of pushing repo → live, it pulls live → repo.

## When to invoke

- A change was made in the PingOne admin console and needs to be captured in code
- Onboarding an existing environment into config-as-code for the first time
- Auditing what has drifted from repo and deciding to accept the live state as truth

## Environment setup

```bash
# Confirm environment ID
echo $CICD_ENV_ID   # should be set — if not, export it first
pingcli pingone environments list --no-color
```

## Extraction workflow

### Step 1 — Read live state for each resource type

```bash
# Populations
pingcli pingone populations list \
  --environment-id $CICD_ENV_ID \
  --output-format json

# Password policies
pingcli pingone password-policies list \
  --environment-id $CICD_ENV_ID \
  --output-format json

# Applications
pingcli pingone applications list \
  --environment-id $CICD_ENV_ID \
  --output-format json
```

### Step 2 — Compare each resource to its ping-config/ file

For each resource, match by `name`. Compare live fields against the local file.

Present findings as a table:

| Resource | Name | Status | What changed live |
|---|---|---|---|
| population | Demo Users | ⚠️ Live differs | `description` changed |
| password-policy | Demo Password Policy | ✅ Matches repo | — |
| application | Demo Web App | ⚠️ Live differs | `redirectUris` added entry |

### Step 3 — For each diverged resource, ask the user

> `Demo Users` has changed in the live environment:
> - `description`: repo = `"Default population for demo environment users"`, live = `"Manually edited in admin console"`
>
> Update `ping-config/population.json` to match live? (y/n)

### Step 4 — If yes, update the local file

Read the current file, apply only the changed fields, write it back. Preserve all other fields in the file as-is.

Example for a population description change:

```bash
# Read live resource via raw API for full field set
pingcli pingone api \
  --http-method GET \
  --output-format json \
  "environments/$CICD_ENV_ID/populations/<id>"
```

Then update `ping-config/population.json` with the live values.

### Step 5 — Show a summary and git diff

After all updates, show what changed:

```bash
git diff ping-config/
```

Then prompt:

> The following files were updated to match live state:
> - `ping-config/population.json`
>
> Commit these changes to capture them in version control? (y/n)

If yes:

```bash
git add ping-config/
git commit -m "chore: extract live changes from pingcli-demo-env"
```

## Rules

- Only update files that already exist in `ping-config/` — do not create new files for resources not already tracked
- Never delete fields from a local file — only update values for fields that exist in both repo and live
- If a resource exists live but has no matching file in `ping-config/`, report it as "untracked" and ask if the user wants to add it
- Always show a diff before committing — never commit silently
- Match resources by `name` field, never by ID

## Example prompt to give the agent

> Extract any changes from the live pingcli-demo-env environment (ID: `693db5e7-3432-4662-8d1a-597c20543d27`) back into the ping-config/ directory. Show me what's different and ask before updating each file.
