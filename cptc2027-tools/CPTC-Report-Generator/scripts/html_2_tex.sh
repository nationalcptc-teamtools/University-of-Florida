#!/bin/sh

# Preserve the original shell entrypoint used by the report-generation pipeline, actual conversion logic lives in Python because robust
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/html_2_tex.py"

