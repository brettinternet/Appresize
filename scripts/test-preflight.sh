#!/bin/sh
set -eu

if pgrep -x HyperWindow >/dev/null 2>&1; then
    echo "HyperWindow is already running. Quit it before running hosted tests (task test:unit)." >&2
    exit 2
fi

exec "$@"
