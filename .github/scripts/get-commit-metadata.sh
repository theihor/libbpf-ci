#!/bin/bash

# branch="${GITHUB_BASE_REF}"

# if [ "${GITHUB_EVENT_NAME}" = 'push' ]; then
#   branch="${GITHUB_REF_NAME}"
# fi

set -eux

echo "pwd = $(pwd)"

branch=${1:-bpf-next_base}

echo "branch=${branch}" >> "${GITHUB_OUTPUT}"

upstream="${branch//_base/}"

commit=$(git rev-parse "origin/${upstream}" 2> /dev/null)
if [ -z "${commit}" ]; then
  echo "Could not rev-parse commit for origin/${upstream}, fetching..."
  git fetch --quiet --prune --no-tags --depth=1 --no-recurse-submodules \
      origin "+refs/heads/${upstream}:refs/remotes/origin/${upstream}"
  commit=$(git rev-parse "origin/${upstream}")
fi

timestamp_utc="$(TZ=utc git show --format='%cd' --no-patch --date=iso-strict-local "${commit}")"

echo "timestamp=${timestamp_utc}" >> "${GITHUB_OUTPUT}"
echo "commit=${commit}" >> "${GITHUB_OUTPUT}"
echo "Most recent upstream commit is ${commit}"
