#!/bin/sh
set -eu

if pgrep -x Appresize >/dev/null 2>&1; then
    echo "Appresize is already running. Quit it before running hosted tests (task test:unit)." >&2
    exit 2
fi

exec "$@"
