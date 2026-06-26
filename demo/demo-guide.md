# Ping CLI Demo Guide (20 min)

## Pre-Demo Setup Checklist

1. **Auth pre-done** — run `pingcli auth login` now and complete the browser step. Confirm with `pingcli auth status`.
2. **Two ENV_IDs exported** — one per segment:
   ```bash
   export ENV_ID="0e837154-0327-4add-9a33-9acf60c0ca10"          # pingcli-test — human demo
   export CICD_ENV_ID="693db5e7-3432-4662-8d1a-597c20543d27"     # pingcli-demo-env — CI/CD + drift demo
   ```
3. **CI/CD env vars pre-set** in a second terminal tab ready to switch to:
   ```bash
   export PINGCLI_SERVICE_PINGONE_AUTHENTICATION_CLIENTCREDENTIALS_CLIENTID=...
   export PINGCLI_SERVICE_PINGONE_AUTHENTICATION_CLIENTCREDENTIALS_CLIENTSECRET=...
   export PINGCLI_SERVICE_PINGONE_ENDPOINT_ENVIRONMENTID=693db5e7-3432-4662-8d1a-597c20543d27
   ```
4. **pingcli-demo repo** checked out at `~/projects/config-automation/pingcli-demo` — GitHub Actions green from last run (targets `pingcli-demo-env`).
5. **Live change seeded in `pingcli-demo-env`** — live `Demo Users` description is `"Population of users for testing against"`, repo has `"Default population for demo environment users"`. Verify:
   ```bash
   pingcli pingone populations list --environment-id $CICD_ENV_ID -O json
   ```
6. **Agent skills installed** in the demo repo:
   ```bash
   cd ~/projects/config-automation/pingcli-demo
   pingcli agent-skills install pingcli-usage
   # ping-extract-changes already in .claude/skills/
   ```
7. **Claude Code open** in `~/projects/config-automation/pingcli-demo` — auth already done.
8. **Font size** ≥ 18pt. Terminal and editor side-by-side on one screen.

---

## Segment 1 — What is Ping CLI (2 min)

**Key message:** One tool, three audiences — pipeline, human, agent.

```bash
pingcli --help
```

Point out: every Ping product under one roof. Consistent flags everywhere (`-O`, `--query`, `-D`, `--no-color`). Profiles for multi-env.

---

## Segment 2 — Setup & Profiles (2 min)

**Key message:** Config resolves flag → env var → file → default. One CLI, multiple environments.

```bash
pingcli config get           # stored config, secrets masked
pingcli config profiles      # show profile management
```

Point out: `--profile staging` on any single command — no config swap needed.

---

## Segment 3 — Auth (2 min)

**Key message:** Three storage modes map to three audiences.

```bash
pingcli auth login                              # device code → browser → OS keychain
pingcli auth login --storage-type file_system   # tokens on disk — portable, scriptable
pingcli auth login --storage-type none          # in-memory only — ephemeral containers
pingcli auth status
```

**Plant the agentic seed here:** Device code is how you pre-authorize before handing off to an agent. Human completes the browser step once; agent inherits the stored token and operates on the user's behalf — no credentials in the prompt.

---

## Segment 4 — CI/CD (5 min)

**Key message:** Zero interaction, env vars, idempotent `apply`, machine-readable output, exit codes.

### 4a — Env var config (switch to second terminal tab)
```bash
env | grep PINGCLI_
pingcli pingone environments list    # works purely from env vars, no config file
```

### 4b — Machine-readable output + JMESPath
```bash
pingcli pingone applications list --environment-id $ENV_ID -O json
pingcli pingone applications list --environment-id $ENV_ID -O json \
  --query 'data[?enabled].{name:name, id:id}'
pingcli pingone environments list -O ndjson    # one object per line — jq-friendly
```

### 4c — Idempotent apply
```bash
# apply = create if missing, update if exists — safe to run on every push
pingcli pingone populations apply \
  --environment-id $ENV_ID \
  --from-file ping-config/population.json
```

### 4d — Exit codes for pipeline control
```bash
pingcli -D pingone applications list --environment-id $ENV_ID
echo "Exit code: $?"    # 0=ok, 1=error, 2=warning
```

### 4e — Show the GitHub Actions workflow
Open `pingcli-demo` repo → Actions tab → last successful run. Walk through the YAML:
- Secrets become env vars — no config file in the runner
- `apply` steps are idempotent — safe to re-run
- Each step logs exit code
- Raw `api` command at the end for anything not yet in the CLI

**Say:** This is the entire pipeline — three steps, no SDK, no custom script.

---

## Segment 5 — Human / Interactive (3 min)

**Key message:** Human-readable output, template-to-create workflow, raw API escape hatch.

### 5a — Browse
```bash
pingcli pingone environments list
pingcli pingone applications list --environment-id $ENV_ID
pingcli pingone populations list --environment-id $ENV_ID
```

### 5b — Get single resource
```bash
pingcli pingone applications get \
  --environment-id $ENV_ID \
  --application-id 71d6a8bc-8878-4642-8d38-ed72d46fdc02
```

### 5c — Template → create (live demo)
```bash
pingcli pingone populations template          # show the full skeleton
pingcli pingone populations template | jq '{name: "Demo Users 2"}'   # minimal

echo '{"name": "Demo Users 2"}' \
  | pingcli pingone populations create --environment-id $ENV_ID --from-file -

pingcli pingone populations list --environment-id $ENV_ID   # confirm it's there

# Cleanup
pingcli pingone populations delete --environment-id $ENV_ID --population-id <id>
```

### 5d — Raw API escape hatch
```bash
# env ID goes in the URI path — no --environment-id flag on api
pingcli pingone api -O json "environments/$ENV_ID/applications"
pingcli pingfederate api serverSettings    # PingFederate pass-through
```

---

## Segment 6 — Agentic (5 min)

**Key message:** Ping CLI is purpose-built for agents — but know the pattern and when to use MCP instead.

### 6a — Agent skills
```bash
pingcli agent-skills list
pingcli agent-skills install pingcli-usage
```

Explain: `agentskills.io` open format. The skill file is a structured reference the agent loads into context — it knows every command, flag, and pattern without hallucinating.

Show the `ping-extract-changes` skill in `.claude/skills/ping-extract-changes/SKILL.md` — a custom skill that teaches the agent a specific workflow.

### 6b — Pre-auth pattern (explain before the live demo)
```bash
# Step 1 — human does this ONCE
pingcli auth login --storage-type file_system
# Step 2 — agent uses stored token, never sees credentials
pingcli pingone environments list -O json
```

**Say:** Device code is interactive — can't run inside an agent. Client credentials work unattended but expose a secret. File-system token is the bridge: human authenticates once, agent operates on their behalf.

### 6c — Live extract-changes demo (Claude Code)

Switch to Claude Code (open in `pingcli-demo` dir). Give it this prompt:

> *Extract any changes from the live pingcli-demo-env environment back into the ping-config/ directory. Show me what's different and ask before updating each file.*

Expected flow:
1. Agent runs `pingcli pingone populations list --environment-id ... -O json`
2. Agent reads `ping-config/population.json` — sees repo description is `"Default population for demo environment users"`
3. Agent finds live description is `"Population of users for testing against"` — reports the difference
4. Agent asks: *"Update population.json to match live?"*
5. Say yes — agent updates the file, shows `git diff`, offers to commit

**Key point:** The agent wrote zero code. It used Ping CLI as the read layer, the skill as its knowledge, and its own reasoning to compare and capture the live state back into version control.

### 6d — When Ping CLI vs MCP

| Use Ping CLI when... | Use MCP when... |
|---|---|
| Agent needs to **do** something (create, delete, apply) | Agent needs to **know** something (search docs, reason over state) |
| You want an **audit trail** (commands log) | You want **fluid conversation** with Ping APIs |
| Running in a **pipeline or container** | Running in an **interactive assistant session** |
| You want **exit codes and structured output** | High-frequency read queries with low latency |

**Say:** MCP and Ping CLI are complementary. MCP gives agents rich read access for reasoning; Ping CLI gives agents precise write operations with pipeline-grade reliability.

### 6e — Prompt engineering tips (quick bullets)
- Always specify output format: `"use -O json for all commands"`
- Reference the installed skill: `"use the ping-extract-changes skill"`
- Pin the environment: `"use --profile prod"` — prevents the agent from guessing
- Pre-auth before handoff: `"tokens are stored at ~/.pingcli/credentials"`

---

## Wrap (1 min)

```bash
pingcli feedback
```

Three audiences, one tool:
- **CI/CD:** env vars + `apply` + exit codes = drop-in pipeline step, no SDK
- **Human:** `list`/`get`/template/`api` = fast browsing and troubleshooting
- **Agent:** pre-auth + skills + prompt discipline = safe, auditable agentic automation

---

## Timing

| Segment | Time |
|---|---|
| What is Ping CLI | 2 min |
| Setup & profiles | 2 min |
| Auth | 2 min |
| CI/CD | 5 min |
| Human / interactive | 3 min |
| Agentic | 5 min |
| Wrap | 1 min |
| **Total** | **20 min** |

---

## Reference

- Demo repo: `~/projects/config-automation/pingcli-demo`
- Human demo env: `pingcli-test` — ID `0e837154-0327-4add-9a33-9acf60c0ca10`
- CI/CD + drift demo env: `pingcli-demo-env` — ID `693db5e7-3432-4662-8d1a-597c20543d27`
- All verified commands: `demo/demo-commands.sh`
- Extract-changes skill: `.claude/skills/ping-extract-changes/SKILL.md`
