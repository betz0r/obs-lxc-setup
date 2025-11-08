#!/bin/bash
# Fix GPU permissions at runtime
if [ -d /dev/dri ]; then
    chmod 666 /dev/dri/* || true
fi

exec "$@"
