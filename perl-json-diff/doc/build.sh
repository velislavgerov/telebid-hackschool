#!/usr/bin/env bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

## Check dependancies
command -v pod2html >/dev/null 2>&1 || { echo >&2 "You need to install pod2html to run this script.  Aborting."; exit 1; }

## Build
printf "Building html docs."
pod2html ../lib/JSON/Patch/Diff.pm > module.html
printf ". "
pod2html ../bin/jsondiff.pl > jsondiff.html
printf "(done)\n"
