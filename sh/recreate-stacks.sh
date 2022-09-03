#!/bin/bash

# recreate all stacks in "compose" directory
ls -d $(realpath -- "$(dirname -- "$0")/../compose/*/") | \
    while read -r dir; do \
        echo "✨ Recreating Stack: $(basename -- $dir)"
        echo "   📁 Directory: $dir"
        docker compose --project-directory $dir up -d;
    done