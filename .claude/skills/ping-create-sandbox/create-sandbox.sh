#!/usr/bin/env bash
# Creates a PingOne SANDBOX environment and applies all resources from ping-config/.
# Usage: create-sandbox.sh <environment-name>
set -euo pipefail

SANDBOX_NAME="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/ping-config"

if [[ -z "$SANDBOX_NAME" ]]; then
  echo "Usage: create-sandbox.sh <environment-name>" >&2
  exit 1
fi

# --- Create environment ---
TMP_ENV=$(mktemp /tmp/sandbox-env-XXXX.json)
trap 'rm -f "$TMP_ENV"' EXIT

pingcli pingone environments template > "$TMP_ENV"

# Inject name and type into the template
python3 - "$TMP_ENV" "$SANDBOX_NAME" <<'EOF'
import sys, json
path, name = sys.argv[1], sys.argv[2]
with open(path) as f:
    body = json.load(f)
body["name"] = name
body["type"] = "SANDBOX"
with open(path, "w") as f:
    json.dump(body, f, indent=2)
EOF

echo "Creating environment: $SANDBOX_NAME"
CREATE_OUTPUT=$(pingcli pingone environments create \
  --from-file "$TMP_ENV" \
  --output-format json \
  --no-color)

SANDBOX_ENV_ID=$(echo "$CREATE_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")

if [[ -z "$SANDBOX_ENV_ID" ]]; then
  echo "ERROR: environment create did not return an ID" >&2
  exit 1
fi

echo "Environment ID: $SANDBOX_ENV_ID"

# --- Apply resources ---
apply_resource() {
  local resource_type="$1"
  local file="$2"
  local display_name="$3"

  echo -n "  Applying $resource_type \"$display_name\"... "
  pingcli pingone "$resource_type" apply \
    --environment-id "$SANDBOX_ENV_ID" \
    --from-file "$file" \
    --no-color
  echo "done"
}

apply_resource "populations"       "$CONFIG_DIR/population.json"        "Demo Users"
apply_resource "password-policies" "$CONFIG_DIR/password-policy.json"   "Demo Password Policy"
apply_resource "applications"      "$CONFIG_DIR/application-oidc.json"  "Demo Web App"

# --- Summary ---
CONSOLE_URL="https://console.pingone.com/?env=$SANDBOX_ENV_ID"

echo ""
echo "Sandbox environment ready."
echo ""
echo "  Name:    $SANDBOX_NAME"
echo "  ID:      $SANDBOX_ENV_ID"
echo "  Console: $CONSOLE_URL"
echo ""
echo "To use in other commands:"
echo "  export SANDBOX_ENV_ID=$SANDBOX_ENV_ID"
echo ""
echo "Next: make changes in PingOne, then run /ping-extract-changes to capture them."
