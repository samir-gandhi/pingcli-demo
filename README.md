# Ping CLI Demo

This repository demonstrates how to use [Ping CLI](https://github.com/pingidentity/pingcli)
to deploy PingOne configuration as code — covering CI/CD pipelines, interactive human use, and agentic automation.

No custom scripts. No SDK setup. Just Ping CLI, environment variables, and JSON config files.

## Demo materials

See [`demo/`](demo/) for the full presentation guide and command reference:

- [`demo/demo-guide.md`](demo/demo-guide.md) — 20-minute demo script with talking points
- [`demo/demo-commands.sh`](demo/demo-commands.sh) — all verified commands in order

## How it works

Every push to `main` that touches `ping-config/**` triggers a workflow that:

1. Installs Ping CLI in the runner
2. Authenticates to PingOne using client credentials from GitHub secrets
3. Reads current state (drift check)
4. Applies each config resource in dependency order — idempotent, safe to re-run
5. Validates what was deployed

## Repository layout

```
.github/
  workflows/
    ping-deploy.yml             # deploys ping-config/ to production environments on push to main
    create-sandbox.yml          # provisions a sandbox environment when a feature branch is pushed
ping-config/
  environment.json              # environment shape (region, license, bill of materials)
  population.json               # user population
  password-policy.json          # password policy
  application-oidc.json         # OIDC web application
  sandbox/
    group-role-assignment.json  # role assignment applied only to sandbox environments
demo/
  demo-guide.md                 # 20-minute demo script
  demo-commands.sh              # all commands in order
.claude/
  skills/
    pingcli-usage/              # Ping CLI command reference skill
    ping-drift-detect/          # drift detection skill
    ping-extract-changes/       # extract live changes back to repo skill
    ping-create-sandbox/        # provision a new sandbox environment skill
```

## PingOne environment setup

This repo depends on a specific structure in PingOne that must be in place before pipelines can run.

### Administrators environment

A long-lived PingOne environment that acts as the org-level management plane. It holds:

- **Worker app for Ping CLI** — used by developers running `pingcli` locally. Configure a Ping CLI profile pointing at this app. Developers log in interactively or via device code to get a token scoped to their own permissions.
- **Worker app for GitHub Actions (`automation-admin`)** — a client credentials app used by CI/CD pipelines. Its credentials are stored as GitHub Actions secrets. It has the permissions needed to create and configure sandbox environments, and to assign roles to groups.
- **`IAM Team` group** — the group that developer users belong to. When a sandbox is created, the pipeline assigns this group the **Environment Admin** role scoped only to the new sandbox — giving every member of the group access to that environment without granting them access to anything else.

### How a developer gets access to their sandbox

1. Developer pushes a `feature/`, `dev/`, or `sandbox/` branch.
2. The `create-sandbox.yml` workflow runs automatically using the `automation-admin` worker app credentials.
3. The workflow creates the PingOne environment, provisions all resources from `ping-config/`, then assigns the **Environment Admin** role to the `IAM Team` group scoped to the new sandbox.
4. Any user in `IAM Team` can now log in to the PingOne console and switch to the sandbox environment.

### Role scoping

The Environment Admin role is granted **per sandbox** — not globally. A developer can administer their own sandbox but cannot affect other environments. When the sandbox is no longer needed, deleting it automatically removes the role assignment.

## Key concepts

### `apply` = idempotent upsert

```bash
pingcli pingone applications apply --from-file ping-config/application-oidc.json
```

Creates the resource on first run. Updates it on subsequent runs. No state file required.

### Config from environment variables

```yaml
env:
  PINGCLI_SERVICE_PINGONE_AUTHENTICATION_CLIENTCREDENTIALS_CLIENTID: ${{ secrets.PINGONE_CLIENT_ID }}
  PINGCLI_SERVICE_PINGONE_ENVIRONMENT_ID: ${{ secrets.PINGONE_ENVIRONMENT_ID }}
```

Ping CLI reads `PINGCLI_*` env vars automatically. Nothing to commit.

### Structured output for validation

```bash
pingcli pingone applications list \
  --output-format json \
  --query 'data[?enabled].{name:name, id:id}'
```

### Raw API for anything not yet in the CLI

```bash
pingcli pingone api --http-method GET "licenses"
```

Authentication and environment ID are injected automatically.

## Required GitHub Actions secrets and variables

### Secrets

| Secret | Description |
|---|---|
| `PINGCLI_PINGONE_CLIENT_CREDENTIALS_CLIENT_ID` | `automation-admin` worker app client ID |
| `PINGCLI_PINGONE_CLIENT_CREDENTIALS_CLIENT_SECRET` | `automation-admin` worker app client secret |
| `PINGCLI_PINGONE_ROOT_DOMAIN` | PingOne root domain (e.g. `pingone.ca`) |

### Variables

| Variable | Description |
|---|---|
| `PINGONE_ADMINISTRATORS_ENV_ID` | ID of the Administrators environment — used to assign group roles and construct console login URLs |

## Running locally

```bash
export PINGCLI_SERVICE_PINGONE_AUTHENTICATION_CLIENTCREDENTIALS_CLIENTID=<id>
export PINGCLI_SERVICE_PINGONE_AUTHENTICATION_CLIENTCREDENTIALS_CLIENTSECRET=<secret>
export PINGCLI_SERVICE_PINGONE_ENDPOINT_ENVIRONMENTID=<env-id>
export PINGCLI_SERVICE_PINGONE_AUTHENTICATION_GRANTTYPE=client_credentials

# Then run any step from the pipeline directly
pingcli pingone applications apply \
  --environment-id <env-id> \
  --from-file ping-config/application-oidc.json
```

## Multi-environment

Use GitHub Actions **environments** (staging, production) to scope secrets.
The same workflow file targets different PingOne environments with no code changes.

```bash
# Locally, use profiles
pingcli --profile production pingone applications list
```
