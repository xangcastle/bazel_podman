#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${RUNFILES_DIR:-}" ]]; then
    RUNFILES="$RUNFILES_DIR"
elif [[ -n "${RUNFILES:-}" ]]; then
    RUNFILES="$RUNFILES"
else
    RUNFILES="${BASH_SOURCE[0]}.runfiles"
fi

export CONTAINERS_HELPER_BINARY_DIR="$RUNFILES/{workspace}"

exec "$RUNFILES/{workspace}/{path}" "$@"
