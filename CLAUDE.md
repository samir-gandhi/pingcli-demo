# pingcli-demo — Project Guidelines for Claude

## Config-as-code first

**All PingOne resource configuration must be driven from `ping-config/`.**

When building any workflow, skill, script, or automation that creates or updates PingOne resources:

- Read desired state from `ping-config/` files — never hardcode resource properties inline
- Add a new file to `ping-config/` for any resource type not yet tracked there
- Use `pingcli ... apply --from-file ping-config/<type>/<resource>.json` to provision — not inline JSON or API calls that bypass the file
- The `ping-config/` files are the single source of truth; live state is a reflection of them, not the other way around

This applies to: environments, populations, password policies, applications, and any other resource type added in future.

## Repository structure

```
ping-config/                          # Golden configuration — one file per resource instance
ping-config/environment.json          # Singleton — environment bill of materials
ping-config/<type>/                   # One subdirectory per resource type (e.g. populations/, applications/)
ping-config/<type>/<name-slug>.json   # One file per resource instance, named by slugified name
ping-config/overrides/<env>/<type>/   # Environment-specific field overrides (redirectUris, etc.)
ping-config/sandbox/                  # Sandbox-only config (e.g. role assignments for dev access) — not applied to production
.github/workflows/                    # CI/CD pipelines — sandbox creation, deployment
.claude/skills/                       # Agent skills for SDLC operations
```

### Config file conventions

- Base files in `ping-config/<type>/` contain only portable, environment-agnostic fields
- Environment-specific fields (e.g. `redirectUris`) go in `ping-config/overrides/<env-name>/<type>/<file>.json`
- At apply time, workflows merge base + overlay using `jq -s '.[0] * .[1]'`
- Never write `id` fields into config files — resources are matched by `name` at apply time

### Apply order (dependency layers)

Workflows apply resource types in this order to satisfy dependencies:

```
populations → password-policies → identity-providers → notification-policies
  → sign-on-policies → groups → applications
```

To add a new resource type: create the `ping-config/<type>/` directory and add the type to the `RESOURCE_TYPES` array in both workflow files at the correct dependency position.

## SDLC workflow

1. **Create** — push a `feature/`, `dev/`, or `sandbox/` branch → GitHub Actions provisions a sandbox from `ping-config/`
2. **Develop** — make changes in the PingOne admin console
3. **Extract** — use `/ping-extract-changes` to pull live state back into `ping-config/`
4. **Promote** — merge to `main` → deploy workflow applies `ping-config/` to production environments
