#!/bin/bash

revisions=${1:-2}

echo "GIT squashing last $revisions commits"
git reset --soft HEAD~${revisions} && git commit --edit -m"$(git log --format=%B --reverse HEAD..HEAD@{1})"
