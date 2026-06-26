#!/usr/bin/env bash
# Ping CLI Demo Commands
# Set ENV_ID before running
ENV_ID="0e837154-0327-4add-9a33-9acf60c0ca10"

# ── SETUP ─────────────────────────────────────────────────────────────────────

pingcli --help
pingcli --version


# ── SETUP & PROFILES ─────────────────────────────────────────────────────────

pingcli init
pingcli config get
pingcli config profiles


# ── AUTH ──────────────────────────────────────────────────────────────────────

pingcli auth login                               # device code → browser → OS keychain
pingcli auth login --storage-type file_system    # tokens on disk (agent-friendly)
pingcli auth login --storage-type none           # in-memory only (ephemeral containers)
pingcli auth status


# ── CI/CD ─────────────────────────────────────────────────────────────────────

# Env vars replace config file in pipelines
env | grep PINGCLI_

# Machine-readable output
pingcli pingone environments list -O json
pingcli pingone applications list --environment-id $ENV_ID -O json
pingcli pingone applications list --environment-id $ENV_ID -O json --query 'data[?enabled].{name:name, id:id}'
pingcli pingone environments list -O ndjson

# Idempotent apply
pingcli pingone populations apply --environment-id $ENV_ID --from-file ping-config/population.json

# Exit codes
pingcli -D pingone applications list --environment-id $ENV_ID
echo "Exit code: $?"

# Stdin piping
echo '{"name": "Demo Population"}' | pingcli pingone populations create --environment-id $ENV_ID --from-file -


# ── HUMAN / INTERACTIVE ───────────────────────────────────────────────────────

# Browse
pingcli pingone environments list
pingcli pingone applications list --environment-id $ENV_ID
pingcli pingone populations list --environment-id $ENV_ID

# Get single resource
pingcli pingone applications get --environment-id $ENV_ID --application-id 71d6a8bc-8878-4642-8d38-ed72d46fdc02

# Template → create workflow
pingcli pingone populations template
pingcli pingone populations template | jq '{name: "Demo Population"}'
echo '{"name": "Demo Population"}' | pingcli pingone populations create --environment-id $ENV_ID --from-file -
pingcli pingone populations list --environment-id $ENV_ID

# Cleanup
pingcli pingone populations delete --environment-id $ENV_ID --population-id <id>

# Raw API escape hatch (env ID in path, no --environment-id flag)
pingcli pingone api -O json "environments/$ENV_ID/applications"
pingcli pingone api -m POST --data-raw '{"name":"test"}' "environments/$ENV_ID/populations"
pingcli pingfederate api serverSettings


# ── AGENTIC ───────────────────────────────────────────────────────────────────

# Agent skills
pingcli agent-skills list
pingcli agent-skills install pingcli-usage

# Pre-auth pattern (human does this once before handing off to agent)
pingcli auth login --storage-type file_system
# Agent then runs normally using stored token — no credentials in the prompt
pingcli pingone environments list -O json