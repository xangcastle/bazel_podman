#!/usr/bin/env bash
set -euo pipefail

# --- Runfiles Setup ---
# Robust runfiles discovery matching Bazel best practices
if [[ -n "${RUNFILES_DIR:-}" ]]; then
  # Environment variable already set
  export RUNFILES_DIR="$RUNFILES_DIR"
elif [[ -d "${0}.runfiles" ]]; then
  # Runfiles directory next to the script
  export RUNFILES_DIR="${0}.runfiles"
else
  # Attempt to resolve runfiles relative to the script location
  abspath() { cd "$(dirname "$1")" && pwd; }
  export RUNFILES_DIR="$(abspath "$0").runfiles"
fi

# Handle Bzlmod structure (_main vs repo name)
if [[ -d "$RUNFILES_DIR/_main" ]]; then
    export MAIN_REPO_PATH="$RUNFILES_DIR/_main"
else
    export MAIN_REPO_PATH="$RUNFILES_DIR"
fi

# --- Path Resolution ---
resolve_path() {
    local p="$1"
    # Remove ../ prefix often found in external dep short_paths
    local clean="${p#../}"
    
    # Try direct resolution
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
LOADER_BIN=""
%{loader_block}

# --- Volume Setup ---
VOLUME_FLAGS=()
%{volume_setup}

# --- Main Execution ---
CONTAINER_NAME="%{container_name}"
IMAGE="%{image}"

echo "🐳 Podman Toolchain: $CONTAINER_NAME"

# 1. Load Image if needed
if [[ -n "$LOADER_BIN" ]]; then
    echo "📦 Loading OCI image..."
    export DOCKER="$PODMAN_BIN"
    "$LOADER_BIN"
fi

# 2. Check Container State
RUNNING=$("$PODMAN_BIN" ps --filter "name=^/${CONTAINER_NAME}$" --format "{{.ID}}")
STOPPED=$("$PODMAN_BIN" ps -a --filter "name=^/${CONTAINER_NAME}$" --filter "status=exited" --filter "status=created" --format "{{.ID}}")

if [[ -n "$RUNNING" ]]; then
    echo "✅ Container '$CONTAINER_NAME' is already running ($RUNNING)."
    # Optional: attach?
elif [[ -n "$STOPPED" ]]; then
    echo "🔄 Container '$CONTAINER_NAME' exists but is stopped. Starting..."
    "$PODMAN_BIN" start "$CONTAINER_NAME"
    echo "✅ Started."
else
    echo "🚀 Creating and starting '$CONTAINER_NAME' from image: $IMAGE"
    
    # Build command args safely
    CMD_ARGS=(%{command_args})

    # Disable nounset temporarily to allow empty array expansion on Bash 3.2 (macOS)
    set +u
    "$PODMAN_BIN" run -d \
        %{env_flags} \
        %{port_flags} \
        "${VOLUME_FLAGS[@]}" \
        --name "$CONTAINER_NAME" \
        "$IMAGE" \
        "${CMD_ARGS[@]}"
    set -u
        
    echo "✨ Started successfully."
fi

echo ""
echo "📋 Commands:"
echo "  Stop:  bazel run %{label_stop}"
echo "  Logs:  bazel run %{label_logs}"
echo "  Shell: bazel run %{label_bash}"
