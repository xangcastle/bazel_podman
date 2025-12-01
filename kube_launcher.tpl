#!/usr/bin/env bash
set -euo pipefail

# --- Runfiles Setup ---
if [[ -n "${RUNFILES_DIR:-}" ]]; then
  export RUNFILES_DIR="$RUNFILES_DIR"
elif [[ -d "${0}.runfiles" ]]; then
  export RUNFILES_DIR="${0}.runfiles"
else
  abspath() { cd "$(dirname "$1")" && pwd; }
  export RUNFILES_DIR="$(abspath "$0").runfiles"
fi

if [[ -d "$RUNFILES_DIR/_main" ]]; then
    export MAIN_REPO_PATH="$RUNFILES_DIR/_main"
else
    export MAIN_REPO_PATH="$RUNFILES_DIR"
fi

resolve_path() {
    local p="$1"
    local clean="${p#../}"
    if [[ -f "$RUNFILES_DIR/$clean" ]]; then
        echo "$RUNFILES_DIR/$clean"
    elif [[ -f "$MAIN_REPO_PATH/$clean" ]]; then
        echo "$MAIN_REPO_PATH/$clean"
    else
        echo "ERROR: Could not resolve path for: $p" >&2
        exit 1
    fi
}

PODMAN_BIN=$(resolve_path "%{podman_path}")
MANIFEST="%{manifest_path}"

echo "🐳 Podman Play Kube: $MANIFEST"
RESOLVED_MANIFEST=$(resolve_path "$MANIFEST")

# Play the kube manifest
# We might want --down support too via separate target or arg
CMD="%{command}" # play or down

if [[ "$CMD" == "play" ]]; then
    echo "🚀 Deploying pods from manifest..."
    # replace adds idempotency if pods exist (needs --replace)
    "$PODMAN_BIN" play kube --replace "$RESOLVED_MANIFEST"
elif [[ "$CMD" == "down" ]]; then
    echo "🛑 Tearing down pods from manifest..."
    "$PODMAN_BIN" play kube --down "$RESOLVED_MANIFEST"
fi
