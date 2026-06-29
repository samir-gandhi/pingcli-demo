# Plan: `ping-export-config` skill + repo restructure

## Goal

Add a `/ping-export-config` skill that captures a live PingOne environment into `ping-config/` as config-as-code, ready to be promoted to higher environments. Alongside this, restructure the config directory and update both GitHub Actions workflows to support multiple resources per type and environment-specific overlays.

---

## 1. Config directory restructure

### Current layout (flat, one file per type)

```
ping-config/
  environment.json
  population.json
  password-policy.json
  application-oidc.json
  sandbox/
    group-role-assignment.json
```

### New layout (subdirectory per type, overlay per environment)

```
ping-config/
  environment.json               # singleton — unchanged
  populations/
    demo-users.json
  password-policies/
    demo.json
  applications/
    demo-web-app.json
  overrides/
    sandbox/
      applications/
        demo-web-app.json        # only fields that differ from base
    staging/
      applications/
        demo-web-app.json
    production/
      applications/
        demo-web-app.json
  sandbox/
    group-role-assignment.json   # unchanged — not exported, not overridden
```

### Migration: existing files → new locations

| Old | New |
|-----|-----|
| `ping-config/population.json` | `ping-config/populations/demo-users.json` |
| `ping-config/password-policy.json` | `ping-config/password-policies/demo.json` |
| `ping-config/application-oidc.json` | `ping-config/applications/demo-web-app.json` |

The base files strip env-specific fields. Those go into `overrides/`.

### Fields routed to overlays (not stored in base config)

| Type | Fields → overlay |
|------|-----------------|
| `applications` | `redirectUris`, `postLogoutRedirectUris`, `initiateLoginUri`, `targetLinkUri` |
| `environments` | `name` (already injected at runtime via jq — no change needed) |

All other fields remain in the base file. Base files contain no environment-specific values — they must be valid across all environments.

---

## 2. Apply loop pattern (used by both workflows)

Replace all single-file `apply` steps with a single ordered loop. The `RESOURCE_TYPES` array enforces dependency order while the inner glob picks up all files dynamically — no workflow edit needed when adding a new resource instance, only when adding a new resource type (which must be inserted at the correct dependency position).

```bash
RESOURCE_TYPES=(populations password-policies identity-providers notification-policies sign-on-policies groups applications)

for type in "${RESOURCE_TYPES[@]}"; do
  [ -d "ping-config/$type" ] || continue   # skip if folder absent
  for f in ping-config/$type/*.json; do
    [ -f "$f" ] || continue                # skip if glob finds nothing
    fname=$(basename "$f")
    override="ping-config/overrides/${ENV_NAME}/$type/$fname"
    if [ -f "$override" ]; then
      jq -s '.[0] * .[1]' "$f" "$override" > /tmp/merged.json
      INPUT="/tmp/merged.json"
    else
      INPUT="$f"
    fi
    pingcli --detailed-exitcode pingone "$type" apply \
      --environment-id "$ENV_ID" \
      --from-file "$INPUT" \
      --no-color
  done
done
```

`jq -s '.[0] * .[1]'` does a shallow merge — overlay fields overwrite base fields. For nested objects (e.g. `oidc.redirectUris`), the overlay must repeat the full parent key path.

---

## 3. Changes to `create-sandbox.yml`

- Derive `ENV_NAME` from branch name (same slug logic already used for `NAME`)
- Replace `Apply population`, `Apply password policy`, `Apply OIDC application` steps with loop steps per type
- Add `ENV_NAME` as a step output from the derive-name step so loop steps can reference it
- Apply order (dependency): populations → password-policies → applications

---

## 4. Changes to `ping-deploy.yml`

- Add `ENV_NAME` from the `environment` workflow input (already `staging` / `production`)
- Replace the three single-file apply steps with loop steps per type
- Same apply order as sandbox workflow
- Keep the existing drift-check and post-deploy validation steps unchanged

---

## 5. New skill: `ping-export-config`

### File: `.claude/skills/ping-export-config/SKILL.md`

**Trigger:** user says "export config", "capture live state to config-as-code", "export environment to repo", etc.

**Purpose:** Export a live PingOne environment into `ping-config/` subdirectories, separating base config from env-specific overrides. Does not replace `ping-extract-changes` — that skill updates *existing* tracked files; this skill does the initial capture of a new resource type or does a full export.

**Inputs:**
- `ENV_ID` — environment to export from (from `$ENV_ID`, or prompts user)
- `ENV_NAME` — logical name for this environment's overlay (e.g. `sandbox`, `staging`, `production`)

**Workflow:**

1. Confirm `ENV_ID` and `ENV_NAME` are set
2. For each resource type in dependency order:
   - Run `pingcli pingone <type> list --environment-id $ENV_ID --output-format json --no-color`
   - For each item in the response:
     - Slug the `name` field: lowercase, spaces→hyphens, strip special chars
     - Strip server-managed fields: `id`, `_links`, `createdAt`, `updatedAt`, `updatedAt`, `environment`, `_embedded`
     - Split fields: env-specific fields → `overrides/<ENV_NAME>/<type>/<slug>.json`; remaining → `ping-config/<type>/<slug>.json`
     - If `ping-config/<type>/<slug>.json` already exists: compare and report changed/unchanged; if `ENV_NAME` overlay exists: same
     - If new: write and report "added"
     - Warn if two resources slug to the same filename — do not overwrite, ask user to resolve
3. Show `git diff ping-config/` summary
4. Ask: "Commit exported config? (y/n)"

**Resource types to export (in order):**

| Order | Type | CLI subcommand |
|-------|------|----------------|
| 1 | populations | `pingcli pingone populations list` |
| 2 | password-policies | `pingcli pingone password-policies list` |
| 3 | identity-providers | `pingcli pingone identity-providers list` |
| 4 | notification-policies | `pingcli pingone notification-policies list` |
| 5 | sign-on-policies | `pingcli pingone sign-on-policies list` |
| 6 | groups | `pingcli pingone groups list` |
| 7 | applications | `pingcli pingone applications list` |

**Out of scope for v1:** DaVinci flows/variables, MFA device policies, schema attributes, users, role assignments, gateway credentials.

**Rules:**
- Never overwrite a base file with env-specific values — those always go to the overlay
- Never write `id` fields into base config — `apply` matches by `name`
- If a type subdirectory doesn't exist yet, create it
- Match existing resources by `name` field — report untracked resources (exist live, no file in repo) separately from known resources
- Do not delete existing files for resources no longer live — report as "missing live" and let the user decide

---

## 6. CLAUDE.md updates

Update the repository structure section to reflect:
- Subdirectory layout under `ping-config/`
- `ping-config/overrides/` purpose and structure
- Note that `apply` loops now iterate all files in each subdirectory

---

## 7. Implementation order

1. Migrate existing `ping-config/` files to new subdirectory layout
2. Create `overrides/sandbox/`, `overrides/staging/`, `overrides/production/` with the redirect URI fields extracted from `application-oidc.json`
3. Update `create-sandbox.yml` — replace single apply steps with loops
4. Update `ping-deploy.yml` — same
5. Write `.claude/skills/ping-export-config/SKILL.md`
6. Update `CLAUDE.md`
7. Update `settings.json` skill trigger registration (if needed)

---

## Open questions

- **`jq` shallow vs deep merge**: `.[0] * .[1]` merges shallow — nested objects like `oidc: { redirectUris: [...] }` require the overlay to repeat the full path. Is this acceptable, or do we need `--argjson` recursive merge?
- **sign-on-policy actions**: sop-actions are child resources of sign-on-policies and require a parent ID. Export should capture them as sub-files or embed them. Defer to v2?
- **`ping-extract-changes` alignment**: that skill currently only updates existing files, matches on flat `ping-config/` paths, and doesn't create new ones. After this restructure it needs updating to: look in subdirectories, write new per-resource files, and respect the overlay split. **Defer — update in a follow-on task after this plan is complete.**
