# Ping CLI — CI/CD Demo

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
    ping-deploy.yml       # the pipeline
ping-config/
  population.json         # user population
  password-policy.json    # password policy
  application-oidc.json   # OIDC web application
demo/
  demo-guide.md           # 20-minute demo script
  demo-commands.sh        # all commands in order
.claude/
  skills/
    pingcli-usage/        # Ping CLI command reference skill
    ping-drift-detect/    # drift detection workflow skill
```

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

## Required GitHub Actions secrets

| Secret | Description |
|---|---|
| `PINGCLI_PINGONE_CLIENT_CREDENTIALS_CLIENT_ID` | Client credentials app client ID |
| `PINGCLI_PINGONE_CLIENT_CREDENTIALS_CLIENT_SECRET` | Client credentials app client secret |
| `PINGCLI_PINGONE_ENVIRONMENT_ID` | Target PingOne environment ID |
| `PINGCLI_PINGONE_ROOT_DOMAIN` | PingOne root domain (e.g. `pingone.com`) |

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
