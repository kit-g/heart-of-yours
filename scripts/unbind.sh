#!/usr/bin/env bash

# deletes local branches that are not in remote anymore
git fetch -p && git branch -vv | awk '/: gone]/{print $1}' | xargs git branch -D