# pingcli-demo — Project Guidelines for Claude

## Config-as-code first

**All PingOne resource configuration must be driven from `ping-config/`.**

When building any workflow, skill, script, or automation that creates or updates PingOne resources:

- Read desired state from `ping-config/` files — never hardcode resource properties inline
- Add a new file to `ping-config/` for any resource type not yet tracked there
- Use `pingcli ... apply --from-file ping-config/<resource>.json` to provision — not inline JSON or API calls that bypass the file
- The `ping-config/` files are the single source of truth; live state is a reflection of them, not the other way around

This applies to: environments, populations, password policies, applications, and any other resource type added in future.

## Repository structure

```
ping-config/       # Golden configuration — one file per resource type
.github/workflows/ # CI/CD pipelines — sandbox creation, deployment
.claude/skills/    # Agent skills for SDLC operations
```

## SDLC workflow

1. **Create** — push a `feature/`, `dev/`, or `sandbox/` branch → GitHub Actions provisions a sandbox from `ping-config/`
2. **Develop** — make changes in the PingOne admin console
3. **Extract** — use `/ping-extract-changes` to pull live state back into `ping-config/`
4. **Promote** — merge to `main` → deploy workflow applies `ping-config/` to production environments
