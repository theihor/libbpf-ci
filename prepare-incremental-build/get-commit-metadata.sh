#!/bin/bash

set -eux

branch=${1:-bpf-next_base}

echo "branch=${branch}" >> "${GITHUB_OUTPUT}"

upstream="${branch//_base/}"

git fetch --quiet --prune --no-tags --depth=1 --no-recurse-submodules \
    origin "+refs/heads/${upstream}:refs/remotes/origin/${upstream}"
commit=$(git rev-parse "origin/${upstream}")

timestamp_utc="$(TZ=utc git show --format='%cd' --no-patch --date=iso-strict-local "${commit}")"

echo "timestamp=${timestamp_utc}" >> "${GITHUB_OUTPUT}"
echo "commit=${commit}" >> "${GITHUB_OUTPUT}"
echo "Most recent upstream commit is ${commit}"

