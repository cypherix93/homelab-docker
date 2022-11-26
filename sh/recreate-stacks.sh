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

compose_dirs=$(realpath -- "$(dirname -- "$0")/../compose/$directory/");

#echo "$directory";
#echo "$force";
#echo "$compose_dirs";
#
#ls -ld $compose_dirs;

#exit 0;

# recreate all stacks in "compose" directory
ls -d $compose_dirs | \
    while read -r dir; do \
        echo "✨ Recreating Stack: $(basename -- $dir)"
        echo "   📁 Directory: $dir"
        docker compose --project-directory $dir up -d --pull 'always' $force;
    done