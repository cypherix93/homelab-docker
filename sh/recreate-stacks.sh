#!/bin/bash

# arguments
directory="*";
force="";

while getopts d:f flag
do
    case "${flag}" in
        d) directory=${OPTARG};;
        f) force="--force-recreate";;
    esac
done

root_dir=$(realpath -- $(dirname -- "$0"));
compose_dirs=$(realpath -- "$root_dir/../compose/$directory/");

# echo "$root_dir";
# echo "$directory";
# echo "$force";
# echo "$compose_dirs";
#
# ls -ld $compose_dirs;

#exit 0;

# recreate all stacks in "compose" directory
ls -d $compose_dirs | \
    while read -r dir; do \
        echo "✨ Recreating Stack: $(basename -- $dir)";
        echo "   📁 Directory: $dir";
        cd $dir \
            && docker-compose pull --include-deps \
            && docker compose up -d $force;
        cd $root_dir;
    done